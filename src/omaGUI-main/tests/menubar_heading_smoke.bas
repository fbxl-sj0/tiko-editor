/'
    Project: omaGUI Tests
    File: menubar_heading_smoke.bas
    Purpose: Verify mutable headings through native pointer/keyboard dispatch.
    Responsibilities: test compaction, disabled ancestry and cancellation.
    This file contains no platform menus or application command implementation.
'/
#lang "fb"
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"
Dim Shared As Integer checks, failures, activations
Private Sub Require(ByVal condition As Integer, ByRef description As Const String)
    checks += 1
    If condition Then Exit Sub
    failures += 1: Print "FAIL: "; description
End Sub
Private Sub OnSelection(ByVal context As Any Ptr, ByVal menu_index As Integer, ByVal item_index As Integer)
    activations += 1
End Sub
backend_Init(400, 300, BACKEND_HEADLESS)
gui_Init()
Dim As Widget Ptr bar_widget = menubar_Create("headings", 0, 0, 400)
gui_AddWidget(bar_widget)
For menu_index As Integer = 0 To 2
    Require(menubar_AddMenu(bar_widget, "&" & Chr(Asc("A") + menu_index)) = menu_index, "construct stable heading index")
    Require(menubar_AddItem(bar_widget, menu_index, "&Run") = 0, "construct command")
Next menu_index
menubar_SetSelectionHandler(bar_widget, @OnSelection, 0)
Require(menubar_SetItemShortcut(bar_widget, 0, 0, FB.SC_R, INPUT_MODIFIER_CONTROL, "Ctrl+R"), "bind accelerator")
Dim As MenuBarData Ptr bar_data = bar_widget->data
Dim As Integer original_left = bar_data->menu_left(1)
Require(menubar_SetMenuLabel(bar_widget, 0, "&Application"), "rename heading")
Require(menubar_GetMenuLabel(bar_widget, 0) = "&Application" AndAlso bar_data->menu_left(1) > original_left, "renaming recomputes following positions")
Require(menubar_SetMenuVisible(bar_widget, 0, 0), "hide first heading")
Require(bar_data->menu_left(1) = 0 AndAlso menubar_GetMenuVisible(bar_widget, 0) = 0, "visible headings compact without renumbering")
Require(menubar_ActivateItem(bar_widget, 0, 0) = 0, "hidden ancestor prevents direct command activation")
gui_SetFocus(bar_widget)
input_MockKeyPress(FB.SC_R, INPUT_MODIFIER_CONTROL)
gui_UpdateAll()
Require(activations = 0, "hidden ancestor prevents accelerators")
Require(menubar_SetMenuVisible(bar_widget, 0, -1), "show heading")
Require(menubar_SetMenuEnabled(bar_widget, 0, 0), "disable heading")
Require(menubar_GetItemEnabled(bar_widget, 0, 0) AndAlso menubar_ActivateItem(bar_widget, 0, 0) = 0, "disabled ancestor preserves child state but blocks commands")
input_MockKeyPress(FB.SC_A, INPUT_MODIFIER_ALT)
gui_UpdateAll()
Require(menubar_GetOpenMenu(bar_widget) = -1, "disabled heading cannot open by access key")
input_MockKeyPress(FB.SC_B, INPUT_MODIFIER_ALT)
gui_UpdateAll()
Require(menubar_GetOpenMenu(bar_widget) = 1, "available heading opens by access key")
input_MockKeyPress(FB.SC_LEFT)
gui_UpdateAll()
Require(menubar_GetOpenMenu(bar_widget) = 2, "keyboard wrap skips disabled heading")
Require(menubar_SetMenuVisible(bar_widget, 2, 0) AndAlso menubar_GetOpenMenu(bar_widget) = -1, "hiding an open heading closes its popup")
Require(menubar_SetMenuEnabled(bar_widget, 0, -1), "enable heading")
input_MockKeyPress(FB.SC_R, INPUT_MODIFIER_CONTROL)
gui_UpdateAll()
Require(activations = 1, "enabled accelerator fires once")
gui_UpdateAll()
Require(activations = 1, "idle frame does not repeat accelerator")
menubar_SetOpenMenu(bar_widget, 1)
Dim As Integer pointer_x = bar_widget->ax + bar_data->menu_left(1) + 10
Dim As Integer pointer_y = bar_widget->ay + MENUBAR_HEIGHT + 10
input_MockMouse(pointer_x, pointer_y, 1, 0)
gui_UpdateAll()
Require(menubar_SetMenuLabel(bar_widget, 1, "&Changed"), "rename while pointer is pressed")
input_MockMouse(pointer_x, pointer_y, 0, 0)
gui_UpdateAll()
Require(activations = 1, "metadata changes cancel pending release")
menubar_SetOpenMenu(bar_widget, 1)
gui_CancelInput(bar_widget)
Require(menubar_GetOpenMenu(bar_widget) = -1 AndAlso bar_widget->pointer_global = 0, "registry cancellation clears popup capture")
Require(menubar_SetMenuVisible(bar_widget, 15, 0) = 0 AndAlso menubar_SetMenuEnabled(0, 0, 0) = 0, "invalid heading/widget rejected")
Require(menubar_SetMenuLabel(bar_widget, 0, "") = 0 AndAlso menubar_SetMenuLabel(bar_widget, 0, String(161, "x")) = 0, "label bounds rejected atomically")
Require(menubar_GetMenuLabel(bar_widget, 0) = "&Application", "rejected label preserves caption")
menubar_SetMenuEnabled(bar_widget, 0, 0)
menubar_SetMenuEnabled(bar_widget, 1, 0)
menubar_Activate(bar_widget)
Require(menubar_GetOpenMenu(bar_widget) = -1, "no eligible heading leaves popup closed")
gui_RenderAll()
gui_RemoveWidgetPtr(bar_widget)
backend_Exit()
Print "menubar_heading_smoke: "; checks; " checks, "; failures; " failures"
If failures Then End 1
End 0
/' end of menubar_heading_smoke.bas '/
