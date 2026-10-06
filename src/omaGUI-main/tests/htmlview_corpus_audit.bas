' Project: omaGUI HTML Corpus Audit
' ---------------------------------
'
' File: htmlview_corpus_audit.bas
'
' Purpose:
'
'     Load every local HTML capture named in a line-oriented corpus list and
'     report whether each document produces a bounded readable layout.
'
' Targets:
'
'     FreeBASIC 1.20.3-1 in FB dialect on 32-bit and 64-bit Windows.  The test
'     is headless and uses only cross-platform omaGUI and FreeBASIC APIs.
'
' Responsibilities:
'
'     - exercise a large page corpus through the public file-loading API
'     - identify load failures, incomplete layouts, and empty fallbacks
'     - enforce item-count and wall-clock bounds for every captured page
'     - print enough per-page evidence to locate a compatibility failure
'
' Module API:
'
'     This is a standalone test program.  Its first command-line argument is
'     a text file containing one local HTML path per line.
'
' Ownership:
'
'     The GUI manager owns the audit widget after gui_AddWidget and releases
'     it through gui_RemoveWidget before the graphics backend is stopped.
'
' This file intentionally does NOT contain:
'
'     - network access, crawling, JavaScript, or CSS execution
'     - copies of third-party HTML documents
'     - application-specific DD rendering

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"
#include once "tests/test_harness.bi"

Const HTMLVIEW_CORPUS_TEST_WIDTH As Integer = 720
Const HTMLVIEW_CORPUS_TEST_HEIGHT As Integer = 520
Const HTMLVIEW_CORPUS_WALL_LIMIT_SECONDS As Double = 4.0
Const HTMLVIEW_CORPUS_SECONDS_PER_DAY As Double = 86400.0


Private Function corpus_ElapsedSeconds( _
    ByVal startedAt As Double, ByVal finishedAt As Double _
) As Double
    If finishedAt >= startedAt Then Return finishedAt - startedAt

    /'
        FreeBASIC TIMER wraps at local midnight.  Account for one wrap so a
        long corpus started near midnight does not report a negative duration.
    '/
    Return (HTMLVIEW_CORPUS_SECONDS_PER_DAY - startedAt) + finishedAt
End Function


Dim As Widget Ptr htmlWidget
Dim As HtmlViewData Ptr viewData
Dim As String listPath
Dim As String pagePath
Dim As String plainText
Dim As String diagnostic
Dim As Integer listFile
Dim As Integer ioResult
Dim As Integer loadResult
Dim As Integer totalPages
Dim As Integer loadFailures
Dim As Integer incompleteLayouts
Dim As Integer emptyLayouts
Dim As Integer itemLimitFailures
Dim As Integer slowLayouts
Dim As Integer reportedItemCount
Dim As Double startedAt
Dim As Double elapsedSeconds
Dim As Double maximumElapsedSeconds

listPath = Command(1)
If Len(listPath) = 0 Then
    Print "usage: htmlview_corpus_audit <page-list.txt>"
    End 2
End If

listFile = FreeFile
ioResult = Open(listPath For Input Access Read As #listFile)
If ioResult <> 0 Then
    Print "cannot open HTML corpus list: "; listPath
    End 2
End If

backend_Init HTMLVIEW_CORPUS_TEST_WIDTH, HTMLVIEW_CORPUS_TEST_HEIGHT, 1
gui_Init
input_ResetForTest

htmlWidget = htmlview_Create("html_corpus", 10, 10, 540, 420)
AssertTrue htmlWidget <> 0, "HTML corpus viewer creates"
If htmlWidget = 0 Then
    Close #listFile
    backend_Exit
    test_Summary
    End 1
End If
gui_AddWidget htmlWidget

test_Section "captured page corpus"
While Not Eof(listFile)
    Line Input #listFile, pagePath
    pagePath = Trim(pagePath)
    If Len(pagePath) = 0 OrElse Left(pagePath, 1) = "#" Then Continue While

    totalPages += 1
    startedAt = Timer
    loadResult = htmlview_LoadFile(htmlWidget, pagePath)
    elapsedSeconds = corpus_ElapsedSeconds(startedAt, Timer)
    If elapsedSeconds > maximumElapsedSeconds Then
        maximumElapsedSeconds = elapsedSeconds
    End If

    viewData = Cast(HtmlViewData Ptr, htmlWidget->data)
    plainText = htmlview_GetPlainText(htmlWidget)
    diagnostic = htmlview_GetLastError(htmlWidget)
    reportedItemCount = -1
    If viewData <> 0 Then reportedItemCount = viewData->itemCount

    If loadResult = 0 Then loadFailures += 1
    If viewData = 0 OrElse viewData->layoutIncomplete <> 0 OrElse _
       Len(diagnostic) > 0 Then incompleteLayouts += 1
    If Len(Trim(plainText)) = 0 Then emptyLayouts += 1
    If viewData = 0 OrElse viewData->itemCount < 0 OrElse _
       viewData->itemCount > HTMLVIEW_MAX_LAYOUT_ITEMS Then
        itemLimitFailures += 1
    End If
    If elapsedSeconds > HTMLVIEW_CORPUS_WALL_LIMIT_SECONDS Then slowLayouts += 1

    If loadResult = 0 OrElse Len(Trim(plainText)) = 0 OrElse _
       Len(diagnostic) > 0 OrElse _
       elapsedSeconds > HTMLVIEW_CORPUS_WALL_LIMIT_SECONDS Then
        Print "  FAIL "; pagePath
        Print "       title="; htmlview_GetTitle(htmlWidget)
        Print "       text bytes="; Len(plainText); _
            " items="; reportedItemCount; _
            " seconds="; elapsedSeconds
        If Len(diagnostic) > 0 Then Print "       diagnostic="; diagnostic
    Else
        Print "  OK   "; pagePath; " text="; Len(plainText); _
            " items="; viewData->itemCount; " seconds="; elapsedSeconds
    End If
Wend
Close #listFile

Print
Print "  Corpus pages: "; totalPages
Print "  Maximum seconds: "; maximumElapsedSeconds
AssertTrue totalPages > 0, "corpus list contains at least one page"
AssertTrue loadFailures = 0, "every captured page loads"
AssertTrue incompleteLayouts = 0, "every captured page completes layout"
AssertTrue emptyLayouts = 0, "every captured page has a readable fallback"
AssertTrue itemLimitFailures = 0, "every captured page respects the item limit"
AssertTrue slowLayouts = 0, "every captured page respects the wall-clock limit"

gui_RemoveWidget "html_corpus"
AssertTrue gui_FindWidget("html_corpus") = 0, _
    "HTML corpus widget and owned state are released"
backend_Exit

test_Summary
End 0

/' end of htmlview_corpus_audit.bas '/
