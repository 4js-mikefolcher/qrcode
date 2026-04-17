PACKAGE com.fourjs.qrcode

IMPORT FGL com.fourjs.qrcode.qrcode
IMPORT FGL com.fourjs.qrcode.qrcode_read
IMPORT FGL com.fourjs.qrcode.qrcode_common

-- Demo program for com.fourjs.qrcode.
--
-- Usage:
--   fglrun test_qrcode.42m                 -- uses a default URL
--   fglrun test_qrcode.42m <data>          -- encodes the given text (URL or plain text)
--
-- Generates five QR codes demonstrating the supported options and prints
-- the path to each file so the user can open them.

MAIN
    DEFINE payload STRING

    IF num_args() >= 1 THEN
        LET payload = arg_val(1)
    ELSE
        LET payload = "https://www.4js.com"
    END IF

    DISPLAY "Encoding: ", payload
    DISPLAY ""

    CALL runDefault(payload)
    CALL runLarge(payload)
    CALL runHighEcc(payload)
    CALL runColored(payload)
    CALL runSvg(payload)

    CALL runRoundTrip(payload)

END MAIN

-- Generate a QR code, then decode it back using both the local-file mode
-- and the remote-URL mode. Verifies the payload survives the round trip.
PRIVATE FUNCTION runRoundTrip(payload STRING) RETURNS ()
    DEFINE genOpts  qrcode_common.tQRCodeOptions
    DEFINE genRes   qrcode_common.tQRCodeResult
    DEFINE readOpts qrcode_common.tQRReadOptions
    DEFINE readRes  qrcode_common.tQRReadResult

    DISPLAY "== Round trip (generate then decode) =="

    LET genOpts.data = payload
    LET genOpts.size = qrcode_common.cSizeMedium
    LET genOpts.format = qrcode_common.cFormatPng
    LET genRes = qrcode.generateQRCode(genOpts)

    IF genRes.status != qrcode_common.cErrOk THEN
        DISPLAY SFMT("  generate FAILED: %1", genRes.errorMessage)
        RETURN
    END IF
    DISPLAY SFMT("  generated: %1", genRes.filepath)

    -- Decode from the local file (multipart POST)
    LET readOpts.source = genRes.filepath
    LET readRes = qrcode_read.readQRCode(readOpts)
    CALL reportRead("decode local file", readRes, payload)

    -- Decode from a remote image URL (GET with fileurl=...)
    LET readOpts.source = "https://api.qrserver.com/v1/create-qr-code/?data="
                        || qrcode_common.urlEncode(payload) || "&size=200x200"
    LET readRes = qrcode_read.readQRCode(readOpts)
    CALL reportRead("decode remote URL", readRes, payload)

    DISPLAY ""
END FUNCTION

PRIVATE FUNCTION reportRead(
    label STRING,
    res qrcode_common.tQRReadResult,
    expected STRING
) RETURNS ()
    IF res.status = qrcode_common.cErrOk THEN
        IF res.data = expected THEN
            DISPLAY SFMT("  %1 OK: %2", label, res.data)
        ELSE
            DISPLAY SFMT("  %1 MISMATCH: got %2", label, res.data)
        END IF
    ELSE
        DISPLAY SFMT("  %1 FAILED (%2): %3",
                     label, res.status, NVL(res.errorMessage, ""))
    END IF
END FUNCTION

PRIVATE FUNCTION runDefault(payload STRING) RETURNS ()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = payload
    CALL runSample("PNG, default (200x200)", opts)
END FUNCTION

PRIVATE FUNCTION runLarge(payload STRING) RETURNS ()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = payload
    LET opts.size = qrcode_common.cSizeXLarge
    CALL runSample("PNG, extra large (800x800)", opts)
END FUNCTION

PRIVATE FUNCTION runHighEcc(payload STRING) RETURNS ()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = payload
    LET opts.size = qrcode_common.cSizeMedium
    LET opts.ecc = qrcode_common.cEccHigh
    LET opts.margin = 4
    CALL runSample("PNG, high ECC + extra margin", opts)
END FUNCTION

PRIVATE FUNCTION runColored(payload STRING) RETURNS ()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = payload
    LET opts.size = qrcode_common.cSizeLarge
    LET opts.color = "003366"     -- dark blue foreground
    LET opts.bgcolor = "ffffff"   -- white background
    CALL runSample("PNG, dark-blue on white", opts)
END FUNCTION

PRIVATE FUNCTION runSvg(payload STRING) RETURNS ()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = payload
    LET opts.size = qrcode_common.cSizeLarge
    LET opts.format = qrcode_common.cFormatSvg
    CALL runSample("SVG, 400x400", opts)
END FUNCTION

PRIVATE FUNCTION runSample(label STRING, opts qrcode_common.tQRCodeOptions) RETURNS ()
    DEFINE result qrcode_common.tQRCodeResult

    LET result = qrcode.generateQRCode(opts)

    DISPLAY "-- ", label, " --"
    IF result.status = qrcode_common.cErrOk THEN
        DISPLAY SFMT("  OK         : %1", result.filepath)
        DISPLAY SFMT("  HTTP status: %1", result.httpStatus)
        DISPLAY SFMT("  Content    : %1", NVL(result.contentType, "(none)"))
    ELSE
        DISPLAY SFMT("  FAILED (%1): %2",
                     result.status,
                     NVL(result.errorMessage, "(no detail)"))
        IF result.httpStatus > 0 THEN
            DISPLAY SFMT("  HTTP status: %1", result.httpStatus)
        END IF
    END IF
    DISPLAY ""
END FUNCTION
