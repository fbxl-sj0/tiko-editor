/'
    Project: omaGUI
    ---------------
    File: input_gfxlib.bas

    Purpose:
        Implement the input abstraction with FreeBASIC gfxlib calls.

    Responsibilities:
        - poll mouse position, buttons, wheel movement, keys, and text input
        - retain a bounded snapshot of logical-coordinate touch contacts
        - promote the primary touch to the ordinary widget pointer stream
        - buffer native mouse transitions which occur between GUI frames
        - retain complete key presses and modifier chords between GUI frames
        - retain a native window-close request until the application reads it
        - expose per-widget pointer and keyboard dispatch masks
        - provide deterministic input values for GUI tests

    This file intentionally does NOT contain:
        - widget-specific input behavior
        - graphics rendering
'/

#lang "fb"

#include once "src/widgets/widgets.bi"

' -------------------------------------------------------------------------
' Retained backend and deterministic test state
' -------------------------------------------------------------------------

/'
    The backend is compiled into omaGUI as a collection of include modules,
    so its private polling state must be shared with the accessor routines in
    this file.  It is not part of the public input API.
'/
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer mX, mY, mButtons, mWheelDelta
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer previousWheelPosition, wheelPositionInitialized
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer mockX, mockY, mockButtons, mockWheelDelta
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer useMockMouse, useMockTouch, useMockKeys, useMockText
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer pointerDispatchEnabled = -1, keyboardDispatchEnabled = -1
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As String textBuffer, mockText
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer inputTouchContactCount, mockTouchContactCount
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer inputTouchX(0 To INPUT_TOUCH_CAPACITY - 1)
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer inputTouchY(0 To INPUT_TOUCH_CAPACITY - 1)
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer inputTouchId(0 To INPUT_TOUCH_CAPACITY - 1)
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer inputTouchPointerActive, inputTouchPointerId = -1
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer inputTouchPointerX, inputTouchPointerY
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer mockTouchX(0 To INPUT_TOUCH_CAPACITY - 1)
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer mockTouchY(0 To INPUT_TOUCH_CAPACITY - 1)
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer mockTouchId(0 To INPUT_TOUCH_CAPACITY - 1)

' FreeBASIC gfxlib scan codes are represented by one unsigned byte.
Const INPUT_KEY_LAST = 255

/'
    Keyboard controls need edge retention for the same reason as pointer
    clicks. A complete Tab, Enter, arrow key, or Alt shortcut may occur while
    an application is parsing a document or formatting live data. MultiKey
    only reports the final state, so ScreenEvent records each press together
    with the modifier state that existed at that instant.
'/
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer inputNativeModifiers
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer inputKeyPressEvents(0 To INPUT_KEY_LAST)
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer inputKeyPressModifiers(0 To INPUT_KEY_LAST)
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer mockKeyPressEvents(0 To INPUT_KEY_LAST)
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer mockKeyPressModifiers(0 To INPUT_KEY_LAST)

/'
    GetMouse exposes only current state. A complete click can otherwise vanish
    when DD rendering takes longer than the press. ScreenEvent supplies the
    missing edges; one queued state is replayed per GUI frame so existing
    release-driven widgets keep their ordinary capture semantics.
'/
Const INPUT_POINTER_EVENT_CAPACITY As Long = 64
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Long inputPointerEventX(0 To INPUT_POINTER_EVENT_CAPACITY - 1)
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Long inputPointerEventY(0 To INPUT_POINTER_EVENT_CAPACITY - 1)
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer inputPointerEventButtons( _
    0 To INPUT_POINTER_EVENT_CAPACITY - 1 _
)
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Long inputPointerEventHead, inputPointerEventTail
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Long inputPointerEventCount
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer inputNativeButtons, inputNativeButtonsInitialized
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer inputNativeX, inputNativeY
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer inputWindowCloseRequested

' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer mockKeys(0 To INPUT_KEY_LAST)
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer mockPreviousKeys(0 To INPUT_KEY_LAST)

' Printable single-byte input is intentionally limited to the ASCII range.
Const INPUT_TEXT_BYTE_INDEX = 0
Const INPUT_TEXT_BYTE_COUNT = 1
Const INPUT_TEXT_ASCII_FIRST = 32
Const INPUT_TEXT_ASCII_LAST = 126


' -------------------------------------------------------------------------
' Native event and contact collection
' -------------------------------------------------------------------------


