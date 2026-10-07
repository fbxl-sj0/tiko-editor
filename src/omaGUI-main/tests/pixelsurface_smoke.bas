/'
    Project: omaGUI Tests
    ---------------------

    File: pixelsurface_smoke.bas

    Purpose:

        Verify retained sparse pixels and their PictureBox integration.

    Responsibilities:

        - exercise checked allocation, clipping, styled lines/rectangles, reads, clears, and release
        - verify resize intersection preservation without a platform bitmap
        - verify PictureBox redraw after a gfxlib screen handoff
        - verify a client-following canvas tracks widget geometry safely

    This file intentionally does NOT contain:

        - image decoding or screenshot files
        - input routing or application drawing algorithms
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub pixelsurface_Require( _
    ByVal condition_value As Integer, ByVal source_line As Integer _
)
    If condition_value Then Exit Sub
    Screen 0
    Print "pixelsurface_smoke: FAIL at line "; source_line
    End 1
End Sub

' -------------------------------------------------------------------------
' Memory-only surface contract
' -------------------------------------------------------------------------

Dim As GuiPixelSurface surface
Dim As ULong pixel_color
Dim As Integer occupied

pixelsurface_Require pixelsurface_Resize(surface, 4, 3), __LINE__
pixelsurface_Require pixelsurface_SetPixel(surface, 0, 0, RGB(255, 0, 0)), __LINE__
pixelsurface_Require pixelsurface_SetPixel(surface, 3, 2, RGB(0, 255, 0)), __LINE__
pixelsurface_Require pixelsurface_SetPixel(surface, 1, 1, RGB(0, 0, 0)), __LINE__
pixelsurface_Require pixelsurface_SetPixel(surface, 4, 2, 0), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 1, 1, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(0, 0, 0), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 2, 1, pixel_color, occupied _
) AndAlso occupied = 0, __LINE__

pixelsurface_Require pixelsurface_Resize(surface, 5, 4), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 3, 2, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(0, 255, 0), __LINE__
Dim As ULong Ptr saved_colors = surface.colors
Dim As UByte Ptr saved_occupied = surface.occupied
pixelsurface_Require pixelsurface_Resize( _
    surface, PIXELSURFACE_MAX_DIMENSION + 1, 1 _
) = 0 AndAlso surface.colors = saved_colors AndAlso _
    surface.occupied = saved_occupied, __LINE__
pixelsurface_Require pixelsurface_Resize(surface, 2, 2), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 1, 1, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(0, 0, 0), __LINE__
pixelsurface_Require pixelsurface_Resize(surface, 4, 3), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 3, 2, pixel_color, occupied _
) AndAlso occupied = 0, __LINE__
pixelsurface_Clear surface
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 0, 0, pixel_color, occupied _
) AndAlso occupied = 0, __LINE__
pixelsurface_Require pixelsurface_Resize(surface, 5, 4), __LINE__
pixelsurface_Require pixelsurface_DrawLine( _
    surface, -3, 1, 7, 1, RGB(0, 0, 255) _
), __LINE__
For column_index As Integer = 0 To 4
    pixelsurface_Require pixelsurface_ReadPixel( _
        surface, column_index, 1, pixel_color, occupied _
    ) AndAlso occupied AndAlso pixel_color = RGB(0, 0, 255), __LINE__
