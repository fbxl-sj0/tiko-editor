/'
    Project: omaGUI Portable Raster Image Tests
    -------------------------------------------

    File: raster_image_smoke.bas

    Purpose:

        Verify the content-sniffing BMP, PNG, GIF, and baseline JPEG paths.

    Responsibilities:

        - decode a transparent GIF and a generated baseline JPEG from memory
        - load BMP and PNG files and memory buffers through gfxlib BLoad
        - reject truncated input without leaking a gfxlib image
        - optionally probe caller-supplied corpus image paths

    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:

        - network image retrieval
        - platform image APIs
        - visual screenshot comparisons
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"
#include once "tests/test_harness.bi"


Private Function rasterSmoke_Base64Value(ByVal character As UByte) As Integer
    If character >= Asc("A") AndAlso character <= Asc("Z") Then
        Return character - Asc("A")
    End If
    If character >= Asc("a") AndAlso character <= Asc("z") Then
        Return character - Asc("a") + 26
    End If
    If character >= Asc("0") AndAlso character <= Asc("9") Then
        Return character - Asc("0") + 52
    End If
    If character = Asc("+") Then Return 62
    If character = Asc("/") Then Return 63
    Return -1
End Function


Private Function rasterSmoke_ReadFile( _
    ByVal filePath As String, fileBytes() As UByte _
) As LongInt
    Dim As Integer fileNumber
    Dim As Integer ioResult
    Dim As LongInt byteCount

    fileNumber = FreeFile
    If Open(filePath For Binary Access Read As #fileNumber) <> 0 Then Return 0
    byteCount = LOF(fileNumber)
    If byteCount < 1 OrElse byteCount > RASTERIMAGE_MAX_FILE_BYTES Then
        Close #fileNumber
        Return 0
    End If
    ReDim fileBytes(0 To byteCount - 1)
    ioResult = Get(#fileNumber, 1, fileBytes())
    Close #fileNumber
    If ioResult <> 0 Then Return 0
    Return byteCount
End Function


Private Function rasterSmoke_DecodeBase64( _
    ByVal encodedText As String, decodedBytes() As UByte _
) As Long
    Dim As Long expectedCount
    Dim As Long outputCount
    Dim As Long position
    Dim As Integer values(0 To 3)
    Dim As ULong packedValue

    If Len(encodedText) = 0 OrElse (Len(encodedText) Mod 4) <> 0 Then Return 0
    expectedCount = (Len(encodedText) \ 4) * 3
    If Right(encodedText, 1) = "=" Then expectedCount -= 1
    If Right(encodedText, 2) = "==" Then expectedCount -= 1
    If expectedCount < 1 Then Return 0
    ReDim decodedBytes(0 To expectedCount - 1)

    For position = 1 To Len(encodedText) Step 4
        For valueIndex As Integer = 0 To 3
            If Mid(encodedText, position + valueIndex, 1) = "=" Then
                values(valueIndex) = 0
            Else
                values(valueIndex) = rasterSmoke_Base64Value( _
                    Asc(Mid(encodedText, position + valueIndex, 1)) _
                )
                If values(valueIndex) < 0 Then Return 0
            End If
        Next valueIndex

        packedValue = (CULng(values(0)) Shl 18) Or _
            (CULng(values(1)) Shl 12) Or _
            (CULng(values(2)) Shl 6) Or CULng(values(3))
        If outputCount < expectedCount Then
            decodedBytes(outputCount) = (packedValue Shr 16) And &hFF
            outputCount += 1
        End If
        If outputCount < expectedCount Then
            decodedBytes(outputCount) = (packedValue Shr 8) And &hFF
            outputCount += 1
        End If
        If outputCount < expectedCount Then
            decodedBytes(outputCount) = packedValue And &hFF
            outputCount += 1
        End If
    Next position
    Return outputCount
End Function


Dim As UByte gifBytes(0 To 42) = { _
    &h47, &h49, &h46, &h38, &h39, &h61, &h02, &h00, _
    &h02, &h00, &h80, &h00, &h00, &h00, &h00, &h00, _
    &h00, &h00, &h00, &h21, &hF9, &h04, &h01, &h00, _
    &h00, &h00, &h00, &h2C, &h00, &h00, &h00, &h00, _
    &h02, &h00, &h02, &h00, &h00, &h02, &h02, &h84, _
    &h51, &h00, &h3B _
}
Dim As String jpegBase64 = _
    "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkS" & _
    "Ew8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJ" & _
    "CQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIy" & _
    "MjIyMjIyMjIyMjIyMjL/wAARCAAIAAgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEA" & _
    "AAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIh" & _
    "MUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6" & _
    "Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZ" & _
    "mqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx" & _
    "8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREA" & _
    "AgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAV" & _
    "YnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hp" & _
    "anN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPE" & _
    "xcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDP" & _
    "8OeAfufuf0ooop0qkuUvJM4xf1SPvH//2Q=="
Dim As String pngBase64 = _
    "iVBORw0KGgoAAAANSUhEUgAAABsAAAAgCAYAAADjaQM7AAAABmJLR0QA/wD/AP+g" & _
    "vaeTAAAACXBIWXMAAA9hAAAPYQGoP6dpAAAEzUlEQVRIie2UWWxUVRzGv3P3ubN1" & _
    "9pm2dmEpJVUSAz40RE3ALZhIH5QYowGjEhLTB4MSyaA4qVMxEolbBOIDGmMQJeFB" & _
    "okR5UBEhDlFoaCtSShXqlM60s/Tuy/GBNAGkTEEfNOFLztu5v985+e7/ADfzfwu5" & _
    "3g+OHPm21abCUoHgbst2wiMTyuhvRWPf5icfOvivyGgux6/7Kb9CkthVKb90b0D2" & _
    "xDyigJaQhBDr4PjZvNVXNN/1jqx4PpMh7g3LFq3f2RoO+bZHg4H7KCeiMeRFQqSY" & _
    "1CwohoXbEl7cHiI4WdRxakzZ3BnJb+vqerp63bLlvR9GJId8FY9GlwycHoZkKSCS" & _
    "F8mGBqimBVbg4ZNE3NXoxS2SiwNDkxAkqd923de3rnnwoyt57LVkkUXL0g2x6KPn" & _
    "+3Iw+r9Hio4jaORxcmAIY7YIj8+HkqJhSreRV2zo4GFyUqyimV2dK1b+kNv/+ZlL" & _
    "edxMosVrd8jUqC47O3wW+uBRzI+KaGmKgrgOrPIIThe9KAaDCMkCClPAuMIg7JcA" & _
    "tQTK88TLMM8A+OZSJjOTzGIqPipIjZVSEUkfwfwFc0AAWI6L5qYU5slViNRG3Cui" & _
    "oOj4ZWQUA+cuQIAN0TXhIVS+kjmj7MT2Fy5wrn1G8MhQVRWGacB13YsLBBzjQjd0" & _
    "/FE1YNoOTNNEuVJFg8wiyAE+geyetQwAAiz5jo/U4/cpgtzRY7AsCwzLoDBexKm8" & _
    "iopqgDU1cK4N23LQGqsDT1xNMdVNG9Y88sl1ySQOBwVLU0J3PIBRncexY30YOjOC" & _
    "4YIN/7wlqI+EkPRLcHQNdRyKCyOenoKidb7f/USWEEKv5NWcs64X31preaM7KFyc" & _
    "O3USjmUi1TQXnCCAMMCUpsGYKu+uD8c27cuuG7oWa8a/cTq8OLGL0fiiTthMpKW9" & _
    "Q9V1mARQ9Isdjqk62uoCbC3RrGSfZTImgL2Pb3xj4eAk7aGEQcGi0AAsjAeRiIUR" & _
    "5lyxFgeo0dllGwnL25YF17bguC5kjoPIcwAhYBn8rZ+rpebNpmNYZsh1HIBSMABY" & _
    "AtiUwnEoVBaBWR14Npv27NnDhpxSU71goD4gIC5zCAsUQdZBnNUQNwqxzatXS7U4" & _
    "13wbp5OKxZb6BPpqi59hO1IBzPFRzPXYmCNbSNIKRFuLV1iiHD585NA/vlm5OvHw" & _
    "VGWcD4Qi4AggEQc+HlDL47jw5xA8soz29o6VtTgzdtbTk24uTUzcoyrmZDgSWxpP" & _
    "JEAphWlZAAhAGIDh4JH9iCeSaG5u1WrJZhzqLb09byrV4nOqZkMzLLQtWABDNwBQ" & _
    "cBwPEIDneFBCIPA8HNcZdGz3qbFqdVhTVWZbb+/5Wcuy2WxCV0pvix7fqnAkCoHn" & _
    "QSkFyzBgGAa246BarQAAxvKjAENwa0cHbFMvuYBrWM57y5fdn21razOmmTN2lk6n" & _
    "xyLx5ncs2/nV7/NbvCDDdV2UK+XjvCh8KQh8IZ5IIZGsh88fhChKmJycPMQxTr9X" & _
    "4tVQXbhBVdXLaqr5NuZyueC5wb3dXsl45ef+ieyGl3dtBVDNZF66szEZ/rouFBP7" & _
    "+gYKsXhy57Pd3WkA2JjNxl5Lp8drsa8amoN84ov2xZRePir7dzy25cDH63/89INM" & _
    "5w2Bb+Y/n78ANLMKtAfGyc0AAAAASUVORK5CYII="
Dim As UByte jpegBytes()
Dim As UByte pngBytes()
Dim As UByte bmpBytes()
Dim As UByte badBytes(0 To 2) = {&h47, &h49, &h46}
Dim As UByte emptyBytes()
Dim As RasterImage Ptr loadedImage
Dim As String errorMessage
Dim As Long jpegByteCount
Dim As Long pngByteCount
Dim As LongInt bmpByteCount
Dim As Long bufferWidth
Dim As Long bufferHeight
Dim As Long bytesPerPixel
Dim As Long pitch
Dim As Long bufferSize
Dim As Any Ptr pixelData
Dim As ULong cornerPixel

backend_Init 64, 64, 1

test_Section "native GIF"
AssertTrue rasterimage_DetectFormat( _
    gifBytes(), 43 _
) = RASTERIMAGE_FORMAT_GIF, "GIF signature is detected"
AssertTrue rasterimage_LoadMemory( _
    gifBytes(), 43, loadedImage, errorMessage _
), "transparent GIF decodes from memory"
If loadedImage <> 0 Then
    AssertTrue loadedImage->width = 2 AndAlso loadedImage->height = 2, _
        "GIF logical dimensions are retained"
    AssertTrue loadedImage->formatKind = RASTERIMAGE_FORMAT_GIF AndAlso _
        loadedImage->hasAlpha <> 0, _
        "GIF format and transparency are reported"
    AssertTrue rasterimage_ScaleToFit( _
        loadedImage, 1, 1, errorMessage _
    ) AndAlso loadedImage->width = 1 AndAlso loadedImage->height = 1, _
        "decoded image can be proportionally fitted without another library"
    rasterimage_Destroy loadedImage
    loadedImage = 0
End If

test_Section "native baseline JPEG"
jpegByteCount = rasterSmoke_DecodeBase64(jpegBase64, jpegBytes())
AssertTrue jpegByteCount = 649, "baseline JPEG fixture decodes from Base64"
AssertTrue rasterimage_DetectFormat( _
    jpegBytes(), jpegByteCount _
) = RASTERIMAGE_FORMAT_JPEG, "JPEG signature is detected"
AssertTrue rasterimage_LoadMemory( _
    jpegBytes(), jpegByteCount, loadedImage, errorMessage _
), "baseline JPEG decodes from memory"
If loadedImage <> 0 Then
    AssertTrue loadedImage->width = 8 AndAlso loadedImage->height = 8, _
        "JPEG frame dimensions are retained"
    AssertTrue ImageInfo( _
        loadedImage->pixels, bufferWidth, bufferHeight, bytesPerPixel, _
        pitch, pixelData, bufferSize _
    ) = 0 AndAlso bytesPerPixel = 4 AndAlso pixelData <> 0, _
        "JPEG output is a valid 32-bit gfxlib image"
    If pixelData <> 0 Then
        cornerPixel = Cast(ULong Ptr, _
            Cast(UByte Ptr, pixelData) + 7 * pitch _
        )[7]
        AssertTrue ((cornerPixel Shr 16) And &hFF) > 210 AndAlso _
            ((cornerPixel Shr 8) And &hFF) > 210 AndAlso _
            (cornerPixel And &hFF) > 210, _
            "JPEG inverse transform and YCbCr conversion retain bright corner"
    End If
    rasterimage_Destroy loadedImage
    loadedImage = 0
End If

test_Section "gfxlib BMP and PNG"
AssertTrue rasterimage_LoadFile( _
    "assets/fonts/font_arial_10_regular.bmp", loadedImage, errorMessage _
), "BMP loads through the content-sniffing file API"
If loadedImage <> 0 Then
    AssertTrue loadedImage->formatKind = RASTERIMAGE_FORMAT_BMP AndAlso _
        loadedImage->width > 0 AndAlso loadedImage->height > 0, _
        "BMP metadata is retained"
    rasterimage_Destroy loadedImage
    loadedImage = 0
End If
bmpByteCount = rasterSmoke_ReadFile( _
    "assets/fonts/font_arial_10_regular.bmp", bmpBytes() _
)
AssertTrue bmpByteCount > 0 AndAlso rasterimage_LoadMemory( _
    bmpBytes(), bmpByteCount, loadedImage, errorMessage _
), "BMP memory data is bridged through gfxlib BLoad"
If loadedImage <> 0 Then
    AssertTrue loadedImage->formatKind = RASTERIMAGE_FORMAT_BMP, _
        "memory BMP retains its detected format"
    rasterimage_Destroy loadedImage
    loadedImage = 0
End If

pngByteCount = rasterSmoke_DecodeBase64(pngBase64, pngBytes())
AssertTrue pngByteCount > 0 AndAlso rasterimage_DetectFormat( _
    pngBytes(), pngByteCount _
) = RASTERIMAGE_FORMAT_PNG, "PNG memory fixture is detected"
AssertTrue rasterimage_LoadMemory( _
    pngBytes(), pngByteCount, loadedImage, errorMessage _
), "PNG memory data is bridged through gfxlib BLoad"
If loadedImage <> 0 Then
    AssertTrue loadedImage->formatKind = RASTERIMAGE_FORMAT_PNG AndAlso _
        loadedImage->width = 27 AndAlso loadedImage->height = 32, _
        "memory PNG dimensions and format are retained"
    rasterimage_Destroy loadedImage
    loadedImage = 0
End If

test_Section "invalid input"
AssertTrue rasterimage_DetectFormat( _
    emptyBytes(), 1 _
) = RASTERIMAGE_FORMAT_UNKNOWN, _
    "unallocated byte arrays are rejected before format detection"
AssertTrue rasterimage_LoadMemory( _
    badBytes(), 3, loadedImage, errorMessage _
) = 0 AndAlso loadedImage = 0 AndAlso Len(errorMessage) > 0, _
    "truncated input returns a diagnostic and no image"

If __FB_ARGC__ > 1 Then
    test_Section "optional corpus files"
    For argumentIndex As Integer = 1 To __FB_ARGC__ - 1
        AssertTrue rasterimage_LoadFile( _
            Command(argumentIndex), loadedImage, errorMessage _
        ), "corpus image loads: " & Command(argumentIndex)
        If loadedImage <> 0 Then
            rasterimage_Destroy loadedImage
            loadedImage = 0
        End If
    Next argumentIndex
End If

backend_Exit
test_Summary
End 0

/' end of raster_image_smoke.bas '/
