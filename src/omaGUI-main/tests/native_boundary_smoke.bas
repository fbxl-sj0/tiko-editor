/'
    Project: omaGUI tests
    File: native_boundary_smoke.bas
    Purpose: Verify native imports coexist with application handles and menus.
    Responsibilities: Exercise popup removal without touching the host clipboard.
    This file does not open a desktop window or write application files.
'/
#lang "fb"
' winnt.bi publishes this global access mask in applications importing Win32.
Const SYNCHRONIZE As Long = &h00100000
Type HWND As Any Ptr
Type HMENU As Any Ptr
Type MSG
    As Integer application_value
End Type
#define OMAGUI_ENABLE_HOST_CLIPBOARD
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

backend_Init 320, 200, BACKEND_HEADLESS
gui_Init
input_ResetForTest
Dim As Widget Ptr bar = menubar_Create("boundary_bar", 0, 0, 320)
Dim As Widget Ptr popup = menu_Create("boundary_popup", 0, 0)
If bar = 0 OrElse popup = 0 Then End 1
gui_AddWidget bar
menu_AddCommand popup, "Open", 1
Dim As Integer headingIndex = menubar_AddMenu(bar, "File")
If menubar_SetMenuPopup(bar, headingIndex, popup) = 0 Then End 2
If menubar_GetMenuPopup(bar, headingIndex) <> popup Then End 3
If menubar_ClearMenuPopup(bar, headingIndex) = 0 Then End 4
If menubar_GetMenuPopup(bar, headingIndex) <> 0 Then End 5
If gui_IsWidgetRegistered(popup) <> 0 Then End 6
If menubar_ClearMenuPopup(bar, headingIndex) = 0 Then End 7
If menubar_ClearMenuPopup(bar, -1) <> 0 Then End 8
gui_ResetForTest
backend_Exit
Print "NATIVE_BOUNDARY_SMOKE_PASS checks=8"
End 0
' end of native_boundary_smoke.bas