Private Sub input_QueuePointerEvent( _
    ByVal x As Long, _
    ByVal y As Long, _
    ByVal buttons As Integer _
)
    If inputPointerEventCount >= INPUT_POINTER_EVENT_CAPACITY Then
        /'
            Recover to the newest physical state if an application was unable
            to render for an extreme number of transitions. This may discard
            old clicks, but it cannot leave a widget permanently pressed.
        '/
        inputPointerEventHead = 0
        inputPointerEventTail = 0
        inputPointerEventCount = 0
    End If

    inputPointerEventX(inputPointerEventTail) = x
    inputPointerEventY(inputPointerEventTail) = y
    inputPointerEventButtons(inputPointerEventTail) = buttons
    inputPointerEventTail += 1
    If inputPointerEventTail >= INPUT_POINTER_EVENT_CAPACITY Then _
        inputPointerEventTail = 0
    inputPointerEventCount += 1
End Sub


Private Function input_ModifierForScanCode( _
    ByVal scanCode As Integer _
) As Integer
    Select Case scanCode
    Case FB.SC_CONTROL
        Return INPUT_MODIFIER_CONTROL
    Case FB.SC_ALT
        Return INPUT_MODIFIER_ALT
    Case FB.SC_LSHIFT, FB.SC_RSHIFT
        Return INPUT_MODIFIER_SHIFT
    End Select

    Return INPUT_MODIFIER_NONE
End Function


Private Sub input_CollectNativeEvents()
    Dim As FB.Event eventRecord
    Dim As Integer modifierBit

    While ScreenEvent(@eventRecord)
        Select Case eventRecord.type
        Case FB.EVENT_KEY_PRESS
            modifierBit = input_ModifierForScanCode(eventRecord.scancode)
            If modifierBit <> INPUT_MODIFIER_NONE Then _
                inputNativeModifiers Or= modifierBit
            If eventRecord.scancode >= 0 AndAlso _
               eventRecord.scancode <= INPUT_KEY_LAST Then
                inputKeyPressEvents(eventRecord.scancode) = -1
                inputKeyPressModifiers(eventRecord.scancode) Or= _
                    inputNativeModifiers
            End If
        Case FB.EVENT_KEY_RELEASE
            modifierBit = input_ModifierForScanCode(eventRecord.scancode)
            If modifierBit <> INPUT_MODIFIER_NONE Then _
                inputNativeModifiers And= Not modifierBit
        Case FB.EVENT_MOUSE_MOVE
            inputNativeX = eventRecord.x
            inputNativeY = eventRecord.y
        Case FB.EVENT_MOUSE_BUTTON_PRESS, FB.EVENT_MOUSE_DOUBLE_CLICK
            /'
                Touchscreen taps can begin without a preceding mouse-move
                event. Use the coordinates carried by the button event so a
                stationary finger does not activate the last pointer location.
            '/
            inputNativeX = eventRecord.x
            inputNativeY = eventRecord.y
            inputNativeButtons Or= eventRecord.button
            input_QueuePointerEvent _
                inputNativeX, inputNativeY, inputNativeButtons
        Case FB.EVENT_MOUSE_BUTTON_RELEASE
            inputNativeX = eventRecord.x
            inputNativeY = eventRecord.y
            inputNativeButtons And= Not eventRecord.button
            input_QueuePointerEvent _
                inputNativeX, inputNativeY, inputNativeButtons
        Case FB.EVENT_WINDOW_CLOSE
            inputWindowCloseRequested = -1
        Case FB.EVENT_WINDOW_LOST_FOCUS
            inputNativeModifiers = INPUT_MODIFIER_NONE
        End Select
    Wend
End Sub


Private Function input_PopPointerEvent( _
    ByRef x As Integer, _
    ByRef y As Integer, _
    ByRef buttons As Integer _
) As Integer
    If inputPointerEventCount <= 0 Then Return 0

    x = inputPointerEventX(inputPointerEventHead)
    y = inputPointerEventY(inputPointerEventHead)
    buttons = inputPointerEventButtons(inputPointerEventHead)
    inputPointerEventHead += 1
    If inputPointerEventHead >= INPUT_POINTER_EVENT_CAPACITY Then _
        inputPointerEventHead = 0
    inputPointerEventCount -= 1
    Return -1
End Function


