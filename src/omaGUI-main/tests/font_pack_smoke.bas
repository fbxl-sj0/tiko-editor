/'
    Project: omaGUI Tests
    File: font_pack_smoke.bas
    Purpose: Verify editor font packs and UTF-8 text in the combined backend.
    Responsibilities: Check font slots, fallback, replacement, clearing and
        rejected loads without retaining stale ASCII metrics.
    This file intentionally does NOT contain widget or application behavior.
'/
#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Dim Shared As Integer fontPackSmokeChecks
Private Sub require_result(ByVal condition As Integer, ByVal message As String)
    fontPackSmokeChecks += 1
    If condition <> 0 Then Exit Sub
    Print "font_pack_smoke: "; message
    End 1
End Sub

backend_Init 320, 200, BACKEND_HEADLESS_DRAWABLE
require_result ScreenPtr <> 0, "drawable null screen missing"
require_result BACKEND_FONT_LIBERATION_SANS_18_BOLD = 3, "legacy bold slot changed"
require_result BACKEND_FONT_LIBERATION_SERIF_18_REGULAR = 4, "legacy serif slot changed"
require_result backend_GetTextHeightFont(BACKEND_FONT_LIBERATION_SANS_18_BOLD) > 10, "legacy bold face missing"

require_result backend_LoadFontPack( _
    BACKEND_FONT_DEFAULT, "assets/fonts/noto_sans_ui.ogf" _
) <> 0, "UI pack failed to load"
require_result backend_LoadFontPack( _
    BACKEND_FONT_CASCADIA_MONO, "assets/fonts/cascadia_mono.ogf" _
) <> 0, "monospace pack failed to load"
require_result backend_LoadFontPack( _
    BACKEND_FONT_UNICODE_FALLBACK, "assets/fonts/noto_sans_cjk_sc.ogf" _
) <> 0, "CJK fallback failed to load"

Dim As String cjk_character = Chr(&hE4, &hB8, &hAD)
Dim As Integer byte_index
require_result backend_ReadUTF8Codepoint(cjk_character, byte_index) = &h4E2D, "UTF-8 decode failed"
require_result byte_index = Len(cjk_character), "UTF-8 byte count failed"
require_result backend_GetTextWidthFont(cjk_character, BACKEND_FONT_DEFAULT) > 0, "CJK fallback was not measured"
require_result backend_GetFontPointSize(BACKEND_FONT_CASCADIA_MONO) = 11, "pack point size changed"

Dim As Integer uiWidths(32 To 126), monoWidths(32 To 126)
Dim As Integer differingWidths
For codepoint As Integer = 32 To 126
    uiWidths(codepoint) = backend_GetTextWidthFont(Chr(codepoint), BACKEND_FONT_DEFAULT)
    monoWidths(codepoint) = backend_GetTextWidthFont(Chr(codepoint), BACKEND_FONT_CASCADIA_MONO)
    If uiWidths(codepoint) <> monoWidths(codepoint) Then differingWidths += 1
Next codepoint
require_result differingWidths > 0, "replacement test requires different font metrics"
require_result backend_LoadFontPack(BACKEND_FONT_DEFAULT, "assets/fonts/cascadia_mono.ogf") <> 0, _
    "replacement pack failed to load"
For codepoint As Integer = 32 To 126
    require_result backend_GetTextWidthFont(Chr(codepoint), BACKEND_FONT_DEFAULT) = monoWidths(codepoint), _
        "replacement retained stale ASCII width for codepoint " & Str(codepoint)
Next codepoint
require_result backend_LoadFontPack(BACKEND_FONT_DEFAULT, "assets/fonts/__missing_font__.ogf") = 0, _
    "missing replacement unexpectedly loaded"
For codepoint As Integer = 32 To 126
    require_result backend_GetTextWidthFont(Chr(codepoint), BACKEND_FONT_DEFAULT) = monoWidths(codepoint), _
        "rejected replacement changed ASCII width for codepoint " & Str(codepoint)
Next codepoint
backend_ClearFontPacks()
require_result backend_IsFontAvailable(BACKEND_FONT_CASCADIA_MONO) = 0, "font pack was retained"
require_result backend_LoadFontPack(BACKEND_FONT_DEFAULT, "assets/fonts/noto_sans_ui.ogf") <> 0, _
    "UI pack failed to reload after clearing"
For codepoint As Integer = 32 To 126
    require_result backend_GetTextWidthFont(Chr(codepoint), BACKEND_FONT_DEFAULT) = uiWidths(codepoint), _
        "clear and reload changed ASCII width for codepoint " & Str(codepoint)
Next codepoint
backend_Exit
Print "font_pack_smoke: PASS;"; fontPackSmokeChecks; " checks"
End 0

/' end of font_pack_smoke.bas '/
