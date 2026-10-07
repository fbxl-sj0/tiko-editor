/'
    Project: omaGUI Tests
    File: textsurface_smoke.bas
    Purpose: Verify retained byte-cell storage and native PictureBox rendering.
    Responsibilities: Exercise bounds, ownership, clipping, colors, and CP437.
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain: a BASIC cursor or PRINT parser.
'/
#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub Require(ByVal success As Integer, ByVal source_line As Integer)
    If success Then Exit Sub
    Screen 0
    Print "textsurface_smoke: FAIL at line "; source_line
    End 1
End Sub

Dim As GuiTextSurface surface
Dim As GuiTextCell cell
Require textsurface_Resize(surface, 4, 3), __LINE__
Require textsurface_WriteByte(surface, 0, 0, 65, RGB(255, 0, 0), RGB(0, 0, 255)), __LINE__
Require textsurface_WriteByte(surface, 3, 2, 219, RGB(0, 255, 0), 0), __LINE__
Require textsurface_WriteByte(surface, 4, 2, 66, 0, 0), __LINE__
Require textsurface_WriteByte(surface, 0, 0, 256, 0, 0) = 0, __LINE__
Require textsurface_Resize(surface, 5, 4), __LINE__
Require textsurface_ReadCell(surface, 3, 2, cell) AndAlso cell.character_code = 219, __LINE__
Require textsurface_ReadCell(surface, 4, 2, cell) AndAlso cell.occupied = 0, __LINE__
Dim As GuiTextCell Ptr saved_cells = surface.cells
Require textsurface_Resize(surface, 256, 3) = 0 AndAlso surface.cells = saved_cells, __LINE__
Require textsurface_Resize(surface, -1, 3) = 0 AndAlso surface.columns = 5, __LINE__
Require textsurface_Resize(surface, 2, 2), __LINE__
Require textsurface_ReadCell(surface, 0, 0, cell) AndAlso cell.character_code = 65, __LINE__
Require textsurface_Resize(surface, 4, 3), __LINE__
Require textsurface_ReadCell(surface, 3, 2, cell) AndAlso cell.occupied = 0, __LINE__
Require textsurface_Resize(surface, 255, 255), __LINE__
Require textsurface_WriteByte(surface, 254, 254, 255, 7, 1), __LINE__
Require textsurface_ReadCell(surface, 254, 254, cell) AndAlso cell.character_code = 255, __LINE__
textsurface_Clear surface
Require textsurface_ReadCell(surface, 254, 254, cell) AndAlso cell.occupied = 0, __LINE__
textsurface_Release surface
textsurface_Release surface
Require surface.cells = 0 AndAlso surface.rows = 0 AndAlso surface.columns = 0, __LINE__

backend_Init 320, 200
Dim As Integer screen_width, screen_height, screen_depth
ScreenInfo screen_width, screen_height, screen_depth
Require ScreenPtr <> 0 AndAlso screen_width = 320 AndAlso screen_height = 200 AndAlso screen_depth = 32, __LINE__
gui_Init
input_ResetForTest
Dim As Widget Ptr picture_widget = picturebox_Create("print-test", "", 20, 30, 100, 100, PICTUREBOX_BORDER_NONE)
Require picture_widget <> 0, __LINE__
gui_AddWidget picture_widget
Require picturebox_SetPrintGrid(picture_widget, 4, 3, 10, 20, 10, 20), __LINE__
Require Cast(PictureBoxData Ptr, picture_widget->data)->print_surface.cells = 0, __LINE__
Require picturebox_WriteByte(picture_widget, 254, 254, 65), __LINE__
Require Cast(PictureBoxData Ptr, picture_widget->data)->print_surface.cells = 0, __LINE__
Require picturebox_SetBackgroundColor(picture_widget, RGB(0, 0, 255)), __LINE__
Require picturebox_SetForegroundColor(picture_widget, RGB(255, 0, 0)), __LINE__
Require picturebox_WriteByte(picture_widget, 0, 0, 219), __LINE__
Require picturebox_SetForegroundColor(picture_widget, RGB(0, 255, 0)), __LINE__
Require picturebox_WriteByte(picture_widget, 1, 0, 219), __LINE__
Require picturebox_WriteByte(picture_widget, 2, 0, 1), __LINE__
Require picturebox_WriteByte(picture_widget, 3, 0, 196), __LINE__
Require picturebox_SetText(picture_widget, "caption"), __LINE__
Require picturebox_ReadPrintCell(picture_widget, 0, 0, cell) AndAlso cell.character_code = 219, __LINE__
Require (cell.foreground_color And &hFFFFFF) = &hFF0000, __LINE__
gui_UpdateAll
backend_Clear RGB(17, 17, 17)
gui_RenderAll
Require (Point(30, 50) And &hFFFFFF) = &hFF0000, __LINE__
Require (Point(40, 50) And &hFFFFFF) = &h00FF00, __LINE__
Require (Point(38, 50) And &hFFFFFF) = &h0000FF, __LINE__
Dim As Integer control_ink, line_ink
For pixel_y As Integer = 50 To 65
    For pixel_x As Integer = 50 To 57
        If (Point(pixel_x, pixel_y) And &hFFFFFF) = &h00FF00 Then control_ink += 1
        If (Point(pixel_x + 10, pixel_y) And &hFFFFFF) = &h00FF00 Then line_ink += 1
    Next pixel_x
Next pixel_y
Require control_ink > 0 AndAlso line_ink > 0, __LINE__

' A parent clip must prevent off-client cells from writing pixel (0,0) when
' the backend represents an empty nested VIEW by its fallback single pixel.
backend_Clear RGB(17, 17, 17)
backend_SetClip 40, 50, 10, 20
picturebox_Render picture_widget
backend_ResetClip
Require (Point(0, 0) And &hFFFFFF) = &h111111, __LINE__
Require (Point(30, 50) And &hFFFFFF) = &h111111, __LINE__
Require (Point(40, 50) And &hFFFFFF) = &h00FF00, __LINE__

Dim As BackendDisplayState saved_display
Require backend_CaptureDisplay(saved_display), __LINE__
Screen 2
Require ScreenPtr <> 0, __LINE__
Require backend_RestoreDisplay(saved_display), __LINE__
backend_Clear 0
gui_RenderAll
Require (Point(30, 50) And &hFFFFFF) = &hFF0000, __LINE__
Require picturebox_SetBorderStyle( _
    picture_widget, PICTUREBOX_BORDER_DOUBLE _
), __LINE__
backend_Clear RGB(17, 17, 17)
gui_RenderAll
Dim As ULong double_border_color = theme_GetColor(GUI_COLOR_BORDER)
Require (Point(20, 30) And &hFFFFFF) = _
    (double_border_color And &hFFFFFF), __LINE__
Require (Point(21, 31) And &hFFFFFF) = _
    (double_border_color And &hFFFFFF), __LINE__
Require (Point(22, 32) And &hFFFFFF) = &h0000FF, __LINE__
picturebox_ClearPrint picture_widget
Require Cast(PictureBoxData Ptr, picture_widget->data)->text = "caption", __LINE__
Require picturebox_ReadPrintCell(picture_widget, 0, 0, cell) = 0, __LINE__
gui_ResetForTest
backend_Exit
Screen 0
Print "textsurface_smoke: PASS (bounds, resize, cells/colors, CP437, clipping, caption, screen handoff)"
End 0
/' end of textsurface_smoke.bas '/
