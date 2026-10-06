/'
    Project: omaGUI Tests
    ---------------------

    File: menubar_smoke.bas

    Purpose:

        Verify bounded menu-bar construction, navigation, and activation.

    Responsibilities:

        - populate two menus and a separator in the headless backend
        - exercise keyboard wrapping, separator skipping, and exact accelerators
        - exercise release-inside pointer opening and command activation
        - verify mutable labels and hidden-row compaction
        - reject invalid menu and item indexes

    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:

        - application command behavior
        - screenshot comparisons
        - platform-native menu calls
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim Shared As Integer menubar_selection_count
Dim Shared As Integer menubar_selected_menu
Dim Shared As Integer menubar_selected_item


Private Sub menubarSmoke_OnSelection( _
    ByVal callback_context As Any Ptr, _
    ByVal menu_index As Integer, _
    ByVal item_index As Integer _
)
    If callback_context <> 0 Then
        menubar_selection_count += 1
        menubar_selected_menu = menu_index
        menubar_selected_item = item_index
    End If
End Sub


Dim As Widget Ptr bar_widget
Dim As Integer context_marker
Dim As Integer edit_menu
Dim As Integer failure_count
Dim As Integer file_menu
Dim As Integer shortcut_modifiers
Dim As Integer shortcut_scan_code

backend_Init 320, 240, BACKEND_HEADLESS
gui_Init
bar_widget = menubar_Create("menubar_smoke", 10, 10, 280)
If bar_widget = 0 Then
    Print "menubar_smoke: constructor failed"
    backend_Exit
    End 1
End If

file_menu = menubar_AddMenu(bar_widget, "&File")
edit_menu = menubar_AddMenu(bar_widget, "&Edit")
If file_menu <> 0 OrElse edit_menu <> 1 OrElse _
   menubar_AddItem(bar_widget, file_menu, "&New") <> 0 OrElse _
   menubar_AddItem(bar_widget, file_menu, "-") <> 1 OrElse _
   menubar_AddItem(bar_widget, file_menu, "E&xit") <> 2 OrElse _
   menubar_AddItem(bar_widget, edit_menu, "&Copy") <> 0 OrElse _
   menubar_AddItem(bar_widget, edit_menu, "&Paste") <> 1 Then
    Print "FAIL bounded construction"
    failure_count += 1
End If
If menubar_AddMenu(bar_widget, "") <> -1 OrElse _
   menubar_AddItem(bar_widget, 9, "Invalid") <> -1 OrElse _
   menubar_GetMenuCount(bar_widget) <> 2 OrElse _
   menubar_GetItemCount(bar_widget, file_menu) <> 3 OrElse _
   menubar_GetMenuLabel(bar_widget, edit_menu) <> "&Edit" OrElse _
   menubar_GetItemLabel(bar_widget, file_menu, 2) <> "E&xit" Then
    Print "FAIL checked metadata API"
    failure_count += 1
End If
If menubar_SetItemLabel(bar_widget, file_menu, 0, "&Create") = 0 OrElse _
   menubar_GetItemLabel(bar_widget, file_menu, 0) <> "&Create" OrElse _
   menubar_SetItemLabel(bar_widget, file_menu, 0, "&New") = 0 OrElse _
   menubar_SetItemLabel(bar_widget, 9, 0, "Invalid") <> 0 OrElse _
   menubar_SetItemLabel(bar_widget, file_menu, 0, "") <> 0 Then
    Print "FAIL mutable label API"
    failure_count += 1
End If
If menubar_GetItemVisible(bar_widget, file_menu, 0) = 0 OrElse _
   menubar_SetItemVisible(bar_widget, file_menu, 0, 0) = 0 OrElse _
   menubar_GetItemVisible(bar_widget, file_menu, 0) <> 0 OrElse _
   menubar_SetItemVisible(bar_widget, file_menu, 0, -1) = 0 OrElse _
   menubar_SetItemVisible(bar_widget, 9, 0, 0) <> 0 Then
    Print "FAIL item visibility API"
    failure_count += 1
