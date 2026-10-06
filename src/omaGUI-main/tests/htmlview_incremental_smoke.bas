' Project: omaGUI Cooperative HTML Viewer Tests
' ---------------------------------------------
'
' File: htmlview_incremental_smoke.bas
'
' Purpose:
'
'     Verify incremental HTML parsing on the ordinary omaGUI update thread.
'
' Targets:
'
'     FreeBASIC 1.20.3-1 in FB dialect on 32-bit and 64-bit Windows.  The
'     test uses only cross-platform omaGUI and FreeBASIC interfaces.
'
' Responsibilities:
'
'     - prove that a visible document remains stable while another is parsed
'     - verify explicit progress, completion, cancellation, and failure states
'     - verify resize restarts and automatic gui_UpdateAll advancement
'     - verify that staged item ownership transfers and is released safely
'
' Module API:
'
'     This is a standalone test program.  Its document builder is private
'     test support and is not part of the omaGUI public API.
'
' Ownership:
'
'     The GUI manager owns the test widget after gui_AddWidget and destroys
'     both active and staged HTML data through gui_RemoveWidget.
'
' This file intentionally does NOT contain:
'
'     - worker threads, network access, browser emulation, or timing sleeps
'     - application-specific HART or DD behavior

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"
#include once "tests/test_harness.bi"

Const HTMLVIEW_INCREMENTAL_WIDTH As Integer = 720
Const HTMLVIEW_INCREMENTAL_HEIGHT As Integer = 520
Const HTMLVIEW_INCREMENTAL_ROWS As Integer = 6000
Const HTMLVIEW_INCREMENTAL_MAXIMUM_STEPS As Integer = 20000


Private Function incremental_BuildDocument( _
    ByVal documentTitle As String, ByVal rowCount As Integer _
) As String
    Dim As String htmlText
    Dim As String headerText
    Dim As String footerText
    Dim As String rowText
    Dim As Integer rowIndex
    Dim As Long writePosition
    Dim As LongInt bufferLength

    If rowCount < 0 Then rowCount = 0
    headerText = "<!doctype html><html><head><title>" & _
        documentTitle & "</title></head><body><h1>" & _
        documentTitle & "</h1>"
    footerText = "</body></html>"

    /'
        Each generated row is shorter than 64 bytes for the bounded test
        index.  Preallocation keeps document construction linear so the test
        measures parser behavior rather than repeated string growth.
    '/
    bufferLength = Len(headerText) + Len(footerText) + _
        CLngInt(rowCount) * 64
    If bufferLength > HTMLVIEW_MAX_DOCUMENT_BYTES Then Return ""
    htmlText = Space(bufferLength)
    writePosition = 1
    Mid(htmlText, writePosition, Len(headerText)) = headerText
    writePosition += Len(headerText)
    For rowIndex = 1 To rowCount
        rowText = "<p>Cooperative row " & _
            LTrim(Str(rowIndex)) & " remains readable.</p>"
        If writePosition + Len(rowText) + Len(footerText) - 1 > _
           Len(htmlText) Then Return ""
        Mid(htmlText, writePosition, Len(rowText)) = rowText
        writePosition += Len(rowText)
    Next rowIndex
    Mid(htmlText, writePosition, Len(footerText)) = footerText
    writePosition += Len(footerText)
    htmlText = Left(htmlText, writePosition - 1)
    Return htmlText
End Function


Dim As Widget Ptr htmlWidget
Dim As HtmlViewData Ptr viewData
Dim As String largeHtml
Dim As String activeTitle
Dim As String activeText
Dim As String malformedHtml
Dim As Integer loadState
Dim As Integer loadProgress
Dim As Integer previousProgress
Dim As Integer loadStepCount
Dim As Integer activeDocumentStayedStable = -1
Dim As Integer progressStayedMonotonic = -1

backend_Init HTMLVIEW_INCREMENTAL_WIDTH, HTMLVIEW_INCREMENTAL_HEIGHT, 1
gui_Init
input_ResetForTest

