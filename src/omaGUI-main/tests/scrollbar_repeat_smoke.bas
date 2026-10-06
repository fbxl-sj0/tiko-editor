/'
    Project: omaGUI Tests
    File: scrollbar_repeat_smoke.bas
    Purpose: Verify held scrollbar steps without wall-clock-dependent sleeps.
    Responsibilities:
        - check initial delay, repeat interval, and coalesced long pauses
        - pause paging at the pointer and retain the originally pressed region
        - cancel capture across parent visibility, enablement, and modal changes
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:
        - VBDOS event dispatch or platform-specific input injection
'/

#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub repeat_Require(ByVal success As Integer, ByVal source_line As Integer)
    If success Then Exit Sub
    Print "scrollbar_repeat_smoke: FAIL at line "; source_line
    End 1
End Sub

Private Sub repeat_Pointer(ByVal x As Integer, ByVal y As Integer, ByVal buttons As Integer)
    input_MockMouse x, y, buttons
    gui_UpdateAll
End Sub

backend_Init 320, 240, -1
gui_Init
input_ResetForTest
Dim As Widget Ptr parent_widget = New Widget
repeat_Require parent_widget <> 0, __LINE__
parent_widget->name = "repeat_parent"
parent_widget->w = 300
parent_widget->h = 220
parent_widget->enabled = -1
parent_widget->visible = -1
gui_AddWidget parent_widget
Dim As Widget Ptr scroll_widget = scrollbar_Create("repeat_scroll", 10, 10, 240, 20, 1000, 100, 0)
repeat_Require scroll_widget <> 0, __LINE__
gui_AddWidget scroll_widget
gui_SetParent scroll_widget, parent_widget
repeat_Require scrollbar_SetValue(scroll_widget, 500), __LINE__
repeat_Require scrollbar_SetChanges(scroll_widget, 3, 100), __LINE__
repeat_Require scrollbar_SetArrowButtons(scroll_widget, -1), __LINE__
scrollbar_SetAutomaticRepeat scroll_widget, 0
gui_UpdateAll

repeat_Pointer 15, 15, 1
repeat_Require scrollbar_GetValue(scroll_widget) = 497, __LINE__
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 399) = 0, __LINE__
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 1), __LINE__
repeat_Require scrollbar_GetValue(scroll_widget) = 494, __LINE__
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 49) = 0, __LINE__
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 1), __LINE__
repeat_Require scrollbar_GetValue(scroll_widget) = 491, __LINE__
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 500), __LINE__
repeat_Require scrollbar_GetValue(scroll_widget) = 488, __LINE__

' Leaving the pressed region resets its delay without selecting another part.
repeat_Pointer 100, 100, 1
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 1000) = 0, __LINE__
repeat_Pointer 15, 15, 1
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 399) = 0, __LINE__
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 1), __LINE__
repeat_Require scrollbar_GetValue(scroll_widget) = 485, __LINE__
repeat_Pointer 245, 15, 1
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 1000) = 0, __LINE__
repeat_Require scrollbar_GetValue(scroll_widget) = 485, __LINE__
repeat_Pointer 15, 15, 1
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 400), __LINE__
repeat_Require scrollbar_GetValue(scroll_widget) = 482, __LINE__
repeat_Pointer 15, 15, 0
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 1000) = 0, __LINE__

' At 700 the proportional thumb covers the held pointer. Further page steps
' pause there rather than alternating directions on either side of the thumb.
repeat_Require scrollbar_SetValue(scroll_widget, 500), __LINE__
repeat_Pointer 160, 15, 1
repeat_Require scrollbar_GetValue(scroll_widget) = 600, __LINE__
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 400), __LINE__
repeat_Require scrollbar_GetValue(scroll_widget) = 700, __LINE__
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 5000) = 0, __LINE__
repeat_Require scrollbar_GetValue(scroll_widget) = 700, __LINE__
repeat_Pointer 160, 15, 0

' The manager normally skips inactive widgets. Its cancel_input notification
' must still clear their private press state, even while the button stays down.
Dim As Widget Ptr modal_widget = New Widget
repeat_Require modal_widget <> 0, __LINE__
modal_widget->name = "repeat_modal"
modal_widget->x = 305
modal_widget->y = 225
modal_widget->w = 10
modal_widget->h = 10
modal_widget->visible = -1
modal_widget->enabled = -1
gui_AddWidget modal_widget
For interruption As Integer = 0 To 2
    repeat_Require scrollbar_SetValue(scroll_widget, 500), __LINE__
    repeat_Pointer 15, 15, 1
    repeat_Require scrollbar_GetValue(scroll_widget) = 497, __LINE__
    Select Case interruption
    Case 0: parent_widget->enabled = 0
    Case 1: parent_widget->visible = 0
    Case 2: gui_SetModalRoot modal_widget
    End Select
    gui_UpdateAll
    parent_widget->enabled = -1
    parent_widget->visible = -1
    gui_SetModalRoot 0
    gui_UpdateAll
    repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 5000) = 0, __LINE__
    repeat_Require scrollbar_GetValue(scroll_widget) = 497, __LINE__
    repeat_Pointer 15, 15, 0
    repeat_Pointer 15, 15, 1
    repeat_Require scrollbar_GetValue(scroll_widget) = 494, __LINE__
    repeat_Pointer 15, 15, 0
