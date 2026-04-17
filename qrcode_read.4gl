PACKAGE com.fourjs.qrcode

IMPORT com
IMPORT os
IMPORT util
IMPORT FGL com.fourjs.qrcode.qrcode_common

-- Module: qrcode_read
-- Public entry point for decoding QR codes via goqr.me (api.qrserver.com).
-- Accepts either a URL to an image hosted on the internet or a path to a
-- local image file.

-- Decode the QR code contained in the image referenced by opts.source.
-- On success the returned record's `data` field holds the decoded payload.
PUBLIC FUNCTION readQRCode(opts qrcode_common.tQRReadOptions)
    RETURNS qrcode_common.tQRReadResult

    DEFINE result qrcode_common.tQRReadResult

    LET result.status = qrcode_common.cErrOk
    LET result.httpStatus = 0

    IF opts.source IS NULL OR opts.source.getLength() = 0 THEN
        LET result.status = qrcode_common.cErrMissingSource
        LET result.errorMessage =
            qrcode_common.getErrorMessage(qrcode_common.cErrMissingSource)
        RETURN result
    END IF

    IF opts.connectTimeout IS NULL OR opts.connectTimeout <= 0 THEN
        LET opts.connectTimeout = qrcode_common.cDefaultConnectTimeout
    END IF
    IF opts.readTimeout IS NULL OR opts.readTimeout <= 0 THEN
        LET opts.readTimeout = qrcode_common.cDefaultReadTimeout
    END IF

    IF qrcode_common.isUrl(opts.source) THEN
        CALL readFromUrl(opts) RETURNING result
    ELSE
        CALL readFromFile(opts) RETURNING result
    END IF

    RETURN result
END FUNCTION

PRIVATE FUNCTION readFromUrl(opts qrcode_common.tQRReadOptions)
    RETURNS qrcode_common.tQRReadResult

    DEFINE result qrcode_common.tQRReadResult
    DEFINE req com.HttpRequest
    DEFINE resp com.HttpResponse
    DEFINE apiUrl STRING
    DEFINE body STRING

    LET apiUrl = SFMT("%1?fileurl=%2",
                      qrcode_common.cApiReadBaseUrl,
                      qrcode_common.urlEncode(opts.source))

    TRY
        LET req = com.HttpRequest.Create(apiUrl)
        CALL req.setMethod("GET")
        CALL req.setConnectionTimeOut(opts.connectTimeout)
        CALL req.setTimeOut(opts.readTimeout)
        CALL req.setHeader("User-Agent", "fglpkg-qrcode/1.0")
        CALL req.setHeader("Accept", "application/json")
        CALL req.doRequest()
        LET resp = req.getResponse()
    CATCH
        LET result.status = qrcode_common.cErrHttpRequest
        LET result.errorMessage =
            SFMT("%1: %2",
                 qrcode_common.getErrorMessage(qrcode_common.cErrHttpRequest),
                 NVL(sqlca.sqlerrm, ""))
        RETURN result
    END TRY

    LET result.httpStatus = resp.getStatusCode()
    IF result.httpStatus < 200 OR result.httpStatus >= 300 THEN
        LET result.status = qrcode_common.cErrHttpStatus
        LET result.errorMessage =
            SFMT("%1: HTTP %2 %3",
                 qrcode_common.getErrorMessage(qrcode_common.cErrHttpStatus),
                 result.httpStatus,
                 NVL(resp.getStatusDescription(), ""))
        RETURN result
    END IF

    LET body = resp.getTextResponse()
    CALL parseReadResponse(body) RETURNING result.status, result.errorMessage, result.data
    RETURN result
END FUNCTION