htmlWidget = htmlview_Create("html_incremental", 10, 10, 560, 420)
AssertTrue htmlWidget <> 0, "cooperative HTML viewer creates"
If htmlWidget = 0 Then
    backend_Exit
    test_Summary
    End 1
End If
gui_AddWidget htmlWidget

test_Section "staged completion and atomic transfer"
AssertTrue htmlview_SetHtml( _
    htmlWidget, _
    "<html><head><title>Baseline</title></head>" & _
    "<body><p>Last known good content.</p></body></html>" _
), "baseline document lays out synchronously"
activeTitle = htmlview_GetTitle(htmlWidget)
activeText = htmlview_GetPlainText(htmlWidget)
largeHtml = incremental_BuildDocument( _
    "Cooperative replacement", HTMLVIEW_INCREMENTAL_ROWS _
)

AssertTrue htmlview_BeginSetHtml(htmlWidget, largeHtml), _
    "large replacement is accepted for cooperative parsing"
AssertTrue htmlview_IsLoading(htmlWidget), _
    "accepted replacement enters the loading state"
AssertTrue htmlview_GetLoadProgress(htmlWidget) = 0, _
    "new cooperative load begins at zero percent"
AssertTrue htmlview_GetTitle(htmlWidget) = activeTitle AndAlso _
    htmlview_GetPlainText(htmlWidget) = activeText, _
    "beginning a load leaves the active document untouched"

loadState = htmlview_UpdateLoad(htmlWidget, 1)
AssertTrue loadState = HTMLVIEW_LOAD_LOADING, _
    "one short parsing slice yields before the large document completes"
previousProgress = htmlview_GetLoadProgress(htmlWidget)
Do While htmlview_IsLoading(htmlWidget)
    If htmlview_GetTitle(htmlWidget) <> activeTitle OrElse _
       htmlview_GetPlainText(htmlWidget) <> activeText Then
        activeDocumentStayedStable = 0
    End If
    loadState = htmlview_UpdateLoad(htmlWidget, 1)
    loadProgress = htmlview_GetLoadProgress(htmlWidget)
    If loadState = HTMLVIEW_LOAD_LOADING AndAlso _
       loadProgress < previousProgress Then progressStayedMonotonic = 0
    If loadState = HTMLVIEW_LOAD_LOADING Then previousProgress = loadProgress
    loadStepCount += 1
    If loadStepCount >= HTMLVIEW_INCREMENTAL_MAXIMUM_STEPS Then Exit Do
Loop

AssertTrue loadStepCount < HTMLVIEW_INCREMENTAL_MAXIMUM_STEPS, _
    "cooperative parsing reaches a terminal state"
AssertTrue activeDocumentStayedStable, _
    "last completed content stays visible during every pending slice"
AssertTrue progressStayedMonotonic, _
    "cooperative progress does not move backwards"
AssertTrue htmlview_GetLoadState(htmlWidget) = HTMLVIEW_LOAD_COMPLETE, _
    "successful staged layout enters the complete state"
AssertTrue htmlview_GetLoadProgress(htmlWidget) = 100, _
    "successful staged layout reports one hundred percent"
AssertTrue htmlview_GetTitle(htmlWidget) = "Cooperative replacement", _
    "completed replacement transfers its title atomically"
AssertTrue InStr( _
    htmlview_GetPlainText(htmlWidget), _
    "Cooperative row 6000 remains readable." _
) > 0, "completed replacement transfers all readable content"

test_Section "cancellation preserves active content"
activeTitle = htmlview_GetTitle(htmlWidget)
activeText = htmlview_GetPlainText(htmlWidget)
AssertTrue htmlview_BeginSetHtml( _
    htmlWidget, incremental_BuildDocument( _
        "Cancelled replacement", HTMLVIEW_INCREMENTAL_ROWS _
    ) _
), "cancellable replacement begins"
loadState = htmlview_UpdateLoad(htmlWidget, 1)
AssertTrue loadState = HTMLVIEW_LOAD_LOADING, _
    "cancellable replacement remains pending after one slice"
