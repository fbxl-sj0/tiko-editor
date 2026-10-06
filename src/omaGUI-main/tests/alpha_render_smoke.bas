/'
    Project: omaGUI Test Suite
    --------------------------

    File: alpha_render_smoke.bas

    Purpose:

        Verify true-color alpha compositing used by the feature demo.

    Responsibilities:

        - prove per-pixel alpha blends source and destination color channels
        - prove imported graphic object alpha reaches its filled geometry
        - prove normal and scaled embedded text reaches the alpha renderer
        - prove fully transparent pixels preserve the destination

    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:

        - indexed-color alpha expectations
        - screenshot comparison
        - interactive control tests
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"

Private Sub alphaRender_Fail( _
    ByVal messageText As String, ByVal exitCode As Integer _
)
    backend_Exit
    Print "alpha render smoke failed: " & messageText
    End exitCode
End Sub


Private Function alphaRender_Channel( _
    ByVal pixelValue As ULong, ByVal shiftValue As Integer _
) As Integer
    Return (pixelValue Shr shiftValue) And &HFF
End Function


Private Function alphaRender_ChangedPixels( _
    ByVal x1 As Integer, ByVal y1 As Integer, _
    ByVal x2 As Integer, ByVal y2 As Integer, _
    ByRef maximumRed As Integer _
) As Integer
    Dim As Integer changedPixels
    Dim As Integer redValue
    Dim As ULong sampleValue

    maximumRed = 0

    For sampleY As Integer = y1 To y2
        For sampleX As Integer = x1 To x2
            sampleValue = Point(sampleX, sampleY)
            redValue = alphaRender_Channel(sampleValue, 16)

            If sampleValue <> RGB(0, 0, 0) Then changedPixels += 1
            If redValue > maximumRed Then maximumRed = redValue
        Next sampleX
    Next sampleY

    Return changedPixels
End Function


Dim As ULong pixelValue
Dim As GraphicShapeRenderOptions shapeOptions
Dim As Integer unusedPointX(1 To GRAPHICSHAPE_MAX_POINTS)
Dim As Integer unusedPointY(1 To GRAPHICSHAPE_MAX_POINTS)
Dim As Integer changedPixels
Dim As Integer maximumRed

backend_Init 96, 72, 0, BACKEND_WINDOW_FIXED, _
    BACKEND_COLOR_DEPTH_TRUE_COLOR
backend_Clear RGB(0, 0, 0)

backend_PSetAlpha 10, 10, RGB(255, 128, 0), 128
pixelValue = Point(10, 10)

If alphaRender_Channel(pixelValue, 16) <> 128 OrElse _
   alphaRender_Channel(pixelValue, 8) <> 64 OrElse _
   alphaRender_Channel(pixelValue, 0) <> 0 Then
    alphaRender_Fail "per-pixel 50 percent blend was wrong", 1
End If

backend_PSetAlpha 11, 10, RGB(255, 255, 255), 0
If Point(11, 10) <> RGB(0, 0, 0) Then
    alphaRender_Fail "zero alpha changed its destination pixel", 2
End If

graphicshape_DefaultOptions shapeOptions, GUI_SHAPE_RECTANGLE
shapeOptions.stroke_clr = RGB(0, 0, 0)
shapeOptions.fill_clr = RGB(0, 128, 255)
shapeOptions.fill_gradient_clr = shapeOptions.fill_clr
shapeOptions.filled = -1
shapeOptions.fill_mode = GUI_FILL_SOLID
shapeOptions.line_width = 0
shapeOptions.object_alpha = 128
shapeOptions.fill_alpha = 255

graphicshape_RenderWithOptions _
    20, 20, 12, 12, shapeOptions, "", 0, _
    unusedPointX(), unusedPointY()
pixelValue = Point(25, 25)

If alphaRender_Channel(pixelValue, 16) <> 0 OrElse _
   alphaRender_Channel(pixelValue, 8) <> 64 OrElse _
   alphaRender_Channel(pixelValue, 0) <> 128 Then
    alphaRender_Fail "graphic object alpha did not blend its fill", 3
End If

backend_PrintFontAlpha _
    40, 4, RGB(255, 255, 255), "HART", _
    BACKEND_FONT_LIBERATION_SANS_18_BOLD, 128
changedPixels = alphaRender_ChangedPixels(40, 4, 95, 30, maximumRed)

If changedPixels = 0 OrElse maximumRed < 127 OrElse maximumRed > 129 Then
    alphaRender_Fail "alpha font rendering did not reach the framebuffer", 4
End If

backend_PrintScaledFontAlpha _
    40, 36, RGB(255, 255, 255), "A", BACKEND_FONT_DEFAULT, 2, 2, 192
changedPixels = alphaRender_ChangedPixels(40, 36, 70, 71, maximumRed)

If changedPixels = 0 OrElse maximumRed < 191 OrElse maximumRed > 193 Then
    alphaRender_Fail "scaled alpha font rendering was wrong", 5
End If

backend_Exit
Print "alpha render smoke OK"
End 0

/' end of alpha_render_smoke.bas '/
