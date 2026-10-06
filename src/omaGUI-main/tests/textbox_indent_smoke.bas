/'
    Project: omaGUI Tests
    File: textbox_indent_smoke.bas
    Purpose: Verify native multiline indentation through the public textbox API.
    Responsibilities:
        - preserve selected source, line endings, caret direction, and undo state
        - exercise opt-in keyboard input without changing normal focus traversal
        - reject invalid, read-only, single-line, and oversized edits atomically
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:
        - IDE menu policy, host clipboard access, or platform keyboard injection
'/

#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub indent_Require(ByVal success As Integer, ByVal source_line As Integer)
    If success Then Exit Sub
    gui_ResetForTest
    backend_Exit
    Print "textbox_indent_smoke: FAIL at line "; source_line
    End 1
End Sub

Private Sub indent_Select(ByVal w As Widget Ptr, ByVal anchor As Integer, ByVal cursor As Integer)
    indent_Require textbox_SetCursorPosition(w, anchor), __LINE__
    indent_Require textbox_SetCursorPosition(w, cursor, -1), __LINE__
End Sub

Private Sub indent_Key(ByVal key_code As Integer, ByVal modifiers As Integer = 0)
    input_MockKeyPress key_code, modifiers
    gui_UpdateAll
End Sub

backend_Init 640, 480, BACKEND_HEADLESS
gui_Init
input_ResetForTest
Dim As Widget Ptr editor_widget = textbox_Create("indent_editor", "", 10, 10, 320, 160, -1, 0)
Dim As Widget Ptr single_line = textbox_Create("single_line", "single", 10, 190, 240, 24, 0, 0)
Dim As Widget Ptr other_widget = button_Create("other", "Other", 350, 10, 100, 24)
indent_Require editor_widget <> 0 AndAlso single_line <> 0 AndAlso other_widget <> 0, __LINE__
gui_AddWidget editor_widget
gui_AddWidget single_line
gui_AddWidget other_widget
Dim As TextBoxData Ptr textData = Cast(TextBoxData Ptr, editor_widget->data)
Dim As String original_text = "one" & Chr(13, 10) & "two" & Chr(13, 10) & "three"
Dim As String indented_text = "    one" & Chr(13, 10) & "    two" & Chr(13, 10) & "three"

' -------------------------------------------------------------------------
' Public commands, selection boundaries, and history
' -------------------------------------------------------------------------

textbox_SetText editor_widget, original_text, -1
indent_Select editor_widget, 0, 10
indent_Require textbox_IndentSelection(editor_widget), __LINE__
indent_Require textData->text = indented_text AndAlso textData->undoCount = 1, __LINE__
indent_Require textData->cursor_pos = 18 AndAlso textData->selection_anchor = 4 AndAlso _
    textData->sel_start = 4 AndAlso textData->sel_end = 18, __LINE__
indent_Require textbox_Undo(editor_widget) AndAlso textData->text = original_text AndAlso _
    textData->cursor_pos = 10 AndAlso textData->selection_anchor = 0, __LINE__
indent_Require textbox_Redo(editor_widget) AndAlso textData->text = indented_text AndAlso _
    textData->cursor_pos = 18 AndAlso textData->selection_anchor = 4, __LINE__
indent_Require textbox_UnindentSelection(editor_widget) AndAlso textData->text = original_text AndAlso _
    textData->cursor_pos = 10 AndAlso textData->selection_anchor = 0, __LINE__
indent_Require textbox_Undo(editor_widget) AndAlso textData->text = indented_text, __LINE__

original_text = "one" & Chr(10) & "second" & Chr(10) & "third"
textbox_SetText editor_widget, original_text, -1
indent_Select editor_widget, 8, 1
indent_Require textbox_IndentSelection(editor_widget), __LINE__
indent_Require textData->text = "    one" & Chr(10) & "    second" & Chr(10) & "third", __LINE__
indent_Require textData->cursor_pos = 5 AndAlso textData->selection_anchor = 16 AndAlso _
    textData->sel_start = 5 AndAlso textData->sel_end = 16, __LINE__
indent_Require textbox_Undo(editor_widget) AndAlso textData->text = original_text AndAlso _
    textData->cursor_pos = 1 AndAlso textData->selection_anchor = 8, __LINE__