Private Sub input_CollectTouchContacts()
    inputTouchContactCount = 0

    If useMockTouch <> 0 Then
        inputTouchContactCount = mockTouchContactCount
        For contactIndex As Integer = 0 To inputTouchContactCount - 1
            inputTouchX(contactIndex) = mockTouchX(contactIndex)
            inputTouchY(contactIndex) = mockTouchY(contactIndex)
            inputTouchId(contactIndex) = mockTouchId(contactIndex)
        Next
        Exit Sub
    End If

    Dim As Integer nativeCount = GetTouchCount()
    If nativeCount < 0 Then nativeCount = 0
    If nativeCount > INPUT_TOUCH_CAPACITY Then _
        nativeCount = INPUT_TOUCH_CAPACITY

    For nativeIndex As Integer = 0 To nativeCount - 1
        Dim As Integer contactX
        Dim As Integer contactY
        Dim As Integer contactId
        If GetTouch(nativeIndex, contactX, contactY, contactId) = 0 Then
            inputTouchX(inputTouchContactCount) = contactX
            inputTouchY(inputTouchContactCount) = contactY
            inputTouchId(inputTouchContactCount) = contactId
            inputTouchContactCount += 1
        End If
    Next
End Sub


Private Sub input_ApplyTouchCompatibilityPointer()
    /'
        Some gfxlib targets expose accurate logical coordinates through the
        touch API while their emulated mouse retains a stale or transformed
        position. Widgets use the ordinary pointer stream, so mirror one
        stable touch contact there and synthesize its release when the final
        contact disappears. Application gesture code still receives every
        independent contact through input_Touch.
    '/
    If inputTouchContactCount > 0 Then
        Dim As Integer pointerContactIndex = 0
        If inputTouchPointerActive <> 0 Then
            For contactIndex As Integer = 0 To inputTouchContactCount - 1
                If inputTouchId(contactIndex) = inputTouchPointerId Then
                    pointerContactIndex = contactIndex
                    Exit For
                End If
            Next
        End If
        inputTouchPointerX = inputTouchX(pointerContactIndex)
        inputTouchPointerY = inputTouchY(pointerContactIndex)
        inputTouchPointerId = inputTouchId(pointerContactIndex)
        inputTouchPointerActive = -1
        mX = inputTouchPointerX
        mY = inputTouchPointerY
        mButtons Or= 1
    ElseIf inputTouchPointerActive <> 0 Then
        mX = inputTouchPointerX
        mY = inputTouchPointerY
        mButtons And= Not 1
        inputTouchPointerActive = 0
        inputTouchPointerId = -1
    End If
End Sub

Sub input_Update()
    Dim As Long MouseStatus
    Dim As Integer currentWheelPosition
    Dim As Integer mockModifiers
    Dim As String KeyText

    pointerDispatchEnabled = -1
    keyboardDispatchEnabled = -1

    For keyIndex As Integer = 0 To INPUT_KEY_LAST
        inputKeyPressEvents(keyIndex) = 0
        inputKeyPressModifiers(keyIndex) = INPUT_MODIFIER_NONE
    Next keyIndex

    If useMockMouse Then
        mX = mockX
        mY = mockY
        mButtons = mockButtons
        mWheelDelta = mockWheelDelta
        mockWheelDelta = 0
    Else
        /'
            gfxlib returns nonzero when no mouse is available and writes -1
            into every output.  The coordinate sentinel is useful to callers,
            but -1 is an invalid button bitmask that would read as every button
            pressed unless it is cleared here.
        '/
        MouseStatus = GetMouse(mX, mY, currentWheelPosition, mButtons)
        If inputNativeButtonsInitialized = 0 Then
            inputNativeButtons = IIf(MouseStatus = 0, mButtons, 0)
            inputNativeX = IIf(MouseStatus = 0, mX, -1)
            inputNativeY = IIf(MouseStatus = 0, mY, -1)
            inputNativeButtonsInitialized = -1
        End If
        input_CollectNativeEvents
        If MouseStatus <> 0 Then
            mX = -1
            mY = -1
            mButtons = 0
            mWheelDelta = 0
            wheelPositionInitialized = 0
        Else
            If wheelPositionInitialized <> 0 Then
                mWheelDelta = currentWheelPosition - previousWheelPosition
            Else
                mWheelDelta = 0
                wheelPositionInitialized = -1
            End If

            previousWheelPosition = currentWheelPosition
            If input_PopPointerEvent(mX, mY, mButtons) = 0 Then
                inputNativeButtons = mButtons
                inputNativeX = mX
                inputNativeY = mY
            End If
        End If
    End If

    /'
        Touch is collected independently from the compatibility mouse path.
        A one-finger contact can therefore continue to operate ordinary
        widgets while application code also sees stable IDs for gestures.
    '/
    input_CollectTouchContacts
    input_ApplyTouchCompatibilityPointer

    If useMockKeys Then
        If mockKeys(FB.SC_CONTROL) <> 0 Then _
            mockModifiers Or= INPUT_MODIFIER_CONTROL
        If mockKeys(FB.SC_ALT) <> 0 Then _
            mockModifiers Or= INPUT_MODIFIER_ALT
        If mockKeys(FB.SC_LSHIFT) <> 0 OrElse _
           mockKeys(FB.SC_RSHIFT) <> 0 Then _
            mockModifiers Or= INPUT_MODIFIER_SHIFT

        For keyIndex As Integer = 0 To INPUT_KEY_LAST
            If mockKeyPressEvents(keyIndex) <> 0 Then
                inputKeyPressEvents(keyIndex) = -1
                inputKeyPressModifiers(keyIndex) Or= _
                    mockKeyPressModifiers(keyIndex)
                mockKeyPressEvents(keyIndex) = 0
                mockKeyPressModifiers(keyIndex) = INPUT_MODIFIER_NONE
            End If
            If mockKeys(keyIndex) <> 0 AndAlso _
               mockPreviousKeys(keyIndex) = 0 Then
                inputKeyPressEvents(keyIndex) = -1
                inputKeyPressModifiers(keyIndex) Or= mockModifiers
            End If
            mockPreviousKeys(keyIndex) = mockKeys(keyIndex)
        Next keyIndex
    End If

    If useMockText Then
        textBuffer = mockText
        mockText = ""
        Exit Sub
    End If

    textBuffer = ""
    KeyText = Inkey

    While KeyText <> ""
        If Len(KeyText) = INPUT_TEXT_BYTE_COUNT Then
            If KeyText[INPUT_TEXT_BYTE_INDEX] >= INPUT_TEXT_ASCII_FIRST And _
               KeyText[INPUT_TEXT_BYTE_INDEX] <= INPUT_TEXT_ASCII_LAST Then
                textBuffer &= KeyText
            End If
        End If

        KeyText = Inkey
    Wend
