/'
    Project: omaGUI RTF Viewer Tests
    ---------------------------------

    File: rtfview_layout_smoke.bas

    Purpose:
        Verify document formatting and measured layout through the real viewer.

    Responsibilities:
        - preserve font, size, color, and group-scoped character properties
        - preserve Unicode scalars through parsing and wrapping
        - verify mixed line heights, margins, and the final scroll page
        - reject malformed or oversized RTF tables without unsafe access

    This file intentionally does NOT contain:
        - application help navigation
        - alternate parser or renderer implementations
        - platform-native rich edit controls

    Targets: FreeBASIC fb dialect with the native omaGUI backend.
    Module API boundary: Standalone development checks for the behavior described above.
'/

#lang "fb"
#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"
#include once "test_harness.bi"

backend_Init 480, 320, BACKEND_HEADLESS_DRAWABLE
gui_Init
input_ResetForTest
input_MockMouse(-10, -10, 0)
Dim As String fontsDirectory = CurDir & "/assets/fonts/"
AssertTrue(backend_LoadFontPack(BACKEND_FONT_DEFAULT, fontsDirectory & "noto_sans_ui.ogf") <> 0, "load the UI face")
AssertTrue(backend_LoadFontPack(BACKEND_FONT_ARIAL_12_BOLD, fontsDirectory & "noto_sans_ui_bold.ogf") <> 0, "load the bold face")
AssertTrue(backend_LoadFontPack(BACKEND_FONT_CASCADIA_MONO, fontsDirectory & "cascadia_mono.ogf") <> 0, "load the monospace face")
AssertTrue(backend_LoadFontPack(BACKEND_FONT_UNICODE_FALLBACK, fontsDirectory & "noto_sans_cjk_sc.ogf") <> 0, "load the Unicode face")
AssertTrue(backend_GetFontPointSize(BACKEND_FONT_DEFAULT) = 9 AndAlso _
    backend_GetFontPointSize(BACKEND_FONT_CASCADIA_MONO) = 11, "retain point sizes from OGF1 headers")

Dim As Widget Ptr viewer = rtfview_Create("rtf_test", 10, 10, 330, 160)
gui_AddWidget(viewer)
rtfview_SetColors(viewer, RGB(255, 255, 255), RGB(0, 0, 0))
Dim As RtfViewData Ptr d = viewer->data
Dim As String fontHeader = "{\rtf1\ansi\deff0{\fonttbl{\f0\fnil Consolas;}{\f1\fswiss Arial;}}"

test_Section("document typography")
AssertTrue(rtfview_SetRtf(viewer, fontHeader & "\f0\fs22 iii WWW\par{\b overview}\par\f1\fs40 Large\par\f0\fs22 tail}") <> 0, "parse mixed fonts and sizes")
gui_UpdateAll
backend_Clear RGB(64, 64, 64)
gui_RenderAll
AssertTrue(d->font_count = 2 AndAlso d->fonts(0).monospaced <> 0, "recognize Consolas declared as fnil")
AssertTrue(d->runs(0).font_id = BACKEND_FONT_CASCADIA_MONO AndAlso d->runs(0).font_percent = 100, "substitute the bundled monospace face at the declared point size")
AssertTrue(d->runs(1).bold <> 0 AndAlso d->runs(1).font_id = BACKEND_FONT_CASCADIA_MONO, "bold does not switch a monospace run to a proportional face")
AssertTrue(d->visual_line_count = 4 AndAlso d->lines(2).height > d->lines(0).height, "only the large-text line receives a taller line box")
AssertTrue(d->lines(1).text_width = backend_GetTextWidthFontPercent("overview", BACKEND_FONT_CASCADIA_MONO, 100), "bold monospace retains its measured advance")
AssertTrue(d->lines(3).top = d->lines(2).top + d->lines(2).height, "line positions use cumulative measured heights")

test_Section("color and character scope")
AssertTrue(rtfview_SetRtf(viewer, fontHeader & _
    "{\colortbl;\red17\green88\blue132;\red0\green0\blue0;}\fs22\cf1 one{\i\cf2 two}\cf0 three}") <> 0, "parse actual RGB colors and nested italics")
AssertTrue(d->color_count = 3 AndAlso d->runs(0).color = RGB(17, 88, 132), "retain the document color table")
AssertTrue(d->runs(1).italic <> 0 AndAlso d->runs(1).color = RGB(0, 0, 0) AndAlso d->runs(1).automatic_color = 0, "explicit black remains distinct from automatic text color")
AssertTrue(d->runs(2).italic = 0 AndAlso d->runs(2).automatic_color <> 0, "a closing group restores its parent's character style")

test_Section("Unicode preservation")
Dim As String expectedText = Chr(&HC3, &HA9) & " " & Chr(&HC3, &HA9) & " " & _
    Chr(&HE4, &HB8, &HAD) & " " & Chr(&HF0, &H9F, &H98, &H80)
