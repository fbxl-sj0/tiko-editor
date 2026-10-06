'
' Project: omaGUI Keyboard Navigation Tests
' -----------------------------------------
'
' File: keyboard_navigation_smoke.bas
'
' Purpose:
'     Verify the desktop keyboard-navigation contract across core widgets.
'
' Responsibilities:
'     - verify forward, reverse, wrapping, and eligibility-aware focus order
'     - verify explicit tab order without changing registration order
'     - verify mouse and keyboard focus-cue modes
'     - route default and cancel actions from Enter and Escape
'     - parse ampersand captions and activate buttons with Enter and Alt mnemonics
'     - transfer static-caption mnemonics through lifetime-checked focus targets
'     - navigate and activate list rows with the keyboard
'     - scroll an HTML document from retained short key presses
'
' Targets:
'     FreeBASIC 1.20.3-1 with the portable gfxlib desktop backend.
'
' Module API:
'     This is a standalone test executable and exports no reusable API.
'
' This file intentionally does NOT contain:
'     - operating-system key injection
'     - application-specific HART commands
'     - production-device communication
'

#define OMAGUI_IMPLEMENTATION
#lang "fb"

#include once "omaGUI.bi"
#include once "tests/test_harness.bi"

' -------------------------------------------------------------------------
' Test state and callbacks
' -------------------------------------------------------------------------

Const KEYBOARD_NAVIGATION_SCREEN_WIDTH As Integer = 420
Const KEYBOARD_NAVIGATION_SCREEN_HEIGHT As Integer = 300

' Test callback state is shared with keyboardNavigation_OnActivate.
Dim Shared As Integer keyboardNavigationActivations
Dim Shared As Integer keyboardNavigationDefaultActivations
Dim Shared As Integer keyboardNavigationCancelActivations
Dim Shared As Integer keyboardNavigationFirstWindowActivations
Dim Shared As Integer keyboardNavigationSecondWindowActivations


Sub keyboardNavigation_OnActivate(ByVal buttonWidget As Widget Ptr)
    keyboardNavigationActivations += 1
End Sub


Sub keyboardNavigation_OnDefault(ByVal buttonWidget As Widget Ptr)
    keyboardNavigationDefaultActivations += 1
End Sub


Sub keyboardNavigation_OnCancel(ByVal buttonWidget As Widget Ptr)
    keyboardNavigationCancelActivations += 1
End Sub


Sub keyboardNavigation_OnWindowAction(ByVal buttonWidget As Widget Ptr)
    If buttonWidget = 0 Then Exit Sub
    If buttonWidget->name = "keyboard_window_one_action" Then
        keyboardNavigationFirstWindowActivations += 1
    ElseIf buttonWidget->name = "keyboard_window_two_action" Then
        keyboardNavigationSecondWindowActivations += 1
    End If
End Sub


' -------------------------------------------------------------------------
' Fixture
' -------------------------------------------------------------------------

backend_Init _
    KEYBOARD_NAVIGATION_SCREEN_WIDTH, _
    KEYBOARD_NAVIGATION_SCREEN_HEIGHT, _
    1
gui_Init()
input_ResetForTest()

Dim As String mnemonicDisplay
Dim As Integer mnemonicKey, mnemonicIndex
AssertTrue _
    gui_ParseMnemonicCaption( _
        "&Connect && Retry", mnemonicDisplay, mnemonicKey, mnemonicIndex _
    ) <> 0 AndAlso mnemonicDisplay = "Connect & Retry" AndAlso _
    mnemonicKey = FB.SC_C AndAlso mnemonicIndex = 0, _
    "access-key caption parser removes markers and preserves escaped ampersands"
AssertTrue _
    gui_ParseMnemonicCaption( _
        "Rock && Roll", mnemonicDisplay, mnemonicKey, mnemonicIndex _
    ) = 0 AndAlso mnemonicDisplay = "Rock & Roll" AndAlso _
    mnemonicKey = 0 AndAlso mnemonicIndex = -1, _
    "escaped ampersands do not create access keys"

