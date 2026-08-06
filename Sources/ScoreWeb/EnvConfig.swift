import Vapor

/// Fail-fast-Konfiguration aus der Umgebung (ARCH §11.3, Rules CFG-1/CFG-2):
/// Pflichtwerte werfen bei FEHLEN einen benannten Fehler — kein Silent-Default
/// auf Dev-Werte. Ein leerer Wert bleibt erlaubt (lokale trust/peer-Auth).
public enum WebConfigError: Error, CustomStringConvertible {
    case missing(String)

    public var description: String {
        switch self {
        case .missing(let key):
            "Umgebungsvariable '\(key)' fehlt (ARCH §11.3 — .env für lokale Entwicklung)."
        }
    }
}

public enum WebEnvironment {
    public static func require(_ key: String) throws -> String {
        guard let value = Environment.get(key) else { throw WebConfigError.missing(key) }
        return value
    }
}

/// `DATABASE_*` gemäss ARCH §11.3: HOST/NAME/USER/PASSWORD zwingend, PORT default
/// 5432, TLS default AN (lokale Dev-DB setzt `DATABASE_TLS=false`).
public struct DatabaseEnvConfig: Sendable {
    public let host: String
    public let port: Int
    public let name: String
    public let user: String
    public let password: String
    public let useTLS: Bool

    public init(host: String, port: Int, name: String, user: String,
                password: String, useTLS: Bool) {
        self.host = host
        self.port = port
        self.name = name
        self.user = user
        self.password = password
        self.useTLS = useTLS
    }

    public static func fromEnvironment() throws -> DatabaseEnvConfig {
        DatabaseEnvConfig(
            host: try WebEnvironment.require("DATABASE_HOST"),
            port: Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5432,
            name: try WebEnvironment.require("DATABASE_NAME"),
            user: try WebEnvironment.require("DATABASE_USER"),
            password: try WebEnvironment.require("DATABASE_PASSWORD"),
            useTLS: Environment.get("DATABASE_TLS").map { $0 == "true" } ?? true)
    }
}

/// `SERVER_HOST`/`SERVER_PORT` (optional, Defaults 0.0.0.0:8080 — kein Secret).
public struct ServerEnvConfig: Sendable {
    public let host: String
    public let port: Int

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    public static func fromEnvironment() -> ServerEnvConfig {
        ServerEnvConfig(
            host: Environment.get("SERVER_HOST") ?? "0.0.0.0",
            port: Environment.get("SERVER_PORT").flatMap(Int.init) ?? 8080)
    }
}
