/'
    Project: omaGUI Tests
    File: font_pack_smoke.bas
    Purpose: Verify editor font packs and UTF-8 text in the combined backend.
    Responsibilities: Check new font slots, loading, fallback, and legacy slots.
    This file intentionally does NOT contain: widget or application behavior.
'/
#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub require_result(ByVal condition As Integer, ByVal message As String)
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

backend_ClearFontPacks()
require_result backend_IsFontAvailable(BACKEND_FONT_CASCADIA_MONO) = 0, "font pack was retained"
backend_Exit
Print "font_pack_smoke: PASS"
End 0

/' end of font_pack_smoke.bas '/
