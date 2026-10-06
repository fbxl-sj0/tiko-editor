/'
    Project: omaGUI Tests
    File: message_dialog_smoke.bas
    Purpose: verify portable message layout, choices, and failed construction.
    Responsibilities: exercise public factories, modal input, and tree cleanup.
    This file intentionally does NOT contain: operating-system dialog calls.
'/
#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim Shared As Integer checks
Private Sub Require(ByVal accepted As Integer, ByVal sourceLine As Integer)
    checks += 1
    If accepted Then Exit Sub
    Print "message_dialog_smoke: FAIL at line "; sourceLine
    gui_ResetForTest
    backend_Exit
    End 1
End Sub

Dim As Integer captureMode = (Command(1) = "--capture")
backend_Init 640, 480, IIf(captureMode, 0, BACKEND_HEADLESS)
gui_Init
Dim As ConfirmDialogOptions options
Dim As Widget Ptr root, actionButton, messageLabel, windowWidget
Dim As String messageText = "The imported form could not open its data file." & Chr(13) & Chr(10) & _
    "Check the project directory and select Retry. Your unsaved changes remain available." & Chr(10) & _
    "This message wraps within the dialog and leaves room for its action buttons."
options.width = 340
options.maximum_height = 460
options.icon_kind = CONFIRM_ICON_WARNING
options.default_choice = 1
root = confirmdialog_CreateChoicesEx("wrapped", "Import", messageText, 12, 12, options, "Retry", 4, "Cancel", 2, "", 0, 2)
Require root <> 0, __LINE__
gui_AddWidget root
actionButton = confirmdialog_GetActionButton(root, 1)
Require actionButton <> 0, __LINE__
Require gui_GetDefaultAction(actionButton), __LINE__
Require gui_GetFocus() = actionButton, __LINE__
Require confirmdialog_GetActionButton(root, -1) = 0, __LINE__
Require confirmdialog_GetActionButton(root, 2) = 0, __LINE__
Require confirmdialog_GetActionButton(actionButton, 0) = 0, __LINE__
Require confirmdialog_GetResultState(actionButton) = 0, __LINE__
messageLabel = gui_FindWidget("wrapped_message")
windowWidget = gui_FindWidget("wrapped_window")
Dim As Integer windowOption
Require subwindow_GetMinButton(windowWidget, windowOption) AndAlso windowOption = 0, __LINE__
Require subwindow_GetMaxButton(windowWidget, windowOption) AndAlso windowOption = 0, __LINE__
Require subwindow_GetBorderStyle(windowWidget, windowOption) AndAlso windowOption = SUBWINDOW_BORDER_FIXED_SINGLE, __LINE__
Require label_GetText(messageLabel) = messageText, __LINE__
Require label_GetRenderedLineCount(messageLabel) > 3, __LINE__
Require windowWidget->h > 150 AndAlso windowWidget->h <= options.maximum_height, __LINE__
Require messageLabel->y + messageLabel->h < actionButton->y, __LINE__
Require gui_FindWidget("wrapped_icon") <> 0, __LINE__
gui_UpdateAll
backend_Clear RGB(225, 225, 225)
gui_RenderAll
If captureMode Then
    Require Len(Command(2)) > 0, __LINE__
    Require BSave(Command(2), 0) = 0, __LINE__
End If
input_MockKeyPress KEY_RETURN
gui_UpdateAll
Require confirmdialog_GetResultState(root) = 2, __LINE__
Require gui_RemoveWidgetPtr(root), __LINE__
Require gui_FindWidget("wrapped_message") = 0 AndAlso gui_FindWidget("wrapped_icon") = 0, __LINE__
Require gui_IsModalOpen() = 0, __LINE__

' A failed extended factory must not disturb an already open modal dialog.
root = confirmdialog_Create("existing", "Existing", "Keep this open", 4, 4)
Require root <> 0, __LINE__
gui_AddWidget root
options.maximum_height = 150
Require confirmdialog_CreateChoicesEx("too_tall", "Import", messageText, 0, 0, options, "OK", 1, "Cancel", 2) = 0, __LINE__
Require gui_FindWidget("too_tall_window") = 0 AndAlso gui_FindWidget("too_tall_message") = 0, __LINE__
Require gui_IsModalOpen(), __LINE__
options.default_choice = 2
Require confirmdialog_CreateChoicesEx("bad_choice", "Import", "Text", 0, 0, options, "OK", 1) = 0, __LINE__
options.default_choice = 0
options.width = 319
Require confirmdialog_CreateChoicesEx("bad_width", "Import", "Text", 0, 0, options, "OK", 1) = 0, __LINE__
options.width = 400
Require confirmdialog_CreateChoicesEx("too_long", "Import", String(16385, "a"), 0, 0, options, "OK", 1) = 0, __LINE__
options.icon_kind = 5
Require confirmdialog_CreateChoicesEx("bad_icon", "Import", "Text", 0, 0, options, "OK", 1) = 0, __LINE__
Require confirmdialog_GetActionButton(0, 0) = 0, __LINE__
gui_RemoveWidgetPtr root

' Repeated creation/removal exercises ownership of every optional icon and
' action count. Render calls cover the same portable drawing callbacks.
options = Type<ConfirmDialogOptions>()
For iteration As Integer = 1 To 100
    options.icon_kind = iteration Mod 5
    root = confirmdialog_CreateChoicesEx("cycle", "Message", "Choose an action.", 0, 0, options, "Yes", 6, "No", 7, "Cancel", 2, 2)
    Require root <> 0, __LINE__
    gui_AddWidget root
    gui_UpdateAll
    gui_RenderAll
    button_Activate confirmdialog_GetActionButton(root, 2)
    Require confirmdialog_GetResultState(root) = 2, __LINE__
    Require gui_RemoveWidgetPtr(root), __LINE__
    Require gui_IsModalOpen() = 0 AndAlso gui_FindWidget("cycle_window") = 0, __LINE__
Next iteration
gui_ResetForTest
backend_Exit
Print "message_dialog_smoke: PASS checks="; checks
End 0

/' end of message_dialog_smoke.bas '/
