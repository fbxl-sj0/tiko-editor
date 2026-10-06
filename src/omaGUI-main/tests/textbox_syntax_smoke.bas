/'
    Project: omaGUI Tests
    ---------------------

    File: textbox_syntax_smoke.bas

    Purpose:

        Verify the opt-in FreeBASIC syntax highlighter through the rendered
        framebuffer rather than only checking its retained metadata.

    Responsibilities:

        - verify syntax mode and per-token color metadata
        - verify keywords, comments, strings, numbers, directives, and types
          reach the display with their configured colors
        - verify user-defined types, object instances, and object members
          receive distinct semantic colors
        - verify the optional logical line-number gutter renders independently
          from syntax-colored document text
        - verify gutter-aware pointer mapping and fixed horizontal scrolling
        - verify ordinary textbox text remains available after rendering

    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:

        - parser validation or compiler diagnostics
        - editor input and selection behavior
        - application-specific IDE policy
'/

#lang "fb"
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub textboxSyntaxSmoke_Require( _
    ByVal success As Integer, ByVal source_line As Integer _
)

    If success Then Exit Sub
    backend_Exit
    Screen 0
    Print "textbox_syntax_smoke: FAIL at line "; source_line
    End 1

End Sub


Private Function textboxSyntaxSmoke_CountPixels( _
    ByVal left_edge As Integer, ByVal top_edge As Integer, _
    ByVal right_edge As Integer, ByVal bottom_edge As Integer, _
    ByVal expected_color As ULong _
) As Integer

    Dim As Integer matching_pixels

    For pixel_y As Integer = top_edge To bottom_edge - 1
        For pixel_x As Integer = left_edge To right_edge - 1
            If (Point(pixel_x, pixel_y) And &hFFFFFF) = _
               (expected_color And &hFFFFFF) Then
                matching_pixels += 1
            End If
        Next pixel_x
    Next pixel_y

    Return matching_pixels

End Function


Const TEXTBOX_SYNTAX_SMOKE_TEXT As String = _
    "#define MAX_COUNT 42" & Chr(10) & _
    "TYPE Counter" & Chr(10) & _
    "    value AS INTEGER" & Chr(10) & _
    "END TYPE" & Chr(10) & _
    "DIM master AS Counter" & Chr(10) & _
    "DIM count AS INTEGER" & Chr(10) & _
    "IF count = 42 THEN ' comment" & Chr(10) & _
    "message = ""hello""" & Chr(10) & _
    "SUB ShowMessage(value AS STRING)" & Chr(10) & _
    "    PRINT value" & Chr(10) & _
    "END SUB" & Chr(10) & _
    "start:" & Chr(10) & _
    "    count = MAX_COUNT" & Chr(10) & _
    "    ShowMessage message" & Chr(10) & _
    "    master.value = TRUE"

backend_Init 400, 260, 0
Dim As Integer screen_width
Dim As Integer screen_height
ScreenInfo screen_width, screen_height
textboxSyntaxSmoke_Require _
    screen_width = 400 AndAlso screen_height = 260 AndAlso ScreenPtr <> 0, _
    __LINE__
gui_Init

Dim As Widget Ptr syntax_widget = textbox_Create( _
    "syntax", TEXTBOX_SYNTAX_SMOKE_TEXT, 10, 10, 360, 230, -1, 0 _
)
textboxSyntaxSmoke_Require syntax_widget <> 0, __LINE__
gui_AddWidget syntax_widget

Dim As Widget Ptr single_line_widget = textbox_Create( _
    "single_line", "one line", 0, 0, 120, 24, 0, 0 _
)
textboxSyntaxSmoke_Require single_line_widget <> 0, __LINE__
textboxSyntaxSmoke_Require _
    textbox_SetLineNumbers(single_line_widget, -1) = 0, __LINE__
textboxSyntaxSmoke_Require _
    textbox_GetLineNumbers(single_line_widget) = 0, __LINE__
