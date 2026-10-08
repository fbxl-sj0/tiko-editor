/'
    Project: omaGUI Test Suite
    --------------------------

    File: menubar_nested_smoke.bas

    Purpose:
        Verify that menu-bar headings own and drive nested popup trees.

    Responsibilities:
        - attach portable Menu trees to MenuBar headings
        - test keyboard navigation, accelerators, and pointer dismissal
        - verify popup ownership, state changes, and cleanup

    This file intentionally does NOT contain:
        - application command policy
        - native operating-system menu calls

    Targets: FreeBASIC fb dialect with the native omaGUI backend.
    Module API boundary: Standalone development checks for the behavior described above.
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"
#include once "test_harness.bi"

Dim Shared As Integer nestedBarActivations
Dim Shared As Integer nestedBarCommand
Dim Shared As Integer nestedBarCheckCount


Private Sub nestedBar_Selected( _
    ByVal callback_context As Any Ptr, ByVal itemIndex As Integer _
)
    If gui_IsWidgetRegistered(Cast(Widget Ptr, callback_context)) = 0 Then Exit Sub
    Dim As MenuData Ptr menu_data = Cast(Widget Ptr, callback_context)->data
    If itemIndex < 0 OrElse itemIndex >= menu_data->count Then Exit Sub
    nestedBarCommand = menu_data->command_ids(itemIndex)
    nestedBarActivations += 1
End Sub


Private Sub nestedBar_Key(ByVal scanCode As Integer)
    input_MockKeyPress(scanCode)
    gui_UpdateAll
End Sub


Private Sub nestedBar_Mouse( _
    ByVal x As Integer, ByVal y As Integer, ByVal buttons As Integer _
)
    input_MockMouse(x, y, buttons)
    gui_UpdateAll
End Sub


Private Sub nestedBar_Require( _
    ByVal condition As Integer, ByVal description As String _
)
    nestedBarCheckCount += 1
    If condition <> 0 Then
        test_total_pass += 1
        Exit Sub
    End If
    test_total_fail += 1
    Print "  [FAIL] "; nestedBarCheckCount; ": "; description
    End 100 + nestedBarCheckCount
End Sub


backend_Init 640, 400, BACKEND_HEADLESS_DRAWABLE
gui_Init
input_ResetForTest
input_MockMouse(0, 0, 0)

Dim As Widget Ptr editor = textbox_Create( _
    "nested_menu_return_focus", "", 4, 4, 120, 24, 0, 0, _
    TEXTBOX_SCROLLBAR_NONE)
Dim As Widget Ptr bar = menubar_Create("nested_menu_bar", 0, 34, 640)
Dim As Widget Ptr file_popup = menu_Create("nested_file_popup", 0, 0)
Dim As Widget Ptr recent_popup = menu_Create("nested_recent_popup", 0, 0)
Dim As Widget Ptr edit_popup = menu_Create("nested_edit_popup", 0, 0)
If editor = 0 OrElse bar = 0 OrElse file_popup = 0 OrElse _
   recent_popup = 0 OrElse edit_popup = 0 Then
    Print "menubar_nested_smoke: construction failed"
    End 1
End If

gui_AddWidget editor
gui_AddWidget bar
gui_SetFocus editor

Dim As Integer file_heading = menubar_AddMenu(bar, "&File")
Dim As Integer edit_heading = menubar_AddMenu(bar, "&Edit")
menu_SetSelectionHandler(file_popup, @nestedBar_Selected, file_popup)
menu_AddCommand(recent_popup, "&Deep command", 73)
menu_SetSelectionHandler(recent_popup, @nestedBar_Selected, recent_popup)
menu_AddCommand(edit_popup, "Undo", 21)
menu_SetSelectionHandler(edit_popup, @nestedBar_Selected, edit_popup)

If menu_AddSubmenu(file_popup, "Recent", recent_popup) <> 0 Then
    Print "menubar_nested_smoke: could not build nested file menu"
    End 1
End If
menu_AddCommand(file_popup, "Open", 11)
If menu_SetItemShortcut( _
    recent_popup, 0, FB.SC_F5, INPUT_MODIFIER_NONE, "F5") = 0 Then
    Print "menubar_nested_smoke: could not configure nested accelerator"
    End 1
End If
nestedBar_Require(menu_SetItemShortcut( _
    recent_popup, 0, 256, INPUT_MODIFIER_NONE, "invalid") = 0, _
    "reject scan codes outside the gfxlib byte range")
