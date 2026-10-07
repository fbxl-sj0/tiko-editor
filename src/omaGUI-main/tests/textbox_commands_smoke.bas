/'
    Project: omaGUI Tests
    ---------------------

    File: textbox_commands_smoke.bas

    Purpose:

        Verify the public editor-command API used by application menu bars.

    Responsibilities:

        - copy, cut, paste, and select all through public textbox functions
        - preserve undo history for programmatic mutations
        - reject mutation of a disabled read-only editor
        - insert editor tabs without breaking reverse focus traversal
        - expose and operate an owned horizontal scrollbar for long lines
        - set, query, and clear per-widget client and text colors
        - dispatch ordered key-release callbacks with modifier state
        - use only the bounded process-local clipboard backend

    This file intentionally does NOT contain:

        - application keyboard shortcut routing
        - native clipboard access
        - application-specific editor policy
'/

#lang "fb"

#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

' -------------------------------------------------------------------------
' Borrowed keyboard callback fixture
' -------------------------------------------------------------------------

Dim Shared As Integer textboxCommands_key_up_count
Dim Shared As Integer textboxCommands_last_key
Dim Shared As Integer textboxCommands_last_modifiers

Private Sub textboxCommands_OnKeyUp( _
    ByVal control_widget As Widget Ptr, ByRef key_code As Integer, _
    ByRef modifiers As Integer _
)
    If control_widget = 0 Then Exit Sub
    textboxCommands_key_up_count += 1
    textboxCommands_last_key = key_code
    textboxCommands_last_modifiers = modifiers
End Sub

' -------------------------------------------------------------------------
' Editor command coverage
' -------------------------------------------------------------------------

Dim As Widget Ptr editor_widget
Dim As Widget Ptr single_line_widget
Dim As TextBoxData Ptr editor_data
Dim As Integer column_number
Dim As Integer failure_count
Dim As Integer line_number
Dim As ULong retained_color

backend_Init 320, 240, BACKEND_HEADLESS
gui_Init
editor_widget = textbox_Create( _
    "textbox_commands", "Alpha Beta", 10, 10, 240, 100, -1, 0 _
)
If editor_widget = 0 Then
    Print "textbox_commands_smoke: constructor failed"
    backend_Exit
    End 1
End If
gui_AddWidget editor_widget
editor_data = Cast(TextBoxData Ptr, editor_widget->data)

If textbox_SetBackgroundColor( _
    editor_widget, RGB(11, 22, 33) _
) = 0 OrElse textbox_GetBackgroundColor( _
    editor_widget, retained_color _
) = 0 OrElse retained_color <> RGB(11, 22, 33) Then
    Print "FAIL textbox background color"
    failure_count += 1
End If
If textbox_SetForegroundColor( _
    editor_widget, RGB(44, 55, 66) _
) = 0 OrElse textbox_GetForegroundColor( _
    editor_widget, retained_color _
) = 0 OrElse retained_color <> RGB(44, 55, 66) Then
    Print "FAIL textbox foreground color"
    failure_count += 1
End If

editor_data->sel_start = 0
editor_data->sel_end = 5
editor_data->cursor_pos = 5
If textbox_HasSelection(editor_widget) = 0 OrElse _
   textbox_Copy(editor_widget) = 0 OrElse clipboard_GetText() <> "Alpha" Then
    Print "FAIL public copy"
    failure_count += 1
End If
If textbox_Cut(editor_widget) = 0 OrElse editor_data->text <> " Beta" Then
    Print "FAIL public cut"
    failure_count += 1
End If
If textbox_CanUndo(editor_widget) = 0 OrElse _
   textbox_Undo(editor_widget) = 0 OrElse _
   editor_data->text <> "Alpha Beta" OrElse _
   textbox_CanRedo(editor_widget) = 0 Then
    Print "FAIL cut undo history"
    failure_count += 1
End If

editor_data->sel_start = Len(editor_data->text)
editor_data->sel_end = Len(editor_data->text)
editor_data->cursor_pos = Len(editor_data->text)
clipboard_SetText "!"
If textbox_Paste(editor_widget) = 0 OrElse _
   editor_data->text <> "Alpha Beta!" Then
    Print "FAIL public paste"
    failure_count += 1
End If
If textbox_SelectAll(editor_widget) = 0 OrElse _
   editor_data->sel_start <> 0 OrElse _
   editor_data->sel_end <> Len(editor_data->text) Then
    Print "FAIL public select all"
    failure_count += 1
End If

editor_widget->enabled = 0
If textbox_Cut(editor_widget) <> 0 OrElse _
   textbox_Paste(editor_widget) <> 0 OrElse _
   editor_data->text <> "Alpha Beta!" Then
    Print "FAIL disabled editor mutation guard"
    failure_count += 1
End If

