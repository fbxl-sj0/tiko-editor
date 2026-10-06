/'
    Project: omaGUI Tests
    File: label_alignment_smoke.bas

    Purpose:
        Verify portable fixed-rectangle label layout on a real framebuffer.
    Responsibilities:
        - compare alignment, wrapped lines, and explicit paragraphs with glyphs
        - retain legacy defaults and reject invalid API calls transactionally
        - render bounded bold, italic, underline, and strikeout label styles
        - preserve opaque white when requesting literal label colors
        - verify mnemonic placement and the caller's clip after rendering
    This file intentionally does NOT contain:
        - operating-system GUI calls or application-specific render callbacks
'/

#lang "fb"
#define OMAGUI_IMPLEMENTATION
#define OMAGUI_PORTABLE_ONLY
#include once "omaGUI.bi"

Dim Shared As String test_failure_messages
Dim Shared As Integer test_mismatch_found, test_mismatch_x, test_mismatch_y
Dim Shared As ULong test_mismatch_left, test_mismatch_right
Dim Shared As Integer test_mismatch_ax, test_mismatch_ay, test_mismatch_w, test_mismatch_h
Dim Shared As Integer test_mismatch_font, test_mismatch_percent, test_mismatch_style
Dim Shared As Integer test_mismatch_border, test_mismatch_aligned, test_mismatch_clip
Dim Shared As Integer test_mismatch_wrapped, test_mismatch_text_length
Dim Shared As ULong test_mismatch_text_color
Dim Shared As Widget Ptr labelWidget

Private Sub test_Require(ByVal conditionValue As Integer, _
    ByRef messageText As Const String, ByRef failures As Integer)
    If conditionValue Then Exit Sub
    test_failure_messages &= "FAIL " & messageText & Chr(13, 10)
    failures += 1
End Sub

Private Function test_MatchesReference() As Integer
    ' The left and right halves have identical local coordinates. Only the
    ' left half uses label_Render; the right is a manually positioned glyph
    ' reference using the embedded font and the same framebuffer depth.
    For pixelY As Integer = 0 To 179
        For pixelX As Integer = 0 To 159
            Dim As ULong left_pixel = Point(pixelX, pixelY)
            Dim As ULong right_pixel = Point(pixelX + 160, pixelY)
            If left_pixel <> right_pixel Then
                If test_mismatch_found = 0 Then
                    test_mismatch_found = -1
                    test_mismatch_x = pixelX
                    test_mismatch_y = pixelY
                    test_mismatch_left = left_pixel
                    test_mismatch_right = right_pixel
                    If labelWidget <> 0 Then
                        test_mismatch_ax = labelWidget->ax
                        test_mismatch_ay = labelWidget->ay
                        test_mismatch_w = labelWidget->w
                        test_mismatch_h = labelWidget->h
                        With *Cast(LabelData Ptr, labelWidget->data)
                            test_mismatch_font = .fontId
                            test_mismatch_percent = .fontPercent
                            test_mismatch_style = .textStyle
                            test_mismatch_border = .borderStyle
                            test_mismatch_aligned = .alignmentOverride
                            test_mismatch_clip = .clipToBounds
                            test_mismatch_wrapped = .wordWrap
                            test_mismatch_text_length = Len(.text)
                            test_mismatch_text_color = .clr
                        End With
                    End If
                End If
                Return 0
            End If
        Next pixelX
    Next pixelY
    Return -1
End Function

Dim As Integer failures, horizontalValue, verticalValue, fontId, textWidth, textHeight
Dim As Integer expectedX, expectedY, fontHeight, screenWidth, screenHeight, screenDepth
Dim As Integer styleValue, boldOffset
Dim As ULong retainedColor
Dim As String textValue
Dim As Widget otherWidget
Dim As Integer otherData
otherWidget.data = @otherData

ScreenControl FB.SET_DRIVER_NAME, "null"
backend_Init 320, 180, 0
ScreenInfo screenWidth, screenHeight, screenDepth
If screenWidth <> 320 OrElse screenHeight <> 180 OrElse screenDepth <> 32 Then
    backend_Exit
    Screen 0
    Print "label_alignment_smoke: missing null framebuffer"
    End 1
End If
gui_Init
labelWidget = label_CreateWithColor( _
    "aligned", "AB", 10, 10, RGB(255, 255, 255))
