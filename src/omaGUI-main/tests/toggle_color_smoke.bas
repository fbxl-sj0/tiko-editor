/'
    Project: omaGUI Tests
    ---------------------

    File: toggle_color_smoke.bas

    Purpose:

        Verify retained CheckBox and RadioBox control colors.

    Responsibilities:

        - construct both toggle families in the headless backend
        - set and query literal client and indicator/text colors
        - clear every override before registry-owned destruction

    This file intentionally does NOT contain:

        - group-selection or pointer-input checks
        - screenshot comparisons
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim As Widget Ptr check_widget
Dim As Integer failure_count
Dim As Widget Ptr radio_widget
Dim As ULong retained_color

backend_Init 260, 140, BACKEND_HEADLESS
gui_Init
check_widget = checkbox_Create("check_color", "Check", 10, 10, -1)
radio_widget = radiobox_Create("radio_color", "Option", 10, 40, 1, -1)
If check_widget = 0 OrElse radio_widget = 0 Then
    Print "toggle_color_smoke: constructor failed"
    backend_Exit
    End 1
End If
check_widget->w = 120
check_widget->h = 20
radio_widget->w = 120
radio_widget->h = 20
gui_AddWidget check_widget
gui_AddWidget radio_widget

If checkbox_SetBackgroundColor(check_widget, RGB(1, 2, 3)) = 0 OrElse _
   checkbox_GetBackgroundColor(check_widget, retained_color) = 0 OrElse _
   retained_color <> RGB(1, 2, 3) OrElse _
   checkbox_SetForegroundColor(check_widget, RGB(4, 5, 6)) = 0 OrElse _
   checkbox_GetForegroundColor(check_widget, retained_color) = 0 OrElse _
   retained_color <> RGB(4, 5, 6) Then
    Print "FAIL CheckBox colors"
    failure_count += 1
End If
If radiobox_SetBackgroundColor(radio_widget, RGB(7, 8, 9)) = 0 OrElse _
   radiobox_GetBackgroundColor(radio_widget, retained_color) = 0 OrElse _
   retained_color <> RGB(7, 8, 9) OrElse _
   radiobox_SetForegroundColor(radio_widget, RGB(10, 11, 12)) = 0 OrElse _
   radiobox_GetForegroundColor(radio_widget, retained_color) = 0 OrElse _
   retained_color <> RGB(10, 11, 12) Then
    Print "FAIL RadioBox colors"
    failure_count += 1
End If

backend_Clear RGB(200, 200, 200)
gui_RenderAll
backend_Flip
If checkbox_ClearBackgroundColor(check_widget) = 0 OrElse _
   checkbox_ClearForegroundColor(check_widget) = 0 OrElse _
   checkbox_GetBackgroundColor(check_widget, retained_color) <> 0 OrElse _
   checkbox_GetForegroundColor(check_widget, retained_color) <> 0 OrElse _
   radiobox_ClearBackgroundColor(radio_widget) = 0 OrElse _
   radiobox_ClearForegroundColor(radio_widget) = 0 OrElse _
   radiobox_GetBackgroundColor(radio_widget, retained_color) <> 0 OrElse _
   radiobox_GetForegroundColor(radio_widget, retained_color) <> 0 Then
    Print "FAIL toggle color clear"
    failure_count += 1
End If

gui_ResetForTest
backend_Exit
If failure_count <> 0 Then
    Print "toggle_color_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "toggle_color_smoke: PASS"
End 0

/' end of toggle_color_smoke.bas '/
