/'
    Project: omaGUI Tests
    File: listbox_columns_smoke.bas
    Purpose: Verify column layout through public list operations and input.
    Responsibilities: Check hit testing, scrolling, clipping and mode changes.
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain: Windows control or drawing APIs.
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
    backend_Exit
    Screen 0
    Print "FAIL "; description
    End 1
End Sub
Private Sub KeyStroke(ByVal key_code As Integer)
    input_MockKey key_code, -1
    gui_UpdateAll
    input_MockKey key_code, 0
    gui_UpdateAll
End Sub
Private Sub ClickAt(ByVal pointer_x As Integer, ByVal pointer_y As Integer)
    input_MockMouse pointer_x, pointer_y, 1
    gui_UpdateAll
    input_MockMouse pointer_x, pointer_y, 0
    gui_UpdateAll
End Sub

' The portable null driver provides real framebuffer pixels without a window.
ScreenControl FB.SET_DRIVER_NAME, "null"
backend_Init 320, 240, BACKEND_DISPLAY_ENABLED
gui_Init
rows = listbox_Create("columns", 10, 10, 240, 79)
Require rows <> 0, "create list"
gui_AddWidget rows
Require listbox_GetColumnCount(rows) = 0, "legacy vertical default"
Require listbox_SetColumnCount(rows, 2), "enable two columns"
For item_index As Integer = 0 To 19
    Require listbox_InsertItem(rows, ""), "insert row"
