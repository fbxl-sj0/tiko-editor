/'
    Project: omaGUI Tests
    File: splitter_smoke.bas
    Purpose: Exercise pane-divider interaction through the real GUI manager.
    Responsibilities:
        - verify capture, range limits, keyboard adjustment, and parent offsets
        - reject interrupted drags and preserve callback lifetime safety
        - exercise theme rendering and the public API's invalid inputs
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:
        - IDE pane policy or native operating-system input injection
'/

#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Type SplitterSmokeState
    As Integer changes, last_position, delete_on_change
    As Widget Ptr source_widget
End Type

Private Sub split_Require(ByVal success As Integer, ByVal source_line As Integer)
    If success Then Exit Sub
    backend_Exit
    Screen 0
    Print "splitter_smoke: FAIL at line "; source_line
    End 1
End Sub

Private Sub split_Pointer(ByVal x As Integer, ByVal y As Integer, ByVal buttons As Integer)
    input_MockMouse x, y, buttons
    gui_UpdateAll
End Sub

Private Sub split_Changed(ByVal context As Any Ptr, ByVal position As Integer)
    Dim As SplitterSmokeState Ptr state = Cast(SplitterSmokeState Ptr, context)
    state->changes += 1
    state->last_position = position
    If state->delete_on_change Then
        gui_RemoveWidgetPtr state->source_widget
        state->source_widget = 0
    End If
End Sub

backend_Init 640, 480, 0
split_Require ScreenPtr <> 0, __LINE__
gui_Init
input_ResetForTest

Dim As SplitterSmokeState state
Dim As Widget Ptr divider = splitter_Create("vertical", 160, 20, 8, 180)
split_Require divider <> 0, __LINE__
gui_AddWidget divider
state.source_widget = divider
split_Require splitter_SetRange(divider, 80, 400), __LINE__
split_Require splitter_SetChangeHandler(divider, @split_Changed, @state), __LINE__
gui_UpdateAll

' Pressing anywhere in the grip leaves the divider at its exact position.
split_Pointer 165, 40, 1
split_Require splitter_IsDragging(divider) AndAlso state.changes = 0, __LINE__
split_Pointer 205, 400, 1
split_Require splitter_GetPosition(divider) = 200 AndAlso state.changes = 1, __LINE__
split_Pointer -2147483647, 400, 1
split_Require splitter_GetPosition(divider) = 80, __LINE__
split_Pointer 2147483647, 400, 1
split_Require splitter_GetPosition(divider) = 400, __LINE__
split_Pointer 165, 40, 1
split_Require splitter_GetPosition(divider) = 160, __LINE__
' A release with movement is itself the final drag sample.
split_Pointer 185, 40, 0
split_Require splitter_GetPosition(divider) = 180 AndAlso splitter_IsDragging(divider) = 0, __LINE__
Dim As Integer changes_before = state.changes
split_Require splitter_SetPosition(divider, 200), __LINE__
split_Require state.changes = changes_before, __LINE__
split_Require splitter_SetRange(divider, 80, 190), __LINE__
split_Require splitter_GetPosition(divider) = 190 AndAlso state.changes = changes_before, __LINE__
Dim As Integer lower_limit, upper_limit
split_Require splitter_SetRange(divider, 200, 100) = 0, __LINE__
split_Require splitter_GetRange(divider, lower_limit, upper_limit), __LINE__
split_Require lower_limit = 80 AndAlso upper_limit = 190, __LINE__
split_Require splitter_SetRange(divider, 80, 400), __LINE__

gui_SetFocus divider
input_MockKeyPress KEY_RIGHT
gui_UpdateAll
split_Require splitter_GetPosition(divider) = 194, __LINE__
input_MockKeyPress KEY_LEFT, INPUT_MODIFIER_SHIFT
gui_UpdateAll
split_Require splitter_GetPosition(divider) = 178, __LINE__
input_MockKeyPress KEY_HOME, INPUT_MODIFIER_CONTROL
gui_UpdateAll
split_Require splitter_GetPosition(divider) = 178, __LINE__
input_MockKeyPress KEY_HOME
gui_UpdateAll
split_Require splitter_GetPosition(divider) = 80, __LINE__
input_MockKeyPress KEY_END
gui_UpdateAll
split_Require splitter_GetPosition(divider) = 400, __LINE__
changes_before = state.changes
input_MockKeyPress KEY_RIGHT
gui_UpdateAll
split_Require state.changes = changes_before, __LINE__

