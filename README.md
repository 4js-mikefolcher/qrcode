# qrcode

A Genero BDL package for generating QR codes via the
[goqr.me](https://goqr.me/api/) API (`api.qrserver.com`).

- Package: `com.fourjs.qrcode`
- Genero versions supported: 4.x, 5.x, 6.x
- Generate and decode QR codes (no external deps, uses built-in `com.HttpRequest`)
- Decode from local files (native multipart upload) or internet URLs
- Formats: PNG, GIF, JPEG, SVG, EPS
- Customisable size, colour, margin, quiet zone, and error correction level

## Install

```bash
fglpkg install qrcode
```

## Quick example

```4gl
IMPORT FGL com.fourjs.qrcode.qrcode
IMPORT FGL com.fourjs.qrcode.qrcode_common

MAIN
    DEFINE opts qrcode_common.tQRCodeOptions
    DEFINE result qrcode_common.tQRCodeResult

    LET opts.data = "https://www.4js.com"
    LET opts.size = qrcode_common.cSizeLarge       -- 400 px square
    LET opts.format = qrcode_common.cFormatPng

    LET result = qrcode.generateQRCode(opts)

    IF result.status = qrcode_common.cErrOk THEN
        DISPLAY "Saved to: ", result.filepath
    ELSE
        DISPLAY "Failed: ", result.errorMessage
    END IF
END MAIN
```

## Decoding a QR code

```4gl
IMPORT FGL com.fourjs.qrcode.qrcode_read
IMPORT FGL com.fourjs.qrcode.qrcode_common

MAIN
    DEFINE opts qrcode_common.tQRReadOptions
    DEFINE res  qrcode_common.tQRReadResult

    LET opts.source = "/tmp/mycode.png"   -- local file (or an http(s) URL)
    LET res = qrcode_read.readQRCode(opts)

    IF res.status = qrcode_common.cErrOk THEN
        DISPLAY "Decoded: ", res.data
    END IF
END MAIN
```

See [USERGUIDE.md](USERGUIDE.md) for the full API reference.

## External service dependency

This package is a thin client for the **[goqr.me](https://goqr.me/)** hosted
QR code service (endpoint: `api.qrserver.com`). All encoding and decoding
happens server-side — there is no offline / on-device QR handling.

Every call to `generateQRCode()` or `readQRCode()` makes an HTTP request to
`api.qrserver.com`. Using this package therefore requires:

- an internet connection from wherever the Genero program runs
- accepting the goqr.me [Terms of Service](https://goqr.me/)
- staying within their fair-use policy (they ask users generating more than
  **10,000 requests per day** to contact them)

goqr.me may change, rate-limit, or discontinue the API at any time — your
application will stop working if they do. Consider caching generated images
locally if you expect repeated encodes of the same payload.

## Demo program

```bash
fglpkg bdl qrcode test_qrcode https://www.4js.com
```

## License

MIT
