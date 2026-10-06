' Project: omaGUI HTML Stress Compatibility Tests
' -----------------------------------------------
'
' File: htmlview_stress_compat.bas
'
' Purpose:
'
'     Verify that the portable HTML viewer remains responsive when it is
'     given large application-shell pages and malformed raw-text elements.
'
' Targets:
'
'     FreeBASIC 1.20.3-1 in FB dialect on 32-bit and 64-bit Windows.  The
'     test is headless and exercises only cross-platform omaGUI interfaces.
'
' Responsibilities:
'
'     - prove that large SCRIPT bodies are skipped without tokenizing them
'     - exclude inline SVG implementation detail from readable page content
'     - reject remote and UNC-style image paths before filesystem access
'     - enforce bounded completion for malformed and captured documents
'
' Module API:
'
'     This is a standalone test program.  Its timing and content helpers are
'     private test support and are not part of the omaGUI public API.
'
' Ownership:
'
'     The GUI manager owns the test widget after gui_AddWidget and releases
'     it through gui_RemoveWidget before the graphics backend is stopped.
'
' This file intentionally does NOT contain:
'
'     - network access, browser emulation, JavaScript, or CSS execution
'     - copies of public website responses
'     - application-specific DD rendering

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"
#include once "tests/test_harness.bi"

Const HTMLVIEW_STRESS_TEST_WIDTH As Integer = 720
Const HTMLVIEW_STRESS_TEST_HEIGHT As Integer = 520
Const HTMLVIEW_STRESS_WALL_LIMIT_SECONDS As Double = 4.0
Const HTMLVIEW_STRESS_SECONDS_PER_DAY As Double = 86400.0


Private Function stress_ElapsedSeconds( _
    ByVal startedAt As Double, ByVal finishedAt As Double _
) As Double
    If finishedAt >= startedAt Then Return finishedAt - startedAt

    /'
        FreeBASIC TIMER wraps at local midnight.  Treat that single wrap as a
        normal clock transition so a test started near midnight stays valid.
    '/
    Return (HTMLVIEW_STRESS_SECONDS_PER_DAY - startedAt) + finishedAt
End Function


Private Function stress_ItemCountIsBounded( _
    ByVal viewData As HtmlViewData Ptr _
) As Integer
    If viewData = 0 Then Return 0
    If viewData->itemCount < 0 Then Return 0
    Return IIf(viewData->itemCount <= HTMLVIEW_MAX_LAYOUT_ITEMS, -1, 0)
End Function


Private Function stress_FindLinkByHref( _
    ByVal viewData As HtmlViewData Ptr, ByVal href As String _
) As HtmlViewItem Ptr
    Dim As HtmlViewItem Ptr item

    If viewData = 0 Then Return 0
    item = viewData->firstItem
    While item <> 0
        If item->itemKind = HTMLVIEW_ITEM_TEXT AndAlso _
           item->href = href Then Return item
        item = item->nextItem
    Wend
    Return 0
End Function


Private Function stress_CountOccurrences( _
    ByVal sourceText As String, ByVal searchText As String _
) As Integer
    Dim As Integer occurrenceCount
    Dim As Long searchPosition = 1
    Dim As Long foundPosition

    If Len(searchText) = 0 Then Return 0
    Do
        foundPosition = InStr(searchPosition, sourceText, searchText)
        If foundPosition = 0 Then Exit Do
        occurrenceCount += 1
        searchPosition = foundPosition + Len(searchText)
    Loop
    Return occurrenceCount
End Function


Dim As Widget Ptr htmlWidget
Dim As HtmlViewData Ptr viewData
Dim As String stressHtml
Dim As String malformedHtml
Dim As String framesetHtml
Dim As String applicationHtml
Dim As String plainText
Dim As String pagePath
Dim As String diagnostic
Dim As Double startedAt
Dim As Double elapsedSeconds
Dim As Integer pageArgument
Dim As Integer layoutResult

backend_Init HTMLVIEW_STRESS_TEST_WIDTH, HTMLVIEW_STRESS_TEST_HEIGHT, 1
gui_Init
input_ResetForTest