AssertTrue(rtfview_SetRtf(viewer, fontHeader & "\fs22\uc1\u233? \'e9 \u20013? \u-10179?\u-8704?}") <> 0, "parse escaped ANSI, BMP, and surrogate-pair text")
AssertTrue(Left(d->display_text, d->display_text_length) = expectedText, "RTF fallback bytes do not replace or duplicate UTF-8 scalars")
AssertTrue(rtfview_SetRtf(viewer, fontHeader & "\fs22\uc1\u-10179?{\b\u-8704?}}") <> 0 AndAlso _
    Left(d->display_text, d->display_text_length) = Chr(&HF0, &H9F, &H98, &H80), "surrogate pairing spans formatting groups")
AssertTrue(rtfview_SetRtf(viewer, fontHeader & "\fs22\u-10179?a}") <> 0 AndAlso _
    Left(d->display_text, d->display_text_length) = Chr(&HEF, &HBF, &HBD) & "a", "broken surrogate pairs produce one replacement scalar")
viewer->w = 40
AssertTrue(rtfview_SetPlainText(viewer, expectedText) <> 0, "plain text retains UTF-8")
gui_UpdateAll
For fragmentIndex As Integer = 0 To d->line_fragment_count - 1
    Dim As RtfViewLineFragment Ptr fragmentData = @d->fragments(fragmentIndex)
    Dim As Integer firstByte = d->display_text[fragmentData->start_byte]
    AssertTrue(firstByte < &H80 OrElse firstByte >= &HC2, "wrapping starts at a complete UTF-8 scalar")
    Dim As Integer bytePosition = fragmentData->start_byte
    While bytePosition < fragmentData->start_byte + fragmentData->byte_length
        backend_ReadUTF8Codepoint(d->display_text, bytePosition)
    Wend
    AssertTrue(bytePosition = fragmentData->start_byte + fragmentData->byte_length, "wrapping ends at a complete UTF-8 scalar")
Next fragmentIndex

test_Section("margins and scrolling")
viewer->w = 330 : viewer->h = 55
rtfview_SetMargins(viewer, 20, 3, 8, 4)
AssertTrue(rtfview_SetRtf(viewer, fontHeader & "\fs22 first\par\fs60 heading\par\fs22 final}") <> 0, "load a document with mixed line heights")
gui_UpdateAll
d->scroll_offset = d->document_height
rtfview_ClampScroll(viewer)
AssertTrue(d->scroll_offset = d->document_height - viewer->h + d->content_top + d->content_bottom, "the last scroll page ends at the document bottom")
AssertTrue(Cast(ScrollBarData Ptr, d->scrollbar->data)->page_size = viewer->h - 7, "the scrollbar accounts for view margins")
backend_Clear RGB(64, 64, 64)
gui_RenderAll
AssertTrue(Point(viewer->ax + 10, viewer->ay + 5) = RGB(255, 255, 255), "the left reading margin remains clear after scrolling")

test_Section("bounded parser recovery")
AssertTrue(rtfview_SetRtf(viewer, "{\rtf1\deff7{\fonttbl{\f7\fnil Consolas;}}\fs22 default}") <> 0 AndAlso _
    d->runs(0).font_id = BACKEND_FONT_CASCADIA_MONO, "the declared default font applies without an explicit body f control")
Dim As String binaryBytes = "{}" & Chr(92) & "x"
AssertTrue(rtfview_SetRtf(viewer, "{\rtf1{\pict\bin4 " & binaryBytes & "}visible}") <> 0 AndAlso _
    Left(d->display_text, d->display_text_length) = "visible", "binary destinations do not interpret embedded braces")
AssertTrue(rtfview_SetRtf(viewer, "{\rtf1\bin999999 x}") = 0, "reject a binary count beyond the input")
AssertTrue(rtfview_SetRtf(viewer, "{\rtf1{\fonttbl{\f0 " & String(129, "A") & ";}}x}") = 0, "reject an overlong font name")
Dim As String manyFonts = "{\rtf1{\fonttbl"
For fontIndex As Integer = 0 To RTFVIEW_MAX_FONTS
    manyFonts &= "{\f" & LTrim(Str(fontIndex)) & "\fswiss Arial;}"
Next fontIndex
manyFonts &= "}x}"
AssertTrue(rtfview_SetRtf(viewer, manyFonts) = 0, "reject excess font definitions")
AssertTrue(rtfview_SetRtf(viewer, fontHeader & "\fs999999 bounded}") <> 0 AndAlso d->runs(0).font_percent <= 900, "bound oversized type before rendering")
AssertTrue(rtfview_SetPlainText(viewer, "valid again") <> 0 AndAlso rtfview_GetError(viewer) = "", "a valid document can replace a rejected one")

gui_ResetForTest
backend_Exit
Screen 0
test_Summary

' end of rtfview_layout_smoke.bas