Next item_index
gui_SynchronizeLayout
gui_SetFocus rows
ClickAt rows->ax + 124, rows->ay + 20
Require listbox_GetSelectedIndex(rows) = 5, "pointer reaches second column row one"
KeyStroke KEY_RIGHT
Require listbox_GetSelectedIndex(rows) = 9 AndAlso listbox_GetTopIndex(rows) = 4, "Right advances one column and reveals it"
KeyStroke KEY_LEFT
Require listbox_GetSelectedIndex(rows) = 5 AndAlso listbox_GetTopIndex(rows) = 4, "Left retains row position"
KeyStroke KEY_HOME
Require listbox_GetSelectedIndex(rows) = 0 AndAlso listbox_GetTopIndex(rows) = 0, "Home reveals first column"
KeyStroke KEY_END
Require listbox_GetSelectedIndex(rows) = 19 AndAlso listbox_GetTopIndex(rows) = 12, "End reveals final full page"
KeyStroke FB.SC_PAGEUP
Require listbox_GetSelectedIndex(rows) = 11 AndAlso listbox_GetTopIndex(rows) = 8, "PageUp advances by visible cell count"
Require listbox_SetTopIndex(rows, 7) AndAlso listbox_GetTopIndex(rows) = 4, "TopIndex aligns requested row to its column"
Require listbox_SetColumnCount(rows, 3), "change visible count"
Require listbox_GetTopIndex(rows) = 4 AndAlso listbox_GetSelectedIndex(rows) = 11, "count change preserves caret and valid viewport"
Require listbox_SetColumnCount(rows, 1), "one horizontally scrolling column"
Require listbox_SetSelectedIndex(rows, 19) AndAlso listbox_GetTopIndex(rows) = 16, "one column reveals final row"
rows->h = 111
Require listbox_GetTopIndex(rows) = 12 AndAlso listbox_GetSelectedIndex(rows) = 19, "resize reflows rows without changing caret"
rows->h = 79
Require listbox_SetColumnCount(rows, 2), "restore two columns"
Require listbox_SetTopIndex(rows, 0), "reset viewport"
input_MockMouse rows->ax + 4, rows->ay + 4, 0, -1
gui_UpdateAll
input_MockMouse rows->ax + 4, rows->ay + 4, 0, 0
gui_UpdateAll
Require listbox_GetTopIndex(rows) = 4 AndAlso listbox_GetSelectedIndex(rows) = 19, "wheel moves one column without selecting"
input_MockMouse rows->ax + 4, rows->ay + 4, 0, 2147483647
gui_UpdateAll
Require listbox_GetTopIndex(rows) = 0, "large positive wheel delta saturates at first column"
input_MockMouse rows->ax + 4, rows->ay + 4, 0, -2147483648LL
gui_UpdateAll
Require listbox_GetTopIndex(rows) = 12, "large negative wheel delta saturates at final page"
input_MockMouse rows->ax + 4, rows->ay + 4, 0, 0
gui_UpdateAll
Require listbox_SetTopIndex(rows, 0), "reset before scrollbar"
ClickAt rows->ax + 235, rows->ay + 70
Require listbox_GetTopIndex(rows) > 0 AndAlso listbox_GetTopIndex(rows) Mod 4 = 0, "horizontal scrollbar moves whole columns"
Require listbox_GetSelectedIndex(rows) = 19, "scrollbar preserves selection"
Require listbox_SetTopIndex(rows, 0), "reset before padding hit"
rows->h = 83
ClickAt rows->ax + 4, rows->ay + 66
Require listbox_GetSelectedIndex(rows) = 19, "partial bottom padding is not another row"
rows->h = 79
Require listbox_SetSelectionMode(rows, LISTBOX_SELECTION_EXTENDED), "enable independent selected rows"
Require listbox_SetSelectedIndex(rows, -1), "clear selection"
Require listbox_SetItemSelected(rows, 0, -1) AndAlso listbox_SetItemSelected(rows, 5, -1), "select rows in separate columns"
Require listbox_SetItem(rows, 0, String(200, "M")), "long first-column label"
Require listbox_SetTopIndex(rows, 0), "render first columns"
Require listbox_SetBackgroundColor(rows, RGB(255, 255, 255)), "known client background"
backend_Clear RGB(128, 128, 128)
backend_SetClip 0, 0, 300, 200
listbox_Render rows
Dim As Integer clip_x, clip_y, clip_width, clip_height
backend_GetClip clip_x, clip_y, clip_width, clip_height
Require clip_x = 0 AndAlso clip_y = 0 AndAlso clip_width = 300 AndAlso clip_height = 200, "render restores parent clip"
backend_ResetClip
Dim As ULong selected_color = theme_GetColor(GUI_COLOR_SELECT_BG) And &hFFFFFF
Require (Point(12, 11) And &hFFFFFF) = selected_color, "first column selection rendered"
Require (Point(132, 27) And &hFFFFFF) = selected_color, "second column selection rendered"
Dim As Integer leaked_pixels
For pixel_y As Integer = 12 To 24
    For pixel_x As Integer = 132 To 238
        If (Point(pixel_x, pixel_y) And &hFFFFFF) <> &hFFFFFF Then leaked_pixels += 1
    Next pixel_x
Next pixel_y
Require leaked_pixels = 0, "long label clipped at column boundary"
Require listbox_SetColumnCount(rows, -1) = 0 AndAlso listbox_GetColumnCount(rows) = 2, "negative count leaves layout intact"
Require listbox_SetColumnCount(rows, LISTBOX_MAX_COLUMNS + 1) = 0, "count bound rejected"
Require listbox_SetColumnCount(0, 2) = 0 AndAlso listbox_GetColumnCount(0) = -1, "invalid widget rejected"
rows->w = 1
rows->h = 1
Require listbox_SetColumnCount(rows, LISTBOX_MAX_COLUMNS), "bounded maximum count in tiny geometry"
Require listbox_SetSelectedIndex(rows, 19), "tiny geometry reveals safely"
listbox_Render rows
gui_UpdateAll
Require listbox_GetSelectedCount(rows) = 2, "tiny geometry retains selection"
rows->w = 240
rows->h = 79
Require listbox_SetColumnCount(rows, 0), "library permits vertical conversion"
Require listbox_GetSelectedCount(rows) = 2, "conversion retains selected rows"
gui_ResetForTest
backend_Exit
Screen 0
Print "listbox_columns_smoke: PASS ("; check_count; " checks)"
/' end of listbox_columns_smoke.bas '/
