/'
    Project: omaGUI Tests
    File: textbox_unicode_editor_smoke.bas
    Purpose: Check editor callbacks and UTF-8 cursor operations.
    Responsibilities: Exercise typed hooks, whole-character navigation,
        deletion, and malformed-byte progress in drawable headless mode.
    This file intentionally does NOT contain:
        platform text-input policy.

    Targets: FreeBASIC fb dialect with the native omaGUI backend.
    Module API boundary: Standalone development checks for the behavior described above.
'/

#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim Shared As Integer typedCalls
Dim Shared As Integer colorCalls, styleCalls, colorSawReset
Dim Shared As Integer indicatorCalls
Dim Shared As Integer gutterClicks, foldClicks, gutterMarks, foldMarks
Dim Shared As Integer hiddenLineChecks

Private Sub Require(ByVal condition As Integer, ByRef description As Const String)
    If condition Then Exit Sub
    backend_Exit
    Screen 0
    Print "textbox_unicode_editor_smoke: FAIL "; description
    End 1
End Sub

Private Sub AfterTyping( _
    ByVal w As Widget Ptr, ByRef insertedText As Const String _
)
    If insertedText = "x" Then typedCalls += 1
End Sub

Private Function DisplayByte( _
    ByRef lineText As Const String, ByVal characterIndex As Integer, _
    ByRef state As Integer _
) As Integer
    If lineText[characterIndex] = Asc("a") Then Return Asc("W")
    Return lineText[characterIndex]
End Function

Private Function ColorByte( _
    ByRef lineText As Const String, ByVal characterIndex As Integer, _
    ByRef state As Integer _
) As ULong
    colorCalls += 1
    If colorCalls = 3 AndAlso state = 0 Then colorSawReset = -1
    state = 5
    Return RGB(180, 40, 20)
End Function

Private Function StyleByte( _
    ByRef lineText As Const String, ByVal characterIndex As Integer, _
    ByRef state As Integer, ByRef characterStyle As TextBoxCharacterStyle _
) As Integer
    styleCalls += 1
    characterStyle.foreground = RGB(20, 130, 220)
    characterStyle.background = TEXTBOX_TEXT_STYLE_BACKGROUND_DEFAULT
    characterStyle.flags = TEXTBOX_TEXT_STYLE_UNDERLINE
    Return -1
End Function

Private Function MarkByte( _
    ByVal w As Widget Ptr, ByVal sourcePosition As Integer, _
    ByRef markColor As ULong, ByRef alpha As Integer, _
    ByRef style As Integer _
) As Integer
    indicatorCalls += 1
    markColor = RGB(100, 160, 40)
    alpha = 120
    style = TEXTBOX_INDICATOR_STYLE_FILL
    Return IIf(sourcePosition = 1, -1, 0)
End Function

Private Function GutterMark( _
    ByVal w As Widget Ptr, ByVal lineNumber As Integer, _
    ByVal lineStart As Integer _
) As ULong
    gutterMarks += 1
    Return RGB(160, 40, 60)
End Function

Private Function FoldMark( _
    ByVal w As Widget Ptr, ByVal lineNumber As Integer, _
    ByVal lineStart As Integer _
) As Integer
    foldMarks += 1
    Return -1
End Function

Private Sub GutterClick( _
    ByVal w As Widget Ptr, ByVal lineNumber As Integer, _
    ByVal lineStart As Integer _
)
    If lineNumber = 0 AndAlso lineStart = 0 Then gutterClicks += 1
End Sub

Private Sub FoldClick( _
    ByVal w As Widget Ptr, ByVal lineNumber As Integer, _
    ByVal lineStart As Integer _
)
    If lineNumber = 0 AndAlso lineStart = 0 Then foldClicks += 1
End Sub

Private Function HideMiddle( _
    ByVal w As Widget Ptr, ByVal lineNumber As Integer, _
    ByVal lineStart As Integer _
) As Integer
    If lineNumber = 1 AndAlso lineStart = 4 Then
        hiddenLineChecks += 1
        Return 0
    End If
    Return -1
End Function

Private Sub PressKey(ByVal code As Integer)
    input_MockKey code, 1
    gui_UpdateAll
    input_MockKey code, 0
    gui_UpdateAll
End Sub

backend_Init 320, 200, BACKEND_HEADLESS_DRAWABLE
gui_Init
input_ResetForTest