-- Upload a local image file and decode it using com.HttpRequest's native
-- multipart support (setMultipartType + com.HttpPart + doDataRequest).
PRIVATE FUNCTION readFromFile(opts qrcode_common.tQRReadOptions)
    RETURNS qrcode_common.tQRReadResult

    DEFINE result qrcode_common.tQRReadResult
    DEFINE req com.HttpRequest
    DEFINE resp com.HttpResponse
    DEFINE part com.HttpPart
    DEFINE fileData BYTE
    DEFINE fileSize BIGINT
    DEFINE mime STRING
    DEFINE body STRING

    IF NOT os.Path.exists(opts.source) THEN
        LET result.status = qrcode_common.cErrSourceNotFound
        LET result.errorMessage =
            SFMT("%1: %2",
                 qrcode_common.getErrorMessage(qrcode_common.cErrSourceNotFound),
                 opts.source)
        RETURN result
    END IF

    LET fileSize = os.Path.size(opts.source)
    IF fileSize > qrcode_common.cMaxReadFileBytes THEN
        LET result.status = qrcode_common.cErrSourceTooLarge
        LET result.errorMessage =
            SFMT("%1: file is %2 bytes (max %3)",
                 qrcode_common.getErrorMessage(qrcode_common.cErrSourceTooLarge),
                 fileSize,
                 qrcode_common.cMaxReadFileBytes)
        RETURN result
    END IF

    LET mime = qrcode_common.mimeTypeForPath(opts.source)

    TRY
        LET req = com.HttpRequest.Create(qrcode_common.cApiReadBaseUrl)
        CALL req.setMethod("POST")
        CALL req.setConnectionTimeOut(opts.connectTimeout)
        CALL req.setTimeOut(opts.readTimeout)
        CALL req.setHeader("User-Agent", "fglpkg-qrcode/1.0")
        CALL req.setHeader("Accept", "application/json")
        CALL req.setMultipartType("form-data", NULL, NULL)

        -- Hidden MAX_FILE_SIZE form field (goqr.me honours it).
        LET part = com.HttpPart.CreateFromString(
                       SFMT("%1", qrcode_common.cMaxReadFileBytes))
        CALL part.setHeader("Content-Disposition",
                            "form-data; name=\"MAX_FILE_SIZE\"")
        CALL req.addPart(part)

        -- The image itself becomes the final part of the multipart body.
        CALL req.setHeader("Content-Disposition",
                           SFMT("form-data; name=\"file\"; filename=\"%1\"",
                                os.Path.baseName(opts.source)))
        CALL req.setHeader("Content-Type", mime)

        LOCATE fileData IN FILE opts.source
        CALL req.doDataRequest(fileData)

        LET resp = req.getResponse()
    CATCH
        LET result.status = qrcode_common.cErrHttpRequest
        LET result.errorMessage =
            SFMT("%1: %2",
                 qrcode_common.getErrorMessage(qrcode_common.cErrHttpRequest),
                 NVL(sqlca.sqlerrm, ""))
        RETURN result
    END TRY

    LET result.httpStatus = resp.getStatusCode()
    IF result.httpStatus < 200 OR result.httpStatus >= 300 THEN
        LET result.status = qrcode_common.cErrHttpStatus
        LET result.errorMessage =
            SFMT("%1: HTTP %2 %3",
                 qrcode_common.getErrorMessage(qrcode_common.cErrHttpStatus),
                 result.httpStatus,
                 NVL(resp.getStatusDescription(), ""))
        RETURN result
    END IF

    LET body = resp.getTextResponse()
    CALL parseReadResponse(body)
         RETURNING result.status, result.errorMessage, result.data
    RETURN result
END FUNCTION

-- Parse a JSON response from read-qr-code. Returns (status, errorMessage, data).
PRIVATE FUNCTION parseReadResponse(body STRING)
    RETURNS (INTEGER, STRING, STRING)

    DEFINE arr util.JSONArray
    DEFINE obj util.JSONObject
    DEFINE symbols util.JSONArray
    DEFINE sym util.JSONObject
    DEFINE decoded STRING
    DEFINE symErr STRING

    IF body IS NULL OR body.getLength() = 0 THEN
        RETURN qrcode_common.cErrParseResponse,
               qrcode_common.getErrorMessage(qrcode_common.cErrParseResponse),
               NULL
    END IF

    TRY
        LET arr = util.JSONArray.parse(body)
    CATCH
        RETURN qrcode_common.cErrParseResponse,
               SFMT("%1: %2",
                    qrcode_common.getErrorMessage(qrcode_common.cErrParseResponse),
                    body),
               NULL
    END TRY

    IF arr IS NULL OR arr.getLength() = 0 THEN
        RETURN qrcode_common.cErrParseResponse,
               qrcode_common.getErrorMessage(qrcode_common.cErrParseResponse),
               NULL
    END IF

    TRY
        LET obj = arr.get(1)
        LET symbols = obj.get("symbol")
        IF symbols IS NULL OR symbols.getLength() = 0 THEN
            RETURN qrcode_common.cErrNoQRDetected,
                   qrcode_common.getErrorMessage(qrcode_common.cErrNoQRDetected),
                   NULL
        END IF
        LET sym = symbols.get(1)
        LET decoded = sym.get("data")
        LET symErr = sym.get("error")
    CATCH
        RETURN qrcode_common.cErrParseResponse,
               SFMT("%1: unexpected response shape",
                    qrcode_common.getErrorMessage(qrcode_common.cErrParseResponse)),
               NULL
    END TRY

    IF decoded IS NOT NULL AND decoded.getLength() > 0 THEN
        RETURN qrcode_common.cErrOk, NULL, decoded
    END IF

    IF symErr IS NOT NULL AND symErr.getLength() > 0 THEN
        RETURN qrcode_common.cErrNoQRDetected,
               SFMT("%1: %2",
                    qrcode_common.getErrorMessage(qrcode_common.cErrNoQRDetected),
                    symErr),
               NULL
    END IF

    RETURN qrcode_common.cErrNoQRDetected,
           qrcode_common.getErrorMessage(qrcode_common.cErrNoQRDetected),
           NULL
END FUNCTION