Next column_index
pixelsurface_Require pixelsurface_DrawLine( _
    surface, 0, 0, 4, 3, RGB(255, 0, 0) _
), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 0, 0, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(255, 0, 0), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 4, 3, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(255, 0, 0), __LINE__
pixelsurface_Require pixelsurface_DrawCircle( _
    surface, 2, 2, 1, RGB(255, 255, 0) _
), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 3, 2, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(255, 255, 0), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 2, 1, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(255, 255, 0), __LINE__
pixelsurface_Require pixelsurface_DrawCircle( _
    surface, -3, 2, 1, RGB(255, 255, 255) _
), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 0, 2, pixel_color, occupied _
) AndAlso occupied = 0, __LINE__
pixelsurface_Require pixelsurface_DrawCircle( _
    surface, 2, 2, -1, RGB(255, 255, 255) _
) = 0, __LINE__
' Earlier line and circle assertions deliberately overlap this tiny surface.
' Reset it so the following rectangle checks can prove fill/interior behavior.
pixelsurface_Clear surface
pixelsurface_Require pixelsurface_DrawRectangle( _
    surface, -2, -2, 1, 1, RGB(0, 255, 255), -1 _
), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 1, 1, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(0, 255, 255), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 2, 2, pixel_color, occupied _
) AndAlso occupied = 0, __LINE__
pixelsurface_Require pixelsurface_DrawRectangle( _
    surface, 1, 1, 3, 3, RGB(255, 0, 255), 0 _
), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 2, 2, pixel_color, occupied _
) AndAlso occupied = 0, __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 3, 1, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(255, 0, 255), __LINE__
pixelsurface_Require pixelsurface_DrawLine( _
    surface, -10, -10, -2, -2, RGB(255, 255, 255) _
), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 4, 0, pixel_color, occupied _
) AndAlso occupied = 0, __LINE__
pixelsurface_Clear surface
pixelsurface_Require pixelsurface_DrawStyledLine( _
    surface, 0, 0, 4, 0, RGB(255, 128, 0), &hAAAA _
), __LINE__
For column_index As Integer = 0 To 4
    pixelsurface_Require pixelsurface_ReadPixel( _
        surface, column_index, 0, pixel_color, occupied _
    ) AndAlso occupied = IIf((column_index And 1) = 0, -1, 0), __LINE__
Next column_index
pixelsurface_Require pixelsurface_DrawStyledLine( _
    surface, -2, 2, 4, 2, RGB(128, 0, 255), &hAAAA _
), __LINE__
For column_index As Integer = 0 To 4
    pixelsurface_Require pixelsurface_ReadPixel( _
        surface, column_index, 2, pixel_color, occupied _
    ) AndAlso occupied = IIf((column_index And 1) = 0, -1, 0), __LINE__
Next column_index
pixelsurface_Require pixelsurface_DrawStyledLine( _
    surface, 4, 3, 0, 3, RGB(0, 128, 255), &h8000 _
), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 4, 3, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(0, 128, 255), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 0, 3, pixel_color, occupied _
) AndAlso occupied = 0, __LINE__
pixelsurface_Clear surface
' The native B perimeter starts along the bottom, then continues across top,
' right, and left. This all-ones-first-bit style distinguishes that order from
' four independent styled lines and retains overlapping corner writes.
pixelsurface_Require pixelsurface_DrawStyledRectangle( _
    surface, 1, 1, 3, 2, RGB(255, 0, 255), 0, &h8000 _
), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 1, 1, pixel_color, occupied _
) AndAlso occupied = 0, __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 1, 2, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(255, 0, 255), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 3, 2, pixel_color, occupied _
) AndAlso occupied = 0, __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 3, 1, pixel_color, occupied _
) AndAlso occupied = 0, __LINE__
pixelsurface_Clear surface
' BF deliberately ignores the styled mask, just as the installed gfxlib fill
' path does. A zero mask must still retain the complete inclusive fill.
pixelsurface_Require pixelsurface_DrawStyledRectangle( _
    surface, -1, -1, 1, 1, RGB(0, 255, 255), -1, 0 _
), __LINE__
For pixel_y As Integer = 0 To 1
    For pixel_x As Integer = 0 To 1
        pixelsurface_Require pixelsurface_ReadPixel( _
            surface, pixel_x, pixel_y, pixel_color, occupied _
        ) AndAlso occupied AndAlso pixel_color = RGB(0, 255, 255), __LINE__
    Next pixel_x
