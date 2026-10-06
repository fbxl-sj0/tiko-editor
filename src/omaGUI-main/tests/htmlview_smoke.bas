/'
    Project: omaGUI HTML Viewer Tests
    ---------------------------------

    File: htmlview_smoke.bas

    Purpose:

        Verify the portable HTML viewer parser, layout, input, and lifecycle.

    Responsibilities:

        - load a representative HTML file through the public API
        - verify supported markup, entities, safety limits, and reflow
        - exercise link callbacks, polling, wheel, key, and scrollbar input
        - verify application-provided image schemes and ownership transfer
        - render and destroy the widget through the ordinary GUI manager

    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:

        - network access or external link launching
        - visual screenshot comparisons
        - DD-reader-specific behavior
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"
#include once "tests/test_harness.bi"

Const HTMLVIEW_SMOKE_WIDTH As Integer = 640
Const HTMLVIEW_SMOKE_HEIGHT As Integer = 480

Dim Shared As Integer htmlviewSmokeCallbackCount
Dim Shared As Integer htmlviewSmokeContextCount
Dim Shared As String htmlviewSmokeCallbackHref
Dim Shared As Integer htmlviewSmokeImageCount


Sub htmlviewSmoke_LinkHandler( _
    ByVal htmlWidget As Widget Ptr, _
    ByVal href As String, _
    ByVal context As Any Ptr _
)
    If htmlWidget = 0 Then Exit Sub
    htmlviewSmokeCallbackCount += 1
    htmlviewSmokeCallbackHref = href
    If context <> 0 Then *Cast(Integer Ptr, context) += 1
End Sub


Function htmlviewSmoke_ImageHandler( _
    ByVal source As String, _
    ByVal context As Any Ptr, _
    ByRef loadedImage As RasterImage Ptr, _
    ByRef errorMessage As String _
) As Integer
    loadedImage = 0
    errorMessage = ""
    If source <> "memory:test-image" Then Return 0
    htmlviewSmokeImageCount += 1
    Return rasterimage_LoadFile( _
        "assets/fonts/font_arial_10_regular.bmp", loadedImage, errorMessage _
    )
End Function


