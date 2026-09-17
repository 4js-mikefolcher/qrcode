-- Error-path tests for the public API of com.fourjs.qrcode.
--
-- Every case here is rejected by validation *before* any HTTP request is
-- made, so the suite runs offline. Live calls live in test_qrcode_net.4gl.

IMPORT os
IMPORT FGL com.fourjs.fglunit.Assertions
IMPORT FGL com.fourjs.qrcode.qrcode
IMPORT FGL com.fourjs.qrcode.qrcode_read
IMPORT FGL com.fourjs.qrcode.qrcode_common

PRIVATE DEFINE mOversizedPath STRING

PUBLIC FUNCTION tearDown()
    DEFINE ignored INTEGER
    IF mOversizedPath IS NOT NULL AND os.Path.exists(mOversizedPath) THEN
        LET ignored = os.Path.delete(mOversizedPath)
    END IF
    LET mOversizedPath = NULL
END FUNCTION

------------------------------------------------------------------------
-- generateQRCode() -- rejected before the network is touched
------------------------------------------------------------------------

PUBLIC FUNCTION test_generate_rejects_missing_data()
    DEFINE opts qrcode_common.tQRCodeOptions
    DEFINE res qrcode_common.tQRCodeResult
    LET res = qrcode.generateQRCode(opts)
    CALL Assertions.assertEqualsInt(qrcode_common.cErrMissingData, res.status,
        "generating without data fails")
    CALL Assertions.assertEqualsInt(0, res.httpStatus,
        "no HTTP request was attempted")
    CALL Assertions.assertNotNull(res.errorMessage,
        "a failure always carries an explanation")
END FUNCTION

PUBLIC FUNCTION test_generate_rejects_bad_format()
    DEFINE opts qrcode_common.tQRCodeOptions
    DEFINE res qrcode_common.tQRCodeResult
    LET opts.data = "x"
    LET opts.format = "tiff"
    LET res = qrcode.generateQRCode(opts)
    CALL Assertions.assertEqualsInt(qrcode_common.cErrInvalidFormat, res.status,
        "an unsupported format fails")
    CALL Assertions.assertEqualsInt(0, res.httpStatus,
        "no HTTP request was attempted")
END FUNCTION

PUBLIC FUNCTION test_generate_rejects_bad_size()
    DEFINE opts qrcode_common.tQRCodeOptions
    DEFINE res qrcode_common.tQRCodeResult
    LET opts.data = "x"
    LET opts.size = qrcode_common.cMaxSize + 1
    LET res = qrcode.generateQRCode(opts)
    CALL Assertions.assertEqualsInt(qrcode_common.cErrInvalidSize, res.status,
        "an out-of-range size fails")
    CALL Assertions.assertNull(res.filepath,
        "no file path is reported when nothing was written")
END FUNCTION

------------------------------------------------------------------------
-- readQRCode() -- rejected before the network is touched
------------------------------------------------------------------------

PUBLIC FUNCTION test_read_rejects_null_source()
    DEFINE opts qrcode_common.tQRReadOptions
    DEFINE res qrcode_common.tQRReadResult
    LET res = qrcode_read.readQRCode(opts)
    CALL Assertions.assertEqualsInt(qrcode_common.cErrMissingSource, res.status,
        "reading without a source fails")
    CALL Assertions.assertEqualsInt(0, res.httpStatus,
        "no HTTP request was attempted")
END FUNCTION

PUBLIC FUNCTION test_read_rejects_empty_source()
    DEFINE opts qrcode_common.tQRReadOptions
    DEFINE res qrcode_common.tQRReadResult
    LET opts.source = ""
    LET res = qrcode_read.readQRCode(opts)
    CALL Assertions.assertEqualsInt(qrcode_common.cErrMissingSource, res.status,
        "an empty source fails")
END FUNCTION

PUBLIC FUNCTION test_read_rejects_missing_local_file()
    DEFINE opts qrcode_common.tQRReadOptions
    DEFINE res qrcode_common.tQRReadResult
    LET opts.source = os.Path.join(os.Path.makeTempName(), "does-not-exist.png")
    LET res = qrcode_read.readQRCode(opts)
    CALL Assertions.assertEqualsInt(qrcode_common.cErrSourceNotFound, res.status,
        "a non-existent local file fails before upload")
    CALL Assertions.assertContains(NVL(res.errorMessage, ""), "does-not-exist.png",
        "the failing path is named in the error")
END FUNCTION

-- goqr.me caps uploads at 1 MiB; the library must reject an oversized file
-- locally rather than spend the round trip discovering it.
PUBLIC FUNCTION test_read_rejects_oversized_local_file()
    DEFINE opts qrcode_common.tQRReadOptions
    DEFINE res qrcode_common.tQRReadResult
    LET mOversizedPath = makeOversizedFile()
    IF mOversizedPath IS NULL THEN
        CALL Assertions.fail("could not create the oversized fixture file")
        RETURN
    END IF
    LET opts.source = mOversizedPath
    LET res = qrcode_read.readQRCode(opts)
    CALL Assertions.assertEqualsInt(qrcode_common.cErrSourceTooLarge, res.status,
        "a file above cMaxReadFileBytes is rejected locally")
    CALL Assertions.assertEqualsInt(0, res.httpStatus,
        "no HTTP request was attempted")
END FUNCTION

-- Write a file just over the 1 MiB read limit. Returns NULL on failure.
PRIVATE FUNCTION makeOversizedFile() RETURNS STRING
    DEFINE ch base.Channel
    DEFINE path STRING
    DEFINE chunk base.StringBuffer
    DEFINE block STRING
    DEFINE i, blocks INTEGER

    LET path = os.Path.makeTempName() || ".png"
    LET chunk = base.StringBuffer.create()
    FOR i = 1 TO 64
        CALL chunk.append("0123456789abcdef")      -- 16 bytes x 64 = 1 KiB
    END FOR
    LET block = chunk.toString()
    LET blocks = (qrcode_common.cMaxReadFileBytes / 1024) + 2

    TRY
        LET ch = base.Channel.create()
        CALL ch.openFile(path, "w")
        FOR i = 1 TO blocks
            CALL ch.writeNoNL(block)
        END FOR
        CALL ch.close()
    CATCH
        RETURN NULL
    END TRY

    IF os.Path.size(path) <= qrcode_common.cMaxReadFileBytes THEN
        RETURN NULL
    END IF
    RETURN path
END FUNCTION
