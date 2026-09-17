-- Unit tests for com.fourjs.qrcode.qrcode_common.
--
-- Pure functions only: nothing here touches the network or writes to disk,
-- so the suite runs anywhere, offline, in milliseconds.
--
-- NOTE: this file is UTF-8 and must stay that way -- test_urlEncode_utf8
-- depends on a literal holding multibyte characters.

IMPORT FGL com.fourjs.fglunit.Assertions
IMPORT FGL com.fourjs.qrcode.qrcode_common

------------------------------------------------------------------------
-- getErrorMessage()
------------------------------------------------------------------------

PUBLIC FUNCTION test_getErrorMessage_known_code()
    CALL Assertions.assertEquals("OK",
        qrcode_common.getErrorMessage(qrcode_common.cErrOk),
        "cErrOk maps to 'OK'")
END FUNCTION

PUBLIC FUNCTION test_getErrorMessage_unknown_code()
    CALL Assertions.assertEquals("Unknown error (-999)",
        qrcode_common.getErrorMessage(-999),
        "an unmapped code reports its own number")
END FUNCTION

-- Guards against a new cErr* constant being added without a matching row
-- in the error map, which would surface to users as "Unknown error (-nnn)".
PUBLIC FUNCTION test_getErrorMessage_every_code_is_mapped()
    DEFINE codes DYNAMIC ARRAY OF INTEGER = [
            qrcode_common.cErrMissingData,
            qrcode_common.cErrInvalidFormat,
            qrcode_common.cErrInvalidSize,
            qrcode_common.cErrInvalidEcc,
            qrcode_common.cErrInvalidMargin,
            qrcode_common.cErrInvalidQzone,
            qrcode_common.cErrMissingSource,
            qrcode_common.cErrSourceNotFound,
            qrcode_common.cErrSourceTooLarge,
            qrcode_common.cErrHttpRequest,
            qrcode_common.cErrHttpStatus,
            qrcode_common.cErrFileSave,
            qrcode_common.cErrParseResponse,
            qrcode_common.cErrNoQRDetected
        ]
    DEFINE i INTEGER
    FOR i = 1 TO codes.getLength()
        CALL Assertions.assertNotContains(
            qrcode_common.getErrorMessage(codes[i]), "Unknown error",
            SFMT("error code %1 has no mapped message", codes[i]))
    END FOR
END FUNCTION

------------------------------------------------------------------------
-- urlEncode()
------------------------------------------------------------------------

PUBLIC FUNCTION test_urlEncode_null_returns_empty_string()
    CALL Assertions.assertEquals("", qrcode_common.urlEncode(NULL),
        "NULL encodes to an empty string, not NULL")
END FUNCTION

PUBLIC FUNCTION test_urlEncode_unreserved_passes_through()
    CALL Assertions.assertEquals("abcXYZ019-_.~",
        qrcode_common.urlEncode("abcXYZ019-_.~"),
        "RFC 3986 unreserved characters are never escaped")
END FUNCTION

PUBLIC FUNCTION test_urlEncode_space_uses_percent_20()
    CALL Assertions.assertEquals("a%20b", qrcode_common.urlEncode("a b"),
        "space encodes as %20, not +")
END FUNCTION

PUBLIC FUNCTION test_urlEncode_reserved_characters_escaped()
    CALL Assertions.assertEquals("%26%2F%3F%3D%2B%23",
        qrcode_common.urlEncode("&/?=+#"),
        "query-significant characters are escaped")
END FUNCTION

-- Regression test for the 1.1.0 encoder bug: the previous hand-rolled
-- implementation walked the string with ORD(), which returns 32 for every
-- byte of a multibyte character in a UTF-8 locale, so accented payloads
-- were silently encoded as runs of %20.
PUBLIC FUNCTION test_urlEncode_utf8_multibyte()
    CALL Assertions.assertEquals("Caf%C3%A9", qrcode_common.urlEncode("Café"),
        "a 2-byte UTF-8 character encodes as both its bytes")
    CALL Assertions.assertEquals("%E6%97%A5%E6%9C%AC",
        qrcode_common.urlEncode("日本"),
        "3-byte UTF-8 characters encode as all three bytes")
END FUNCTION

PUBLIC FUNCTION test_urlEncode_never_emits_raw_percent_20_for_accents()
    CALL Assertions.assertNotContains(qrcode_common.urlEncode("é"), "%20",
        "an accented character must not degrade to a space")
END FUNCTION

------------------------------------------------------------------------
-- isUrl()
------------------------------------------------------------------------

PUBLIC FUNCTION test_isUrl_accepts_http_and_https()
    CALL Assertions.assertTrue(qrcode_common.isUrl("http://example.com"),
        "http:// is a URL")
    CALL Assertions.assertTrue(qrcode_common.isUrl("https://example.com"),
        "https:// is a URL")
END FUNCTION

PUBLIC FUNCTION test_isUrl_is_case_insensitive()
    CALL Assertions.assertTrue(qrcode_common.isUrl("HTTPS://example.com"),
        "scheme matching ignores case")
END FUNCTION

PUBLIC FUNCTION test_isUrl_rejects_local_paths()
    CALL Assertions.assertFalse(qrcode_common.isUrl("/tmp/code.png"),
        "an absolute path is not a URL")
    CALL Assertions.assertFalse(qrcode_common.isUrl("code.png"),
        "a bare filename is not a URL")
END FUNCTION

PUBLIC FUNCTION test_isUrl_rejects_null_and_short_input()
    CALL Assertions.assertFalse(qrcode_common.isUrl(NULL), "NULL is not a URL")
    CALL Assertions.assertFalse(qrcode_common.isUrl(""), "empty is not a URL")
    CALL Assertions.assertFalse(qrcode_common.isUrl("http:/"),
        "a truncated scheme is not a URL")
END FUNCTION

------------------------------------------------------------------------
-- mimeTypeForPath()
------------------------------------------------------------------------

PUBLIC FUNCTION test_mimeTypeForPath_known_extensions()
    CALL Assertions.assertEquals("image/png",
        qrcode_common.mimeTypeForPath("/tmp/a.png"), "png")
    CALL Assertions.assertEquals("image/gif",
        qrcode_common.mimeTypeForPath("/tmp/a.gif"), "gif")
    CALL Assertions.assertEquals("image/jpeg",
        qrcode_common.mimeTypeForPath("/tmp/a.jpg"), "jpg")
    CALL Assertions.assertEquals("image/jpeg",
        qrcode_common.mimeTypeForPath("/tmp/a.jpeg"), "jpeg")
END FUNCTION

PUBLIC FUNCTION test_mimeTypeForPath_ignores_extension_case()
    CALL Assertions.assertEquals("image/png",
        qrcode_common.mimeTypeForPath("/tmp/A.PNG"),
        "an upper-case extension still resolves")
END FUNCTION

PUBLIC FUNCTION test_mimeTypeForPath_falls_back_to_octet_stream()
    CALL Assertions.assertEquals("application/octet-stream",
        qrcode_common.mimeTypeForPath("/tmp/a.bmp"), "unknown extension")
    CALL Assertions.assertEquals("application/octet-stream",
        qrcode_common.mimeTypeForPath("/tmp/noextension"), "no extension")
END FUNCTION