If labelWidget = 0 Then End 1
test_Require(label_SetTextColorLiteral(labelWidget, RGB(255, 255, 255)) AndAlso _
    label_GetTextColor(labelWidget, retainedColor) AndAlso _
    retainedColor = RGB(255, 255, 255), _
    "opaque white remains a literal text color", failures)
gui_AddWidget labelWidget
labelWidget->w = 100
labelWidget->h = 90
gui_SynchronizeLayout

test_Require(label_GetAlignment(labelWidget, horizontalValue, verticalValue) AndAlso _
    horizontalValue = BACKEND_ALIGN_LEFT AndAlso verticalValue = BACKEND_ALIGN_TOP, "initial alignment", failures)
test_Require(label_GetTextStyle(labelWidget) = BACKEND_TEXT_STYLE_NORMAL, _
    "initial text style", failures)
For styleValue = BACKEND_TEXT_STYLE_NORMAL To BACKEND_TEXT_STYLE_ALL
    test_Require(label_SetTextStyle(labelWidget, styleValue), _
        "valid text style", failures)
    test_Require(label_GetTextStyle(labelWidget) = styleValue, _
        "text style round-trip", failures)
Next styleValue
test_Require(label_SetTextStyle(labelWidget, BACKEND_TEXT_STYLE_ALL + 1) = 0 AndAlso _
    label_GetTextStyle(labelWidget) = BACKEND_TEXT_STYLE_ALL, _
    "invalid text style rejected without mutation", failures)
backend_Clear RGB(0, 0, 0)
label_SetTextStyle labelWidget, BACKEND_TEXT_STYLE_NORMAL
test_Require(label_GetText(labelWidget) = "AB" AndAlso _
    label_GetRenderedLineCount(labelWidget) = 1, _
    "style changes preserve caption and layout", failures)
test_Require(label_GetTextStyle(labelWidget) = BACKEND_TEXT_STYLE_NORMAL, _
    "normal style restored before legacy rendering", failures)
test_Require(Cast(LabelData Ptr, labelWidget->data)->fontPercent = 100 AndAlso _
    Cast(LabelData Ptr, labelWidget->data)->fontId = BACKEND_FONT_DEFAULT AndAlso _
    Cast(LabelData Ptr, labelWidget->data)->textStyle = _
        BACKEND_TEXT_STYLE_NORMAL, "label font state before rendering", failures)
label_Render labelWidget
backend_PrintFont 170, 10, RGB(255, 255, 255), "AB", BACKEND_FONT_DEFAULT
test_Require(test_MatchesReference(), "legacy rendering unchanged", failures)
test_Require(label_SetAlignment(0, BACKEND_ALIGN_RIGHT) = 0 AndAlso _
    label_SetAlignment(@otherWidget, BACKEND_ALIGN_RIGHT) = 0 AndAlso _
    label_ClearAlignment(@otherWidget) = 0, "null and wrong widget type", failures)
test_Require(label_GetAlignment(@otherWidget, horizontalValue, verticalValue) = 0 AndAlso _
    horizontalValue = BACKEND_ALIGN_LEFT AndAlso verticalValue = BACKEND_ALIGN_TOP, "failed getter defaults", failures)
test_Require(label_SetTextStyle(0, BACKEND_TEXT_STYLE_BOLD) = 0 AndAlso _
    label_SetTextStyle(@otherWidget, BACKEND_TEXT_STYLE_BOLD) = 0 AndAlso _
    label_GetTextStyle(@otherWidget) = 0, "text style rejects invalid widget", failures)

label_SetClipToBounds labelWidget, -1
For fontIndex As Integer = 0 To 1
    fontId = BACKEND_FONT_DEFAULT
    If fontIndex = 1 Then fontId = BACKEND_FONT_ARIAL_12_BOLD
    label_SetFont labelWidget, fontId
    textWidth = backend_GetTextWidthFont("AB", fontId)
    fontHeight = backend_GetTextHeightFont(fontId)
    For verticalValue = BACKEND_ALIGN_TOP To BACKEND_ALIGN_BOTTOM
        For horizontalValue = BACKEND_ALIGN_LEFT To BACKEND_ALIGN_RIGHT
            test_Require(label_SetAlignment(labelWidget, horizontalValue, verticalValue), "valid alignment", failures)
            expectedX = 170
            expectedY = 10
            Select Case horizontalValue
            Case BACKEND_ALIGN_CENTER: expectedX += (100 - textWidth) \ 2
            Case BACKEND_ALIGN_RIGHT: expectedX += 100 - textWidth
            End Select
            Select Case verticalValue
            Case BACKEND_ALIGN_MIDDLE: expectedY += (90 - fontHeight) \ 2
            Case BACKEND_ALIGN_BOTTOM: expectedY += 90 - fontHeight
            End Select
            backend_Clear RGB(0, 0, 0)
            label_Render labelWidget
            backend_PrintFont expectedX, expectedY, RGB(255, 255, 255), "AB", fontId
            test_Require(test_MatchesReference(), "nine alignment positions with embedded fonts", failures)
        Next horizontalValue
