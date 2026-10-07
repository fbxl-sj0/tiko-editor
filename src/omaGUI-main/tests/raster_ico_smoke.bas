/'
    Project: omaGUI Tests
    File: raster_ico_smoke.bas
    Purpose: Check classic icon decoding and retained PictureBox image ownership.
    Responsibilities: Exercise masks, padded rows, malformed spans, and live redraw.
    This file intentionally does NOT contain a second image decoder.
'/
#lang "fb"
#define OMAGUI_IMPLEMENTATION
#define OMAGUI_PORTABLE_ONLY
#include once "omaGUI.bi"

Private Sub requireValue(ByVal conditionValue As Integer, ByRef messageText As Const String)
    If conditionValue Then Exit Sub
    Screen 0
    Print "FAIL "; messageText
    End 1
End Sub

Private Function rasterIco_LoadMemory(ByRef payload As Const String, ByRef imageValue As RasterImage Ptr, _
    ByRef errorText As String) As Integer
    Dim As UByte bytes(0 To Len(payload) - 1)
    For position As Integer = 0 To Len(payload) - 1
        bytes(position) = Asc(payload, position + 1)
    Next position
    Return rasterimage_LoadMemory(bytes(), Len(payload), imageValue, errorText)
End Function

Private Function pixelValue(ByVal imageValue As RasterImage Ptr, ByVal x As Integer, ByVal y As Integer) As ULong
    Dim As Integer w, h, bpp, pitch, bufferSize
    Dim As Any Ptr pixelBytes
    If ImageInfo(imageValue->pixels, w, h, bpp, pitch, pixelBytes, bufferSize) <> 0 Then
        requireValue(0, "read decoded pixels")
        Return 0
    End If
    If bpp <> 4 OrElse pixelBytes = 0 OrElse w < 1 OrElse h < 1 OrElse _
       pitch < w * 4 OrElse CLngInt(pitch) * CLngInt(h) > bufferSize OrElse _
       x < 0 OrElse x >= w OrElse y < 0 OrElse y >= h Then
        requireValue(0, "pixel within decoded image buffer")
        Return 0
    End If
    ' ImageInfo validates the allocation; x and y were checked above.
    ' FB-LINTER: DISABLE-NEXT-LINE FBL525 FBL-PTR-019 REASON: The pixel coordinate and image buffer extent are explicitly validated.
    Return Cast(ULong Ptr, Cast(UByte Ptr, pixelBytes) + y * pitch)[x]
End Function

' A 3x2, 4-bit icon: two palette entries, padded XOR rows, then AND rows.
' Top: red, transparent, red. Bottom: black, red, black.
Dim As String dib = MKL(40) & MKL(3) & MKL(4) & MKShort(1) & MKShort(4) & _
    MKL(0) & MKL(16) & MKL(0) & MKL(0) & MKL(2) & MKL(0) & _
    Chr(0, 0, 0, 0, 0, 0, 255, 0) & Chr(&h01, 0, 0, 0, &h10, &h10, 0, 0) & _
    Chr(0, 0, 0, 0, &h40, 0, 0, 0)
Dim As String payload = Chr(0, 0, 1, 0, 1, 0, 3, 2, 2, 0, 0, 0, 0, 0) & MKL(Len(dib)) & MKL(22) & dib
Dim As String errorText, damaged
Dim As RasterImage Ptr imageValue
backend_Init 80, 60, BACKEND_HEADLESS
requireValue(rasterIco_LoadMemory(payload, imageValue, errorText), errorText)
requireValue(imageValue->width = 3 AndAlso imageValue->height = 2, "directory dimensions")
requireValue(imageValue->hasAlpha AndAlso imageValue->formatKind = RASTERIMAGE_FORMAT_ICO, "icon metadata")
requireValue(pixelValue(imageValue, 0, 0) = &hFFFF0000UL, "top row red")
requireValue(pixelValue(imageValue, 1, 0) = 0, "transparent AND mask")
requireValue(pixelValue(imageValue, 0, 1) = &hFF000000UL, "bottom row black is opaque")
requireValue(pixelValue(imageValue, 1, 1) = &hFFFF0000UL, "padded bottom row")

backend_Exit
ScreenControl FB.SET_DRIVER_NAME, "null"
backend_Init 80, 60, 0
gui_Init
Dim As Any Ptr alphaStrip = backend_CreateImage(4, 1, 0, 32)
requireValue(alphaStrip <> 0, "alpha comparison buffer")
PSet alphaStrip, (0, 0), RGBA(200, 30, 60, 0)
PSet alphaStrip, (1, 0), RGBA(200, 30, 60, 1)
PSet alphaStrip, (2, 0), RGBA(200, 30, 60, 128)
PSet alphaStrip, (3, 0), RGBA(200, 30, 60, 255)
backend_Clear RGB(50, 100, 150)
backend_DrawImage 0, 0, alphaStrip, -1, -1
Put (0, 1), alphaStrip, Alpha
requireValue((CULng(Point(0, 0)) And &hFFFFFFUL) = &h326496UL, "zero alpha preserves destination exactly")
For columnIndex As Integer = 1 To 3
    requireValue(Point(columnIndex, 0) = Point(columnIndex, 1), "nonzero alpha retains gfxlib interpolation")
