/'
    Project: omaGUI Tests
    ---------------------

    File: label_smoke.bas

    Purpose:

        Verify retained Label foreground and background color state.

    Responsibilities:

        - construct and render a bounded Label in the headless backend
        - set and query literal black without confusing it with no override
        - clear the optional background while retaining the foreground

    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:

        - screenshot comparisons
        - application-specific label formatting
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim As Integer failureCount
Dim As ULong retainedColor
Dim As Widget Ptr labelWidget

backend_Init 240, 120, BACKEND_HEADLESS
gui_Init
labelWidget = label_Create( _
    "label_smoke", "Color state", 10, 10, RGB(30, 40, 50) _
)
If labelWidget = 0 Then
    Print "label_smoke: constructor failed"
    backend_Exit
    End 1
End If
labelWidget->w = 160
labelWidget->h = 24
gui_AddWidget labelWidget

If label_GetTextColor(labelWidget, retainedColor) = 0 OrElse _
   retainedColor <> RGB(30, 40, 50) Then
    Print "FAIL initial text color"
    failureCount += 1
End If
If label_SetTextColor(labelWidget, RGB(60, 70, 80)) = 0 OrElse _
   label_GetTextColor(labelWidget, retainedColor) = 0 OrElse _
   retainedColor <> RGB(60, 70, 80) Then
    Print "FAIL text color update"
    failureCount += 1
End If
If label_SetBackgroundColor(labelWidget, RGB(0, 0, 0)) = 0 OrElse _
   label_GetBackgroundColor(labelWidget, retainedColor) = 0 OrElse _
   retainedColor <> RGB(0, 0, 0) Then
    Print "FAIL literal black background"
    failureCount += 1
End If

backend_Clear RGB(200, 200, 200)
gui_RenderAll
backend_Flip
If label_ClearBackgroundColor(labelWidget) = 0 OrElse _
   label_GetBackgroundColor(labelWidget, retainedColor) <> 0 OrElse _
   label_GetTextColor(labelWidget, retainedColor) = 0 OrElse _
   retainedColor <> RGB(60, 70, 80) Then
    Print "FAIL background clear"
    failureCount += 1
End If
gui_ResetForTest
backend_Exit

If failureCount <> 0 Then
    Print "label_smoke: "; failureCount; " failure(s)"
    End 1
End If
Print "label_smoke: PASS"
End 0

/' end of label_smoke.bas '/
