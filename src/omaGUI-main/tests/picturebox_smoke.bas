/'
    Project: omaGUI Tests
    ---------------------

    File: picturebox_smoke.bas

    Purpose:

        Verify PictureBox construction, state changes, child clipping, and
        lifecycle.

    Responsibilities:

        - create and render a framed surface in the headless backend
        - replace display text and border style through checked APIs
        - set, query, and clear an explicit client background color
        - reject an unsupported border style without changing retained state

    This file intentionally does NOT contain:

        - screenshot comparisons
        - image decoding
        - application-specific drawing
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim As PictureBoxData Ptr picture_data
Dim As Widget Ptr picture_widget
Dim As Integer failure_count
Dim As ULong retained_color

backend_Init 320, 240, BACKEND_HEADLESS
gui_Init
picture_widget = picturebox_Create( _
    "picture_smoke", "Original", 10, 10, 180, 90 _
)
If picture_widget = 0 Then
    Print "picturebox_smoke: constructor failed"
    backend_Exit
    End 1
End If

If picturebox_SetBackgroundColor( _
    picture_widget, RGB(12, 34, 56) _
) = 0 OrElse picturebox_GetBackgroundColor( _
    picture_widget, retained_color _
) = 0 OrElse retained_color <> RGB(12, 34, 56) Then
    Print "FAIL background override"
    failure_count += 1
End If
If picturebox_SetForegroundColor( _
    picture_widget, RGB(90, 100, 110) _
) = 0 OrElse picturebox_GetForegroundColor( _
    picture_widget, retained_color _
) = 0 OrElse retained_color <> RGB(90, 100, 110) Then
    Print "FAIL foreground override"
    failure_count += 1
End If
gui_AddWidget picture_widget

If picture_widget->clip_children = 0 OrElse _
   picture_widget->child_clip_x <> 2 Then
    Print "FAIL initial child clipping"
    failure_count += 1
End If

If picturebox_SetText(picture_widget, "Updated surface") = 0 OrElse _
   picturebox_SetBorderStyle( _
       picture_widget, PICTUREBOX_BORDER_SINGLE _
   ) = 0 Then
    Print "FAIL valid state update"
    failure_count += 1
Else
    picture_data = Cast(PictureBoxData Ptr, picture_widget->data)
    If picture_data->text <> "Updated surface" OrElse _
       picture_data->border_style <> PICTUREBOX_BORDER_SINGLE OrElse _
       picture_widget->child_clip_x <> 1 Then
        Print "FAIL retained state update"
        failure_count += 1
    End If
End If

If picturebox_SetBorderStyle(picture_widget, 99) <> 0 Then
    Print "FAIL invalid border accepted"
    failure_count += 1
ElseIf Cast(PictureBoxData Ptr, picture_widget->data)->border_style <> _
       PICTUREBOX_BORDER_SINGLE Then
    Print "FAIL invalid border changed retained state"
    failure_count += 1
End If

backend_Clear RGB(200, 200, 200)
gui_RenderAll
backend_Flip
If picturebox_ClearBackgroundColor(picture_widget) = 0 OrElse _
   picturebox_GetBackgroundColor(picture_widget, retained_color) <> 0 Then
    Print "FAIL background override clear"
    failure_count += 1
End If
If picturebox_ClearForegroundColor(picture_widget) = 0 OrElse _
   picturebox_GetForegroundColor(picture_widget, retained_color) <> 0 Then
    Print "FAIL foreground override clear"
    failure_count += 1
End If
gui_ResetForTest
backend_Exit

If failure_count <> 0 Then
    Print "picturebox_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "picturebox_smoke: PASS"
End 0

/' end of picturebox_smoke.bas '/
