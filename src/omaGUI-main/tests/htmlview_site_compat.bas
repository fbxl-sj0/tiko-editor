' Project: omaGUI HTML Site Compatibility Tests
' ------------------------------------------------
'
' File: htmlview_site_compat.bas
'
' Purpose:
'
'     Verify content-first rendering for the structural HTML patterns used
'     by the FBXL and FBXL Lotide landing pages.
'
' Targets:
'
'     FreeBASIC 1.20.3-1 in FB dialect on 32-bit and 64-bit Windows.  The test
'     is headless and uses only cross-platform omaGUI interfaces.
'
' Responsibilities:
'
'     - cover legacy HTML 4 tables, FONT, BIG, and Latin-1 text
'     - cover HTML 5 semantic containers, navigation, and disclosure tags
'     - verify decorative image ALT handling and readable text fallback
'     - verify links, Unicode punctuation, reflow, and ignored templates
'
' Module API:
'
'     This is a standalone test program.  Its helper functions are local test
'     queries and are not part of the omaGUI public API.
'
' Ownership:
'
'     The GUI manager owns the test widget after gui_AddWidget and releases
'     it through gui_RemoveWidget before the graphics backend is stopped.
'
' This file intentionally does NOT contain:
'
'     - network access or copies of either live page
'     - CSS layout or JavaScript behavior
'     - application-specific DD rendering

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"
#include once "tests/test_harness.bi"

Const HTMLVIEW_SITE_TEST_WIDTH As Integer = 720
Const HTMLVIEW_SITE_TEST_HEIGHT As Integer = 520


Function siteCompat_FindTextItem( _
    ByVal viewData As HtmlViewData Ptr, ByVal textPart As String _
) As HtmlViewItem Ptr
    Dim As HtmlViewItem Ptr item

    If viewData = 0 Then Return 0
    item = viewData->firstItem
    While item <> 0
        If item->itemKind = HTMLVIEW_ITEM_TEXT AndAlso _
           InStr(item->text, textPart) > 0 Then Return item
        item = item->nextItem
    Wend
    Return 0
End Function


