/'
    Project: omaGUI HTML Viewer Example
    -----------------------------------

    File: htmlview_demo.bas

    Purpose:

        Demonstrate the small public API of the portable HTML viewer widget.

    Responsibilities:

        - create and populate one resizable HTML viewer
        - accept an optional local HTML file for compatibility inspection
        - show application-controlled link handling
        - use only omaGUI and standard FreeBASIC facilities

    Targets:

        FreeBASIC gfxlib build with a display driver.

    Module API:

        Standalone omaGUI example entry point; this file exposes no library API.

    This file intentionally does NOT contain:

        - a network client or external browser launcher
        - JavaScript or active document content
        - DD-reader-specific navigation policy
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Const HTMLVIEW_DEMO_WIDTH As Integer = 720
Const HTMLVIEW_DEMO_HEIGHT As Integer = 520


Private Sub htmlviewDemo_Link( _
    ByVal htmlWidget As Widget Ptr, _
    ByVal href As String, _
    ByVal context As Any Ptr _
)
    Dim As Widget Ptr statusLabel
    Dim As LabelData Ptr statusData

    If htmlWidget = 0 OrElse context = 0 Then Exit Sub
    statusLabel = Cast(Widget Ptr, context)
    If statusLabel->data = 0 Then Exit Sub

    statusData = Cast(LabelData Ptr, statusLabel->data)
    statusData->text = "Application received link: " & href
End Sub


Private Function htmlviewDemo_Document() As String
    Dim As String htmlText

    htmlText = "<html><head><title>Portable Help</title></head>" & _
        "<body bgcolor='#fbfbf7' text='#202428' link='#164c9c'>" & _
        "<h1>Portable HTML help</h1>" & _
        "<p>The viewer is an ordinary <strong>omaGUI widget</strong>. " & _
        "It wraps text, owns its scrollbar, and uses embedded fonts.</p>" & _
        "<h2>Useful document elements</h2>" & _
        "<ul><li>Headings and paragraphs</li>" & _
        "<li>Ordered and unordered lists</li>" & _
        "<li>Tables, preformatted text, rules, and colors</li></ul>" & _
        "<pre>Dim viewer As Widget Ptr" & Chr(10) & _
        "viewer = htmlview_Create(""help"", 20, 20, 500, 300)</pre>" & _
        "<p><a href='dd:item/device-status'>Open the device-status item</a>" & _
        "</p><hr>" & _
        "<p>The callback receives the URI. The application decides whether " & _
        "that means DD navigation, a local file, or no action at all.</p>" & _
        "</body></html>"
    Return htmlText
End Function


Dim As Widget Ptr htmlWidget
Dim As Widget Ptr statusLabel
Dim As String documentPath
Dim As Integer documentLoaded

backend_Init _
    HTMLVIEW_DEMO_WIDTH, HTMLVIEW_DEMO_HEIGHT, 0, _
    BACKEND_WINDOW_RESIZABLE
WindowTitle "omaGUI portable HTML viewer"
gui_Init

htmlWidget = htmlview_Create( _
    "help_view", 16, 16, HTMLVIEW_DEMO_WIDTH - 32, _
    HTMLVIEW_DEMO_HEIGHT - 62 _
)
statusLabel = label_Create( _
    "link_status", "Click the document link to test navigation.", _
    18, HTMLVIEW_DEMO_HEIGHT - 31 _
)

If htmlWidget = 0 OrElse statusLabel = 0 Then
    Print "Unable to create the HTML viewer example widgets."
    backend_Exit
    End 1
End If

gui_AddWidget htmlWidget
gui_AddWidget statusLabel
gui_SetAnchors htmlWidget, GUI_ANCHOR_ALL
gui_SetAnchors statusLabel, GUI_ANCHOR_LEFT Or GUI_ANCHOR_BOTTOM
htmlview_SetLinkHandler htmlWidget, @htmlviewDemo_Link, statusLabel

documentPath = Command(1)
If Len(documentPath) > 0 Then
    documentLoaded = htmlview_LoadFile(htmlWidget, documentPath)
Else
    documentLoaded = htmlview_SetHtml(htmlWidget, htmlviewDemo_Document())
End If
If documentLoaded = 0 Then
    Print "Unable to lay out HTML: "; htmlview_GetLastError(htmlWidget)
    gui_ResetForTest
    backend_Exit
    End 2
End If
If Len(htmlview_GetTitle(htmlWidget)) > 0 Then
    WindowTitle "omaGUI HTML viewer - " & htmlview_GetTitle(htmlWidget)
End If

Do
    backend_Clear RGB(224, 224, 224)
    gui_UpdateAll
    gui_RenderAll
    backend_Flip

    If input_KeyPressed(KEY_ESCAPE) Then Exit Do
    Sleep 10, 1
Loop

gui_ResetForTest
backend_Exit

/' end of htmlview_demo.bas '/