htmlWidget = htmlview_Create("html_stress", 10, 10, 540, 420)
AssertTrue htmlWidget <> 0, "HTML stress viewer creates"
If htmlWidget = 0 Then
    backend_Exit
    test_Summary
    End 1
End If
gui_AddWidget htmlWidget

test_Section "large application shell"
stressHtml = _
    "<!doctype html><html><head><script>" & _
    String(600000, Asc("x")) & _
    "if(a<p$.length&&(n=p[i]));</script>" & _
    "<title>Stress Title</title><style>body>main{display:block}</style>" & _
    "</head><body><svg><title>Wrong embedded title</title>" & _
    "<path d='M0 0 L20 20'></path></svg>" & _
    "<img src='//remote.invalid/picture.webp' alt='Remote image'>" & _
    "<main><h1>Static fallback</h1><p>The document remains readable.</p>" & _
    "</main></body></html>"

startedAt = Timer
layoutResult = htmlview_SetHtml(htmlWidget, stressHtml)
elapsedSeconds = stress_ElapsedSeconds(startedAt, Timer)
viewData = Cast(HtmlViewData Ptr, htmlWidget->data)
plainText = htmlview_GetPlainText(htmlWidget)

AssertTrue layoutResult, "large raw-text document lays out"
AssertTrue elapsedSeconds <= HTMLVIEW_STRESS_WALL_LIMIT_SECONDS, _
    "large raw-text document completes within the wall-clock limit"
AssertTrue htmlview_GetTitle(htmlWidget) = "Stress Title", _
    "only the document TITLE supplies the window title"
AssertTrue InStr(plainText, "Static fallback") > 0 AndAlso _
    InStr(plainText, "The document remains readable.") > 0, _
    "static fallback content remains readable"
AssertTrue InStr(plainText, "if(a<p$.length") = 0 AndAlso _
    InStr(plainText, "Wrong embedded title") = 0, _
    "SCRIPT and inline SVG implementation detail stays hidden"
AssertTrue InStr(plainText, "[Remote image]") > 0, _
    "protocol-relative image uses ALT without a network-share lookup"
AssertTrue Len(htmlview_GetLastError(htmlWidget)) = 0 AndAlso _
    viewData->layoutIncomplete = 0, _
    "large raw-text layout completes without a diagnostic"
AssertTrue stress_ItemCountIsBounded(viewData), _
    "large application shell respects the public item limit"
Print "  Synthetic layout seconds: "; elapsedSeconds

test_Section "malformed raw-text element"
malformedHtml = _
    "<!doctype html><html><head><title>Broken page</title>" & _
    "<script>if (deviceValue < requestedValue) {" & _
    String(600000, Asc("y"))

startedAt = Timer
layoutResult = htmlview_SetHtml(htmlWidget, malformedHtml)
elapsedSeconds = stress_ElapsedSeconds(startedAt, Timer)
viewData = Cast(HtmlViewData Ptr, htmlWidget->data)
diagnostic = htmlview_GetLastError(htmlWidget)

AssertTrue layoutResult = 0, _
    "unterminated SCRIPT is reported as an incomplete document"
AssertTrue elapsedSeconds <= HTMLVIEW_STRESS_WALL_LIMIT_SECONDS, _
    "unterminated SCRIPT completes within the wall-clock limit"
AssertTrue viewData->layoutIncomplete <> 0 AndAlso _
    InStr(diagnostic, "unterminated HTML SCRIPT element") > 0, _
    "unterminated raw-text diagnostic identifies the failed element"
AssertTrue stress_ItemCountIsBounded(viewData), _
    "malformed application shell respects the public item limit"
Print "  Malformed layout seconds: "; elapsedSeconds
Print "  Diagnostic: "; diagnostic

test_Section "legacy frameset fallback"
framesetHtml = _
    "<html><head><title>Archived issue</title></head>" & _
    "<frameset cols='90,*'><frame src='contents.html' name='index'>" & _
    "<frame src='title.html' name='main'>" & _
    "<frame src='contents.html' name='index'></frameset></html>"

