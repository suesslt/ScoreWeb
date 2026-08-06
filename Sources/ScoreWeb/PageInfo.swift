import Score
import Vapor

/// Render-Kontext des geteilten Pagination-Partials (`scoreweb/pagination.leaf`,
/// WEB-7): Seitenlinks behalten die Filter-Query, ‹/›-Enden werden deaktiviert.
public struct PageInfo: Content {
    public let page: Int
    public let pageCount: Int
    /// Basis-Pfad der Seitenlinks, z. B. `/members`.
    public let path: String
    /// Querystring OHNE `page`, damit Links die aktiven Filter behalten.
    public let query: String
    /// Beschriftungen (Wirte lokalisieren via `req.t`); Defaults deutsch.
    public let previousLabel: String
    public let nextLabel: String
    public let pageOfFormat: String

    public var hasPrev: Bool { page > 1 }
    public var hasNext: Bool { page < pageCount }
    public var prev: Int { max(1, page - 1) }
    public var next: Int { min(pageCount, page + 1) }
    public var pageOfText: String {
        pageOfFormat
            .replacingOccurrences(of: "%1", with: String(page))
            .replacingOccurrences(of: "%2", with: String(pageCount))
    }

    public init(page: Int, pageCount: Int, path: String, query: String = "",
                previousLabel: String = "‹ Zurück", nextLabel: String = "Weiter ›",
                pageOfFormat: String = "Seite %1 / %2") {
        self.page = page
        self.pageCount = pageCount
        self.path = path
        self.query = query
        self.previousLabel = previousLabel
        self.nextLabel = nextLabel
        self.pageOfFormat = pageOfFormat
    }

    /// Direkt aus einem `Score.Page`-Ergebnis (Kernel, ARCH §12).
    public init<Item>(_ result: Page<Item>, path: String, query: String = "",
                      previousLabel: String = "‹ Zurück", nextLabel: String = "Weiter ›",
                      pageOfFormat: String = "Seite %1 / %2") {
        self.init(page: result.page, pageCount: result.pageCount, path: path, query: query,
                  previousLabel: previousLabel, nextLabel: nextLabel, pageOfFormat: pageOfFormat)
    }
}