Function htmlviewSmoke_FindTextItem( _
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


Function htmlviewSmoke_FindLinkItem( _
    ByVal viewData As HtmlViewData Ptr _
) As HtmlViewItem Ptr
    Dim As HtmlViewItem Ptr item

    If viewData = 0 Then Return 0
    item = viewData->firstItem
    While item <> 0
        If item->itemKind = HTMLVIEW_ITEM_TEXT AndAlso Len(item->href) > 0 Then
            Return item
        End If
        item = item->nextItem
    Wend
    Return 0
End Function


Function htmlviewSmoke_FindRule( _
    ByVal viewData As HtmlViewData Ptr _
) As HtmlViewItem Ptr
    Dim As HtmlViewItem Ptr item

    If viewData = 0 Then Return 0
    item = viewData->firstItem
    While item <> 0
        If item->itemKind = HTMLVIEW_ITEM_RULE Then Return item
        item = item->nextItem
    Wend
    Return 0
End Function


Function htmlviewSmoke_FindLinkByHref( _
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


Function htmlviewSmoke_TableBox( _
    ByVal viewData As HtmlViewData Ptr, ByVal requestedIndex As Integer _
) As HtmlViewItem Ptr
    Dim As HtmlViewItem Ptr item
    Dim As Integer boxIndex

    If viewData = 0 OrElse requestedIndex < 0 Then Return 0
    item = viewData->firstItem
    While item <> 0
        If item->itemKind = HTMLVIEW_ITEM_BOX Then
            If boxIndex = requestedIndex Then Return item
            boxIndex += 1
        End If
        item = item->nextItem
    Wend
    Return 0
End Function


Sub htmlviewSmoke_Click(ByVal x As Integer, ByVal y As Integer)
    input_MockMouse x, y, 1
    gui_UpdateAll
    input_MockMouse x, y, 0
    gui_UpdateAll
End Sub


Dim As Widget Ptr htmlWidget
Dim As HtmlViewData Ptr viewData
Dim As HtmlViewItem Ptr item
Dim As Integer wideHeight
Dim As Integer scrollBefore
Dim As Integer maximumScroll
Dim As Integer clickX
Dim As Integer clickY
Dim As String href
Dim As String previousTitle
Dim As String oversizedHtml
Dim As String nestedHtml

backend_Init HTMLVIEW_SMOKE_WIDTH, HTMLVIEW_SMOKE_HEIGHT, 1
gui_Init
input_ResetForTest

htmlWidget = htmlview_Create("html_smoke", 20, 20, 360, 150)
AssertTrue htmlWidget <> 0, "HTML viewer constructor returns a widget"
If htmlWidget = 0 Then
    backend_Exit
    test_Summary
    End 1
End If

gui_AddWidget htmlWidget
gui_UpdateAll
viewData = Cast(HtmlViewData Ptr, htmlWidget->data)

test_Section "file loading and supported markup"
AssertTrue htmlview_LoadFile( _
    htmlWidget, "tests/assets/htmlview_sample.html" _
), "representative HTML file loads"
AssertTrue htmlview_GetTitle(htmlWidget) = "Device & Valve Help", _
    "TITLE text and entities are decoded"
AssertTrue InStr(htmlview_GetPlainText(htmlWidget), "A & B") > 0, _
    "text entities are decoded"
AssertTrue InStr( _
    htmlview_GetPlainText(htmlWidget), "script text must not be displayed" _
) = 0, "SCRIPT content is not displayed"
AssertTrue InStr(htmlview_GetPlainText(htmlWidget), ".hidden") = 0, _
    "STYLE content is not displayed"
AssertTrue InStr( _
    htmlview_GetPlainText(htmlWidget), "[Valve &amp;" _
) > 0 AndAlso InStr( _
    htmlview_GetPlainText(htmlWidget), "actuator]" _
) > 0, "image ALT text is decoded exactly once"
AssertTrue InStr( _
    htmlview_GetPlainText(htmlWidget), "[Decoded local font atlas]" _
) > 0, "decoded local image contributes accessible ALT text"
AssertTrue InStr(htmlview_GetPlainText(htmlWidget), "Name") > 0 AndAlso _
    InStr(htmlview_GetPlainText(htmlWidget), "Value") > 0, _
    "table cell text is retained"
AssertTrue InStr( _
    htmlview_GetPlainText(htmlWidget), "Name" & Chr(9) & "Value" _
) > 0 AndAlso InStr( _
    htmlview_GetPlainText(htmlWidget), "Position" & Chr(9) & "52 percent" _
) > 0, "table plain text uses tab-separated cells and line-separated rows"
AssertTrue htmlviewSmoke_TableBox(viewData, 0) <> 0 AndAlso _
    htmlviewSmoke_TableBox(viewData, 1) <> 0 AndAlso _
    htmlviewSmoke_TableBox(viewData, 2) <> 0 AndAlso _
    htmlviewSmoke_TableBox(viewData, 3) <> 0, _
    "two table rows produce four bordered cell backgrounds"
If htmlviewSmoke_TableBox(viewData, 0) <> 0 AndAlso _
   htmlviewSmoke_TableBox(viewData, 1) <> 0 AndAlso _
   htmlviewSmoke_TableBox(viewData, 2) <> 0 AndAlso _
   htmlviewSmoke_TableBox(viewData, 3) <> 0 Then
    AssertTrue htmlviewSmoke_TableBox(viewData, 0)->y = _
        htmlviewSmoke_TableBox(viewData, 1)->y AndAlso _
        htmlviewSmoke_TableBox(viewData, 0)->h = _
        htmlviewSmoke_TableBox(viewData, 1)->h AndAlso _
        htmlviewSmoke_TableBox(viewData, 2)->y = _
        htmlviewSmoke_TableBox(viewData, 3)->y AndAlso _
        htmlviewSmoke_TableBox(viewData, 2)->h = _
        htmlviewSmoke_TableBox(viewData, 3)->h, _
        "cells in each table row share one top and one computed height"
    AssertTrue htmlviewSmoke_TableBox(viewData, 0)->x = _
        htmlviewSmoke_TableBox(viewData, 2)->x AndAlso _
        htmlviewSmoke_TableBox(viewData, 1)->x = _
        htmlviewSmoke_TableBox(viewData, 3)->x, _
        "table columns remain aligned between rows"
End If
AssertTrue htmlviewSmoke_FindLinkByHref( _
    viewData, "dd:item/table-position" _
) <> 0, "a link inside a table cell remains interactive"
AssertTrue InStr(htmlview_GetPlainText(htmlWidget), "command  42") > 0, _
    "preformatted spacing is retained"
AssertTrue viewData->documentBackgroundColor = RGB(248, 248, 244), _
    "BODY background color is applied"
AssertTrue viewData->documentTextColor = RGB(32, 36, 40), _
    "BODY text color is applied"
AssertTrue viewData->documentLinkColor = RGB(22, 76, 156), _
    "BODY link color is applied"

item = htmlviewSmoke_FindTextItem(viewData, "Wireless")
AssertTrue item <> 0, "heading text produces a layout item"
If item <> 0 Then
    AssertTrue item->fontId = BACKEND_FONT_LIBERATION_SERIF_18_REGULAR AndAlso _
        item->scaleX = 1 AndAlso item->scaleY = 1, _
        "H1 uses the large bold embedded font"
End If

item = htmlviewSmoke_FindTextItem(viewData, "bold")
AssertTrue item <> 0 AndAlso item->fontId = BACKEND_FONT_ARIAL_12_BOLD, _
    "STRONG text uses the bold embedded font"
item = htmlviewSmoke_FindTextItem(viewData, "Inline")
AssertTrue item <> 0 AndAlso item->color = RGB(128, 48, 16), _
    "bounded inline color CSS is applied"
AssertTrue htmlviewSmoke_FindRule(viewData) <> 0, _
    "horizontal rule produces a rule item"
item = viewData->firstItem
While item <> 0 AndAlso item->itemKind <> HTMLVIEW_ITEM_IMAGE
    item = item->nextItem
Wend
AssertTrue item <> 0 AndAlso item->image <> 0 AndAlso _
    item->image->formatKind = RASTERIMAGE_FORMAT_BMP, _
    "relative local IMG source is decoded into a layout item"
AssertTrue viewData->itemCount > 0 AndAlso _
    viewData->itemCount <= HTMLVIEW_MAX_LAYOUT_ITEMS, _
    "layout item count remains inside its public bound"

test_Section "reflow and input"
wideHeight = htmlview_GetContentHeight(htmlWidget)
AssertTrue wideHeight > htmlWidget->h, _
    "sample document overflows the short viewport"
htmlWidget->w = 180
AssertTrue htmlview_Reflow(htmlWidget), "explicit narrow reflow succeeds"
AssertTrue htmlview_GetContentHeight(htmlWidget) >= wideHeight, _
    "narrow reflow does not reduce wrapped document height"
htmlWidget->w = 360
AssertTrue htmlview_Reflow(htmlWidget), "wide reflow succeeds"

htmlview_SetScroll htmlWidget, &h7fffffff
maximumScroll = htmlview_GetScroll(htmlWidget)
AssertTrue maximumScroll > 0 AndAlso _
    maximumScroll < htmlview_GetContentHeight(htmlWidget), _
    "programmatic scrolling clamps to the document range"

htmlview_SetScroll htmlWidget, 0
input_MockMouse htmlWidget->ax + 10, htmlWidget->ay + 10, 0, -1
gui_UpdateAll
AssertTrue htmlview_GetScroll(htmlWidget) > 0, _
    "mouse wheel scrolls while the pointer is over the document"

scrollBefore = htmlview_GetScroll(htmlWidget)
htmlviewSmoke_Click _
    htmlWidget->ax + htmlWidget->w - 3, _
    htmlWidget->ay + htmlWidget->h - 3
AssertTrue htmlview_GetScroll(htmlWidget) > scrollBefore, _
    "owned vertical scrollbar moves the document"

htmlview_SetScroll htmlWidget, 0
htmlWidget->has_focus = -1
input_MockKey KEY_DOWN, -1
gui_UpdateAll
input_MockKey KEY_DOWN, 0
gui_UpdateAll
AssertTrue htmlview_GetScroll(htmlWidget) > 0, _
    "focused Down key scrolls by one text line"

test_Section "link policy"
htmlview_SetScroll htmlWidget, 0
htmlview_SetLinkHandler _
    htmlWidget, @htmlviewSmoke_LinkHandler, @htmlviewSmokeContextCount
item = htmlviewSmoke_FindLinkItem(viewData)
AssertTrue item <> 0, "anchor produces a linked layout item"
If item <> 0 Then
    htmlview_SetScroll htmlWidget, item->y - 20
    clickX = htmlWidget->ax + 1 + viewData->padding + item->x + 1
    clickY = htmlWidget->ay + 1 + viewData->padding + _
        item->y - htmlview_GetScroll(htmlWidget) + 1
    htmlviewSmoke_Click clickX, clickY
End If
AssertTrue htmlviewSmokeCallbackCount = 1 AndAlso _
    htmlviewSmokeContextCount = 1, _
    "completed link click invokes the optional callback once"
AssertTrue htmlviewSmokeCallbackHref = _
    "dd:item/42?mode=read&safe=yes", _
    "link callback receives the decoded application URI"
AssertTrue htmlview_PopLink(htmlWidget, href) AndAlso _
    href = htmlviewSmokeCallbackHref, _
    "polling returns the same activated link"
AssertTrue htmlview_PopLink(htmlWidget, href) = 0 AndAlso href = "", _
    "polling consumes a pending link"

test_Section "invalid input and safety limits"
previousTitle = htmlview_GetTitle(htmlWidget)
AssertTrue htmlview_LoadFile( _
    htmlWidget, "tests/assets/does_not_exist.html" _
) = 0, "missing file reports failure"
AssertTrue Len(htmlview_GetLastError(htmlWidget)) > 0 AndAlso _
    htmlview_GetTitle(htmlWidget) = previousTitle, _
    "failed file load preserves the current document"

oversizedHtml = String(HTMLVIEW_MAX_DOCUMENT_BYTES + 1, Asc("x"))
AssertTrue htmlview_SetHtml(htmlWidget, oversizedHtml) = 0, _
    "document larger than 2 MiB is rejected"
AssertTrue htmlview_GetTitle(htmlWidget) = previousTitle, _
    "oversized input preserves the current document"
oversizedHtml = ""

nestedHtml = ""
For nestingLevel As Integer = 1 To 65
    nestedHtml &= "<span>"
Next nestingLevel
nestedHtml &= "bounded"
For nestingLevel As Integer = 1 To 65
    nestedHtml &= "</span>"
Next nestingLevel
AssertTrue htmlview_SetHtml(htmlWidget, nestedHtml) = 0, _
    "style nesting beyond 64 levels reports a bounded layout"
AssertTrue Len(htmlview_GetLastError(htmlWidget)) > 0, _
    "nesting limit provides a diagnostic"

AssertTrue htmlview_SetHtml(htmlWidget, "alpha <broken") <> 0, _
    "unterminated tag text remains safe to parse"
AssertTrue InStr(htmlview_GetPlainText(htmlWidget), "<broken") > 0, _
    "unterminated tag is retained as visible text"

test_Section "rendering and lifecycle"
htmlview_SetImageHandler htmlWidget, @htmlviewSmoke_ImageHandler, 0
AssertTrue htmlview_SetHtml( _
    htmlWidget, "<img src='memory:test-image' alt='Provided image'>" _
), "application image provider supplies a custom source"
viewData = Cast(HtmlViewData Ptr, htmlWidget->data)
item = viewData->firstItem
AssertTrue htmlviewSmokeImageCount = 1 AndAlso item <> 0 AndAlso _
    item->itemKind = HTMLVIEW_ITEM_IMAGE AndAlso item->image <> 0, _
    "provided image transfers into an owned layout item"

htmlview_SetBasePath htmlWidget, "tests/assets"
AssertTrue htmlview_GetBasePath(htmlWidget) = "tests/assets", _
    "explicit image base path is retained"
AssertTrue htmlview_SetHtml( _
    htmlWidget, _
    "<img src='../../assets/fonts/font_arial_10_regular.bmp' " & _
    "alt='SetHtml local image'>" _
), "SetHtml resolves an image through the explicit base path"
viewData = Cast(HtmlViewData Ptr, htmlWidget->data)
item = viewData->firstItem
AssertTrue item <> 0 AndAlso item->itemKind = HTMLVIEW_ITEM_IMAGE, _
    "explicit base path produces an image item"
AssertTrue htmlview_LoadFile( _
    htmlWidget, "tests/assets/htmlview_sample.html" _
), "sample document reloads after invalid input"
backend_Clear RGB(220, 220, 220)
gui_UpdateAll
gui_RenderAll
AssertTrue htmlview_GetContentHeight(htmlWidget) > 0, _
    "render pass leaves a valid layout"

htmlview_Clear htmlWidget
AssertTrue htmlview_GetPlainText(htmlWidget) = "" AndAlso _
    htmlview_GetContentHeight(htmlWidget) = 1, _
    "clear releases document layout and resets state"
gui_RemoveWidget "html_smoke"
AssertTrue gui_FindWidget("html_smoke") = 0, _
    "manager removal destroys the viewer and owned scrollbar"

backend_Exit
test_Summary
End 0

/' end of htmlview_smoke.bas '/