Dim As Widget Ptr editor = textbox_Create( _
    "unicode", "a" & Chr(&HE4, &HB8, &HAD) & "b", _
    10, 10, 200, 90, -1, 0 _
)
Require editor <> 0, "allocation"
gui_AddWidget editor
gui_SetFocus editor
Dim As TextBoxData Ptr d = Cast(TextBoxData Ptr, editor->data)
textbox_SetTypedTextHandler editor, @AfterTyping
textbox_SetIndentGuides editor, -1, RGB(30, 40, 50)
textbox_SetRightEdge editor, 80, RGB(60, 70, 80)
gui_RenderAll

textbox_SetText editor, "aa" & Chr(10) & "a", -1
textbox_SetTextDisplayHandler editor, @DisplayByte
textbox_SetTextColorHandler editor, @ColorByte
textbox_SetTextStyleHandler editor, @StyleByte
textbox_SetTextIndicatorHandler editor, @MarkByte
gui_RenderAll
Require d->text = "aa" & Chr(10) & "a", "display hook preserves source"
Require d->display_text = "WW" & Chr(10) & "W", _
    "display hook follows source byte positions"
Require colorCalls = 3 AndAlso styleCalls = 3, _
    "color and style callbacks visit source bytes"
Require colorSawReset, "line-local callback state resets"
Require indicatorCalls = 3, "indicator visits source positions"
textbox_SetLineNumbers editor, -1
textbox_SetGutterMarkerHandler editor, @GutterMark
textbox_SetGutterClickHandler editor, @GutterClick
textbox_SetFoldGutter editor, 15, @FoldMark, @FoldClick
textbox_SetFoldColors editor, RGB(20, 20, 20), _
    RGB(200, 200, 200), RGB(40, 40, 40)
gui_RenderAll
Require gutterMarks >= 2 AndAlso foldMarks >= 2, "gutter markers render"
gui_RefreshLayout
input_MockMouse editor->ax + 8, editor->ay + 8, 1
gui_UpdateAll
input_MockMouse editor->ax + 8, editor->ay + 8, 0
gui_UpdateAll
Require gutterClicks = 1, "gutter click callback"
input_MockMouse editor->ax + d->line_number_gutter_width + 7, _
    editor->ay + 8, 1
gui_UpdateAll
input_MockMouse editor->ax + d->line_number_gutter_width + 7, _
    editor->ay + 8, 0
gui_UpdateAll
Require foldClicks = 1, "fold click callback"
textbox_SetFoldGutter editor, 0, 0, 0
textbox_SetTextDisplayHandler editor, 0
textbox_SetTextColorHandler editor, 0
textbox_SetTextStyleHandler editor, 0
textbox_SetTextIndicatorHandler editor, 0
textbox_SetText editor, "top" & Chr(10) & "middle" & Chr(10) & "bottom", -1
textbox_SetLineVisibilityHandler editor, @HideMiddle
gui_RenderAll
Require hiddenLineChecks > 0, "visibility callback observes source line"
Require d->total_visual_lines = 2, "hidden source line leaves visual map"
textbox_SetLineVisibilityHandler editor, 0
textbox_SetText editor, "a" & Chr(&HE4, &HB8, &HAD) & "b", -1

Require textbox_SetCursorPosition(editor, 4), "position at UTF-8 boundary"
PressKey KEY_LEFT
Require d->cursor_pos = 1, "left skips the entire UTF-8 scalar"
PressKey KEY_RIGHT
Require d->cursor_pos = 4, "right skips the entire UTF-8 scalar"
PressKey KEY_BACKSPACE
Require d->text = "ab" AndAlso d->cursor_pos = 1, _
    "backspace removes the entire UTF-8 scalar"

textbox_SetText editor, "a" & Chr(&HE4, &HB8, &HAD) & "b", -1
Require textbox_SetCursorPosition(editor, 1), "position before UTF-8 scalar"
PressKey KEY_DELETE
Require d->text = "ab" AndAlso d->cursor_pos = 1, _
    "delete removes the entire UTF-8 scalar"

input_MockText "x"
gui_UpdateAll
Require typedCalls = 1, "typed text callback"

textbox_SetFontScalePercent editor, 150
textbox_SetZoomPercent editor, 125
textbox_SetLineSpacing editor, 3
textbox_SetFont editor, BACKEND_FONT_CASCADIA_MONO
Require d->font_scale_percent = 150 AndAlso d->zoom_percent = 125, _
    "font and zoom settings"
