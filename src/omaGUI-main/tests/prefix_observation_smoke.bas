/'
    Project: omaGUI tests. File: prefix_observation_smoke.bas.
    Purpose: Compare retained themePalette/prefix matching with legacy serialization.
    Responsibilities: Check exact bytes, all fields and malformed lengths.
    This file does not draw, invoke dummy callbacks or write user data.
    Local widgets and palettes outlive every borrowed-byte comparison.
'/
#lang "fb"
#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"
Private Dim Shared As Integer checks
Private Sub require(ByVal condition As Integer, ByVal lineValue As Integer)
    checks += 1
    If condition = 0 Then
        Print "PREFIX_MATCH_FAIL "; lineValue
        End 1
    End If
End Sub
' -------------------------------------------------------------------------
' Independent legacy serialization and malformed-key checks
' -------------------------------------------------------------------------
Private Function referencePalette(ByRef themePalette As Const GUI_Theme) As String
    Dim As String result
    result &= MKLongInt(themePalette.bg_face)
    result &= MKLongInt(themePalette.bg_widget)
    result &= MKLongInt(themePalette.bg_dark)
    result &= MKLongInt(themePalette.bg_light)
    result &= MKLongInt(themePalette.text_main)
    result &= MKLongInt(themePalette.text_select)
    result &= MKLongInt(themePalette.bg_select)
    result &= MKLongInt(themePalette.win_border)
    result &= MKLongInt(themePalette.menu_background)
    result &= MKLongInt(themePalette.menu_text)
    result &= MKLongInt(themePalette.menu_selected_background)
    result &= MKLongInt(themePalette.menu_selected_text)
    result &= MKLongInt(themePalette.menu_separator)
    result &= MKLongInt(themePalette.menu_disabled_text)
    result &= MKLongInt(themePalette.control_style)
    result &= MKLongInt(themePalette.title_background)
    result &= MKLongInt(themePalette.title_text)
    result &= MKLongInt(themePalette.classic_access_text)
    result &= MKLongInt(themePalette.classic_active_border_background)
    result &= MKLongInt(themePalette.classic_active_border_text)
    result &= MKLongInt(themePalette.classic_command_text)
    result &= MKLongInt(themePalette.classic_disabled_text)
    result &= MKLongInt(themePalette.classic_menu_background)
    result &= MKLongInt(themePalette.classic_menu_text)
    result &= MKLongInt(themePalette.classic_menu_selected_background)
    result &= MKLongInt(themePalette.classic_menu_selected_text)
    result &= MKLongInt(themePalette.classic_scrollbar_background)
    result &= MKLongInt(themePalette.classic_scrollbar_text)
    result &= MKLongInt(themePalette.syntax_keyword_color)
    result &= MKLongInt(themePalette.syntax_comment_color)
    result &= MKLongInt(themePalette.syntax_string_color)
    result &= MKLongInt(themePalette.syntax_number_color)
    result &= MKLongInt(themePalette.syntax_preprocessor_color)
    result &= MKLongInt(themePalette.syntax_type_color)
    result &= MKLongInt(themePalette.syntax_command_color)
    result &= MKLongInt(themePalette.syntax_procedure_color)
    result &= MKLongInt(themePalette.syntax_macro_color)
    result &= MKLongInt(themePalette.syntax_variable_color)
    result &= MKLongInt(themePalette.syntax_constant_color)
    result &= MKLongInt(themePalette.syntax_member_color)
    result &= MKLongInt(themePalette.syntax_label_color)
    result &= MKLongInt(themePalette.syntax_object_color)
    result &= MKLongInt(themePalette.mode)
    result &= MKLongInt(themePalette.panel_face)
    result &= MKLongInt(themePalette.accent_secondary)
    result &= MKLongInt(themePalette.visual_style)
    Return result
