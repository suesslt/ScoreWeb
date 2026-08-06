import Leaf
import LeafKit
import Vapor

/// Übersetzungs-Store der Web-UI (WEB-5): lädt beim Boot eine JSON-Tabelle
/// `{"WEB-001": {"de": …, "en": …}}`. Zugriff key-basiert mit Fallback auf die
/// `fallbackLanguage`, zuletzt auf den Key (sichtbarer Marker fehlender Einträge).
public struct WebTranslations: Sendable {
    public let supported: Set<String>
    public let fallbackLanguage: String
    private let table: [String: [String: String]]

    /// - Parameter merging: Zusätzliche Tabelle (z. B. eines Screens-Pakets wie
    ///   `WebAccounting`), die UNTER die eigene gemischt wird — bei gleichem
    ///   Schlüssel gewinnt der Host, damit er Texte überschreiben kann.
    public init(path: String,
                supported: Set<String> = ["de", "en", "fr", "it", "ja"],
                fallbackLanguage: String = "de",
                merging additional: [String: [String: String]] = [:]) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let own = try JSONDecoder().decode([String: [String: String]].self, from: data)
        self.init(table: additional.merging(own) { _, host in host },
                  supported: supported, fallbackLanguage: fallbackLanguage)
    }

    public init(table: [String: [String: String]],
                supported: Set<String> = ["de", "en", "fr", "it", "ja"],
                fallbackLanguage: String = "de") {
        self.table = table
        self.supported = supported
        self.fallbackLanguage = fallbackLanguage
    }

    public func string(_ key: String, language: String) -> String {
        let lang = supported.contains(language) ? language : fallbackLanguage
        guard let entry = table[key] else { return key }
        return entry[lang] ?? entry[fallbackLanguage] ?? key
    }

    public var keyCount: Int { table.count }
}

// MARK: - Application/Request-Zugriff

private struct WebTranslationsKey: StorageKey {
    typealias Value = WebTranslations
}

private struct LanguageResolverKey: StorageKey {
    typealias Value = @Sendable (Request) -> String
}

extension Application {
    /// Der beim Boot geladene Store (auch vom `#t`-Tag genutzt).
    public var webTranslations: WebTranslations {
        get { storage[WebTranslationsKey.self] ?? WebTranslations(table: [:]) }
        set { storage[WebTranslationsKey.self] = newValue }
    }

    /// Seitensprache pro Request (Default: Session `tenant_language`, sonst der
    /// Fallback des Stores). Wirte mit anderer Sprachquelle ersetzen die Closure.
    public var webLanguageResolver: @Sendable (Request) -> String {
        get {
            storage[LanguageResolverKey.self] ?? { req in
                req.session.data["tenant_language"]
                    ?? req.application.webTranslations.fallbackLanguage
            }
        }
        set { storage[LanguageResolverKey.self] = newValue }
    }
}

extension Request {
    /// Übersetzter Web-String in der Seitensprache; `%@`-Platzhalter werden der
    /// Reihe nach ersetzt (für Notices, Validierungen, Seitentitel in Controllern).
    public func t(_ key: String, _ args: String...) -> String {
        var value = application.webTranslations
            .string(key, language: application.webLanguageResolver(self))
        for arg in args {
            guard let range = value.range(of: "%@") else { break }
            value = value.replacingCharacters(in: range, with: arg)
        }
        return value
    }
}

// MARK: - Leaf-Tag

/// Leaf-Tag `#t("WEB-001")` bzw. `#t("WEB-002", arg, …)`: löst den Key in der
/// Seitensprache auf (`page.language` bzw. `common.language` des Render-Kontexts);
/// `%@`-Platzhalter werden ersetzt. Die Ausgabe wird HTML-escaped — inkl. `'`,
/// damit auch einfach-gequotete Attributwerte nicht ausbrechen können.
public struct TranslationTag: LeafTag {
    let translations: WebTranslations

    public init(translations: WebTranslations) {
        self.translations = translations
    }

    public func render(_ ctx: LeafContext) throws -> LeafData {
        guard let key = ctx.parameters.first?.string else {
            throw "#t erwartet einen Key als erstes Argument"
        }
        let language = ctx.data["page"]?.dictionary?["language"]?.string
            ?? ctx.data["common"]?.dictionary?["language"]?.string
            ?? translations.fallbackLanguage
        var value = translations.string(key, language: language)
        for param in ctx.parameters.dropFirst() {
            guard let range = value.range(of: "%@") else { break }
            value = value.replacingCharacters(in: range, with: param.string ?? param.short)
        }
        return .string(Self.escape(value))
    }

    static func escape(_ s: String) -> String {
        // `&` zuerst; `'` zusätzlich (einfach-gequotete Attribute).
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
