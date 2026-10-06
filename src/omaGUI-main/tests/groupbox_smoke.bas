/'
    Project: omaGUI Tests
    ---------------------

    File: groupbox_smoke.bas

    Purpose:

        Verify GroupBox construction, caption replacement, and lifecycle.

    Responsibilities:

        - create a bounded frame in the headless backend
        - replace its retained caption through the public API
        - set, query, and clear retained client and caption colors
        - render and destroy it through the ordinary widget registry

    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:

        - screenshot comparisons
        - child layout behavior
        - native desktop-window interaction
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim As GroupBoxData Ptr group_data
Dim As Widget Ptr group_widget
Dim As Integer failure_count
Dim As ULong retained_color

backend_Init 320, 240, BACKEND_HEADLESS
gui_Init
group_widget = groupbox_Create("group_smoke", "Original", 10, 10, 180, 90)
If group_widget = 0 Then
    Print "groupbox_smoke: constructor failed"
    backend_Exit
    End 1
End If

If groupbox_SetBackgroundColor( _
    group_widget, RGB(10, 20, 30) _
) = 0 OrElse groupbox_GetBackgroundColor( _
    group_widget, retained_color _
) = 0 OrElse retained_color <> RGB(10, 20, 30) Then
    Print "FAIL group background color"
    failure_count += 1
End If
If groupbox_SetForegroundColor( _
    group_widget, RGB(40, 50, 60) _
) = 0 OrElse groupbox_GetForegroundColor( _
    group_widget, retained_color _
) = 0 OrElse retained_color <> RGB(40, 50, 60) Then
    Print "FAIL group foreground color"
    failure_count += 1
End If
gui_AddWidget group_widget

If groupbox_SetText(group_widget, "Updated frame") = 0 Then
    Print "FAIL replacing group caption"
    failure_count += 1
Else
    group_data = Cast(GroupBoxData Ptr, group_widget->data)
    If group_data->text <> "Updated frame" Then
        Print "FAIL retained group caption"
        failure_count += 1
    End If
End If

backend_Clear RGB(200, 200, 200)
gui_RenderAll
backend_Flip
If groupbox_ClearBackgroundColor(group_widget) = 0 OrElse _
   groupbox_GetBackgroundColor(group_widget, retained_color) <> 0 OrElse _
   groupbox_ClearForegroundColor(group_widget) = 0 OrElse _
   groupbox_GetForegroundColor(group_widget, retained_color) <> 0 Then
    Print "FAIL group color clear"
    failure_count += 1
End If
gui_ResetForTest
backend_Exit

If failure_count <> 0 Then
    Print "groupbox_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "groupbox_smoke: PASS"
End 0

/' end of groupbox_smoke.bas '/