End If
If menubar_SetItemChecked(bar_widget, edit_menu, 0, -1) = 0 OrElse _
   menubar_GetItemChecked(bar_widget, edit_menu, 0) = 0 OrElse _
   menubar_GetItemChecked(bar_widget, edit_menu, 1) <> 0 OrElse _
   menubar_SetItemChecked(bar_widget, file_menu, 1, -1) <> 0 OrElse _
   menubar_SetItemChecked(bar_widget, 9, 0, -1) <> 0 Then
    Print "FAIL checked state API"
    failure_count += 1
End If
If menubar_GetItemEnabled(bar_widget, edit_menu, 0) = 0 OrElse _
   menubar_SetItemEnabled(bar_widget, edit_menu, 0, 0) = 0 OrElse _
   menubar_GetItemEnabled(bar_widget, edit_menu, 0) <> 0 OrElse _
   menubar_SetItemEnabled(bar_widget, file_menu, 1, 0) <> 0 OrElse _
   menubar_SetItemEnabled(bar_widget, 9, 0, 0) <> 0 Then
    Print "FAIL enabled state API"
    failure_count += 1
End If
If menubar_SetItemShortcutText( _
       bar_widget, edit_menu, 0, "Ctrl+C" _
   ) = 0 OrElse _
   menubar_GetItemShortcutText(bar_widget, edit_menu, 0) <> "Ctrl+C" _
   OrElse menubar_SetItemShortcutText( _
       bar_widget, file_menu, 1, "invalid" _
   ) <> 0 OrElse _
   menubar_SetItemShortcutText( _
       bar_widget, edit_menu, 0, String(161, "X") _
   ) <> 0 Then
    Print "FAIL shortcut text API"
    failure_count += 1
End If
If menubar_SetItemShortcut( _
       bar_widget, file_menu, 0, FB.SC_F5, INPUT_MODIFIER_NONE, "F5" _
   ) = 0 OrElse menubar_GetItemShortcut( _
       bar_widget, file_menu, 0, shortcut_scan_code, shortcut_modifiers _
   ) = 0 OrElse shortcut_scan_code <> FB.SC_F5 OrElse _
   shortcut_modifiers <> INPUT_MODIFIER_NONE OrElse _
   menubar_GetItemShortcutText(bar_widget, file_menu, 0) <> "F5" OrElse _
   menubar_SetItemShortcut( _
       bar_widget, file_menu, 0, 256, INPUT_MODIFIER_NONE, "F5" _
   ) <> 0 OrElse menubar_SetItemShortcut( _
       bar_widget, file_menu, 0, FB.SC_F5, 8, "F5" _
   ) <> 0 OrElse menubar_SetItemShortcut( _
       bar_widget, file_menu, 1, FB.SC_F5, INPUT_MODIFIER_NONE, "F5" _
   ) <> 0 Then
    Print "FAIL shortcut binding API"
    failure_count += 1
End If

context_marker = 1
menubar_SetSelectionHandler _
    bar_widget, @menubarSmoke_OnSelection, @context_marker
gui_AddWidget bar_widget
gui_SetFocus bar_widget

input_MockKeyPress FB.SC_E, INPUT_MODIFIER_ALT
gui_UpdateAll
If menubar_GetOpenMenu(bar_widget) <> edit_menu Then
    Print "FAIL Alt heading mnemonic"
    failure_count += 1
End If
input_MockKeyPress KEY_RETURN
gui_UpdateAll
If menubar_selection_count <> 1 OrElse _
   menubar_selected_menu <> edit_menu OrElse menubar_selected_item <> 1 Then
    Print "FAIL disabled command keyboard skip"
    failure_count += 1
End If
menubar_SetItemEnabled bar_widget, edit_menu, 0, -1

If menubar_SetOpenMenu(bar_widget, file_menu) = 0 Then
    Print "FAIL programmatic open"
    failure_count += 1
