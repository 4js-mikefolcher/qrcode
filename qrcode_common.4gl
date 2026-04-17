PACKAGE com.fourjs.qrcode

IMPORT os

-- Module: qrcode_common
-- Shared types, constants, error map and helpers for the qrcode library.
-- Backend: goqr.me (api.qrserver.com) create-qr-code endpoint.

-- Supported output formats
PUBLIC CONSTANT cFormatPng  = "png"
PUBLIC CONSTANT cFormatGif  = "gif"
PUBLIC CONSTANT cFormatJpeg = "jpeg"
PUBLIC CONSTANT cFormatJpg  = "jpg"
PUBLIC CONSTANT cFormatSvg  = "svg"
PUBLIC CONSTANT cFormatEps  = "eps"

-- Error correction levels
PUBLIC CONSTANT cEccLow       = "L"  -- ~7% recovery
PUBLIC CONSTANT cEccMedium    = "M"  -- ~15% recovery
PUBLIC CONSTANT cEccQuartile  = "Q"  -- ~25% recovery
PUBLIC CONSTANT cEccHigh      = "H"  -- ~30% recovery

-- Size presets (pixels; square)
PUBLIC CONSTANT cSizeSmall  = 100
PUBLIC CONSTANT cSizeMedium = 200
PUBLIC CONSTANT cSizeLarge  = 400
PUBLIC CONSTANT cSizeXLarge = 800

-- Defaults applied when the corresponding option field is NULL / 0
PUBLIC CONSTANT cDefaultSize   = 200
PUBLIC CONSTANT cDefaultFormat = "png"
PUBLIC CONSTANT cDefaultEcc    = "L"
PUBLIC CONSTANT cDefaultMargin = 1
PUBLIC CONSTANT cDefaultQzone  = 0

-- Endpoint base URLs for goqr.me
PUBLIC CONSTANT cApiBaseUrl     = "https://api.qrserver.com/v1/create-qr-code/"
PUBLIC CONSTANT cApiReadBaseUrl = "https://api.qrserver.com/v1/read-qr-code/"

-- goqr.me read endpoint accepts images up to 1 MiB
PUBLIC CONSTANT cMaxReadFileBytes = 1048576

-- Default network timeouts (seconds)
PUBLIC CONSTANT cDefaultConnectTimeout = 10
PUBLIC CONSTANT cDefaultReadTimeout    = 30

-- goqr.me documented limits
PUBLIC CONSTANT cMinSize     = 10
PUBLIC CONSTANT cMaxSize     = 1000     -- raster formats
PUBLIC CONSTANT cMaxSizeSvg  = 1000000  -- vector formats
PUBLIC CONSTANT cMaxMargin   = 50
PUBLIC CONSTANT cMaxQzone    = 100

-- Error codes
PUBLIC CONSTANT cErrOk               = 0
PUBLIC CONSTANT cErrMissingData      = -101
PUBLIC CONSTANT cErrInvalidFormat    = -102
PUBLIC CONSTANT cErrInvalidSize      = -103
PUBLIC CONSTANT cErrInvalidEcc       = -104
PUBLIC CONSTANT cErrInvalidMargin    = -105
PUBLIC CONSTANT cErrInvalidQzone     = -106
PUBLIC CONSTANT cErrMissingSource    = -111
PUBLIC CONSTANT cErrSourceNotFound   = -112
PUBLIC CONSTANT cErrSourceTooLarge   = -113
PUBLIC CONSTANT cErrHttpRequest      = -201
PUBLIC CONSTANT cErrHttpStatus       = -202
PUBLIC CONSTANT cErrFileSave         = -301
PUBLIC CONSTANT cErrParseResponse    = -311
PUBLIC CONSTANT cErrNoQRDetected     = -312

-- Options passed into generate()
PUBLIC TYPE tQRCodeOptions RECORD
    data           STRING,    -- REQUIRED: text (or URL) to encode
    size           INTEGER,   -- square pixel size; default cDefaultSize
    format         STRING,    -- "png", "gif", "jpeg", "jpg", "svg", "eps"
    color          STRING,    -- fg colour: "R-G-B" decimal or hex (e.g. "000000")
    bgcolor        STRING,    -- bg colour: same format as color
    margin         INTEGER,   -- pixel margin around the code (0..50)
    qzone          INTEGER,   -- quiet zone in modules (0..100)
    ecc            STRING,    -- error correction level: "L", "M", "Q", "H"
    outputPath     STRING,    -- destination file path; default: auto temp file
    connectTimeout INTEGER,   -- TCP connect timeout (s); default 10
    readTimeout    INTEGER    -- read/write timeout (s); default 30
END RECORD

-- Options passed into readQRCode()
PUBLIC TYPE tQRReadOptions RECORD
    source         STRING,   -- REQUIRED: http(s) URL of an image, or local file path
    connectTimeout INTEGER,  -- optional; seconds
    readTimeout    INTEGER   -- optional; seconds
END RECORD

