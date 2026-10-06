/'
    Project: omaGUI Font Tools
    --------------------------

    File: font_gen.bas

    Purpose:

        Generate omaGUI bitmap font data from a mapped font file.

    Responsibilities:

        - load TrueType, OpenType, or BDF font data through SDL_ttf
        - rasterize printable ASCII glyphs into 8-bit alpha data
        - optionally rasterize a sorted list of Unicode code points
        - write complete mapped Unicode fonts in the OGF1 binary format
        - write a FreeBASIC include file containing the glyph bitmaps
        - optionally write a BMP atlas for visual inspection

    Ownership:

        SDL fonts, surfaces, and open file handles belong to this utility and
        are released on its success and error paths. Generated output files
        remain on disk for the caller.

    Targets:

        FreeBASIC host with SDL2 and SDL_ttf development headers and libraries.

    Module API:

        Standalone font-data generator; this file exposes no library API.

    This file intentionally does NOT contain:

        - runtime text drawing logic
        - font selection policy for the renderer
        - Wonderware/System Platform graphics parsing
'/

#lang "fb"

#include "SDL2/SDL.bi"
#include "SDL2/SDL_ttf.bi"
#include once "crt/stdio.bi"
#ifdef __FB_WIN32__
#include once "windows.bi"
#elseif defined(__FB_UNIX__)
#include once "crt/stdlib.bi"
Extern "C"
    Declare Function fontgen_CloseFileDescriptor Alias "close" ( _
        ByVal file_descriptor As Long _
    ) As Long
End Extern
#endif

Const FIRST_GLYPH As Integer = 32
Const LAST_GLYPH As Integer = 126
Const DEFAULT_POINT_SIZE As Integer = 12
Const ATLAS_COLUMNS As Integer = 16
Const FONTGEN_MAX_EXTRA_GLYPHS As Integer = 4096
Const FONT_PACK_HEADER_BYTES As Integer = 20
Const FONT_PACK_GLYPH_HEADER_BYTES As Integer = 14
Const FONT_PACK_MAX_CODEPOINT As UInteger = &H10FFFF
' Keep generated packs within the runtime loader's allocation limits.
Const FONT_PACK_MAX_BYTES As ULongInt = 67108864
' Includes every scalar after excluding UTF-8 controls and surrogates.
Const FONT_PACK_MAX_GLYPHS As Integer = 1111999
' Windows desktop fonts are authored against the standard 96 DPI desktop grid.
Const FONT_PACK_TARGET_DPI As UInteger = 96
' SDL2 assigns value one to ordinary source-alpha blending.
Const FONTGEN_BLENDMODE_BLEND As Integer = &h00000001

/'
    The system FreeBASIC SDL_ttf binding targets 2.0.15. Full Unicode glyph
    enumeration and the 96-DPI font opener were added later, so declare those
    entry points here for the build-time generator. SDL stays out of the omaGUI
    runtime.
'/
Extern "C"
    Declare Function TTF_GlyphIsProvided32 Alias "TTF_GlyphIsProvided32" ( _
        ByVal font As TTF_Font Ptr, ByVal codepoint As UInteger _
    ) As Long
    Declare Function TTF_OpenFontIndexDPI _
        Alias "TTF_OpenFontIndexDPI" ( _
        ByVal fontPath As Const ZString Ptr, ByVal pointSize As Long, _
        ByVal faceIndex As CLong, ByVal horizontalDpi As UInteger, _
        ByVal verticalDpi As UInteger _
    ) As TTF_Font Ptr
    Declare Function TTF_GlyphMetrics32 Alias "TTF_GlyphMetrics32" ( _
        ByVal font As TTF_Font Ptr, ByVal codepoint As UInteger, _
        ByVal minX As Long Ptr, ByVal maxX As Long Ptr, _
        ByVal minY As Long Ptr, ByVal maxY As Long Ptr, _
        ByVal advance As Long Ptr _
    ) As Long
    Declare Function TTF_RenderGlyph32_Blended _
        Alias "TTF_RenderGlyph32_Blended" ( _
        ByVal font As TTF_Font Ptr, ByVal codepoint As UInteger, _
        ByVal foreground As SDL_Color _
    ) As SDL_Surface Ptr
End Extern

' -------------------------------------------------------------------------
' Output helpers
' -------------------------------------------------------------------------

Function FontPackCreateTemporaryFile( _
    ByRef output_path As String, ByRef temporary_path As String _
) As Integer

