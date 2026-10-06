/'
    Project: omaGUI Test Suite
    --------------------------

    File: input_any_key_smoke.bas

    Targets:

        FreeBASIC FB dialect with the gfxlib2 desktop backend.

    Module API:

        Standalone executable. It exports no reusable symbols.

    Purpose:

        Verify the bounded any-key query used by modal user interfaces.

    Responsibilities:

        - verify idle, pressed, and released key states
        - verify multiple held keys remain observable
        - verify the GUI keyboard dispatch mask suppresses the query
        - use the guarded deterministic input backend for every key change

    This file intentionally does NOT contain:

        - widget behavior or application-specific modal policy
        - screenshots or native desktop automation
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"

' -------------------------------------------------------------------------
' Failure handling
' -------------------------------------------------------------------------

Private Sub inputAnyKey_Fail( _
    ByVal messageText As String, ByVal exitCode As Integer _
)
    gui_ResetForTest
    backend_Exit
    Print "input any-key smoke failed: " & messageText
    End exitCode
End Sub

' -------------------------------------------------------------------------
' Any-key state and dispatch coverage
' -------------------------------------------------------------------------

backend_Init 320, 180, -1
gui_Init
input_ResetForTest

If input_AnyKeyPressed() <> 0 Then
    inputAnyKey_Fail "the reset input state reported a key", 1
End If

input_MockKey FB.SC_F4, -1
If input_AnyKeyPressed() = 0 OrElse input_KeyPressed(FB.SC_F4) = 0 Then
    inputAnyKey_Fail "one held function key was not reported", 2
End If

input_SetDispatchMask -1, 0
If input_AnyKeyPressed() <> 0 Then
    inputAnyKey_Fail "the keyboard dispatch mask was ignored", 3
End If

input_SetDispatchMask -1, -1
If input_AnyKeyPressed() = 0 Then
    inputAnyKey_Fail "a held key was lost after dispatch resumed", 4
End If

input_MockKey FB.SC_SPACE, -1
input_MockKey FB.SC_F4, 0
If input_AnyKeyPressed() = 0 Then
    inputAnyKey_Fail "the second held key was not reported", 5
End If

input_MockKey FB.SC_SPACE, 0
If input_AnyKeyPressed() <> 0 Then
    inputAnyKey_Fail "released keys remained active", 6
End If

gui_ResetForTest
backend_Exit
Print "input any-key smoke OK"
End 0

/' end of input_any_key_smoke.bas '/