editor_widget->enabled = -1
textbox_SetReadOnly editor_widget, -1
editor_data->sel_start = 0
editor_data->sel_end = 5
editor_data->cursor_pos = 5
If textbox_GetReadOnly(editor_widget) = 0 OrElse _
   textbox_CanUndo(editor_widget) <> 0 OrElse _
   textbox_CanRedo(editor_widget) <> 0 OrElse _
   textbox_Copy(editor_widget) = 0 OrElse clipboard_GetText() <> "Alpha" OrElse _
   textbox_Cut(editor_widget) <> 0 OrElse _
   textbox_Paste(editor_widget) <> 0 OrElse _
   textbox_Undo(editor_widget) <> 0 Then
    Print "FAIL read-only selection and mutation guard"
    failure_count += 1
End If
gui_SetFocus editor_widget
input_MockText "changed"
input_MockKeyPress KEY_BACKSPACE
gui_UpdateAll
If editor_data->text <> "Alpha Beta!" Then
    Print "FAIL read-only keyboard mutation guard"
    failure_count += 1
End If

textbox_SetReadOnly editor_widget, 0

' -------------------------------------------------------------------------
' Ordered key-release callbacks
' -------------------------------------------------------------------------

input_ResetForTest
gui_SetFocus editor_widget
gui_UpdateAll
If textbox_SetKeyUpHandler(editor_widget, @textboxCommands_OnKeyUp) = 0 OrElse _
   input_MockKeyEvent( _
       INPUT_KEY_EVENT_RELEASE, FB.SC_A, 0, _
       INPUT_MODIFIER_SHIFT Or INPUT_MODIFIER_CONTROL _
   ) = 0 Then
    Print "FAIL key-release callback setup"
    failure_count += 1
Else
    gui_UpdateAll
    If textboxCommands_key_up_count <> 1 OrElse _
       textboxCommands_last_key <> FB.SC_A OrElse _
       textboxCommands_last_modifiers <> _
           (INPUT_MODIFIER_SHIFT Or INPUT_MODIFIER_CONTROL) Then
        Print "FAIL key-release callback dispatch"
        failure_count += 1
    End If
End If
If input_MockKeyEvent( _
       INPUT_KEY_EVENT_PRESS, FB.SC_B, 0, INPUT_MODIFIER_ALT _
   ) = 0 Then
    Print "FAIL key-press callback isolation setup"
    failure_count += 1
Else
    gui_UpdateAll
    If textboxCommands_key_up_count <> 1 Then
        Print "FAIL key-release callback accepted a press"
        failure_count += 1
    End If
End If
If textbox_SetKeyUpHandler(editor_widget, 0) = 0 Then
    Print "FAIL key-release callback clear"
    failure_count += 1
End If
input_ResetForTest

textbox_SetText editor_widget, "one" & Chr(13) & Chr(10) & "two", -1
editor_data->cursor_pos = Len(editor_data->text)
editor_data->sel_start = 1
editor_data->sel_end = 6
If textbox_GetCursorPosition(editor_widget) <> 8 OrElse _
   textbox_GetSelectionLength(editor_widget) <> 5 OrElse _
   textbox_GetSelectedText(editor_widget) <> "ne" & Chr(13) & Chr(10) & "t" _
   OrElse _
   textbox_GetLineColumn( _
       editor_widget, line_number, column_number _
   ) = 0 OrElse line_number <> 2 OrElse column_number <> 4 Then
    Print "FAIL public cursor and selection queries"
    failure_count += 1
End If
If textbox_FindText(editor_widget, "TWO", 0, 0, 0) <> 5 OrElse _
   textbox_GetSelectedText(editor_widget) <> "two" OrElse _
   textbox_FindText(editor_widget, "one", 8, -1, -1) <> 0 OrElse _
   textbox_FindText(editor_widget, "missing", 0, 0, -1) <> -1 Then
    Print "FAIL public text search"
    failure_count += 1
End If
If textbox_GotoLine(editor_widget, 2, 2) = 0 OrElse _
   textbox_GetCursorPosition(editor_widget) <> 6 OrElse _
   textbox_GetLineColumn( _
       editor_widget, line_number, column_number _
   ) = 0 OrElse line_number <> 2 OrElse column_number <> 2 OrElse _
   textbox_GotoLine(editor_widget, 3, 1) <> 0 OrElse _
   textbox_SetCursorPosition(editor_widget, 999, 0) = 0 OrElse _
   textbox_GetCursorPosition(editor_widget) <> 8 Then
    Print "FAIL public cursor navigation"
    failure_count += 1
End If
If textbox_FindText(editor_widget, "two", 0, -1, 0) <> 5 OrElse _
   textbox_ReplaceSelection(editor_widget, "second") = 0 OrElse _
   editor_data->text <> "one" & Chr(13) & Chr(10) & "second" OrElse _
   textbox_Undo(editor_widget) = 0 OrElse _
   editor_data->text <> "one" & Chr(13) & Chr(10) & "two" Then
    Print "FAIL public selection replacement"
    failure_count += 1
End If
textbox_SetText editor_widget, "One one ONE", -1
If textbox_ReplaceAll(editor_widget, "one", "item", 0) <> 3 OrElse _
   editor_data->text <> "item item item" OrElse _
   textbox_Undo(editor_widget) = 0 OrElse editor_data->text <> "One one ONE" _
   OrElse textbox_ReplaceAll(editor_widget, "missing", "x", 0) <> 0 Then
    Print "FAIL public replace all"
    failure_count += 1
