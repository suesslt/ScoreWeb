import Vapor

/// Setzt HTTP-Security-Header auf JEDER Antwort (Defense-in-Depth): CSP mit
/// `frame-ancestors 'none'` + `X-Frame-Options: DENY` gegen Clickjacking,
/// `nosniff`, Referrer-Policy und (nur hinter TLS, d. h. in Produktion) HSTS.
///
/// CSP-Defaults: alle Quellen `self`, keine externen/CDN-Ressourcen (WEB-6).
/// `allowInlineScripts`/`allowInlineStyles` für Wirte mit first-party
/// Inline-`<script>`/`style=`-Attributen (Härtung auf Nonces bleibt Wirtssache);
/// `allowDataImages` für data-URI-Logos.
public struct SecurityHeadersMiddleware: AsyncMiddleware {
    let sendHSTS: Bool
    let csp: String

    /// - Parameter sendHSTS: In Produktion `true` (TLS terminiert am Proxy); in
    ///   Dev `false` — HSTS über HTTP würde ignoriert und stört lokale Entwicklung.
    public init(sendHSTS: Bool,
                allowInlineScripts: Bool = true,
                allowInlineStyles: Bool = true,
                allowDataImages: Bool = true,
                additionalDirectives: [String] = []) {
        self.sendHSTS = sendHSTS
        let inlineScript = allowInlineScripts ? " 'unsafe-inline'" : ""
        let inlineStyle = allowInlineStyles ? " 'unsafe-inline'" : ""
        let dataImage = allowDataImages ? " data:" : ""
        self.csp = ([
            "default-src 'self'",
            "script-src 'self'\(inlineScript)",
            "style-src 'self'\(inlineStyle)",
            "img-src 'self'\(dataImage)",
            "font-src 'self'",
            "connect-src 'self'",
            "base-uri 'self'",
            "form-action 'self'",
            "frame-ancestors 'none'",
            "object-src 'none'",
        ] + additionalDirectives).joined(separator: "; ")
    }

    public func respond(to req: Request,
                        chainingTo next: any AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: req)
        var headers = response.headers
        headers.replaceOrAdd(name: "Content-Security-Policy", value: csp)
        headers.replaceOrAdd(name: "X-Frame-Options", value: "DENY")
        headers.replaceOrAdd(name: "X-Content-Type-Options", value: "nosniff")
        headers.replaceOrAdd(name: "Referrer-Policy", value: "strict-origin-when-cross-origin")
        if sendHSTS {
            headers.replaceOrAdd(name: "Strict-Transport-Security",
                                 value: "max-age=31536000; includeSubDomains")
        }
        response.headers = headers
        return response
    }
}
