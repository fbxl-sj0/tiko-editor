/'
    Project: omaGUI Tests
    File: button_lifetime_smoke.bas
    Purpose: Verify button activation commits state before application callbacks.
    Responsibilities:
        - detect post-callback writes without accessing freed memory
        - exercise callbacks which destroy their button or complete window tree
        - verify a replacement tree cannot inherit the activating key event
        - retain pointer, Enter, Space, and polled activation behavior
        - accept null widgets and released private data during update
    This file intentionally does NOT contain:
        - host window APIs, allocator instrumentation, or VBDOS event handling
'/
#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

' -------------------------------------------------------------------------
' GUI-thread callback fixtures and shared state
' -------------------------------------------------------------------------

' The test owns detached_data until it is returned to its original widget.
' Keeping it alive makes a stale write observable without undefined behavior.
Dim Shared As ButtonData Ptr detached_data
Dim Shared As Integer callback_count
Dim Shared As Integer callback_state
Dim Shared As Integer replacement_callback_count
Dim Shared As ULongInt removed_registry_id

Private Sub buttonLifetime_Require(ByVal success As Integer, ByVal source_line As Integer)
    If success Then Exit Sub
    Print "button_lifetime_smoke: FAIL at line "; source_line
    End 1
End Sub

Private Sub buttonLifetime_DetachData(ByVal w As Widget Ptr)
    callback_count += 1
    detached_data = Cast(ButtonData Ptr, w->data)
    callback_state = detached_data->state
    detached_data->state = 0
    w->data = 0
    w->has_focus = 0
End Sub

Private Sub buttonLifetime_DestroyButton(ByVal w As Widget Ptr)
    callback_count += 1
    ' This fixture is not registered; the callback owns both allocations.
    button_Destroy w
    Delete w
End Sub

Private Sub buttonLifetime_ReplacementActivated(ByVal w As Widget Ptr)
    If w = 0 Then Exit Sub
    replacement_callback_count += 1
End Sub

Private Sub buttonLifetime_ReplaceTree(ByVal w As Widget Ptr)
    Dim As Widget Ptr replacement_window
    Dim As Widget Ptr replacement_button
    Dim As Widget Ptr replacement_editor
    Dim As Widget Ptr replacement_caption

    If w = 0 Then Exit Sub
    callback_count += 1
    removed_registry_id = w->registry_id
    gui_RemoveWidget "lifetime_window"

    replacement_window = subwindow_Create( _
        "lifetime_replacement_window", "Replacement", 10, 10, 200, 120 _
    )
    If replacement_window = 0 Then Exit Sub
    gui_AddWidget replacement_window

    replacement_button = button_Create( _
        "replacement_button", "Default", 10, 60, 100, 24, _
        @buttonLifetime_ReplacementActivated _
    )
    If replacement_button = 0 Then
        gui_RemoveWidget "lifetime_replacement_window"
        Exit Sub
    End If
    gui_AddWidget replacement_button
    gui_SetParent replacement_button, replacement_window
    If gui_SetDefaultAction(replacement_button, -1) = 0 OrElse _
       gui_SetCancelAction(replacement_button, -1) = 0 Then
        gui_RemoveWidget "lifetime_replacement_window"
        Exit Sub
    End If

    replacement_editor = textbox_Create( _
        "replacement_editor", "", 10, 30, 120, 24, 0, 0 _
    )
    If replacement_editor = 0 Then
        gui_RemoveWidget "lifetime_replacement_window"
        Exit Sub
    End If
    gui_AddWidget replacement_editor
    gui_SetParent replacement_editor, replacement_window
    gui_SetFocus replacement_editor

    replacement_caption = label_Create( _
        "replacement_caption", "Replacement", 10, 90 _
    )
    If replacement_caption = 0 Then
        gui_RemoveWidget "lifetime_replacement_window"
        Exit Sub
    End If
    gui_AddWidget replacement_caption
    gui_SetParent replacement_caption, replacement_window
    gui_SetMnemonic replacement_caption, FB.SC_R
    If gui_SetMnemonicTarget(replacement_caption, replacement_button) = 0 Then
        gui_RemoveWidget "lifetime_replacement_window"
        Exit Sub
    End If
End Sub

Private Sub buttonLifetime_Pointer(ByVal x As Integer, ByVal y As Integer, ByVal buttons As Integer)
    input_MockMouse x, y, buttons
    gui_UpdateAll
End Sub

' -------------------------------------------------------------------------
' A release must finish its state writes before dispatching the callback
' -------------------------------------------------------------------------

backend_Init 320, 240, BACKEND_HEADLESS
gui_Init
input_ResetForTest
Dim As Widget Ptr button_widget = button_Create( _
    "lifetime_button", "Detach", 10, 10, 100, 24, @buttonLifetime_DetachData _
)
buttonLifetime_Require button_widget <> 0, __LINE__
gui_AddWidget button_widget
buttonLifetime_Pointer 20, 20, 1
buttonLifetime_Pointer 20, 20, 0
buttonLifetime_Require callback_count = 1 AndAlso detached_data <> 0, __LINE__
buttonLifetime_Require callback_state = 1, __LINE__
buttonLifetime_Require detached_data->state = 0, __LINE__
button_widget->data = detached_data
detached_data = 0
gui_RemoveWidget "lifetime_button"