' A press that began on empty desktop cannot become a divider drag.
splitter_SetPosition divider, 160
split_Pointer 50, 40, 1
split_Pointer 163, 40, 1
split_Require splitter_IsDragging(divider) = 0, __LINE__
split_Pointer 163, 40, 0
split_Pointer 163, 40, 1
divider->enabled = 0
gui_UpdateAll
split_Require splitter_IsDragging(divider) = 0, __LINE__
divider->enabled = -1
split_Pointer 250, 40, 1
split_Require splitter_GetPosition(divider) = 160 AndAlso splitter_IsDragging(divider) = 0, __LINE__
split_Pointer 163, 40, 0
split_Pointer 163, 40, 1
divider->visible = 0
gui_UpdateAll
split_Require splitter_IsDragging(divider) = 0, __LINE__
divider->visible = -1
split_Pointer 200, 40, 1
split_Require splitter_GetPosition(divider) = 160, __LINE__
split_Pointer 163, 40, 0

Dim As Widget Ptr modal_widget = button_Create("modal", "OK", 420, 220, 60, 24)
gui_AddWidget modal_widget
split_Pointer 163, 40, 1
gui_SetModalRoot modal_widget
split_Require splitter_IsDragging(divider) = 0, __LINE__
gui_ClearModalRoot modal_widget
split_Pointer 200, 40, 1
split_Require splitter_GetPosition(divider) = 160, __LINE__
split_Pointer 163, 40, 0

' Parent offsets affect only hit testing; values stay parent-relative.
Dim As Widget Ptr parent_widget = groupbox_Create("pane", "Pane", 20, 230, 350, 200)
gui_AddWidget parent_widget
Dim As Widget Ptr horizontal = splitter_Create("horizontal", 10, 50, 300, 8, SPLITTER_HORIZONTAL)
split_Require horizontal <> 0, __LINE__
gui_AddWidget horizontal
gui_SetParent horizontal, parent_widget
split_Require splitter_SetRange(horizontal, 30, 150), __LINE__
gui_SynchronizeLayout
split_Pointer 100, 283, 1
split_Pointer 100, 313, 1
split_Require splitter_GetPosition(horizontal) = 80 AndAlso horizontal->ay = 310, __LINE__
split_Pointer 100, 313, 0
input_MockKeyPress KEY_DOWN
gui_UpdateAll
split_Require splitter_GetPosition(horizontal) = 84, __LINE__

For theme_mode As Integer = GUI_THEME_MODE_NORMAL To GUI_THEME_MODE_BLACK
    theme_SetMode theme_mode
    gui_RenderAll
    split_Require (Point(horizontal->ax, horizontal->ay) And &hFFFFFF) = _
        (current_theme.bg_face And &hFFFFFF), __LINE__
Next theme_mode

' Anchors retain a manually adjusted local position when a parent resizes.
gui_SetAnchors horizontal, GUI_ANCHOR_LEFT Or GUI_ANCHOR_TOP Or GUI_ANCHOR_RIGHT
splitter_SetPosition horizontal, 90
parent_widget->w += 20
gui_SetViewportSize 641, 480
split_Require horizontal->w = 320 AndAlso splitter_GetPosition(horizontal) = 90, __LINE__

split_Require splitter_SetPosition(modal_widget, 12) = 0, __LINE__
split_Require splitter_GetPosition(0) = -1 AndAlso splitter_IsDragging(0) = 0, __LINE__
split_Require splitter_SetRange(divider, -1, 12) = 0, __LINE__
split_Require splitter_Create("invalid", 0, 0, 0, 20) = 0, __LINE__
split_Require splitter_Create("invalid", 0, 0, 8, 20, 2) = 0, __LINE__

state.delete_on_change = -1
gui_SetFocus divider
input_MockKeyPress KEY_RIGHT
gui_UpdateAll
split_Require state.source_widget = 0 AndAlso gui_FindWidget("vertical") = 0, __LINE__

gui_ResetForTest
backend_Exit
Screen 0
Print "splitter_smoke: PASS (capture, keyboard, limits, interruption, parent layout, callback lifetime)"
End 0

/' end of splitter_smoke.bas '/
