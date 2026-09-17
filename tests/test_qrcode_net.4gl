-- Live integration tests against goqr.me (api.qrserver.com).
--
-- OPT-IN. Every test skips unless QRCODE_NET_TESTS=1 is set, because these
-- consume the provider's free quota and fail on any machine without
-- outbound internet access:
--
--     QRCODE_NET_TESTS=1 make test
--
-- Payloads are deliberately ASCII: goqr.me's read endpoint mis-decodes
-- bytes above 0x7F, so a non-ASCII round trip would fail for reasons that
-- have nothing to do with this library. See the caveats in USERGUIDE.md.

IMPORT os
IMPORT FGL com.fourjs.fglunit.Assertions
IMPORT FGL com.fourjs.qrcode.qrcode
IMPORT FGL com.fourjs.qrcode.qrcode_read
IMPORT FGL com.fourjs.qrcode.qrcode_common

CONSTANT cPayload = "https://www.4js.com/fglpkg/qrcode"

PRIVATE DEFINE mGenerated DYNAMIC ARRAY OF STRING

PUBLIC FUNCTION tearDown()
    DEFINE i, ignored INTEGER
    FOR i = 1 TO mGenerated.getLength()
        IF mGenerated[i] IS NOT NULL AND os.Path.exists(mGenerated[i]) THEN
            LET ignored = os.Path.delete(mGenerated[i])
        END IF
    END FOR
    CALL mGenerated.clear()
END FUNCTION

-- TRUE when the caller opted in to live network calls.
--
-- Written the long way on purpose: NVL(fgl_getenv(...), "") yields a CHAR
-- empty string, which BDL treats as NULL, so the obvious one-liner compares
-- NULL against "1" and returns NULL rather than FALSE -- and `IF NOT <NULL>`
-- does not execute, silently running the live tests it was meant to skip.
PRIVATE FUNCTION netEnabled() RETURNS BOOLEAN
    DEFINE v STRING
    LET v = fgl_getenv("QRCODE_NET_TESTS")
    IF v IS NULL THEN
        RETURN FALSE
    END IF
    RETURN (v == "1")
END FUNCTION

-- Remember a generated file so tearDown can remove it.
PRIVATE FUNCTION track(path STRING) RETURNS ()
    IF path IS NOT NULL THEN
        LET mGenerated[mGenerated.getLength() + 1] = path
    END IF
END FUNCTION

------------------------------------------------------------------------

PUBLIC FUNCTION test_generate_png_writes_a_readable_file()
    DEFINE opts qrcode_common.tQRCodeOptions
    DEFINE res qrcode_common.tQRCodeResult
    IF NOT netEnabled() THEN
        CALL Assertions.skip("set QRCODE_NET_TESTS=1 to run live goqr.me tests")
        RETURN
    END IF

    LET opts.data = cPayload
    LET opts.size = qrcode_common.cSizeMedium
    LET opts.format = qrcode_common.cFormatPng
    LET res = qrcode.generateQRCode(opts)
    CALL track(res.filepath)

    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, res.status,
        SFMT("generate succeeded (%1)", NVL(res.errorMessage, "")))
    CALL Assertions.assertEqualsInt(200, res.httpStatus, "HTTP 200")
    CALL Assertions.assertTrue(os.Path.exists(res.filepath),
        "the reported file exists on disk")
    CALL Assertions.assertTrue(os.Path.size(res.filepath) > 0,
        "the reported file is not empty")
    CALL Assertions.assertContains(NVL(res.contentType, ""), "image/png",
        "the response is a PNG")
END FUNCTION

PUBLIC FUNCTION test_generate_svg_gets_an_svg_extension()
    DEFINE opts qrcode_common.tQRCodeOptions
    DEFINE res qrcode_common.tQRCodeResult
    IF NOT netEnabled() THEN
        CALL Assertions.skip("set QRCODE_NET_TESTS=1 to run live goqr.me tests")
        RETURN
    END IF

    LET opts.data = cPayload
    LET opts.format = qrcode_common.cFormatSvg
    LET res = qrcode.generateQRCode(opts)
    CALL track(res.filepath)

    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, res.status,
        SFMT("generate succeeded (%1)", NVL(res.errorMessage, "")))
    CALL Assertions.assertEquals("svg",
        NVL(os.Path.extension(res.filepath), ""),
        "goqr.me sends no Content-Disposition, so the library adds the extension")
END FUNCTION

PUBLIC FUNCTION test_generate_honours_an_explicit_output_path()
    DEFINE opts qrcode_common.tQRCodeOptions
    DEFINE res qrcode_common.tQRCodeResult
    DEFINE wanted STRING
    IF NOT netEnabled() THEN
        CALL Assertions.skip("set QRCODE_NET_TESTS=1 to run live goqr.me tests")
        RETURN
    END IF

    LET wanted = os.Path.makeTempName() || ".png"
    CALL track(wanted)
    LET opts.data = cPayload
    LET opts.outputPath = wanted
    LET res = qrcode.generateQRCode(opts)
    CALL track(res.filepath)

    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, res.status,
        SFMT("generate succeeded (%1)", NVL(res.errorMessage, "")))
    CALL Assertions.assertEquals(os.Path.fullPath(wanted), res.filepath,
        "the file lands where the caller asked")
    CALL Assertions.assertTrue(os.Path.exists(wanted),
        "the requested path really exists")
END FUNCTION

PUBLIC FUNCTION test_ascii_payload_survives_a_round_trip()
    DEFINE gen qrcode_common.tQRCodeOptions
    DEFINE genRes qrcode_common.tQRCodeResult
    DEFINE read qrcode_common.tQRReadOptions
    DEFINE readRes qrcode_common.tQRReadResult
    IF NOT netEnabled() THEN
        CALL Assertions.skip("set QRCODE_NET_TESTS=1 to run live goqr.me tests")
        RETURN
    END IF

    LET gen.data = cPayload
    LET genRes = qrcode.generateQRCode(gen)
    CALL track(genRes.filepath)
    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, genRes.status,
        SFMT("generate succeeded (%1)", NVL(genRes.errorMessage, "")))

    LET read.source = genRes.filepath
    LET readRes = qrcode_read.readQRCode(read)
    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, readRes.status,
        SFMT("decode succeeded (%1)", NVL(readRes.errorMessage, "")))
    CALL Assertions.assertEquals(cPayload, readRes.data,
        "the decoded payload matches what was encoded")
END FUNCTION

PUBLIC FUNCTION test_decoding_a_non_qr_image_reports_no_code_found()
    DEFINE opts qrcode_common.tQRReadOptions
    DEFINE res qrcode_common.tQRReadResult
    DEFINE ch base.Channel
    DEFINE path STRING
    IF NOT netEnabled() THEN
        CALL Assertions.skip("set QRCODE_NET_TESTS=1 to run live goqr.me tests")
        RETURN
    END IF

    -- A tiny file that is not a QR code at all.
    LET path = os.Path.makeTempName() || ".png"
    CALL track(path)
    LET ch = base.Channel.create()
    CALL ch.openFile(path, "w")
    CALL ch.writeNoNL("not an image")
    CALL ch.close()

    LET opts.source = path
    LET res = qrcode_read.readQRCode(opts)
    CALL Assertions.assertEqualsInt(qrcode_common.cErrNoQRDetected, res.status,
        "an undecodable upload is reported as 'no QR detected', not a crash")
END FUNCTION
