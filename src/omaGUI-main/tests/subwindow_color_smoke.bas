/'
    Project: omaGUI Tests
    ---------------------

    File: subwindow_color_smoke.bas

    Purpose:

        Verify retained child-window colors, borders, title controls, sizing,
        and window state.

    Responsibilities:

        - set and query one explicit portable client color
        - retain none, single, sizable-single, and double border modes
        - resize only a sizable window through captured pointer input
        - clamp the resized rectangle to the GUI viewport
        - minimize to a title bar and suspend descendant input
        - maximize to the viewport and restore the exact normal rectangle
        - enable and disable portable close, minimize, and maximize buttons
        - drive maximize, restore, and minimize through title-button clicks
        - track viewport changes while a window is minimized or maximized
        - keep a borderless minimized title surface visible and draggable
        - render the child window through the headless backend
        - clear the override before registry-owned destruction

    This file intentionally does NOT contain:

        - title-bar palette customization
        - close-handler or child-clipping checks
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim As ULong color_value
Dim As Integer border_style
Dim As Integer failure_count
Dim As Integer title_button_value
Dim As Integer window_state
Dim As Widget Ptr state_button
Dim As Widget Ptr window_widget

backend_Init 240, 160, BACKEND_HEADLESS
gui_Init
input_ResetForTest
window_widget = subwindow_Create( _
    "color_window", "Client Color", 10, 10, 180, 110, 0 _
)
If window_widget = 0 Then
    Print "subwindow_color_smoke: constructor failed"
    backend_Exit
    End 1
End If
gui_AddWidget window_widget
state_button = button_Create( _
    "state_button", "Child", 12, 30, 72, 24 _
)
If state_button = 0 Then
    Print "subwindow_color_smoke: child constructor failed"
    gui_ResetForTest
    backend_Exit
    End 1
End If
gui_AddWidget state_button
gui_SetParent state_button, window_widget

If subwindow_SetClientColor(window_widget, RGB(12, 34, 56)) = 0 OrElse _
   subwindow_GetClientColor(window_widget, color_value) = 0 OrElse _
   color_value <> RGB(12, 34, 56) Then
    Print "FAIL SubWindow client color"
    failure_count += 1
End If
If subwindow_GetBorderStyle(window_widget, border_style) = 0 OrElse _
   border_style <> SUBWINDOW_BORDER_FIXED_SINGLE OrElse _
   subwindow_SetBorderStyle( _
       window_widget, SUBWINDOW_BORDER_FIXED_DOUBLE _
   ) = 0 OrElse subwindow_GetBorderStyle( _
       window_widget, border_style _
   ) = 0 OrElse border_style <> SUBWINDOW_BORDER_FIXED_DOUBLE OrElse _
   window_widget->child_clip_x <> 2 OrElse _
   subwindow_GetClientTopInset(window_widget) <> 20 Then
    Print "FAIL SubWindow double border"
    failure_count += 1
End If
backend_Clear RGB(200, 200, 200)
gui_RenderAll
backend_Flip

If subwindow_SetBorderStyle(window_widget, SUBWINDOW_BORDER_NONE) = 0 OrElse _
   subwindow_GetClientTopInset(window_widget) <> 0 OrElse _
   subwindow_SetBorderStyle(window_widget, 4) <> 0 OrElse _
   subwindow_GetBorderStyle(window_widget, border_style) = 0 OrElse _
   border_style <> SUBWINDOW_BORDER_NONE Then
    Print "FAIL SubWindow border validation"
    failure_count += 1
End If
gui_RenderAll
If subwindow_SetBorderStyle( _
    window_widget, SUBWINDOW_BORDER_SIZABLE_SINGLE _
) = 0 OrElse subwindow_GetClientTopInset(window_widget) <> 20 Then
    Print "FAIL SubWindow sizable single border"
    failure_count += 1
End If

' The final pixel belongs to the resize border rather than the form client.
input_MockMouse window_widget->ax + window_widget->w - 1, _
    window_widget->ay + window_widget->h - 1, 1
gui_UpdateAll
If subwindow_IsResizing(window_widget) = 0 Then
    Print "FAIL SubWindow resize capture"
    failure_count += 1
End If
input_MockMouse window_widget->ax + window_widget->w + 23, _
    window_widget->ay + window_widget->h + 17, 1
gui_UpdateAll
If window_widget->w <> 204 OrElse window_widget->h <> 128 Then
    Print "FAIL SubWindow pointer resize"
    failure_count += 1
End If
input_MockMouse window_widget->ax + window_widget->w - 1, _
    window_widget->ay + window_widget->h - 1, 0
gui_UpdateAll
If subwindow_IsResizing(window_widget) <> 0 Then
    Print "FAIL SubWindow resize release"
    failure_count += 1
End If

' The root window begins at 10,10 in a 240x160 viewport.
input_MockMouse window_widget->ax + window_widget->w - 1, _
    window_widget->ay + window_widget->h - 1, 1
gui_UpdateAll
input_MockMouse 1000, 1000, 1
gui_UpdateAll
input_MockMouse 1000, 1000, 0
gui_UpdateAll
If window_widget->w <> 230 OrElse window_widget->h <> 150 Then
    Print "FAIL SubWindow resize viewport clamp"
    failure_count += 1
