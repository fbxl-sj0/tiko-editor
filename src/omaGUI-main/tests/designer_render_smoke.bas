/'
    Project: omaGUI tests
    File: designer_render_smoke.bas
    Purpose: Verify fixed-rectangle rendering without an input update.
    Responsibilities:
        - position an owned list scrollbar on first render and after movement
        - check opt-in label clipping and restoration of the caller's clip
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:
        - VB source handlers or visible desktop interaction
'/

#lang "fb"
#define OMAGUI_IMPLEMENTATION
#define OMAGUI_PORTABLE_ONLY
#include once "omaGUI.bi"

Dim As Integer failures
ScreenControl FB.SET_DRIVER_NAME, "null"
backend_Init 240, 180, 0
Dim As Integer screen_width, screen_height, screen_depth
ScreenInfo screen_width, screen_height, screen_depth
If screen_width <> 240 OrElse screen_height <> 180 OrElse screen_depth <> 32 Then
    backend_Exit
    Screen 0
    Print "designer_render_smoke: unable to create the null graphics surface"
    End 1
End If
gui_Init
Dim As Widget Ptr list_widget = listbox_Create("layout", 30, 40, 100, 60)
Dim As Widget Ptr label_widget = label_Create("clipped", "WWWWWWWWWWWW", 20, 120, RGB(255, 255, 255))
If list_widget = 0 OrElse label_widget = 0 Then End 1
gui_AddWidget list_widget
gui_AddWidget label_widget
label_widget->w = 16
label_widget->h = 16
For item_index As Integer = 1 To 20
    listbox_AddItem list_widget, LTrim(Str(item_index))
Next item_index
gui_SynchronizeLayout
listbox_Render list_widget
Dim As Widget Ptr scrollbar_widget = Cast(ListBoxData Ptr, list_widget->data)->scrollbar
If scrollbar_widget->ax <> 115 OrElse scrollbar_widget->ay <> 40 OrElse scrollbar_widget->h <> 60 Then failures += 1
list_widget->x = 50
list_widget->y = 60
list_widget->w = 140
list_widget->h = 80
gui_SynchronizeLayout
listbox_Render list_widget
If scrollbar_widget->ax <> 175 OrElse scrollbar_widget->ay <> 60 OrElse scrollbar_widget->h <> 80 Then failures += 1
If listbox_GetSelectedIndex(list_widget) <> -1 OrElse listbox_GetActivationCount(list_widget) <> 0 Then failures += 1

' Render to the ordinary 32-bit work page. No Flip or input update is needed
' for Point to inspect these pixels while the null graphics driver is active.
backend_Clear RGB(0, 0, 0)
If label_GetClipToBounds(label_widget) <> 0 Then failures += 1
label_Render label_widget
Dim As Integer overflow_pixels
For y As Integer = 120 To 135
    For x As Integer = 36 To 150
        If (CULng(Point(x, y)) And &hFFFFFFUL) <> 0 Then overflow_pixels += 1
    Next x
Next y
If overflow_pixels = 0 Then failures += 1
backend_Clear RGB(0, 0, 0)
If label_SetClipToBounds(label_widget, -1) = 0 OrElse label_GetClipToBounds(label_widget) = 0 Then failures += 1
If label_SetClipToBounds(list_widget, -1) <> 0 Then failures += 1
backend_SetClip 0, 0, 100, 180
label_Render label_widget
backend_PSet 80, 10, RGB(255, 0, 0)
backend_PSet 110, 10, RGB(255, 0, 0)
backend_ResetClip
Dim As Integer inside_pixels
For y As Integer = 120 To 135
    For x As Integer = 20 To 150
        If (CULng(Point(x, y)) And &hFFFFFFUL) <> 0 Then
            If x < 36 Then inside_pixels += 1 Else failures += 1
        End If
    Next x
Next y
If inside_pixels = 0 Then failures += 1
If (CULng(Point(80, 10)) And &hFFFFFFUL) <> &hFF0000UL OrElse _
    (CULng(Point(110, 10)) And &hFFFFFFUL) <> 0 Then failures += 1
gui_ResetForTest
backend_Exit
Screen 0
If failures Then
    Print "designer_render_smoke: FAIL "; failures
    End 1
End If
Print "designer_render_smoke: PASS"

/' end of designer_render_smoke.bas '/
