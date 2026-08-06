import Score
import Vapor

/// Mappt geworfene `Score.DomainError` auf HTTP-Status + Body (ARCH §5.2) — der
/// geteilte Kern: Status-Tabelle und das Sanitizing interner Fehler (storage/
/// transport: Details NUR ins Server-Log, generische Fassung an den Client).
///
/// Zwei Host-Seams:
/// - `userMessage`: Fehler → Benutzertext (Wirte mit i18n z. B. via `req.t`).
///   Default: die Domain-Meldung bzw. ein knapper englischer Text.
/// - `makeResponse`: eigenes Wire-Format des Wirts (Config-C-Clients decodieren
///   ihr projektspezifisches Fehler-JSON — das ist ein Client-VERTRAG und bleibt
///   deshalb beim Wirt). Default: `{"error": <DomainError>, "message": <text>}`.
public struct DomainErrorMiddleware: AsyncMiddleware {
    public typealias UserMessage = @Sendable (Request, DomainError) -> String
    public typealias MakeResponse =
        @Sendable (Request, DomainError, HTTPResponseStatus, String) throws -> Response

    let userMessage: UserMessage
    let makeResponse: MakeResponse?

    public init(userMessage: @escaping UserMessage = { _, error in Self.defaultMessage(error) },
                makeResponse: MakeResponse? = nil) {
        self.userMessage = userMessage
        self.makeResponse = makeResponse
    }

    public func respond(to request: Request,
                        chainingTo next: any AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch let error as DomainError {
            let sanitized = Self.sanitize(error, logger: request.logger)
            let status = Self.status(for: sanitized)
            let message = userMessage(request, sanitized)
            if let makeResponse {
                return try makeResponse(request, sanitized, status, message)
            }
            struct ErrorBody: Content {
                let error: DomainError
                let message: String
            }
            let response = Response(status: status)
            try response.content.encode(ErrorBody(error: sanitized, message: message))
            return response
        }
    }

    /// Die EINE Status-Tabelle (ARCH §5.2).
    public static func status(for error: DomainError) -> HTTPResponseStatus {
        switch error {
        case .notFound: .notFound                       // 404
        case .validation: .unprocessableEntity          // 422
        case .conflict, .businessRule: .conflict        // 409
        case .unauthorized: .unauthorized               // 401
        case .storage: .internalServerError             // 500
        case .transport: .badGateway                    // 502
        }
    }

    /// Interne Fehler tragen ggf. Infrastruktur-Details (DB-/Pfad-Internas):
    /// serverseitig loggen, an den Client nur eine generische Fassung.
    public static func sanitize(_ error: DomainError, logger: Logger) -> DomainError {
        switch error {
        case .storage:
            logger.error("Storage-Fehler: \(String(reflecting: error))")
            return .storage(message: "internal")
        case .transport:
            logger.error("Transport-Fehler: \(String(reflecting: error))")
            return .transport(message: "internal")
        default:
            return error
        }
    }

    /// Default-Benutzertext (englisch, knapp): Domain-Meldungen (validation/
    /// conflict/businessRule) unverändert, Rest generisch.
    public static func defaultMessage(_ error: DomainError) -> String {
        switch error {
        case .notFound(let entity, _): "\(entity) not found"
        case .validation(_, let message): message
        case .conflict(let message): message
        case .businessRule(let code, let message):
            message.isEmpty ? "A business rule (\(code)) refused this operation" : message
        case .unauthorized: "Not authorized"
        case .storage: "Storage failure"
        case .transport: "Upstream failure"
        }
    }
}
