/'
    Project: omaGUI font raster tests
    File: font_span_pixels.bas
    Purpose: Capture identical scenes from batched and original font rendering.
    Responsibilities: Cover glyph bearings, alpha, scaling, italic text, clipping
        and reused mask dimensions; emit a full framebuffer checksum and image.
    Targets:

        FreeBASIC gfxlib builds with headless 32-bit truecolor image support.

    Module API:

        Standalone regression executable; it exposes no library declarations.

    This file intentionally does NOT contain:

        - application input dispatch
        - user-content loading
'/
#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

backend_Init 640, 480, BACKEND_HEADLESS_DRAWABLE, 0, BACKEND_COLOR_DEPTH_TRUE_COLOR
If backend_LoadFontPack(BACKEND_FONT_DEFAULT, "assets/fonts/noto_sans_ui.ogf") = 0 OrElse _
   backend_LoadFontPack(BACKEND_FONT_CASCADIA_MONO, "assets/fonts/cascadia_mono.ogf") = 0 OrElse _
   backend_LoadFontPack(BACKEND_FONT_UNICODE_FALLBACK, "assets/fonts/noto_sans_cjk_sc.ogf") = 0 Then
    backend_Exit
    End 2
End If
ScreenLock
For rowIndex As Integer = 0 To 14
    For columnIndex As Integer = 0 To 19
        backend_Rect columnIndex * 32, rowIndex * 32, 32, 32, _
            RGB(11 + rowIndex * 9, 19 + columnIndex * 7, 31 + (rowIndex + columnIndex) * 5), -1
    Next columnIndex
Next rowIndex
Dim As String sampleText = "AaWm 0123()" & Chr(&HE4, &HB8, &HAD) & Chr(&HCC, &H81)
Dim As Integer fontIds(0 To 3) = {BACKEND_FONT_DEFAULT, BACKEND_FONT_CASCADIA_MONO, _
    BACKEND_FONT_LIBERATION_SERIF_18_REGULAR, BACKEND_FONT_UNICODE_FALLBACK}
Dim As ULong colors(0 To 3) = {RGB(251, 73, 129), &H123456, &H7A37AB91, RGB(97, 239, 41)}
For fontIndex As Integer = 0 To 3
    Dim As Integer y = 12 + fontIndex * 100
    backend_PrintFont -7, y, colors(fontIndex), sampleText, fontIds(fontIndex)
    backend_PrintFontAlpha 180, y, colors(fontIndex), sampleText, fontIds(fontIndex), 119
    backend_PrintFontPercent 9, y + 25, colors(fontIndex), sampleText, fontIds(fontIndex), 75
    backend_PrintFontPercent 180, y + 25, colors(fontIndex), sampleText, fontIds(fontIndex), 125
    backend_PrintItalicFontPercent 350, y + 25, colors(fontIndex), sampleText, fontIds(fontIndex), 150
    backend_SetClip 35, y + 50, 100, 24
    backend_PrintFontPercent 18, y + 48, colors(fontIndex), sampleText, fontIds(fontIndex), 100
    backend_ResetClip
Next fontIndex
' Exercise mask eviction, color-independent reuse and font-generation reset.
' These rows are also captured by the original per-pixel reference build.
Dim As String evictionText
For characterCode As Integer = 33 To 126
    evictionText &= Chr(characterCode)
Next characterCode
backend_PrintFont 1, 426, RGB(201, 87, 41), evictionText, BACKEND_FONT_DEFAULT
backend_PrintFont 1, 445, RGB(47, 203, 117), "AaWm 0123()", BACKEND_FONT_DEFAULT
ScreenUnlock
If backend_LoadFontPack(BACKEND_FONT_DEFAULT, "assets/fonts/noto_sans_ui.ogf") = 0 Then
    backend_Exit
    End 5
End If
ScreenLock
backend_PrintFontAlpha 180, 445, RGB(133, 61, 211), "AaWm 0123()", BACKEND_FONT_DEFAULT, 119
Dim As Any Ptr snapshot = ImageCreate(640, 480, 0, 32)
If snapshot <> 0 Then
    Get (0, 0)-(639, 479), snapshot
End If
ScreenUnlock 1, 0
If snapshot = 0 Then
    backend_Exit
    End 3
End If
Dim As Integer widthValue, heightValue, bytesPerPixel, pitchBytes
Dim As Any Ptr pixels
If ImageInfo(snapshot, widthValue, heightValue, bytesPerPixel, pitchBytes, pixels) <> 0 OrElse _
   pixels = 0 OrElse bytesPerPixel <> 4 Then
    ImageDestroy snapshot
    backend_Exit
    End 4
End If
Dim As ULong checksum
Dim As UByte Ptr pixelBytes = pixels
For byteIndex As Integer = 0 To pitchBytes * heightValue - 1
    checksum = (checksum Shl 5) Or (checksum Shr 27)
    checksum Xor= pixelBytes[byteIndex]
Next byteIndex
If Command(1) <> "" Then BSave Command(1), snapshot
ImageDestroy snapshot
backend_Exit
Print "font_span_pixels: "; checksum
End 0
' end of font_span_pixels.bas