button_Update 0
Dim As Widget empty_widget
button_Update @empty_widget

' -------------------------------------------------------------------------
' Direct update callers may release the entire unregistered widget
' -------------------------------------------------------------------------

For input_method As Integer = 0 To 2
    input_ResetForTest
    callback_count = 0
    button_widget = button_Create("direct_button", "Destroy", 10, 10, 100, 24, @buttonLifetime_DestroyButton)
    buttonLifetime_Require button_widget <> 0, __LINE__
    button_widget->ax = 10
    button_widget->ay = 10
    button_widget->has_focus = -1
    If input_method = 0 Then
        input_MockMouse 20, 20, 1
        input_Update
        button_Update button_widget
        input_MockMouse 20, 20, 0
        ' A simultaneous key must not dispatch a second activation after
        ' the pointer callback has destroyed this widget.
        input_MockKeyPress KEY_RETURN
    ElseIf input_method = 1 Then
        input_MockKeyPress KEY_RETURN
    Else
        input_MockKeyPress FB.SC_SPACE
    End If
    input_Update
    button_Update button_widget
    button_widget = 0
    buttonLifetime_Require callback_count = 1, __LINE__
Next input_method

' Registry callbacks remove the whole tree through the manager, not Delete.
For input_method As Integer = 0 To 2
    input_ResetForTest
    callback_count = 0
    replacement_callback_count = 0
    removed_registry_id = 0
    Dim As Widget Ptr window_widget = subwindow_Create("lifetime_window", "Lifetime", 10, 10, 200, 120)
    button_widget = button_Create("tree_button", "Replace", 10, 30, 100, 24, @buttonLifetime_ReplaceTree)
    buttonLifetime_Require window_widget <> 0 AndAlso button_widget <> 0, __LINE__
    gui_AddWidget window_widget
    gui_AddWidget button_widget
    gui_SetParent button_widget, window_widget
    gui_SetFocus button_widget
    If input_method = 0 Then
        buttonLifetime_Pointer 30, 50, 1
        buttonLifetime_Pointer 30, 50, 0
    Else
        If input_method = 1 Then
            input_MockKeyPress KEY_RETURN
            input_MockKeyPress FB.SC_R, INPUT_MODIFIER_ALT
        Else
            input_MockKeyPress FB.SC_SPACE
            input_MockKeyPress KEY_ESCAPE
        End If
        gui_UpdateAll
    End If
    buttonLifetime_Require callback_count = 1, __LINE__
    buttonLifetime_Require gui_FindWidget("lifetime_window") = 0, __LINE__
    buttonLifetime_Require gui_FindWidget("tree_button") = 0, __LINE__
    buttonLifetime_Require replacement_callback_count = 0, __LINE__
    buttonLifetime_Require removed_registry_id <> 0, __LINE__
    button_widget = gui_FindWidget("replacement_button")
    buttonLifetime_Require button_widget <> 0, __LINE__
    buttonLifetime_Require button_widget->registry_id <> removed_registry_id, __LINE__
    buttonLifetime_Require gui_GetFocus() = gui_FindWidget("replacement_editor"), __LINE__
    gui_RemoveWidget "lifetime_replacement_window"
Next input_method

' -------------------------------------------------------------------------
' Buttons without callbacks still expose one-frame polled activation
' -------------------------------------------------------------------------

input_ResetForTest
button_widget = button_Create("polled_button", "Poll", 10, 10, 100, 24)
buttonLifetime_Require button_widget <> 0, __LINE__
gui_AddWidget button_widget
buttonLifetime_Pointer 20, 20, 1
buttonLifetime_Require gui_ButtonPressed("polled_button") = 0, __LINE__
buttonLifetime_Pointer 20, 20, 0
buttonLifetime_Require gui_ButtonPressed("polled_button") <> 0, __LINE__
buttonLifetime_Require Cast(ButtonData Ptr, button_widget->data)->state = 1, __LINE__
buttonLifetime_Pointer 20, 20, 0
buttonLifetime_Require gui_ButtonPressed("polled_button") = 0, __LINE__
buttonLifetime_Pointer 20, 20, 1
buttonLifetime_Pointer 200, 200, 0
buttonLifetime_Require gui_ButtonPressed("polled_button") = 0, __LINE__
For input_method As Integer = 0 To 1
    input_MockKeyPress IIf(input_method = 0, KEY_RETURN, FB.SC_SPACE)
    gui_UpdateAll
    buttonLifetime_Require gui_ButtonPressed("polled_button") <> 0, __LINE__
    gui_UpdateAll
    buttonLifetime_Require gui_ButtonPressed("polled_button") = 0, __LINE__
Next input_method

gui_ResetForTest
backend_Exit
Print "button_lifetime_smoke: PASS (callback state, destruction, null guards, pointer and keyboard)"
End 0
/' end of button_lifetime_smoke.bas '/