htmlview_CancelLoad htmlWidget
AssertTrue htmlview_GetLoadState(htmlWidget) = HTMLVIEW_LOAD_CANCELLED AndAlso _
    htmlview_IsLoading(htmlWidget) = 0, _
    "cancellation reaches a non-loading terminal state"
AssertTrue htmlview_GetTitle(htmlWidget) = activeTitle AndAlso _
    htmlview_GetPlainText(htmlWidget) = activeText, _
    "cancellation leaves the last completed document intact"

test_Section "staged failure preserves active content"
malformedHtml = _
    "<html><head><title>Broken replacement</title>" & _
    "<script>if (deviceValue < requestedValue) {" & _
    String(250000, Asc("x"))
AssertTrue htmlview_BeginSetHtml(htmlWidget, malformedHtml), _
    "malformed replacement is accepted for bounded inspection"
loadStepCount = 0
Do While htmlview_IsLoading(htmlWidget)
    htmlview_UpdateLoad htmlWidget, 1
    loadStepCount += 1
    If loadStepCount >= HTMLVIEW_INCREMENTAL_MAXIMUM_STEPS Then Exit Do
Loop
AssertTrue htmlview_GetLoadState(htmlWidget) = HTMLVIEW_LOAD_FAILED, _
    "malformed staged document reports failure"
AssertTrue InStr( _
    htmlview_GetLoadError(htmlWidget), _
    "unterminated HTML SCRIPT element" _
) > 0, "cooperative failure exposes the parser diagnostic"
AssertTrue htmlview_GetTitle(htmlWidget) = activeTitle AndAlso _
    htmlview_GetPlainText(htmlWidget) = activeText, _
    "failed staged document does not replace active content"

test_Section "ordinary GUI update advancement and resize"
AssertTrue htmlview_BeginSetHtml( _
    htmlWidget, incremental_BuildDocument( _
        "GUI update replacement", HTMLVIEW_INCREMENTAL_ROWS \ 2 _
    ) _
), "GUI-managed replacement begins"
gui_UpdateAll
htmlWidget->w += 48
loadStepCount = 0
Do While htmlview_IsLoading(htmlWidget)
    gui_UpdateAll
    loadStepCount += 1
    If loadStepCount >= HTMLVIEW_INCREMENTAL_MAXIMUM_STEPS Then Exit Do
Loop
AssertTrue loadStepCount < HTMLVIEW_INCREMENTAL_MAXIMUM_STEPS AndAlso _
    htmlview_GetLoadState(htmlWidget) = HTMLVIEW_LOAD_COMPLETE, _
    "gui_UpdateAll completes a load that restarts after resize"
AssertTrue htmlview_GetTitle(htmlWidget) = "GUI update replacement", _
    "automatically advanced replacement becomes active"

test_Section "cooperative file loading"
activeTitle = htmlview_GetTitle(htmlWidget)
AssertTrue htmlview_BeginLoadFile( _
    htmlWidget, "tests/assets/htmlview_sample.html" _
), "local HTML file begins cooperative parsing"
AssertTrue htmlview_GetTitle(htmlWidget) = activeTitle, _
    "file loading also retains the active title while pending"
Do While htmlview_IsLoading(htmlWidget)
    gui_UpdateAll
Loop
AssertTrue htmlview_GetLoadState(htmlWidget) = HTMLVIEW_LOAD_COMPLETE AndAlso _
    htmlview_GetTitle(htmlWidget) = "Device & Valve Help", _
    "cooperative file load commits the parsed local document"

viewData = Cast(HtmlViewData Ptr, htmlWidget->data)
AssertTrue viewData->loadContext = 0, _
    "terminal cooperative state releases its staging context"
gui_RemoveWidget "html_incremental"
AssertTrue gui_FindWidget("html_incremental") = 0, _
    "cooperative viewer and owned documents are destroyed"
backend_Exit

test_Summary
End 0

/' end of htmlview_incremental_smoke.bas '/