Next columnIndex
ImageDestroy alphaStrip
Dim As Widget Ptr surface = picturebox_Create("image", "", 10, 10, 5, 4, PICTUREBOX_BORDER_SINGLE)
gui_AddWidget surface
requireValue(picturebox_SetImage(surface, imageValue), "retain image")
rasterimage_Destroy imageValue
imageValue = 0
picturebox_SetBackgroundColor surface, RGB(0, 255, 0)
backend_Clear RGB(0, 0, 255)
gui_RenderAll
requireValue((CULng(Point(11, 11)) And &hFFFFFFUL) = &hFF0000UL, "owned image survives source release")
requireValue((CULng(Point(12, 11)) And &hFFFFFFUL) = &h00FF00UL, "transparent pixel shows background: " & Hex(CULng(Point(12, 11))))
requireValue((CULng(Point(15, 11)) And &hFFFFFFUL) = &h0000FFUL, "image clipped to client")
picturebox_SetBackgroundColor surface, RGB(255, 255, 0)
gui_RenderAll
requireValue((CULng(Point(12, 11)) And &hFFFFFFUL) = &hFFFF00UL, "alpha reacts to live background")
surface->w = 4
gui_RenderAll
requireValue((CULng(Point(13, 11)) And &hFFFFFFUL) = (theme_GetColor(GUI_COLOR_BORDER) And &hFFFFFFUL), "resize clips image before border")
surface->w = 5
Dim As RasterImage invalidImage
requireValue(picturebox_SetImage(surface, @invalidImage) = 0, "invalid replacement rejected")
gui_RenderAll
requireValue((CULng(Point(11, 11)) And &hFFFFFFUL) = &hFF0000UL, "failed replacement preserves image")
requireValue(picturebox_SetPixelCanvas(surface, 3, 2), "independent drawing surface")
requireValue(picturebox_SetPixel(surface, 0, 0, RGB(0, 255, 255)), "draw over image")
gui_RenderAll
requireValue((CULng(Point(11, 11)) And &hFFFFFFUL) = &h00FFFFUL, "drawing overlays image")
picturebox_ClearPixels surface
gui_RenderAll
requireValue((CULng(Point(11, 11)) And &hFFFFFFUL) = &hFF0000UL, "clearing drawings preserves image")
requireValue(picturebox_SetImage(surface, 0), "clear image")
gui_RenderAll
requireValue((CULng(Point(11, 11)) And &hFFFFFFUL) = &hFFFF00UL, "cleared image shows background")
gui_ResetForTest
backend_Exit
Screen 0

backend_Init 80, 60, BACKEND_HEADLESS
For depthIndex As Integer = 0 To 2
    Dim As Integer bitDepth = IIf(depthIndex = 0, 1, IIf(depthIndex = 1, 8, 24))
    Dim As String colors = Chr(0, 0, 0, 0, 0, 0, 255, 0)
    Dim As String colorRow = IIf(bitDepth = 1, Chr(128, 0, 0, 0), Chr(1, 0, 0, 0))
    If bitDepth = 24 Then colors = "": colorRow = Chr(0, 0, 255, 0)
    Dim As String oneDib = MKL(40) & MKL(1) & MKL(2) & MKShort(1) & MKShort(bitDepth) & _
        MKL(0) & MKL(8) & MKL(0) & MKL(0) & MKL(IIf(bitDepth = 24, 0, 2)) & MKL(0) & _
        colors & colorRow & Chr(0, 0, 0, 0)
    Dim As String oneIcon = Chr(0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0) & MKL(Len(oneDib)) & MKL(22) & oneDib
    requireValue(rasterIco_LoadMemory(oneIcon, imageValue, errorText), "supported indexed/true-color depth: " & errorText)
    requireValue(pixelValue(imageValue, 0, 0) = &hFFFF0000UL, "supported depth red pixel")
    rasterimage_Destroy imageValue
    imageValue = 0
Next depthIndex
For byteCount As Integer = 1 To Len(payload) - 1
    damaged = Left(payload, byteCount)
    requireValue(rasterIco_LoadMemory(damaged, imageValue, errorText) = 0 AndAlso imageValue = 0 AndAlso Len(errorText) > 0, "every truncated prefix rejected")
Next byteCount
For damageKind As Integer = 0 To 7
    damaged = payload
    Select Case damageKind
    Case 0: Mid(damaged, 19, 4) = MKL(&hFFFFFFFFUL)
    Case 1: Mid(damaged, 15, 4) = MKL(&hFFFFFFFFUL)
    Case 2: Mid(damaged, 5, 2) = MKShort(2)
    Case 3: Mid(damaged, 27, 4) = MKL(4)
    Case 4: Mid(damaged, 39, 4) = MKL(1)
    Case 5: Mid(damaged, 79, 1) = Chr(&hC0) ' AND=1 over red requires XOR compositing.
    Case 6: Mid(damaged, 71, 1) = Chr(&h20) ' Palette index two is unavailable.
    Case 7: Mid(damaged, 37, 2) = MKShort(32)
    End Select
    requireValue(rasterIco_LoadMemory(damaged, imageValue, errorText) = 0 AndAlso imageValue = 0 AndAlso Len(errorText) > 0, "malformed or unsupported icon rejected")
    If damageKind = 5 Then requireValue(InStr(errorText, "XOR pixels") > 0, "explicit XOR limitation")
    If damageKind = 6 Then requireValue(InStr(errorText, "outside its palette") > 0, "explicit palette bound")
Next damageKind
Dim As UByte tooSmall(0 To 0)
requireValue(rasterimage_LoadMemory(tooSmall(), 100, imageValue, errorText) = 0, "claimed count cannot exceed array")
backend_Exit
Print "ICO decoding and PictureBox image ownership: PASS"
End 0
/' end of raster_ico_smoke.bas '/