AssertTrue htmlview_SetHtml(htmlWidget, framesetHtml), _
    "legacy FRAMESET document lays out"
viewData = Cast(HtmlViewData Ptr, htmlWidget->data)
plainText = htmlview_GetPlainText(htmlWidget)
AssertTrue InStr(plainText, "Contents") > 0 AndAlso _
    InStr(plainText, "Main page") > 0, _
    "legacy FRAME names become readable navigation labels"
AssertTrue stress_FindLinkByHref(viewData, "contents.html") <> 0 AndAlso _
    stress_FindLinkByHref(viewData, "title.html") <> 0, _
    "legacy FRAME sources remain application-routed links"
AssertTrue stress_CountOccurrences(plainText, "Contents") = 1 AndAlso _
    stress_CountOccurrences(plainText, "Main page") = 1, _
    "duplicate FRAME sources do not create duplicate navigation"

test_Section "script-only application fallback"
applicationHtml = _
    "<!doctype html><html><head><title>Canvas application</title>" & _
    "<script type='module' src='application.js'></script></head>" & _
    "<body><div id='root'></div><canvas id='canvas'></canvas></body></html>"

AssertTrue htmlview_SetHtml(htmlWidget, applicationHtml), _
    "script-only application shell completes layout"
viewData = Cast(HtmlViewData Ptr, htmlWidget->data)
plainText = htmlview_GetPlainText(htmlWidget)
AssertTrue htmlview_GetTitle(htmlWidget) = "Canvas application", _
    "script-only application retains its document title"
AssertTrue plainText = _
    "Interactive page content requires a full browser.", _
    "script-only application explains the capability boundary"
AssertTrue viewData->layoutIncomplete = 0 AndAlso _
    Len(htmlview_GetLastError(htmlWidget)) = 0, _
    "script-only fallback is a successful bounded layout"

For pageArgument = 1 To 2
    pagePath = Command(pageArgument)
    If Len(pagePath) = 0 Then Continue For

    test_Section "optional captured application page"
    startedAt = Timer
    layoutResult = htmlview_LoadFile(htmlWidget, pagePath)
    elapsedSeconds = stress_ElapsedSeconds(startedAt, Timer)
    viewData = Cast(HtmlViewData Ptr, htmlWidget->data)
    plainText = htmlview_GetPlainText(htmlWidget)
    diagnostic = htmlview_GetLastError(htmlWidget)

    AssertTrue elapsedSeconds <= HTMLVIEW_STRESS_WALL_LIMIT_SECONDS, _
        "captured application page completes within the wall-clock limit"
    AssertTrue layoutResult OrElse Len(diagnostic) > 0, _
        "captured application page succeeds or returns a diagnostic"
    AssertTrue stress_ItemCountIsBounded(viewData), _
        "captured application page respects the public item limit"

    If layoutResult Then
        AssertTrue Len(htmlview_GetTitle(htmlWidget)) > 0, _
            "captured application page retains a document title"
        AssertTrue Len(plainText) > 20, _
            "captured application page exposes a static text fallback"
        AssertTrue viewData->layoutIncomplete = 0 AndAlso _
            Len(diagnostic) = 0, _
            "successful captured layout has no hidden failure"
        AssertTrue InStr(plainText, "ytcfg.set") = 0 AndAlso _
            InStr(plainText, "client-env") = 0, _
            "captured application code is not exposed as page text"
    End If

    Print "  Captured title: "; htmlview_GetTitle(htmlWidget)
    Print "  Plain-text bytes: "; Len(plainText)
    Print "  Layout items: "; viewData->itemCount
    Print "  Layout seconds: "; elapsedSeconds
    If Len(diagnostic) > 0 Then Print "  Diagnostic: "; diagnostic
Next pageArgument

gui_RemoveWidget "html_stress"
AssertTrue gui_FindWidget("html_stress") = 0, _
    "HTML stress widget and owned state are released"
backend_Exit

test_Summary
End 0

/' end of htmlview_stress_compat.bas '/
