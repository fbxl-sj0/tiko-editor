/'
    Project: omaGUI
    File: textbox_observation_smoke.bas

    Purpose: Verify exact textbox matching against the reference serializer.
    Responsibilities: Check both pointer widths, malformed keys and NUL bytes.
    Targets: FreeBASIC fb dialect and the host graphics backend.
    Module API: Standalone smoke test; no reusable symbols.

    This file intentionally does NOT contain:
        - widget drawing or document persistence
        - application-owned callbacks
    The test owns its local Widget and TextBoxData for the complete run.
'/
#lang "fb"
#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"

' -------------------------------------------------------------------------
' Reference serialization before the allocation change
' -------------------------------------------------------------------------
Private Function reference_Header(ByVal w As Widget Ptr) As String
    If w = 0 OrElse w->data = 0 Then Return ""
    Dim As TextBoxData Ptr d = Cast(TextBoxData Ptr, w->data)
    Dim As String result
    #define OBSERVE_TEXT_FIELD(field) result &= MKLongInt(d->field)
    OBSERVE_TEXT_FIELD(active)
    OBSERVE_TEXT_FIELD(multiline)
    OBSERVE_TEXT_FIELD(wordwrap)
    OBSERVE_TEXT_FIELD(scroll_offset)
    OBSERVE_TEXT_FIELD(v_scroll)
    OBSERVE_TEXT_FIELD(line_number_gutter_width)
    OBSERVE_TEXT_FIELD(scrollbar_visible)
    OBSERVE_TEXT_FIELD(horizontal_scrollbar_visible)
    OBSERVE_TEXT_FIELD(background_color_override)
    OBSERVE_TEXT_FIELD(foreground_color_override)
    OBSERVE_TEXT_FIELD(background_color)
    OBSERVE_TEXT_FIELD(foreground_color)
    OBSERVE_TEXT_FIELD(syntax_mode)
    OBSERVE_TEXT_FIELD(syntax_color_overrides)
    OBSERVE_TEXT_FIELD(syntax_keyword_color)
    OBSERVE_TEXT_FIELD(syntax_comment_color)
    OBSERVE_TEXT_FIELD(syntax_string_color)
    OBSERVE_TEXT_FIELD(syntax_number_color)
    OBSERVE_TEXT_FIELD(syntax_preprocessor_color)
    OBSERVE_TEXT_FIELD(syntax_type_color)
    OBSERVE_TEXT_FIELD(syntax_command_color)
    OBSERVE_TEXT_FIELD(syntax_procedure_color)
    OBSERVE_TEXT_FIELD(syntax_macro_color)
    OBSERVE_TEXT_FIELD(syntax_variable_color)
    OBSERVE_TEXT_FIELD(syntax_constant_color)
    OBSERVE_TEXT_FIELD(syntax_member_color)
    OBSERVE_TEXT_FIELD(syntax_label_color)
    OBSERVE_TEXT_FIELD(syntax_object_color)
    OBSERVE_TEXT_FIELD(password_character) ' FB-LINTER: DISABLE-LINE FBL008 FBL-SEC-004 REASON: Render identity tracks changes to mask mode.
    OBSERVE_TEXT_FIELD(hide_selection_on_blur)
    OBSERVE_TEXT_FIELD(text_style)
    OBSERVE_TEXT_FIELD(cue_banner_color)
    OBSERVE_TEXT_FIELD(caret_color)
    OBSERVE_TEXT_FIELD(surface_border_color)
    OBSERVE_TEXT_FIELD(surface_background_color)
    OBSERVE_TEXT_FIELD(surface_text_color)
    OBSERVE_TEXT_FIELD(current_line_highlight)
    OBSERVE_TEXT_FIELD(current_line_background_color)
    OBSERVE_TEXT_FIELD(line_range_highlight)
    OBSERVE_TEXT_FIELD(line_range_highlight_first)
    OBSERVE_TEXT_FIELD(line_range_highlight_last)
    OBSERVE_TEXT_FIELD(line_numbers_visible)
    OBSERVE_TEXT_FIELD(line_number_text_style_flags)
    OBSERVE_TEXT_FIELD(line_number_text_color)
    OBSERVE_TEXT_FIELD(line_number_background_color)
    OBSERVE_TEXT_FIELD(indent_guides_enabled)
    OBSERVE_TEXT_FIELD(indent_width)
    OBSERVE_TEXT_FIELD(virtual_space_enabled)
    OBSERVE_TEXT_FIELD(indent_guides_color)
    OBSERVE_TEXT_FIELD(right_edge_column)
    OBSERVE_TEXT_FIELD(right_edge_color)
    OBSERVE_TEXT_FIELD(fold_gutter_width)
    OBSERVE_TEXT_FIELD(fold_margin_background_color)
    OBSERVE_TEXT_FIELD(fold_symbol_foreground_color)
    OBSERVE_TEXT_FIELD(fold_symbol_background_color)
    OBSERVE_TEXT_FIELD(font_id)
    OBSERVE_TEXT_FIELD(font_scale_percent)
    OBSERVE_TEXT_FIELD(zoom_percent)
    OBSERVE_TEXT_FIELD(extra_line_spacing)
    OBSERVE_TEXT_FIELD(caret_visible)
    #undef OBSERVE_TEXT_FIELD
    ' Keep the serialized callback fields at 8 bytes on both pointer widths.
    ' Retained comparisons use this layout as an exact process-local key.
    result &= MKLongInt(CLngInt(CUInt(d->text_display_handler)))
    result &= MKLongInt(CLngInt(CUInt(d->text_color_handler)))
    result &= MKLongInt(CLngInt(CUInt(d->text_style_handler)))
    result &= MKLongInt(CLngInt(CUInt(d->text_indicator_handler)))
    result &= MKLongInt(CLngInt(CUInt(d->gutter_marker_handler)))
    result &= MKLongInt(CLngInt(CUInt(d->gutter_marker_style_handler)))
    result &= MKLongInt(CLngInt(CUInt(d->fold_marker_handler)))
    result &= MKLongInt(CLngInt(CUInt(d->line_visibility_handler)))
    result &= MKLongInt(CLngInt(CUInt(d->render_state_handler)))
    result &= MKLongInt(d->border_style)
    result &= MKLongInt(Len(d->cue_banner_text)) & d->cue_banner_text
    Return result
