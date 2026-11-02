// swift-tools-version: 6.0

import PackageDescription

// ScoreWeb — geteilte Web-Infrastruktur der Scoreware-Konfigurationen C/D (Vapor):
// SecurityHeadersMiddleware, DomainErrorMiddleware (Score.DomainError → HTTP, mit
// Host-Seams für Wire-Format und Benutzertexte), WebTranslations + #t-Leaf-Tag,
// PageInfo + pagination.leaf (Paket-Bundle via leafSource), fail-fast Env-Configs
// (DatabaseEnvConfig/ServerEnvConfig) und das WEB-7-Navigations-CSS-Skelett.
// Auth-Bausteine (WebAuthMiddleware, CSRF, …) liegen in ScorewareAuthVapor.
let package = Package(
    name: "ScoreWeb",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ScoreWeb", targets: ["ScoreWeb"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.99.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.3.0"),
        .package(url: "https://github.com/suesslt/score.git", "2.0.0"..<"4.0.0"),
    ],
    targets: [
        .target(
            name: "ScoreWeb",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "Score", package: "score"),
            ],
            resources: [.copy("Resources/Views")]
        ),
        .testTarget(
            name: "ScoreWebTests",
            dependencies: ["ScoreWeb"]
        ),
    ]
)
