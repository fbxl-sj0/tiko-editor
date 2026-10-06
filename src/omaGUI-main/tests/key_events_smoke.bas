/'
    Project: omaGUI Tests
    File: key_events_smoke.bas
    Purpose: Verify ordered portable keyboard snapshots and modifier chords.
    Responsibilities:
        - retain presses, releases, repeats, bytes, and exact chord order
        - check masks, copy ownership, bounds, overflow, and screen handoff
        - exercise native FB.Event translation without operating-system injection
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:
        - VBDOS event handlers or a keyboard-layout translator
        - assertions about physical keyboard delivery by a platform driver
'/

#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub keyEvents_Require(ByVal success As Integer, ByVal sourceLine As Integer)
    If success Then Exit Sub
    Print "key_events_smoke: FAIL at line "; sourceLine
    End 1
End Sub

Private Sub keyEvents_Check( _
    ByVal eventIndex As Long, ByVal eventKind As Long, ByVal scanCode As Long, _
    ByVal characterByte As Long, ByVal modifiers As Long _
)
    Dim As InputKeyEvent eventValue
    keyEvents_Require input_ReadKeyEvent(eventIndex, eventValue), __LINE__
    keyEvents_Require eventValue.event_kind = eventKind, __LINE__
    keyEvents_Require eventValue.scan_code = scanCode, __LINE__
    keyEvents_Require eventValue.character_byte = characterByte, __LINE__
    keyEvents_Require eventValue.modifiers = modifiers, __LINE__
End Sub

Private Sub keyEvents_Native(ByVal eventKind As Long, ByVal scanCode As Long, ByVal characterByte As Long = 0)
    ' The library's implementation-include build lets this fixture test the
    ' same private translator called by ScreenEvent without adding a public
    ' native-injection hook to production applications.
    Dim As FB.Event eventValue
    eventValue.type = eventKind
    eventValue.scancode = scanCode
    eventValue.ascii = characterByte
    input_CollectNativeKey eventValue
End Sub

input_ResetForTest

' Separate Ctrl+A and Alt+A are not Ctrl+Alt+A. Preserve both records even
' though the traditional per-key accessor continues to report one edge.
keyEvents_Require input_MockKeyEvent(INPUT_KEY_EVENT_PRESS, FB.SC_A, 1, INPUT_MODIFIER_CONTROL), __LINE__
keyEvents_Require input_MockKeyEvent(INPUT_KEY_EVENT_RELEASE, FB.SC_A, 255, 0), __LINE__
keyEvents_Require input_MockKeyEvent(INPUT_KEY_EVENT_PRESS, FB.SC_A, 97, INPUT_MODIFIER_ALT), __LINE__
keyEvents_Require input_MockKeyEvent(INPUT_KEY_EVENT_REPEAT, FB.SC_A, 97, INPUT_MODIFIER_ALT), __LINE__
input_Update
keyEvents_Require input_KeyEventCount() = 4, __LINE__
keyEvents_Check 0, INPUT_KEY_EVENT_PRESS, FB.SC_A, 1, INPUT_MODIFIER_CONTROL
keyEvents_Check 1, INPUT_KEY_EVENT_RELEASE, FB.SC_A, 0, 0
keyEvents_Check 2, INPUT_KEY_EVENT_PRESS, FB.SC_A, 97, INPUT_MODIFIER_ALT
keyEvents_Check 3, INPUT_KEY_EVENT_REPEAT, FB.SC_A, 97, INPUT_MODIFIER_ALT
keyEvents_Require input_ControlShortcutPressed(FB.SC_A), __LINE__
keyEvents_Require input_AltShortcutPressed(FB.SC_A), __LINE__
keyEvents_Require input_ModifiedKeyPressEvent(FB.SC_A, INPUT_MODIFIER_CONTROL Or INPUT_MODIFIER_ALT) = 0, __LINE__
keyEvents_Require input_ModifiedKeyPressEvent(FB.SC_A, -1) = 0, __LINE__
keyEvents_Require input_ModifiedKeyPressEvent(FB.SC_A, 8) = 0, __LINE__
keyEvents_Require Len(input_PollTextInput()) = 0 AndAlso input_KeyPressed(FB.SC_A) = 0, __LINE__

