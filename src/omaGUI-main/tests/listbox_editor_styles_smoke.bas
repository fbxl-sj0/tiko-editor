/'
    Project: omaGUI Tests
    File: listbox_editor_styles_smoke.bas
    Purpose: Check editor list styles alongside the local item model.
    Responsibilities: Exercise checklist row lifetime, table header hits,
        and bounded dropdown presentation in a drawable headless backend.
    This file intentionally does NOT contain: application list policy.
'/

#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub Require(ByVal condition As Integer, ByRef description As Const String)
    If condition Then Exit Sub
    Print "listbox_editor_styles_smoke: FAIL "; description
    End 1
End Sub

backend_Init 400, 280, BACKEND_HEADLESS_DRAWABLE
gui_Init
input_ResetForTest

Dim As Widget Ptr checklist = listbox_Create("checks", 8, 8, 170, 110)
Require checklist <> 0, "checklist allocation"
gui_AddWidget checklist
listbox_SetChecklistStyle checklist
listbox_AddItem checklist, "first"
listbox_AddItem checklist, "second"
listbox_SetChecked checklist, 0, -1
Require listbox_IsChecked(checklist, 0), "checked state"
Require listbox_InsertItem(checklist, "new", 0), "insert before checked row"
Require listbox_IsChecked(checklist, 1), "checked state follows inserted row"
Require listbox_RemoveItem(checklist, 0), "remove inserted row"
Require listbox_IsChecked(checklist, 0), "checked state follows removed row"
gui_RefreshLayout
input_MockMouse checklist->ax + 7, checklist->ay + 7, 1
gui_UpdateAll
input_MockMouse checklist->ax + 7, checklist->ay + 7, 0
gui_UpdateAll
Require listbox_IsChecked(checklist, 0) = 0, "release toggles checkbox"
listbox_SetRowHeight checklist, 24
listbox_SetScrollbarColors checklist, RGB(1, 2, 3), RGB(4, 5, 6), RGB(7, 8, 9)
Require Cast(ListBoxData Ptr, checklist->data)->row_height = 24, "row height"
gui_RenderAll

Dim As Widget Ptr table = listbox_Create("table", 185, 8, 205, 110)
Require table <> 0, "table allocation"
gui_AddWidget table
listbox_SetColumn table, 0, "Name", 100
listbox_SetColumn table, 1, "Kind", 90
Require Cast(ListBoxData Ptr, table->data)->table_column_count = 2, "table columns"
listbox_AddItem table, "alpha" & Chr(9) & "file"
gui_RefreshLayout
input_MockMouse table->ax + 8, table->ay + 5, 1
gui_UpdateAll
input_MockMouse table->ax + 8, table->ay + 5, 0
gui_UpdateAll
Require listbox_GetSelectedIndex(table) = -1, "header cannot select a row"
input_MockMouse table->ax + 8, table->ay + 25, 1
gui_UpdateAll
input_MockMouse table->ax + 8, table->ay + 25, 0
gui_UpdateAll
Require listbox_GetSelectedIndex(table) = 0, "table row selection"
gui_RenderAll

Dim As Widget Ptr dropdown = listbox_Create("choices", 8, 140, 170, 80)
Require dropdown <> 0, "dropdown allocation"
gui_AddWidget dropdown
listbox_AddItem dropdown, "one"
listbox_AddItem dropdown, "two"
listbox_SetDropdownStyle dropdown
Require dropdown->h = 24, "dropdown height"
gui_RefreshLayout
input_MockMouse dropdown->ax + 8, dropdown->ay + 8, 1
gui_UpdateAll
input_MockMouse dropdown->ax + 8, dropdown->ay + 8, 0
gui_UpdateAll
Require Cast(ListBoxData Ptr, dropdown->data)->dropdown_popup <> 0, "dropdown popup"
gui_RenderAll

gui_ResetForTest
backend_Exit
Print "listbox_editor_styles_smoke: PASS"

' end of listbox_editor_styles_smoke.bas
