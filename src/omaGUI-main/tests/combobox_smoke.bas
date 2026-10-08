/'
    Project: omaGUI Tests
    ---------------------

    File: combobox_smoke.bas

    Purpose:

        Verify bounded ComboBox API, all three portable styles, keyboard
        input, pointer selection, and type-ahead lifecycle behavior.

    Responsibilities:

        - create and populate a drop-down in the headless backend
        - check programmatic selection without callback side effects
        - commit keyboard and pointer choices with one callback each
        - match incremental prefixes and cycle repeated initial characters
        - retain an editable Simple list inside its checked widget geometry
        - reject invalid item and open-state operations

    This file intentionally does NOT contain:

        - screenshot comparisons
        - native desktop-window interaction

    Targets: FreeBASIC fb dialect with the native omaGUI backend.
    Module API boundary: Standalone development checks for the behavior described above.
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim Shared As Integer combo_change_count

Private Sub comboSmoke_OnChange(ByVal source_widget As Widget Ptr)
    If source_widget <> 0 Then combo_change_count += 1
End Sub


Dim As Widget Ptr combo_widget
Dim As Widget Ptr simple_combo_widget
Dim As ComboBoxData Ptr combo_data
Dim As Integer failure_count

backend_Init 320, 240, BACKEND_HEADLESS
gui_Init
combo_widget = combobox_Create( _
    "combo_smoke", 10, 10, 150, 24, 3, @comboSmoke_OnChange _
)
If combo_widget = 0 Then
    Print "combobox_smoke: constructor failed"
    backend_Exit
    End 1
End If
gui_AddWidget combo_widget

If combobox_AddItem(combo_widget, "Alpha") = 0 OrElse _
   combobox_AddItem(combo_widget, "Beta") = 0 OrElse _
   combobox_AddItem(combo_widget, "Gamma") = 0 OrElse _
   combobox_AddItem(combo_widget, "Delta") = 0 OrElse _
   combobox_SetSelectedIndex(combo_widget, 1) = 0 Then
    Print "FAIL initial item API"
    failure_count += 1
End If
If combobox_GetSelectedItem(combo_widget) <> "Beta" OrElse _
   combo_change_count <> 0 OrElse _
   combobox_SetSelectedIndex(combo_widget, 7) <> 0 Then
    Print "FAIL checked programmatic selection"
    failure_count += 1
End If

gui_SetFocus combo_widget
input_MockKeyPress KEY_DOWN
gui_UpdateAll
If combobox_GetSelectedItem(combo_widget) <> "Gamma" OrElse _
   combo_change_count <> 1 Then
    Print "FAIL closed keyboard selection"
    failure_count += 1
End If

input_MockKeyPress KEY_RETURN
gui_UpdateAll
input_MockKeyPress KEY_END
gui_UpdateAll
If combobox_IsOpen(combo_widget) = 0 Then
    Print "FAIL keyboard open"
    failure_count += 1
End If
input_MockKeyPress KEY_RETURN
gui_UpdateAll
If combobox_GetSelectedItem(combo_widget) <> "Delta" OrElse _
   combo_change_count <> 2 OrElse combobox_IsOpen(combo_widget) <> 0 Then
    Print "FAIL keyboard popup commit"
    failure_count += 1
End If

If combobox_SetOpen(combo_widget, -1) = 0 Then
    Print "FAIL programmatic popup open"
    failure_count += 1
Else
    /'
        With three visible rows and Delta selected, scroll_top is one. The
        first displayed row is therefore Beta at y = 35 through 52.
    '/
    input_MockMouse 30, 40, 1
    gui_UpdateAll
    input_MockMouse 30, 40, 0
    gui_UpdateAll
    If combobox_GetSelectedItem(combo_widget) <> "Beta" OrElse _
       combo_change_count <> 3 OrElse combobox_IsOpen(combo_widget) <> 0 Then
        Print "FAIL pointer popup commit"
        failure_count += 1
    End If
End If

If combobox_AddItem(combo_widget, "Gizmo") = 0 OrElse _
   combobox_SetSelectedIndex(combo_widget, 0) = 0 Then
    Print "FAIL type-ahead fixture setup"
    failure_count += 1
