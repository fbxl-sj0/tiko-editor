/'
    Project: omaGUI Tests
    File: textbox_masked_input_smoke.bas

    Purpose:
        Verify native masked text editing and visual metrics on a real framebuffer.
    Responsibilities:
        - check opt-in defaults, failed API calls, and preserved editor state
        - exercise clipboard commands through the process-local backend
        - compare masked drawing and pointer placement with literal glyphs
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:
        - host clipboard access, operating-system controls, or VB5 runtime code
'/

#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

' Test diagnostics are buffered while FreeBASIC Print targets the framebuffer.
Dim Shared As Integer test_failures, test_checks
Dim Shared As String test_messages

Private Sub test_Require(ByVal condition As Integer, ByRef message_text As Const String)
    test_checks += 1
    If condition Then Exit Sub
    test_failures += 1
    test_messages &= "FAIL " & message_text & Chr(10)
End Sub

Private Function test_GetMaskChar(ByVal target As Widget Ptr) As Integer
    Return textbox_GetPasswordChar(target) ' FB-LINTER: DISABLE-LINE FBL008 FBL-SEC-004 REASON: Calls the public display-mask API with synthetic test data.
End Function


Private Function test_SetMaskChar( _
    ByVal target As Widget Ptr, ByVal character_code As Integer _
) As Integer
    Return textbox_SetPasswordChar(target, character_code) ' FB-LINTER: DISABLE-LINE FBL008 FBL-SEC-004 REASON: Calls the public display-mask API with synthetic test data.
End Function

Private Sub test_Key(ByVal scan_code As Integer, ByVal modifiers As Integer = 0)
    gui_UpdateAll()
    ' The editor handles navigation through held-key latches, while GUI
    ' shortcuts also consume press events. Supply both views of one key press.
    input_MockKey(scan_code, -1)
    If (modifiers And INPUT_MODIFIER_SHIFT) Then input_MockKey(FB.SC_LSHIFT, -1)
    If (modifiers And INPUT_MODIFIER_CONTROL) Then input_MockKey(FB.SC_CONTROL, -1)
    input_MockKeyPress(scan_code, modifiers)
    gui_UpdateAll()
    input_MockKey(scan_code, 0)
    input_MockKey(FB.SC_LSHIFT, 0)
    input_MockKey(FB.SC_CONTROL, 0)
    gui_UpdateAll()
End Sub

Private Sub test_Mouse(ByVal target As Widget Ptr, ByVal local_x As Integer, ByVal buttons As Integer)
    input_MockMouse(target->ax + local_x, target->ay + 8, buttons)
    gui_UpdateAll()
    input_MockMouse(target->ax + local_x, target->ay + 8, 0)
    gui_UpdateAll()
End Sub

Private Function test_PixelsMatch() As Integer
    ' Both controls have the same local geometry in adjacent 320-pixel panes.
    For pixel_y As Integer = 0 To 59
        For pixel_x As Integer = 0 To 319
            If Point(pixel_x, pixel_y) <> Point(pixel_x + 320, pixel_y) Then Return 0
        Next pixel_x
    Next pixel_y
    Return -1
End Function

ScreenControl FB.SET_DRIVER_NAME, "null"
backend_Init 640, 120, 0
Dim As Integer screen_width, screen_height, screen_depth
ScreenInfo screen_width, screen_height, screen_depth
If screen_width <> 640 OrElse screen_height <> 120 OrElse screen_depth <> 32 Then
    backend_Exit()
    Screen 0
    Print "textbox_masked_input_smoke: missing null framebuffer"
    End 1
End If
gui_Init()

Dim As Widget Ptr masked = textbox_Create("masked", "abcdef", 10, 10, 260, 28, 0, -1)
Dim As Widget Ptr reference = textbox_Create("reference", "******", 330, 10, 260, 28, 0, 0)
Dim As Widget Ptr multiline = textbox_Create("multiline", "one", 10, 70, 260, 40, -1, -1)
If masked = 0 OrElse reference = 0 OrElse multiline = 0 Then
    backend_Exit()
    Screen 0
    Print "textbox_masked_input_smoke: allocation failed"
    End 1