nestedBar_Require(file_heading = 0 AndAlso edit_heading = 1, "headings retain stable indices")
nestedBar_Require(menubar_SetMenuPopup(bar, file_heading, file_popup), "attach nested File popup")
nestedBar_Require(menubar_SetMenuPopup(bar, edit_heading, edit_popup), "attach Edit popup")
nestedBar_Require( _
    menubar_GetItemCount(bar, file_heading) = 2 AndAlso _
    menubar_GetItemCount(bar, edit_heading) = 1, _
    "attached popup headings expose their live root row counts")
nestedBar_Require(file_popup->parent = bar AndAlso _
    menu_GetRoot(recent_popup) = file_popup, "popup tree is owned by its heading")
nestedBar_Require(menubar_GetMenuPopup(bar, file_heading) = file_popup, "popup can be queried")

test_Section("keyboard and shortcuts")
nestedBar_Require(menubar_SetOpenMenu(bar, file_heading), "open File popup")
nestedBar_Require(file_popup->visible AndAlso gui_GetFocus() = file_popup, "opening transfers focus to popup")
nestedBar_Key(KEY_RIGHT)
nestedBar_Require(recent_popup->visible AndAlso _
    menu_GetOpenLeaf(file_popup) = recent_popup, "Right opens a nested submenu")
nestedBar_Key(KEY_RETURN)
nestedBar_Require(nestedBarActivations = 1 AndAlso nestedBarCommand = 73, _
    "Enter dispatches the deeply nested command")
nestedBar_Require(menubar_GetOpenMenu(bar) = -1 AndAlso _
    gui_GetFocus() = editor, "selection closes the heading and restores focus")

input_MockKeyPress(FB.SC_F5)
gui_UpdateAll
nestedBar_Require(nestedBarActivations = 2 AndAlso nestedBarCommand = 73, _
    "nested accelerator works while its popup is closed")
nestedBar_Require(menubar_SetOpenMenu(bar, file_heading), _
    "reopen File before testing a popup mnemonic")
nestedBar_Key(KEY_RIGHT)
nestedBar_Key(FB.SC_D)
nestedBar_Require(nestedBarActivations = 3 AndAlso nestedBarCommand = 73, _
    "popup mnemonic activates its matching command")
nestedBar_Require(menu_TakeKeyboardHandled(file_popup), _
    "popup mnemonic reports that the key was consumed")

test_Section("visibility and pointer dismissal")
nestedBar_Require(menu_SetItemVisible(file_popup, 1, 0), "hide a top-level command")
nestedBar_Require(menu_GetVisibleItemCount(file_popup) = 1, "hidden commands are removed from popup layout")
nestedBar_Require(menubar_SetOpenMenu(bar, file_heading), "reopen File with a hidden item")
nestedBar_Mouse(610, 380, 1)
nestedBar_Mouse(610, 380, 0)
nestedBar_Require(file_popup->visible = 0 AndAlso menubar_GetOpenMenu(bar) = -1, _
    "outside pointer release dismisses the popup and synchronizes the heading")

nestedBar_Require(menubar_SetOpenMenu(bar, file_heading), "open File before heading hover")
Dim As MenuBarData Ptr bar_data = bar->data
Dim As Integer edit_x = bar->ax + bar_data->menu_left(edit_heading) + 2
Dim As Integer edit_y = bar->ay + 4
nestedBar_Mouse(edit_x, edit_y, 0)
nestedBar_Require(file_popup->visible = 0 AndAlso edit_popup->visible <> 0 AndAlso _
    menubar_GetOpenMenu(bar) = edit_heading, _
    "hovering another heading switches its nested popup")
nestedBar_Require(menubar_SetMenuVisible(bar, edit_heading, 0), "hide an open heading")
nestedBar_Require(edit_popup->visible = 0 AndAlso menubar_GetOpenMenu(bar) = -1, _
    "hiding the active heading closes its popup")

test_Section("lifetime")
nestedBar_Require(gui_RemoveWidgetPtr(bar), "remove the owning MenuBar tree")
nestedBar_Require(gui_FindWidget("nested_file_popup") = 0 AndAlso _
    gui_FindWidget("nested_recent_popup") = 0 AndAlso _
    gui_FindWidget("nested_edit_popup") = 0, _
    "removing the owner releases all attached popup levels")

gui_ResetForTest
backend_Exit
Screen 0
test_Summary
/' end of menubar_nested_smoke.bas '/
