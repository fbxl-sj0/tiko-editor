/'
    Project: omaGUI Tests
    File: list_item_state_smoke.bas
    Purpose: Verify row identity, replacement and checked scroll operations.
    Responsibilities: test both list providers through their public APIs,
        including portable 64-bit values, aliasing and failed mutations.
    This file intentionally does NOT contain: VB runtime or operating-system APIs.
'/
#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Type ItemApi
    insert_row As Function(ByVal As Widget Ptr, ByRef As Const String, ByVal As Integer) As Integer
    remove_row As Function(ByVal As Widget Ptr, ByVal As Integer) As Integer
    set_text As Function(ByVal As Widget Ptr, ByVal As Integer, ByRef As Const String) As Integer
    get_text As Function(ByVal As Widget Ptr, ByVal As Integer, ByRef As String) As Integer
    set_data As Function(ByVal As Widget Ptr, ByVal As Integer, ByVal As LongInt) As Integer
    get_data As Function(ByVal As Widget Ptr, ByVal As Integer, ByRef As LongInt) As Integer
    select_row As Function(ByVal As Widget Ptr, ByVal As Integer) As Integer
    selection As Function(ByVal As Widget Ptr) As Integer
    clear_rows As Sub(ByVal As Widget Ptr)
End Type
Dim Shared As Integer checks
Private Sub Require(ByVal accepted As Integer, ByVal source_line As Integer)
    checks += 1
    If accepted Then Exit Sub
    gui_ResetForTest()
    backend_Exit()
    Screen 0
    Print "list_item_state_smoke: FAIL at line "; source_line
    End 1
End Sub

