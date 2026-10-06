/'
    Project: omaGUI Tests
    ---------------------

    File: colordialog_smoke.bas

    Purpose:

        Verify modal classic-palette selection and result handling.

    Responsibilities:

        - construct the generated color dialog
        - activate a palette entry through its public widget tree
        - accept the selection and verify its stable result
        - verify the canonical palette mapping

    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:

        - native desktop interaction
        - screenshot comparisons
        - application theme changes
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim As Widget Ptr dialog_widget
Dim As Widget Ptr color_button
Dim As Widget Ptr accept_button
Dim As Integer failure_count

backend_Init 640, 480, -1
gui_Init
dialog_widget = colordialog_Create( _
    "color_smoke", "Choose a color", 70, 80, 3 _
)
gui_AddWidget dialog_widget
If dialog_widget = 0 OrElse colordialog_GetSelectedIndex(dialog_widget) <> 3 Then
    Print "FAIL color dialog construction"
    failure_count += 1
Else
    color_button = gui_FindWidget("color_smoke_color_12")
    accept_button = gui_FindWidget("color_smoke_accept")
    If color_button = 0 OrElse accept_button = 0 Then
        Print "FAIL generated color controls"
        failure_count += 1
    Else
        button_Activate color_button
        button_Activate accept_button
        If colordialog_GetSelectedIndex(dialog_widget) <> 12 OrElse _
           colordialog_GetResultState(dialog_widget) <> 1 Then
            Print "FAIL accepted color result"
            failure_count += 1
        End If
    End If
End If

If colordialog_GetClassicColor(12) <> RGB(255, 85, 85) Then
    Print "FAIL classic palette mapping"
    failure_count += 1
End If
backend_Clear RGB(220, 220, 220)
gui_UpdateAll
gui_RenderAll
backend_Flip
gui_ResetForTest
backend_Exit

If failure_count <> 0 Then
    Print "colordialog_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "colordialog_smoke: PASS"
End 0

/' end of colordialog_smoke.bas '/
