# Changelog

All notable changes to this package are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-09-17

### Fixed

- `qrcode_common.urlEncode()` silently corrupted non-ASCII payloads when the
  program ran in a UTF-8 locale. It walked the string with `ORD()`, which
  returns 32 for every byte of a multibyte character, so `"Café"` was encoded
  as `Caf%20%20` and the generated QR code carried the wrong text with no
  error reported. It now delegates to the built-in `util.Strings.urlEncode()`,
  which converts to UTF-8 before percent-encoding.
- The documented `margin` default of 1 was never applied. A freshly defined
  BDL record sets numeric members to `0`, not NULL, so the `IS NULL` guard in
  `normaliseOptions()` never fired and every caller silently got a margin of
  `0`. Zero is now treated as "unset", the way `size` already was.

### Changed

- Minimum supported Genero version raised from 4.00 to 5.00. The package calls
  `os.Path.describeLastError()`, which was only introduced in 4.01.03, so the
  previous `>=4.0.0` constraint was never accurate. Consumers are unaffected:
  no 1.0.0 release was ever published to the registry.
- `README.md` and `LICENSE` are now included in the published package archive.

### Added

- `LICENSE` (MIT).
- `keywords` in `fglpkg.json`, so the package is findable via `fglpkg search`.
- A test suite: 48 cases across four fglunit suites in `tests/`, covering
  option normalisation, URL building, the helper functions and the API error
  paths. `make test` runs offline in well under a second; the live goqr.me
  integration tests are opt-in via `QRCODE_NET_TESTS=1` (`make test-net`).
- `fglunit` as a dev dependency, and `make` targets for deps, tests, JUnit
  XML output and the demo. The old `make test` (which ran the demo) is now
  `make demo`.
- Documented an upstream defect in goqr.me's read endpoint: it mis-decodes
  bytes above `0x7F`, so a QR code generated from `"Café"` decodes back
  through `readQRCode()` as `"Caf矇"`. Generation is unaffected. The
  `test_qrcode` demo now explains a round-trip mismatch instead of reporting
  it as a bare failure.

## [1.0.0] - 2026-04-17

### Added

- Initial release. `generateQRCode()` and `readQRCode()` against the goqr.me
  (`api.qrserver.com`) API, using the built-in `com.HttpRequest` — no Java
  JARs or other external dependencies.
- Output formats: PNG, GIF, JPEG, JPG, SVG, EPS.
- Options for size, foreground and background colour, margin, quiet zone and
  error correction level.
- Decoding from a local image file (native multipart upload) or from an
  internet-accessible URL.
- `test_qrcode` demo program, runnable via `fglpkg bdl`.
