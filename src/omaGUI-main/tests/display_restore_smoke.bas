/'
    Project: omaGUI Tests
    File: display_restore_smoke.bas
    Purpose: Verify display restoration after direct gfxlib use.
    Responsibilities: Check modes, pages, clipping, theme, widgets, and input.
    This file intentionally does NOT contain VBDOS form or sample algorithms.
'/
#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub restore_Require(ByVal success As Integer, ByVal source_line As Integer)
    If success Then Exit Sub
    Screen 0
    Print "display_restore_smoke: FAIL at line "; source_line
    End 1
End Sub

Dim As BackendDisplayState saved_display, rejected_display
restore_Require backend_CaptureDisplay(saved_display) = 0, __LINE__
backend_Init 320, 200, BACKEND_DISPLAY_ENABLED
gui_Init
input_ResetForTest
Dim As Widget Ptr retained_widget = textbox_Create("retained", "kept", 10, 10, 100, 30, 0, 0)
restore_Require retained_widget <> 0, __LINE__
gui_AddWidget retained_widget
gui_SetFocus retained_widget
current_theme.text_main = RGB(23, 45, 67)
restore_Require backend_CaptureDisplay(saved_display), __LINE__
restore_Require saved_display.width = 320 AndAlso saved_display.height = 200 AndAlso _
    saved_display.color_depth = 32 AndAlso saved_display.headless = 0, __LINE__
For cycle_index As Integer = 1 To 3
    Screen 2
    Dim As Integer legacy_width, legacy_height, legacy_depth
    ScreenInfo legacy_width, legacy_height, legacy_depth
    restore_Require legacy_width = 640 AndAlso legacy_height = 200 AndAlso legacy_depth = 1, __LINE__
    View (10, 10)-(100, 100), 0, 1
    PSet (1, 1), 1
    restore_Require Point(1, 1) = 1, __LINE__
    restore_Require backend_RestoreDisplay(saved_display), __LINE__
    Dim As Integer restored_width, restored_height, restored_depth
    ScreenInfo restored_width, restored_height, restored_depth
    restore_Require restored_width = 320 AndAlso restored_height = 200 AndAlso restored_depth = 32, __LINE__
    restore_Require current_theme.text_main = RGB(23, 45, 67), __LINE__
    restore_Require gui_FindWidget("retained") = retained_widget AndAlso gui_GetFocus() = retained_widget, __LINE__
    restore_Require Cast(TextBoxData Ptr, retained_widget->data)->text = "kept", __LINE__
    backend_Clear RGB(0, 0, 0)
    backend_Rect 0, 0, 2, 2, RGB(11, 22, 33), -1
    restore_Require (Point(0, 0) And &hFFFFFF) = (RGB(11, 22, 33) And &hFFFFFF), __LINE__
    backend_Flip
    backend_Clear RGB(44, 55, 66)
    restore_Require (Point(0, 0) And &hFFFFFF) = (RGB(44, 55, 66) And &hFFFFFF), __LINE__
    ScreenSet 1, 0
    restore_Require (Point(0, 0) And &hFFFFFF) = (RGB(11, 22, 33) And &hFFFFFF), __LINE__
Next cycle_index

' Invalid descriptions must leave the active display and its pixels alone.
rejected_display = saved_display
rejected_display.height = 0
restore_Require backend_RestoreDisplay(rejected_display) = 0, __LINE__
rejected_display = saved_display
rejected_display.width = 16777217
restore_Require backend_RestoreDisplay(rejected_display) = 0, __LINE__
rejected_display = saved_display
rejected_display.color_depth = 3
restore_Require backend_RestoreDisplay(rejected_display) = 0, __LINE__
rejected_display = saved_display
rejected_display.headless = 1
restore_Require backend_RestoreDisplay(rejected_display) = 0, __LINE__
rejected_display = saved_display
rejected_display.window_flags = 4
restore_Require backend_RestoreDisplay(rejected_display) = 0, __LINE__
restore_Require (Point(0, 0) And &hFFFFFF) = (RGB(11, 22, 33) And &hFFFFFF), __LINE__

input_MockMouse 12, 13, 1, 4
input_MockKey KEY_RETURN, -1
input_MockKeyPress KEY_ESCAPE
input_MockText "stale"
input_Update
input_ResumeAfterScreenChange
input_MockText "repeat"
input_Update
restore_Require input_MouseButtons() = 0 AndAlso input_MouseWheel() = 0, __LINE__
restore_Require input_KeyPressed(KEY_RETURN) = 0 AndAlso input_KeyPressEvent(KEY_RETURN) = 0, __LINE__
restore_Require input_KeyPressEvent(KEY_ESCAPE) = 0 AndAlso Len(input_PollTextInput()) = 0, __LINE__
input_MockMouse 12, 13, 0
input_MockKey KEY_RETURN, 0
input_Update
input_MockMouse 12, 13, 1
input_MockKey KEY_RETURN, -1
input_MockText "new"
input_Update
restore_Require input_MouseButtons() = 1 AndAlso input_KeyPressEvent(KEY_RETURN), __LINE__
restore_Require input_PollTextInput() = "new", __LINE__

gui_ResetForTest
backend_Exit
backend_Init 800, 500, BACKEND_HEADLESS
restore_Require backend_CaptureDisplay(saved_display), __LINE__
Screen 2
restore_Require backend_RestoreDisplay(saved_display), __LINE__
restore_Require ScreenPtr = 0, __LINE__
Dim As Integer logical_width, logical_height
backend_GetSize logical_width, logical_height
restore_Require logical_width = 800 AndAlso logical_height = 500, __LINE__
backend_Exit
Print "display_restore_smoke: PASS (native modes/pages, clipping, widgets/theme, held input, headless, guards)"
End 0
/' end of display_restore_smoke.bas '/