' Each separator keeps its exact bytes; selecting up to the next line excludes it.
For newline_kind As Integer = 0 To 2
    Dim As String newline_text
    Select Case newline_kind
    Case 0: newline_text = Chr(10)
    Case 1: newline_text = Chr(13)
    Case 2: newline_text = Chr(13, 10)
    End Select
    original_text = "a" & newline_text & "b" & newline_text
    textbox_SetText editor_widget, original_text, -1
    indent_Select editor_widget, 0, 1 + Len(newline_text)
    indent_Require textbox_IndentSelection(editor_widget) AndAlso _
        textData->text = "    a" & newline_text & "b" & newline_text, __LINE__
    indent_Require textbox_Undo(editor_widget), __LINE__
    textbox_SelectAll editor_widget
    indent_Require textbox_IndentSelection(editor_widget) AndAlso _
        textData->text = "    a" & newline_text & "    b" & newline_text, __LINE__
Next newline_kind

original_text = "a" & Chr(13, 10) & "b"
textbox_SetText editor_widget, original_text, -1
textbox_SetCursorPosition editor_widget, 2
indent_Require textbox_IndentSelection(editor_widget) AndAlso _
    textData->text = "    a" & Chr(13, 10) & "b" AndAlso textData->cursor_pos = 6, __LINE__
indent_Require textbox_UnindentSelection(editor_widget) AndAlso textData->text = original_text, __LINE__

original_text = Chr(9) & "first" & Chr(13) & "  second" & Chr(10) & _
    "  " & Chr(9) & "third" & Chr(13, 10) & "    fourth" & Chr(10) & "last"
textbox_SetText editor_widget, original_text, -1
textbox_SelectAll editor_widget
indent_Require textbox_UnindentSelection(editor_widget), __LINE__
indent_Require textData->text = "first" & Chr(13) & "second" & Chr(10) & _
    "third" & Chr(13, 10) & "fourth" & Chr(10) & "last", __LINE__
indent_Require textbox_Undo(editor_widget) AndAlso textData->text = original_text, __LINE__

' A cursor within removed indentation clamps to the line start.
textbox_SetText editor_widget, "    code", -1
textbox_SetCursorPosition editor_widget, 2
indent_Require textbox_UnindentSelection(editor_widget) AndAlso textData->text = "code" AndAlso _
    textData->cursor_pos = 0 AndAlso textbox_HasSelection(editor_widget) = 0, __LINE__
indent_Require textbox_Undo(editor_widget) AndAlso textData->cursor_pos = 2, __LINE__

textbox_SetText editor_widget, "", -1
indent_Require textbox_IndentSelection(editor_widget) AndAlso textData->text = "    ", __LINE__
indent_Require textbox_UnindentSelection(editor_widget) AndAlso textData->text = "", __LINE__
textbox_SetText editor_widget, Chr(10, 10), -1
textbox_SelectAll editor_widget
indent_Require textbox_IndentSelection(editor_widget) AndAlso textData->text = "    " & Chr(10) & "    " & Chr(10), __LINE__
textbox_SetCursorPosition editor_widget, Len(textData->text)
indent_Require textbox_IndentSelection(editor_widget) AndAlso Right(textData->text, 5) = Chr(10) & "    ", __LINE__

' Wrapped display rows are not logical lines, and binary bytes are not whitespace.
original_text = String(140, Asc("x")) & Chr(0, 255, 10) & "tail"
textbox_SetText editor_widget, original_text, -1
textData->wordwrap = -1
textbox_SelectAll editor_widget
indent_Require textbox_IndentSelection(editor_widget) AndAlso _
    textData->text = "    " & String(140, Asc("x")) & Chr(0, 255, 10) & "    tail", __LINE__
indent_Require textbox_Undo(editor_widget) AndAlso textData->text = original_text, __LINE__
textData->wordwrap = 0

' -------------------------------------------------------------------------
' Opt-in input and unchanged focus traversal
' -------------------------------------------------------------------------

indent_Require textbox_GetBlockIndent(editor_widget) = 0, __LINE__
indent_Require textbox_SetAcceptsTab(editor_widget, -1), __LINE__
textbox_SetText editor_widget, "ab", -1
indent_Select editor_widget, 0, 2
gui_SetFocus editor_widget
indent_Key FB.SC_TAB
indent_Require textData->text = "  ", __LINE__
indent_Require textbox_SetBlockIndent(editor_widget, -1) AndAlso textbox_GetBlockIndent(editor_widget), __LINE__
original_text = "one" & Chr(10) & "two"
textbox_SetText editor_widget, original_text, -1
textbox_SelectAll editor_widget
indent_Key FB.SC_TAB
indent_Require textData->text = "    one" & Chr(10) & "    two" AndAlso _
    gui_GetFocus() = editor_widget AndAlso textData->undoCount = 1, __LINE__
indent_Key FB.SC_TAB
indent_Require textData->text = "        one" & Chr(10) & "        two" AndAlso _
    textData->undoCount = 2, __LINE__