-- Result returned from readQRCode()
PUBLIC TYPE tQRReadResult RECORD
    status       INTEGER,   -- 0 on success, negative otherwise
    errorMessage STRING,    -- human-readable error detail
    data         STRING,    -- the decoded QR code content on success
    httpStatus   INTEGER    -- last HTTP status code observed (0 if none)
END RECORD

-- Result returned from generate()
PUBLIC TYPE tQRCodeResult RECORD
    status       INTEGER,  -- 0 on success, negative otherwise
    errorMessage STRING,   -- human-readable error detail when status != 0
    filepath     STRING,   -- absolute path to the saved QR file on success
    httpStatus   INTEGER,  -- last HTTP status code observed (0 if none)
    contentType  STRING    -- Content-Type header from the response
END RECORD

PRIVATE DEFINE mErrMap DYNAMIC ARRAY OF RECORD
        num INTEGER,
        message STRING
    END RECORD = [
        ( num: cErrOk,            message: "OK" ),
        ( num: cErrMissingData,   message: "Missing or empty 'data' in options" ),
        ( num: cErrInvalidFormat, message: "Invalid format (expected png, gif, jpeg, jpg, svg, or eps)" ),
        ( num: cErrInvalidSize,   message: "Invalid size (out of allowed range)" ),
        ( num: cErrInvalidEcc,    message: "Invalid error correction level (expected L, M, Q, or H)" ),
        ( num: cErrInvalidMargin, message: "Invalid margin (must be 0..50)" ),
        ( num: cErrInvalidQzone,  message: "Invalid qzone (must be 0..100)" ),
        ( num: cErrMissingSource, message: "Missing or empty 'source' in options" ),
        ( num: cErrSourceNotFound,message: "Source file does not exist" ),
        ( num: cErrSourceTooLarge,message: "Source file exceeds 1 MiB (goqr.me read limit)" ),
        ( num: cErrHttpRequest,   message: "HTTP request failed" ),
        ( num: cErrHttpStatus,    message: "HTTP response returned non-success status" ),
        ( num: cErrFileSave,      message: "Failed to write QR code file" ),
        ( num: cErrParseResponse, message: "Failed to parse response from goqr.me" ),
        ( num: cErrNoQRDetected,  message: "No QR code was detected in the image" )
    ]

PUBLIC FUNCTION getErrorMessage(errNum INTEGER) RETURNS STRING
    DEFINE x INTEGER
    LET x = mErrMap.search("num", errNum)
    IF x > 0 THEN
        RETURN mErrMap[x].message
    END IF
    RETURN SFMT("Unknown error (%1)", errNum)
END FUNCTION

-- Validate and normalise options. Returns (errCode, errMsg).
-- On success errCode = cErrOk and opts is mutated with defaults filled in.
PUBLIC FUNCTION normaliseOptions(opts tQRCodeOptions INOUT) RETURNS (INTEGER, STRING)
    DEFINE maxSize INTEGER

    IF opts.data IS NULL OR opts.data.getLength() = 0 THEN
        RETURN cErrMissingData, getErrorMessage(cErrMissingData)
    END IF

    IF opts.format IS NULL OR opts.format.getLength() = 0 THEN
        LET opts.format = cDefaultFormat
    ELSE
        LET opts.format = opts.format.toLowerCase()
        IF NOT isValidFormat(opts.format) THEN
            RETURN cErrInvalidFormat, getErrorMessage(cErrInvalidFormat)
        END IF
    END IF

    IF opts.size IS NULL OR opts.size = 0 THEN
        LET opts.size = cDefaultSize
    END IF
    IF opts.format = cFormatSvg OR opts.format = cFormatEps THEN
        LET maxSize = cMaxSizeSvg
    ELSE
        LET maxSize = cMaxSize
    END IF
    IF opts.size < cMinSize OR opts.size > maxSize THEN
        RETURN cErrInvalidSize, getErrorMessage(cErrInvalidSize)
    END IF

    IF opts.ecc IS NULL OR opts.ecc.getLength() = 0 THEN
        LET opts.ecc = cDefaultEcc
    ELSE
        LET opts.ecc = opts.ecc.toUpperCase()
        IF opts.ecc != cEccLow AND opts.ecc != cEccMedium
           AND opts.ecc != cEccQuartile AND opts.ecc != cEccHigh THEN
            RETURN cErrInvalidEcc, getErrorMessage(cErrInvalidEcc)
        END IF
    END IF

    IF opts.margin IS NULL THEN
        LET opts.margin = cDefaultMargin
    END IF
    IF opts.margin < 0 OR opts.margin > cMaxMargin THEN
        RETURN cErrInvalidMargin, getErrorMessage(cErrInvalidMargin)
    END IF

    IF opts.qzone IS NULL THEN
        LET opts.qzone = cDefaultQzone
    END IF
    IF opts.qzone < 0 OR opts.qzone > cMaxQzone THEN
        RETURN cErrInvalidQzone, getErrorMessage(cErrInvalidQzone)
    END IF

    IF opts.connectTimeout IS NULL OR opts.connectTimeout <= 0 THEN
        LET opts.connectTimeout = cDefaultConnectTimeout
    END IF
    IF opts.readTimeout IS NULL OR opts.readTimeout <= 0 THEN
        LET opts.readTimeout = cDefaultReadTimeout
    END IF

    RETURN cErrOk, NULL