Next verticalValue
Next fontIndex

' Styled output must retain the same right/bottom aligned origin as its
' explicitly rendered reference, including font-size scaling and decoration.
label_SetText labelWidget, "AB"
label_SetFontScalePercent labelWidget, 150
label_SetAlignment labelWidget, BACKEND_ALIGN_RIGHT, BACKEND_ALIGN_BOTTOM
label_SetTextStyle labelWidget, BACKEND_TEXT_STYLE_ALL
textWidth = backend_GetTextWidthFontPercent("AB", fontId, 150)
fontHeight = backend_GetTextHeightFontPercent(fontId, 150)
expectedX = 270 - textWidth
expectedY = 100 - fontHeight
boldOffset = 1
backend_Clear RGB(0, 0, 0)
label_Render labelWidget
backend_SetClip 170, 10, 100, 90
backend_PrintItalicFontPercent expectedX, expectedY, RGB(255, 255, 255), _
    "AB", fontId, 150
backend_PrintItalicFontPercent expectedX + boldOffset, expectedY, _
    RGB(255, 255, 255), "AB", fontId, 150
backend_Line expectedX, expectedY + fontHeight - 2, _
    expectedX + textWidth - 1, expectedY + fontHeight - 2, RGB(255, 255, 255)
backend_Line expectedX, expectedY + fontHeight \ 2, _
    expectedX + textWidth - 1, expectedY + fontHeight \ 2, RGB(255, 255, 255)
backend_ResetClip
test_Require(test_MatchesReference(), "scaled styled text alignment", failures)
label_SetTextStyle labelWidget, BACKEND_TEXT_STYLE_NORMAL
label_SetFontScalePercent labelWidget, 100
label_SetAlignment labelWidget, BACKEND_ALIGN_RIGHT, BACKEND_ALIGN_BOTTOM
fontHeight = backend_GetTextHeightFont(fontId)

test_Require(label_SetAlignment(labelWidget, -1, BACKEND_ALIGN_TOP) = 0 AndAlso _
    label_SetAlignment(labelWidget, BACKEND_ALIGN_LEFT, 3) = 0, "invalid alignment rejected", failures)
test_Require(label_GetAlignment(labelWidget, horizontalValue, verticalValue) AndAlso _
    horizontalValue = BACKEND_ALIGN_RIGHT AndAlso verticalValue = BACKEND_ALIGN_BOTTOM, "failed setter retains alignment", failures)

' Each line aligns independently; vertical placement uses the complete block,
' with the existing two-pixel wrapped-line gap between font-height cells.
textValue = "AB" & Chr(13, 10) & "C"
label_SetText labelWidget, textValue
test_Require(label_GetRenderedLineCount(labelWidget) = 2, "CRLF paragraph count", failures)
textHeight = fontHeight * 2 + 2
backend_Clear RGB(0, 0, 0)
label_Render labelWidget
expectedY = 100 - textHeight
backend_PrintFont 270 - backend_GetTextWidthFont("AB", fontId), expectedY, RGB(255, 255, 255), "AB", fontId
backend_PrintFont 270 - backend_GetTextWidthFont("C", fontId), expectedY + fontHeight + 2, RGB(255, 255, 255), "C", fontId
test_Require(test_MatchesReference(), "paragraph alignment", failures)

label_SetText labelWidget, "WW WW"
label_SetWordWrap labelWidget, backend_GetTextWidthFont("WW", fontId) + 1, 10
test_Require(label_GetRenderedLineCount(labelWidget) = 2, "word wrapping count", failures)
backend_Clear RGB(0, 0, 0)
label_Render labelWidget
backend_PrintFont 171, expectedY, RGB(255, 255, 255), "WW", fontId
backend_PrintFont 171, expectedY + fontHeight + 2, RGB(255, 255, 255), "WW", fontId
test_Require(test_MatchesReference(), "wrapped bottom-right alignment", failures)
label_SetWordWrap labelWidget, labelWidget->w, 1
test_Require(label_GetRenderedLineCount(labelWidget) = 1, "existing maximum-lines limit", failures)

