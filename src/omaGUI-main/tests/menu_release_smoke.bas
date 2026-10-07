/'
    Project: omaGUI
    ---------------

    File: menu_release_smoke.bas

    Purpose:

        Verify that popup-menu callbacks are edge-triggered and cannot repeat
        while a pointer button remains held.

    Responsibilities:

        - exercise the menu widget with deterministic mock input
        - verify one callback on a matching release
        - verify outside release cancels and dismisses the popup

    This file intentionally does NOT contain:

        - gfxlib screen creation
        - application menu policy
        - visual screenshot comparison
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"

Dim Shared As Integer menuSmokeChecks
Dim Shared As Integer menuSmokeFailures
Dim Shared As Integer menuSmokeSelections
Dim Shared As Integer menuSmokeSelectedIndex


Private Sub MenuSmokeAssert( _
    ByVal condition As Integer, _
    ByRef message As String _
)
    menuSmokeChecks += 1
    If condition Then Exit Sub
    menuSmokeFailures += 1
    Print "FAIL: "; message
End Sub


Private Sub MenuSmokeSelection( _
    ByVal context As Any Ptr, _
    ByVal selectedIndex As Integer _
)
    menuSmokeSelections += 1
    menuSmokeSelectedIndex = selectedIndex
End Sub


Private Sub MenuSmokeFrame( _
    ByVal menuWidget As Widget Ptr, _
    ByVal x As Integer, _
    ByVal y As Integer, _
    ByVal buttons As Integer _
)
    input_MockMouse x, y, buttons
    input_Update
    menu_Update menuWidget
End Sub


Dim As Widget Ptr testMenu = menu_Create("menu_release_smoke", 40, 30)
Dim As String message

If testMenu = 0 OrElse testMenu->data = 0 Then
    Print "FAIL: menu construction failed"
    End 1
End If

testMenu->ax = 40
testMenu->ay = 30
menu_AddItem testMenu, "First", 0
menu_AddItem testMenu, "Second", 0
menu_SetSelectionHandler testMenu, @MenuSmokeSelection, 0

MenuSmokeFrame testMenu, 50, 36, 1
MenuSmokeFrame testMenu, 50, 36, 1
message = "a held menu press does not invoke its callback"
MenuSmokeAssert menuSmokeSelections = 0, message

MenuSmokeFrame testMenu, 50, 36, 0
message = "a matching menu release invokes one callback"
MenuSmokeAssert menuSmokeSelections = 1 AndAlso _
    menuSmokeSelectedIndex = 0, message
message = "a completed menu selection dismisses the popup"
MenuSmokeAssert testMenu->visible = 0, message

testMenu->visible = 1
menuSmokeSelections = 0
menuSmokeSelectedIndex = -1
MenuSmokeFrame testMenu, 50, 56, 1
MenuSmokeFrame testMenu, 200, 200, 1
MenuSmokeFrame testMenu, 200, 200, 0
message = "an outside menu release cancels without invoking a callback"
MenuSmokeAssert menuSmokeSelections = 0, message
message = "an outside menu release dismisses the popup"
MenuSmokeAssert testMenu->visible = 0, message

menu_Destroy testMenu
Delete testMenu

Print menuSmokeChecks; " checks, "; menuSmokeFailures; " failures"
If menuSmokeFailures > 0 Then End 1
End 0

/' end of menu_release_smoke.bas '/
