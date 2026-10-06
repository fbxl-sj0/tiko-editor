/'
    Project: omaGUI Tests
    File: canvas_click_smoke.bas
    Purpose: Verify opt-in canvas clicks through the ordinary input manager.
    Responsibilities: Exercise capture, cancellation, occlusion, and default compatibility.
    This file intentionally does NOT contain: a platform pointer provider.
'/
#lang "fb"
#define OMAGUI_IMPLEMENTATION
#define OMAGUI_PORTABLE_ONLY
#include once "omaGUI.bi"

Private Sub test_Require(ByVal condition As Integer, ByRef description As Const String)
    If condition Then Exit Sub
    Print "FAIL "; description
    End 1
End Sub

Private Sub test_Mouse(ByVal x As Integer, ByVal y As Integer, ByVal buttons As Integer)
    input_MockMouse x, y, buttons
    gui_UpdateAll
End Sub

backend_Init 320, 200, -1
gui_Init
Dim As Widget Ptr surface = canvas_Create("surface", 20, 20, 100, 80, 0)
Dim As Widget Ptr cover = button_Create("cover", "Cover", 60, 40, 40, 30, 0)
test_Require(surface <> 0 AndAlso cover <> 0, "widget allocation")
gui_AddWidget surface
gui_AddWidget cover
test_Mouse 25, 25, 1
test_Mouse 25, 25, 0
test_Require(canvas_GetActivationCount(surface) = 0 AndAlso surface->accepts_focus = 0, "canvas remains nonclickable and nonfocusable by default")
test_Require(canvas_SetClickable(surface, -1), "enable clicks")
test_Require(canvas_SetClickable(cover, -1) = 0 AndAlso canvas_SetClickable(0, -1) = 0, "wrong type and null rejected")
test_Mouse 25, 25, 1
test_Require(canvas_GetActivationCount(surface) = 0, "press alone does not click")
test_Mouse 25, 25, 0
test_Require(canvas_GetActivationCount(surface) = 1, "release inside completes click")
test_Mouse 25, 25, 0
test_Require(canvas_GetActivationCount(surface) = 1, "idle frame does not replay click")
test_Mouse 25, 25, 1
test_Mouse 180, 150, 1
test_Mouse 180, 150, 0
test_Require(canvas_GetActivationCount(surface) = 1, "release outside cancels click")
test_Mouse 180, 150, 1
test_Mouse 25, 25, 1
test_Mouse 25, 25, 0
test_Require(canvas_GetActivationCount(surface) = 1, "dragging an outside press onto canvas cannot click")
test_Mouse 25, 25, 1
test_Mouse 180, 150, 1
test_Mouse 25, 25, 1
test_Mouse 25, 25, 0
test_Require(canvas_GetActivationCount(surface) = 2, "captured press can return before release")
test_Mouse 65, 45, 1
test_Mouse 65, 45, 0
test_Require(canvas_GetActivationCount(surface) = 2, "covering widget owns overlapping input")
test_Mouse 25, 25, 1
surface->enabled = 0
test_Mouse 25, 25, 1
surface->enabled = -1
test_Mouse 25, 25, 1
test_Mouse 25, 25, 0
test_Require(canvas_GetActivationCount(surface) = 2, "disable and re-enable during press cannot re-arm it")
test_Mouse 25, 25, 1
surface->visible = 0
test_Mouse 25, 25, 1
surface->visible = -1
test_Mouse 25, 25, 0
test_Require(canvas_GetActivationCount(surface) = 2, "hidden press is cancelled")
test_Mouse 25, 25, 1
gui_SetModalRoot cover
test_Mouse 25, 25, 0
gui_ClearModalRoot cover
test_Mouse 25, 25, 0
test_Require(canvas_GetActivationCount(surface) = 2, "modal exclusion cancels pending press")
test_Mouse 25, 25, 2
test_Mouse 25, 25, 0
test_Require(canvas_GetActivationCount(surface) = 2, "secondary button does not activate")
test_Mouse 25, 25, 1
canvas_SetClickable surface, 0
canvas_SetClickable surface, -1
test_Mouse 25, 25, 0
test_Require(canvas_GetActivationCount(surface) = 2, "changing click policy cancels pending press")
test_Mouse 25, 25, 1
test_Mouse 25, 25, 0
test_Require(canvas_GetActivationCount(surface) = 3, "next fresh click remains usable")
gui_ResetForTest
backend_Exit
Print "canvas_click_smoke: PASS"

/' end of canvas_click_smoke.bas '/