End Function

Private Function reference_Movement(ByVal d As TextBoxData Ptr) As String
    Dim As String result
    ' The length locates the movement fields without parsing the source text.
    result &= MKLongInt(Len(d->text))
    ' The final six 8-byte fields describe caret and selection movement.
    ' An opted-in row damage handler compares the exact stable prefix first.
    result &= MKLongInt(d->cursor_pos)
    result &= MKLongInt(d->sel_start)
    result &= MKLongInt(d->sel_end)
    result &= MKLongInt(d->cursor_virtual_space)
    result &= MKLongInt(d->sel_start_virtual_space)
    result &= MKLongInt(d->sel_end_virtual_space)
    result &= Chr(IIf(d->active <> 0 AndAlso d->caret_visible <> 0 AndAlso _
        gui_CaretBlinkVisible(Timer) <> 0, 1, 0))
    Return result
End Function

Private Function reference_Observation(ByVal w As Widget Ptr) As String
    If w = 0 OrElse w->data = 0 Then Return ""
    Dim As TextBoxData Ptr d = w->data
    ' Keep exact source bytes in changed observations, including legacy writes
    ' which did not advance change_serial. The matcher borrows them on idle frames.
    Return reference_Header(w) & MKLongInt(Len(d->text)) & _
        d->text & reference_Movement(d)
End Function

