/'
    Project: omaGUI Tests
    File: textbox_style_smoke.bas
    Purpose: Verify opt-in text styling on the actual portable framebuffer.
    Responsibilities: Check glyph coverage, clipping, editor state and masks.
    This file intentionally does NOT rely on installed fonts or native controls.
'/
#lang "fb"
#define OMAGUI_IMPLEMENTATION
#define OMAGUI_PORTABLE_ONLY
#include once "omaGUI.bi"

Dim Shared As Integer checks, failures
Dim Shared As String diagnostics

Private Sub Require(ByVal condition As Integer, ByRef description As Const String)
    checks += 1
    If condition Then Exit Sub
    failures += 1
    diagnostics &= "FAIL " & description & Chr(10)
End Sub

Private Function SamePanes(ByVal top_row As Integer, ByVal row_count As Integer) As Integer
    For pixel_y As Integer = top_row To top_row + row_count - 1
        For pixel_x As Integer = 0 To 319
            If Point(pixel_x, pixel_y) <> Point(pixel_x + 320, pixel_y) Then Return 0
        Next pixel_x
    Next pixel_y
    Return -1
End Function

Private Function InkCount(ByVal left_column As Integer, ByVal top_row As Integer) As Integer
    Dim As Integer result
    For pixel_y As Integer = top_row To top_row + 25
        For pixel_x As Integer = left_column To left_column + 180
            If (Point(pixel_x, pixel_y) And &hFFFFFF) <> &hFFFFFF Then result += 1
        Next pixel_x
    Next pixel_y
    Return result
End Function

ScreenControl FB.SET_DRIVER_NAME, "null"
backend_Init 640, 240, BACKEND_DISPLAY_ENABLED
gui_Init
backend_Clear RGB(255, 255, 255)
backend_Print 10, 10, RGB(0, 0, 0), "Baseline sample"
backend_PrintStyled 330, 10, RGB(0, 0, 0), "Baseline sample", BACKEND_TEXT_STYLE_NORMAL
Require(SamePanes(0, 35), "normal style preserves exact existing pixels")
backend_Print 10, 45, RGB(0, 0, 0), "MMMM sample"
backend_PrintStyled 330, 45, RGB(0, 0, 0), "MMMM sample", BACKEND_TEXT_STYLE_BOLD
Require(InkCount(330, 45) > InkCount(10, 45), "bold increases glyph coverage")
backend_Print 10, 80, RGB(0, 0, 0), "Italic sample"
backend_PrintStyled 330, 80, RGB(0, 0, 0), "Italic sample", BACKEND_TEXT_STYLE_ITALIC
Require(SamePanes(75, 35) = 0, "italic changes the glyph shape")
Dim As Integer text_height = backend_GetTextHeightFont(BACKEND_FONT_DEFAULT)
backend_PrintStyled 10, 115, RGB(0, 0, 0), "   ", BACKEND_TEXT_STYLE_UNDERLINE
backend_PrintStyled 330, 115, RGB(0, 0, 0), "   ", BACKEND_TEXT_STYLE_STRIKEOUT
Require((Point(10, 115 + text_height - 2) And &hFFFFFF) = 0, "underline crosses spaces")
Require((Point(330, 115 + text_height \ 2) And &hFFFFFF) = 0, "strikeout crosses spaces")
backend_PrintStyled 10, 150, RGB(0, 0, 0), "Mg y", BACKEND_TEXT_STYLE_UNDERLINE
For pixel_x As Integer = 10 To 9 + backend_GetTextWidth("Mg y")
    Require((Point(pixel_x, 150 + text_height - 2) And &hFFFFFF) = 0, "underline stays level across descenders and spaces")
Next pixel_x
backend_Clear RGB(255, 255, 255)
backend_SetClip 10, 10, 8, 8
backend_PrintStyled 8, 6, RGB(0, 0, 0), "Clipped", BACKEND_TEXT_STYLE_ALL
backend_ResetClip
Dim As Integer outside_ink
For pixel_y As Integer = 0 To 39
    For pixel_x As Integer = 0 To 149
        If pixel_x >= 10 AndAlso pixel_x < 18 AndAlso pixel_y >= 10 AndAlso pixel_y < 18 Then Continue For
        If (Point(pixel_x, pixel_y) And &hFFFFFF) <> &hFFFFFF Then outside_ink += 1
    Next pixel_x
Next pixel_y
Require(outside_ink = 0 AndAlso InkCount(0, 0) > 0, "all style ink respects the active clip")
backend_Clear RGB(255, 255, 255)
backend_PrintStyled 10, 10, RGB(0, 0, 0), "invalid", 16
backend_PrintStyled 2147483647, 10, RGB(0, 0, 0), "overflow", BACKEND_TEXT_STYLE_BOLD
Require(InkCount(0, 0) = 0, "invalid flags and extreme positions do not draw")