END FUNCTION

PRIVATE FUNCTION isValidFormat(fmt STRING) RETURNS BOOLEAN
    RETURN fmt = cFormatPng OR fmt = cFormatGif OR fmt = cFormatJpeg
        OR fmt = cFormatJpg OR fmt = cFormatSvg OR fmt = cFormatEps
END FUNCTION

-- RFC 3986 style percent-encoding for the value of a query parameter.
-- Keeps unreserved characters (A-Z a-z 0-9 - _ . ~) unescaped.
PUBLIC FUNCTION urlEncode(value STRING) RETURNS STRING
    DEFINE i INTEGER
    DEFINE code INTEGER
    DEFINE ch STRING
    DEFINE sb base.StringBuffer
    IF value IS NULL THEN
        RETURN ""
    END IF
    LET sb = base.StringBuffer.create()
    FOR i = 1 TO value.getLength()
        LET ch = value.subString(i, i)
        LET code = ORD(ch)
        IF (code >= 48 AND code <= 57)           -- 0-9
        OR (code >= 65 AND code <= 90)           -- A-Z
        OR (code >= 97 AND code <= 122)          -- a-z
        OR code = 45 OR code = 95                -- - _
        OR code = 46 OR code = 126 THEN          -- . ~
            CALL sb.append(ch)
        ELSE
            CALL sb.append(SFMT("%%%1", hexByte(code)))
        END IF
    END FOR
    RETURN sb.toString()
END FUNCTION

-- Format a byte (0-255) as two uppercase hex digits.
PRIVATE FUNCTION hexByte(n INTEGER) RETURNS STRING
    DEFINE digits STRING
    DEFINE hi INTEGER
    DEFINE lo INTEGER
    LET digits = "0123456789ABCDEF"
    LET hi = (n / 16) + 1
    LET lo = (n MOD 16) + 1
    RETURN digits.subString(hi, hi) || digits.subString(lo, lo)
END FUNCTION

-- Build the full goqr.me URL for the given (already normalised) options.
PUBLIC FUNCTION buildApiUrl(opts tQRCodeOptions) RETURNS STRING
    DEFINE sb base.StringBuffer

    LET sb = base.StringBuffer.create()
    CALL sb.append(cApiBaseUrl)
    CALL sb.append("?data=")
    CALL sb.append(urlEncode(opts.data))

    CALL sb.append(SFMT("&size=%1x%1", opts.size))
    CALL sb.append(SFMT("&format=%1", opts.format))
    CALL sb.append(SFMT("&ecc=%1", opts.ecc))
    CALL sb.append(SFMT("&margin=%1", opts.margin))
    CALL sb.append(SFMT("&qzone=%1", opts.qzone))

    IF opts.color IS NOT NULL AND opts.color.getLength() > 0 THEN
        CALL sb.append("&color=")
        CALL sb.append(urlEncode(opts.color))
    END IF
    IF opts.bgcolor IS NOT NULL AND opts.bgcolor.getLength() > 0 THEN
        CALL sb.append("&bgcolor=")
        CALL sb.append(urlEncode(opts.bgcolor))
    END IF

    RETURN sb.toString()
END FUNCTION

-- TRUE if value looks like an http(s) URL.
PUBLIC FUNCTION isUrl(value STRING) RETURNS BOOLEAN
    DEFINE prefix STRING
    IF value IS NULL OR value.getLength() < 7 THEN
        RETURN FALSE
    END IF
    LET prefix = value.subString(1, 7)
    LET prefix = prefix.toLowerCase()
    IF prefix = "http://" THEN
        RETURN TRUE
    END IF
    IF value.getLength() >= 8 THEN
        LET prefix = value.subString(1, 8)
        LET prefix = prefix.toLowerCase()
        IF prefix = "https://" THEN
            RETURN TRUE
        END IF
    END IF
    RETURN FALSE
END FUNCTION

-- Guess a content-type from a file extension. Returns "application/octet-stream"
-- for unknown extensions.
PUBLIC FUNCTION mimeTypeForPath(path STRING) RETURNS STRING
    DEFINE ext STRING
    LET ext = NVL(os.Path.extension(path), "")
    LET ext = ext.toLowerCase()
    CASE ext
        WHEN "png"  RETURN "image/png"
        WHEN "gif"  RETURN "image/gif"
        WHEN "jpg"  RETURN "image/jpeg"
        WHEN "jpeg" RETURN "image/jpeg"
        OTHERWISE   RETURN "application/octet-stream"
    END CASE
END FUNCTION