End If

If subwindow_SetBorderStyle( _
    window_widget, SUBWINDOW_BORDER_FIXED_SINGLE _
) = 0 Then
    Print "FAIL SubWindow fixed border restore"
    failure_count += 1
End If
Dim As Integer fixed_width = window_widget->w
Dim As Integer fixed_height = window_widget->h
input_MockMouse window_widget->ax + window_widget->w - 1, _
    window_widget->ay + window_widget->h - 1, 1
gui_UpdateAll
input_MockMouse window_widget->ax + window_widget->w - 20, _
    window_widget->ay + window_widget->h - 20, 1
gui_UpdateAll
input_MockMouse window_widget->ax + window_widget->w - 20, _
    window_widget->ay + window_widget->h - 20, 0
gui_UpdateAll
If window_widget->w <> fixed_width OrElse _
   window_widget->h <> fixed_height Then
    Print "FAIL SubWindow fixed border resized"
    failure_count += 1
End If

' Window states preserve the last normal rectangle across direct transitions.
' A minimized parent remains interactive, but its controls cannot retain or
' receive keyboard focus while their client area is collapsed.
Dim As Integer normal_x = window_widget->x
Dim As Integer normal_y = window_widget->y
Dim As Integer normal_width = window_widget->w
Dim As Integer normal_height = window_widget->h
gui_SetFocus state_button
If subwindow_SetWindowState( _
    window_widget, SUBWINDOW_STATE_MINIMIZED _
) = 0 Then
    Print "FAIL SubWindow minimize"
    failure_count += 1
End If
gui_SynchronizeLayout
If subwindow_GetWindowState(window_widget, window_state) = 0 OrElse _
   window_state <> SUBWINDOW_STATE_MINIMIZED OrElse _
   window_widget->w <> 180 OrElse window_widget->h <> 20 OrElse _
   window_widget->y <> 140 OrElse window_widget->suspend_children = 0 OrElse _
   state_button->een <> 0 OrElse gui_GetFocus() <> 0 Then
    Print "FAIL SubWindow minimized geometry or child input"
    failure_count += 1
End If
If subwindow_SetWindowState( _
    window_widget, SUBWINDOW_STATE_MAXIMIZED _
) = 0 Then
    Print "FAIL SubWindow maximize"
    failure_count += 1
End If
gui_SynchronizeLayout
If subwindow_GetWindowState(window_widget, window_state) = 0 OrElse _
   window_state <> SUBWINDOW_STATE_MAXIMIZED OrElse _
   window_widget->x <> 0 OrElse window_widget->y <> 0 OrElse _
   window_widget->w <> 240 OrElse window_widget->h <> 160 OrElse _
   window_widget->suspend_children <> 0 OrElse state_button->een = 0 Then
    Print "FAIL SubWindow maximized geometry"
    failure_count += 1
End If
gui_SetViewportSize 300, 200
subwindow_Update window_widget
gui_SynchronizeLayout
If window_widget->x <> 0 OrElse window_widget->y <> 0 OrElse _
   window_widget->w <> 300 OrElse window_widget->h <> 200 Then
    Print "FAIL SubWindow maximized viewport tracking"
    failure_count += 1
End If
If subwindow_SetWindowState( _
    window_widget, SUBWINDOW_STATE_MINIMIZED _
) = 0 Then
    Print "FAIL SubWindow dynamic minimize"
    failure_count += 1
End If
gui_SetViewportSize 160, 90
subwindow_Update window_widget
gui_SynchronizeLayout
If window_widget->x <> 0 OrElse window_widget->y <> 70 OrElse _
   window_widget->w <> 160 OrElse window_widget->h <> 20 Then
    Print "FAIL SubWindow minimized viewport tracking"
    failure_count += 1
End If
gui_SetViewportSize 2, 1
subwindow_Update window_widget
gui_SynchronizeLayout
If window_widget->x <> 0 OrElse window_widget->y <> 0 OrElse _
   window_widget->w <> 2 OrElse window_widget->h <> 1 Then
    Print "FAIL SubWindow tiny minimized viewport"
    failure_count += 1
End If
backend_Clear RGB(200, 200, 200)
gui_RenderAll
gui_SetViewportSize 240, 160
subwindow_Update window_widget
gui_SynchronizeLayout
If subwindow_SetWindowState(window_widget, SUBWINDOW_STATE_NORMAL) = 0 Then
    Print "FAIL SubWindow normal restore"
    failure_count += 1
End If
If window_widget->x <> normal_x OrElse window_widget->y <> normal_y OrElse _
   window_widget->w <> normal_width OrElse _
   window_widget->h <> normal_height OrElse _
   subwindow_SetWindowState(window_widget, 3) <> 0 OrElse _
   subwindow_GetWindowState(window_widget, window_state) = 0 OrElse _
   window_state <> SUBWINDOW_STATE_NORMAL Then
    Print "FAIL SubWindow normal restore or state validation"
    failure_count += 1
End If