Function siteCompat_FindLinkItem( _
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


Dim As Widget Ptr htmlWidget
Dim As HtmlViewData Ptr viewData
Dim As HtmlViewItem Ptr item
Dim As HtmlViewItem Ptr comparisonItem
Dim As String legacyHtml
Dim As String modernHtml
Dim As String classicHtml
Dim As String plainText
Dim As Integer wideHeight
Dim As Integer pageArgument
Dim As String pagePath

backend_Init HTMLVIEW_SITE_TEST_WIDTH, HTMLVIEW_SITE_TEST_HEIGHT, 1
gui_Init
input_ResetForTest

htmlWidget = htmlview_Create("site_compat", 10, 10, 540, 420)
AssertTrue htmlWidget <> 0, "site compatibility viewer creates"
If htmlWidget = 0 Then
    backend_Exit
    test_Summary
    End 1
End If
gui_AddWidget htmlWidget

test_Section "legacy FBXL landing-page structure"
legacyHtml = _
    "<!DOCTYPE html PUBLIC '-//W3C//DTD HTML 4.01 Transitional//EN'>" & _
    "<html><head><meta http-equiv='content-type' " & _
    "content='text/html; charset=ISO-8859-1'>" & _
    "<title>FreeBASIC Accelerator Magazine</title></head>" & _
    "<body><table border='0' cellpadding='0' cellspacing='0' " & _
    "style='width: 100%; height: 100%'><tbody><tr>" & _
    "<td rowspan='2'><table border='0'><tbody><tr><td>" & _
    "<img src='graphics/decorative.png' alt=''>" & _
    "<font size='+2'><a href='issue1/'>Issue 1</a><br>" & _
    "<a href='issue2/'>Issue 2</a></font>" & _
    "</td></tr></tbody></table></td>" & _
    "<td><h1><big><font size='+3'>FreeBASIC XL Magazine</font>" & _
    "</big></h1></td></tr>" & _
    "<tr><td><a href='https://lotide.fbxl.net/communities/6'>" & _
    "Message Board</a><br><b>News</b><br>" & _
    "Caf" & Chr(233) & " archive &hellip;</td></tr>" & _
    "</tbody></table><template>Hidden template payload</template>" & _
    "</body></html>"

AssertTrue htmlview_SetHtml(htmlWidget, legacyHtml), _
    "legacy transitional document lays out"
viewData = Cast(HtmlViewData Ptr, htmlWidget->data)
plainText = htmlview_GetPlainText(htmlWidget)
AssertTrue htmlview_GetTitle(htmlWidget) = _
    "FreeBASIC Accelerator Magazine", "legacy TITLE is retained"
AssertTrue InStr(plainText, "Issue 1") > 0 AndAlso _
    InStr(plainText, "Issue 2") > 0 AndAlso _
    InStr(plainText, "FreeBASIC XL Magazine") > 0 AndAlso _
    InStr(plainText, "Message Board") > 0 AndAlso _
    InStr(plainText, "News") > 0, _
    "legacy nested-table content remains readable"
AssertTrue InStr(plainText, "Cafe archive ...") > 0, _
    "declared Latin-1 bytes and common entities use readable ASCII"
AssertTrue InStr(plainText, "[Image]") = 0, _
    "empty ALT images remain decorative when unavailable"
AssertTrue InStr(plainText, "Hidden template payload") = 0, _
    "TEMPLATE content is not displayed"
item = siteCompat_FindTextItem(viewData, "FreeBASIC")
AssertTrue item <> 0 AndAlso item->scaleX = 2 AndAlso item->scaleY = 2, _
    "legacy BIG and FONT size produce one bounded larger style"
AssertTrue item <> 0 AndAlso item->x < 100, _
    "legacy presentation tables do not squeeze the article into a column"
item = siteCompat_FindLinkItem(viewData, "issue1/")
AssertTrue item <> 0, _
    "relative legacy links remain navigable"

test_Section "early-WWW optional tags and presentation images"
classicHtml = _
    "<header><title>Early Web</title><nextid n='12'></header><body>" & _
    "<h1>Project Index</h1><dl compact>" & _
    "<dt><a href='first.html'>First topic</a>" & _
    "<dd>First explanation" & _
    "<dt><a href='second.html'>Second topic</a>" & _
    "<dd>Second explanation</dl>" & _
    "<img src='spacer.gif' width='14' height='1'>" & _
    "<img src='refresh.gif' width='16' height='16' title='Refresh'>" & _
    "<img src='photograph.jpg' width='320' height='200'>" & _
    "<center><table border='0'><tr><td>1.</td>" & _
    "<td><div title='vote'></div></td><td>" & _
    "<a href='compact.html'>Compact story</a></td></tr></table></center>" & _
    "<div><a href='adjacent-a.html'>First label</a><span></span>" & _
    "<a href='adjacent-b.html'>Second label</a></div>" & _
    "</body>"

AssertTrue htmlview_SetHtml(htmlWidget, classicHtml), _
    "early-WWW document lays out"
viewData = Cast(HtmlViewData Ptr, htmlWidget->data)
plainText = htmlview_GetPlainText(htmlWidget)
AssertTrue htmlview_GetTitle(htmlWidget) = "Early Web", _
    "TITLE inside the historical HEADER element is retained"
AssertTrue InStr(plainText, "First topic") > 0 AndAlso _
    InStr(plainText, "First explanation") > 0 AndAlso _
    InStr(plainText, "Second topic") > 0 AndAlso _
    InStr(plainText, "Second explanation") > 0, _
    "definition terms with optional end tags remain readable"
item = siteCompat_FindLinkItem(viewData, "first.html")
comparisonItem = siteCompat_FindLinkItem(viewData, "second.html")
AssertTrue item <> 0 AndAlso comparisonItem <> 0 AndAlso _
    item->x = comparisonItem->x, _
    "implicit DT and DD closure resets term indentation"
AssertTrue InStr(plainText, "[Image]") > 0 AndAlso _
    InStr(plainText, "[Refresh]") > 0, _
    "large unknown images and titled controls retain useful fallbacks"
AssertTrue InStr(plainText, "spacer") = 0, _
    "untitled small presentation images remain silent"
item = siteCompat_FindTextItem(viewData, "1.")
comparisonItem = siteCompat_FindLinkItem(viewData, "compact.html")
AssertTrue item <> 0 AndAlso comparisonItem <> 0 AndAlso _
    item->y = comparisonItem->y AndAlso item->x < HTMLVIEW_LIST_INDENT, _
    "presentation-table cells share a compact left-aligned row"
AssertTrue InStr(plainText, "First label Second label") > 0, _
    "adjacent linked labels remain separate without CSS"

test_Section "FBXL Lotide HTML 5 structure"
modernHtml = _
    "<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'>" & _
    "<link href='/static/main.css' rel='stylesheet'>" & _
    "<title>FBXL Lotide</title></head><body>" & _
    "<header><nav aria-label='Main Navigation'>" & _
    "<details><summary><img src='/static/menu.svg' alt='Open Menu'>" & _
    "</summary><div><a href='/all'>All</a><a href='/local'>Local</a>" & _
    "<a href='/communities'>Communities</a><a href='/sources'>Feeds</a>" & _
    "<a href='/about'>About</a></div></details>" & _
    "<a class='siteName' href='/'><img src='https://example.invalid/logo' " & _
    "alt=''>FBXL Lotide</a><a href='/login'>Login</a>" & _
    "<img src='//remote.invalid/status.svg' alt='Remote status'>" & _
    "</nav></header><main><h1>The Whole Known Network</h1><ul><li>" & _
    "<div class='titleLine'><a href='/posts/1'>A compatible post</a>" & _
    "<em><a href='https://example.org/'>example.org &#x2197;</a></em></div>" & _
    "<small>Submitted &#x2068;21&#x2069; minutes ago by " & _
    "<a href='/users/1'>reader@example.org</a> | " & _
    "<a href='/posts/1'>0 comments</a></small></li></ul>" & _
    "<article><p>It&rsquo;s readable &mdash; even without CSS.</p></article>" & _
    "<template>Client-only duplicate</template></main></body></html>"

AssertTrue htmlview_SetHtml(htmlWidget, modernHtml), _
    "modern semantic document lays out"
viewData = Cast(HtmlViewData Ptr, htmlWidget->data)
plainText = htmlview_GetPlainText(htmlWidget)
AssertTrue htmlview_GetTitle(htmlWidget) = "FBXL Lotide", _
    "modern TITLE is retained"
AssertTrue InStr(plainText, "[Open Menu]") > 0 AndAlso _
    InStr(plainText, "[Remote status]") > 0 AndAlso _
    InStr(plainText, "[Image]") = 0, _
    "meaningful image ALT is shown without decorative-image noise"
AssertTrue InStr(plainText, "All" & Chr(10) & "Local") > 0 AndAlso _
    InStr(plainText, "Local" & Chr(10) & "Communities") > 0, _
    "CSS-spaced navigation links remain separate without CSS"
AssertTrue InStr(plainText, "A compatible post example.org ->") > 0, _
    "adjacent emphasized source links retain readable separation"
AssertTrue InStr(plainText, "Submitted 21 minutes ago") > 0, _
    "Unicode directional isolates do not hide or corrupt metadata"
AssertTrue InStr(plainText, "It's readable - even without CSS.") > 0, _
    "common Unicode punctuation is reduced to embedded-font glyphs"
AssertTrue InStr(plainText, "Client-only duplicate") = 0, _
    "modern TEMPLATE content is ignored"
item = siteCompat_FindTextItem(viewData, "compatible")
AssertTrue item <> 0 AndAlso item->href = "/posts/1", _
    "relative modern links remain navigable"
AssertTrue Len(htmlview_GetLastError(htmlWidget)) = 0, _
    "site-compatible layout completes without a diagnostic"

wideHeight = htmlview_GetContentHeight(htmlWidget)
htmlWidget->w = 260
AssertTrue htmlview_Reflow(htmlWidget), _
    "site-compatible content reflows in a narrow viewer"
AssertTrue htmlview_GetContentHeight(htmlWidget) >= wideHeight, _
    "narrow site layout retains all wrapped content"

For pageArgument = 1 To 8
    pagePath = Command(pageArgument)
    If Len(pagePath) = 0 Then Continue For
    test_Section "optional captured live-page response"
    htmlWidget->w = 540
    AssertTrue htmlview_LoadFile(htmlWidget, pagePath), _
        "captured response lays out through the public file API"
    viewData = Cast(HtmlViewData Ptr, htmlWidget->data)
    plainText = htmlview_GetPlainText(htmlWidget)
    AssertTrue Len(htmlview_GetTitle(htmlWidget)) > 0 AndAlso _
        Len(plainText) > 500, _
        "captured response retains its title and substantial content"
    AssertTrue InStr(plainText, "AllLocalCommunities") = 0 AndAlso _
        InStr(plainText, "Hacker Newsnew") = 0, _
        "captured navigation labels are not run together"
    AssertTrue InStr(plainText, "[Image]") = 0, _
        "captured decorative images do not create generic placeholders"
    AssertTrue Len(htmlview_GetLastError(htmlWidget)) = 0 AndAlso _
        viewData->layoutIncomplete = 0, _
        "captured response completes within public layout limits"
    Print "  Captured title: "; htmlview_GetTitle(htmlWidget)
    Print "  Plain-text bytes: "; Len(plainText)
Next pageArgument

gui_RemoveWidget "site_compat"
AssertTrue gui_FindWidget("site_compat") = 0, _
    "site compatibility widget and owned state are released"
backend_Exit

test_Summary
End 0

/' end of htmlview_site_compat.bas '/