Dim As Widget Ptr editor = textbox_Create("styled", "abcdef", 10, 10, 270, 50, 0, 0)
Dim As Widget Ptr reference = textbox_Create("reference", "******", 330, 10, 270, 50, 0, 0)
Dim As Widget Ptr other = button_Create("other", "Other", 10, 90, 90, 25)
gui_AddWidget editor
gui_AddWidget reference
gui_AddWidget other
gui_SynchronizeLayout
Require(textbox_GetTextStyle(editor) = BACKEND_TEXT_STYLE_NORMAL, "existing editors remain unstyled")
Require(textbox_SetTextStyle(0, 1) = 0 AndAlso textbox_SetTextStyle(other, 1) = 0, "setter validates widget provider")
textbox_SetSelectionRange editor, 1, 2
textbox_InsertAtSelection editor, "XY"
textbox_SetSelectionRange editor, 1, 3
Dim As Integer previous_cursor = textbox_GetCursorPosition(editor)
For text_style As Integer = 0 To BACKEND_TEXT_STYLE_ALL
    Require(textbox_SetTextStyle(editor, text_style), "all declared style combinations accepted")
    Require(textbox_GetTextStyle(editor) = text_style, "style getter retains combination")
    Require(textbox_GetText(editor) = "aXYdef" AndAlso textbox_GetSelectedText(editor) = "XYd", "style preserves editor text and selection")
    Require(textbox_GetCursorPosition(editor) = previous_cursor AndAlso textbox_CanUndo(editor), "style preserves caret and history")
Next text_style
Require(textbox_SetTextStyle(editor, 16) = 0 AndAlso textbox_GetTextStyle(editor) = BACKEND_TEXT_STYLE_ALL, "invalid bits preserve prior style")
Require(textbox_SetTextStyle(editor, -1) = 0, "negative style rejected")
Require(textbox_Undo(editor) AndAlso textbox_GetText(editor) = "abcdef", "style changes do not create undo transactions")
textbox_SetPasswordChar editor, 42 ' FB-LINTER: DISABLE-LINE FBL008 FBL-SEC-004 REASON: This check exercises the public display-mask API.
textbox_SetTextStyle reference, BACKEND_TEXT_STYLE_ALL
textbox_SetSelectionRange editor, 1, 3
textbox_SetSelectionRange reference, 1, 3
gui_SetFocus 0
backend_Clear RGB(220, 220, 220)
textbox_Render editor
textbox_Render reference
Require(SamePanes(0, 70), "styled mask selection matches styled literal glyphs")

' Exercise the syntax span path with the same token categories and selection.
textbox_SetPasswordChar editor, 0 ' FB-LINTER: DISABLE-LINE FBL008 FBL-SEC-004 REASON: This check clears the public display mask.
textbox_SetText editor, "Dim answer As Integer = 42", -1
textbox_SetText reference, "Dim answer As Integer = 42", -1
textbox_SetSyntaxMode editor, TEXTBOX_SYNTAX_FREEBASIC
textbox_SetSyntaxMode reference, TEXTBOX_SYNTAX_FREEBASIC
textbox_SetSelectionRange editor, 2, 12
textbox_SetSelectionRange reference, 2, 12
textbox_SetTextStyle editor, BACKEND_TEXT_STYLE_NORMAL
textbox_SetTextStyle reference, BACKEND_TEXT_STYLE_NORMAL
backend_Clear RGB(220, 220, 220)
textbox_Render editor
textbox_Render reference
Require(SamePanes(0, 70), "unstyled syntax and selection retain identical rendering")
textbox_SetTextStyle editor, BACKEND_TEXT_STYLE_BOLD Or BACKEND_TEXT_STYLE_ITALIC
backend_Clear RGB(220, 220, 220)
textbox_Render editor
textbox_Render reference
Require(SamePanes(0, 70) = 0, "styles reach syntax-colored and selected spans")
textbox_SetTextStyle reference, BACKEND_TEXT_STYLE_BOLD Or BACKEND_TEXT_STYLE_ITALIC
backend_Clear RGB(220, 220, 220)
textbox_Render editor
textbox_Render reference
Require(SamePanes(0, 70), "syntax styling is per-widget and reproducible")

gui_ResetForTest
backend_Exit
Screen 0
If Len(diagnostics) Then Print diagnostics;
Print "textbox_style_smoke: "; checks; " checks, "; failures; " failures"
If failures Then End 1
End 0
/' end of textbox_style_smoke.bas '/