End If
gui_AddWidget(masked)
gui_AddWidget(reference)
gui_AddWidget(multiline)
gui_SynchronizeLayout()
Dim As TextBoxData Ptr masked_data = Cast(TextBoxData Ptr, masked->data)
Dim As TextBoxData Ptr reference_data = Cast(TextBoxData Ptr, reference->data)
Dim As Widget unrelated
Dim As Integer unrelated_data
unrelated.data = @unrelated_data

test_Require(test_GetMaskChar(masked) = 0 AndAlso _
    textbox_GetText(masked) = "abcdef", "existing constructor defaults")
test_Require(textbox_GetText(0) = "" AndAlso textbox_GetText(@unrelated) = "" AndAlso _
    test_GetMaskChar(@unrelated) = 0, "checked getters")
test_Require(test_SetMaskChar(0, 42) = 0 AndAlso _
    test_SetMaskChar(@unrelated, 42) = 0 AndAlso _
    test_SetMaskChar(multiline, 42) = 0, "invalid targets rejected")
test_Require(textbox_GetText(multiline) = "one" AndAlso _
    test_GetMaskChar(multiline) = 0, "failed setter preserves multiline state")

Dim As Integer previous_code, accepted_code
For character_code As Integer = -1 To 256
    previous_code = test_GetMaskChar(masked)
    accepted_code = (character_code = 0 OrElse (character_code >= 33 AndAlso character_code <= 126))
    test_Require((test_SetMaskChar(masked, character_code) <> 0) = accepted_code, "mask byte range")
    If accepted_code Then previous_code = character_code
    test_Require(test_GetMaskChar(masked) = previous_code AndAlso _
        textbox_GetText(masked) = "abcdef", "mask update is transactional")
Next character_code
test_SetMaskChar(masked, 42)
test_Require(masked_data->wordwrap = 0, "mask mode uses one visual line")
textbox_SelectAll(masked)
test_Require(textbox_GetSelectedText(masked) = "abcdef", "application selection reads real text")
clipboard_SetText("clipboard sentinel")
test_Require(textbox_Copy(masked) = 0 AndAlso textbox_Cut(masked) = 0 AndAlso _
    clipboard_GetText() = "clipboard sentinel" AndAlso textbox_GetText(masked) = "abcdef", "direct clipboard export blocked")
gui_SetFocus(masked)
gui_UpdateAll()
test_Key(FB.SC_C, INPUT_MODIFIER_CONTROL)
test_Key(FB.SC_X, INPUT_MODIFIER_CONTROL)
test_Require(clipboard_GetText() = "clipboard sentinel" AndAlso _
    textbox_GetText(masked) = "abcdef" AndAlso textbox_GetSelectionLength(masked) = 6, "keyboard clipboard export blocked")
test_Mouse(masked, 12, 2)
Dim As Widget Ptr context_menu = gui_FindWidget("tb_ctx")
test_Require(context_menu = 0 OrElse context_menu->visible = 0, "context menu excluded for masked input")
test_Mouse(reference, 12, 2)
context_menu = gui_FindWidget("tb_ctx")
test_Require(context_menu <> 0 AndAlso context_menu->visible <> 0, "ordinary menu still reachable")
If context_menu <> 0 Then context_menu->visible = 0

gui_SetFocus(masked)
gui_UpdateAll()
textbox_SelectAll(masked)
clipboard_SetText("replacement")
test_Require(textbox_Paste(masked) AndAlso textbox_GetText(masked) = "replacement", "paste retained")
test_Require(textbox_Undo(masked) AndAlso textbox_GetText(masked) = "abcdef", "undo retains real bytes")
test_Require(textbox_Redo(masked) AndAlso textbox_GetText(masked) = "replacement", "redo retains real bytes")
test_SetMaskChar(masked, 0)
test_Require(masked_data->wordwrap = -1, "clearing mode restores wrapping")
textbox_SelectAll(masked)
test_Require(textbox_Copy(masked) AndAlso clipboard_GetText() = "replacement", "clearing mode restores copy")
test_SetMaskChar(masked, 42)

