/'
    Project: omaGUI Tests
    ---------------------

    File: inputdialog_smoke.bas

    Purpose:

        Verify bounded modal text and option result handling.

    Responsibilities:

        - construct a two-field prompt with two options
        - change generated controls and accept the dialog
        - verify copied text, boolean choices, and result state
        - verify unmodified Escape reports cancellation through the dialog

    This file intentionally does NOT contain:

        - application-specific validation
        - native desktop interaction
        - screenshot comparisons
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim As Widget Ptr accept_button
Dim As Widget Ptr cancel_button
Dim As Widget Ptr cancel_dialog
Dim As Widget Ptr dialog_widget
Dim As Widget Ptr second_field
Dim As Widget Ptr second_option
Dim As Integer failure_count

backend_Init 640, 480, -1
gui_Init
dialog_widget = inputdialog_Create( _
    "input_smoke", "Change", "Find what", "alpha", _
    "Change to", "beta", "Match case", 0, "Whole word", -1, _
    70, 70, "Change" _
)
gui_AddWidget dialog_widget
second_field = gui_FindWidget("input_smoke_field_1")
second_option = gui_FindWidget("input_smoke_option_1")
accept_button = gui_FindWidget("input_smoke_accept")
If dialog_widget = 0 OrElse second_field = 0 OrElse _
   second_option = 0 OrElse accept_button = 0 Then
    Print "FAIL generated input controls"
    failure_count += 1
Else
    textbox_SetText second_field, "gamma", -1
    checkbox_Activate second_option
    button_Activate accept_button
    If inputdialog_GetResultState(dialog_widget) <> 1 OrElse _
       inputdialog_GetText(dialog_widget, 0) <> "alpha" OrElse _
       inputdialog_GetText(dialog_widget, 1) <> "gamma" OrElse _
       inputdialog_GetOption(dialog_widget, 0) <> 0 OrElse _
       inputdialog_GetOption(dialog_widget, 1) <> 0 Then
        Print "FAIL accepted input result"
        failure_count += 1
    End If
End If

cancel_dialog = inputdialog_Create( _
    "input_cancel_smoke", "Cancel", "Value", "unchanged", "", "", _
    "", 0, "", 0, 70, 70, "Apply" _
)
gui_AddWidget cancel_dialog
cancel_button = gui_FindWidget("input_cancel_smoke_cancel")
If cancel_dialog = 0 OrElse cancel_button = 0 OrElse _
   gui_GetCancelAction(cancel_button) = 0 Then
    Print "FAIL Escape cancel action registration"
    failure_count += 1
Else
    input_MockKeyPress KEY_ESCAPE
    gui_UpdateAll
    If inputdialog_GetResultState(cancel_dialog) <> -1 OrElse _
       inputdialog_GetText(cancel_dialog, 0) <> "unchanged" Then
        Print "FAIL Escape cancel result"
        failure_count += 1
    End If
End If

backend_Clear RGB(220, 220, 220)
gui_UpdateAll
gui_RenderAll
backend_Flip
gui_ResetForTest
backend_Exit

If failure_count <> 0 Then
    Print "inputdialog_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "inputdialog_smoke: PASS"
End 0

/' end of inputdialog_smoke.bas '/
