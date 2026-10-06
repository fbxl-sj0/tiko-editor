/'
    Project: omaGUI Tests
    File: toggle_input_smoke.bas
    Purpose: Verify checked state and captured input for boolean controls.
    Responsibilities:
        - normalize nonzero state and preserve radio group exclusivity
        - distinguish state assignment from actual user activation
        - exercise label clicks, release cancellation, keyboard, and bounds
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:
        - VBDOS value conversion, application events, or platform SDK calls
'/

#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub toggle_Require(ByVal success As Integer, ByVal source_line As Integer)
    If success Then Exit Sub
    Print "toggle_input_smoke: FAIL at line "; source_line
    gui_ResetForTest
    backend_Exit
    End 1
End Sub

backend_Init 400, 220, BACKEND_HEADLESS
gui_Init
input_ResetForTest
Dim As Widget Ptr check_widget = checkbox_Create("check", "Checkbox label", 10, 10, 1)
Dim As Widget Ptr radio_a = radiobox_Create("radio_a", "Radio A", 10, 50, 1, -1)
Dim As Widget Ptr radio_b = radiobox_Create("radio_b", "Radio B", 10, 80, 1, 0)
Dim As Widget Ptr other_radio = radiobox_Create("other", "Other group", 10, 110, 2, -1)
toggle_Require check_widget <> 0 AndAlso radio_a <> 0 AndAlso radio_b <> 0 AndAlso other_radio <> 0, __LINE__
Dim As Widget Ptr controls(0 To 3) = {check_widget, radio_a, radio_b, other_radio}
For item_index As Integer = 0 To UBound(controls)
    controls(item_index)->w = 170
    controls(item_index)->h = 20
    gui_AddWidget controls(item_index)
Next item_index
gui_UpdateAll
toggle_Require checkbox_GetChecked(check_widget) = -1, __LINE__
checkbox_Activate check_widget
toggle_Require checkbox_GetChecked(check_widget) = 0 AndAlso checkbox_GetActivationCount(check_widget) = 1, __LINE__
toggle_Require checkbox_SetChecked(check_widget, 42), __LINE__
toggle_Require checkbox_GetChecked(check_widget) = -1 AndAlso checkbox_GetActivationCount(check_widget) = 1, __LINE__
toggle_Require checkbox_SetValue(check_widget, 2) AndAlso _
    checkbox_GetValue(check_widget) = 2 AndAlso _
    checkbox_GetChecked(check_widget) = 0, __LINE__
checkbox_Activate check_widget
toggle_Require checkbox_GetValue(check_widget) = 1 AndAlso _
    checkbox_GetActivationCount(check_widget) = 2, __LINE__
toggle_Require checkbox_SetValue(check_widget, 3) = 0 AndAlso _
    checkbox_GetValue(check_widget) = 1, __LINE__
input_MockMouse 100, 15, 1
gui_UpdateAll
toggle_Require checkbox_GetChecked(check_widget) = -1, __LINE__
input_MockMouse 100, 15, 0
gui_UpdateAll
toggle_Require checkbox_GetChecked(check_widget) = 0 AndAlso checkbox_GetActivationCount(check_widget) = 3, __LINE__
input_MockMouse 100, 15, 1
gui_UpdateAll
input_MockMouse 350, 180, 0
gui_UpdateAll
toggle_Require checkbox_GetActivationCount(check_widget) = 3, __LINE__
gui_SetFocus check_widget
input_MockKeyPress FB.SC_SPACE
gui_UpdateAll
toggle_Require checkbox_GetChecked(check_widget) = -1 AndAlso checkbox_GetActivationCount(check_widget) = 4, __LINE__
gui_UpdateAll
toggle_Require checkbox_GetActivationCount(check_widget) = 4, __LINE__

input_MockMouse 100, 85, 1
gui_UpdateAll
toggle_Require radiobox_GetSelected(radio_a) = -1 AndAlso radiobox_GetSelected(radio_b) = 0, __LINE__
input_MockMouse 100, 85, 0
gui_UpdateAll
toggle_Require radiobox_GetSelected(radio_a) = 0 AndAlso radiobox_GetSelected(radio_b) = -1, __LINE__
toggle_Require radiobox_GetSelected(other_radio) = -1 AndAlso radiobox_GetActivationCount(radio_b) = 1, __LINE__
toggle_Require radiobox_SetSelected(radio_a, 1), __LINE__
toggle_Require radiobox_GetSelected(radio_b) = 0 AndAlso radiobox_GetActivationCount(radio_a) = 0, __LINE__
toggle_Require radiobox_SetSelected(radio_a, 0) AndAlso radiobox_GetSelected(radio_a) = 0, __LINE__
input_MockMouse 100, 85, 1
gui_UpdateAll
input_MockMouse -2147483647, -2147483647, 0
gui_UpdateAll
toggle_Require radiobox_GetActivationCount(radio_b) = 1, __LINE__
radio_b->enabled = 0
input_MockMouse 100, 85, 1
gui_UpdateAll
input_MockMouse 100, 85, 0
gui_UpdateAll
toggle_Require radiobox_GetActivationCount(radio_b) = 1, __LINE__
toggle_Require checkbox_SetChecked(0, 1) = 0 AndAlso radiobox_SetSelected(0, 1) = 0, __LINE__
toggle_Require checkbox_GetActivationCount(0) = 0 AndAlso radiobox_GetSelected(0) = 0, __LINE__
gui_ResetForTest
backend_Exit
Print "toggle_input_smoke: PASS (normalization, labels, capture, keyboard, groups, activation counts)"
End 0

/' end of toggle_input_smoke.bas '/
