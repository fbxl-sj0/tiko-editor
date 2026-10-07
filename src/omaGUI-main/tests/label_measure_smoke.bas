/'
    Project: omaGUI Tests
    File: label_measure_smoke.bas
    Purpose: Verify measured label dimensions and opt-in fixed borders.
    Responsibilities: Check layout against glyph metrics and independent pixels.
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain: application-specific sizing rules.
'/
#lang "fb"
#define OMAGUI_IMPLEMENTATION
#define OMAGUI_PORTABLE_ONLY
#include once "omaGUI.bi"

Private Sub test_Require(ByVal condition As Integer, ByRef description As Const String)
    If condition Then Exit Sub
    Screen 0
    Print "FAIL "; description
    End 1
End Sub

ScreenControl FB.SET_DRIVER_NAME, "null"
backend_Init 320, 180, 0
gui_Init
Dim As Widget Ptr labelWidget = label_CreateWithColor("measured", "AB", 10, 10, RGB(255, 255, 255))
test_Require(labelWidget <> 0, "label allocation")
gui_AddWidget labelWidget
labelWidget->w = 60: labelWidget->h = 40
label_SetAlignment labelWidget, BACKEND_ALIGN_LEFT
label_SetClipToBounds labelWidget, -1
label_SetBackgroundColor labelWidget, RGB(0, 0, 100)
gui_SynchronizeLayout
Dim As Integer textWidth, textHeight
Dim As Integer glyphWidth = backend_GetTextWidthFont("AB", BACKEND_FONT_DEFAULT)
Dim As Integer fontHeight = backend_GetTextHeightFont(BACKEND_FONT_DEFAULT)
test_Require(label_GetBorderStyle(labelWidget) = 0, "legacy border default")
test_Require(label_GetTextSize(labelWidget, textWidth, textHeight) AndAlso _
    textWidth = glyphWidth AndAlso textHeight = fontHeight, "unwrapped glyph measurements")
test_Require(labelWidget->w = 60 AndAlso labelWidget->h = 40, "measurement never resizes widget")
label_SetBorderStyle labelWidget, 1
test_Require(label_GetTextSize(labelWidget, textWidth, textHeight) AndAlso _
    textWidth = glyphWidth + 4 AndAlso textHeight = fontHeight + 4, "border includes text inset")
test_Require(label_SetBorderStyle(labelWidget, LABEL_BORDER_DOUBLE) <> 0 AndAlso _
    label_GetBorderStyle(labelWidget) = LABEL_BORDER_DOUBLE, "double-line border accepted")
test_Require(label_GetTextSize(labelWidget, textWidth, textHeight) AndAlso _
    textWidth = glyphWidth + 4 AndAlso textHeight = fontHeight + 4, "double-line border keeps a two-pixel inset")
test_Require(label_SetBorderStyle(labelWidget, 3) = 0 AndAlso _
    label_GetBorderStyle(labelWidget) = LABEL_BORDER_DOUBLE, "invalid border preserves state")
Dim As Widget otherWidget
Dim As Integer otherData
otherWidget.data = @otherData
test_Require(label_GetTextSize(@otherWidget, textWidth, textHeight) = 0 AndAlso _
    textWidth = 0 AndAlso textHeight = 0 AndAlso label_SetBorderStyle(@otherWidget, 1) = 0, "wrong type rejected")
test_Require(label_GetTextSize(0, textWidth, textHeight) = 0, "null rejected")
label_SetText labelWidget, "AB" & Chr(13, 10) & "CD"
test_Require(label_GetTextSize(labelWidget, textWidth, textHeight) AndAlso _
    textHeight = 2 * fontHeight + 2 + 4, "explicit paragraphs use renderer line spacing")
label_SetBorderStyle labelWidget, LABEL_BORDER_SINGLE
backend_Clear RGB(0, 0, 0)
label_Render labelWidget
backend_Rect 170, 10, 60, 40, RGB(0, 0, 100), -1
backend_Rect 170, 10, 60, 40, _
    theme_GetClassicColor(GUI_CLASSIC_COLOR_WINDOW_FRAME), 0
backend_PrintFont 172, 12, RGB(255, 255, 255), "AB", BACKEND_FONT_DEFAULT
backend_PrintFont 172, 12 + fontHeight + 2, RGB(255, 255, 255), "CD", BACKEND_FONT_DEFAULT
For y As Integer = 0 To 179
    For x As Integer = 0 To 159
        test_Require(Point(x, y) = Point(x + 160, y), "border and paragraph pixels match independent reference")
Next x
Next y
label_SetBorderStyle labelWidget, LABEL_BORDER_DOUBLE
backend_Clear RGB(0, 0, 0)
label_Render labelWidget
Dim As ULong border_color = _
    theme_GetClassicColor(GUI_CLASSIC_COLOR_WINDOW_FRAME)
test_Require((Point(10, 10) And &hFFFFFF) = (border_color And &hFFFFFF) AndAlso _
    (Point(11, 11) And &hFFFFFF) = (border_color And &hFFFFFF), _
    "double-line border renders both edges")
test_Require((Point(67, 47) And &hFFFFFF) = _
    (RGB(0, 0, 100) And &hFFFFFF), _
    "double-line border retains its client background")
label_SetText labelWidget, "AB AB"
label_SetWordWrap labelWidget, glyphWidth + 4
test_Require(label_GetRenderedLineCount(labelWidget) = 2, "wrapping excludes border insets")
test_Require(label_GetTextSize(labelWidget, textWidth, textHeight) AndAlso _
    textHeight = 2 * fontHeight + 2 + 4, "wrapped measurement uses rendered lines")
labelWidget->w = 4
test_Require(label_GetTextSize(labelWidget, textWidth, textHeight) = 0, "no wrapped client area rejected")
labelWidget->w = 60
label_SetWordWrap labelWidget, 0
labelWidget->w = 60
label_SetText labelWidget, ""
test_Require(label_GetTextSize(labelWidget, textWidth, textHeight) AndAlso _
    textWidth = 4 AndAlso textHeight = fontHeight + 4, "empty label retains one line and border")
gui_ResetForTest
backend_Exit
Screen 0
Print "label_measure_smoke: PASS"

/' end of label_measure_smoke.bas '/
