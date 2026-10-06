/'
    Project: omaGUI Tests
    ---------------------

    File: timerwidget_smoke.bas

    Purpose:

        Verify deterministic Timer interval, coalescing, enable, and lifecycle
        behavior.

    Responsibilities:

        - advance a timer without sleeping or depending on host clock jitter
        - require one callback per completed update, including delayed frames
        - reject invalid intervals without changing retained state
        - initialize the normal GUI-clock update path

    This file intentionally does NOT contain:

        - wall-clock timing assertions
        - worker-thread behavior
        - native timer APIs
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim Shared As Integer timer_callback_count

Private Sub timerSmoke_OnTick(ByVal source_widget As Widget Ptr)
    If source_widget <> 0 Then timer_callback_count += 1
End Sub


Dim As Widget Ptr timer_widget
Dim As Integer advance_result
Dim As Integer failure_count

backend_Init 320, 240, BACKEND_HEADLESS
gui_Init

If timerwidget_Create("invalid_timer", 0) <> 0 Then
    Print "FAIL zero interval accepted"
    failure_count += 1
End If
timer_widget = timerwidget_Create( _
    "timer_smoke", 100, -1, @timerSmoke_OnTick _
)
If timer_widget = 0 Then
    Print "timerwidget_smoke: constructor failed"
    backend_Exit
    End 1
End If
gui_AddWidget timer_widget
If timer_widget->w <> 0 OrElse timer_widget->h <> 0 Then
    Print "FAIL nonvisual hit-test rectangle"
    failure_count += 1
End If

advance_result = timerwidget_Advance(timer_widget, 40.0)
If advance_result <> 0 Then
    Print "FAIL premature interval"
    failure_count += 1
End If

If timerwidget_Advance(timer_widget, -1.0) <> 0 Then
    Print "FAIL negative advancement accepted"
    failure_count += 1
End If
advance_result = timerwidget_Advance(timer_widget, 60.0)
If advance_result = 0 OrElse _
   timer_callback_count <> 1 OrElse _
   timerwidget_GetTickCount(timer_widget) <> 1 Then
    Print "FAIL accumulated interval"
    failure_count += 1
End If

advance_result = timerwidget_Advance(timer_widget, 350.0)
If advance_result = 0 OrElse _
   timer_callback_count <> 2 OrElse _
   timerwidget_GetTickCount(timer_widget) <> 2 Then
    Print "FAIL delayed-frame coalescing"
    failure_count += 1
End If

If timerwidget_SetEnabled(timer_widget, 0) = 0 OrElse _
   timerwidget_Advance(timer_widget, 1000.0) <> 0 OrElse _
   timer_callback_count <> 2 Then
    Print "FAIL disabled timer"
    failure_count += 1
End If

If timerwidget_SetInterval(timer_widget, -1) <> 0 OrElse _
   timerwidget_GetInterval(timer_widget) <> 100 OrElse _
   timerwidget_SetInterval(timer_widget, 250) = 0 OrElse _
   timerwidget_SetEnabled(timer_widget, -1) = 0 OrElse _
   timerwidget_GetEnabled(timer_widget) = 0 Then
    Print "FAIL checked timer state API"
    failure_count += 1
End If

timerwidget_Reset timer_widget
gui_UpdateAll
If timerwidget_GetTickCount(timer_widget) <> 0 Then
    Print "FAIL clock initialization emitted a tick"
    failure_count += 1
End If

gui_ResetForTest
backend_Exit
If failure_count <> 0 Then
    Print "timerwidget_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "timerwidget_smoke: PASS"
End 0

/' end of timerwidget_smoke.bas '/