#ifdef __FB_WIN32__
    Dim As Integer separator_index = InStrRev(output_path, "\")
    Dim As Integer alternate_separator_index = InStrRev(output_path, "/")
    Dim As String directory_path
    Dim As ZString * MAX_PATH temporary_path_buffer

    If alternate_separator_index > separator_index Then _
        separator_index = alternate_separator_index

    If separator_index = 0 Then
        directory_path = "."
    ElseIf separator_index = 1 Then
        directory_path = Left(output_path, 1)
    ElseIf separator_index = 3 AndAlso output_path[1] = Asc(":") Then
        directory_path = Left(output_path, separator_index)
    Else
        directory_path = Left(output_path, separator_index - 1)
    End If

    If GetTempFileNameA( _
        directory_path, "ogf", 0, @temporary_path_buffer _
    ) = 0 Then Return 0

    temporary_path = temporary_path_buffer
    Return -1
#elseif defined(__FB_UNIX__)
    ' fblint: disable-next-line FBL760. mkstemp atomically creates a unique file from this template.
    temporary_path = output_path & ".tmp.XXXXXX"
    Dim As Long file_descriptor = mkstemp(StrPtr(temporary_path))
    If file_descriptor < 0 Then Return 0
    If fontgen_CloseFileDescriptor(file_descriptor) <> 0 Then
        remove(StrPtr(temporary_path))
        Return 0
    End If
    Return -1
#else
    Return 0
#endif

End Function

Function FontPackRemoveTemporaryFile(ByRef temporary_path As String) As Integer
    If Len(temporary_path) = 0 OrElse Len(Dir(temporary_path)) = 0 Then _
        Return -1
    Return (remove(temporary_path) = 0)
End Function

Function FontPackInstallTemporaryFile( _
    ByRef temporary_path As String, ByRef output_path As String _
) As Integer

#ifdef __FB_WIN32__
    ' The temporary file shares the output directory, so replacement stays on one volume.
    Dim As ULong replace_flags
    ' fblint: disable-next-line FBL310 -- Windows replacement flags are declared by windows.bi.
    replace_flags = MOVEFILE_REPLACE_EXISTING Or MOVEFILE_WRITE_THROUGH
    Return (MoveFileExA( _
        temporary_path, output_path, replace_flags _
    ) <> 0)
#elseif defined(__FB_UNIX__)
    ' POSIX rename atomically replaces an existing destination on the same filesystem.
    Return (rename(temporary_path, output_path) = 0)
#else
    Return 0
#endif

End Function

Sub PrintUsage()
    Print "Usage:"
    Print "  font_gen.exe [font-path] [point-size] [symbol-prefix] [data-output.bi] [atlas-output.bmp] [unicode-codepoints.txt] [font-face-index] [font-license]"
    Print "  font_gen.exe --pack [font-path] [point-size] [data-output.ogf] [font-face-index]"
    Print
    Print "Example:"
    Print "  font_gen.exe C:\Windows\Fonts\arial.ttf 10 font_arial_10_regular assets\fonts\font_arial_10_regular.bi assets\fonts\font_arial_10_regular.bmp"
    Print "  font_gen.exe --pack assets\fonts\CascadiaMono-Regular.ttf 11 assets\fonts\cascadia_mono.ogf"
    Print "  font_gen.exe --pack NotoSansCJK-Regular.ttc 9 assets\fonts\noto_sans_cjk_sc.ogf 2"
    Print "  font_gen.exe --pack assets\fonts\spleen-8x16.bdf 12 assets\fonts\terminal_spleen_8x16.ogf"
End Sub

Function ReadExtraGlyphList( _
    ByRef list_path As String, _
    ByRef normalized_list As String, _
    ByRef glyph_count As Integer _
) As Integer

    Dim As Integer file_number
    Dim As UInteger previous_codepoint = LAST_GLYPH
    Dim As UInteger codepoint
    Dim As String line_text

    normalized_list = ""
    glyph_count = 0
    If Len(list_path) = 0 Then Return -1

    file_number = FreeFile
    If Open(list_path For Input As #file_number) <> 0 Then
        Print "ERROR: Could not open Unicode code point list " & list_path
        Return 0
    End If

    While Not Eof(file_number)
        Line Input #file_number, line_text
        line_text = Trim(line_text)
        If line_text = "" OrElse Left(line_text, 1) = "#" OrElse _
           Left(line_text, 1) = "'" Then Continue While

        codepoint = CUInt(ValInt(line_text))
        If codepoint <= LAST_GLYPH OrElse _
           codepoint > FONT_PACK_MAX_CODEPOINT OrElse _
           (codepoint >= &H7F AndAlso codepoint <= &H9F) OrElse _
           (codepoint >= &HD800 AndAlso codepoint <= &HDFFF) Then
            Close #file_number
            Print "ERROR: Invalid Unicode scalar code point: " & line_text
            Return 0
        End If
        If glyph_count >= FONTGEN_MAX_EXTRA_GLYPHS Then
            Close #file_number
            Print "ERROR: Unicode code point list exceeds its limit."
            Return 0
        End If
        If codepoint <= previous_codepoint Then
            Close #file_number
            Print "ERROR: Unicode code points must be unique and sorted."
            Return 0
        End If

        If glyph_count > 0 Then normalized_list &= Chr(10)
        normalized_list &= Str(codepoint)
        previous_codepoint = codepoint
        glyph_count += 1
    Wend

    Close #file_number
    Return -1

End Function


Function NextExtraGlyph( _
    ByRef normalized_list As String, _
    ByRef list_position As Integer, _
    ByRef codepoint As UInteger _
) As Integer

    Dim As Integer line_end

    If list_position > Len(normalized_list) Then Return 0
    line_end = InStr(list_position, normalized_list, Chr(10))
    If line_end = 0 Then
        codepoint = ValInt(Mid(normalized_list, list_position))
        list_position = Len(normalized_list) + 1
    Else
        codepoint = ValInt(Mid( _
            normalized_list, list_position, line_end - list_position _
        ))
        list_position = line_end + 1
    End If

    Return -1

End Function

Function DefaultFontPath() As String
#ifdef __FB_WIN32__
    Return "C:\Windows\Fonts\arial.ttf"
#else
    Return "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
#endif
End Function

Function SafePointSize(ByRef text As String) As Integer
    Dim value As Integer

    value = ValInt(text)

    If value <= 0 Then
        value = DEFAULT_POINT_SIZE
    End If

    Return value
End Function

Sub EmitLine(ByVal file_number As Integer, _
             ByVal use_file As Integer, _
             ByRef text As String)
    If use_file <> 0 Then
        Print #file_number, text
    Else
        Print text
    End If
End Sub


Private Function FontDataOutputFilename( _
    ByRef symbol_prefix As String, ByRef data_output_path As String _
) As String

    Dim As Integer lastSeparator
    Dim As String outputFileName = data_output_path

    For characterIndex As Integer = 1 To Len(data_output_path)
        If Mid(data_output_path, characterIndex, 1) = "/" OrElse _
           Mid(data_output_path, characterIndex, 1) = Chr(92) Then _
            lastSeparator = characterIndex
    Next characterIndex
    If lastSeparator > 0 Then _
        outputFileName = Mid(data_output_path, lastSeparator + 1)
    If outputFileName = "" OrElse outputFileName = "-" Then _
        outputFileName = symbol_prefix & ".bi"

    Return outputFileName

End Function


' -------------------------------------------------------------------------
' Font data generation
' -------------------------------------------------------------------------

Sub EmitFileHeader(ByVal file_number As Integer, _
                   ByVal use_file As Integer, _
                   ByRef symbol_prefix As String, _
                   ByRef font_path As String, _
                   ByRef data_output_path As String, _
                   ByVal point_size As Integer, _
                   ByVal font_face_index As Integer, _
                   ByRef source_license As String)
    Dim As String outputFileName = _
        FontDataOutputFilename(symbol_prefix, data_output_path)

    EmitLine file_number, use_file, "/'"
    EmitLine file_number, use_file, "    Project: omaGUI Generated Bitmap Font"
    EmitLine file_number, use_file, "    ------------------------------------"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "    File: " & outputFileName
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "    Purpose:"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "        Store one generated bitmap font for the omaGUI renderer."
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "    Source font:"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "        " & font_path
    EmitLine file_number, use_file, "        point size " & Str(point_size)
    EmitLine file_number, use_file, "        collection face " & _
        Str(font_face_index)
    If source_license <> "" Then
        EmitLine file_number, use_file, ""
        EmitLine file_number, use_file, "    Font license:"
        EmitLine file_number, use_file, ""
        EmitLine file_number, use_file, "        " & source_license
    End If
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "    This file intentionally does NOT contain:"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "        - runtime font selection"
    EmitLine file_number, use_file, "        - text layout logic"
    EmitLine file_number, use_file, "        - the source TrueType font"
    EmitLine file_number, use_file, "'/"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "#ifndef __" & UCase(symbol_prefix) & "_BI__"
    EmitLine file_number, use_file, "#define __" & UCase(symbol_prefix) & "_BI__"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "' Format: Width, Height, AlphaData..."
    EmitLine file_number, use_file, "Dim Shared As UByte Ptr " & symbol_prefix & "_chars(32 To 126)"
    EmitLine file_number, use_file, ""
End Sub

Sub EmitGlyphData(ByVal file_number As Integer, _
                  ByVal use_file As Integer, _
                  ByRef symbol_prefix As String, _
                  ByVal character_code As Integer, _
                  ByVal surface As SDL_Surface Ptr)
    Dim pixels As UByte Ptr
    Dim pixel_value As ULong
    Dim alpha As UByte
    Dim line_text As String
    Dim pixel_text As String
    Dim suffix_text As String
    Dim output_position As Integer

    If surface = 0 OrElse surface->pixels = 0 Then Exit Sub
    If surface->w <= 0 OrElse surface->h <= 0 Then Exit Sub
    If surface->pitch < surface->w * SizeOf(ULong) Then Exit Sub

    EmitLine file_number, use_file, "' Font data for Unicode code point " & _
             Trim(Str(character_code))
    EmitLine file_number, use_file, "Static Shared As UByte " & symbol_prefix & _
             "_char_" & Trim(Str(character_code)) & "_data(...) = { _"
    EmitLine file_number, use_file, "  " & Str(surface->w) & ", " & _
             Str(surface->h) & ", _"

    pixels = surface->pixels

    For y As Integer = 0 To surface->h - 1
        ' Three alpha digits, one comma, and the line suffix bound each pixel.
        line_text = Space(2 + (surface->w * 4) + 4)
        Mid(line_text, 1, 2) = "  "
        output_position = 3

        For x As Integer = 0 To surface->w - 1
            pixel_value = *Cast( _
                ULong Ptr, _
                pixels + (y * surface->pitch) + (x * SizeOf(ULong)) _
            )
            alpha = (pixel_value Shr 24) And &HFF
            If x < surface->w - 1 Or y < surface->h - 1 Then
                pixel_text = Trim(Str(alpha)) & ","
            Else
                pixel_text = Trim(Str(alpha))
            End If

            Mid(line_text, output_position, Len(pixel_text)) = pixel_text
            output_position += Len(pixel_text)
        Next x

        If y < surface->h - 1 Then
            suffix_text = " _"
        Else
            suffix_text = " , _"
        End If

        Mid(line_text, output_position, Len(suffix_text)) = suffix_text
        line_text = Left(line_text, output_position + Len(suffix_text) - 1)

        EmitLine file_number, use_file, line_text
    Next y

    EmitLine file_number, use_file, "0 }"
    EmitLine file_number, use_file, ""
End Sub


Sub EmitUnicodeGlyphTable( _
    ByVal file_number As Integer, _
    ByVal use_file As Integer, _
    ByRef symbol_prefix As String, _
    ByRef normalized_list As String, _
    ByVal glyph_count As Integer _
)

    Dim As Integer list_position = 1
    Dim As UInteger codepoint
    Dim As Integer glyph_index

    If glyph_count <= 0 Then Exit Sub

    EmitLine file_number, use_file, "' Sorted Unicode glyph pointers for backend_SetUnicodeGlyphs."
    EmitLine file_number, use_file, "Const " & symbol_prefix & _
        "_unicode_glyph_count As Integer = " & Trim(Str(glyph_count))
    EmitLine file_number, use_file, "Dim Shared As UInteger " & symbol_prefix & _
        "_unicode_codepoints(0 To " & Trim(Str(glyph_count - 1)) & ")"
    EmitLine file_number, use_file, "Dim Shared As UByte Ptr " & symbol_prefix & _
        "_unicode_glyphs(0 To " & Trim(Str(glyph_count - 1)) & ")"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "Sub " & symbol_prefix & _
        "_init_unicode_pointers()"

    For glyph_index = 0 To glyph_count - 1
        If NextExtraGlyph(normalized_list, list_position, codepoint) = 0 Then _
            Exit For
        EmitLine file_number, use_file, "    " & symbol_prefix & _
            "_unicode_codepoints(" & Trim(Str(glyph_index)) & ") = &H" & _
            Hex(codepoint)
        EmitLine file_number, use_file, "    " & symbol_prefix & _
            "_unicode_glyphs(" & Trim(Str(glyph_index)) & ") = @" & _
            symbol_prefix & "_char_" & Trim(Str(codepoint)) & "_data(0)"
    Next glyph_index

    EmitLine file_number, use_file, "End Sub"
    EmitLine file_number, use_file, ""

End Sub

Sub EmitInitBlock(ByVal file_number As Integer, _
                  ByVal use_file As Integer, _
                  ByRef symbol_prefix As String)
    EmitLine file_number, use_file, "Sub " & symbol_prefix & "_init_pointers()"
    EmitLine file_number, use_file, "    /'"
    EmitLine file_number, use_file, "        The drawing backend indexes printable ASCII characters"
    EmitLine file_number, use_file, "        directly by character code. Each pointer references one"
    EmitLine file_number, use_file, "        generated width, height, alpha-data block."
    EmitLine file_number, use_file, "    '/"

    For i As Integer = FIRST_GLYPH To LAST_GLYPH
        EmitLine file_number, use_file, "    " & symbol_prefix & "_chars(" & _
                 Trim(Str(i)) & ") = @" & symbol_prefix & "_char_" & _
                 Trim(Str(i)) & "_data(0)"
    Next i

    EmitLine file_number, use_file, "End Sub"
    EmitLine file_number, use_file, ""
End Sub

Sub EmitFileFooter( _
    ByVal file_number As Integer, ByVal use_file As Integer, _
    ByRef symbol_prefix As String, ByRef data_output_path As String _
)

    EmitLine file_number, use_file, "#endif"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "/' end of " & _
        FontDataOutputFilename(symbol_prefix, data_output_path) & " '/"

End Sub

Function SaveAtlas(ByVal font As TTF_Font Ptr, _
                   ByRef atlas_path As String, _
                   ByVal max_width As Integer, _
                   ByVal max_height As Integer) As Integer
    Dim rows As Integer
    Dim cell_width As Integer
    Dim cell_height As Integer
    Dim atlas_width As Integer
    Dim atlas_height As Integer
    Dim atlas As SDL_Surface Ptr
    Dim glyph As SDL_Surface Ptr
    Dim dest As SDL_Rect
    Dim white As SDL_Color
    Dim black As ULong

    If Len(atlas_path) = 0 Then
        Return -1
    End If

    rows = ((LAST_GLYPH - FIRST_GLYPH + 1) + ATLAS_COLUMNS - 1) \ ATLAS_COLUMNS
    cell_width = max_width + 4
    cell_height = max_height + 4
    atlas_width = ATLAS_COLUMNS * cell_width
    atlas_height = rows * cell_height

    If cell_width < 4 Or cell_height < 4 Then
        Print "ERROR: Invalid atlas cell dimensions."
        Return 0
    End If

    atlas = SDL_CreateRGBSurface(0, atlas_width, atlas_height, 32, _
                                 &H00FF0000, &H0000FF00, &H000000FF, _
                                 &HFF000000)
    If atlas = 0 Then
        Print "ERROR: Could not create atlas surface."
        Return 0
    End If

    black = SDL_MapRGB(atlas->format, 0, 0, 0)
    SDL_FillRect(atlas, 0, black)

    white.r = 255
    white.g = 255
    white.b = 255
    white.a = 255

    For i As Integer = FIRST_GLYPH To LAST_GLYPH
        glyph = TTF_RenderGlyph_Blended(font, i, white)

        If glyph <> 0 Then
            SDL_SetSurfaceBlendMode(glyph, FONTGEN_BLENDMODE_BLEND)
            dest.x = ((i - FIRST_GLYPH) Mod ATLAS_COLUMNS) * cell_width + 2
            dest.y = ((i - FIRST_GLYPH) \ ATLAS_COLUMNS) * cell_height + 2
            dest.w = glyph->w
            dest.h = glyph->h
            SDL_BlitSurface(glyph, 0, atlas, @dest)
            SDL_FreeSurface(glyph)
        End If
    Next i

    If SDL_SaveBMP(atlas, atlas_path) <> 0 Then
        Print "ERROR: Could not save atlas " & atlas_path
        SDL_FreeSurface(atlas)
        Return 0
    End If

    SDL_FreeSurface(atlas)
    Return -1
End Function

Private Function FontPackU16(ByVal value As UInteger) As String
    Return Chr(value And &HFF) & Chr((value Shr 8) And &HFF)
End Function

Private Function FontPackU32(ByVal value As UInteger) As String
    Return Chr(value And &HFF) & _
           Chr((value Shr 8) And &HFF) & _
           Chr((value Shr 16) And &HFF) & _
           Chr((value Shr 24) And &HFF)
End Function

Private Function FontPackSigned16(ByVal value As Long) As String
    Return FontPackU16(CUInt(value) And &HFFFF)
End Function

Private Function FontPackCodepointIsControl( _
    ByVal codepoint As UInteger _
) As Integer

    If codepoint < 32 OrElse _
       (codepoint >= &H7F AndAlso codepoint <= &H9F) Then Return -1
    If codepoint >= &HD800 AndAlso codepoint <= &HDFFF Then Return -1
    Return 0

End Function

' fblint: disable-next-line FBL111 -- Glyph metrics, SDL surface and output cursor share one record step.
Function GenerateFontPack( _
    ByRef font_path As String, ByVal point_size As Integer, _
    ByRef output_path As String, ByVal font_face_index As Integer _
) As Integer

    Dim As Integer file_number
    Dim As Integer glyph_count
    Dim As Integer font_height
    Dim As Integer font_ascent
    Dim As Integer pixel_count
    Dim As Integer pixel_index
    Dim As Integer invalid_pack
    Dim As Integer bitmap_width
    Dim As Integer bitmap_height
    Dim As Integer alpha_min_x
    Dim As Integer alpha_min_y
    Dim As Integer alpha_max_x
    Dim As Integer alpha_max_y
    Dim As Long min_x
    Dim As Long max_x
    Dim As Long min_y
    Dim As Long max_y
    Dim As Long advance
    Dim As Long bearing_x
    Dim As Long bearing_y
    Dim As UInteger codepoint
    Dim As ULong pixel_value
    Dim As ULongInt pack_size
    Dim As ULongInt glyph_record_size
    Dim As UByte alpha
    Dim As UByte Ptr pixels
    Dim As SDL_Surface Ptr surface
    Dim As SDL_Color white
    Dim As Const SDL_version Ptr linked_version
    Dim As TTF_Font Ptr font
    Dim As String temporary_path
    Dim As String file_header
    Dim As String glyph_header
    Dim As String glyph_pixels

    If point_size < 1 OrElse point_size > 255 Then
        Print "ERROR: Font point size must be from 1 through 255."
        Return 0
    End If
    If font_face_index < 0 OrElse font_face_index > 65535 Then
        Print "ERROR: Font face index must be from 0 through 65535."
        Return 0
    End If
    If Len(output_path) = 0 Then
        Print "ERROR: Font pack output path is empty."
        Return 0
    End If

    If TTF_Init() = -1 Then
        Print "ERROR: Could not initialize SDL_ttf."
        Return 0
    End If

    linked_version = TTF_Linked_Version()
    If linked_version = 0 OrElse linked_version->major < 2 OrElse _
       (linked_version->major = 2 AndAlso linked_version->minor < 0) OrElse _
       (linked_version->major = 2 AndAlso linked_version->minor = 0 AndAlso _
        linked_version->patch < 18) Then
        Print "ERROR: Full Unicode font packs require SDL_ttf 2.0.18 or newer."
        TTF_Quit()
        Return 0
    End If

    font = TTF_OpenFontIndexDPI( _
        font_path, point_size, font_face_index, _
        FONT_PACK_TARGET_DPI, FONT_PACK_TARGET_DPI _
    )
    If font = 0 Then
        Print "ERROR: Could not load font " & font_path
        TTF_Quit()
        Return 0
    End If

    font_height = TTF_FontHeight(font)
    font_ascent = TTF_FontAscent(font)
    If font_height < 1 OrElse font_height > 65535 OrElse _
       font_ascent < 0 OrElse font_ascent > 65535 Then
        Print "ERROR: Font metrics are outside the font-pack format limits."
        TTF_CloseFont(font)
        TTF_Quit()
        Return 0
    End If

    If FontPackCreateTemporaryFile(output_path, temporary_path) = 0 Then
        Print "ERROR: Could not create a temporary font pack beside " & output_path
        TTF_CloseFont(font)
        TTF_Quit()
        Return 0
    End If
    file_number = FreeFile
    If Open(temporary_path For Binary Access Write As #file_number) <> 0 Then
        Print "ERROR: Could not open font pack output " & temporary_path
        If FontPackRemoveTemporaryFile(temporary_path) = 0 Then _
            Print "WARNING: Could not remove temporary font pack " & temporary_path
        TTF_CloseFont(font)
        TTF_Quit()
        Return 0
    End If
    pack_size = FONT_PACK_HEADER_BYTES

    /'
        OGF1 stores one complete font cmap in sorted code-point order.
        Header: magic, version, header size, glyph count, line height,
        ascent, point size, and collection face index, all little-endian.
        Glyphs store code point, cropped bitmap dimensions, advance, bearings,
        then one alpha byte per bitmap pixel. SDL_ttf renders each glyph into
        a line-aligned surface, so cropping the ink is required before the
        bearings can be applied by omaGUI's bitmap renderer.
    '/
    file_header = "OGF1" & FontPackU16(1) & _
        FontPackU16(FONT_PACK_HEADER_BYTES) & FontPackU32(0) & _
        FontPackU16(font_height) & FontPackU16(font_ascent) & _
        FontPackU16(point_size) & FontPackU16(font_face_index)
    Put #file_number, , file_header

    white.r = 255
    white.g = 255
    white.b = 255
    white.a = 255

    For codepoint As UInteger = 32 To FONT_PACK_MAX_CODEPOINT
        If FontPackCodepointIsControl(codepoint) <> 0 Then Continue For
        If TTF_GlyphIsProvided32(font, codepoint) = 0 Then Continue For
        If glyph_count >= FONT_PACK_MAX_GLYPHS Then
            Print "ERROR: Font has more glyphs than the OGF1 format allows."
            invalid_pack = -1
            Exit For
        End If
        If TTF_GlyphMetrics32( _
            font, codepoint, @min_x, @max_x, @min_y, @max_y, @advance _
        ) <> 0 Then
            Print "WARNING: Could not read metrics for Unicode code point " & _
                Str(codepoint)
            Continue For
        End If

        surface = TTF_RenderGlyph32_Blended(font, codepoint, white)
        If surface = 0 Then
            Print "WARNING: Could not render Unicode code point " & _
                Str(codepoint)
            Continue For
        End If

        If surface->pixels = 0 OrElse surface->format = 0 OrElse _
           surface->format->BytesPerPixel <> 4 OrElse _
           surface->format->Amask = 0 OrElse surface->w < 0 OrElse _
           surface->h < 0 OrElse surface->w > 255 OrElse _
           surface->h > 255 OrElse surface->pitch < surface->w * 4 OrElse _
           advance < 0 OrElse advance > 65535 OrElse _
           min_x < -32768 OrElse min_x > 32767 OrElse _
           (font_ascent - max_y) < -32768 OrElse _
           (font_ascent - max_y) > 32767 Then
            Print "WARNING: Skipping out-of-range glyph " & Str(codepoint)
            SDL_FreeSurface(surface)
            Continue For
        End If

        /'
            SDL_ttf returns a line-aligned glyph surface. Its origin shifts
            right or down when a glyph overhangs above or left of the line.
            Cropped pixel bounds include the metric bearing and that shift, so
            remove only the surface-origin shift when storing pen-relative
            bearings.
        '/
        alpha_min_x = surface->w
        alpha_min_y = surface->h
        alpha_max_x = -1
        alpha_max_y = -1
        pixels = surface->pixels
        For pixel_y As Integer = 0 To surface->h - 1
            For pixel_x As Integer = 0 To surface->w - 1
                pixel_value = *Cast( _
                    ULong Ptr, pixels + (pixel_y * surface->pitch) + _
                    (pixel_x * SizeOf(ULong)) _
                )
                alpha = (pixel_value Shr surface->format->Ashift) And &HFF
                If alpha = 0 Then Continue For
                If pixel_x < alpha_min_x Then alpha_min_x = pixel_x
                If pixel_y < alpha_min_y Then alpha_min_y = pixel_y
                If pixel_x > alpha_max_x Then alpha_max_x = pixel_x
                If pixel_y > alpha_max_y Then alpha_max_y = pixel_y
            Next pixel_x
        Next pixel_y

        If alpha_max_x < alpha_min_x OrElse alpha_max_y < alpha_min_y Then
            ' Whitespace has an advance but no bitmap pixels.
            bitmap_width = 0
            bitmap_height = 0
            alpha_min_x = 0
            alpha_min_y = 0
        Else
            bitmap_width = alpha_max_x - alpha_min_x + 1
            bitmap_height = alpha_max_y - alpha_min_y + 1
        End If

        bearing_x = alpha_min_x
        If min_x < 0 Then bearing_x += min_x
        bearing_y = alpha_min_y
        If max_y > font_ascent Then _
            bearing_y += font_ascent - max_y
        If bearing_x < -32768 OrElse bearing_x > 32767 OrElse _
           bearing_y < -32768 OrElse bearing_y > 32767 Then
            Print "WARNING: Skipping out-of-range glyph " & Str(codepoint)
            SDL_FreeSurface(surface)
            Continue For
        End If

        pixel_count = bitmap_width * bitmap_height
        glyph_record_size = FONT_PACK_GLYPH_HEADER_BYTES + _
            CULngInt(pixel_count)
        If glyph_record_size > FONT_PACK_MAX_BYTES OrElse _
           pack_size > FONT_PACK_MAX_BYTES - glyph_record_size Then
            Print "ERROR: Generated font pack would exceed 64 MiB."
            SDL_FreeSurface(surface)
            invalid_pack = -1
            Exit For
        End If

        glyph_pixels = Space(pixel_count)
        pixel_index = 0
        For pixel_y As Integer = alpha_min_y To alpha_max_y
            For pixel_x As Integer = alpha_min_x To alpha_max_x
                pixel_value = *Cast( _
                    ULong Ptr, pixels + (pixel_y * surface->pitch) + _
                    (pixel_x * SizeOf(ULong)) _
                )
                alpha = (pixel_value Shr surface->format->Ashift) And &HFF
                glyph_pixels[pixel_index] = alpha
                pixel_index += 1
            Next pixel_x
        Next pixel_y

        glyph_header = FontPackU32(codepoint) & _
            FontPackU16(bitmap_width) & FontPackU16(bitmap_height) & _
            FontPackU16(advance) & FontPackSigned16(bearing_x) & _
            FontPackSigned16(bearing_y)
        Put #file_number, , glyph_header
        If pixel_count > 0 Then Put #file_number, , glyph_pixels
        SDL_FreeSurface(surface)
        glyph_count += 1
        pack_size += glyph_record_size

        If glyph_count Mod 4096 = 0 Then _
            Print "Rendered " & Str(glyph_count) & " glyphs..."
    Next codepoint

    If invalid_pack <> 0 Then
        Close #file_number
        If FontPackRemoveTemporaryFile(temporary_path) = 0 Then _
            Print "WARNING: Could not remove temporary font pack " & temporary_path
        TTF_CloseFont(font)
        TTF_Quit()
        Return 0
    End If

    If glyph_count < 1 Then
        Print "ERROR: The selected font has no renderable glyphs."
        Close #file_number
        If FontPackRemoveTemporaryFile(temporary_path) = 0 Then _
            Print "WARNING: Could not remove temporary font pack " & temporary_path
        TTF_CloseFont(font)
        TTF_Quit()
        Return 0
    End If

    Put #file_number, 9, FontPackU32(glyph_count)
    Close #file_number
    TTF_CloseFont(font)
    TTF_Quit()

    If FontPackInstallTemporaryFile(temporary_path, output_path) = 0 Then
        Print "ERROR: Could not replace font pack output " & output_path
        If FontPackRemoveTemporaryFile(temporary_path) = 0 Then _
            Print "WARNING: Could not remove temporary font pack " & temporary_path
        Return 0
    End If
    Print "Saved " & Str(glyph_count) & " glyphs to " & output_path
    Return -1

End Function

Function GenerateFontData(ByRef font_path As String, _
                          ByVal point_size As Integer, _
                          ByRef symbol_prefix As String, _
                          ByRef data_output_path As String, _
                          ByRef atlas_output_path As String, _
                          ByRef unicode_list_path As String, _
                          ByVal font_face_index As Integer, _
                          ByRef source_license As String) As Integer
    Dim file_number As Integer
    Dim use_file As Integer
    Dim font As TTF_Font Ptr
    Dim surface As SDL_Surface Ptr
    Dim white As SDL_Color
    Dim max_width As Integer = 0
    Dim max_height As Integer = 0
    Dim unicode_list As String
    Dim unicode_count As Integer
    Dim unicode_position As Integer
    Dim codepoint As UInteger

    If ReadExtraGlyphList( _
        unicode_list_path, unicode_list, unicode_count _
    ) = 0 Then Return 0

    If TTF_Init() = -1 Then
        Print "ERROR: Could not initialize SDL_ttf."
        Return 0
    End If

    font = TTF_OpenFontIndex(font_path, point_size, font_face_index)
    If font = 0 Then
        Print "ERROR: Could not load font " & font_path
        TTF_Quit()
        Return 0
    End If

    use_file = 0
    file_number = 0

    If Len(data_output_path) > 0 AndAlso data_output_path <> "-" Then
        file_number = FreeFile

        If Open(data_output_path For Output As #file_number) <> 0 Then
            Print "ERROR: Could not open output file " & data_output_path
            TTF_CloseFont(font)
            TTF_Quit()
            Return 0
        End If

        use_file = -1
    End If

    white.r = 255
    white.g = 255
    white.b = 255
    white.a = 255

    EmitFileHeader _
        file_number, use_file, symbol_prefix, font_path, data_output_path, _
        point_size, font_face_index, source_license

    For i As Integer = FIRST_GLYPH To LAST_GLYPH
        surface = TTF_RenderGlyph_Blended(font, i, white)

        If surface <> 0 Then
            If surface->w > max_width Then max_width = surface->w
            If surface->h > max_height Then max_height = surface->h
            EmitGlyphData file_number, use_file, symbol_prefix, i, surface
            SDL_FreeSurface(surface)
        Else
            Print "WARNING: Missing glyph " & Str(i)
        End If
    Next i

    unicode_position = 1
    For i As Integer = 0 To unicode_count - 1
        If NextExtraGlyph(unicode_list, unicode_position, codepoint) = 0 Then _
            Exit For

        /'
            The legacy TTF_RenderGlyph_Blended entry point accepts only a
            16-bit character. Unicode include glyphs use the 32-bit variant.
        '/
        If TTF_GlyphIsProvided32(font, codepoint) = 0 Then
            Print "ERROR: Font does not contain Unicode code point " & _
                Str(codepoint)
            If use_file <> 0 Then
                Close #file_number
            End If
            TTF_CloseFont(font)
            TTF_Quit()
            Return 0
        End If
        surface = TTF_RenderGlyph32_Blended(font, codepoint, white)
        If surface = 0 Then
            Print "ERROR: Font does not contain Unicode code point " & _
                Str(codepoint)
            If use_file <> 0 Then
                Close #file_number
            End If
            TTF_CloseFont(font)
            TTF_Quit()
            Return 0
        End If

        EmitGlyphData file_number, use_file, symbol_prefix, codepoint, surface
        SDL_FreeSurface(surface)
    Next i

    EmitInitBlock file_number, use_file, symbol_prefix
    EmitUnicodeGlyphTable _
        file_number, use_file, symbol_prefix, unicode_list, unicode_count
    EmitFileFooter file_number, use_file, symbol_prefix, data_output_path

    If use_file <> 0 Then
        Close #file_number
    End If

    If SaveAtlas(font, atlas_output_path, max_width, max_height) = 0 Then
        TTF_CloseFont(font)
        TTF_Quit()
        Return 0
    End If

    TTF_CloseFont(font)
    TTF_Quit()

    Return -1
End Function

' -------------------------------------------------------------------------
' Program entry
' -------------------------------------------------------------------------

Dim font_path As String = Command(1)
Dim point_size As Integer = SafePointSize(Command(2))
Dim symbol_prefix As String = Command(3)
Dim data_output_path As String = Command(4)
Dim atlas_output_path As String = Command(5)
Dim unicode_list_path As String = Command(6)
Dim font_face_index As Integer = ValInt(Command(7))
Dim source_license As String = Command(8)

If LCase(Command(1)) = "--pack" Then
    Dim As String pack_font_path = Command(2)
    Dim As Integer pack_point_size = SafePointSize(Command(3))
    Dim As String pack_output_path = Command(4)
    Dim As Integer pack_face_index = ValInt(Command(5))

    If pack_font_path = "" OrElse pack_output_path = "" Then
        PrintUsage
        End 1
    End If
    If GenerateFontPack( _
        pack_font_path, pack_point_size, pack_output_path, pack_face_index _
    ) = 0 Then End 1
    End 0
End If

If LCase(font_path) = "--help" Or font_path = "/?" Then
    PrintUsage
    End 0
End If

If Len(font_path) = 0 Then
    font_path = DefaultFontPath()
End If

If Len(symbol_prefix) = 0 Then
    symbol_prefix = "font"
End If

If font_face_index < 0 Then
    Print "ERROR: Font face index cannot be negative."
    End 1
End If

If GenerateFontData(font_path, point_size, symbol_prefix, _
                    data_output_path, atlas_output_path, _
                    unicode_list_path, font_face_index, _
                    source_license) = 0 Then
    End 1
End If

End 0

/' end of font_gen.bas '/
