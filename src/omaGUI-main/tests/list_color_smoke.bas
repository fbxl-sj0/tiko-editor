/'
    Project: omaGUI Tests
    ---------------------

    File: list_color_smoke.bas

    Purpose:

        Verify retained normal-surface colors for list-family widgets.

    Responsibilities:

        - set and query ListBox and ComboBox BackColor and ForeColor values
        - render both controls through the portable headless backend
        - clear every override before registry-owned destruction

    This file intentionally does NOT contain:

        - selection-highlight color customization
        - filesystem enumeration or pointer-input checks

    Targets: FreeBASIC fb dialect with the native omaGUI backend.
    Module API boundary: Standalone development checks for the behavior described above.
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim As ULong color_value
Dim As Widget Ptr combo_widget
Dim As Integer failure_count
Dim As Widget Ptr list_widget

backend_Init 320, 180, BACKEND_HEADLESS_DRAWABLE
gui_Init
list_widget = listbox_Create("color_list", 10, 10, 140, 64)
combo_widget = combobox_Create("color_combo", 10, 90, 140, 24)
If list_widget = 0 OrElse combo_widget = 0 Then
    Print "list_color_smoke: constructor failed"
    backend_Exit
    End 1
End If
gui_AddWidget list_widget
gui_AddWidget combo_widget
listbox_AddItem list_widget, "List item"
combobox_AddItem combo_widget, "Combo item"
combobox_SetSelectedIndex combo_widget, 0

If listbox_SetBackgroundColor(list_widget, RGB(1, 2, 3)) = 0 OrElse _
   listbox_GetBackgroundColor(list_widget, color_value) = 0 OrElse _
   color_value <> RGB(1, 2, 3) OrElse _
   listbox_SetForegroundColor(list_widget, RGB(4, 5, 6)) = 0 OrElse _
   listbox_GetForegroundColor(list_widget, color_value) = 0 OrElse _
   color_value <> RGB(4, 5, 6) Then
    Print "FAIL ListBox colors"
    failure_count += 1
End If
If combobox_SetBackgroundColor(combo_widget, RGB(7, 8, 9)) = 0 OrElse _
   combobox_GetBackgroundColor(combo_widget, color_value) = 0 OrElse _
   color_value <> RGB(7, 8, 9) OrElse _
   combobox_SetForegroundColor(combo_widget, RGB(10, 11, 12)) = 0 OrElse _
   combobox_GetForegroundColor(combo_widget, color_value) = 0 OrElse _
   color_value <> RGB(10, 11, 12) Then
    Print "FAIL ComboBox colors"
    failure_count += 1
End If

backend_Clear RGB(200, 200, 200)
gui_RenderAll
backend_Flip
listbox_SetColors list_widget, RGB(20, 30, 40), RGB(50, 60, 70), _
    RGB(80, 90, 100), RGB(110, 120, 130), RGB(140, 150, 160)
listbox_Clear list_widget
listbox_AddItem list_widget, "Hull" & Chr(9) & "100"
listbox_SetSelectedIndex list_widget, 0
If listbox_SetRightColumn(list_widget, 70) = 0 OrElse _
   listbox_SetRightColumn(list_widget, -1) <> 0 OrElse _
   listbox_SetRightColumn(list_widget, 140) <> 0 OrElse _
   listbox_SetRightColumn(combo_widget, 70) <> 0 Then failure_count += 1
backend_Clear RGB(200, 200, 200)
gui_RenderAll
If Point(10, 10) <> RGB(50, 60, 70) OrElse _
   Point(120, 12) <> RGB(110, 120, 130) OrElse _
   Point(120, 40) <> RGB(20, 30, 40) Then failure_count += 1
Dim As Integer valueColumnPainted
For pixelY As Integer = 12 To 25
    For pixelX As Integer = 80 To 100
        If Point(pixelX, pixelY) <> RGB(110, 120, 130) Then valueColumnPainted = -1
    Next pixelX
Next pixelY
If valueColumnPainted = 0 Then failure_count += 1

If listbox_ClearBackgroundColor(list_widget) = 0 OrElse _
   listbox_ClearForegroundColor(list_widget) = 0 OrElse _
   listbox_GetBackgroundColor(list_widget, color_value) <> 0 OrElse _
   listbox_GetForegroundColor(list_widget, color_value) <> 0 OrElse _
   combobox_ClearBackgroundColor(combo_widget) = 0 OrElse _
   combobox_ClearForegroundColor(combo_widget) = 0 OrElse _
   combobox_GetBackgroundColor(combo_widget, color_value) <> 0 OrElse _
   combobox_GetForegroundColor(combo_widget, color_value) <> 0 Then
    Print "FAIL list-family color clear"
    failure_count += 1
End If

gui_ResetForTest
backend_Exit
If failure_count <> 0 Then
    Print "list_color_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "list_color_smoke: PASS"
End 0

/' end of list_color_smoke.bas '/
