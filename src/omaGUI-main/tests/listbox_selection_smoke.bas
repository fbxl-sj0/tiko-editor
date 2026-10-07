/'
    Project: omaGUI Tests
    File: listbox_selection_smoke.bas
    Purpose: Verify independent row selection and caret navigation.
    Responsibilities: Exercise simple/extended gestures and row lifetimes.
    This file intentionally does NOT contain VB-specific event dispatch.
'/
#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim Shared As Widget Ptr rows
Dim Shared As Integer check_count
Private Sub Require(ByVal condition As Integer, ByRef description As Const String)
    check_count += 1
    If condition Then Exit Sub
    Print "FAIL "; description
    End 1
End Sub

Private Function Selected(ByVal item_index As Integer) As Integer
    Dim As Integer selected_value
    Require listbox_GetItemSelected(rows, item_index, selected_value), "query existing row"
    Return selected_value
End Function

Private Sub KeyStroke(ByVal key_code As Integer)
    input_MockKey key_code, -1
    gui_UpdateAll
    input_MockKey key_code, 0
    gui_UpdateAll
End Sub

Private Sub ClickRow(ByVal item_index As Integer, ByVal shift_down As Integer = 0, ByVal control_down As Integer = 0)
    input_MockKey FB.SC_LSHIFT, shift_down
    input_MockKey FB.SC_CONTROL, control_down
    Dim As Integer row_y = rows->ay + (item_index - listbox_GetTopIndex(rows)) * 16 + 4
    input_MockMouse rows->ax + 4, row_y, 1
    gui_UpdateAll
    input_MockMouse rows->ax + 4, row_y, 0
    gui_UpdateAll
    input_MockKey FB.SC_LSHIFT, 0
    input_MockKey FB.SC_CONTROL, 0
    gui_UpdateAll
End Sub

backend_Init 320, 240, -1
gui_Init
rows = listbox_Create("rows", 10, 10, 240, 192)
Require rows <> 0, "create list"
gui_AddWidget rows
For item_index As Integer = 0 To 11
    Require listbox_InsertItem(rows, "row"), "insert item"
Next item_index
gui_SynchronizeLayout
gui_SetFocus rows
Require listbox_GetSelectionMode(rows) = LISTBOX_SELECTION_SINGLE, "legacy default mode"
Require listbox_SetItemSelected(rows, 2, -1), "single selection through row API"
Require listbox_GetSelectedIndex(rows) = 2 AndAlso listbox_GetSelectedCount(rows) = 1, "single mode retains legacy caret"
Require listbox_SetSelectionMode(rows, LISTBOX_SELECTION_SIMPLE), "enable simple selection"
Require Selected(2), "mode conversion retains selected item"
Require listbox_SetItemSelected(rows, 5, -1), "add independent selection"
Require listbox_GetSelectedIndex(rows) = 2 AndAlso listbox_GetSelectedCount(rows) = 2, "programmatic selection preserves caret"
Dim As ULongInt revision = listbox_GetSelectionChangeCount(rows)
Require listbox_SetItemSelected(rows, 5, -1), "idempotent selected assignment succeeds"
Require listbox_GetSelectionChangeCount(rows) = revision, "idempotent assignment leaves revision"
KeyStroke KEY_DOWN
Require listbox_GetSelectedIndex(rows) = 3 AndAlso listbox_GetSelectedCount(rows) = 2, "simple arrows only move caret"
input_MockKey FB.SC_SPACE, -1
gui_UpdateAll
gui_UpdateAll
Require Selected(3) AndAlso listbox_GetSelectedCount(rows) = 3, "held Space toggles once"
input_MockKey FB.SC_SPACE, 0
gui_UpdateAll
KeyStroke FB.SC_SPACE
Require Selected(3) = 0 AndAlso listbox_GetSelectedCount(rows) = 2, "Space toggles off"
ClickRow 5
Require Selected(5) = 0 AndAlso Selected(2), "simple click toggles one row"