End Sub

Function input_MouseX() As Integer
    If pointerDispatchEnabled = 0 Then Return -1
    Return mX
End Function

Function input_MouseY() As Integer
    If pointerDispatchEnabled = 0 Then Return -1
    Return mY
End Function

Function input_MouseButtons() As Integer
    If pointerDispatchEnabled = 0 Then Return 0
    Return mButtons
End Function

Function input_MouseWheel() As Integer
    If pointerDispatchEnabled = 0 Then Return 0
    Return mWheelDelta
End Function


Function input_TouchCount() As Integer
    If pointerDispatchEnabled = 0 Then Return 0
    Return inputTouchContactCount
End Function


Function input_Touch( _
    ByVal contactIndex As Integer, _
    ByRef x As Integer, _
    ByRef y As Integer, _
    ByRef id As Integer _
) As Integer
    x = -1
    y = -1
    id = -1
    If pointerDispatchEnabled = 0 Then Return 0
    If contactIndex < 0 OrElse _
        contactIndex >= inputTouchContactCount Then Return 0

    x = inputTouchX(contactIndex)
    y = inputTouchY(contactIndex)
    id = inputTouchId(contactIndex)
    Return -1
End Function

Function input_KeyPressed(ByVal k As Integer) As Integer
    If k < 0 OrElse k > INPUT_KEY_LAST Then Return 0
    If keyboardDispatchEnabled = 0 Then Return 0

    If useMockKeys Then Return mockKeys(k)
    Return MultiKey(k)
End Function

Function input_KeyPressEvent(ByVal k As Integer) As Integer
    If k < 0 OrElse k > INPUT_KEY_LAST Then Return 0
    If keyboardDispatchEnabled = 0 Then Return 0
    Return inputKeyPressEvents(k)
End Function

Function input_ModifiedKeyPressEvent( _
    ByVal k As Integer, _
    ByVal requiredModifiers As Integer _
) As Integer
    If input_KeyPressEvent(k) = 0 Then Return 0
    If requiredModifiers = INPUT_MODIFIER_NONE Then Return -1
    If (inputKeyPressModifiers(k) And requiredModifiers) <> _
       requiredModifiers Then Return 0
    Return -1
End Function

Function input_ControlShortcutPressed(ByVal k As Integer) As Integer
    Return input_ModifiedKeyPressEvent(k, INPUT_MODIFIER_CONTROL)
End Function

Function input_AltShortcutPressed(ByVal k As Integer) As Integer
    Return input_ModifiedKeyPressEvent(k, INPUT_MODIFIER_ALT)
End Function

Function input_PollTextInput() As String
    If keyboardDispatchEnabled = 0 Then Return ""
    Return textBuffer
End Function