Next interruption

repeat_Require scrollbar_SetValue(scroll_widget, 500), __LINE__
repeat_Pointer 130, 15, 1
repeat_Require scrollbar_IsDragging(scroll_widget), __LINE__
parent_widget->visible = 0
gui_UpdateAll
repeat_Require scrollbar_IsDragging(scroll_widget) = 0, __LINE__
parent_widget->visible = -1
repeat_Pointer 180, 15, 1
repeat_Require scrollbar_GetValue(scroll_widget) = 500, __LINE__
repeat_Pointer 180, 15, 0

repeat_Require scrollbar_SetReverse(scroll_widget, -1), __LINE__
repeat_Pointer 15, 15, 1
repeat_Require scrollbar_GetValue(scroll_widget) = 503, __LINE__
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 400), __LINE__
repeat_Require scrollbar_GetValue(scroll_widget) = 506, __LINE__
repeat_Require scrollbar_SetValue(scroll_widget, 700), __LINE__
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 5000) = 0, __LINE__
repeat_Require scrollbar_GetValue(scroll_widget) = 700, __LINE__
repeat_Pointer 15, 15, 0

repeat_Require scrollbar_SetRepeat(scroll_widget, 400, 0), __LINE__
repeat_Pointer 15, 15, 1
repeat_Require scrollbar_GetValue(scroll_widget) = 703, __LINE__
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 5000) = 0, __LINE__
repeat_Pointer 15, 15, 0
repeat_Require scrollbar_SetRepeat(scroll_widget, -1, 50) = 0, __LINE__
repeat_Require scrollbar_SetRepeat(scroll_widget, 0, 65536) = 0, __LINE__
repeat_Require scrollbar_SetRepeat(scroll_widget, 65536, 50) = 0, __LINE__
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, -1) = 0, __LINE__
repeat_Require scrollbar_AdvanceRepeat(scroll_widget, 86400001.0) = 0, __LINE__
repeat_Require scrollbar_SetRepeat(0, 400, 50) = 0, __LINE__
repeat_Require scrollbar_AdvanceRepeat(0, 500) = 0, __LINE__
scrollbar_CancelPointer 0
scrollbar_SetAutomaticRepeat 0, 1

Dim As Widget Ptr vertical_widget = scrollbar_Create("repeat_vertical", 270, 10, 20, 180, 1000, 100, -1)
repeat_Require vertical_widget <> 0, __LINE__
gui_AddWidget vertical_widget
repeat_Require scrollbar_SetValue(vertical_widget, 500), __LINE__
repeat_Require scrollbar_SetChanges(vertical_widget, 3, 100), __LINE__
repeat_Require scrollbar_SetArrowButtons(vertical_widget, -1), __LINE__
scrollbar_SetAutomaticRepeat vertical_widget, 0
repeat_Pointer 275, 15, 1
repeat_Require scrollbar_GetValue(vertical_widget) = 497, __LINE__
repeat_Require scrollbar_AdvanceRepeat(vertical_widget, 400), __LINE__
repeat_Require scrollbar_GetValue(vertical_widget) = 494, __LINE__
gui_CancelInput parent_widget
repeat_Require scrollbar_AdvanceRepeat(vertical_widget, 50), __LINE__
repeat_Require scrollbar_GetValue(vertical_widget) = 491, __LINE__
gui_CancelInput 0
repeat_Require scrollbar_AdvanceRepeat(vertical_widget, 5000) = 0, __LINE__
repeat_Pointer 275, 15, 0
' Cancelling an idle control must not swallow the next genuine press.
gui_CancelInput 0
repeat_Pointer 275, 15, 1
repeat_Require scrollbar_GetValue(vertical_widget) = 488, __LINE__
input_SetDispatchMask 0, 0
scrollbar_CancelPointer vertical_widget
input_SetDispatchMask -1, -1
gui_UpdateAll
repeat_Require scrollbar_GetValue(vertical_widget) = 488, __LINE__
repeat_Require scrollbar_AdvanceRepeat(vertical_widget, 5000) = 0, __LINE__
repeat_Pointer 275, 15, 0

gui_ResetForTest
backend_Exit
Print "scrollbar_repeat_smoke: PASS (delay, interval, paging, interruption, reverse, vertical)"
End 0

/' end of scrollbar_repeat_smoke.bas '/
