/'
    Project: omaGUI Tests
    ---------------------

    File: confirmdialog_smoke.bas

    Purpose:

        Verify legacy confirmation and reusable three-choice dialog results.

    Responsibilities:

        - preserve the established confirm/cancel child names and values
        - keep Enter activation on the plain legacy confirmation button
        - expose caller-selected values for one to three action buttons
        - reject an invalid empty primary choice

    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:

        - application-specific message-box policy
        - platform-native dialogs
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub confirmSmoke_Require( _
    ByVal success As Integer, ByVal sourceLine As Integer _
)
    If success Then Exit Sub
    Print "confirmdialog_smoke: FAIL at line "; sourceLine
    gui_ResetForTest
    backend_Exit
    End 1
End Sub

backend_Init 640, 480, -1
gui_Init

Dim As Widget Ptr dialogWidget = confirmdialog_Create( _
    "confirm_smoke", "Confirm", "Discard changes?", 70, 70, "Discard" _
)
confirmSmoke_Require dialogWidget <> 0, __LINE__
confirmSmoke_Require gui_IsWidgetRegistered(dialogWidget) AndAlso _
    gui_IsModalOpen(), __LINE__
gui_AddWidget dialogWidget
confirmSmoke_Require dialogWidget->name = "confirm_smoke", __LINE__
confirmSmoke_Require gui_FindWidget("confirm_smoke_confirm") <> 0 AndAlso _
    gui_FindWidget("confirm_smoke_cancel") <> 0, __LINE__
button_Activate gui_FindWidget("confirm_smoke_cancel")
confirmSmoke_Require confirmdialog_GetResultState(dialogWidget) = -1, __LINE__
gui_RemoveWidget "confirm_smoke"

dialogWidget = confirmdialog_Create( _
    "confirm_default_smoke", "Confirm", "Discard changes?", 70, 70, "Discard" _
)
confirmSmoke_Require dialogWidget <> 0, __LINE__
confirmSmoke_Require gui_IsWidgetRegistered(dialogWidget) AndAlso _
    gui_IsModalOpen(), __LINE__
gui_AddWidget dialogWidget
input_ResetForTest
input_MockKeyPress KEY_RETURN
gui_UpdateAll
confirmSmoke_Require confirmdialog_GetResultState(dialogWidget) = 1, __LINE__
gui_RemoveWidget "confirm_default_smoke"

dialogWidget = confirmdialog_CreateChoices( _
    "choice_smoke", "Question", "Save changes?", 70, 70, _
    "Yes", 6, "No", 7, "Cancel", 2, 2 _
)
confirmSmoke_Require dialogWidget <> 0, __LINE__
confirmSmoke_Require gui_IsWidgetRegistered(dialogWidget) AndAlso _
    gui_IsModalOpen(), __LINE__
gui_AddWidget dialogWidget
confirmSmoke_Require gui_FindWidget("choice_smoke_choice_0") <> 0 AndAlso _
    gui_FindWidget("choice_smoke_choice_1") <> 0 AndAlso _
    gui_FindWidget("choice_smoke_choice_2") <> 0, __LINE__
button_Activate gui_FindWidget("choice_smoke_choice_1")
confirmSmoke_Require confirmdialog_GetResultState(dialogWidget) = 7, __LINE__
gui_RemoveWidget "choice_smoke"

confirmSmoke_Require confirmdialog_CreateChoices( _
    "invalid_choice", "Invalid", "Missing", 0, 0, "", 1 _
) = 0, __LINE__

gui_ResetForTest
backend_Exit
Print "confirmdialog_smoke: PASS (legacy and three-choice results)"
End 0

/' end of confirmdialog_smoke.bas '/