Else
    combo_data = Cast(ComboBoxData Ptr, combo_widget->data)
    input_MockText "g"
    gui_UpdateAll
    input_ResetForTest
    If combobox_GetSelectedItem(combo_widget) <> "Gamma" OrElse _
       combo_change_count <> 4 Then
        Print "FAIL case-insensitive type-ahead prefix"
        failure_count += 1
    End If

    input_MockText "G"
    gui_UpdateAll
    input_ResetForTest
    If combobox_GetSelectedItem(combo_widget) <> "Gizmo" OrElse _
       combo_change_count <> 5 Then
        Print "FAIL repeated-character type-ahead cycling"
        failure_count += 1
    End If

    If combobox_SetSelectedIndex(combo_widget, 0) = 0 Then
        Print "FAIL type-ahead extension reset"
        failure_count += 1
    Else
        input_MockText "g"
        gui_UpdateAll
        input_ResetForTest
        input_MockText "a"
        gui_UpdateAll
        input_ResetForTest
        If combobox_GetSelectedItem(combo_widget) <> "Gamma" OrElse _
           combo_change_count <> 6 Then
            Print "FAIL multi-character type-ahead prefix"
            failure_count += 1
        End If
    End If

    If combobox_SetSelectedIndex(combo_widget, 0) = 0 OrElse _
       combobox_SetOpen(combo_widget, -1) = 0 Then
        Print "FAIL open type-ahead fixture setup"
        failure_count += 1
    Else
        input_MockText "g"
        gui_UpdateAll
        input_ResetForTest
        If combo_data->pending_index <> 2 OrElse _
           combobox_GetSelectedItem(combo_widget) <> "Alpha" OrElse _
           combobox_IsOpen(combo_widget) = 0 Then
            Print "FAIL popup type-ahead preview"
            failure_count += 1
        End If

        input_MockKeyPress KEY_RETURN
        gui_UpdateAll
        input_ResetForTest
        If combobox_GetSelectedItem(combo_widget) <> "Gamma" OrElse _
           combo_change_count <> 7 OrElse _
           combobox_IsOpen(combo_widget) <> 0 Then
            Print "FAIL popup type-ahead commit"
            failure_count += 1
        End If
    End If
End If

combo_data = Cast(ComboBoxData Ptr, combo_widget->data)
combobox_Clear combo_widget
If combo_data->item_count <> 0 OrElse _
   combobox_GetSelectedIndex(combo_widget) <> -1 OrElse _
   combobox_SetOpen(combo_widget, -1) <> 0 Then
    Print "FAIL clear or empty popup rejection"
    failure_count += 1
End If

simple_combo_widget = combobox_Create( _
    "combo_simple_smoke", 10, 100, 150, 100, 3, @comboSmoke_OnChange _
)
If simple_combo_widget = 0 Then
    Print "FAIL Simple style constructor"
    failure_count += 1
Else
    gui_AddWidget simple_combo_widget
    If combobox_SetStyle(simple_combo_widget, 1) = 0 OrElse _
       combobox_GetStyle(simple_combo_widget) <> 1 OrElse _
       combobox_IsEditable(simple_combo_widget) = 0 OrElse _
       combobox_IsOpen(simple_combo_widget) = 0 Then
        Print "FAIL Simple style state"
        failure_count += 1
    End If
    If combobox_AddItem(simple_combo_widget, "One") = 0 OrElse _
       combobox_AddItem(simple_combo_widget, "Two") = 0 OrElse _
       combobox_AddItem(simple_combo_widget, "Three") = 0 OrElse _
       combobox_AddItem(simple_combo_widget, "Four") = 0 OrElse _
       combobox_AddItem(simple_combo_widget, "Five") = 0 OrElse _
       combobox_SetSelectedIndex(simple_combo_widget, 1) = 0 Then
        Print "FAIL Simple style item setup"
        failure_count += 1
    Else
        Dim As ULongInt dropdown_count = _
            combobox_GetDropDownCount(simple_combo_widget)
        Dim As ULongInt change_count = combo_change_count
        gui_SetFocus simple_combo_widget
        input_MockKeyPress KEY_UP
        gui_UpdateAll
        If combobox_GetSelectedItem(simple_combo_widget) <> "One" OrElse _
           combo_change_count <> change_count + 1 OrElse _
           combobox_GetDropDownCount(simple_combo_widget) <> dropdown_count Then
            Print "FAIL Simple style immediate keyboard selection"
            failure_count += 1
        End If

        If combobox_SetText(simple_combo_widget, "") = 0 Then
            Print "FAIL Simple style clear edit text"
            failure_count += 1
        Else
            input_MockText "Three"
            gui_UpdateAll
            input_ResetForTest
            If combobox_GetText(simple_combo_widget) <> "Three" OrElse _
               combobox_GetSelectedIndex(simple_combo_widget) <> 2 Then
                Print "FAIL Simple style editable text match"
                failure_count += 1
            End If
        End If

        If combobox_SetSelectedIndex(simple_combo_widget, 4) = 0 Then
            Print "FAIL Simple style scroll selection"
            failure_count += 1
        Else
            input_MockMouse(30, 164, 1)
            gui_UpdateAll
            input_MockMouse(30, 164, 0)
            gui_UpdateAll
            If combobox_GetSelectedItem(simple_combo_widget) <> "Five" OrElse _
               combobox_GetDropDownCount(simple_combo_widget) <> dropdown_count Then
                Print "FAIL Simple style visible-list pointer selection"
                failure_count += 1
            End If
        End If

        If combobox_SetOpen(simple_combo_widget, 0) = 0 OrElse _
           combobox_IsOpen(simple_combo_widget) = 0 OrElse _
           combobox_SetStyle(simple_combo_widget, 3) <> 0 OrElse _
           combobox_GetStyle(simple_combo_widget) <> 1 Then
            Print "FAIL Simple style fixed list or invalid style guard"
            failure_count += 1
        End If
    End If
End If

backend_Clear RGB(200, 200, 200)
gui_RenderAll
backend_Flip
gui_ResetForTest
backend_Exit

If failure_count <> 0 Then
    Print "combobox_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "combobox_smoke: PASS"
End 0

/' end of combobox_smoke.bas '/
