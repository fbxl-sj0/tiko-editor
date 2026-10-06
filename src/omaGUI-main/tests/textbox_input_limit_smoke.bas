/'
    Project: omaGUI Tests
    File: textbox_input_limit_smoke.bas
    Purpose: Verify opt-in byte limits without changing ordinary editor behavior.
    Responsibilities: test typing, selection, paste, history and atomic commands.
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain: VB policies, host clipboard access or platform APIs.
'/
#lang "fb"
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"
Dim Shared As Integer checks, failures
Dim Shared As String diagnostics
Private Sub Require(ByVal condition As Integer, ByRef description As Const String)
    checks += 1
    If condition Then Exit Sub
    failures += 1: diagnostics &= "FAIL: " & description & Chr(10)
End Sub
ScreenControl FB.SET_DRIVER_NAME, "null"
backend_Init(400, 240, BACKEND_DISPLAY_ENABLED)
gui_Init()
Dim As Widget Ptr editor = textbox_Create("editor", "", 10, 10, 220, 90, -1, 0)
Dim As Widget Ptr other = button_Create("other", "Other", 10, 120, 90, 25)
gui_AddWidget(editor): gui_AddWidget(other)
gui_SynchronizeLayout(): gui_SetFocus(editor)
Require(textbox_GetInputLimit(editor) = 0, "existing editors default to unlimited input")
input_MockText("abcdef"): gui_UpdateAll()
Require(textbox_GetText(editor) = "abcdef", "unlimited native typing unchanged")
Require(textbox_SetInputLimit(editor, 4), "set native limit")
Require(textbox_GetText(editor) = "abcdef" AndAlso textbox_GetCursorPosition(editor) = 6, "policy change preserves text and caret")
Require(textbox_SetInputLimit(editor, -1) = 0 AndAlso textbox_GetInputLimit(editor) = 4, "invalid limit preserves prior policy")
Require(textbox_SetInputLimit(0, 1) = 0 AndAlso textbox_SetInputLimit(other, 1) = 0, "input limit validates provider")
Require(textbox_SetInputLimit(editor, 2147483647) AndAlso textbox_GetInputLimit(editor) = 2147483647, "signed Long maximum is representable")
textbox_SetInputLimit(editor, 4)
textbox_SetText(editor, "", -1)
input_MockText("abcdef"): gui_UpdateAll()
Require(textbox_GetText(editor) = "abcd" AndAlso textbox_GetCursorPosition(editor) = 4, "typed batch truncates at limit")
input_MockText("e"): gui_UpdateAll()
Require(textbox_GetText(editor) = "abcd", "typing at capacity does nothing")
textbox_SetSelectionRange(editor, 1, 2)
input_MockText("XYZ"): gui_UpdateAll()
Require(textbox_GetText(editor) = "aXYd", "selection releases room before typing is truncated")
Require(textbox_GetCursorPosition(editor) = 3 AndAlso textbox_GetSelectionLength(editor) = 0, "replacement advances by accepted bytes")
Require(textbox_Undo(editor) AndAlso textbox_GetText(editor) = "abcd", "undo restores full selected text")
textbox_SetSelectionRange(editor, 4, 0)
clipboard_SetText("no room")
Require(textbox_Paste(editor) = 0 AndAlso textbox_GetCursorPosition(editor) = 4, "blocked paste retains caret")
Require(textbox_Redo(editor) AndAlso textbox_GetText(editor) = "aXYd", "blocked paste preserves pending redo")
textbox_SetSelectionRange(editor, 1, 2)
clipboard_SetText("12more")
Require(textbox_Paste(editor) AndAlso textbox_GetText(editor) = "a12d", "paste truncates only inserted bytes, preserving suffix")
textbox_SetCursorPosition(editor, 3)
textbox_SetCursorPosition(editor, 1, -1)
Require(textbox_InsertAtSelection(editor, "UVW") AndAlso textbox_GetText(editor) = "aUVd", "reverse selection supplies insertion capacity")
textbox_SetSelectionRange(editor, 1, 2)
Require(textbox_ReplaceSelection(editor, "xyz") AndAlso textbox_GetText(editor) = "axyd", "replace selection respects limit")
textbox_SetSelectionRange(editor, 1, 2)
Require(textbox_InsertAtSelection(editor, "") AndAlso textbox_GetText(editor) = "ad", "empty explicit replacement still deletes selection")
Require(textbox_SetText(editor, "oversized", -1) AndAlso textbox_GetText(editor) = "oversized", "native programmatic SetText remains unrestricted")
textbox_SetSelectionRange(editor, 1, 1)
Require(textbox_InsertAtSelection(editor, "z") = 0 AndAlso textbox_GetSelectedText(editor) = "v", "blocked oversized insertion preserves selection")
textbox_SetSelectionRange(editor, 0, 9)
Require(textbox_InsertAtSelection(editor, "abcdef") AndAlso textbox_GetText(editor) = "abcd", "full selection can replace oversized content")
textbox_SetReadOnly(editor, -1)
textbox_SetSelectionRange(editor, 0, 4)
Require(textbox_Paste(editor) = 0 AndAlso textbox_GetText(editor) = "abcd", "read-only still blocks limited edits")
textbox_SetReadOnly(editor, 0)

textbox_SetText(editor, "abc", -1): gui_SetFocus(editor)
input_MockKey(KEY_RETURN, -1): gui_UpdateAll()
input_MockKey(KEY_RETURN, 0): gui_UpdateAll()
Require(textbox_GetText(editor) = "abc" & Chr(10), "multiline Return consumes one stored byte")
input_MockKey(KEY_RETURN, -1): gui_UpdateAll()
input_MockKey(KEY_RETURN, 0): gui_UpdateAll()
Require(Len(textbox_GetText(editor)) = 4, "Return at capacity is blocked")
textbox_SetText(editor, "ab", -1)
textbox_SetAcceptsTab(editor, -1)
input_MockKeyPress(FB.SC_TAB): gui_UpdateAll()
Require(textbox_GetText(editor) = "ab  ", "Tab spaces respect remaining room")
textbox_SetText(editor, "abc", -1)
Require(textbox_ReplaceAll(editor, "a", "AAA") = 0 AndAlso textbox_GetText(editor) = "abc", "oversized bulk replace is atomic")
Require(textbox_ReplaceAll(editor, "a", "AA") = 1 AndAlso textbox_GetText(editor) = "AAbc", "fitting bulk replace is accepted")
Require(textbox_Undo(editor) AndAlso textbox_GetText(editor) = "abc", "bulk replacement owns one undo transaction")
Require(textbox_IndentSelection(editor) = 0 AndAlso textbox_GetText(editor) = "abc", "oversized block indent is atomic")
Require(textbox_Redo(editor) AndAlso textbox_GetText(editor) = "AAbc", "blocked indent retains redo")
textbox_SetText(editor, "    abc", -1)
Require(textbox_UnindentSelection(editor) AndAlso textbox_GetText(editor) = "abc", "outdent may shrink oversized source")
textbox_SetInputLimit(editor, 0)
textbox_SetCursorPosition(editor, 3)
input_MockText("defgh"): gui_UpdateAll()
Require(textbox_GetText(editor) = "abcdefgh", "clearing limit restores unlimited typing")
gui_ResetForTest(): backend_Exit(): Screen 0
If Len(diagnostics) Then Print diagnostics;
Print "textbox_input_limit_smoke: "; checks; " checks, "; failures; " failures"
If failures Then End 1
End 0
/' end of textbox_input_limit_smoke.bas '/