End If
input_MockKeyPress KEY_DOWN
gui_UpdateAll
input_MockKeyPress KEY_RETURN
gui_UpdateAll
If menubar_selection_count <> 2 OrElse menubar_selected_menu <> file_menu _
   OrElse menubar_selected_item <> 2 OrElse _
   menubar_GetOpenMenu(bar_widget) <> -1 Then
    Print "FAIL keyboard separator skip and activation"
    failure_count += 1
End If

If menubar_SetOpenMenu(bar_widget, edit_menu) = 0 Then
    Print "FAIL second menu open"
    failure_count += 1
Else
    input_MockKeyPress KEY_LEFT
    gui_UpdateAll
    If menubar_GetOpenMenu(bar_widget) <> file_menu Then
        Print "FAIL keyboard heading wrap"
        failure_count += 1
    End If
    input_MockKeyPress KEY_ESCAPE
    gui_UpdateAll
    If menubar_GetOpenMenu(bar_widget) <> -1 Then
        Print "FAIL keyboard dismissal"
        failure_count += 1
    End If
End If

/'
    A pointer release on the first heading opens File. The first row begins
    immediately below the 22-pixel strip and selects New on release.
'/
input_MockMouse 20, 16, 1
gui_UpdateAll
input_MockMouse 20, 16, 0
gui_UpdateAll
input_MockMouse 20, 34, 1
gui_UpdateAll
input_MockMouse 20, 34, 0
gui_UpdateAll
If menubar_selection_count <> 3 OrElse menubar_selected_menu <> file_menu _
   OrElse menubar_selected_item <> 0 OrElse _
   menubar_GetOpenMenu(bar_widget) <> -1 Then
    Print "FAIL pointer opening and activation"
    failure_count += 1
End If

menubar_SetItemEnabled bar_widget, edit_menu, 0, 0
If menubar_ActivateItem(0, 0, 0) <> 0 OrElse _
   menubar_ActivateItem(bar_widget, -1, 0) <> 0 OrElse _
   menubar_ActivateItem(bar_widget, file_menu, 99) <> 0 OrElse _
   menubar_ActivateItem(bar_widget, file_menu, 1) <> 0 OrElse _
   menubar_ActivateItem(bar_widget, edit_menu, 0) <> 0 OrElse _
   menubar_selection_count <> 3 Then
    Print "FAIL programmatic activation guards"
    failure_count += 1
End If
menubar_SetOpenMenu bar_widget, file_menu
If menubar_ActivateItem(bar_widget, edit_menu, 1) = 0 OrElse _
   menubar_selection_count <> 4 OrElse menubar_selected_menu <> edit_menu OrElse _
   menubar_selected_item <> 1 OrElse menubar_GetOpenMenu(bar_widget) <> -1 Then
    Print "FAIL programmatic command activation"
    failure_count += 1
End If

/'
    A menu accelerator is process-wide inside its active form scope. No menu
    focus is required, and exact chords keep Ctrl+F5 from triggering plain F5.
'/
gui_SetFocus 0
input_MockKeyPress FB.SC_F5, INPUT_MODIFIER_CONTROL
gui_UpdateAll
If menubar_selection_count <> 4 Then
    Print "FAIL exact shortcut chord"
    failure_count += 1
End If
input_MockKeyPress FB.SC_F5
gui_UpdateAll
If menubar_selection_count <> 5 OrElse menubar_selected_menu <> file_menu _
   OrElse menubar_selected_item <> 0 Then
    Print "FAIL global shortcut activation"
    failure_count += 1
End If
menubar_SetItemEnabled bar_widget, file_menu, 0, 0
input_MockKeyPress FB.SC_F5
gui_UpdateAll
If menubar_selection_count <> 5 Then
    Print "FAIL disabled shortcut activation"
    failure_count += 1
End If
menubar_SetItemEnabled bar_widget, file_menu, 0, -1

backend_Clear RGB(200, 200, 200)
gui_RenderAll
backend_Flip
gui_ResetForTest
backend_Exit

If failure_count <> 0 Then
    Print "menubar_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "menubar_smoke: PASS"
End 0

/' end of menubar_smoke.bas '/