Private Function reference_Matches(ByVal w As Widget Ptr, _
    ByRef previousKey As Const String, ByVal observationOffset As Integer) As Integer
    If w = 0 OrElse w->data = 0 Then Return 0
    If observationOffset < 0 OrElse observationOffset > Len(previousKey) Then Return 0
    Dim As TextBoxData Ptr d = w->data
    Dim As String header = reference_Header(w)
    ' Layout: header, source length (8), exact source bytes, movement (57).
    ' Subtract before adding offsets, so malformed retained keys cannot wrap.
    Const fixedBytes As Integer = 65
    Dim As Integer available = Len(previousKey) - observationOffset
    If available < fixedBytes OrElse Len(header) > available - fixedBytes Then Return 0
    If Len(d->text) <> available - fixedBytes - Len(header) Then Return 0
    Dim As Const UByte Ptr retainedBytes = StrPtr(previousKey) + observationOffset
    If oma_BytesEqual(retainedBytes, StrPtr(header), Len(header)) = 0 Then Return 0
    Dim As String sourceLength = MKLongInt(Len(d->text))
    retainedBytes += Len(header)
    If oma_BytesEqual(retainedBytes, StrPtr(sourceLength), 8) = 0 Then Return 0
    retainedBytes += 8
    ' Exact equality catches same-length legacy writes without a serial bump.
    ' Borrow the live document only for this GUI-thread call; never retain it.
    If oma_BytesEqual(retainedBytes, StrPtr(d->text), Len(d->text)) = 0 Then Return 0
    Dim As String movement = reference_Movement(d)
    Return oma_BytesEqual(retainedBytes + Len(d->text), StrPtr(movement), Len(movement))
End Function

Private Dim Shared As Integer allocationChecks
Private Sub requireMatch(ByVal condition As Integer, ByVal labelText As String)
    allocationChecks += 1
    If condition <> 0 Then Exit Sub
    Print "ALLOCATION_FAIL "; labelText
    End 1
End Sub
Private Sub compareKey(ByVal w As Widget Ptr, ByRef keyText As Const String, ByVal offset As Integer)
    Dim As Integer expected = reference_Matches(w, keyText, offset)
    requireMatch textbox_RenderObservationMatches(w, keyText, offset) = expected, "matcher disagrees"
End Sub
Private Sub compareHeader(ByVal w As Widget Ptr)
    Dim As String expected = reference_Header(w)
    requireMatch textbox_RenderObservationHeader(w) = expected, "header byte layout"