End Function
Private Function referencePrefix(ByVal w As Widget Ptr, ByVal themePalette As Const GUI_Theme Ptr) As String
    Dim As String result = MKLongInt(-19) & MKLongInt(31) & MKLongInt(480) & MKLongInt(320)
    If themePalette <> 0 Then result &= referencePalette(*themePalette)
    Return result & MKLongInt(w->een) & MKLongInt(w->has_focus) & _
        MKLongInt(gui_KeyboardFocusVisible) & MKLongInt(CLngInt(CUInt(w->render)))
End Function
Private Sub checkPalette(ByRef themePalette As Const GUI_Theme)
    require gui_RetainedPaletteKey(themePalette) = referencePalette(themePalette), __LINE__
End Sub
Private Sub checkPrefix(ByVal w As Widget Ptr, ByVal themePalette As Const GUI_Theme Ptr)
    Dim As String expected = referencePrefix(w, themePalette)
    Dim As Integer offset = Len(expected)
    require gui_RetainedPrefixKey(w, themePalette, -19, 31, 480, 320) = expected, __LINE__
    w->retained_key = expected & "payload" & Chr(0)
    require gui_RetainedPrefixMatches(w, themePalette, -19, 31, 480, 320, offset), __LINE__
    require gui_RetainedPrefixMatches(w, themePalette, -18, 31, 480, 320, offset) = 0, __LINE__
    require gui_RetainedPrefixMatches(w, themePalette, -19, 32, 480, 320, offset) = 0, __LINE__
    require gui_RetainedPrefixMatches(w, themePalette, -19, 31, 481, 320, offset) = 0, __LINE__
    require gui_RetainedPrefixMatches(w, themePalette, -19, 31, 480, 321, offset) = 0, __LINE__
    For invalidOffset As Integer = -1 To offset + 1
        If invalidOffset = offset Then Continue For
        require gui_RetainedPrefixMatches(w, themePalette, -19, 31, 480, 320, invalidOffset) = 0, __LINE__
    Next
    For cut As Integer = 0 To offset - 1
        w->retained_key = Left(expected, cut)
        require gui_RetainedPrefixMatches(w, themePalette, -19, 31, 480, 320, offset) = 0, __LINE__
    Next
    For index As Integer = 0 To offset - 1
        w->retained_key = expected
        w->retained_key[index] Xor= 1
        require gui_RetainedPrefixMatches(w, themePalette, -19, 31, 480, 320, offset) = 0, __LINE__
    Next
End Sub
Private Sub checkTheme()
    Dim As String expected = MKLongInt(backend_GetFontGeneration()) & referencePalette(current_theme) & _
        MKLongInt(theme_GetClassicShadow()) & MKLongInt(theme_GetClassicThreeD())
    require gui_RetainedThemeMatches(expected), __LINE__
    For cut As Integer = 0 To Len(expected) - 1
        Dim As String broken = Left(expected, cut)
        require gui_RetainedThemeMatches(broken) = 0, __LINE__
    Next
    For index As Integer = 0 To Len(expected) - 1
        Dim As String broken = expected
        broken[index] Xor= 1
        require gui_RetainedThemeMatches(broken) = 0, __LINE__
    Next
    Dim As String extra = expected & "x"
    require gui_RetainedThemeMatches(extra) = 0, __LINE__