Require d->extra_line_spacing = 3 AndAlso _
    d->font_id = BACKEND_FONT_CASCADIA_MONO, "line spacing and font"
gui_RenderAll

textbox_SetFont editor, BACKEND_FONT_DEFAULT
textbox_SetFontScalePercent editor, 100
textbox_SetZoomPercent editor, 100
textbox_SetLineSpacing editor, 0
textbox_SetText editor, "a", -1
textbox_SetVirtualSpace editor, -1
Require textbox_SetCursorPosition(editor, 1), "virtual origin"
PressKey KEY_RIGHT
PressKey KEY_RIGHT
Require d->cursor_pos = 1 AndAlso d->cursor_virtual_space = 2, _
    "right moves through virtual columns"
Dim As ULong serialBefore = d->change_serial
input_MockText "x"
gui_UpdateAll
Require d->text = "a  x" AndAlso d->cursor_virtual_space = 0, _
    "typing materializes virtual columns"
Require d->change_serial > serialBefore, "text change advances serial"
Require textbox_Undo(editor), "undo virtual insertion"
Require d->text = "a" AndAlso d->cursor_virtual_space = 2, _
    "undo restores virtual caret"
Require textbox_Redo(editor), "redo virtual insertion"
Require d->text = "a  x" AndAlso d->change_serial > serialBefore, _
    "redo restores text and advances serial"
Require textbox_Undo(editor), "return to virtual caret"
PressKey KEY_BACKSPACE
Require d->text = "a" AndAlso d->cursor_virtual_space = 1, _
    "backspace moves in virtual space without editing"
d->sel_start = 1
d->sel_end = 1
d->sel_start_virtual_space = 1
d->sel_end_virtual_space = 3
Require textbox_GetSelectedText(editor) = "  ", _
    "virtual-only selection copies blank columns"
Require textbox_ReplaceSelection(editor, "Q"), _
    "replace virtual-only selection"
Require d->text = "a Q", "replacement materializes selected line position"
Require textbox_Undo(editor), "undo virtual-only replacement"
textbox_ClearVirtualSpace editor
Require d->cursor_virtual_space = 0, "clear virtual offsets"
textbox_SetVirtualSpace editor, 0
Require textbox_SetInputLimit(editor, 8), "set editor byte limit"
Require d->max_text_bytes = 8, "source byte-limit field stays synchronized"
textbox_SetInputLimit editor, 0

/'
    A small viewport must not run syntax callbacks over rows below it.
    Earlier rows still establish multiline state when scrolling down.
'/
Dim As String viewportSource
For rowIndex As Integer = 0 To 199
    viewportSource &= "aa" & Chr(13, 10)
Next rowIndex
textbox_SetText editor, viewportSource, -1
textbox_SetTextColorHandler editor, @ColorByte
colorCalls = 0
gui_RenderAll
Require colorCalls > 0 AndAlso colorCalls < 100, _
    "syntax visits only rows through the viewport"
d->v_scroll = 20
colorCalls = 0
gui_RenderAll
Require colorCalls >= 40 AndAlso colorCalls < 140, _
    "scrolled syntax retains preceding multiline state"
Require d->total_visual_lines = 201, "CRLF metrics retain offscreen rows"
textbox_SetTextColorHandler editor, 0

textbox_SetText editor, Chr(&HE4, &H80) & "z", -1
Require textbox_SetCursorPosition(editor, 0), "malformed start"
PressKey KEY_RIGHT
Require d->cursor_pos = 1, "malformed byte makes progress"

/'
    Maximum-width scans must agree with the backend's full UTF-8 measurement,
    including malformed bytes, tabs and per-glyph rounding at fractional zoom.
'/
Dim As String widthLine = "wide" & Chr(9, &HE4, &HB8, &HAD) & _
    Chr(&HE4, &H80) & String(180, "W")
textbox_SetText editor, "short" & Chr(13, 10) & widthLine, -1
For scalePercent As Integer = 100 To 150 Step 25
    textbox_SetFontScalePercent editor, scalePercent
    Require textbox_MaximumLineWidth(d->text, d) = textbox_TextWidth(d, widthLine), _
        "ASCII advance table preserves Unicode and zoom metrics"
Next scalePercent

gui_RemoveWidgetPtr editor
backend_Exit
Print "textbox_unicode_editor_smoke OK"

' end of textbox_unicode_editor_smoke.bas