' Title controls are part of the retained widget rather than an operating-
' system decoration. This keeps the same behavior in headless, X11, and
' Windows builds while allowing translated VBDOS properties to configure it.
gui_SynchronizeLayout
If subwindow_GetControlBox(window_widget, title_button_value) = 0 OrElse _
   title_button_value <> 0 OrElse _
   subwindow_GetMinButton(window_widget, title_button_value) = 0 OrElse _
   title_button_value = 0 OrElse _
   subwindow_GetMaxButton(window_widget, title_button_value) = 0 OrElse _
   title_button_value = 0 OrElse _
   subwindow_SetControlBox(window_widget, -1) = 0 OrElse _
   subwindow_GetControlBox(window_widget, title_button_value) = 0 OrElse _
   title_button_value = 0 Then
    Print "FAIL SubWindow title-button defaults or ControlBox"
    failure_count += 1
End If
If subwindow_SetMinButton(window_widget, 0) = 0 OrElse _
   subwindow_GetMinButton(window_widget, title_button_value) = 0 OrElse _
   title_button_value <> 0 OrElse _
   subwindow_SetMaxButton(window_widget, 0) = 0 OrElse _
   subwindow_GetMaxButton(window_widget, title_button_value) = 0 OrElse _
   title_button_value <> 0 OrElse _
   subwindow_SetMinButton(window_widget, 7) = 0 OrElse _
   subwindow_SetMaxButton(window_widget, -1) = 0 OrElse _
   subwindow_SetMinButton(state_button, -1) <> 0 Then
    Print "FAIL SubWindow title-button setters"
    failure_count += 1
End If

' With all three controls present, their centers are laid out from the right
' as Close, Maximize, and Minimize with a two-pixel gap between each box.
input_MockMouse window_widget->ax + window_widget->w - 27, _
    window_widget->ay + 10, 1
gui_UpdateAll
input_MockMouse window_widget->ax + window_widget->w - 27, _
    window_widget->ay + 10, 0
gui_UpdateAll
If subwindow_GetWindowState(window_widget, window_state) = 0 OrElse _
   window_state <> SUBWINDOW_STATE_MAXIMIZED Then
    Print "FAIL SubWindow maximize title button"
    failure_count += 1
End If
input_MockMouse window_widget->ax + window_widget->w - 27, _
    window_widget->ay + 10, 1
gui_UpdateAll
input_MockMouse window_widget->ax + window_widget->w - 27, _
    window_widget->ay + 10, 0
gui_UpdateAll
If subwindow_GetWindowState(window_widget, window_state) = 0 OrElse _
   window_state <> SUBWINDOW_STATE_NORMAL OrElse _
   window_widget->x <> normal_x OrElse window_widget->y <> normal_y OrElse _
   window_widget->w <> normal_width OrElse _
   window_widget->h <> normal_height Then
    Print "FAIL SubWindow restore title button"
    failure_count += 1
End If
input_MockMouse window_widget->ax + window_widget->w - 43, _
    window_widget->ay + 10, 1
gui_UpdateAll
input_MockMouse window_widget->ax + window_widget->w - 43, _
    window_widget->ay + 10, 0
gui_UpdateAll
If subwindow_GetWindowState(window_widget, window_state) = 0 OrElse _
   window_state <> SUBWINDOW_STATE_MINIMIZED Then
    Print "FAIL SubWindow minimize title button"
    failure_count += 1
End If
If subwindow_SetWindowState( _
    window_widget, SUBWINDOW_STATE_NORMAL _
) = 0 Then
    Print "FAIL SubWindow title-button state restore"
    failure_count += 1
End If

' BorderStyle None normally exposes only the client. The portable minimized
' representation must still display its title and permit horizontal placement.
If subwindow_SetBorderStyle(window_widget, SUBWINDOW_BORDER_NONE) = 0 OrElse _
   subwindow_SetWindowState( _
       window_widget, SUBWINDOW_STATE_MINIMIZED _
   ) = 0 Then
    Print "FAIL SubWindow borderless minimize"
    failure_count += 1
Else
    gui_SynchronizeLayout
    backend_Clear RGB(200, 200, 200)
    gui_RenderAll
    Dim As Integer minimized_x = window_widget->x
    input_MockMouse window_widget->ax + 20, window_widget->ay + 5, 1
    gui_UpdateAll
    input_MockMouse window_widget->ax + 40, window_widget->ay + 25, 1
    gui_UpdateAll
    input_MockMouse window_widget->ax + 40, window_widget->ay + 5, 0
    gui_UpdateAll
    If window_widget->x <> minimized_x + 20 OrElse _
       window_widget->y <> 140 Then
        Print "FAIL SubWindow borderless minimized drag"
        failure_count += 1
    End If
End If

If subwindow_ClearClientColor(window_widget) = 0 OrElse _
   subwindow_GetClientColor(window_widget, color_value) <> 0 Then
    Print "FAIL SubWindow client color clear"
    failure_count += 1
End If

gui_ResetForTest
backend_Exit
If failure_count <> 0 Then
    Print "subwindow_color_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "subwindow_color_smoke: PASS"
End 0

/' end of subwindow_color_smoke.bas '/