End Sub
' -------------------------------------------------------------------------
' Field mutations and visual identity checks
' -------------------------------------------------------------------------
Dim As GUI_Theme themePalette
Dim As Widget w
w.een = -1
w.has_focus = 1
gui_KeyboardFocusVisible = -1
checkPalette themePalette
checkPrefix @w, 0
checkPrefix @w, @themePalette
checkTheme
themePalette.bg_face = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_bg_face = referencePrefix(@w, @current_theme)
w.retained_key = previous_bg_face
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_bg_face)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.bg_face = 0
current_theme = themePalette
themePalette.bg_widget = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_bg_widget = referencePrefix(@w, @current_theme)
w.retained_key = previous_bg_widget
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_bg_widget)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.bg_widget = 0
current_theme = themePalette
themePalette.bg_dark = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_bg_dark = referencePrefix(@w, @current_theme)
w.retained_key = previous_bg_dark
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_bg_dark)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.bg_dark = 0
current_theme = themePalette
themePalette.bg_light = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_bg_light = referencePrefix(@w, @current_theme)
w.retained_key = previous_bg_light
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_bg_light)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.bg_light = 0
current_theme = themePalette
themePalette.text_main = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_text_main = referencePrefix(@w, @current_theme)
w.retained_key = previous_text_main
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_text_main)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.text_main = 0
current_theme = themePalette
themePalette.text_select = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_text_select = referencePrefix(@w, @current_theme)
w.retained_key = previous_text_select
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_text_select)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.text_select = 0
current_theme = themePalette
themePalette.bg_select = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_bg_select = referencePrefix(@w, @current_theme)
w.retained_key = previous_bg_select
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_bg_select)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.bg_select = 0
current_theme = themePalette
themePalette.win_border = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_win_border = referencePrefix(@w, @current_theme)
w.retained_key = previous_win_border
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_win_border)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.win_border = 0
current_theme = themePalette
themePalette.menu_background = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_menu_background = referencePrefix(@w, @current_theme)
w.retained_key = previous_menu_background
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_menu_background)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.menu_background = 0
current_theme = themePalette
themePalette.menu_text = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_menu_text = referencePrefix(@w, @current_theme)
w.retained_key = previous_menu_text
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_menu_text)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.menu_text = 0
current_theme = themePalette
themePalette.menu_selected_background = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_menu_selected_background = referencePrefix(@w, @current_theme)
w.retained_key = previous_menu_selected_background
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_menu_selected_background)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.menu_selected_background = 0
current_theme = themePalette
themePalette.menu_selected_text = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_menu_selected_text = referencePrefix(@w, @current_theme)
w.retained_key = previous_menu_selected_text
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_menu_selected_text)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.menu_selected_text = 0
current_theme = themePalette
themePalette.menu_separator = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_menu_separator = referencePrefix(@w, @current_theme)
w.retained_key = previous_menu_separator
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_menu_separator)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.menu_separator = 0
current_theme = themePalette
themePalette.menu_disabled_text = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_menu_disabled_text = referencePrefix(@w, @current_theme)
w.retained_key = previous_menu_disabled_text
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_menu_disabled_text)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.menu_disabled_text = 0
current_theme = themePalette
themePalette.control_style = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_control_style = referencePrefix(@w, @current_theme)
w.retained_key = previous_control_style
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_control_style)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.control_style = 0
current_theme = themePalette
themePalette.title_background = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_title_background = referencePrefix(@w, @current_theme)
w.retained_key = previous_title_background
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_title_background)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.title_background = 0
current_theme = themePalette
themePalette.title_text = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_title_text = referencePrefix(@w, @current_theme)
w.retained_key = previous_title_text
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_title_text)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.title_text = 0
current_theme = themePalette
themePalette.classic_access_text = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_classic_access_text = referencePrefix(@w, @current_theme)
w.retained_key = previous_classic_access_text
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_classic_access_text)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.classic_access_text = 0
current_theme = themePalette
themePalette.classic_active_border_background = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_classic_active_border_background = referencePrefix(@w, @current_theme)
w.retained_key = previous_classic_active_border_background
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_classic_active_border_background)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.classic_active_border_background = 0
current_theme = themePalette
themePalette.classic_active_border_text = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_classic_active_border_text = referencePrefix(@w, @current_theme)
w.retained_key = previous_classic_active_border_text
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_classic_active_border_text)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.classic_active_border_text = 0
current_theme = themePalette
themePalette.classic_command_text = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_classic_command_text = referencePrefix(@w, @current_theme)
w.retained_key = previous_classic_command_text
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_classic_command_text)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.classic_command_text = 0
current_theme = themePalette
themePalette.classic_disabled_text = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_classic_disabled_text = referencePrefix(@w, @current_theme)
w.retained_key = previous_classic_disabled_text
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_classic_disabled_text)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.classic_disabled_text = 0
current_theme = themePalette
themePalette.classic_menu_background = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_classic_menu_background = referencePrefix(@w, @current_theme)
w.retained_key = previous_classic_menu_background
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_classic_menu_background)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.classic_menu_background = 0
current_theme = themePalette
themePalette.classic_menu_text = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_classic_menu_text = referencePrefix(@w, @current_theme)
w.retained_key = previous_classic_menu_text
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_classic_menu_text)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.classic_menu_text = 0
current_theme = themePalette
themePalette.classic_menu_selected_background = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_classic_menu_selected_background = referencePrefix(@w, @current_theme)
w.retained_key = previous_classic_menu_selected_background
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_classic_menu_selected_background)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.classic_menu_selected_background = 0
current_theme = themePalette
themePalette.classic_menu_selected_text = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_classic_menu_selected_text = referencePrefix(@w, @current_theme)
w.retained_key = previous_classic_menu_selected_text
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_classic_menu_selected_text)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.classic_menu_selected_text = 0
current_theme = themePalette
themePalette.classic_scrollbar_background = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_classic_scrollbar_background = referencePrefix(@w, @current_theme)
w.retained_key = previous_classic_scrollbar_background
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_classic_scrollbar_background)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.classic_scrollbar_background = 0
current_theme = themePalette
themePalette.classic_scrollbar_text = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_classic_scrollbar_text = referencePrefix(@w, @current_theme)
w.retained_key = previous_classic_scrollbar_text
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_classic_scrollbar_text)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.classic_scrollbar_text = 0
current_theme = themePalette
themePalette.syntax_keyword_color = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_syntax_keyword_color = referencePrefix(@w, @current_theme)
w.retained_key = previous_syntax_keyword_color
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_syntax_keyword_color)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.syntax_keyword_color = 0
current_theme = themePalette
themePalette.syntax_comment_color = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_syntax_comment_color = referencePrefix(@w, @current_theme)
w.retained_key = previous_syntax_comment_color
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_syntax_comment_color)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.syntax_comment_color = 0
current_theme = themePalette
themePalette.syntax_string_color = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_syntax_string_color = referencePrefix(@w, @current_theme)
w.retained_key = previous_syntax_string_color
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_syntax_string_color)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.syntax_string_color = 0
current_theme = themePalette
themePalette.syntax_number_color = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_syntax_number_color = referencePrefix(@w, @current_theme)
w.retained_key = previous_syntax_number_color
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_syntax_number_color)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.syntax_number_color = 0
current_theme = themePalette
themePalette.syntax_preprocessor_color = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_syntax_preprocessor_color = referencePrefix(@w, @current_theme)
w.retained_key = previous_syntax_preprocessor_color
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_syntax_preprocessor_color)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.syntax_preprocessor_color = 0
current_theme = themePalette
themePalette.syntax_type_color = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_syntax_type_color = referencePrefix(@w, @current_theme)
w.retained_key = previous_syntax_type_color
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_syntax_type_color)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.syntax_type_color = 0
current_theme = themePalette
themePalette.syntax_command_color = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_syntax_command_color = referencePrefix(@w, @current_theme)
w.retained_key = previous_syntax_command_color
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_syntax_command_color)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.syntax_command_color = 0
current_theme = themePalette
themePalette.syntax_procedure_color = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_syntax_procedure_color = referencePrefix(@w, @current_theme)
w.retained_key = previous_syntax_procedure_color
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_syntax_procedure_color)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.syntax_procedure_color = 0
current_theme = themePalette
themePalette.syntax_macro_color = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_syntax_macro_color = referencePrefix(@w, @current_theme)
w.retained_key = previous_syntax_macro_color
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_syntax_macro_color)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.syntax_macro_color = 0
current_theme = themePalette
themePalette.syntax_variable_color = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_syntax_variable_color = referencePrefix(@w, @current_theme)
w.retained_key = previous_syntax_variable_color
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_syntax_variable_color)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.syntax_variable_color = 0
current_theme = themePalette
themePalette.syntax_constant_color = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_syntax_constant_color = referencePrefix(@w, @current_theme)
w.retained_key = previous_syntax_constant_color
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_syntax_constant_color)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.syntax_constant_color = 0
current_theme = themePalette
themePalette.syntax_member_color = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_syntax_member_color = referencePrefix(@w, @current_theme)
w.retained_key = previous_syntax_member_color
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_syntax_member_color)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.syntax_member_color = 0
current_theme = themePalette
themePalette.syntax_label_color = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_syntax_label_color = referencePrefix(@w, @current_theme)
w.retained_key = previous_syntax_label_color
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_syntax_label_color)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.syntax_label_color = 0
current_theme = themePalette
themePalette.syntax_object_color = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_syntax_object_color = referencePrefix(@w, @current_theme)
w.retained_key = previous_syntax_object_color
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_syntax_object_color)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.syntax_object_color = 0
current_theme = themePalette
themePalette.mode = -2147483647
checkPalette themePalette
Dim As String previous_mode = referencePrefix(@w, @current_theme)
w.retained_key = previous_mode
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_mode)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.mode = 0
current_theme = themePalette
themePalette.panel_face = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_panel_face = referencePrefix(@w, @current_theme)
w.retained_key = previous_panel_face
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_panel_face)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.panel_face = 0
current_theme = themePalette
themePalette.accent_secondary = &hFFFFFFFFu
checkPalette themePalette
Dim As String previous_accent_secondary = referencePrefix(@w, @current_theme)
w.retained_key = previous_accent_secondary
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_accent_secondary)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.accent_secondary = 0
current_theme = themePalette
themePalette.visual_style = -2147483647
checkPalette themePalette
Dim As String previous_visual_style = referencePrefix(@w, @current_theme)
w.retained_key = previous_visual_style
require gui_RetainedPrefixMatches(@w, @themePalette, -19, 31, 480, 320, Len(previous_visual_style)) = 0, __LINE__
current_theme = themePalette
checkTheme
themePalette.visual_style = 0
current_theme = themePalette
w.retained_key = referencePrefix(@w, 0)
w.een = 0
require gui_RetainedPrefixMatches(@w, 0, -19, 31, 480, 320, 64) = 0, __LINE__
w.een = -1
w.has_focus = 0
require gui_RetainedPrefixMatches(@w, 0, -19, 31, 480, 320, 64) = 0, __LINE__
w.has_focus = 1
gui_KeyboardFocusVisible = 0
require gui_RetainedPrefixMatches(@w, 0, -19, 31, 480, 320, 64) = 0, __LINE__
gui_KeyboardFocusVisible = -1
' A dummy address tests identity only. No code calls it.
w.render = Cast(Sub(ByVal As Widget Ptr), 123)
require gui_RetainedPrefixMatches(@w, 0, -19, 31, 480, 320, 64) = 0, __LINE__
checkPrefix @w, @themePalette
require gui_RetainedPrefixMatches(0, 0, 0, 0, 0, 0, 0) = 0, __LINE__
require gui_RetainedPrefixKey(0, 0, 0, 0, 0, 0) = "", __LINE__
Dim As String previousTheme = MKLongInt(backend_GetFontGeneration()) & referencePalette(current_theme) & _
    MKLongInt(theme_GetClassicShadow()) & MKLongInt(theme_GetClassicThreeD())
theme_SetClassicEffects Not theme_GetClassicShadow(), theme_GetClassicThreeD()
require gui_RetainedThemeMatches(previousTheme) = 0, __LINE__
checkTheme
previousTheme = MKLongInt(backend_GetFontGeneration()) & referencePalette(current_theme) & _
    MKLongInt(theme_GetClassicShadow()) & MKLongInt(theme_GetClassicThreeD())
theme_SetClassicEffects theme_GetClassicShadow(), Not theme_GetClassicThreeD()
require gui_RetainedThemeMatches(previousTheme) = 0, __LINE__
checkTheme
Print "prefix_observation_smoke: PASS "; checks
End 0
' end of prefix_observation_smoke.bas
