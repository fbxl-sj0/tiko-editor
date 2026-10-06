/'
    Project: omaGUI Tests
    ---------------------

    File: toolbar_smoke.bas

    Purpose:

        Verify portable toolbar construction, state, and activation.

    Responsibilities:

        - construct text commands around a separator
        - exercise enabled-state and bounded metadata APIs
        - verify pointer and programmatic callback dispatch
        - render through the headless backend

    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:

        - application command behavior
        - screenshot comparison
        - operating-system toolbar calls
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim Shared As Integer toolbar_selection_count
Dim Shared As Integer toolbar_selected_item


Private Sub toolbarSmoke_OnSelection( _
    ByVal callback_context As Any Ptr, _
    ByVal item_index As Integer _
)
    If callback_context <> 0 Then
        toolbar_selection_count += 1
        toolbar_selected_item = item_index
    End If
End Sub


Dim As Widget Ptr bar_widget
Dim As Integer context_marker
Dim As Integer failure_count
Dim As Integer open_item
Dim As Integer run_item
Dim As Integer save_item
Dim As Integer separator_item

backend_Init 280, 100, BACKEND_HEADLESS
gui_Init
bar_widget = toolbar_Create("toolbar_smoke", 10, 10, 250, 34)
If bar_widget = 0 Then
    Print "toolbar_smoke: constructor failed"
    backend_Exit
    End 1
End If

open_item = toolbar_AddButton(bar_widget, "Open", 70)
separator_item = toolbar_AddSeparator(bar_widget)
save_item = toolbar_AddButton(bar_widget, "Save", 70)
run_item = toolbar_AddButton(bar_widget, "Run", 60)
If open_item <> 0 OrElse separator_item <> 1 OrElse _
   save_item <> 2 OrElse run_item <> 3 OrElse _
   toolbar_GetItemCount(bar_widget) <> 4 OrElse _
   toolbar_GetItemLabel(bar_widget, save_item) <> "Save" Then
    Print "FAIL bounded construction"
    failure_count += 1
End If
If toolbar_AddButton(bar_widget, "", 40) <> -1 OrElse _
   toolbar_AddButton( _
       bar_widget, String(TOOLBAR_MAX_TEXT_BYTES + 1, "X"), 40 _
   ) <> -1 OrElse _
   toolbar_AddButton(bar_widget, "Bad", -1) <> -1 OrElse _
   toolbar_SetItemEnabled(bar_widget, separator_item, 0) <> 0 OrElse _
   toolbar_GetItemLabel(bar_widget, separator_item) <> "" Then
    Print "FAIL bounded rejection"
    failure_count += 1
End If
If toolbar_SetItemEnabled(bar_widget, save_item, 0) = 0 OrElse _
   toolbar_GetItemEnabled(bar_widget, save_item) <> 0 OrElse _
   toolbar_SetItemEnabled(bar_widget, 99, 0) <> 0 Then
    Print "FAIL enabled state"
    failure_count += 1
End If

context_marker = 1
toolbar_SetSelectionHandler _
    bar_widget, @toolbarSmoke_OnSelection, @context_marker
gui_AddWidget bar_widget

input_MockMouse 20, 24, 1
gui_UpdateAll
input_MockMouse 20, 24, 0
gui_UpdateAll
If toolbar_selection_count <> 1 OrElse toolbar_selected_item <> open_item Then
    Print "FAIL pointer activation"
    failure_count += 1
End If

If toolbar_ActivateItem(bar_widget, save_item) <> 0 OrElse _
   toolbar_selection_count <> 1 Then
    Print "FAIL disabled activation rejection"
    failure_count += 1
End If
If toolbar_ActivateItem(bar_widget, run_item) = 0 OrElse _
   toolbar_selection_count <> 2 OrElse toolbar_selected_item <> run_item Then
    Print "FAIL programmatic activation"
    failure_count += 1
End If

backend_Clear RGB(200, 200, 200)
gui_RenderAll
backend_Flip
gui_ResetForTest
backend_Exit

If failure_count <> 0 Then
    Print "toolbar_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "toolbar_smoke: PASS"
End 0

/' end of toolbar_smoke.bas '/