label_SetWordWrap labelWidget, 0
labelWidget->w = 100
label_SetText labelWidget, "AB "
backend_Clear RGB(0, 0, 0)
label_Render labelWidget
backend_PrintFont 270 - backend_GetTextWidthFont("AB ", fontId), 100 - fontHeight, RGB(255, 255, 255), "AB ", fontId
test_Require(test_MatchesReference(), "unwrapped trailing spaces retained", failures)

' Resizing needs no input update or alignment reset. The mnemonic uses the
' selected font's prefix width, including after the label has moved.
label_SetText labelWidget, "AB"
labelWidget->w = 120
labelWidget->x = 5
gui_SynchronizeLayout
gui_SetMnemonic labelWidget, gui_MnemonicScanCode(Asc("B"))
backend_Clear RGB(0, 0, 0)
label_Render labelWidget
expectedX = 285 - backend_GetTextWidthFont("AB", fontId)
expectedY = 100 - fontHeight
backend_PrintFont expectedX, expectedY, RGB(255, 255, 255), "AB", fontId
expectedX += backend_GetTextWidthFont("A", fontId)
backend_Line expectedX, 97, expectedX + backend_GetTextWidthFont("B", fontId) - 1, 97, _
    theme_GetClassicColor(GUI_CLASSIC_COLOR_ACCESS_TEXT)
test_Require(test_MatchesReference(), "resizing and aligned mnemonic", failures)
gui_SetMnemonic labelWidget, 0

backend_Clear RGB(0, 0, 0)
backend_SetClip 0, 0, 100, 180
label_Render labelWidget
backend_PSet 80, 150, RGB(255, 0, 0)
backend_PSet 110, 150, RGB(255, 0, 0)
backend_ResetClip
test_Require((CULng(Point(80, 150)) And &hFFFFFFUL) = &hFF0000UL AndAlso _
    (CULng(Point(110, 150)) And &hFFFFFFUL) = 0, "caller clip restored", failures)

labelWidget->w = 0
backend_Clear RGB(0, 0, 0)
label_Render labelWidget
test_Require(test_MatchesReference(), "zero-width aligned label draws nothing", failures)
labelWidget->w = 100
textValue = String(LABEL_MAXIMUM_ALIGNED_TEXT_BYTES + 1, "W")
test_Require(label_SetText(labelWidget, textValue) = 0 AndAlso label_GetText(labelWidget) = "AB", _
    "oversized aligned text rejected without mutation", failures)
test_Require(label_ClearAlignment(labelWidget), "clear alignment", failures)
test_Require(label_GetAlignment(labelWidget, horizontalValue, verticalValue) AndAlso _
    horizontalValue = BACKEND_ALIGN_LEFT AndAlso verticalValue = BACKEND_ALIGN_TOP, "restored defaults", failures)
backend_Clear RGB(0, 0, 0)
label_Render labelWidget
backend_PrintFont 165, 10, RGB(255, 255, 255), "AB", fontId
test_Require(test_MatchesReference(), "clear restores legacy renderer", failures)

gui_ResetForTest
backend_Exit
Screen 0
If failures Then
    Print test_failure_messages;
    If test_mismatch_found Then
        Print "first pixel mismatch at "; test_mismatch_x; ","; _
            test_mismatch_y; " left="; Hex(test_mismatch_left); _
            " right="; Hex(test_mismatch_right)
        Print "label bounds="; test_mismatch_ax; ","; test_mismatch_ay; _
            " "; test_mismatch_w; "x"; test_mismatch_h; " font="; _
            test_mismatch_font; " scale="; test_mismatch_percent; _
            " style="; test_mismatch_style; " border="; _
            test_mismatch_border; " align="; test_mismatch_aligned; _
            " clip="; test_mismatch_clip; " wrap="; test_mismatch_wrapped; _
            " text bytes="; test_mismatch_text_length; " color="; _
            Hex(test_mismatch_text_color)
    End If
    Print "label_alignment_smoke: FAIL "; failures
    End 1
End If
Print "label_alignment_smoke: PASS"
End 0

/' end of label_alignment_smoke.bas '/