Require listbox_SetSelectionMode(rows, LISTBOX_SELECTION_EXTENDED), "enable extended mode"
ClickRow 1
ClickRow 4, -1
Require listbox_GetSelectedCount(rows) = 4 AndAlso Selected(1) AndAlso Selected(4), "Shift click selects inclusive range"
ClickRow 2, -1
Require listbox_GetSelectedCount(rows) = 2 AndAlso Selected(1) AndAlso Selected(2), "reverse Shift click shrinks range"
ClickRow 6, 0, -1
Require listbox_GetSelectedCount(rows) = 3 AndAlso Selected(6), "Ctrl click adds row"
ClickRow 1, 0, -1
Require listbox_GetSelectedCount(rows) = 2 AndAlso Selected(1) = 0, "Ctrl click removes row"
input_MockKey FB.SC_CONTROL, -1
KeyStroke KEY_DOWN
Require listbox_GetSelectedIndex(rows) = 2 AndAlso listbox_GetSelectedCount(rows) = 2, "Ctrl arrow moves caret only"
KeyStroke FB.SC_SPACE
Require Selected(2) = 0 AndAlso Selected(6), "Ctrl Space toggles focused row"
input_MockKey FB.SC_CONTROL, 0
input_MockKey FB.SC_LSHIFT, -1
KeyStroke KEY_HOME
input_MockKey FB.SC_LSHIFT, 0
gui_UpdateAll
Require listbox_GetSelectedCount(rows) = 3 AndAlso Selected(0) AndAlso Selected(2), "Shift Home uses retained anchor"
ClickRow 6
Require listbox_GetSelectedCount(rows) = 1 AndAlso Selected(6), "plain click replaces selection"
Require listbox_SetItemSelected(rows, 9, -1), "second row selection"
Require listbox_SetItemData(rows, 6, 1234), "attach row data"
Require listbox_InsertItem(rows, "prefix", 0), "insert before selection"
Dim As LongInt row_data
Require Selected(7) AndAlso Selected(10) AndAlso listbox_GetSelectedIndex(rows) = 7, "flags and caret follow insertion"
Require listbox_GetItemData(rows, 7, row_data) AndAlso row_data = 1234, "data follows selected row"
Require listbox_RemoveItem(rows, 7), "remove selected caret"
Require listbox_GetSelectedCount(rows) = 1 AndAlso Selected(9) AndAlso listbox_GetSelectedIndex(rows) = -1, "remove preserves other selected row"
Require listbox_SetSelectionMode(rows, LISTBOX_SELECTION_SINGLE), "restore single selection"
Require listbox_GetSelectedIndex(rows) = 9 AndAlso listbox_GetSelectedCount(rows) = 1, "single mode retains surviving selection"
input_MockKey FB.SC_SPACE, -1
gui_UpdateAll
Require listbox_SetSelectionMode(rows, LISTBOX_SELECTION_EXTENDED), "change mode while Space is held"
gui_UpdateAll
Require listbox_GetSelectedCount(rows) = 1 AndAlso Selected(9), "mode change does not invent a Space edge"
input_MockKey FB.SC_SPACE, 0
gui_UpdateAll
Require listbox_SetSelectionMode(rows, LISTBOX_SELECTION_SINGLE), "restore mode after held-key check"
Require listbox_SetSelectionMode(rows, 3) = 0 AndAlso listbox_GetSelectionMode(rows) = 0, "invalid mode is atomic"
Dim As Integer invalid_selection = 123
Require listbox_GetItemSelected(rows, 100, invalid_selection) = 0 AndAlso invalid_selection = 0, "invalid query clears output"
Require listbox_SetItemSelected(rows, -1, -1) = 0, "invalid selection rejected"
Require listbox_SetSelectionMode(0, 1) = 0 AndAlso listbox_GetSelectionMode(0) = -1, "null widget rejected"
listbox_Clear rows
Require listbox_GetSelectedCount(rows) = 0, "clear releases selection"
Require listbox_SetSelectionMode(rows, 2), "empty mode conversion"
For item_index As Integer = 0 To LISTBOX_MAX_ITEMS - 1
    Require listbox_InsertItem(rows, "row"), "fill capacity"
    Require listbox_SetItemSelected(rows, item_index, -1), "select capacity"
Next item_index
Require listbox_GetSelectedCount(rows) = LISTBOX_MAX_ITEMS, "all bounded rows may be selected"
Require listbox_InsertItem(rows, "overflow") = 0 AndAlso listbox_GetSelectedCount(rows) = LISTBOX_MAX_ITEMS, "failed insertion retains selection"
Require listbox_SetSelectedIndex(rows, -1) AndAlso listbox_GetSelectedCount(rows) = 0, "explicit reset clears all selected rows"
gui_ResetForTest
backend_Exit
Print "listbox_selection_smoke: PASS ("; check_count; " checks)"
/' end of listbox_selection_smoke.bas '/