textbox_Destroy single_line_widget
Delete single_line_widget

Dim As ULong syntax_color
Dim As TextBoxData Ptr syntax_data = Cast( _
    TextBoxData Ptr, syntax_widget->data _
)
textboxSyntaxSmoke_Require syntax_data <> 0, __LINE__
textboxSyntaxSmoke_Require _
    textbox_SetSyntaxMode(syntax_widget, TEXTBOX_SYNTAX_FREEBASIC) <> 0, _
    __LINE__
textboxSyntaxSmoke_Require _
    textbox_GetSyntaxMode(syntax_widget) = TEXTBOX_SYNTAX_FREEBASIC, _
    __LINE__
textboxSyntaxSmoke_Require _
    textbox_SetLineNumbers(syntax_widget, -1) <> 0, __LINE__
textboxSyntaxSmoke_Require _
    textbox_GetLineNumbers(syntax_widget) <> 0, __LINE__
textboxSyntaxSmoke_Require _
    textbox_SetSyntaxColor( _
        syntax_widget, TEXTBOX_SYNTAX_COLOR_KEYWORD, RGB(255, 0, 0) _
    ) <> 0, __LINE__
textboxSyntaxSmoke_Require _
    textbox_GetSyntaxColor( _
        syntax_widget, TEXTBOX_SYNTAX_COLOR_KEYWORD, syntax_color _
    ) <> 0 AndAlso syntax_color = RGB(255, 0, 0), __LINE__
textboxSyntaxSmoke_Require _
    textbox_SetSyntaxColor( _
        syntax_widget, TEXTBOX_SYNTAX_COLOR_COMMAND, RGB(255, 128, 0) _
    ) <> 0, __LINE__
textboxSyntaxSmoke_Require _
    textbox_SetSyntaxColor( _
        syntax_widget, TEXTBOX_SYNTAX_COLOR_PROCEDURE, RGB(0, 255, 0) _
    ) <> 0, __LINE__
textboxSyntaxSmoke_Require _
    textbox_SetSyntaxColor( _
        syntax_widget, TEXTBOX_SYNTAX_COLOR_MACRO, RGB(255, 0, 255) _
    ) <> 0, __LINE__
textboxSyntaxSmoke_Require _
    textbox_SetSyntaxColor( _
        syntax_widget, TEXTBOX_SYNTAX_COLOR_VARIABLE, RGB(255, 255, 0) _
    ) <> 0, __LINE__
textboxSyntaxSmoke_Require _
    textbox_SetSyntaxColor( _
        syntax_widget, TEXTBOX_SYNTAX_COLOR_CONSTANT, RGB(0, 255, 255) _
    ) <> 0, __LINE__
textboxSyntaxSmoke_Require _
    textbox_SetSyntaxColor( _
        syntax_widget, TEXTBOX_SYNTAX_COLOR_MEMBER, RGB(0, 128, 255) _
    ) <> 0, __LINE__
textboxSyntaxSmoke_Require _
    textbox_SetSyntaxColor( _
        syntax_widget, TEXTBOX_SYNTAX_COLOR_LABEL, RGB(255, 128, 128) _
    ) <> 0, __LINE__
textboxSyntaxSmoke_Require _
    textbox_SetSyntaxColor( _
        syntax_widget, TEXTBOX_SYNTAX_COLOR_OBJECT, RGB(128, 0, 255) _
    ) <> 0, __LINE__

backend_Clear RGB(0, 0, 0)
gui_RenderAll

textboxSyntaxSmoke_Require syntax_data->line_number_gutter_width > 0, __LINE__
textboxSyntaxSmoke_Require _
    textboxSyntaxSmoke_CountPixels( _
        syntax_widget->ax + 2, _
        syntax_widget->ay + 2, _
        syntax_widget->ax + 2 + syntax_data->line_number_gutter_width, _
        syntax_widget->ay + syntax_widget->h - 2, _
        current_theme.classic_disabled_text _
    ) > 0, __LINE__