End Sub
Dim As Widget testWidget
Dim As TextBoxData testData
testWidget.data = @testData
testData.cue_banner_text = "A" & Chr(0) & Chr(255) & "B"
testData.text = "line" & Chr(0) & Chr(128) & Chr(13, 10) & "tail"
compareHeader @testWidget
compareHeader 0
Dim As String fieldKey_active = reference_Observation(@testWidget)
testData.active = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_active, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_active, 0) = 0, "changed active"
testData.active = 0
Dim As String fieldKey_multiline = reference_Observation(@testWidget)
testData.multiline = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_multiline, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_multiline, 0) = 0, "changed multiline"
testData.multiline = 0
Dim As String fieldKey_wordwrap = reference_Observation(@testWidget)
testData.wordwrap = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_wordwrap, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_wordwrap, 0) = 0, "changed wordwrap"
testData.wordwrap = 0
Dim As String fieldKey_scroll_offset = reference_Observation(@testWidget)
testData.scroll_offset = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_scroll_offset, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_scroll_offset, 0) = 0, "changed scroll_offset"
testData.scroll_offset = 0
Dim As String fieldKey_v_scroll = reference_Observation(@testWidget)
testData.v_scroll = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_v_scroll, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_v_scroll, 0) = 0, "changed v_scroll"
testData.v_scroll = 0
Dim As String fieldKey_line_number_gutter_width = reference_Observation(@testWidget)
testData.line_number_gutter_width = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_line_number_gutter_width, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_line_number_gutter_width, 0) = 0, "changed line_number_gutter_width"
testData.line_number_gutter_width = 0
Dim As String fieldKey_scrollbar_visible = reference_Observation(@testWidget)
testData.scrollbar_visible = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_scrollbar_visible, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_scrollbar_visible, 0) = 0, "changed scrollbar_visible"
testData.scrollbar_visible = 0
Dim As String fieldKey_horizontal_scrollbar_visible = reference_Observation(@testWidget)
testData.horizontal_scrollbar_visible = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_horizontal_scrollbar_visible, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_horizontal_scrollbar_visible, 0) = 0, "changed horizontal_scrollbar_visible"
testData.horizontal_scrollbar_visible = 0
Dim As String fieldKey_background_color_override = reference_Observation(@testWidget)
testData.background_color_override = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_background_color_override, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_background_color_override, 0) = 0, "changed background_color_override"
testData.background_color_override = 0
Dim As String fieldKey_foreground_color_override = reference_Observation(@testWidget)
testData.foreground_color_override = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_foreground_color_override, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_foreground_color_override, 0) = 0, "changed foreground_color_override"
testData.foreground_color_override = 0
Dim As String fieldKey_background_color = reference_Observation(@testWidget)
testData.background_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_background_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_background_color, 0) = 0, "changed background_color"
testData.background_color = 0
Dim As String fieldKey_foreground_color = reference_Observation(@testWidget)
testData.foreground_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_foreground_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_foreground_color, 0) = 0, "changed foreground_color"
testData.foreground_color = 0
Dim As String fieldKey_syntax_mode = reference_Observation(@testWidget)
testData.syntax_mode = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_mode, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_mode, 0) = 0, "changed syntax_mode"
testData.syntax_mode = 0
Dim As String fieldKey_syntax_color_overrides = reference_Observation(@testWidget)
testData.syntax_color_overrides = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_color_overrides, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_color_overrides, 0) = 0, "changed syntax_color_overrides"
testData.syntax_color_overrides = 0
Dim As String fieldKey_syntax_keyword_color = reference_Observation(@testWidget)
testData.syntax_keyword_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_keyword_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_keyword_color, 0) = 0, "changed syntax_keyword_color"
testData.syntax_keyword_color = 0
Dim As String fieldKey_syntax_comment_color = reference_Observation(@testWidget)
testData.syntax_comment_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_comment_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_comment_color, 0) = 0, "changed syntax_comment_color"
testData.syntax_comment_color = 0
Dim As String fieldKey_syntax_string_color = reference_Observation(@testWidget)
testData.syntax_string_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_string_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_string_color, 0) = 0, "changed syntax_string_color"
testData.syntax_string_color = 0
Dim As String fieldKey_syntax_number_color = reference_Observation(@testWidget)
testData.syntax_number_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_number_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_number_color, 0) = 0, "changed syntax_number_color"
testData.syntax_number_color = 0
Dim As String fieldKey_syntax_preprocessor_color = reference_Observation(@testWidget)
testData.syntax_preprocessor_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_preprocessor_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_preprocessor_color, 0) = 0, "changed syntax_preprocessor_color"
testData.syntax_preprocessor_color = 0
Dim As String fieldKey_syntax_type_color = reference_Observation(@testWidget)
testData.syntax_type_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_type_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_type_color, 0) = 0, "changed syntax_type_color"
testData.syntax_type_color = 0
Dim As String fieldKey_syntax_command_color = reference_Observation(@testWidget)
testData.syntax_command_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_command_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_command_color, 0) = 0, "changed syntax_command_color"
testData.syntax_command_color = 0
Dim As String fieldKey_syntax_procedure_color = reference_Observation(@testWidget)
testData.syntax_procedure_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_procedure_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_procedure_color, 0) = 0, "changed syntax_procedure_color"
testData.syntax_procedure_color = 0
Dim As String fieldKey_syntax_macro_color = reference_Observation(@testWidget)
testData.syntax_macro_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_macro_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_macro_color, 0) = 0, "changed syntax_macro_color"
testData.syntax_macro_color = 0
Dim As String fieldKey_syntax_variable_color = reference_Observation(@testWidget)
testData.syntax_variable_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_variable_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_variable_color, 0) = 0, "changed syntax_variable_color"
testData.syntax_variable_color = 0
Dim As String fieldKey_syntax_constant_color = reference_Observation(@testWidget)
testData.syntax_constant_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_constant_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_constant_color, 0) = 0, "changed syntax_constant_color"
testData.syntax_constant_color = 0
Dim As String fieldKey_syntax_member_color = reference_Observation(@testWidget)
testData.syntax_member_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_member_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_member_color, 0) = 0, "changed syntax_member_color"
testData.syntax_member_color = 0
Dim As String fieldKey_syntax_label_color = reference_Observation(@testWidget)
testData.syntax_label_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_label_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_label_color, 0) = 0, "changed syntax_label_color"
testData.syntax_label_color = 0
Dim As String fieldKey_syntax_object_color = reference_Observation(@testWidget)
testData.syntax_object_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_syntax_object_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_syntax_object_color, 0) = 0, "changed syntax_object_color"
testData.syntax_object_color = 0
Dim As String fieldKey_mask_character = reference_Observation(@testWidget)
testData.password_character = 123 ' fblint: disable-line FBL008,FBL-SEC-004 -- display-mask selector, not a credential.
compareHeader @testWidget
compareKey @testWidget, fieldKey_mask_character, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_mask_character, 0) = 0, "changed display mask selector"
testData.password_character = 0 ' fblint: disable-line FBL008,FBL-SEC-004 -- clear the display-mask selector.
Dim As String fieldKey_hide_selection_on_blur = reference_Observation(@testWidget)
testData.hide_selection_on_blur = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_hide_selection_on_blur, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_hide_selection_on_blur, 0) = 0, "changed hide_selection_on_blur"
testData.hide_selection_on_blur = 0
Dim As String fieldKey_text_style = reference_Observation(@testWidget)
testData.text_style = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_text_style, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_text_style, 0) = 0, "changed text_style"
testData.text_style = 0
Dim As String fieldKey_cue_banner_color = reference_Observation(@testWidget)
testData.cue_banner_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_cue_banner_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_cue_banner_color, 0) = 0, "changed cue_banner_color"
testData.cue_banner_color = 0
Dim As String fieldKey_caret_color = reference_Observation(@testWidget)
testData.caret_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_caret_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_caret_color, 0) = 0, "changed caret_color"
testData.caret_color = 0
Dim As String fieldKey_surface_border_color = reference_Observation(@testWidget)
testData.surface_border_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_surface_border_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_surface_border_color, 0) = 0, "changed surface_border_color"
testData.surface_border_color = 0
Dim As String fieldKey_surface_background_color = reference_Observation(@testWidget)
testData.surface_background_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_surface_background_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_surface_background_color, 0) = 0, "changed surface_background_color"
testData.surface_background_color = 0
Dim As String fieldKey_surface_text_color = reference_Observation(@testWidget)
testData.surface_text_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_surface_text_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_surface_text_color, 0) = 0, "changed surface_text_color"
testData.surface_text_color = 0
Dim As String fieldKey_current_line_highlight = reference_Observation(@testWidget)
testData.current_line_highlight = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_current_line_highlight, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_current_line_highlight, 0) = 0, "changed current_line_highlight"
testData.current_line_highlight = 0
Dim As String fieldKey_current_line_background_color = reference_Observation(@testWidget)
testData.current_line_background_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_current_line_background_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_current_line_background_color, 0) = 0, "changed current_line_background_color"
testData.current_line_background_color = 0
Dim As String fieldKey_line_range_highlight = reference_Observation(@testWidget)
testData.line_range_highlight = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_line_range_highlight, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_line_range_highlight, 0) = 0, "changed line_range_highlight"
testData.line_range_highlight = 0
Dim As String fieldKey_line_range_highlight_first = reference_Observation(@testWidget)
testData.line_range_highlight_first = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_line_range_highlight_first, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_line_range_highlight_first, 0) = 0, "changed line_range_highlight_first"
testData.line_range_highlight_first = 0
Dim As String fieldKey_line_range_highlight_last = reference_Observation(@testWidget)
testData.line_range_highlight_last = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_line_range_highlight_last, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_line_range_highlight_last, 0) = 0, "changed line_range_highlight_last"
testData.line_range_highlight_last = 0
Dim As String fieldKey_line_numbers_visible = reference_Observation(@testWidget)
testData.line_numbers_visible = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_line_numbers_visible, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_line_numbers_visible, 0) = 0, "changed line_numbers_visible"
testData.line_numbers_visible = 0
Dim As String fieldKey_line_number_text_style_flags = reference_Observation(@testWidget)
testData.line_number_text_style_flags = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_line_number_text_style_flags, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_line_number_text_style_flags, 0) = 0, "changed line_number_text_style_flags"
testData.line_number_text_style_flags = 0
Dim As String fieldKey_line_number_text_color = reference_Observation(@testWidget)
testData.line_number_text_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_line_number_text_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_line_number_text_color, 0) = 0, "changed line_number_text_color"
testData.line_number_text_color = 0
Dim As String fieldKey_line_number_background_color = reference_Observation(@testWidget)
testData.line_number_background_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_line_number_background_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_line_number_background_color, 0) = 0, "changed line_number_background_color"
testData.line_number_background_color = 0
Dim As String fieldKey_indent_guides_enabled = reference_Observation(@testWidget)
testData.indent_guides_enabled = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_indent_guides_enabled, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_indent_guides_enabled, 0) = 0, "changed indent_guides_enabled"
testData.indent_guides_enabled = 0
Dim As String fieldKey_indent_width = reference_Observation(@testWidget)
testData.indent_width = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_indent_width, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_indent_width, 0) = 0, "changed indent_width"
testData.indent_width = 0
Dim As String fieldKey_virtual_space_enabled = reference_Observation(@testWidget)
testData.virtual_space_enabled = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_virtual_space_enabled, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_virtual_space_enabled, 0) = 0, "changed virtual_space_enabled"
testData.virtual_space_enabled = 0
Dim As String fieldKey_indent_guides_color = reference_Observation(@testWidget)
testData.indent_guides_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_indent_guides_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_indent_guides_color, 0) = 0, "changed indent_guides_color"
testData.indent_guides_color = 0
Dim As String fieldKey_right_edge_column = reference_Observation(@testWidget)
testData.right_edge_column = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_right_edge_column, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_right_edge_column, 0) = 0, "changed right_edge_column"
testData.right_edge_column = 0
Dim As String fieldKey_right_edge_color = reference_Observation(@testWidget)
testData.right_edge_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_right_edge_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_right_edge_color, 0) = 0, "changed right_edge_color"
testData.right_edge_color = 0
Dim As String fieldKey_fold_gutter_width = reference_Observation(@testWidget)
testData.fold_gutter_width = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_fold_gutter_width, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_fold_gutter_width, 0) = 0, "changed fold_gutter_width"
testData.fold_gutter_width = 0
Dim As String fieldKey_fold_margin_background_color = reference_Observation(@testWidget)
testData.fold_margin_background_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_fold_margin_background_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_fold_margin_background_color, 0) = 0, "changed fold_margin_background_color"
testData.fold_margin_background_color = 0
Dim As String fieldKey_fold_symbol_foreground_color = reference_Observation(@testWidget)
testData.fold_symbol_foreground_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_fold_symbol_foreground_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_fold_symbol_foreground_color, 0) = 0, "changed fold_symbol_foreground_color"
testData.fold_symbol_foreground_color = 0
Dim As String fieldKey_fold_symbol_background_color = reference_Observation(@testWidget)
testData.fold_symbol_background_color = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_fold_symbol_background_color, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_fold_symbol_background_color, 0) = 0, "changed fold_symbol_background_color"
testData.fold_symbol_background_color = 0
Dim As String fieldKey_font_id = reference_Observation(@testWidget)
testData.font_id = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_font_id, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_font_id, 0) = 0, "changed font_id"
testData.font_id = 0
Dim As String fieldKey_font_scale_percent = reference_Observation(@testWidget)
testData.font_scale_percent = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_font_scale_percent, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_font_scale_percent, 0) = 0, "changed font_scale_percent"
testData.font_scale_percent = 0
Dim As String fieldKey_zoom_percent = reference_Observation(@testWidget)
testData.zoom_percent = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_zoom_percent, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_zoom_percent, 0) = 0, "changed zoom_percent"
testData.zoom_percent = 0
Dim As String fieldKey_extra_line_spacing = reference_Observation(@testWidget)
testData.extra_line_spacing = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_extra_line_spacing, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_extra_line_spacing, 0) = 0, "changed extra_line_spacing"
testData.extra_line_spacing = 0
Dim As String fieldKey_caret_visible = reference_Observation(@testWidget)
testData.caret_visible = 123
compareHeader @testWidget
compareKey @testWidget, fieldKey_caret_visible, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_caret_visible, 0) = 0, "changed caret_visible"
testData.caret_visible = 0
Dim As String fieldKey_text_display_handler = reference_Observation(@testWidget)
' The address is serialized only; no test callback address is ever invoked.
testData.text_display_handler = Cast(TypeOf(testData.text_display_handler), 123)
compareHeader @testWidget
compareKey @testWidget, fieldKey_text_display_handler, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_text_display_handler, 0) = 0, "changed text_display_handler"
testData.text_display_handler = 0
Dim As String fieldKey_text_color_handler = reference_Observation(@testWidget)
' The address is serialized only; no test callback address is ever invoked.
testData.text_color_handler = Cast(TypeOf(testData.text_color_handler), 123)
compareHeader @testWidget
compareKey @testWidget, fieldKey_text_color_handler, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_text_color_handler, 0) = 0, "changed text_color_handler"
testData.text_color_handler = 0
Dim As String fieldKey_text_style_handler = reference_Observation(@testWidget)
' The address is serialized only; no test callback address is ever invoked.
testData.text_style_handler = Cast(TypeOf(testData.text_style_handler), 123)
compareHeader @testWidget
compareKey @testWidget, fieldKey_text_style_handler, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_text_style_handler, 0) = 0, "changed text_style_handler"
testData.text_style_handler = 0
Dim As String fieldKey_text_indicator_handler = reference_Observation(@testWidget)
' The address is serialized only; no test callback address is ever invoked.
testData.text_indicator_handler = Cast(TypeOf(testData.text_indicator_handler), 123)
compareHeader @testWidget
compareKey @testWidget, fieldKey_text_indicator_handler, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_text_indicator_handler, 0) = 0, "changed text_indicator_handler"
testData.text_indicator_handler = 0
Dim As String fieldKey_gutter_marker_handler = reference_Observation(@testWidget)
' The address is serialized only; no test callback address is ever invoked.
testData.gutter_marker_handler = Cast(TypeOf(testData.gutter_marker_handler), 123)
compareHeader @testWidget
compareKey @testWidget, fieldKey_gutter_marker_handler, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_gutter_marker_handler, 0) = 0, "changed gutter_marker_handler"
testData.gutter_marker_handler = 0
Dim As String fieldKey_gutter_marker_style_handler = reference_Observation(@testWidget)
' The address is serialized only; no test callback address is ever invoked.
testData.gutter_marker_style_handler = Cast(TypeOf(testData.gutter_marker_style_handler), 123)
compareHeader @testWidget
compareKey @testWidget, fieldKey_gutter_marker_style_handler, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_gutter_marker_style_handler, 0) = 0, "changed gutter_marker_style_handler"
testData.gutter_marker_style_handler = 0
Dim As String fieldKey_fold_marker_handler = reference_Observation(@testWidget)
' The address is serialized only; no test callback address is ever invoked.
testData.fold_marker_handler = Cast(TypeOf(testData.fold_marker_handler), 123)
compareHeader @testWidget
compareKey @testWidget, fieldKey_fold_marker_handler, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_fold_marker_handler, 0) = 0, "changed fold_marker_handler"
testData.fold_marker_handler = 0
Dim As String fieldKey_line_visibility_handler = reference_Observation(@testWidget)
' The address is serialized only; no test callback address is ever invoked.
testData.line_visibility_handler = Cast(TypeOf(testData.line_visibility_handler), 123)
compareHeader @testWidget
compareKey @testWidget, fieldKey_line_visibility_handler, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_line_visibility_handler, 0) = 0, "changed line_visibility_handler"
testData.line_visibility_handler = 0
Dim As String fieldKey_render_state_handler = reference_Observation(@testWidget)
' The address is serialized only; no test callback address is ever invoked.
testData.render_state_handler = Cast(TypeOf(testData.render_state_handler), 123)
compareHeader @testWidget
compareKey @testWidget, fieldKey_render_state_handler, 0
requireMatch textbox_RenderObservationMatches(@testWidget, fieldKey_render_state_handler, 0) = 0, "changed render_state_handler"
testData.render_state_handler = 0
' Signed fields and full-range color values retain the old widening rules.
testData.v_scroll = -123
testData.background_color = &hFFFFFFFFu
testData.foreground_color = &h80000000u
compareHeader @testWidget
Dim As String keyText = reference_Observation(@testWidget)
compareKey @testWidget, keyText, 0
requireMatch textbox_RenderObservationMatches(@testWidget, keyText, 0), "unchanged observation"
For byteIndex As Integer = 0 To Len(keyText) - 1
    Dim As String corruptKey = keyText
    corruptKey[byteIndex] = corruptKey[byteIndex] Xor 1
    compareKey @testWidget, corruptKey, 0
    requireMatch textbox_RenderObservationMatches(@testWidget, corruptKey, 0) = 0, "corrupt byte"
