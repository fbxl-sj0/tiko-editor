/'
    Project: omaGUI Tests
    File: listbox_items_smoke.bas
    Purpose: Verify checked list mutations used by native VBDOS source.
    Responsibilities:
        - preserve selection identity across insertion and removal
        - reject invalid indices and item/text capacity without partial writes
        - cancel a pending pointer row when list content moves
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:
        - filesystem access or application-specific list behavior
'/

#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub items_Require(ByVal success As Integer, ByVal source_line As Integer)
    If success Then Exit Sub
    Print "listbox_items_smoke: FAIL at line "; source_line
    gui_ResetForTest
    backend_Exit
    End 1
End Sub

backend_Init 320, 200, -1
gui_Init
Dim As Widget Ptr list_widget = listbox_Create("items", 0, 0, 200, 100)
items_Require list_widget <> 0, __LINE__
gui_AddWidget list_widget
Dim As ListBoxData Ptr list_data = list_widget->data
Dim As String item_text
items_Require listbox_InsertItem(list_widget, "a"), __LINE__
items_Require listbox_InsertItem(list_widget, "c"), __LINE__
items_Require listbox_SetSelectedIndex(list_widget, 1), __LINE__
list_data->pointer_latch = -1
list_data->pointer_index = 1
items_Require listbox_InsertItem(list_widget, "b", 1), __LINE__
items_Require listbox_GetSelectedIndex(list_widget) = 2 AndAlso _
    listbox_GetSelectedItem(list_widget) = "c" AndAlso list_data->pointer_index = -1, __LINE__
items_Require listbox_GetItem(list_widget, 1, item_text) AndAlso item_text = "b", __LINE__
items_Require listbox_InsertItem(list_widget, list_data->items(2), 0), __LINE__
items_Require listbox_GetItem(list_widget, 0, item_text) AndAlso item_text = "c", __LINE__
items_Require listbox_GetItem(list_widget, 0, list_data->items(0)), __LINE__
items_Require list_data->items(0) = "c", __LINE__
items_Require listbox_RemoveItem(list_widget, 0), __LINE__
items_Require listbox_GetSelectedIndex(list_widget) = 2, __LINE__
items_Require listbox_RemoveItem(list_widget, 2), __LINE__
items_Require listbox_GetSelectedIndex(list_widget) = -1 AndAlso listbox_GetItemCount(list_widget) = 2, __LINE__
items_Require listbox_RemoveItem(list_widget, -1) = 0, __LINE__
items_Require listbox_InsertItem(list_widget, "bad", 9) = 0, __LINE__
items_Require listbox_GetItem(list_widget, 9, item_text) = 0 AndAlso Len(item_text) = 0, __LINE__
listbox_Clear list_widget
items_Require Len(list_data->items(0)) = 0 AndAlso Len(list_data->items(1)) = 0, __LINE__
For item_index As Integer = 0 To LISTBOX_MAX_ITEMS - 1
    items_Require listbox_InsertItem(list_widget, Str(item_index)), __LINE__
Next item_index
items_Require listbox_InsertItem(list_widget, "overflow") = 0, __LINE__
items_Require listbox_GetItemCount(list_widget) = LISTBOX_MAX_ITEMS, __LINE__
listbox_Clear list_widget
item_text = String(LISTBOX_MAX_TEXT_BYTES, "x")
items_Require listbox_InsertItem(list_widget, item_text), __LINE__
items_Require listbox_InsertItem(list_widget, "x") = 0 AndAlso _
    listbox_GetItemCount(list_widget) = 1, __LINE__
listbox_Clear list_widget
item_text &= "x"
items_Require listbox_InsertItem(list_widget, item_text) = 0, __LINE__
gui_ResetForTest
backend_Exit
Print "listbox_items_smoke: PASS (indices, aliases, selection, pointer cancellation, item/text limits)"
End 0

/' end of listbox_items_smoke.bas '/
