/'
    Project: omaGUI Tests
    ---------------------

    File: statusbar_smoke.bas

    Purpose:

        Verify bounded status-bar panels and headless rendering.

    Responsibilities:

        - construct flexible and fixed-width panels
        - update and query panel text and alignment through checked APIs
        - reject invalid indexes, widths, alignments, and oversized text
        - render a narrow layout without overflowing panel geometry

    This file intentionally does NOT contain:

        - application-specific status messages
        - screenshot comparison
        - native operating-system status-bar calls
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim As Widget Ptr bar_widget
Dim As Integer failure_count

backend_Init 160, 80, BACKEND_HEADLESS
gui_Init
bar_widget = statusbar_Create("statusbar_smoke", 0, 50, 160, 24)
If bar_widget = 0 Then
    Print "statusbar_smoke: constructor failed"
    backend_Exit
    End 1
End If
If statusbar_AddPanel(bar_widget, "Ready", 0) <> 0 OrElse _
   statusbar_AddPanel(bar_widget, "Ln 1, Col 1", 90) <> 1 OrElse _
   statusbar_GetPanelCount(bar_widget) <> 2 OrElse _
   statusbar_SetPanelText(bar_widget, 0, "Working") = 0 OrElse _
   statusbar_GetPanelText(bar_widget, 0) <> "Working" OrElse _
   statusbar_GetPanelAlignment( _
       bar_widget, 0 _
   ) <> BACKEND_ALIGN_LEFT OrElse _
   statusbar_SetPanelAlignment( _
       bar_widget, 1, BACKEND_ALIGN_RIGHT _
   ) = 0 OrElse _
   statusbar_GetPanelAlignment(bar_widget, 1) <> BACKEND_ALIGN_RIGHT Then
    Print "FAIL panel metadata"
    failure_count += 1
End If
If statusbar_AddPanel(bar_widget, "bad", -1) <> -1 OrElse _
   statusbar_SetPanelText(bar_widget, 9, "bad") <> 0 OrElse _
   statusbar_SetPanelAlignment( _
       bar_widget, 2, BACKEND_ALIGN_CENTER _
   ) <> 0 OrElse _
   statusbar_SetPanelAlignment( _
       bar_widget, 1, BACKEND_ALIGN_RIGHT + 1 _
   ) <> 0 OrElse _
   statusbar_GetPanelAlignment( _
       bar_widget, 2 _
   ) <> BACKEND_ALIGN_LEFT OrElse _
   statusbar_SetPanelText( _
       bar_widget, 0, String(STATUSBAR_MAX_TEXT_BYTES + 1, "X") _
   ) <> 0 Then
    Print "FAIL bounded rejection"
    failure_count += 1
End If

gui_AddWidget bar_widget
backend_Clear RGB(200, 200, 200)
gui_UpdateAll
gui_RenderAll
backend_Flip
gui_ResetForTest
backend_Exit

If failure_count <> 0 Then
    Print "statusbar_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "statusbar_smoke: PASS"
End 0

/' end of statusbar_smoke.bas '/
