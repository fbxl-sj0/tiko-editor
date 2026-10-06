/'
    Project: omaGUI Tests
    ---------------------

    File: scrollbar_api_smoke.bas

    Purpose:

        Verify signed scrollbar ranges and checked property setters.

    Responsibilities:

        - preserve imported negative and positive range endpoints
        - accept valid values and reject out-of-range values
        - retain validated SmallChange and LargeChange properties
        - clamp an existing value when a later valid range excludes it
        - change horizontal and vertical values through portable keys

    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:

        - pointer or wheel input simulation
        - VBDOS binary-form parsing
        - application-specific scrolling behavior
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim As Widget Ptr scroll_widget
Dim As Widget Ptr vertical_widget
Dim As ScrollBarData Ptr scroll_data
Dim As Integer failure_count

backend_Init 320, 240, -1
gui_Init
input_ResetForTest

scroll_widget = scrollbar_Create( _
    "scrollbar_api", 10, 10, 180, 18, 100, 10, 0 _
)
If scroll_widget = 0 Then
    Print "scrollbar_api_smoke: constructor failed"
    backend_Exit
    End 1
End If
gui_AddWidget scroll_widget

If scrollbar_SetRange(scroll_widget, -25, 75) = 0 OrElse _
   scrollbar_SetChanges(scroll_widget, 2, 10) = 0 OrElse _
   scrollbar_SetValue(scroll_widget, -10) = 0 OrElse _
   scrollbar_GetValue(scroll_widget) <> -10 Then
    Print "FAIL applying a signed range and value"
    failure_count += 1
End If

scroll_data = Cast(ScrollBarData Ptr, scroll_widget->data)
If scroll_data->min_val <> -25 OrElse scroll_data->max_val <> 75 OrElse _
   scroll_data->small_change <> 2 OrElse scroll_data->large_change <> 10 OrElse _
   scroll_data->page_size <> 10 Then
    Print "FAIL retaining range and increment properties"
    failure_count += 1
End If

gui_SetFocus scroll_widget
input_MockKeyPress KEY_RIGHT
gui_UpdateAll
If scrollbar_GetValue(scroll_widget) <> -8 Then
    Print "FAIL horizontal small keyboard change"
    failure_count += 1
End If
input_MockKeyPress FB.SC_PAGEDOWN
gui_UpdateAll
If scrollbar_GetValue(scroll_widget) <> 2 Then
    Print "FAIL horizontal large keyboard change"
    failure_count += 1
End If
input_MockKeyPress KEY_HOME
gui_UpdateAll
If scrollbar_GetValue(scroll_widget) <> -25 Then
    Print "FAIL keyboard range start"
    failure_count += 1
End If
input_MockKeyPress KEY_END
gui_UpdateAll
input_MockKeyPress KEY_RIGHT
gui_UpdateAll
If scrollbar_GetValue(scroll_widget) <> 75 Then
    Print "FAIL keyboard range end clamp"
    failure_count += 1
End If
scrollbar_SetValue scroll_widget, -10

vertical_widget = scrollbar_Create( _
    "vertical_scrollbar_api", 200, 10, 18, 150, 5, 4, -1 _
)
If vertical_widget = 0 Then
    Print "FAIL vertical constructor"
    failure_count += 1
Else
    gui_AddWidget vertical_widget
    scrollbar_SetRange vertical_widget, -5, 5
    scrollbar_SetChanges vertical_widget, 1, 4
    scrollbar_SetValue vertical_widget, 0
    gui_SetFocus vertical_widget
    input_MockKeyPress KEY_DOWN
    gui_UpdateAll
    input_MockKeyPress KEY_RIGHT
    gui_UpdateAll
    If scrollbar_GetValue(vertical_widget) <> 1 Then
        Print "FAIL vertical directional keyboard change"
        failure_count += 1
    End If
    input_MockKeyPress KEY_UP
    gui_UpdateAll
    input_MockKeyPress FB.SC_PAGEDOWN
    gui_UpdateAll
    input_MockKeyPress FB.SC_PAGEUP
    gui_UpdateAll
    If scrollbar_GetValue(vertical_widget) <> 0 Then
        Print "FAIL vertical page keyboard changes"
        failure_count += 1
    End If
End If

If scrollbar_SetValue(scroll_widget, 76) <> 0 OrElse _
   scrollbar_GetValue(scroll_widget) <> -10 OrElse _
   scrollbar_SetRange(scroll_widget, 10, -10) <> 0 Then
    Print "FAIL rejecting invalid scrollbar properties"
    failure_count += 1
End If

If scrollbar_SetRange(scroll_widget, 0, 5) = 0 OrElse _
   scrollbar_GetValue(scroll_widget) <> 0 Then
    Print "FAIL clamping after a valid range change"
    failure_count += 1
End If

scrollbar_Render scroll_widget
gui_ResetForTest
backend_Exit

If failure_count <> 0 Then
    Print "scrollbar_api_smoke: "; failure_count; " failure(s)"
    End 1
End If

Print "scrollbar_api_smoke: PASS"
End 0

/' end of scrollbar_api_smoke.bas '/
