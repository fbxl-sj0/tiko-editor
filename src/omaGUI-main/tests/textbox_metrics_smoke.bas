/'
    Project: omaGUI Tests
    File: textbox_metrics_smoke.bas
    Purpose: Check large-document row checkpoints and folded line mapping.
    Responsibilities: Exercise unwrapped row indexing, stable visibility
        callbacks, caret edits, and bounded lookup work in drawable headless mode.
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable API.

    This file intentionally does NOT contain: editor syntax or rendering policy.
'/

#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Const METRICS_SMOKE_LINE_COUNT As Integer = 10000
Private Const METRICS_SMOKE_EDIT_LINE As Integer = 5001
Private Dim Shared As Integer metricsSmokeCallbackCalls
Private Dim Shared As Integer metricsSmokeCallbackErrors
Private Dim Shared As Integer metricsSmokeTrackPositions
Private Dim Shared As Integer metricsSmokeEditApplied

Private Sub Fail(ByRef messageText As Const String)
    Print "textbox metrics smoke failed: "; messageText
    backend_Exit
    End 1
End Sub

Private Function MetricsSmokeVisibleLine( _
    ByVal w As Widget Ptr, ByVal lineNumber As Integer, _
    ByVal lineStart As Integer _
) As Integer
    Dim As LongInt expectedStart

    If w = 0 Then Return 0
    metricsSmokeCallbackCalls += 1
    If metricsSmokeTrackPositions <> 0 Then
        expectedStart = CLngInt(lineNumber) * 2
        If metricsSmokeEditApplied <> 0 AndAlso _
           lineNumber > METRICS_SMOKE_EDIT_LINE Then
            expectedStart += 1
        End If
        If lineStart <> expectedStart Then metricsSmokeCallbackErrors += 1
    End If
    Return IIf((lineNumber Mod 2) = 1, -1, 0)
End Function

Private Function MetricsSmokeVisibilityState( _
    ByVal w As Widget Ptr _
) As String
    If w = 0 Then Return ""
    Return "fixed visibility state"
End Function

backend_Init 320, 200, BACKEND_HEADLESS_DRAWABLE, 0, _
    BACKEND_COLOR_DEPTH_TRUE_COLOR
gui_Init

Dim As Widget Ptr editor = textbox_Create( _
    "metrics", "", 10, 10, 240, 90, -1, 0 _
)
If editor = 0 Then Fail "editor allocation"
gui_AddWidget editor

Dim As String document
For lineNumber As Integer = 0 To METRICS_SMOKE_LINE_COUNT - 1
    document &= "x" & Chr(10)
Next lineNumber

textbox_SetText editor, document, -1
textbox_SetLineVisibilityHandler editor, @MetricsSmokeVisibleLine
textbox_SetMetricsStateHandler editor, @MetricsSmokeVisibilityState
metricsSmokeTrackPositions = -1
gui_RenderAll

Dim As TextBoxData Ptr textData = Cast(TextBoxData Ptr, editor->data)
If textData = 0 Then Fail "textbox data"
If textData->total_visual_lines <> METRICS_SMOKE_LINE_COUNT \ 2 Then _
    Fail "folded visual-line count"
If textData->metrics_row_count < 30 OrElse _
   textData->metrics_row_count > 32 Then Fail "checkpoint count"
If metricsSmokeCallbackErrors <> 0 Then Fail "initial callback line positions"

metricsSmokeCallbackCalls = 0
If textbox_VisualLineForPosition( _
    document, (METRICS_SMOKE_LINE_COUNT - 1) * 2, 0, 200, textData _
) <> (METRICS_SMOKE_LINE_COUNT \ 2) - 1 Then _
    Fail "visual row lookup near document end"

Dim As Integer lineStart, lineEnd
If textbox_VisualLineBounds( _
    document, (METRICS_SMOKE_LINE_COUNT \ 2) - 1, 0, 200, _
    lineStart, lineEnd, textData _
) = 0 Then Fail "visual row bounds near document end"
If lineStart <> (METRICS_SMOKE_LINE_COUNT - 1) * 2 OrElse _
   lineEnd <> lineStart + 1 Then Fail "visual row byte bounds"
If metricsSmokeCallbackErrors <> 0 Then Fail "indexed callback line positions"
#If Not Defined(OMAGUI_DISABLE_ROW_INDEX)
If metricsSmokeCallbackCalls > 1500 Then Fail "row lookup did not use checkpoints"
#EndIf

If textbox_SetCursorPosition(editor, METRICS_SMOKE_EDIT_LINE * 2) = 0 Then _
    Fail "caret placement before edit"
metricsSmokeTrackPositions = 0
If textbox_InsertAtSelection(editor, "z") = 0 Then Fail "single-byte edit"
metricsSmokeEditApplied = -1
metricsSmokeTrackPositions = -1
If Len(textData->text) <> Len(document) + 1 Then Fail "edited document length"

metricsSmokeCallbackCalls = 0
If textbox_VisualLineForPosition( _
    textData->text, (METRICS_SMOKE_LINE_COUNT - 1) * 2 + 1, _
    0, 200, textData _
) <> (METRICS_SMOKE_LINE_COUNT \ 2) - 1 Then _
    Fail "visual row lookup after edit"
If textbox_VisualLineBounds( _
    textData->text, (METRICS_SMOKE_LINE_COUNT \ 2) - 1, 0, 200, _
    lineStart, lineEnd, textData _
) = 0 Then Fail "visual row bounds after edit"
If lineStart <> (METRICS_SMOKE_LINE_COUNT - 1) * 2 + 1 OrElse _
   lineEnd <> lineStart + 1 Then Fail "edited visual row byte bounds"
If metricsSmokeCallbackErrors <> 0 Then Fail "edited callback line positions"
#If Not Defined(OMAGUI_DISABLE_ROW_INDEX)
If metricsSmokeCallbackCalls > 1500 Then Fail "edited row lookup did not use checkpoints"
#EndIf

gui_RemoveWidgetPtr editor
backend_Exit
Print "textbox_metrics_smoke: PASS (checkpoints, fold mapping, edit, bounded lookup)"
/' end of textbox_metrics_smoke.bas '/
