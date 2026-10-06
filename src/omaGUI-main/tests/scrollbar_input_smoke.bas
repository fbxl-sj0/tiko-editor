/'
    Project: omaGUI Tests
    File: scrollbar_input_smoke.bas
    Purpose: Verify scrollbar pointer capture and numeric boundary behavior.
    Responsibilities:
        - preserve exact values when pressing a quantized thumb
        - drag beyond the track, restore the grab position, and page on press
        - check optional arrows, reversed direction, and signed 32-bit bounds
    This file intentionally does NOT contain:
        - VBDOS event dispatch or application-specific scrolling
'/

#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub scroll_Require(ByVal success As Integer, ByVal source_line As Integer)
    If success Then Exit Sub
    Print "scrollbar_input_smoke: FAIL at line "; source_line
    End 1
End Sub

Private Sub scroll_Pointer(ByVal x As Integer, ByVal y As Integer, ByVal buttons As Integer)
    input_MockMouse x, y, buttons
    gui_UpdateAll
End Sub

backend_Init 320, 240, -1
gui_Init
input_ResetForTest
Dim As Widget Ptr scroll_widget = scrollbar_Create("pointer_scroll", 10, 10, 240, 20, 32767, 20, 0)
scroll_Require scroll_widget <> 0, __LINE__
gui_AddWidget scroll_widget
scrollbar_SetAutomaticRepeat scroll_widget, 0
gui_SetFocus scroll_widget
scroll_Require scrollbar_SetRange(scroll_widget, -32768, 32767), __LINE__
scroll_Require scrollbar_SetValue(scroll_widget, 123), __LINE__
gui_UpdateAll

' The 12-pixel thumb occupies track offset 114. Grab five pixels inside it;
' mapping that rounded position back to a value would lose the original 123.
scroll_Pointer 129, 15, 1
scroll_Require scrollbar_IsDragging(scroll_widget) AndAlso scrollbar_GetValue(scroll_widget) = 123, __LINE__
gui_UpdateAll
scroll_Require scrollbar_GetValue(scroll_widget) = 123, __LINE__
scroll_Pointer 159, 15, 1
scroll_Require scrollbar_GetValue(scroll_widget) = 8746, __LINE__
scroll_Pointer -2147483647, 15, 1
scroll_Require scrollbar_GetValue(scroll_widget) = -32768, __LINE__
scroll_Pointer 2147483647, 15, 1
scroll_Require scrollbar_GetValue(scroll_widget) = 32767, __LINE__
scroll_Pointer 129, 15, 1
scroll_Require scrollbar_GetValue(scroll_widget) = 123, __LINE__
scroll_Pointer 129, 15, 0
scroll_Require scrollbar_IsDragging(scroll_widget) = 0, __LINE__
scroll_Pointer 11, 15, 1
scroll_Require scrollbar_GetValue(scroll_widget) = 103, __LINE__
gui_UpdateAll
scroll_Require scrollbar_GetValue(scroll_widget) = 103, __LINE__
scroll_Pointer 11, 15, 0

scroll_Require scrollbar_SetRange(scroll_widget, 0, 1000), __LINE__
scroll_Require scrollbar_SetValue(scroll_widget, 500), __LINE__
scroll_Require scrollbar_SetChanges(scroll_widget, 3, 20), __LINE__
scroll_Require scrollbar_SetArrowButtons(scroll_widget, -1), __LINE__
scroll_Pointer 15, 15, 1
scroll_Require scrollbar_GetValue(scroll_widget) = 497, __LINE__
scroll_Pointer 15, 15, 0
scroll_Pointer 245, 15, 1
scroll_Require scrollbar_GetValue(scroll_widget) = 500, __LINE__
scroll_Pointer 245, 15, 0
scroll_Pointer 200, 15, 1
scroll_Require scrollbar_GetValue(scroll_widget) = 520, __LINE__
scroll_Pointer 200, 15, 0

scroll_Require scrollbar_SetReverse(scroll_widget, -1), __LINE__
input_MockKeyPress KEY_RIGHT
gui_UpdateAll
scroll_Require scrollbar_GetValue(scroll_widget) = 517, __LINE__
input_MockKeyPress FB.SC_PAGEDOWN
gui_UpdateAll
scroll_Require scrollbar_GetValue(scroll_widget) = 497, __LINE__
input_MockKeyPress KEY_HOME
gui_UpdateAll
scroll_Require scrollbar_GetValue(scroll_widget) = 1000, __LINE__
input_MockKeyPress KEY_END
gui_UpdateAll
scroll_Require scrollbar_GetValue(scroll_widget) = 0, __LINE__
scroll_Require scrollbar_SetReverse(scroll_widget, 0), __LINE__
scroll_Require scrollbar_SetRange(scroll_widget, -2147483648ll, 2147483647ll), __LINE__
scroll_Require scrollbar_SetChanges(scroll_widget, 2147483647, 2147483647), __LINE__
scrollbar_Render scroll_widget
input_MockKeyPress KEY_RIGHT
gui_UpdateAll
scroll_Require scrollbar_GetValue(scroll_widget) = 2147483647, __LINE__
input_MockKeyPress KEY_RIGHT
gui_UpdateAll
scroll_Require scrollbar_GetValue(scroll_widget) = 2147483647, __LINE__
input_MockMouse 15, 15, 0, 2147483647
gui_UpdateAll
scroll_Require scrollbar_GetValue(scroll_widget) = -2147483648ll, __LINE__
input_MockMouse 15, 15, 0, -2147483647
gui_UpdateAll
scroll_Require scrollbar_GetValue(scroll_widget) = 2147483647, __LINE__
scroll_widget->enabled = 0
scroll_Pointer 15, 15, 1
scroll_Require scrollbar_GetValue(scroll_widget) = 2147483647, __LINE__
scroll_Require scrollbar_SetArrowButtons(0, 1) = 0 AndAlso scrollbar_SetReverse(0, 1) = 0, __LINE__
scroll_Require scrollbar_IsDragging(0) = 0, __LINE__
gui_ResetForTest
backend_Exit
Print "scrollbar_input_smoke: PASS (capture, quantization, arrows, pages, reverse, boundaries)"
End 0

/' end of scrollbar_input_smoke.bas '/