Dim As Integer text_left = syntax_widget->ax + 2
Dim As Integer text_top = syntax_widget->ay + 2
Dim As Integer text_right = syntax_widget->ax + syntax_widget->w - 2
Dim As Integer text_bottom = syntax_widget->ay + syntax_widget->h - 2
textboxSyntaxSmoke_Require _
    textboxSyntaxSmoke_CountPixels( _
        text_left, text_top, text_right, text_bottom, RGB(255, 0, 0) _
    ) > 0, __LINE__
textboxSyntaxSmoke_Require _
    textboxSyntaxSmoke_CountPixels( _
        text_left, text_top, text_right, text_bottom, _
        syntax_data->syntax_comment_color _
    ) > 0, __LINE__
textboxSyntaxSmoke_Require _
    textboxSyntaxSmoke_CountPixels( _
        text_left, text_top, text_right, text_bottom, _
        syntax_data->syntax_string_color _
    ) > 0, __LINE__
textboxSyntaxSmoke_Require _
    textboxSyntaxSmoke_CountPixels( _
        text_left, text_top, text_right, text_bottom, _
        syntax_data->syntax_number_color _
    ) > 0, __LINE__
textboxSyntaxSmoke_Require _
    textboxSyntaxSmoke_CountPixels( _
        text_left, text_top, text_right, text_bottom, _
        syntax_data->syntax_preprocessor_color _
    ) > 0, __LINE__
textboxSyntaxSmoke_Require _
    textboxSyntaxSmoke_CountPixels( _
        text_left, text_top, text_right, text_bottom, _
        syntax_data->syntax_type_color _
    ) > 0, __LINE__
textboxSyntaxSmoke_Require _
    textboxSyntaxSmoke_CountPixels( _
        text_left, text_top, text_right, text_bottom, RGB(255, 128, 0) _
    ) > 0, __LINE__
textboxSyntaxSmoke_Require _
    textboxSyntaxSmoke_CountPixels( _
        text_left, text_top, text_right, text_bottom, RGB(0, 255, 0) _
    ) > 0, __LINE__
textboxSyntaxSmoke_Require _
    textboxSyntaxSmoke_CountPixels( _
        text_left, text_top, text_right, text_bottom, RGB(255, 0, 255) _
    ) > 0, __LINE__
textboxSyntaxSmoke_Require _
    textboxSyntaxSmoke_CountPixels( _
        text_left, text_top, text_right, text_bottom, RGB(255, 255, 0) _
    ) > 0, __LINE__
textboxSyntaxSmoke_Require _
    textboxSyntaxSmoke_CountPixels( _
        text_left, text_top, text_right, text_bottom, RGB(0, 255, 255) _
    ) > 0, __LINE__
textboxSyntaxSmoke_Require _
    textboxSyntaxSmoke_CountPixels( _
        text_left, text_top, text_right, text_bottom, RGB(0, 128, 255) _
    ) > 0, __LINE__
textboxSyntaxSmoke_Require _
    textboxSyntaxSmoke_CountPixels( _
        text_left, text_top, text_right, text_bottom, RGB(255, 128, 128) _
    ) > 0, __LINE__
textboxSyntaxSmoke_Require _
    textboxSyntaxSmoke_CountPixels( _
        text_left, text_top, text_right, text_bottom, RGB(128, 0, 255) _
    ) > 0, __LINE__
textboxSyntaxSmoke_Require syntax_data->text = TEXTBOX_SYNTAX_SMOKE_TEXT, __LINE__

Dim As Integer two_digit_gutter = syntax_data->line_number_gutter_width
textbox_SetHorizontalScrollbar syntax_widget, TEXTBOX_SCROLLBAR_ALWAYS
backend_Clear RGB(0, 0, 0)
gui_RenderAll
textboxSyntaxSmoke_Require _
    syntax_data->horizontal_scrollbar->ax = _
        syntax_widget->ax + 2 + two_digit_gutter, __LINE__

