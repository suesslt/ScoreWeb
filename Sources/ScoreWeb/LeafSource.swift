import Leaf
import LeafKit
import Vapor

/// Zugriff auf die Paket-Ressourcen (Muster `WebAccounting`): eine zweite
/// Leaf-Quelle auf das Modul-Bundle, damit Wirte `scoreweb/…`-Partials rendern
/// können, während ihr eigenes `layout` beim Host bleibt.
///
/// ```swift
/// let sources = LeafSources()
/// try sources.register(source: "host", using: NIOLeafFiles(...), searchable: true)
/// try sources.register(source: "scoreweb", using: ScoreWebResources.leafSource(app), searchable: true)
/// app.leaf.sources = sources
/// ```
public enum ScoreWebResources {
    public static func leafSource(_ app: Application) throws -> any LeafSource {
        guard let path = Bundle.module.resourcePath else {
            throw Abort(.internalServerError, reason: "ScoreWebResources: Ressourcenpfad fehlt.")
        }
        let views = path + "/Views/"
        // OHNE `.toVisibleFiles`: der Bundle-Pfad liegt im Debug-Build unter
        // `.build/…`, und diese Schranke lehnt Pfadsegmente mit führendem Punkt ab.
        // `.toSandbox` bleibt — Zugriff nur innerhalb des Bundle-Verzeichnisses.
        return NIOLeafFiles(fileio: app.fileio,
                            limits: [.toSandbox, .requireExtensions],
                            sandboxDirectory: views,
                            viewDirectory: views)
    }
}
