/'
    Project: omaGUI Tests
    ---------------------

    File: combobox_editable_smoke.bas

    Purpose:

        Verify the portable editable ComboBox contract used by VBDOS Style 0
        forms without relying on a host-native edit control.

    Responsibilities:

        - check programmatic editable Text and exact ListIndex matching
        - check typed text, cursor editing, and Change notifications
        - check arrow-opened list selection restores the selected row text
        - reject multiline programmatic text without changing state

    This file intentionally does NOT contain:

        - desktop-window interaction
        - autocomplete policy tests
        - VBDOS runtime code
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim Shared As Integer combo_change_count

Private Sub comboEditable_OnChange(ByVal source_widget As Widget Ptr)
    If source_widget <> 0 Then combo_change_count += 1
End Sub


Private Sub comboEditable_Require( _
    ByVal condition_value As Integer, _
    ByVal line_number As Integer, _
    ByRef failure_count As Integer _
)
    If condition_value Then Exit Sub
    Print "combobox_editable_smoke: failed line "; line_number
    failure_count += 1
End Sub


Dim As Widget Ptr combo_widget
Dim As Integer failure_count

backend_Init 320, 240, BACKEND_HEADLESS
gui_Init
combo_widget = combobox_Create( _
    "combo_editable", 10, 10, 150, 24, 3, @comboEditable_OnChange _
)
comboEditable_Require combo_widget <> 0, __LINE__, failure_count
If combo_widget <> 0 Then
    gui_AddWidget combo_widget
    comboEditable_Require combobox_AddItem(combo_widget, "Alpha"), _
        __LINE__, failure_count
    comboEditable_Require combobox_AddItem(combo_widget, "Beta"), _
        __LINE__, failure_count
    comboEditable_Require combobox_SetEditable(combo_widget, -1), _
        __LINE__, failure_count
    comboEditable_Require combobox_IsEditable(combo_widget), __LINE__, failure_count
    comboEditable_Require combobox_SetText(combo_widget, "Alpha"), _
        __LINE__, failure_count
    comboEditable_Require combobox_GetText(combo_widget) = "Alpha" AndAlso _
        combobox_GetSelectedIndex(combo_widget) = 0 AndAlso _
        combo_change_count = 0, __LINE__, failure_count

    gui_SetFocus combo_widget
    input_MockText "!"
    gui_UpdateAll
    comboEditable_Require combobox_GetText(combo_widget) = "Alpha!" AndAlso _
        combobox_GetSelectedIndex(combo_widget) = -1 AndAlso _
        combo_change_count = 1, __LINE__, failure_count

    input_MockKeyPress KEY_BACKSPACE
    gui_UpdateAll
    comboEditable_Require combobox_GetText(combo_widget) = "Alpha" AndAlso _
        combobox_GetSelectedIndex(combo_widget) = 0 AndAlso _
        combo_change_count = 2, __LINE__, failure_count

    input_MockKeyPress KEY_LEFT
    gui_UpdateAll
    input_MockText "Z"
    gui_UpdateAll
    comboEditable_Require combobox_GetText(combo_widget) = "AlphZa" AndAlso _
        combobox_GetSelectedIndex(combo_widget) = -1 AndAlso _
        combo_change_count = 3, __LINE__, failure_count

    comboEditable_Require combobox_SetText(combo_widget, "Beta"), _
        __LINE__, failure_count
    comboEditable_Require combobox_GetText(combo_widget) = "Beta" AndAlso _
        combobox_GetSelectedIndex(combo_widget) = 1 AndAlso _
        combo_change_count = 3, __LINE__, failure_count
    comboEditable_Require combobox_SetText(combo_widget, "Bad" & Chr(13)) = 0 _
        AndAlso combobox_GetText(combo_widget) = "Beta", __LINE__, failure_count

    input_MockMouse 150, 20, 1
    gui_UpdateAll
    input_MockMouse 150, 20, 0
    gui_UpdateAll
    comboEditable_Require combobox_IsOpen(combo_widget), __LINE__, failure_count
    input_MockMouse 30, 43, 1
    gui_UpdateAll
    input_MockMouse 30, 43, 0
    gui_UpdateAll
    comboEditable_Require combobox_IsOpen(combo_widget) = 0 AndAlso _
        combobox_GetText(combo_widget) = "Alpha" AndAlso _
        combobox_GetSelectedIndex(combo_widget) = 0 AndAlso _
        combo_change_count = 4, __LINE__, failure_count
End If

gui_ResetForTest
backend_Exit

If failure_count <> 0 Then
    Print "combobox_editable_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "combobox_editable_smoke: PASS"
End 0

/' end of combobox_editable_smoke.bas '/