Function input_TakeWindowCloseRequested() As Integer
    Dim As Integer requested

    requested = inputWindowCloseRequested
    inputWindowCloseRequested = 0
    Return requested
End Function

Sub input_SetDispatchMask( _
    ByVal pointerEnabled As Integer, _
    ByVal keyboardEnabled As Integer _
)
    pointerDispatchEnabled = IIf(pointerEnabled <> 0, -1, 0)
    keyboardDispatchEnabled = IIf(keyboardEnabled <> 0, -1, 0)
End Sub

Sub input_MockMouse( _
    ByVal x As Integer, ByVal y As Integer, ByVal b As Integer, _
    ByVal wheelDelta As Integer _
)
    mockX = x
    mockY = y
    mockButtons = b
    mockWheelDelta = wheelDelta
    useMockMouse = 1
End Sub


Sub input_MockTouchCount(ByVal contactCount As Integer)
    If contactCount < 0 Then contactCount = 0
    If contactCount > INPUT_TOUCH_CAPACITY Then _
        contactCount = INPUT_TOUCH_CAPACITY
    mockTouchContactCount = contactCount
    useMockTouch = 1
End Sub


Sub input_MockTouch( _
    ByVal contactIndex As Integer, _
    ByVal x As Integer, _
    ByVal y As Integer, _
    ByVal id As Integer _
)
    If contactIndex < 0 OrElse _
        contactIndex >= INPUT_TOUCH_CAPACITY Then Exit Sub
    mockTouchX(contactIndex) = x
    mockTouchY(contactIndex) = y
    mockTouchId(contactIndex) = id
    If mockTouchContactCount <= contactIndex Then _
        mockTouchContactCount = contactIndex + 1
    useMockTouch = 1
End Sub

Sub input_MockKey(ByVal k As Integer, ByVal state As Integer)
    If k < 0 Or k > INPUT_KEY_LAST Then Exit Sub

    mockKeys(k) = state
    useMockKeys = 1
End Sub

Sub input_MockKeyPress( _
    ByVal k As Integer, _
    ByVal modifiers As Integer _
)
    If k < 0 OrElse k > INPUT_KEY_LAST Then Exit Sub

    mockKeyPressEvents(k) = -1
    mockKeyPressModifiers(k) Or= modifiers
    useMockKeys = 1
End Sub

Sub input_MockControlShortcut(ByVal k As Integer)
    input_MockKeyPress k, INPUT_MODIFIER_CONTROL
End Sub

Sub input_MockText(ByVal txt As String)
    mockText = txt
    useMockText = 1
End Sub

Sub input_ResetForTest()
    mX = 0
    mY = 0
    mWheelDelta = 0
    mButtons = 0
    mockX = 0
    mockY = 0
    mockButtons = 0
    mockWheelDelta = 0
    previousWheelPosition = 0
    wheelPositionInitialized = 0
    useMockMouse = 1
    useMockTouch = 1
    useMockKeys = 1
    useMockText = 1
    textBuffer = ""
    mockText = ""
    pointerDispatchEnabled = -1
    keyboardDispatchEnabled = -1
    inputPointerEventHead = 0
    inputPointerEventTail = 0
    inputPointerEventCount = 0
    inputNativeButtons = 0
    inputNativeButtonsInitialized = 0
    inputNativeX = 0
    inputNativeY = 0
    inputWindowCloseRequested = 0
    inputNativeModifiers = INPUT_MODIFIER_NONE
    inputTouchContactCount = 0
    mockTouchContactCount = 0
    inputTouchPointerActive = 0
    inputTouchPointerId = -1
    inputTouchPointerX = 0
    inputTouchPointerY = 0

    For keyIndex As Integer = 0 To INPUT_KEY_LAST
        mockKeys(keyIndex) = 0
        mockPreviousKeys(keyIndex) = 0
        inputKeyPressEvents(keyIndex) = 0
        inputKeyPressModifiers(keyIndex) = INPUT_MODIFIER_NONE
        mockKeyPressEvents(keyIndex) = 0
        mockKeyPressModifiers(keyIndex) = INPUT_MODIFIER_NONE
    Next keyIndex
    For contactIndex As Integer = 0 To INPUT_TOUCH_CAPACITY - 1
        inputTouchX(contactIndex) = 0
        inputTouchY(contactIndex) = 0
        inputTouchId(contactIndex) = -1
        mockTouchX(contactIndex) = 0
        mockTouchY(contactIndex) = 0
        mockTouchId(contactIndex) = -1
    Next contactIndex
End Sub

' end of input_gfxlib.bas