Dim As Widget Ptr textWidget
Dim As Widget Ptr labelWidget
Dim As Widget Ptr hiddenButton
Dim As Widget Ptr disabledButton
Dim As Widget Ptr commandButton
Dim As Widget Ptr listWidget
Dim As Widget Ptr htmlWidget
Dim As Widget Ptr checkWidget
Dim As Widget Ptr firstRadio
Dim As Widget Ptr secondRadio
Dim As Widget Ptr defaultButton
Dim As Widget Ptr cancelButton
Dim As Widget Ptr firstWindow
Dim As Widget Ptr secondWindow
Dim As Widget Ptr firstWindowText
Dim As Widget Ptr secondWindowText
Dim As Widget Ptr firstWindowAction
Dim As Widget Ptr secondWindowAction
Dim As ListBoxData Ptr listData
Dim As Integer htmlScrollBefore
Dim As Integer tabOrderValue

textWidget = textbox_Create("keyboard_text", "", 10, 10, 150, 26, 0, 0)
labelWidget = label_Create("keyboard_label", "Name", 170, 10)
hiddenButton = button_Create("keyboard_hidden", "Hidden", 10, 44, 80, 24)
disabledButton = button_Create("keyboard_disabled", "Disabled", 96, 44, 80, 24)
commandButton = button_Create( _
    "keyboard_command", "Connect", 182, 44, 80, 24, _
    @keyboardNavigation_OnActivate _
)
listWidget = listbox_Create("keyboard_list", 10, 76, 150, 80)
htmlWidget = htmlview_Create("keyboard_html", 170, 76, 220, 80)

hiddenButton->visible = 0
disabledButton->enabled = 0
gui_SetMnemonic commandButton, gui_MnemonicScanCode(Asc("c"))
gui_SetMnemonic labelWidget, gui_MnemonicScanCode(Asc("n"))

gui_AddWidget textWidget
gui_AddWidget labelWidget
gui_AddWidget hiddenButton
gui_AddWidget disabledButton
gui_AddWidget commandButton
gui_AddWidget listWidget
gui_AddWidget htmlWidget
AssertTrue _
    gui_SetMnemonicTarget(labelWidget, textWidget) <> 0 AndAlso _
    gui_GetMnemonicTarget(labelWidget) = textWidget, _
    "static caption accepts a registered mnemonic focus target"

listbox_AddItem listWidget, "First"
listbox_AddItem listWidget, "Second"
listbox_AddItem listWidget, "Third"
listData = Cast(ListBoxData Ptr, listWidget->data)

AssertTrue _
    htmlview_SetHtml( _
        htmlWidget, _
        "<h1>Keyboard scroll</h1>" & _
        "<p>First paragraph</p><p>Second paragraph</p>" & _
        "<p>Third paragraph</p><p>Fourth paragraph</p>" _
    ) <> 0, _
    "HTML fixture loads"

' Resolve effective visibility and enabled state before traversal begins.
gui_UpdateAll()

' -------------------------------------------------------------------------
' Focus traversal and button activation
' -------------------------------------------------------------------------

test_Section "focus traversal"

input_MockKeyPress FB.SC_TAB
gui_UpdateAll()
AssertTrue gui_GetFocus() = textWidget, "Tab focuses the first control"
AssertTrue _
    gui_IsKeyboardNavigationActive() <> 0, _
    "keyboard navigation displays the focus cue"

input_MockMouse textWidget->ax + 6, textWidget->ay + 6, 1
gui_UpdateAll()
input_MockMouse textWidget->ax + 6, textWidget->ay + 6, 0
gui_UpdateAll()
AssertTrue _
    gui_IsKeyboardNavigationActive() = 0, _
    "mouse focus hides the keyboard focus cue"

input_MockKeyPress FB.SC_TAB
gui_UpdateAll()
AssertTrue _
    gui_GetFocus() = commandButton, _
    "Tab skips hidden and disabled controls"

input_MockKeyPress KEY_RETURN
gui_UpdateAll()
AssertTrue keyboardNavigationActivations = 1, "Enter activates a button"
AssertTrue gui_ButtonPressed("keyboard_command") <> 0, _
    "keyboard activation is visible to polling applications"

input_MockKeyPress FB.SC_TAB, INPUT_MODIFIER_SHIFT
gui_UpdateAll()
AssertTrue gui_GetFocus() = textWidget, "Shift+Tab traverses backward"

input_MockKeyPress FB.SC_TAB, INPUT_MODIFIER_SHIFT
gui_UpdateAll()
AssertTrue gui_GetFocus() = htmlWidget, "reverse traversal wraps"

AssertTrue _
    gui_SetTabOrder(commandButton, 10) <> 0 AndAlso _
    gui_SetTabOrder(textWidget, 20) <> 0 AndAlso _
    gui_SetTabOrder(listWidget, 30) <> 0 AndAlso _
    gui_SetTabOrder(htmlWidget, 40) <> 0, _
    "explicit tab order is accepted"