' Identical masks must have identical glyph, selection, and scroll geometry
' even when the underlying bytes have very different proportional widths.
For pattern_index As Integer = 0 To 3
    Dim As String source_text
    Select Case pattern_index
    Case 0: source_text = "iiiiWWWW"
    Case 1: source_text = String(80, "W")
    Case 2: source_text = String(80, "i")
    Case 3: source_text = "a" & Chr(13) & Chr(10) & "b" & Chr(0) & "c"
    End Select
    textbox_SetText(masked, source_text, -1)
    textbox_SetText(reference, String(Len(source_text), "*"), -1)
    textbox_SetCursorPosition(masked, Len(source_text))
    textbox_SetCursorPosition(reference, Len(source_text))
    test_Require(masked_data->scroll_offset = reference_data->scroll_offset, "mask controls scroll width")
    gui_SetFocus(0)
    backend_Clear(RGB(220, 220, 220))
    textbox_Render(masked)
    textbox_Render(reference)
    test_Require(test_PixelsMatch(), "masked glyphs match literal reference")
    test_Require(textbox_GetText(masked) = source_text, "render preserves editor bytes")
    textbox_SetCursorPosition(masked, 1)
    textbox_SetCursorPosition(masked, Len(source_text) - 1, -1)
    textbox_SetCursorPosition(reference, 1)
    textbox_SetCursorPosition(reference, Len(source_text) - 1, -1)
    backend_Clear(RGB(220, 220, 220))
    textbox_Render(masked)
    textbox_Render(reference)
    test_Require(test_PixelsMatch(), "selected mask matches literal reference")
    For local_x As Integer = 6 To 240 Step 13
        ' Reset to the same end viewport before each independent pointer trial.
        textbox_SetCursorPosition(masked, Len(source_text))
        textbox_SetCursorPosition(reference, Len(source_text))
        test_Mouse(masked, local_x, 1)
        Dim As Integer masked_position = textbox_GetCursorPosition(masked)
        test_Mouse(reference, local_x, 1)
        test_Require(masked_position = textbox_GetCursorPosition(reference), "pointer follows displayed glyph widths")
    Next local_x
Next pattern_index

' Home and End address the displayed single line even if application text
' contains line delimiters. No byte is removed from the stored value.
gui_SetFocus(masked)
gui_UpdateAll()
test_Key(KEY_HOME)
test_Require(textbox_GetCursorPosition(masked) = 0, "masked Home")
test_Key(KEY_END, INPUT_MODIFIER_SHIFT)
test_Require(textbox_GetSelectionLength(masked) = Len(textbox_GetText(masked)), "masked Shift End")
textbox_SetText(masked, "history", -1)
textbox_SelectAll(masked)
textbox_ReplaceSelection(masked, "edited")
Dim As Integer undo_count = masked_data->undoCount
test_SetMaskChar(masked, 35)
test_Require(masked_data->undoCount = undo_count AndAlso textbox_Undo(masked) AndAlso _
    textbox_GetText(masked) = "history", "mode change preserves history")
textbox_SetText(reference, "#######", -1)
textbox_SetCursorPosition(masked, 0)
textbox_SetCursorPosition(reference, 0)
gui_SetFocus(0)
backend_Clear(RGB(220, 220, 220))
textbox_Render(masked)
textbox_Render(reference)
test_Require(test_PixelsMatch(), "changing glyph invalidates cached mask")
textbox_SetText(masked, "", -1)
test_Require(textbox_GetText(masked) = "" AndAlso test_GetMaskChar(masked) = 35, "empty text retains mode")

gui_ResetForTest()
backend_Exit()
Screen 0
If Len(test_messages) Then Print test_messages;
If test_failures Then End 1
Print "textbox_masked_input_smoke: PASS ("; test_checks; " checks)"
End 0

/' end of textbox_masked_input_smoke.bas '/
