# qrcode — User Guide

A thin Genero BDL wrapper around the [goqr.me](https://goqr.me/api/) QR code
API (hosted at `api.qrserver.com`). Supply data to encode (typically a URL),
get back a path to the downloaded image on disk.

- **Package**: `com.fourjs.qrcode`
- **Modules**: `qrcode_common` (types/constants/helpers), `qrcode` (public API)
- **Transport**: built-in `com.HttpRequest` (no Java JARs required)
- **Output**: file on disk, either in the system temp dir or a caller-supplied path
- **Formats**: PNG, GIF, JPEG, JPG, SVG, EPS
- **Genero support**: 5.x, 6.x

## Contents

- [Installation](#installation)
- [Quick start](#quick-start)
- [Public API](#public-api)
- [Options](#options)
- [Result](#result)
- [Constants](#constants)
- [Error codes](#error-codes)
- [Demo program](#demo-program)
- [goqr.me caveats](#goqrme-caveats)

## Installation

```bash
fglpkg install qrcode
```

The package is self-contained; no additional JARs or native libraries are
required.

## Quick start

```4gl
IMPORT FGL com.fourjs.qrcode.qrcode
IMPORT FGL com.fourjs.qrcode.qrcode_common

MAIN
    DEFINE opts qrcode_common.tQRCodeOptions
    DEFINE result qrcode_common.tQRCodeResult

    LET opts.data = "https://www.4js.com"
    LET result = qrcode.generateQRCode(opts)

    IF result.status = qrcode_common.cErrOk THEN
        DISPLAY "Saved: ", result.filepath
    ELSE
        DISPLAY "Error: ", result.errorMessage
    END IF
END MAIN
```

## Public API

### `qrcode.generateQRCode(opts) RETURNING tQRCodeResult`

Downloads a QR code image for `opts.data` and saves it to disk. The
returned record's `filepath` field contains the absolute path to the
saved file. When `opts.outputPath` is NULL, the file is placed in the
Genero runtime's temporary directory (`DBTEMP`).

### `qrcode_read.readQRCode(opts) RETURNING tQRReadResult`

Decodes a QR code from an image. `opts.source` accepts either:

- a local file path (PNG/GIF/JPEG, under 1 MiB), or
- an `http://` or `https://` URL pointing to an internet-accessible image.

The function auto-detects the mode: strings starting with `http://` or
`https://` are sent to goqr.me as `fileurl`, everything else is treated
as a local file path and uploaded as `multipart/form-data`.

Both modes use `com.HttpRequest` — no external dependencies. Local-file
uploads use Genero's native multipart support via `setMultipartType`,
`com.HttpPart`, and `doDataRequest`.

> ⚠️ goqr.me's `fileurl` mode has been observed to return
> `"download error (could not establish connection)"` for many public
> URLs — this is a server-side limitation, not a library issue. If
> this happens to you, download the image locally and pass the file
> path instead.

## Options

Defined in `qrcode_common`:

```4gl
PUBLIC TYPE tQRCodeOptions RECORD
    data           STRING,    -- REQUIRED: text (or URL) to encode
    size           INTEGER,   -- square pixel size; default 200
    format         STRING,    -- png/gif/jpeg/jpg/svg/eps; default "png"
    color          STRING,    -- foreground colour (e.g. "000000" or "0-0-0")
    bgcolor        STRING,    -- background colour (same format as color)
    margin         INTEGER,   -- pixels of outer margin (1..50); default 1
    qzone          INTEGER,   -- quiet zone in modules (0..100); default 0
    ecc            STRING,    -- error correction: "L", "M", "Q", "H"; default "L"
    outputPath     STRING,    -- destination file path; default auto temp file
    connectTimeout INTEGER,   -- TCP connect timeout (s); default 10
    readTimeout    INTEGER    -- read/write timeout (s); default 30
END RECORD
```

Only `data` is required. `normaliseOptions()` (called internally by
`generateQRCode`) fills in defaults for missing values.

> **Zero reads as "unset" for `size` and `margin`.** A freshly defined BDL
> record has its numeric members set to `0`, not NULL, so the library cannot
> distinguish "I want zero" from "I never set this". Both fields therefore
> fall back to their default when left at `0`. `qzone` is unaffected, because
> its default *is* `0` — use it if you need to control the quiet zone exactly.

### Read options

```4gl
PUBLIC TYPE tQRReadOptions RECORD
    source         STRING,   -- REQUIRED: local file path OR http(s) URL
    connectTimeout INTEGER,  -- seconds; default 10
    readTimeout    INTEGER   -- seconds; default 30
END RECORD
```

### Read result

```4gl
PUBLIC TYPE tQRReadResult RECORD
    status       INTEGER,   -- 0 on success; negative on error
    errorMessage STRING,
    data         STRING,    -- the decoded QR content on success
    httpStatus   INTEGER
END RECORD
```

### Size limits

- Raster formats (`png`/`gif`/`jpeg`/`jpg`): **10 ≤ size ≤ 1000**
- Vector formats (`svg`/`eps`): **10 ≤ size ≤ 1,000,000**

### Colour values

Accepted by both `color` and `bgcolor`:

- Hex: `"000000"` (black), `"FF0000"` (red), `"f00"` (short red)
- Decimal triplet: `"0-0-0"`, `"255-0-0"`

The library passes the value through to goqr.me unchanged (after
URL-encoding); it does not validate the colour syntax itself.

## Result

```4gl
PUBLIC TYPE tQRCodeResult RECORD
    status       INTEGER,  -- 0 on success; negative on error
    errorMessage STRING,   -- human-readable detail when status != 0
    filepath     STRING,   -- absolute path to the saved QR image on success
    httpStatus   INTEGER,  -- last HTTP status observed (0 if none)
    contentType  STRING    -- Content-Type header from the response
END RECORD
```

## Constants

All exposed from `qrcode_common`:

### Formats

| Constant       | Value   |
|----------------|---------|
| `cFormatPng`   | `"png"` |
| `cFormatGif`   | `"gif"` |
| `cFormatJpeg`  | `"jpeg"`|
| `cFormatJpg`   | `"jpg"` |
| `cFormatSvg`   | `"svg"` |
| `cFormatEps`   | `"eps"` |

### Error correction levels

| Constant       | Value | Recovery |
|----------------|:-----:|---------:|
| `cEccLow`      | `"L"` | ~7%      |
| `cEccMedium`   | `"M"` | ~15%     |
| `cEccQuartile` | `"Q"` | ~25%     |
| `cEccHigh`     | `"H"` | ~30%     |

### Size presets (pixels)

| Constant       | Value |
|----------------|------:|
| `cSizeSmall`   | 100   |
| `cSizeMedium`  | 200 (default) |
| `cSizeLarge`   | 400   |
| `cSizeXLarge`  | 800   |

### Defaults and limits

| Constant                  | Value |
|---------------------------|------:|
| `cDefaultSize`            | 200   |
| `cDefaultFormat`          | `"png"` |
| `cDefaultEcc`             | `"L"` |
| `cDefaultMargin`          | 1     |
| `cDefaultQzone`           | 0     |
| `cMinSize`                | 10    |
| `cMaxSize` (raster)       | 1000  |
| `cMaxSizeSvg` (vector)    | 1,000,000 |
| `cMaxMargin`              | 50    |
| `cMaxQzone`               | 100   |
| `cDefaultConnectTimeout`  | 10 s  |
| `cDefaultReadTimeout`     | 30 s  |
| `cApiBaseUrl`             | `"https://api.qrserver.com/v1/create-qr-code/"` |

## Error codes

| Constant            | Value  | Meaning |
|---------------------|-------:|---------|
| `cErrOk`            | `0`    | Success |
| `cErrMissingData`   | `-101` | `opts.data` is NULL or empty |
| `cErrInvalidFormat` | `-102` | `opts.format` is not one of png/gif/jpeg/jpg/svg/eps |
| `cErrInvalidSize`   | `-103` | `opts.size` is outside the allowed range |
| `cErrInvalidEcc`    | `-104` | `opts.ecc` is not L/M/Q/H |
| `cErrInvalidMargin` | `-105` | `opts.margin` is outside 0..50 |
| `cErrInvalidQzone`  | `-106` | `opts.qzone` is outside 0..100 |
| `cErrMissingSource` | `-111` | `opts.source` (read) is NULL or empty |
| `cErrSourceNotFound`| `-112` | Local read source file does not exist |
| `cErrSourceTooLarge`| `-113` | Local read source exceeds 1 MiB |
| `cErrHttpRequest`   | `-201` | Underlying HTTP request raised an exception |
| `cErrHttpStatus`    | `-202` | Server returned a non-2xx HTTP status |
| `cErrFileSave`      | `-301` | Could not write the file to `outputPath` |
| `cErrParseResponse` | `-311` | Could not parse the JSON response from goqr.me |
| `cErrNoQRDetected`  | `-312` | No QR code could be decoded from the image |

`qrcode_common.getErrorMessage(n)` returns the canonical message for any
of the above codes.

When the server returns an HTTP error (typically 4xx for a malformed
request), `errorMessage` includes both the status line and the body text
from the server — useful for debugging invalid parameter values.

## Reading example

```4gl
IMPORT FGL com.fourjs.qrcode.qrcode_read
IMPORT FGL com.fourjs.qrcode.qrcode_common

MAIN
    DEFINE opts qrcode_common.tQRReadOptions
    DEFINE res  qrcode_common.tQRReadResult

    LET opts.source = "/tmp/mycode.png"    -- or an http(s) URL
    LET res = qrcode_read.readQRCode(opts)

    IF res.status = qrcode_common.cErrOk THEN
        DISPLAY "Decoded: ", res.data
    ELSE
        DISPLAY "Failed: ", res.errorMessage
    END IF
END MAIN
```

## Demo program

The package ships with a `test_qrcode` program runnable via fglpkg:

```bash
fglpkg bdl qrcode test_qrcode https://www.4js.com
```

It generates five QR codes (default PNG, extra-large PNG, high-ECC with
margin, coloured PNG, and SVG) and then performs a round-trip test —
generates a QR code and decodes it back using `readQRCode`.

## goqr.me caveats

Behaviour inherited from the upstream service:

- No hard rate limit, but the provider asks users generating **more than
  10,000 requests per day** to notify them. Abusive traffic may be refused.
- The service reserves the right to change or discontinue the API.
- **Decoding mangles non-ASCII payloads.** `readQRCode()` returns whatever
  goqr.me reports, and their reader mis-guesses the character set for bytes
  above `0x7F`: a QR code generated from `"Café"` decodes back as
  `"Caf矇"` (the API literally returns `"data":"Caf\u77c7"`). Generation
  is unaffected — it sends correctly percent-encoded UTF-8. Use a local
  decoder if you need a faithful non-ASCII round trip.

Consider caching results locally if you expect heavy use.