indent_Require textbox_Undo(editor_widget) AndAlso textData->text = "    one" & Chr(10) & "    two", __LINE__
indent_Key FB.SC_LEFTBRACKET, INPUT_MODIFIER_CONTROL
indent_Require textData->text = original_text AndAlso gui_GetFocus() = editor_widget, __LINE__
indent_Key FB.SC_RIGHTBRACKET, INPUT_MODIFIER_CONTROL
indent_Require textData->text = "    one" & Chr(10) & "    two", __LINE__
indent_Key FB.SC_RIGHTBRACKET, INPUT_MODIFIER_CONTROL Or INPUT_MODIFIER_ALT
indent_Require textData->text = "    one" & Chr(10) & "    two", __LINE__
indent_Key FB.SC_TAB, INPUT_MODIFIER_SHIFT
indent_Require gui_GetFocus() <> editor_widget AndAlso textData->text = "    one" & Chr(10) & "    two", __LINE__

textbox_SetReadOnly editor_widget, -1
gui_SetFocus editor_widget
indent_Key FB.SC_RIGHTBRACKET, INPUT_MODIFIER_CONTROL
indent_Require textbox_IndentSelection(editor_widget) = 0 AndAlso textbox_UnindentSelection(editor_widget) = 0 AndAlso _
    textData->text = "    one" & Chr(10) & "    two", __LINE__
indent_Key FB.SC_TAB
indent_Require gui_GetFocus() <> editor_widget, __LINE__
textbox_SetReadOnly editor_widget, 0
editor_widget->enabled = 0
indent_Require textbox_IndentSelection(editor_widget) = 0 AndAlso textbox_UnindentSelection(editor_widget) = 0, __LINE__
editor_widget->enabled = -1
indent_Require textbox_SetBlockIndent(single_line, -1) = 0 AndAlso _
    textbox_IndentSelection(single_line) = 0 AndAlso textbox_UnindentSelection(single_line) = 0, __LINE__
indent_Require textbox_IndentSelection(0) = 0 AndAlso textbox_UnindentSelection(other_widget) = 0 AndAlso _
    textbox_SetBlockIndent(other_widget, -1) = 0 AndAlso textbox_GetBlockIndent(other_widget) = 0, __LINE__

' -------------------------------------------------------------------------
' No-op and size-limit transactions
' -------------------------------------------------------------------------

textbox_SetText editor_widget, "code", -1
indent_Require textbox_IndentSelection(editor_widget) AndAlso textbox_Undo(editor_widget), __LINE__
Dim As Integer previous_redo = textData->redoCount
Dim As LongInt previous_history_bytes = textData->historyStoredBytes
indent_Require textbox_UnindentSelection(editor_widget) = 0 AndAlso textData->redoCount = previous_redo AndAlso _
    textData->historyStoredBytes = previous_history_bytes AndAlso textbox_Redo(editor_widget), __LINE__

' SetText can load a document near the transaction limit without rendering it.
' Undoing a smaller replacement leaves a real redo entry to protect on failure.
textbox_SetText editor_widget, String(TEXTBOX_HISTORY_MAX_STORED_BYTES - 3, Asc("x")), -1
textbox_SetText editor_widget, "small", 0
indent_Require textbox_Undo(editor_widget), __LINE__
previous_redo = textData->redoCount
previous_history_bytes = textData->historyStoredBytes
indent_Require textbox_IndentSelection(editor_widget) = 0 AndAlso _
    Len(textData->text) = TEXTBOX_HISTORY_MAX_STORED_BYTES - 3 AndAlso _
    textData->cursor_pos = Len(textData->text) AndAlso _
    textData->redoCount = previous_redo AndAlso textData->historyStoredBytes = previous_history_bytes, __LINE__
indent_Require textbox_Redo(editor_widget) AndAlso textData->text = "small", __LINE__

' Many short lines exercise linear reconstruction and the final-line boundary.
original_text = Space(12000)
For byte_index As Integer = 0 To Len(original_text) - 1 Step 2
    original_text[byte_index] = Asc("x")
    original_text[byte_index + 1] = 10
Next byte_index
textbox_SetText editor_widget, original_text, -1
textbox_SelectAll editor_widget
indent_Require textbox_IndentSelection(editor_widget) AndAlso Len(textData->text) = 36000, __LINE__
indent_Require textbox_UnindentSelection(editor_widget) AndAlso textData->text = original_text, __LINE__

gui_ResetForTest
backend_Exit
Print "textbox_indent_smoke: PASS (line endings, selection, undo, input, guards, capacity, large blocks)"
End 0

' end of textbox_indent_smoke.bas
