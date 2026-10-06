/'
    Project: omaGUI Tests
    File: geometry_api_smoke.bas

    Purpose:
        Verify checked public widget geometry updates and anchor rebasing.

    Responsibilities:
        - reject null and non-positive bounds without modifying a widget
        - update a registered widget's current rectangle atomically
        - preserve the caller's new rectangle as the reactive anchor base

    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:
        - platform window APIs
        - VBDOS Studio application layout rules
'/

#lang "fb"
#define OMAGUI_IMPLEMENTATION
#define OMAGUI_PORTABLE_ONLY
#include once "omaGUI.bi"

Private Sub geometry_Require(ByVal success As Integer, ByVal source_line As Integer)
    If success Then Exit Sub
    Print "geometry_api_smoke: FAIL at line "; source_line
    gui_ResetForTest
    backend_Exit
    Screen 0
    End 1
End Sub

ScreenControl FB.SET_DRIVER_NAME, "null"
backend_Init 320, 200, 0
Dim As Integer screen_width, screen_height, screen_depth
ScreenInfo screen_width, screen_height, screen_depth
geometry_Require screen_width = 320 AndAlso screen_height = 200 AndAlso _
    screen_depth = 32, __LINE__
gui_Init

Dim As Widget Ptr dock = button_Create("geometry_dock", "Dock", 20, 30, 80, 24, 0)
geometry_Require dock <> 0, __LINE__
gui_AddWidget dock
gui_SetAnchors dock, GUI_ANCHOR_LEFT Or GUI_ANCHOR_RIGHT Or GUI_ANCHOR_TOP

' At 400 pixels wide, the initial 80-pixel control stretches by 80 pixels.
gui_SetViewportSize 400, 200
geometry_Require dock->x = 20 AndAlso dock->y = 30 AndAlso _
    dock->w = 160 AndAlso dock->h = 24, __LINE__

geometry_Require gui_SetBounds(dock, 15, 40, 200, 32), __LINE__
geometry_Require dock->x = 15 AndAlso dock->y = 40 AndAlso _
    dock->w = 200 AndAlso dock->h = 32, __LINE__
geometry_Require gui_SetBounds(0, 1, 1, 10, 10) = 0, __LINE__
geometry_Require gui_SetBounds(dock, 1, 1, 0, 10) = 0 AndAlso _
    dock->x = 15 AndAlso dock->y = 40 AndAlso _
    dock->w = 200 AndAlso dock->h = 32, __LINE__
gui_SetFocus dock
gui_SetModalRoot dock
geometry_Require gui_GetFocus() = dock AndAlso gui_IsModalOpen(), __LINE__
geometry_Require gui_SetVisible(dock, 0) AndAlso gui_GetVisible(dock) = 0 AndAlso _
    gui_GetFocus() = 0 AndAlso gui_IsModalOpen() = 0, __LINE__
geometry_Require gui_SetVisible(dock, -1) AndAlso gui_GetVisible(dock), __LINE__
geometry_Require gui_SetVisible(0, -1) = 0 AndAlso gui_GetVisible(0) = 0, __LINE__

' The rebase keeps the new origin and applies only the later viewport delta.
gui_SetViewportSize 450, 200
geometry_Require dock->x = 15 AndAlso dock->y = 40 AndAlso _
    dock->w = 250 AndAlso dock->h = 32, __LINE__

gui_ResetForTest
backend_Exit
Screen 0
Print "geometry_api_smoke: PASS (checked bounds and anchor rebase)"
End 0

/' end of geometry_api_smoke.bas '/