End If

' -------------------------------------------------------------------------
' Multiline tab stops and focus traversal
' -------------------------------------------------------------------------

single_line_widget = textbox_Create( _
    "single_line", "single", 10, 120, 240, 24, 0, 0 _
)
If single_line_widget = 0 Then
    Print "FAIL single-line constructor"
    failure_count += 1
Else
    gui_AddWidget single_line_widget
End If

If textbox_SetAcceptsTab(editor_widget, -1) = 0 OrElse _
   textbox_GetAcceptsTab(editor_widget) = 0 OrElse _
   textbox_SetAcceptsTab(single_line_widget, -1) <> 0 OrElse _
   textbox_GetAcceptsTab(single_line_widget) <> 0 Then
    Print "FAIL tab-input policy"
    failure_count += 1
End If

textbox_SetText editor_widget, "ab", -1
textbox_SetCursorPosition editor_widget, 2
gui_SetFocus editor_widget
input_MockKeyPress FB.SC_TAB
gui_UpdateAll
If editor_data->text <> "ab  " OrElse _
   textbox_GetCursorPosition(editor_widget) <> 4 OrElse _
   gui_GetFocus() <> editor_widget Then
    Print "FAIL multiline tab-stop insertion"
    failure_count += 1
End If

input_MockKeyPress FB.SC_TAB, INPUT_MODIFIER_SHIFT
gui_UpdateAll
If editor_data->text <> "ab  " OrElse _
   gui_GetFocus() <> single_line_widget Then
    Print "FAIL Shift+Tab focus traversal"
    failure_count += 1
End If

gui_SetFocus editor_widget
textbox_SetReadOnly editor_widget, -1
input_MockKeyPress FB.SC_TAB
gui_UpdateAll
If textbox_GetAcceptsTab(editor_widget) = 0 OrElse _
   editor_widget->captures_tab <> 0 OrElse _
   gui_GetFocus() <> single_line_widget OrElse editor_data->text <> "ab  " Then
    Print "FAIL read-only tab traversal"
    failure_count += 1
End If
textbox_SetReadOnly editor_widget, 0
If editor_widget->captures_tab = 0 Then
    Print "FAIL tab capture restoration"
    failure_count += 1
End If

' -------------------------------------------------------------------------
' Horizontal scrollbar
' -------------------------------------------------------------------------

textbox_SetVerticalScrollbar editor_widget, TEXTBOX_SCROLLBAR_NONE
textbox_SetHorizontalScrollbar editor_widget, TEXTBOX_SCROLLBAR_ALWAYS
textbox_SetText editor_widget, String(80, Asc("W")), -1
textbox_SetCursorPosition editor_widget, 0
gui_UpdateAll
If textbox_GetHorizontalScrollbarMode(editor_widget) <> _
       TEXTBOX_SCROLLBAR_ALWAYS OrElse _
   editor_data->horizontal_scrollbar_visible = 0 OrElse _
   editor_data->scrollbar_visible <> 0 OrElse _
   editor_data->horizontal_scrollbar = 0 OrElse _
   editor_data->horizontal_scrollbar->data = 0 OrElse _
   Cast( _
       ScrollBarData Ptr, editor_data->horizontal_scrollbar->data _
   )->vertical <> 0 Then
    Print "FAIL horizontal scrollbar construction"
    failure_count += 1
Else
    input_MockMouse _
        editor_data->horizontal_scrollbar->ax + _
            editor_data->horizontal_scrollbar->w - 2, _
        editor_data->horizontal_scrollbar->ay + 4, 1
    gui_UpdateAll
    input_MockMouse input_MouseX(), input_MouseY(), 0
    gui_UpdateAll
    If editor_data->scroll_offset <= 0 Then
        Print "FAIL horizontal scrollbar pointer input"
        failure_count += 1
    End If
End If
textbox_SetHorizontalScrollbar editor_widget, TEXTBOX_SCROLLBAR_NONE
gui_UpdateAll
If textbox_GetHorizontalScrollbarMode(editor_widget) <> _
       TEXTBOX_SCROLLBAR_NONE OrElse _
   editor_data->horizontal_scrollbar_visible <> 0 Then
    Print "FAIL horizontal scrollbar hide"
    failure_count += 1
End If
If textbox_ClearBackgroundColor(editor_widget) = 0 OrElse _
   textbox_GetBackgroundColor(editor_widget, retained_color) <> 0 OrElse _
   textbox_ClearForegroundColor(editor_widget) = 0 OrElse _
   textbox_GetForegroundColor(editor_widget, retained_color) <> 0 Then
    Print "FAIL textbox color clear"
    failure_count += 1
End If

gui_ResetForTest
backend_Exit
If failure_count <> 0 Then
    Print "textbox_commands_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "textbox_commands_smoke: PASS"
End 0

/' end of textbox_commands_smoke.bas '/