Const LOW_TAG As LongInt = -9223372036854775807ll - 1
Const HIGH_TAG As LongInt = 9223372036854775807ll
backend_Init 320, 240, -1
gui_Init()
For provider As Integer = 0 To 1
    Dim As ItemApi api
    Dim As Widget Ptr owner
    Dim As Integer capacity, text_limit
    If provider = 0 Then
        owner = listbox_Create("rows", 10, 10, 180, 64)
        api = Type<ItemApi>(@listbox_InsertItem, @listbox_RemoveItem, @listbox_SetItem, @listbox_GetItem, _
            @listbox_SetItemData, @listbox_GetItemData, @listbox_SetSelectedIndex, @listbox_GetSelectedIndex, @listbox_Clear)
        capacity = LISTBOX_MAX_ITEMS
        text_limit = LISTBOX_MAX_TEXT_BYTES
    Else
        owner = combobox_Create("rows", 10, 10, 180, 24, 2)
        api = Type<ItemApi>(@combobox_InsertItem, @combobox_RemoveItem, @combobox_SetItem, @combobox_GetItem, _
            @combobox_SetItemData, @combobox_GetItemData, @combobox_SetSelectedIndex, @combobox_GetSelectedIndex, @combobox_Clear)
        capacity = COMBOBOX_MAX_ITEMS
        text_limit = COMBOBOX_MAX_TEXT_BYTES
    End If
    Require(owner <> 0, __LINE__)
    gui_AddWidget owner
    Dim As LongInt data_value = 123
    Dim As String text_value
    Dim As Widget empty_widget
    Require(api.get_data(0, 0, data_value) = 0 AndAlso data_value = 0, __LINE__)
    Require(api.set_data(@empty_widget, 0, 12) = 0, __LINE__)
    Require(api.get_data(owner, 0, data_value) = 0, __LINE__)
    Require(api.set_text(owner, 0, "absent") = 0, __LINE__)
    Require(api.insert_row(owner, "alpha", -1), __LINE__)
    Require(api.insert_row(owner, "gamma", -1), __LINE__)
    Require(api.set_data(owner, 0, LOW_TAG), __LINE__)
    Require(api.set_data(owner, 1, HIGH_TAG), __LINE__)
    Require(api.select_row(owner, 1), __LINE__)
    Require(api.insert_row(owner, "beta", 1), __LINE__)
    Require(api.selection(owner) = 2, __LINE__)
    Require(api.get_data(owner, 2, data_value) AndAlso data_value = HIGH_TAG, __LINE__)
    Require(api.get_data(owner, 1, data_value) AndAlso data_value = 0, __LINE__)
    Require(api.get_data(owner, 0, data_value) AndAlso data_value = LOW_TAG, __LINE__)

    ' The retained data is inspected only to supply aliases and an in-flight
    ' gesture. Applications use the checked API instead of editing these fields.
    If provider = 0 Then
        Dim As ListBoxData Ptr state = owner->data
        Require(api.get_data(owner, 2, state->item_data(2)) AndAlso state->item_data(2) = HIGH_TAG, __LINE__)
        state->pointer_latch = -1: state->pointer_index = 2
        state->double_click_armed = -1
        Require(api.set_text(owner, 2, state->items(0)), __LINE__)
        Require(state->pointer_index = -1 AndAlso state->double_click_armed = 0, __LINE__)
        Require(listbox_GetActivationCount(owner) = 0, __LINE__)
    Else
        Dim As ComboBoxData Ptr state = owner->data
        Require(api.get_data(owner, 2, state->item_data(2)) AndAlso state->item_data(2) = HIGH_TAG, __LINE__)
        Require(combobox_SetOpen(owner, -1), __LINE__)
        state->pointer_latch = -1: state->pointer_target = 2
        state->pending_index = 1: state->scroll_top = 1
        Require(api.set_text(owner, 2, state->items(0)), __LINE__)
        Require(state->pointer_target = -1 AndAlso state->is_open AndAlso state->pending_index = 1 AndAlso state->scroll_top = 1, __LINE__)
        Require(combobox_GetActivationCount(owner) = 0 AndAlso combobox_GetDropDownCount(owner) = 0, __LINE__)
    End If
    Require(api.get_text(owner, 2, text_value) AndAlso text_value = "alpha", __LINE__)
    Require(api.get_data(owner, 2, data_value) AndAlso data_value = HIGH_TAG AndAlso api.selection(owner) = 2, __LINE__)
    Require(api.set_data(owner, -1, 99) = 0 AndAlso api.set_data(owner, 3, 99) = 0, __LINE__)
    Require(api.set_text(owner, 3, "bad") = 0, __LINE__)
    Dim As String oversized = String(text_limit, "z")
    Require(api.set_text(owner, 2, oversized) = 0, __LINE__)
    Require(api.get_text(owner, 2, text_value) AndAlso text_value = "alpha", __LINE__)
    Require(api.get_data(owner, 2, data_value) AndAlso data_value = HIGH_TAG AndAlso api.selection(owner) = 2, __LINE__)
    Require(api.remove_row(owner, 1), __LINE__)
    Require(api.get_data(owner, 1, data_value) AndAlso data_value = HIGH_TAG AndAlso api.selection(owner) = 1, __LINE__)
    api.clear_rows(owner)
    Require(api.insert_row(owner, oversized, -1), __LINE__)
    Require(api.set_text(owner, 0, oversized), __LINE__)
    Require(api.insert_row(owner, "x", -1) = 0, __LINE__)
    Require(api.set_text(owner, 0, Left(oversized, text_limit - 1)), __LINE__)
    Require(api.insert_row(owner, "x", -1), __LINE__)
    Require(api.set_data(owner, 1, HIGH_TAG), __LINE__)
    Require(api.set_text(owner, 1, "xx") = 0, __LINE__)
    Require(api.get_text(owner, 1, text_value) AndAlso text_value = "x", __LINE__)
    Require(api.get_data(owner, 1, data_value) AndAlso data_value = HIGH_TAG, __LINE__)
    api.clear_rows(owner)
    For row As Integer = 0 To capacity - 1
        Require(api.insert_row(owner, "row", -1), __LINE__)
        Require(api.get_data(owner, row, data_value) AndAlso data_value = 0, __LINE__)
        Require(api.set_data(owner, row, 5000000000ll + row), __LINE__)
    Next row
    Require(api.insert_row(owner, "full", 0) = 0, __LINE__)
    Require(api.remove_row(owner, 0), __LINE__)
    For row As Integer = 0 To capacity - 2
        Require(api.get_data(owner, row, data_value) AndAlso data_value = 5000000001ll + row, __LINE__)
    Next row
    Require(api.insert_row(owner, "new", 0), __LINE__)
    Require(api.get_data(owner, 0, data_value) AndAlso data_value = 0, __LINE__)
    Require(api.get_data(owner, capacity - 1, data_value) AndAlso data_value = 5000000000ll + capacity - 1, __LINE__)
    If provider = 0 Then
        Require(listbox_SetSelectedIndex(owner, 1), __LINE__)
        Require(listbox_SetTopIndex(owner, capacity - 1), __LINE__)
        Require(listbox_GetTopIndex(owner) = capacity - 4 AndAlso api.selection(owner) = 1, __LINE__)
        Require(listbox_SetTopIndex(owner, capacity) = 0 AndAlso listbox_GetTopIndex(owner) = capacity - 4, __LINE__)
        owner->h = capacity * 16
        Require(listbox_GetTopIndex(owner) = 0, __LINE__)
    End If
    api.clear_rows(owner)
    Require(api.insert_row(owner, "fresh", -1), __LINE__)
    Require(api.get_data(owner, 0, data_value) AndAlso data_value = 0, __LINE__)
    gui_RemoveWidgetPtr owner
Next provider
Require(listbox_GetTopIndex(0) = -1 AndAlso listbox_SetTopIndex(0, 0) = 0, __LINE__)
gui_ResetForTest()
backend_Exit()
Screen 0
Print "list_item_state_smoke: PASS ("; checks; " checks)"
End 0
/' end of list_item_state_smoke.bas '/
