/'
    Project: omaGUI Tests
    ---------------------

    File: canvas_smoke.bas

    Purpose:

        Verify canvas callback, context, clipping, and routed pointer behavior.

    Responsibilities:

        - construct and render a canvas through the ordinary widget registry
        - deliver relative pointer coordinates only while routed inside
        - retain current and previous pointer button state
        - preserve caller-owned callback context

    This file intentionally does NOT contain:

        - screenshot comparisons
        - native desktop-window interaction
        - application-specific drawing state
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Type CanvasSmokeContext
    As Integer render_count
    As Integer update_count
End Type

Private Sub canvasSmoke_Render( _
    ByVal canvas_widget As Widget Ptr, _
    ByVal context As Any Ptr _
)
    Dim As CanvasSmokeContext Ptr smoke_context

    If canvas_widget = 0 OrElse context = 0 Then Exit Sub
    smoke_context = Cast(CanvasSmokeContext Ptr, context)
    smoke_context->render_count += 1
    backend_Rect canvas_widget->ax - 20, canvas_widget->ay - 20, _
        canvas_widget->w + 40, canvas_widget->h + 40, RGB(20, 40, 80), -1
End Sub


Private Sub canvasSmoke_Update( _
    ByVal canvas_widget As Widget Ptr, _
    ByVal context As Any Ptr _
)
    Dim As CanvasSmokeContext Ptr smoke_context

    If canvas_widget = 0 OrElse context = 0 Then Exit Sub
    smoke_context = Cast(CanvasSmokeContext Ptr, context)
    smoke_context->update_count += 1
End Sub


Dim As CanvasSmokeContext smoke_context
Dim As Widget Ptr canvas_widget
Dim As Integer failure_count

backend_Init 320, 240, -1
gui_Init
canvas_widget = canvas_Create( _
    "canvas_smoke", 20, 30, 100, 80, _
    @canvasSmoke_Render, @canvasSmoke_Update, @smoke_context _
)
If canvas_widget = 0 Then
    Print "canvas_smoke: constructor failed"
    backend_Exit
    End 1
End If
gui_AddWidget canvas_widget
canvas_SetFocusable canvas_widget, -1

input_MockMouse 45, 52, 1
gui_UpdateAll
If canvas_GetPointerX(canvas_widget) <> 25 OrElse _
   canvas_GetPointerY(canvas_widget) <> 22 OrElse _
   canvas_GetPointerButtons(canvas_widget) <> 1 OrElse _
   smoke_context.update_count <> 1 OrElse _
   gui_GetFocus() <> canvas_widget Then
    Print "FAIL routed canvas pointer state"
    failure_count += 1
End If

backend_Clear RGB(240, 240, 240)
gui_RenderAll
backend_Flip
If smoke_context.render_count <> 1 OrElse _
   canvas_GetContext(canvas_widget) <> @smoke_context Then
    Print "FAIL canvas callback context"
    failure_count += 1
End If

input_MockMouse 45, 52, 0
gui_UpdateAll
If canvas_GetPointerButtons(canvas_widget) <> 0 OrElse _
   canvas_GetPreviousPointerButtons(canvas_widget) <> 1 Then
    Print "FAIL canvas button transition"
    failure_count += 1
End If

canvas_SetFocusable canvas_widget, 0
If canvas_widget->accepts_focus OrElse gui_GetFocus() <> 0 Then
    Print "FAIL canvas focus release"
    failure_count += 1
End If

gui_ResetForTest
backend_Exit
If failure_count <> 0 Then
    Print "canvas_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "canvas_smoke: PASS"
End 0

/' end of canvas_smoke.bas '/