textboxSyntaxSmoke_Require _
    textbox_SetLineNumbers(syntax_widget, 0) <> 0, __LINE__
backend_Clear RGB(0, 0, 0)
gui_RenderAll
textboxSyntaxSmoke_Require syntax_data->line_number_gutter_width = 0, __LINE__
textboxSyntaxSmoke_Require _
    syntax_data->horizontal_scrollbar->ax = syntax_widget->ax + 2, __LINE__

textboxSyntaxSmoke_Require _
    textbox_SetLineNumbers(syntax_widget, -1) <> 0, __LINE__
textboxSyntaxSmoke_Require _
    textbox_SetText(syntax_widget, "abc" & Chr(10) & "xyz", -1) <> 0, _
    __LINE__
backend_Clear RGB(0, 0, 0)
gui_RenderAll
Dim As Integer virtual_space
textboxSyntaxSmoke_Require _
    textbox_PositionFromPoint( _
        syntax_widget, syntax_data, _
        syntax_widget->ax + 3, _
        syntax_widget->ay + TEXTBOX_TEXT_LEFT_PADDING + _
            TEXTBOX_LINE_HEIGHT + 1, _
        virtual_space _
    ) = 4, __LINE__
textboxSyntaxSmoke_Require virtual_space = 0, __LINE__
textboxSyntaxSmoke_Require _
    textbox_PositionFromPoint( _
        syntax_widget, syntax_data, _
        syntax_widget->ax + TEXTBOX_TEXT_LEFT_PADDING + _
            syntax_data->line_number_gutter_width + _
            backend_GetTextWidth("x"), _
        syntax_widget->ay + TEXTBOX_TEXT_LEFT_PADDING + _
            TEXTBOX_LINE_HEIGHT + 1, _
        virtual_space _
    ) = 5, __LINE__
textboxSyntaxSmoke_Require virtual_space = 0, __LINE__

Dim As String many_lines = "line" & _
    String(99, TEXTBOX_LINE_FEED)
textboxSyntaxSmoke_Require _
    textbox_SetText(syntax_widget, many_lines, -1) <> 0, __LINE__
backend_Clear RGB(0, 0, 0)
gui_RenderAll
textboxSyntaxSmoke_Require _
    syntax_data->line_number_gutter_width > two_digit_gutter, __LINE__

/'
    A wrapped continuation is still part of its original logical source line.
    Only its first visual row receives a number.
'/
syntax_data->wordwrap = -1
textboxSyntaxSmoke_Require _
    textbox_SetText(syntax_widget, String(180, Asc("W")), -1) <> 0, _
    __LINE__
backend_Clear RGB(0, 0, 0)
gui_RenderAll
textboxSyntaxSmoke_Require syntax_data->total_visual_lines > 1, __LINE__
Dim As Integer numbered_row_pixels = textboxSyntaxSmoke_CountPixels( _
    syntax_widget->ax + 2, _
    syntax_widget->ay + 2, _
    syntax_widget->ax + 2 + syntax_data->line_number_gutter_width, _
    syntax_widget->ay + 2 + TEXTBOX_LINE_HEIGHT, _
    current_theme.classic_disabled_text _
)
Dim As Integer continuation_row_pixels = textboxSyntaxSmoke_CountPixels( _
    syntax_widget->ax + 2, _
    syntax_widget->ay + 2 + TEXTBOX_LINE_HEIGHT, _
    syntax_widget->ax + 2 + syntax_data->line_number_gutter_width, _
    syntax_widget->ay + 2 + (TEXTBOX_LINE_HEIGHT * 2), _
    current_theme.classic_disabled_text _
)
textboxSyntaxSmoke_Require _
    numbered_row_pixels > continuation_row_pixels, __LINE__

gui_ResetForTest
backend_Exit
Screen 0
Print "textbox_syntax_smoke: PASS (token colors, line numbers, and metadata)"
End 0

/' end of textbox_syntax_smoke.bas '/
