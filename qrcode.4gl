PACKAGE com.fourjs.qrcode

IMPORT com
IMPORT os
IMPORT FGL com.fourjs.qrcode.qrcode_common

-- Module: qrcode
-- Public entry point for generating QR codes via goqr.me (api.qrserver.com).

-- Generate a QR code for the data supplied in opts.
-- On success the returned record's `filepath` points to the saved file.
-- When opts.outputPath is NULL, the file is written to a unique path under
-- the system temporary directory.
PUBLIC FUNCTION generateQRCode(opts qrcode_common.tQRCodeOptions)
    RETURNS qrcode_common.tQRCodeResult

    DEFINE result qrcode_common.tQRCodeResult
    DEFINE errCode INTEGER
    DEFINE errMsg STRING
    DEFINE apiUrl STRING
    DEFINE req com.HttpRequest
    DEFINE resp com.HttpResponse
    DEFINE statusCode INTEGER
    DEFINE downloadedPath STRING
    DEFINE targetPath STRING
    DEFINE ignoreInt INTEGER

    LET result.status = qrcode_common.cErrOk
    LET result.httpStatus = 0

    CALL qrcode_common.normaliseOptions(opts) RETURNING errCode, errMsg
    IF errCode != qrcode_common.cErrOk THEN
        LET result.status = errCode
        LET result.errorMessage = errMsg
        RETURN result
    END IF

    LET apiUrl = qrcode_common.buildApiUrl(opts)

    TRY
        LET req = com.HttpRequest.Create(apiUrl)
        CALL req.setMethod("GET")
        CALL req.setConnectionTimeOut(opts.connectTimeout)
        CALL req.setTimeOut(opts.readTimeout)
        CALL req.setHeader("User-Agent", "fglpkg-qrcode/1.0")
        CALL req.doRequest()
    CATCH
        LET result.status = qrcode_common.cErrHttpRequest
        LET result.errorMessage =
            SFMT("%1: %2",
                 qrcode_common.getErrorMessage(qrcode_common.cErrHttpRequest),
                 NVL(sqlca.sqlerrm, ""))
        RETURN result
    END TRY

    TRY
        LET resp = req.getResponse()
        LET statusCode = resp.getStatusCode()
        LET result.httpStatus = statusCode
        LET result.contentType = resp.getHeader("Content-Type")

        IF statusCode < 200 OR statusCode >= 300 THEN
            LET result.status = qrcode_common.cErrHttpStatus
            LET result.errorMessage =
                SFMT("%1: HTTP %2 %3 — %4",
                     qrcode_common.getErrorMessage(qrcode_common.cErrHttpStatus),
                     statusCode,
                     NVL(resp.getStatusDescription(), ""),
                     NVL(resp.getTextResponse(), ""))
            RETURN result
        END IF

        LET downloadedPath = resp.getFileResponse()
        LET downloadedPath = ensureExtension(downloadedPath, opts.format)
    CATCH
        LET result.status = qrcode_common.cErrHttpRequest
        LET result.errorMessage =
            SFMT("%1: %2",
                 qrcode_common.getErrorMessage(qrcode_common.cErrHttpRequest),
                 NVL(sqlca.sqlerrm, ""))
        RETURN result
    END TRY

    LET targetPath = resolveTargetPath(opts, downloadedPath)

    IF targetPath != downloadedPath THEN
        IF NOT os.Path.copy(downloadedPath, targetPath) THEN
            LET result.status = qrcode_common.cErrFileSave
            LET result.errorMessage =
                SFMT("%1: %2",
                     qrcode_common.getErrorMessage(qrcode_common.cErrFileSave),
                     NVL(os.Path.describeLastError(), ""))
            RETURN result
        END IF
        LET ignoreInt = os.Path.delete(downloadedPath)
    END IF

    LET result.filepath = targetPath
    RETURN result
END FUNCTION

-- Decide where the final QR file should live.
-- If the caller supplied outputPath, use it verbatim (after resolving).
-- Otherwise keep the file where getFileResponse() placed it (DBTEMP).
PRIVATE FUNCTION resolveTargetPath(
    opts qrcode_common.tQRCodeOptions,
    downloadedPath STRING
) RETURNS STRING
    IF opts.outputPath IS NULL OR opts.outputPath.getLength() = 0 THEN
        RETURN downloadedPath
    END IF
    RETURN os.Path.fullPath(opts.outputPath)
END FUNCTION

-- goqr.me does not send a Content-Disposition header, so getFileResponse()
-- writes a UUID-named file with no extension. Rename it so that the
-- extension matches the requested format (png, svg, etc.). If the rename
-- fails, fall back to the original path.
PRIVATE FUNCTION ensureExtension(path STRING, format STRING) RETURNS STRING
    DEFINE currentExt STRING
    DEFINE expectedExt STRING
    DEFINE newPath STRING

    LET expectedExt = format.toLowerCase()
    LET currentExt = NVL(os.Path.extension(path), "")
    LET currentExt = currentExt.toLowerCase()
    IF currentExt = expectedExt THEN
        RETURN path
    END IF
    -- jpg and jpeg are interchangeable on disk
    IF (currentExt = "jpg"  AND expectedExt = "jpeg")
    OR (currentExt = "jpeg" AND expectedExt = "jpg") THEN
        RETURN path
    END IF

    LET newPath = SFMT("%1.%2", path, expectedExt)
    IF os.Path.rename(path, newPath) THEN
        RETURN newPath
    END IF
    RETURN path
END FUNCTION