' Readers own copies and invalid reads clear every field. A dispatch mask
' hides the snapshot, but does not consume it for the rightful input owner.
Dim As InputKeyEvent savedEvent
keyEvents_Require input_ReadKeyEvent(0, savedEvent), __LINE__
savedEvent.scan_code = -999
keyEvents_Check 0, INPUT_KEY_EVENT_PRESS, FB.SC_A, 1, INPUT_MODIFIER_CONTROL
input_SetDispatchMask -1, 0
keyEvents_Require input_KeyEventCount() = 0, __LINE__
keyEvents_Require input_ReadKeyEvent(0, savedEvent) = 0, __LINE__
keyEvents_Require savedEvent.scan_code = 0 AndAlso savedEvent.event_kind = 0 AndAlso _
    savedEvent.character_byte = 0 AndAlso savedEvent.modifiers = 0, __LINE__
keyEvents_Require input_KeyPressEvent(FB.SC_A) = 0, __LINE__
input_SetDispatchMask 0, -1
keyEvents_Require input_KeyEventCount() = 4, __LINE__
keyEvents_Require input_ReadKeyEvent(-1, savedEvent) = 0, __LINE__
keyEvents_Require input_ReadKeyEvent(4, savedEvent) = 0, __LINE__
keyEvents_Require input_ReadKeyEvent(2147483647, savedEvent) = 0, __LINE__
input_Update
keyEvents_Require input_KeyEventCount() = 0 AndAlso input_KeyPressEvent(FB.SC_A) = 0, __LINE__

' Existing short-press fixtures use the same queue. A real combined chord
' matches either required component and both together, but not Shift.
input_MockKeyPress KEY_UP, INPUT_MODIFIER_CONTROL Or INPUT_MODIFIER_ALT
input_MockKeyPress KEY_DOWN, INPUT_MODIFIER_SHIFT
input_MockKeyPress KEY_UP
input_Update
keyEvents_Require input_KeyEventCount() = 3, __LINE__
keyEvents_Check 0, INPUT_KEY_EVENT_PRESS, KEY_UP, 0, 3
keyEvents_Check 1, INPUT_KEY_EVENT_PRESS, KEY_DOWN, 0, 4
keyEvents_Check 2, INPUT_KEY_EVENT_PRESS, KEY_UP, 0, 0
keyEvents_Require input_ModifiedKeyPressEvent(KEY_UP, 3), __LINE__
keyEvents_Require input_ModifiedKeyPressEvent(KEY_UP, 4) = 0, __LINE__
keyEvents_Require input_MockKeyEvent(INPUT_KEY_EVENT_REPEAT, KEY_UP), __LINE__
input_Update
keyEvents_Check 0, INPUT_KEY_EVENT_REPEAT, KEY_UP, 0, 0
keyEvents_Require input_KeyPressEvent(KEY_UP) = 0, __LINE__

' Malformed records are rejected before they can change the pending queue.
keyEvents_Require input_MockKeyEvent(0, KEY_UP) = 0, __LINE__
keyEvents_Require input_MockKeyEvent(4, KEY_UP) = 0, __LINE__
keyEvents_Require input_MockKeyEvent(1, -1) = 0, __LINE__
keyEvents_Require input_MockKeyEvent(1, 256) = 0, __LINE__
keyEvents_Require input_MockKeyEvent(1, KEY_UP, -1) = 0, __LINE__
keyEvents_Require input_MockKeyEvent(1, KEY_UP, 256) = 0, __LINE__
keyEvents_Require input_MockKeyEvent(1, KEY_UP, 0, -1) = 0, __LINE__
keyEvents_Require input_MockKeyEvent(1, KEY_UP, 0, 8) = 0, __LINE__
input_Update
keyEvents_Require input_KeyEventCount() = 0 AndAlso input_KeyEventsOverflowed() = 0, __LINE__

' Drop newest, retain the complete prefix, and expose overflow for one frame.
For eventIndex As Long = 0 To INPUT_KEY_EVENT_CAPACITY - 1
    keyEvents_Require input_MockKeyEvent(1, FB.SC_A, eventIndex, eventIndex Mod 8), __LINE__
Next eventIndex
keyEvents_Require input_MockKeyEvent(1, FB.SC_B, 98) = 0, __LINE__
input_Update
keyEvents_Require input_KeyEventCount() = INPUT_KEY_EVENT_CAPACITY, __LINE__
keyEvents_Require input_KeyEventsOverflowed(), __LINE__
For eventIndex As Long = 0 To INPUT_KEY_EVENT_CAPACITY - 1
    keyEvents_Check eventIndex, 1, FB.SC_A, eventIndex, eventIndex Mod 8
Next eventIndex
input_SetDispatchMask -1, 0
keyEvents_Require input_KeyEventsOverflowed() = 0, __LINE__
input_SetDispatchMask -1, -1
keyEvents_Require input_KeyEventsOverflowed(), __LINE__
input_Update
keyEvents_Require input_KeyEventsOverflowed() = 0 AndAlso input_KeyEventCount() = 0, __LINE__

