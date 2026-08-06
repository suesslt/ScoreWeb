# ScoreWeb

Shared web infrastructure for Scoreware Vapor servers (Swift Application
Framework, Configurations C/D). One implementation instead of per-project
copies; auth building blocks live in `ScorewareAuthVapor`.

## Contents

- **`SecurityHeadersMiddleware`** — CSP (`self`-only, configurable inline/data
  allowances), `X-Frame-Options: DENY`, `nosniff`, Referrer-Policy, HSTS in
  production.
- **`DomainErrorMiddleware`** — the ONE `Score.DomainError` → HTTP status table
  (ARCH §5.2) with sanitizing of internal errors (details to the server log
  only). Host seams: `userMessage` (localized texts) and `makeResponse` (each
  project's error wire format is a Config-C client CONTRACT and stays with the
  host).
- **`WebTranslations` + `#t` Leaf tag** — key-based i18n store
  (`{"WEB-001": {"de": …}}`) with language/key fallback, host-wins merging for
  screen packages, HTML-escaped output, `req.t("KEY", args…)` for controllers,
  configurable language resolution via `app.webLanguageResolver`.
- **`PageInfo` + `scoreweb/pagination.leaf`** — the shared pagination partial
  (WEB-7); build from a `Score.Page` result, labels localizable per call.
- **`DatabaseEnvConfig`/`ServerEnvConfig`** — fail-fast environment loading per
  ARCH §11.3 (no silent dev defaults; named `WebConfigError.missing`).
- **`ScoreWeb.leafSource(app)`** — second Leaf source onto the package bundle
  (pattern `WebAccounting`); the host keeps its own `layout`.

## Usage

```swift
.package(url: "https://github.com/suesslt/ScoreWeb.git", from: "1.0.0")
```

```swift
app.middleware.use(SecurityHeadersMiddleware(sendHSTS: app.environment == .production))
app.middleware.use(DomainErrorMiddleware(userMessage: { req, error in ... }))
app.webTranslations = try WebTranslations(path: ..., merging: packageTable)
app.leaf.tags["t"] = TranslationTag(translations: app.webTranslations)
try sources.register(source: "scoreweb", using: ScoreWeb.leafSource(app), searchable: true)
```

Internal *infrastructure* library (LIBRARIES.md §2.12): lives in web/transport/
composition-root targets — never in `Domain`/`Services`.

## License

MIT
