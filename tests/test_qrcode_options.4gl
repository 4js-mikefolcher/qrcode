-- Unit tests for option normalisation and URL construction in
-- com.fourjs.qrcode.qrcode_common. Offline: no network, no disk.

IMPORT FGL com.fourjs.fglunit.Assertions
IMPORT FGL com.fourjs.qrcode.qrcode_common

-- Normalise a record carrying only `data`, and return the status code.
PRIVATE FUNCTION normalise(opts qrcode_common.tQRCodeOptions INOUT)
    RETURNS INTEGER
    DEFINE code INTEGER
    DEFINE msg STRING
    CALL qrcode_common.normaliseOptions(opts) RETURNING code, msg
    RETURN code
END FUNCTION

------------------------------------------------------------------------
-- normaliseOptions(): defaults
------------------------------------------------------------------------

PUBLIC FUNCTION test_normalise_fills_every_default()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = "https://example.com"
    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, normalise(opts),
        "a record with only data is valid")
    CALL Assertions.assertEqualsInt(qrcode_common.cDefaultSize, opts.size,
        "size defaults")
    CALL Assertions.assertEquals(qrcode_common.cDefaultFormat, opts.format,
        "format defaults")
    CALL Assertions.assertEquals(qrcode_common.cDefaultEcc, opts.ecc,
        "ecc defaults")
    CALL Assertions.assertEqualsInt(qrcode_common.cDefaultMargin, opts.margin,
        "margin defaults")
    CALL Assertions.assertEqualsInt(qrcode_common.cDefaultQzone, opts.qzone,
        "qzone defaults")
    CALL Assertions.assertEqualsInt(qrcode_common.cDefaultConnectTimeout,
        opts.connectTimeout, "connect timeout defaults")
    CALL Assertions.assertEqualsInt(qrcode_common.cDefaultReadTimeout,
        opts.readTimeout, "read timeout defaults")
END FUNCTION

PUBLIC FUNCTION test_normalise_replaces_nonpositive_timeouts()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = "x"
    LET opts.connectTimeout = 0
    LET opts.readTimeout = -5
    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, normalise(opts),
        "non-positive timeouts are corrected, not rejected")
    CALL Assertions.assertEqualsInt(qrcode_common.cDefaultConnectTimeout,
        opts.connectTimeout, "zero connect timeout falls back to the default")
    CALL Assertions.assertEqualsInt(qrcode_common.cDefaultReadTimeout,
        opts.readTimeout, "negative read timeout falls back to the default")
END FUNCTION

------------------------------------------------------------------------
-- normaliseOptions(): data
------------------------------------------------------------------------

PUBLIC FUNCTION test_normalise_rejects_null_data()
    DEFINE opts qrcode_common.tQRCodeOptions
    CALL Assertions.assertEqualsInt(qrcode_common.cErrMissingData,
        normalise(opts), "NULL data is rejected")
END FUNCTION

PUBLIC FUNCTION test_normalise_rejects_empty_data()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = ""
    CALL Assertions.assertEqualsInt(qrcode_common.cErrMissingData,
        normalise(opts), "empty data is rejected")
END FUNCTION

------------------------------------------------------------------------
-- normaliseOptions(): format
------------------------------------------------------------------------

PUBLIC FUNCTION test_normalise_lowercases_format()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = "x"
    LET opts.format = "PNG"
    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, normalise(opts),
        "an upper-case format is accepted")
    CALL Assertions.assertEquals("png", opts.format, "format is normalised")
END FUNCTION

PUBLIC FUNCTION test_normalise_rejects_unknown_format()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = "x"
    LET opts.format = "bmp"
    CALL Assertions.assertEqualsInt(qrcode_common.cErrInvalidFormat,
        normalise(opts), "bmp is not a supported format")
END FUNCTION

PUBLIC FUNCTION test_normalise_accepts_every_documented_format()
    DEFINE formats DYNAMIC ARRAY OF STRING = [
            qrcode_common.cFormatPng, qrcode_common.cFormatGif,
            qrcode_common.cFormatJpeg, qrcode_common.cFormatJpg,
            qrcode_common.cFormatSvg, qrcode_common.cFormatEps
        ]
    DEFINE opts qrcode_common.tQRCodeOptions
    DEFINE i INTEGER
    FOR i = 1 TO formats.getLength()
        INITIALIZE opts.* TO NULL
        LET opts.data = "x"
        LET opts.format = formats[i]
        CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, normalise(opts),
            SFMT("format '%1' is accepted", formats[i]))
    END FOR
END FUNCTION

------------------------------------------------------------------------
-- normaliseOptions(): size
------------------------------------------------------------------------

PUBLIC FUNCTION test_normalise_rejects_size_below_minimum()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = "x"
    LET opts.size = qrcode_common.cMinSize - 1
    CALL Assertions.assertEqualsInt(qrcode_common.cErrInvalidSize,
        normalise(opts), "size below cMinSize is rejected")
END FUNCTION

PUBLIC FUNCTION test_normalise_rejects_raster_size_above_maximum()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = "x"
    LET opts.format = qrcode_common.cFormatPng
    LET opts.size = qrcode_common.cMaxSize + 1
    CALL Assertions.assertEqualsInt(qrcode_common.cErrInvalidSize,
        normalise(opts), "raster formats cap at cMaxSize")
END FUNCTION

PUBLIC FUNCTION test_normalise_allows_large_vector_sizes()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = "x"
    LET opts.format = qrcode_common.cFormatSvg
    LET opts.size = qrcode_common.cMaxSizeSvg
    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, normalise(opts),
        "svg accepts sizes a raster format would reject")
END FUNCTION