Next pixel_y
pixelsurface_Require pixelsurface_Resize(surface, 17, 17), __LINE__
pixelsurface_Clear surface
' The portable ellipse uses the native CIRCLE aspect rule: an aspect above
' one narrows its X radius while retaining the supplied Y radius.
pixelsurface_Require pixelsurface_DrawEllipse( _
    surface, 8, 8, 4, 2, 0, PIXELSURFACE_FULL_CIRCLE, 0, _
    RGB(255, 128, 0) _
), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 10, 8, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(255, 128, 0), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 8, 4, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(255, 128, 0), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 12, 8, pixel_color, occupied _
) AndAlso occupied = 0, __LINE__
pixelsurface_Clear surface
' Partial arcs leave the opposite side untouched. The point at angle zero is
' right of center and increasing angles travel toward screen-up.
pixelsurface_Require pixelsurface_DrawEllipse( _
    surface, 8, 8, 4, 1, 0, 1.5707963267948966, -1, _
    RGB(128, 0, 255) _
), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 12, 8, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(128, 0, 255), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 8, 4, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(128, 0, 255), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 4, 8, pixel_color, occupied _
) AndAlso occupied = 0, __LINE__
pixelsurface_Clear surface
' F fills only a full ellipse. The center confirms inclusive retained fill.
pixelsurface_Require pixelsurface_DrawEllipse( _
    surface, 8, 8, 3, 1, 0, PIXELSURFACE_FULL_CIRCLE, -1, _
    RGB(0, 128, 255) _
), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 8, 8, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(0, 128, 255), __LINE__
pixelsurface_Clear surface
' Negative arc angles retain their ordinary arc plus a radial center line.
pixelsurface_Require pixelsurface_DrawEllipse( _
    surface, 8, 8, 4, 1, -0.7853981633974483, 0, 0, _
    RGB(255, 255, 255) _
), __LINE__
pixelsurface_Require pixelsurface_ReadPixel( _
    surface, 8, 8, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(255, 255, 255), __LINE__
pixelsurface_Release surface
pixelsurface_Release surface
pixelsurface_Require surface.colors = 0 AndAlso surface.occupied = 0 AndAlso _
    surface.width = 0 AndAlso surface.height = 0, __LINE__

' -------------------------------------------------------------------------
' PictureBox canvas contract
' -------------------------------------------------------------------------

backend_Init 100, 80
gui_Init

Dim As Widget Ptr picture_widget = picturebox_Create( _
    "pixel-surface", "", 10, 10, 32, 24, PICTUREBOX_BORDER_SINGLE _
)
pixelsurface_Require picture_widget <> 0, __LINE__
gui_AddWidget picture_widget

pixelsurface_Require picturebox_SetPixelCanvas( _
    picture_widget, 4, 3, 3, 2 _
), __LINE__
pixelsurface_Require Cast(PictureBoxData Ptr, _
    picture_widget->data)->pixel_surface.colors = 0, __LINE__
pixelsurface_Require picturebox_SetPixel( _
    picture_widget, 0, 0, RGB(255, 0, 0) _
), __LINE__
pixelsurface_Require picturebox_SetPixel( _
    picture_widget, 1, 0, RGB(255, 0, 0) _
), __LINE__
pixelsurface_Require picturebox_SetPixel( _
    picture_widget, 2, 0, RGB(0, 255, 0) _
), __LINE__
pixelsurface_Require picturebox_SetPixel( _
    picture_widget, 3, 2, RGB(0, 0, 0) _
), __LINE__
pixelsurface_Require picturebox_SetPixel( _
    picture_widget, 4, 0, 0 _
), __LINE__
pixelsurface_Require picturebox_DrawLine( _
    picture_widget, 0, 1, 3, 1, RGB(0, 0, 255) _
), __LINE__
pixelsurface_Require picturebox_DrawCircle( _
    picture_widget, 1, 2, 1, RGB(255, 255, 0) _
), __LINE__
pixelsurface_Require picturebox_DrawRectangle( _
    picture_widget, 3, 0, 3, 0, RGB(255, 0, 255), -1 _
), __LINE__
pixelsurface_Require picturebox_DrawStyledLine( _
    picture_widget, 0, 1, 3, 1, RGB(255, 128, 0), &hAAAA _
), __LINE__

backend_Clear RGB(16, 16, 16)
gui_RenderAll
pixelsurface_Require (Point(14, 13) And &hFFFFFF) = &hFF0000, __LINE__
pixelsurface_Require (Point(15, 13) And &hFFFFFF) = &hFF0000, __LINE__
pixelsurface_Require (Point(16, 13) And &hFFFFFF) = &h00FF00, __LINE__
pixelsurface_Require (Point(14, 14) And &hFFFFFF) = &hFF8000, __LINE__
pixelsurface_Require picturebox_ReadPixel( _
    picture_widget, 3, 2, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(0, 0, 0), __LINE__
pixelsurface_Require picturebox_ReadPixel( _
    picture_widget, 1, 1, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(255, 255, 0), __LINE__
pixelsurface_Require picturebox_ReadPixel( _
    picture_widget, 3, 0, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(255, 0, 255), __LINE__

Dim As BackendDisplayState saved_display
pixelsurface_Require backend_CaptureDisplay(saved_display), __LINE__
Screen 2
pixelsurface_Require ScreenPtr <> 0, __LINE__
pixelsurface_Require backend_RestoreDisplay(saved_display), __LINE__
backend_Clear RGB(16, 16, 16)
gui_RenderAll
pixelsurface_Require (Point(14, 13) And &hFFFFFF) = &hFF0000, __LINE__
pixelsurface_Require (Point(14, 14) And &hFFFFFF) = &hFF8000, __LINE__

pixelsurface_Require picturebox_SetPixelCanvas( _
    picture_widget, 5, 4, 3, 2 _
), __LINE__
pixelsurface_Require picturebox_ReadPixel( _
    picture_widget, 2, 0, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(0, 255, 0), __LINE__
picturebox_ClearPixels picture_widget
pixelsurface_Require Cast(PictureBoxData Ptr, _
    picture_widget->data)->pixel_surface.colors = 0, __LINE__
pixelsurface_Require picturebox_ReadPixel( _
    picture_widget, 2, 0, pixel_color, occupied _
) = 0 AndAlso occupied = 0, __LINE__

pixelsurface_Require picturebox_SetPixelCanvasToClient( _
    picture_widget, 2, 1 _
), __LINE__
pixelsurface_Require Cast(PictureBoxData Ptr, _
    picture_widget->data)->pixel_width = 26 AndAlso _
    Cast(PictureBoxData Ptr, picture_widget->data)->pixel_height = 20, __LINE__
pixelsurface_Require picturebox_SetPixel( _
    picture_widget, 10, 10, RGB(0, 0, 255) _
), __LINE__
pixelsurface_Require picturebox_SetPixel( _
    picture_widget, 25, 19, RGB(255, 255, 0) _
), __LINE__
pixelsurface_Require gui_SetBounds(picture_widget, 10, 10, 36, 24), __LINE__
gui_UpdateAll
pixelsurface_Require Cast(PictureBoxData Ptr, _
    picture_widget->data)->pixel_width = 30 AndAlso _
    Cast(PictureBoxData Ptr, picture_widget->data)->pixel_height = 20, __LINE__
pixelsurface_Require picturebox_ReadPixel( _
    picture_widget, 25, 19, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(255, 255, 0), __LINE__
pixelsurface_Require gui_SetBounds(picture_widget, 10, 10, 24, 24), __LINE__
gui_UpdateAll
pixelsurface_Require Cast(PictureBoxData Ptr, _
    picture_widget->data)->pixel_width = 18 AndAlso _
    Cast(PictureBoxData Ptr, picture_widget->data)->pixel_height = 20, __LINE__
pixelsurface_Require picturebox_ReadPixel( _
    picture_widget, 10, 10, pixel_color, occupied _
) AndAlso occupied AndAlso pixel_color = RGB(0, 0, 255), __LINE__
pixelsurface_Require picturebox_ReadPixel( _
    picture_widget, 25, 19, pixel_color, occupied _
) = 0 AndAlso occupied = 0, __LINE__

gui_ResetForTest
backend_Exit
Screen 0
Print "pixelsurface_smoke: PASS (storage, resize, clipping, handoff, client tracking)"
End 0

/' end of pixelsurface_smoke.bas '/
