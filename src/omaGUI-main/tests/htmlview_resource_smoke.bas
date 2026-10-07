/'
    Project: omaGUI Tests
    File: htmlview_resource_smoke.bas
    Purpose: Check application-owned linked stylesheets and anchors.
    Responsibilities: Resolve one virtual stylesheet during staged layout.
    This file intentionally does NOT contain networking or disk resources.
'/

#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"

Dim Shared As Integer resourceCalls

Private Function SupplyResource( _
    ByVal resourcePath As String, ByVal context As Any Ptr, _
    ByRef resourceText As String, ByRef errorText As String _
) As Integer
    If resourcePath <> "chm://help/style.css" Then Return 0
    resourceCalls += 1
    resourceText = "p { color: #123456; }"
    Return -1
End Function

Private Sub Require(ByVal condition As Integer, ByRef description As Const String)
    If condition Then Exit Sub
    backend_Exit
    Screen 0
    Print "htmlview_resource_smoke: FAIL "; description
    End 1
End Sub

backend_Init 320, 240, BACKEND_HEADLESS_DRAWABLE
gui_Init
Dim As Widget Ptr helpView = htmlview_Create("help", 0, 0, 300, 180)
Require helpView <> 0, "create viewer"
gui_AddWidget helpView
htmlview_SetResourceHandler helpView, @SupplyResource
Require htmlview_BeginSetHtmlAtPath( _
    helpView, "<link rel='stylesheet' href='style.css'><p id='topic'>Topic</p>", _
    "chm://help" _
), "start virtual page"

Dim As Integer updateCount
While htmlview_IsLoading(helpView) <> 0 AndAlso updateCount < 1000
    htmlview_UpdateLoad helpView, 10
    updateCount += 1
Wend

Require htmlview_GetLoadState(helpView) = HTMLVIEW_LOAD_COMPLETE, _
    "finish staged page"
Require resourceCalls = 1, "resolve linked stylesheet through callback"
Require Cast(HtmlViewData Ptr, helpView->data)->cssRuleCount > 0, _
    "apply linked stylesheet rules"
Require htmlview_GotoAnchor(helpView, "TOPIC"), "find case-insensitive anchor"

gui_RemoveWidgetPtr helpView
backend_Exit
Print "htmlview_resource_smoke OK"

' end of htmlview_resource_smoke.bas
