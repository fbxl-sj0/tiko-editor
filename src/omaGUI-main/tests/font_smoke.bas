' Project: omaGUI
' ---------------
'
' File: font_smoke.bas
'
' Purpose:
'
'     Verify that the bundled large Liberation bitmap faces are linked into
'     the public omaGUI implementation and can be selected by labels.
'
' Targets: FreeBASIC 1.20.3-1, Windows/Linux/macOS/BSD
' Module API: FontSmokeRun is the executable test entry point.
'
' Responsibilities:
'
'     - check the measured dimensions of the large sans and serif faces
'     - check label font selection without requiring a host font install
'     - check bounded label wrapping at words, paths, and explicit line breaks
'     - exercise label construction through the public widget API
'
' This file intentionally does NOT contain:
'
'     - visual screenshot comparison
'     - TrueType loading at runtime
'     - operating-system font discovery

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"

Dim Shared As Long fontSmokeChecks
Dim Shared As Long fontSmokeFailures


Private Sub FontSmokeAssert(ByVal condition As Integer, ByVal message As String)
    fontSmokeChecks += 1
    If condition Then Exit Sub
    fontSmokeFailures += 1
    Print "FAIL: "; message
End Sub


Private Function FontSmokeRun() As Integer
    Dim As Widget Ptr sansLabel
    Dim As Widget Ptr serifLabel
    Dim As Widget Ptr wrappedLabel
    Dim As LabelData Ptr sansData
    Dim As LabelData Ptr serifData
    Dim As LabelData Ptr wrappedData
    Dim As Integer characterCode
    Dim As String characterText

    FontSmokeAssert( _
        backend_GetTextHeightFont( _
            BACKEND_FONT_LIBERATION_SANS_18_BOLD _
        ) >= 18, _
        "the large sans face has its generated point-size height" _
    )
    FontSmokeAssert( _
        backend_GetTextHeightFont( _
            BACKEND_FONT_LIBERATION_SERIF_18_REGULAR _
        ) >= 18, _
        "the large serif face has its generated point-size height" _
    )
    FontSmokeAssert( _
        backend_GetTextWidthFont( _
            "HART", BACKEND_FONT_LIBERATION_SANS_18_BOLD _
        ) > backend_GetTextWidth("HART"), _
        "the large sans face is wider than the compact default face" _
    )

    ' The generated tables are deliberately printable-ASCII only.  Check
    ' every entry so a partial regeneration cannot silently turn one DD
    ' heading or button label into an empty string at runtime.
    For characterCode = 32 To 126
        characterText = Chr(characterCode)
        FontSmokeAssert( _
            backend_GetTextWidthFont( _
                characterText, BACKEND_FONT_LIBERATION_SANS_18_BOLD _
            ) > 0, _
            "the generated sans table contains character " & Str(characterCode) _
        )
        FontSmokeAssert( _
            backend_GetTextWidthFont( _
                characterText, BACKEND_FONT_LIBERATION_SERIF_18_REGULAR _
            ) > 0, _
            "the generated serif table contains character " & Str(characterCode) _
        )
    Next characterCode

    sansLabel = label_Create( _
        "font_smoke_sans", "Sans heading", 12, 12, RGB(20, 45, 75), _
        BACKEND_FONT_LIBERATION_SANS_18_BOLD _
    )
    serifLabel = label_Create( _
        "font_smoke_serif", "Serif heading", 12, 48, RGB(20, 45, 75), _
        BACKEND_FONT_LIBERATION_SERIF_18_REGULAR _
    )
    sansData = Cast(LabelData Ptr, sansLabel->data)
    serifData = Cast(LabelData Ptr, serifLabel->data)
    FontSmokeAssert( _
        sansData->fontId = BACKEND_FONT_LIBERATION_SANS_18_BOLD, _
        "label_Create retains the selected sans face" _
    )
    FontSmokeAssert( _
        serifData->fontId = BACKEND_FONT_LIBERATION_SERIF_18_REGULAR, _
        "label_Create retains the selected serif face" _
    )
    label_SetFont sansLabel, BACKEND_FONT_LIBERATION_SERIF_18_REGULAR
    FontSmokeAssert( _
        sansData->fontId = BACKEND_FONT_LIBERATION_SERIF_18_REGULAR, _
        "label_SetFont changes the embedded face without rebuilding the widget" _
    )

    wrappedLabel = label_Create( _
        "font_smoke_wrapped", _
        "DD Library: C:\Users\Instrumentation\Downloads\HART\Library", _
        12, 84, RGB(70, 70, 70) _
    )
    wrappedData = Cast(LabelData Ptr, wrappedLabel->data)
    label_SetWordWrap wrappedLabel, 120, 2
    FontSmokeAssert( _
        wrappedData->wordWrap <> 0 AndAlso _
        wrappedData->maximumLines = 2 AndAlso wrappedLabel->w = 120, _
        "label_SetWordWrap retains its measured width and line bound" _
    )
    FontSmokeAssert( _
        label_GetRenderedLineCount(wrappedLabel) = 2, _
        "a long local path wraps within the configured two-line bound" _
    )
    wrappedData->text = "First line" & Chr(13) & Chr(10) & "Second line"
    label_SetWordWrap wrappedLabel, 300, 4
    FontSmokeAssert( _
        label_GetRenderedLineCount(wrappedLabel) = 2, _
        "explicit CRLF text produces two wrapped label lines" _
    )
    label_SetWordWrap wrappedLabel, 0
    FontSmokeAssert( _
        wrappedData->wordWrap = 0 AndAlso _
        label_GetRenderedLineCount(wrappedLabel) = 1, _
        "zero wrap width restores the original single-line behavior" _
    )

    label_Destroy sansLabel
    label_Destroy serifLabel
    label_Destroy wrappedLabel
    Delete sansLabel
    Delete serifLabel
    Delete wrappedLabel

    Print fontSmokeChecks; " checks, "; fontSmokeFailures; " failures"
    If fontSmokeFailures > 0 Then Return 1
    Return 0
End Function

Print "omaGUI bundled font smoke test"
font_init_pointers()
Dim As Integer fontSmokeResult
fontSmokeResult = FontSmokeRun()
If fontSmokeResult <> 0 Then End 1
End 0

/' end of font_smoke.bas '/
