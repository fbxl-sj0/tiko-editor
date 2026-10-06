/'
    Project: omaGUI Tests
    ---------------------

    File: button_color_smoke.bas

    Purpose:

        Verify the optional retained push-button face color.

    Responsibilities:

        - construct and render a button in the headless backend
        - distinguish a literal black override from theme-driven rendering
        - clear the override through the checked public API

    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:

        - pointer or keyboard activation checks
        - screenshot comparisons
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim As Integer failure_count
Dim As ULong retained_color
Dim As Widget Ptr test_button

backend_Init 240, 120, BACKEND_HEADLESS
gui_Init
test_button = button_Create("button_color", "Run", 10, 10, 100, 28)
If test_button = 0 Then
    Print "button_color_smoke: constructor failed"
    backend_Exit
    End 1
End If
gui_AddWidget test_button

If button_SetBackgroundColor(test_button, RGB(0, 0, 0)) = 0 OrElse _
   button_GetBackgroundColor(test_button, retained_color) = 0 OrElse _
   retained_color <> RGB(0, 0, 0) Then
    Print "FAIL literal black button face"
    failure_count += 1
End If
backend_Clear RGB(200, 200, 200)
gui_RenderAll
backend_Flip
If button_ClearBackgroundColor(test_button) = 0 OrElse _
   button_GetBackgroundColor(test_button, retained_color) <> 0 OrElse _
   button_SetBackgroundColor(0, RGB(1, 2, 3)) <> 0 Then
    Print "FAIL button color clear or null guard"
    failure_count += 1
End If

gui_ResetForTest
backend_Exit
If failure_count <> 0 Then
    Print "button_color_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "button_color_smoke: PASS"
End 0

/' end of button_color_smoke.bas '/