' Native translation retains both Shift keys, including across frame changes.
keyEvents_Native FB.EVENT_KEY_PRESS, FB.SC_LSHIFT
keyEvents_Native FB.EVENT_KEY_PRESS, FB.SC_RSHIFT
keyEvents_Native FB.EVENT_KEY_RELEASE, FB.SC_LSHIFT
input_Update
keyEvents_Native FB.EVENT_KEY_PRESS, FB.SC_A, 65
keyEvents_Native FB.EVENT_KEY_REPEAT, FB.SC_A, 65
keyEvents_Native FB.EVENT_KEY_RELEASE, FB.SC_RSHIFT
keyEvents_Native FB.EVENT_KEY_PRESS, FB.SC_A, 97
keyEvents_Check 0, INPUT_KEY_EVENT_PRESS, FB.SC_A, 65, INPUT_MODIFIER_SHIFT
keyEvents_Check 1, INPUT_KEY_EVENT_REPEAT, FB.SC_A, 65, INPUT_MODIFIER_SHIFT
keyEvents_Check 2, INPUT_KEY_EVENT_RELEASE, FB.SC_RSHIFT, 0, 0
keyEvents_Check 3, INPUT_KEY_EVENT_PRESS, FB.SC_A, 97, 0
input_Update
keyEvents_Native FB.EVENT_KEY_PRESS, FB.SC_CONTROL
keyEvents_Native FB.EVENT_KEY_PRESS, FB.SC_A, 1
keyEvents_Native FB.EVENT_KEY_RELEASE, FB.SC_CONTROL
keyEvents_Native FB.EVENT_KEY_PRESS, FB.SC_ALT
keyEvents_Native FB.EVENT_KEY_PRESS, FB.SC_A, 0
keyEvents_Require input_ModifiedKeyPressEvent(FB.SC_A, 3) = 0, __LINE__
keyEvents_Require input_ControlShortcutPressed(FB.SC_A) AndAlso input_AltShortcutPressed(FB.SC_A), __LINE__
keyEvents_Native FB.EVENT_KEY_PRESS, -1, 65
keyEvents_Native FB.EVENT_KEY_PRESS, 256, 65
keyEvents_Require input_KeyEventCount() = 5, __LINE__
keyEvents_Native FB.EVENT_KEY_REPEAT, FB.SC_A, 65535
keyEvents_Check 5, INPUT_KEY_EVENT_REPEAT, FB.SC_A, 0, INPUT_MODIFIER_ALT

' A native frame may overflow even though its legacy per-key snapshot remains
' usable. The new stream advertises truncation independently of that snapshot.
input_Update
For eventIndex As Long = 1 To INPUT_KEY_EVENT_CAPACITY
    keyEvents_Native FB.EVENT_KEY_REPEAT, FB.SC_A, 97
Next eventIndex
keyEvents_Native FB.EVENT_KEY_PRESS, FB.SC_B, 98
keyEvents_Require input_KeyEventCount() = INPUT_KEY_EVENT_CAPACITY AndAlso input_KeyEventsOverflowed(), __LINE__
keyEvents_Require input_KeyPressEvent(FB.SC_B), __LINE__

' Reset and screen handoff discard pending and visible events. A held return
' key that ended external drawing must not enter the restored GUI a second time.
input_MockKeyPress KEY_DOWN
input_ResetForTest
input_Update
keyEvents_Require input_KeyEventCount() = 0 AndAlso input_KeyEventsOverflowed() = 0, __LINE__
input_MockKey KEY_RETURN, -1
input_Update
keyEvents_Check 0, INPUT_KEY_EVENT_PRESS, KEY_RETURN, 0, 0
input_MockKeyPress KEY_RETURN
input_ResumeAfterScreenChange
keyEvents_Require input_KeyEventCount() = 0, __LINE__
input_MockKeyPress KEY_RETURN
input_Update
keyEvents_Require input_KeyEventCount() = 0 AndAlso input_KeyPressEvent(KEY_RETURN) = 0, __LINE__
input_MockKey KEY_RETURN, 0
input_Update
keyEvents_Require input_KeyEventCount() = 0, __LINE__
input_MockKey KEY_RETURN, -1
input_Update
keyEvents_Check 0, INPUT_KEY_EVENT_PRESS, KEY_RETURN, 0, 0
input_MockKey KEY_RETURN, 0
input_Update
keyEvents_Check 0, INPUT_KEY_EVENT_RELEASE, KEY_RETURN, 0, 0
input_ResetForTest
Print "key_events_smoke: PASS (ordered events, exact chords, native translation, bounds and handoff)"

' end of key_events_smoke.bas