PUBLIC FUNCTION test_normalise_rejects_vector_size_above_maximum()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = "x"
    LET opts.format = qrcode_common.cFormatEps
    LET opts.size = qrcode_common.cMaxSizeSvg + 1
    CALL Assertions.assertEqualsInt(qrcode_common.cErrInvalidSize,
        normalise(opts), "vector formats still have an upper bound")
END FUNCTION

------------------------------------------------------------------------
-- normaliseOptions(): ecc, margin, qzone
------------------------------------------------------------------------

PUBLIC FUNCTION test_normalise_uppercases_ecc()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = "x"
    LET opts.ecc = "h"
    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, normalise(opts),
        "a lower-case ecc is accepted")
    CALL Assertions.assertEquals(qrcode_common.cEccHigh, opts.ecc,
        "ecc is normalised to upper case")
END FUNCTION

PUBLIC FUNCTION test_normalise_rejects_unknown_ecc()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = "x"
    LET opts.ecc = "Z"
    CALL Assertions.assertEqualsInt(qrcode_common.cErrInvalidEcc,
        normalise(opts), "only L, M, Q and H are valid")
END FUNCTION

PUBLIC FUNCTION test_normalise_margin_bounds()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = "x"
    LET opts.margin = 0
    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, normalise(opts),
        "a zero margin is accepted")
    CALL Assertions.assertEqualsInt(qrcode_common.cDefaultMargin, opts.margin,
        "zero reads as 'unset' and takes the default, as it does for size")

    INITIALIZE opts.* TO NULL
    LET opts.data = "x"
    LET opts.margin = qrcode_common.cMaxMargin + 1
    CALL Assertions.assertEqualsInt(qrcode_common.cErrInvalidMargin,
        normalise(opts), "margin above cMaxMargin is rejected")

    INITIALIZE opts.* TO NULL
    LET opts.data = "x"
    LET opts.margin = -1
    CALL Assertions.assertEqualsInt(qrcode_common.cErrInvalidMargin,
        normalise(opts), "a negative margin is rejected")
END FUNCTION

PUBLIC FUNCTION test_normalise_qzone_bounds()
    DEFINE opts qrcode_common.tQRCodeOptions
    LET opts.data = "x"
    LET opts.qzone = qrcode_common.cMaxQzone
    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, normalise(opts),
        "qzone at the documented maximum is accepted")

    INITIALIZE opts.* TO NULL
    LET opts.data = "x"
    LET opts.qzone = qrcode_common.cMaxQzone + 1
    CALL Assertions.assertEqualsInt(qrcode_common.cErrInvalidQzone,
        normalise(opts), "qzone above cMaxQzone is rejected")
END FUNCTION

------------------------------------------------------------------------
-- buildApiUrl()
------------------------------------------------------------------------

PUBLIC FUNCTION test_buildApiUrl_targets_the_create_endpoint()
    DEFINE opts qrcode_common.tQRCodeOptions
    DEFINE url STRING
    LET opts.data = "hello"
    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, normalise(opts), "setup")
    LET url = qrcode_common.buildApiUrl(opts)
    CALL Assertions.assertContains(url, qrcode_common.cApiBaseUrl,
        "the create-qr-code endpoint is used")
END FUNCTION

PUBLIC FUNCTION test_buildApiUrl_percent_encodes_the_payload()
    DEFINE opts qrcode_common.tQRCodeOptions
    DEFINE url STRING
    LET opts.data = "a b&c=d"
    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, normalise(opts), "setup")
    LET url = qrcode_common.buildApiUrl(opts)
    CALL Assertions.assertContains(url, "data=a%20b%26c%3Dd",
        "payload separators are escaped so they cannot split the query")
END FUNCTION

PUBLIC FUNCTION test_buildApiUrl_emits_square_size_and_options()
    DEFINE opts qrcode_common.tQRCodeOptions
    DEFINE url STRING
    LET opts.data = "x"
    LET opts.size = 300
    LET opts.ecc = qrcode_common.cEccQuartile
    LET opts.margin = 4
    LET opts.qzone = 2
    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, normalise(opts), "setup")
    LET url = qrcode_common.buildApiUrl(opts)
    CALL Assertions.assertContains(url, "size=300x300", "size is sent as NxN")
    CALL Assertions.assertContains(url, "format=png", "format is sent")
    CALL Assertions.assertContains(url, "ecc=Q", "ecc is sent")
    CALL Assertions.assertContains(url, "margin=4", "margin is sent")
    CALL Assertions.assertContains(url, "qzone=2", "qzone is sent")
END FUNCTION

PUBLIC FUNCTION test_buildApiUrl_omits_unset_colours()
    DEFINE opts qrcode_common.tQRCodeOptions
    DEFINE url STRING
    LET opts.data = "x"
    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, normalise(opts), "setup")
    LET url = qrcode_common.buildApiUrl(opts)
    CALL Assertions.assertNotContains(url, "&color=",
        "no foreground colour parameter when unset")
    CALL Assertions.assertNotContains(url, "&bgcolor=",
        "no background colour parameter when unset")
END FUNCTION

PUBLIC FUNCTION test_buildApiUrl_includes_colours_when_set()
    DEFINE opts qrcode_common.tQRCodeOptions
    DEFINE url STRING
    LET opts.data = "x"
    LET opts.color = "003366"
    LET opts.bgcolor = "255-255-255"
    CALL Assertions.assertEqualsInt(qrcode_common.cErrOk, normalise(opts), "setup")
    LET url = qrcode_common.buildApiUrl(opts)
    CALL Assertions.assertContains(url, "&color=003366", "foreground colour")
    CALL Assertions.assertContains(url, "&bgcolor=255-255-255",
        "a decimal triplet survives encoding (hyphens are unreserved)")
END FUNCTION
