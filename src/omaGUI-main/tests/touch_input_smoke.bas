/'
    Project: omaGUI Tests
    File: touch_input_smoke.bas
    Purpose: Check bounded touch contacts and compatibility pointer behavior.
    Responsibilities: Exercise stable IDs, dispatch masks, and final release.
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain: platform touch hardware setup.
'/
#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub require_result(ByVal condition As Integer, ByVal message As String)
    If condition <> 0 Then Exit Sub
    backend_Exit
    Screen 0
    Print "touch_input_smoke: "; message
    End 1
End Sub

backend_Init 320, 200, BACKEND_HEADLESS_DRAWABLE
input_ResetForTest
input_MockMouse 1, 2, 0
input_MockTouch 0, 100, 50, 7
input_Update
Dim As Integer x, y, id
require_result input_TouchCount() = 1, "contact count"
require_result input_Touch(0, x, y, id) <> 0, "first contact"
require_result x = 100 AndAlso y = 50 AndAlso id = 7, "contact coordinates and ID"
require_result input_MouseX() = 100 AndAlso input_MouseY() = 50, "compatibility pointer position"
require_result (input_MouseButtons() And 1) <> 0, "compatibility pointer press"

input_SetDispatchMask 0, -1
require_result input_TouchCount() = 0, "touch dispatch mask"
require_result input_Touch(0, x, y, id) = 0 AndAlso id = -1, "masked contact output"
input_SetDispatchMask -1, -1

input_MockTouchCount 0
input_Update
require_result input_TouchCount() = 0, "contact release count"
require_result input_MouseX() = 100 AndAlso input_MouseY() = 50, "release position"
require_result (input_MouseButtons() And 1) = 0, "compatibility pointer release"
/'
    A completed native click may arrive after a sampled touch release. Replay
    must retain both edges, rather than letting that release erase the press.
'/
useMockMouse = 0
inputNativeButtonsInitialized = -1
inputTouchPointerActive = -1
inputTouchPointerX = 100
inputTouchPointerY = 50
input_QueuePointerEvent 150, 75, 1
input_QueuePointerEvent 150, 75, 0
input_Update
require_result input_MouseX() = 150 AndAlso input_MouseY() = 75, "queued click position wins"
require_result (input_MouseButtons() And 1) <> 0, "queued press survives touch release"
input_Update
require_result (input_MouseButtons() And 1) = 0, "queued native release survives"
require_result inputTouchPointerActive = 0 AndAlso inputTouchPointerId = -1, "no stale compatibility release"
input_ResetForTest
backend_Exit
Print "touch_input_smoke: PASS"
End 0

/' end of touch_input_smoke.bas '/
