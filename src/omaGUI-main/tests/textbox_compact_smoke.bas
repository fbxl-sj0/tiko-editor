/'
    Project: omaGUI Tests
    File: textbox_compact_smoke.bas
    Purpose: Verify single-line text remains visible in compact classic controls.
    Responsibilities: Compare 19-pixel editors with glyph output and retain multiline clipping.
    This file intentionally does NOT contain application logic or platform-specific drawing.
'/
#lang "fb"
#define OMAGUI_IMPLEMENTATION
#define OMAGUI_PORTABLE_ONLY
#include once "omaGUI.bi"

Private Sub test_Require(ByVal conditionValue As Integer, ByRef description As Const String)
    If conditionValue Then Exit Sub
    Screen 0
    Print "FAIL "; description
    End 1
End Sub

ScreenControl FB.SET_DRIVER_NAME, "null"
backend_Init 220, 100, 0
test_Require(ScreenPtr <> 0, "null framebuffer")
gui_Init
Dim As Widget Ptr editor = textbox_Create("compact", "5", 10, 10, 80, 19, 0, 0)
test_Require(editor <> 0, "compact editor allocation")
gui_AddWidget editor
test_Require(textbox_SetBackgroundColor(editor, RGB(255, 255, 255)), "editor background")
test_Require(textbox_SetForegroundColor(editor, RGB(0, 0, 255)), "editor foreground")
gui_SynchronizeLayout
backend_Clear RGB(255, 0, 255)
textbox_Render editor
backend_Rect 110, 10, 80, 19, RGB(255, 255, 255), -1
backend_SetClip 112, 12, 76, 15
backend_Print 115, 15, RGB(0, 0, 255), "5"
backend_ResetClip
Dim As Integer bluePixels
For y As Integer = 12 To 26
    For x As Integer = 12 To 87
        test_Require(Point(x, y) = Point(x + 100, y), "compact text matches clipped glyph reference")
        If (CULng(Point(x, y)) And &hFFFFFFUL) = 255 Then bluePixels += 1
    Next x
Next y
test_Require(bluePixels > 0, "compact text actually paints blue glyphs")
test_Require((CULng(Point(9, 15)) And &hFFFFFFUL) = &hFF00FF, "left outer clip")
test_Require((CULng(Point(90, 15)) And &hFFFFFFUL) = &hFF00FF, "right outer clip")

Dim As Widget Ptr multiline = textbox_Create("multiline", "5", 10, 50, 80, 19, -1, 0)
test_Require(multiline <> 0, "multiline allocation")
gui_AddWidget multiline
textbox_SetBackgroundColor multiline, RGB(255, 255, 255)
textbox_SetForegroundColor multiline, RGB(0, 0, 255)
gui_SynchronizeLayout
textbox_Render multiline
For y As Integer = 52 To 66
    For x As Integer = 12 To 87
        test_Require((CULng(Point(x, y)) And &hFFFFFFUL) <> 255, "multiline full-row policy retained")
    Next x
Next y
gui_ResetForTest
backend_Exit
Screen 0
Print "textbox_compact_smoke: PASS"
End 0
/' end of textbox_compact_smoke.bas '/