Next byteIndex
For lengthValue As Integer = 0 To Len(keyText) - 1
    Dim As String shortKey = Left(keyText, lengthValue)
    compareKey @testWidget, shortKey, 0
Next lengthValue
compareKey @testWidget, keyText, -1
compareKey @testWidget, keyText, Len(keyText) + 1
compareKey @testWidget, keyText, 2147483647
compareKey 0, keyText, 0
Dim As Widget emptyWidget
compareKey @emptyWidget, keyText, 0
For prefixLength As Integer = 0 To 7
    Dim As String prefixed = String(prefixLength, "x") & keyText
    compareKey @testWidget, prefixed, prefixLength
    requireMatch textbox_RenderObservationMatches(@testWidget, prefixed, prefixLength), "unaligned observation"
Next prefixLength
testData.text[0] = testData.text[0] Xor 1
compareKey @testWidget, keyText, 0
requireMatch textbox_RenderObservationMatches(@testWidget, keyText, 0) = 0, "same-length legacy source write"
testData.text[0] = testData.text[0] Xor 1
testData.cue_banner_text[0] = testData.cue_banner_text[0] Xor 1
compareKey @testWidget, keyText, 0
requireMatch textbox_RenderObservationMatches(@testWidget, keyText, 0) = 0, "same-length cue write"
testData.cue_banner_text = ""
testData.text = ""
compareHeader @testWidget
keyText = reference_Observation(@testWidget)
compareKey @testWidget, keyText, 0
requireMatch textbox_RenderObservationMatches(@testWidget, keyText, 0), "empty strings"
Print "textbox_observation_smoke: PASS "; allocationChecks
End 0
' end of textbox_observation_smoke.bas
