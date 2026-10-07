/'
    Project: omaGUI Tests
    ---------------------

    File: spinbutton_smoke.bas

    Purpose:

        Verify bounded SpinButton pointer, keyboard, callback, and wrap logic.

    Responsibilities:

        - exercise both orientations with deterministic input
        - verify endpoint wrapping and rejected invalid values
        - render and destroy the widget through the normal GUI registry

    This file intentionally does NOT contain:

        - native desktop-window interaction
        - application-specific SpinDemo state
        - screenshot comparisons
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim Shared As Integer spin_change_count
Dim Shared As Integer spin_step_count, spin_last_direction, spin_destroyed

Private Sub spinSmoke_OnChange(ByVal source_widget As Widget Ptr)
    If source_widget <> 0 Then spin_change_count += 1
End Sub

Private Sub spinSmoke_OnStep(ByVal source_widget As Widget Ptr, ByVal direction_value As Integer)
    If source_widget = 0 Then Exit Sub
    spin_step_count += 1
    spin_last_direction = direction_value
End Sub

Private Sub spinSmoke_DestroyOnStep(ByVal source_widget As Widget Ptr, ByVal direction_value As Integer)
    spinbutton_Destroy source_widget
    Delete source_widget
    spin_destroyed = -1
End Sub


Dim As Widget Ptr vertical_spin
Dim As Widget Ptr horizontal_spin
Dim As Integer failure_count

backend_Init 320, 240, BACKEND_HEADLESS
gui_Init

vertical_spin = spinbutton_Create( _
    "vertical_spin", 10, 10, 24, 48, 0, 2, 0, _
    SPINBUTTON_VERTICAL, @spinSmoke_OnChange _
)
horizontal_spin = spinbutton_Create( _
    "horizontal_spin", 50, 10, 64, 24, 0, 2, 0, _
    SPINBUTTON_HORIZONTAL, @spinSmoke_OnChange _
)
If vertical_spin = 0 OrElse horizontal_spin = 0 Then
    Print "spinbutton_smoke: constructor failed"
    gui_ResetForTest
    backend_Exit
    End 1
End If
gui_AddWidget vertical_spin
gui_AddWidget horizontal_spin

input_MockMouse 20, 18, 1
gui_UpdateAll
input_MockMouse 20, 18, 0
gui_UpdateAll
If spinbutton_GetValue(vertical_spin) <> 1 Then
    Print "FAIL vertical increment"
    failure_count += 1
End If

input_MockMouse 20, 48, 1
gui_UpdateAll
input_MockMouse 20, 48, 0
gui_UpdateAll
If spinbutton_GetValue(vertical_spin) <> 0 Then
    Print "FAIL vertical decrement"
    failure_count += 1
End If

input_MockMouse 20, 48, 1
gui_UpdateAll
input_MockMouse 20, 48, 0
gui_UpdateAll
If spinbutton_GetValue(vertical_spin) <> 2 OrElse _
   spin_change_count <> 3 Then
    Print "FAIL wrapped decrement or callback count"
    failure_count += 1
End If

If spinbutton_SetValue(vertical_spin, 3) <> 0 OrElse _
   spinbutton_GetValue(vertical_spin) <> 2 OrElse _
   spinbutton_SetRange(vertical_spin, 5, 4) <> 0 Then
    Print "FAIL invalid API input rejection"
    failure_count += 1
End If

gui_SetFocus horizontal_spin
input_MockKeyPress KEY_RIGHT
gui_UpdateAll
If spinbutton_GetValue(horizontal_spin) <> 1 OrElse _
   spin_change_count <> 4 Then
    Print "FAIL horizontal keyboard increment"
    failure_count += 1
End If

' Repeat is opt-in. The existing release-triggered and change-only API stays intact.
If spinbutton_SetStepHandler(vertical_spin, @spinSmoke_OnStep) = 0 OrElse _
   spinbutton_SetRepeat(vertical_spin, 50) = 0 OrElse _
   spinbutton_SetRepeat(vertical_spin, -1) <> 0 OrElse _
   spinbutton_SetRepeat(vertical_spin, 65536) <> 0 Then failure_count += 1
spinbutton_SetAutomaticRepeat vertical_spin, 0
input_ResetForTest
input_MockMouse 20, 18, 1
gui_UpdateAll
If spinbutton_GetValue(vertical_spin) <> 0 OrElse spin_step_count <> 1 OrElse _
   spin_last_direction <> 1 OrElse spin_change_count <> 4 Then failure_count += 1
If spinbutton_AdvanceRepeat(vertical_spin, 49) <> 0 OrElse _
   spinbutton_GetValue(vertical_spin) <> 0 Then failure_count += 1
If spinbutton_AdvanceRepeat(vertical_spin, 1) = 0 OrElse _
   spinbutton_GetValue(vertical_spin) <> 1 Then failure_count += 1
If spinbutton_AdvanceRepeat(vertical_spin, 500) = 0 OrElse _
   spinbutton_GetValue(vertical_spin) <> 2 OrElse spin_step_count <> 3 Then failure_count += 1
input_MockMouse 20, 18, 0
gui_UpdateAll
If spin_step_count <> 3 OrElse spinbutton_AdvanceRepeat(vertical_spin, 50) <> 0 Then _
    failure_count += 1
If spinbutton_AdvanceRepeat(vertical_spin, -1) <> 0 OrElse _
   spinbutton_AdvanceRepeat(vertical_spin, 86400001.0) <> 0 Then failure_count += 1
If spinbutton_SetOrientation(vertical_spin, SPINBUTTON_HORIZONTAL) = 0 OrElse _
   spinbutton_SetOrientation(vertical_spin, 2) <> 0 Then failure_count += 1
If spinbutton_SetRange(vertical_spin, 7, 7) = 0 OrElse _
   spinbutton_Step(vertical_spin, -1) = 0 OrElse _
   spin_last_direction <> -1 OrElse spin_step_count <> 4 OrElse _
   spinbutton_GetValue(vertical_spin) <> 7 Then failure_count += 1
vertical_spin->enabled = 0
If spinbutton_Step(vertical_spin, 1) <> 0 OrElse _
   spinbutton_Step(vertical_spin, 2) <> 0 Then failure_count += 1
vertical_spin->enabled = -1

' A caller may destroy an unregistered widget inside its notification.
Dim As Widget Ptr transient_spin = spinbutton_Create("transient", 0, 0, 20, 40, 0, 1, 0)
If transient_spin = 0 Then
    failure_count += 1
Else
    spinbutton_SetStepHandler transient_spin, @spinSmoke_DestroyOnStep
    If spinbutton_Step(transient_spin, 1) = 0 OrElse spin_destroyed = 0 Then failure_count += 1
    transient_spin = 0
End If

backend_Clear RGB(200, 200, 200)
gui_RenderAll
backend_Flip
gui_ResetForTest
backend_Exit

If failure_count <> 0 Then
    Print "spinbutton_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "spinbutton_smoke: PASS (input, repeat, direction, singleton, callback destruction)"
End 0

/' end of spinbutton_smoke.bas '/
