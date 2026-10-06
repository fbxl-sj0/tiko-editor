/'
    Project: omaGUI Tests
    File: textbox_selection_api_smoke.bas
    Purpose: Verify public selection APIs and opt-out Tab traversal.
    Responsibilities:
        - validate range bounds, insertion, undo and reverse selections
        - check selection visibility without losing retained editor state
        - preserve pointer/explicit focus when Tab traversal is disabled
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:
        - VB-specific policies, host clipboard access, or platform controls
'/

#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim Shared As Integer checks, failures
Dim Shared As String diagnostics
Private Sub test_Require(ByVal condition As Integer, ByRef message_text As Const String)
    checks += 1
    If condition Then Exit Sub
    failures += 1
    diagnostics &= "FAIL " & message_text & Chr(10)
End Sub

ScreenControl FB.SET_DRIVER_NAME, "null"
backend_Init(400, 180, BACKEND_DISPLAY_ENABLED)
gui_Init()
Dim As Widget Ptr editor = textbox_Create("editor", "abcdef", 10, 10, 180, 24, 0, -1)
Dim As Widget Ptr next_editor = textbox_Create("next_editor", "", 10, 45, 180, 24, 0, -1)
Dim As Widget Ptr third = textbox_Create("third", "", 10, 80, 180, 24, 0, -1)
gui_AddWidget(editor): gui_AddWidget(next_editor): gui_AddWidget(third)
gui_SetTabOrder(editor, 0): gui_SetTabOrder(next_editor, 1): gui_SetTabOrder(third, 2)
gui_SynchronizeLayout()
test_Require(gui_GetTabStop(editor) AndAlso gui_GetTabStop(next_editor), "existing widgets default to Tab stops")
gui_SetTabStop(next_editor, 0)
gui_SetFocus(editor)
gui_MoveFocus(0)
test_Require(gui_GetFocus() = third, "forward Tab skips opted-out editor")
gui_MoveFocus(-1)
test_Require(gui_GetFocus() = editor, "reverse Tab skips opted-out editor")
gui_SetFocus(next_editor)
test_Require(gui_GetFocus() = next_editor, "explicit focus remains available")
gui_SetFocus(editor)
input_MockMouse(20, 53, 1): gui_UpdateAll()
input_MockMouse(20, 53, 0): gui_UpdateAll()
test_Require(gui_GetFocus() = next_editor, "pointer focus remains available")
gui_SetTabStop(next_editor, -1)
gui_SetFocus(editor): gui_MoveFocus(0)
test_Require(gui_GetFocus() = next_editor, "Tab stop can be restored")

test_Require(textbox_SetSelectionRange(editor, 1, 3), "set selection range")
test_Require(textbox_GetSelectionStart(editor) = 1 AndAlso textbox_GetSelectionLength(editor) = 3 AndAlso _
    textbox_GetSelectedText(editor) = "bcd", "public range and text queries")
textbox_SetCursorPosition(editor, 5)
textbox_SetCursorPosition(editor, 2, -1)
test_Require(textbox_GetSelectionStart(editor) = 2 AndAlso textbox_GetCursorPosition(editor) = 2 AndAlso _
    textbox_GetSelectionLength(editor) = 3, "reverse selection reports lower endpoint")
test_Require(textbox_SetSelectionRange(editor, -1, 2) = 0 AndAlso textbox_GetSelectionStart(editor) = 2, "negative start rejected without mutation")
test_Require(textbox_SetSelectionRange(editor, 1, -1) = 0 AndAlso textbox_GetSelectionStart(editor) = 2, "negative length rejected without mutation")
test_Require(textbox_SetSelectionRange(editor, 2147483647, 2147483647) AndAlso _
    textbox_GetSelectionStart(editor) = 6 AndAlso textbox_GetSelectionLength(editor) = 0, "oversized range clamps without addition overflow")
textbox_SetSelectionRange(editor, 3, 0)
test_Require(textbox_InsertAtSelection(editor, "XY") AndAlso textbox_GetText(editor) = "abcXYdef" AndAlso _
    textbox_GetCursorPosition(editor) = 5, "empty selection inserts at caret")
test_Require(textbox_Undo(editor) AndAlso textbox_GetText(editor) = "abcdef" AndAlso _
    textbox_GetCursorPosition(editor) = 3, "insertion undo restores text and caret")
textbox_SetSelectionRange(editor, 1, 2)
test_Require(textbox_InsertAtSelection(editor, "Q") AndAlso textbox_GetText(editor) = "aQdef", "selected text replaced")
test_Require(textbox_ReplaceSelection(editor, "Z") = 0, "older replace command still requires a selection")
textbox_SetSelectionRange(editor, 1, 1)
test_Require(textbox_InsertAtSelection(editor, "") AndAlso textbox_GetText(editor) = "adef", "empty replacement deletes selection")
textbox_SetReadOnly(editor, -1)
test_Require(textbox_InsertAtSelection(editor, "X") = 0 AndAlso textbox_GetText(editor) = "adef", "read-only insertion rejected")
textbox_SetReadOnly(editor, 0)
test_Require(textbox_InsertAtSelection(editor, String(TEXTBOX_HISTORY_MAX_STORED_BYTES + 1, "x")) = 0 AndAlso _
    textbox_GetText(editor) = "adef", "oversized insertion rejected before history or text changes")
test_Require(textbox_SetSelectionRange(0, 0, 0) = 0 AndAlso textbox_InsertAtSelection(0, "x") = 0, "null calls rejected")

' Compare native framebuffer pixels while focus remains elsewhere. Hiding
' selection changes only the highlight, never the retained range or text.
textbox_SetSelectionRange(editor, 0, 3)
gui_SetFocus(third)
test_Require(textbox_GetHideSelection(editor) = 0, "selection remains visible by default")
backend_Clear(current_theme.bg_face): gui_RenderAll()
Dim As ULong selected_pixels(0 To 179, 0 To 23)
For pixel_y As Integer = 0 To 23
    For pixel_x As Integer = 0 To 179
        selected_pixels(pixel_x, pixel_y) = Point(10 + pixel_x, 10 + pixel_y)
    Next pixel_x
Next pixel_y
test_Require(textbox_SetHideSelection(editor, -1), "opt in to hiding selection on blur")
backend_Clear(current_theme.bg_face): gui_RenderAll()
Dim As Integer changed_pixels
For pixel_y As Integer = 0 To 23
    For pixel_x As Integer = 0 To 179
        If selected_pixels(pixel_x, pixel_y) <> Point(10 + pixel_x, 10 + pixel_y) Then changed_pixels += 1
    Next pixel_x
Next pixel_y
test_Require(changed_pixels > 0 AndAlso textbox_GetSelectedText(editor) = "ade", "blur hides highlight while retaining selected text")
textbox_SetHideSelection(editor, 0)
backend_Clear(current_theme.bg_face): gui_RenderAll()
Dim As Integer restored = -1
For pixel_y As Integer = 0 To 23
    For pixel_x As Integer = 0 To 179
        If selected_pixels(pixel_x, pixel_y) <> Point(10 + pixel_x, 10 + pixel_y) Then restored = 0
    Next pixel_x
Next pixel_y
test_Require(restored, "visible-selection pixels restored exactly")
gui_ResetForTest()
backend_Exit()
Screen 0
If Len(diagnostics) Then Print diagnostics;
If failures Then End 1
Print "textbox_selection_api_smoke: PASS ("; checks; " checks)"
End 0

/' end of textbox_selection_api_smoke.bas '/