AssertTrue _
    gui_GetTabOrder(textWidget, tabOrderValue) <> 0 AndAlso _
    tabOrderValue = 20, _
    "explicit tab order is queryable"
gui_SetFocus 0
input_MockKeyPress FB.SC_TAB
gui_UpdateAll()
AssertTrue _
    gui_GetFocus() = commandButton, _
    "explicit order overrides registration order"
input_MockKeyPress FB.SC_TAB
gui_UpdateAll()
AssertTrue gui_GetFocus() = textWidget, "explicit order advances"
input_MockKeyPress FB.SC_TAB, INPUT_MODIFIER_SHIFT
gui_UpdateAll()
AssertTrue gui_GetFocus() = commandButton, "explicit order reverses"
gui_SetTabOrder commandButton, -1
gui_SetTabOrder textWidget, -1
gui_SetTabOrder listWidget, -1
gui_SetTabOrder htmlWidget, -1
AssertTrue _
    gui_GetTabOrder(textWidget, tabOrderValue) = 0, _
    "negative order restores registration behavior"

checkWidget = checkbox_Create("keyboard_check", "Enabled", 10, 170, 0)
firstRadio = radiobox_Create("keyboard_radio_one", "First", 10, 194, 7, -1)
secondRadio = radiobox_Create("keyboard_radio_two", "Second", 10, 218, 7, 0)
gui_AddWidget checkWidget
gui_AddWidget firstRadio
gui_AddWidget secondRadio

' -------------------------------------------------------------------------
' Lists, HTML scrolling, and mnemonics
' -------------------------------------------------------------------------

test_Section "control keys"

gui_SetFocus checkWidget
input_MockKeyPress FB.SC_SPACE
gui_UpdateAll()
AssertTrue _
    Cast(CheckBoxData Ptr, checkWidget->data)->checked <> 0, _
    "Space toggles a checkbox"

gui_SetFocus secondRadio
input_MockKeyPress FB.SC_SPACE
gui_UpdateAll()
AssertTrue _
    Cast(RadioBoxData Ptr, secondRadio->data)->selected <> 0 AndAlso _
    Cast(RadioBoxData Ptr, firstRadio->data)->selected = 0, _
    "Space selects one radio option and clears its group"

gui_SetFocus listWidget
input_MockKeyPress KEY_DOWN
gui_UpdateAll()
AssertTrue listbox_GetSelectedIndex(listWidget) = 0, _
    "Down selects the first list row"

input_MockKeyPress KEY_DOWN
gui_UpdateAll()
AssertTrue listbox_GetSelectedIndex(listWidget) = 1, _
    "Down advances the list selection"

input_MockKeyPress KEY_RETURN
gui_UpdateAll()
AssertTrue listData->activation_count = 1, "Enter activates a list row"

gui_SetFocus htmlWidget
htmlScrollBefore = htmlview_GetScroll(htmlWidget)
input_MockKeyPress KEY_DOWN
gui_UpdateAll()
AssertTrue _
    htmlview_GetScroll(htmlWidget) > htmlScrollBefore, _
    "Down scrolls a focused HTML document"

input_MockKeyPress FB.SC_N, INPUT_MODIFIER_ALT
gui_UpdateAll()
AssertTrue gui_GetFocus() = textWidget, "Alt+N follows a static caption target"
AssertTrue _
    keyboardNavigationActivations = 1, _
    "static caption focus transfer does not activate its target"

input_MockKeyPress FB.SC_C, INPUT_MODIFIER_ALT
gui_UpdateAll()
AssertTrue gui_GetFocus() = commandButton, "Alt+C focuses its command"
AssertTrue keyboardNavigationActivations = 2, "Alt+C activates its command"

Dim As Widget Ptr temporaryLabel = label_Create( _
    "keyboard_temporary_label", "Temporary", 280, 10 _
)
Dim As Widget Ptr temporaryTarget = textbox_Create( _
    "keyboard_temporary_target", "", 280, 34, 100, 22, 0, 0 _
)
gui_AddWidget temporaryLabel
gui_AddWidget temporaryTarget
gui_SetMnemonic temporaryLabel, gui_MnemonicScanCode(Asc("t"))
AssertTrue _
    gui_SetMnemonicTarget(temporaryLabel, temporaryTarget) <> 0 AndAlso _
    gui_RemoveWidgetPtr(temporaryTarget) <> 0 AndAlso _
    gui_GetMnemonicTarget(temporaryLabel) = 0, _
    "removing a target clears inbound mnemonic references"
