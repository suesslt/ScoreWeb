import Foundation
import Score
import Testing
import Vapor
@testable import ScoreWeb

@Suite("WebTranslations")
struct WebTranslationsTests {

    private let store = WebTranslations(table: [
        "WEB-001": ["de": "Hallo", "en": "Hello"],
        "WEB-002": ["de": "Seite %@ von %@"],
        "WEB-003": ["de": "A & B < C"],
    ])

    @Test("Auflösung mit Sprach- und Key-Fallback")
    func resolution() {
        #expect(store.string("WEB-001", language: "en") == "Hello")
        #expect(store.string("WEB-001", language: "fr") == "Hallo")     // kein fr → de
        #expect(store.string("WEB-001", language: "xx") == "Hallo")     // unsupported → de
        #expect(store.string("WEB-999", language: "de") == "WEB-999")   // fehlender Key sichtbar
    }

    @Test("Host gewinnt beim Merge über die Paket-Tabelle")
    func mergePrecedence() {
        let merged = WebTranslations(table: ["K": ["de": "Host"]])
            .string("K", language: "de")
        #expect(merged == "Host")
        let packaged = WebTranslations(
            table: ["K": ["de": "Host"]].merging(["K2": ["de": "Paket"]]) { host, _ in host })
        #expect(packaged.string("K2", language: "de") == "Paket")
    }

    @Test("Tag-Escaping neutralisiert HTML inkl. einfacher Anführungszeichen")
    func escaping() {
        #expect(TranslationTag.escape(#"<a href="x" onclick='y'>&"#)
            == "&lt;a href=&quot;x&quot; onclick=&#39;y&#39;&gt;&amp;")
    }
}

@Suite("PageInfo")
struct PageInfoTests {

    @Test("Ränder: prev/next werden an den Enden geklemmt")
    func bounds() {
        let first = PageInfo(page: 1, pageCount: 3, path: "/x")
        #expect(!first.hasPrev && first.hasNext && first.next == 2 && first.prev == 1)
        let last = PageInfo(page: 3, pageCount: 3, path: "/x")
        #expect(last.hasPrev && !last.hasNext && last.next == 3)
    }

    @Test("Init aus Score.Page übernimmt Seitenmetadaten; Format ersetzt %1/%2")
    func fromKernelPage() {
        let page = Page(items: ["a"], totalCount: 45, page: 2, size: 20)
        let info = PageInfo(page, path: "/members", query: "council=NR")
        #expect(info.page == 2 && info.pageCount == 3 && info.query == "council=NR")
        #expect(info.pageOfText == "Seite 2 / 3")
        let en = PageInfo(page: 1, pageCount: 2, path: "/x", pageOfFormat: "Page %1 of %2")
        #expect(en.pageOfText == "Page 1 of 2")
    }
}

@Suite("DomainErrorMiddleware")
struct DomainErrorMiddlewareTests {

    @Test("Status-Tabelle gemäss ARCH §5.2")
    func statusTable() {
        #expect(DomainErrorMiddleware.status(for: .notFound(entity: "X", id: "1")) == .notFound)
        #expect(DomainErrorMiddleware.status(for: .validation(field: "f", message: "m")) == .unprocessableEntity)
        #expect(DomainErrorMiddleware.status(for: .conflict(message: "m")) == .conflict)
        #expect(DomainErrorMiddleware.status(for: .businessRule(code: "c", message: "m")) == .conflict)
        #expect(DomainErrorMiddleware.status(for: .unauthorized) == .unauthorized)
        #expect(DomainErrorMiddleware.status(for: .storage(message: "m")) == .internalServerError)
        #expect(DomainErrorMiddleware.status(for: .transport(message: "m")) == .badGateway)
    }

    @Test("Sanitizing: storage/transport verlieren ihre Details, Rest bleibt")
    func sanitizing() {
        let logger = Logger(label: "test")
        #expect(DomainErrorMiddleware.sanitize(.storage(message: "db://secret"), logger: logger)
            == .storage(message: "internal"))
        #expect(DomainErrorMiddleware.sanitize(.transport(message: "http://internal"), logger: logger)
            == .transport(message: "internal"))
        let validation = DomainError.validation(field: "f", message: "m")
        #expect(DomainErrorMiddleware.sanitize(validation, logger: logger) == validation)
    }
}

@Suite("EnvConfig")
struct EnvConfigTests {

    @Test("require wirft benannt bei fehlender Variable (fail-fast, kein Silent-Default)")
    func failFast() {
        #expect(throws: WebConfigError.self) {
            _ = try WebEnvironment.require("SCOREWEB_TEST_SURELY_UNSET_\(UInt32.random(in: 0...9999))")
        }
        setenv("SCOREWEB_TEST_SET", "wert", 1)
        defer { unsetenv("SCOREWEB_TEST_SET") }
        #expect((try? WebEnvironment.require("SCOREWEB_TEST_SET")) == "wert")
    }

    @Test("ServerEnvConfig defaultet auf 0.0.0.0:8080")
    func serverDefaults() {
        let config = ServerEnvConfig.fromEnvironment()
        #expect(config.host == "0.0.0.0" && config.port == 8080)
    }
}
