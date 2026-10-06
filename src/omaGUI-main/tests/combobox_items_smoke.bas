/'
    Project: omaGUI Tests
    File: combobox_items_smoke.bas
    Purpose: Verify checked drop-down item operations and callback lifetime.
    Responsibilities:
        - retain selected item identity and protect aliased insertion text
        - bound text storage and indexes without partial mutations
        - distinguish user-open, activation, and programmatic state changes
        - finish internal state before callbacks which release widget data
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:
        - filesystem enumeration or VBDOS event handlers
'/
#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub combo_Require(ByVal success As Integer, ByVal source_line As Integer)
    If success Then Exit Sub
    Print "combobox_items_smoke: FAIL at line "; source_line
    End 1
End Sub

Private Sub combo_ReleaseData(ByVal source_widget As Widget Ptr)
    ' The registry retains the Widget allocation. The callback deliberately
    ' releases its private data; update must not touch that allocation again.
    combobox_Destroy source_widget
End Sub

backend_Init 320, 240, -1
gui_Init
input_ResetForTest
Dim As Widget Ptr combo_widget = combobox_Create("combo_items", 10, 10, 180, 24, 4)
combo_Require combo_widget <> 0, __LINE__
gui_AddWidget combo_widget
Dim As ComboBoxData Ptr combo_data = combo_widget->data
Dim As String item_text
combo_Require combobox_InsertItem(combo_widget, "A"), __LINE__
combo_Require combobox_InsertItem(combo_widget, "C"), __LINE__
combo_Require combobox_SetSelectedIndex(combo_widget, 1), __LINE__
combo_Require combobox_InsertItem(combo_widget, "B", 1), __LINE__
combo_Require combobox_GetSelectedIndex(combo_widget) = 2 AndAlso combobox_GetSelectedItem(combo_widget) = "C", __LINE__
combo_Require combobox_InsertItem(combo_widget, combo_data->items(2), 0), __LINE__
combo_Require combobox_GetItem(combo_widget, 0, item_text) AndAlso item_text = "C", __LINE__
combo_Require combobox_GetItem(combo_widget, 0, combo_data->items(0)), __LINE__
combo_Require combo_data->items(0) = "C", __LINE__
combo_Require combobox_RemoveItem(combo_widget, 0), __LINE__
combo_Require combobox_GetSelectedIndex(combo_widget) = 2, __LINE__
combo_Require combobox_RemoveItem(combo_widget, 2), __LINE__
combo_Require combobox_GetSelectedIndex(combo_widget) = -1 AndAlso combobox_GetItemCount(combo_widget) = 2, __LINE__
combo_Require combobox_RemoveItem(combo_widget, -1) = 0 AndAlso combobox_InsertItem(combo_widget, "bad", 4) = 0, __LINE__
combo_Require combobox_GetItem(combo_widget, 4, item_text) = 0 AndAlso Len(item_text) = 0, __LINE__
combo_Require combobox_SetSelectedIndex(combo_widget, 0), __LINE__
combo_Require combobox_SetOpen(combo_widget, -1), __LINE__
input_MockMouse 20, 40, 1
gui_UpdateAll
combo_Require combobox_InsertItem(combo_widget, "moved", 0), __LINE__
combo_Require combobox_IsOpen(combo_widget) = 0, __LINE__
input_MockMouse 20, 40, 0
gui_UpdateAll
combo_Require combobox_GetActivationCount(combo_widget) = 0 AndAlso combobox_GetSelectedIndex(combo_widget) = 1, __LINE__

' Committing the selected row is one activation, not a value change.
gui_SetFocus combo_widget
combo_Require combobox_SetOpen(combo_widget, -1), __LINE__
input_MockKeyPress KEY_RETURN
gui_UpdateAll
    combo_Require combobox_GetActivationCount(combo_widget) = 1 AndAlso _
        combobox_GetDropDownCount(combo_widget) = 0 AndAlso _
        combo_data->change_count = 0, __LINE__
    input_MockKeyPress KEY_RETURN
    gui_UpdateAll
    combo_Require combobox_IsOpen(combo_widget) AndAlso _
        combobox_GetDropDownCount(combo_widget) = 1, __LINE__
    gui_CancelInput combo_widget
    combo_Require combobox_SetOpen(combo_widget, -1), __LINE__
    gui_CancelInput combo_widget
    combo_Require combobox_IsOpen(combo_widget) = 0 AndAlso _
        combo_widget->pointer_global = 0 AndAlso _
        combobox_GetDropDownCount(combo_widget) = 1, __LINE__
combobox_Clear combo_widget
For item_index As Integer = 0 To COMBOBOX_MAX_ITEMS - 1
    combo_Require combobox_AddItem(combo_widget, Str(item_index)), __LINE__
Next item_index
combo_Require combobox_InsertItem(combo_widget, "overflow") = 0 AndAlso combobox_GetItemCount(combo_widget) = COMBOBOX_MAX_ITEMS, __LINE__
combobox_Clear combo_widget
item_text = String(COMBOBOX_MAX_TEXT_BYTES, "x")
combo_Require combobox_AddItem(combo_widget, item_text), __LINE__
combo_Require combobox_AddItem(combo_widget, "x") = 0 AndAlso combobox_GetItemCount(combo_widget) = 1, __LINE__
combobox_Clear combo_widget
item_text &= "x"
combo_Require combobox_AddItem(combo_widget, item_text) = 0, __LINE__
    combo_Require combobox_GetItemCount(0) = 0 AndAlso _
        combobox_GetActivationCount(0) = 0 AndAlso _
        combobox_GetDropDownCount(0) = 0, __LINE__
combo_Require combobox_InsertItem(0, "null") = 0 AndAlso combobox_RemoveItem(0, 0) = 0, __LINE__
combo_Require combobox_GetItem(0, 0, item_text) = 0 AndAlso Len(item_text) = 0, __LINE__
combobox_CancelInput 0

' Exercise both callback paths which formerly closed the popup after notifying.
For input_method As Integer = 0 To 1
    Dim As Widget Ptr callback_widget = combobox_Create("callback_combo", 10, 80, 180, 24, 4, @combo_ReleaseData)
    combo_Require callback_widget <> 0, __LINE__
    gui_AddWidget callback_widget
    combo_Require combobox_AddItem(callback_widget, "release data"), __LINE__
    gui_SetFocus callback_widget
    combo_Require combobox_SetOpen(callback_widget, -1), __LINE__
    If input_method = 0 Then
        input_MockKeyPress KEY_RETURN
        gui_UpdateAll
    Else
        input_MockMouse 20, 110, 1
        gui_UpdateAll
        input_MockMouse 20, 110, 0
        gui_UpdateAll
    End If
    combo_Require callback_widget->data = 0, __LINE__
    gui_RemoveWidget "callback_combo"
Next input_method
gui_ResetForTest
backend_Exit
Print "combobox_items_smoke: PASS (bounds, aliases, selection, cancellation, callback lifetime)"
End 0
/' end of combobox_items_smoke.bas '/