gui_RemoveWidgetPtr temporaryLabel

' -------------------------------------------------------------------------
' Default and cancel actions
' -------------------------------------------------------------------------

test_Section "dialog actions"

defaultButton = button_Create( _
    "keyboard_default", "Default", 10, 260, 80, 24, _
    @keyboardNavigation_OnDefault _
)
cancelButton = button_Create( _
    "keyboard_cancel", "Cancel", 96, 260, 80, 24, _
    @keyboardNavigation_OnCancel _
)
gui_AddWidget defaultButton
gui_AddWidget cancelButton
AssertTrue _
    gui_SetDefaultAction(defaultButton, -1) <> 0 AndAlso _
    gui_SetCancelAction(cancelButton, -1) <> 0, _
    "dialog action roles are accepted"
AssertTrue _
    gui_GetDefaultAction(defaultButton) <> 0 AndAlso _
    gui_GetCancelAction(cancelButton) <> 0, _
    "dialog action roles are queryable"
AssertTrue _
    gui_SetDefaultAction(0, -1) = 0 AndAlso _
    gui_SetCancelAction(0, -1) = 0, _
    "null dialog action targets are rejected"

gui_SetFocus textWidget
input_MockKeyPress KEY_RETURN
gui_UpdateAll()
AssertTrue keyboardNavigationDefaultActivations = 1, _
    "Enter activates the default action from a single-line editor"

gui_SetFocus commandButton
input_MockKeyPress KEY_RETURN
gui_UpdateAll()
AssertTrue _
    keyboardNavigationActivations = 3 AndAlso _
    keyboardNavigationDefaultActivations = 1, _
    "a focused button captures Enter before the default action"

gui_SetFocus textWidget
input_MockKeyPress KEY_ESCAPE
gui_UpdateAll()
AssertTrue keyboardNavigationCancelActivations = 1, _
    "Escape activates the cancel action"

cancelButton->enabled = 0
input_MockKeyPress KEY_ESCAPE
gui_UpdateAll()
AssertTrue keyboardNavigationCancelActivations = 1, _
    "a disabled cancel action is not activated"

firstWindow = subwindow_Create( _
    "keyboard_window_one", "First", 190, 170, 105, 112, 0 _
)
secondWindow = subwindow_Create( _
    "keyboard_window_two", "Second", 300, 170, 105, 112, 0 _
)
firstWindowText = textbox_Create( _
    "keyboard_window_one_text", "", 8, 28, 85, 22, 0, 0 _
)
secondWindowText = textbox_Create( _
    "keyboard_window_two_text", "", 8, 28, 85, 22, 0, 0 _
)
firstWindowAction = button_Create( _
    "keyboard_window_one_action", "One", 8, 58, 85, 22, _
    @keyboardNavigation_OnWindowAction _
)
secondWindowAction = button_Create( _
    "keyboard_window_two_action", "Two", 8, 58, 85, 22, _
    @keyboardNavigation_OnWindowAction _
)
gui_AddWidget firstWindow
gui_AddWidget secondWindow
gui_SetParent firstWindowText, firstWindow
gui_SetParent firstWindowAction, firstWindow
gui_SetParent secondWindowText, secondWindow
gui_SetParent secondWindowAction, secondWindow
gui_AddWidget firstWindowText
gui_AddWidget firstWindowAction
gui_AddWidget secondWindowText
gui_AddWidget secondWindowAction
gui_SetDefaultAction firstWindowAction, -1
gui_SetDefaultAction secondWindowAction, -1
gui_UpdateAll()

gui_SetFocus firstWindowText
input_MockKeyPress KEY_RETURN
gui_UpdateAll()
AssertTrue _
    keyboardNavigationFirstWindowActivations = 1 AndAlso _
    keyboardNavigationSecondWindowActivations = 0, _
    "Enter uses the focused control's owning window"

gui_SetFocus secondWindowText
input_MockKeyPress KEY_RETURN
gui_UpdateAll()
AssertTrue _
    keyboardNavigationFirstWindowActivations = 1 AndAlso _
    keyboardNavigationSecondWindowActivations = 1, _
    "dialog actions do not cross window trees"

gui_RenderAll()

' -------------------------------------------------------------------------
' Cleanup and result
' -------------------------------------------------------------------------

gui_ResetForTest()
backend_Exit()
test_Summary()

' end of keyboard_navigation_smoke.bas
