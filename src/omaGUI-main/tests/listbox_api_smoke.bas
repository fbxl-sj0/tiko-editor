/'
    Project: omaGUI Tests
    ---------------------

    File: listbox_api_smoke.bas

    Purpose:

        Verify checked list selection and double-activation interfaces.

    Responsibilities:

        - query the bounded item count without reaching into widget data
        - select an existing item and keep it within the visible viewport
        - reject an out-of-range item without corrupting selection
        - explicitly clear a selection
        - expose explicit activation through the same retained event counter
        - distinguish timely same-row pointer clicks from different-row clicks

    This file intentionally does NOT contain:

        - keyboard input simulation
        - application-specific list content
        - native desktop-window interaction
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim As Widget Ptr list_widget
Dim As ListBoxData Ptr list_data
Dim As Integer item_index
Dim As Integer failure_count

backend_Init 320, 240, -1
gui_Init
list_widget = listbox_Create("listbox_api", 10, 10, 180, 64)
If list_widget = 0 Then
    Print "listbox_api_smoke: constructor failed"
    backend_Exit
    End 1
End If
gui_AddWidget list_widget
For item_index = 0 To 19
    listbox_AddItem list_widget, "Item " & LTrim(Str(item_index))
Next item_index
list_data = Cast(ListBoxData Ptr, list_widget->data)

If listbox_GetItemCount(list_widget) <> 20 OrElse _
   listbox_GetItemCount(0) <> 0 Then
    Print "FAIL querying item count"
    failure_count += 1
End If
If listbox_SetSelectedIndex(list_widget, 18) = 0 OrElse _
   listbox_GetSelectedIndex(list_widget) <> 18 OrElse _
   listbox_GetSelectedItem(list_widget) <> "Item 18" OrElse _
   list_data->scroll_top = 0 Then
    Print "FAIL selecting and revealing item 18"
    failure_count += 1
End If
If listbox_SetSelectedIndex(list_widget, 20) <> 0 OrElse _
   listbox_GetSelectedIndex(list_widget) <> 18 Then
    Print "FAIL rejecting an out-of-range selection"
    failure_count += 1
End If
If listbox_GetActivationCount(list_widget) <> 0 OrElse _
   listbox_ActivateSelected(list_widget) = 0 OrElse _
   listbox_GetActivationCount(list_widget) <> 1 OrElse _
   listbox_GetActivationCount(0) <> 0 Then
    Print "FAIL explicit selected-row activation"
    failure_count += 1
End If
If listbox_SetSelectedIndex(list_widget, 2) = 0 OrElse _
   listbox_DoubleActivateSelected(list_widget) = 0 OrElse _
   listbox_GetActivationCount(list_widget) <> 2 OrElse _
   listbox_GetDoubleActivationCount(list_widget) <> 1 OrElse _
   listbox_GetDoubleActivationCount(0) <> 0 Then
    Print "FAIL explicit selected-row double activation"
    failure_count += 1
End If

' The next two releases are close enough to form one physical double click.
If listbox_SetSelectedIndex(list_widget, 0) = 0 Then failure_count += 1
' Resolve absolute geometry before deriving mock pointer coordinates.
gui_UpdateAll
input_MockMouse list_widget->ax + 4, list_widget->ay + 4, 1
gui_UpdateAll
input_MockMouse list_widget->ax + 4, list_widget->ay + 4, 0
gui_UpdateAll
If listbox_GetActivationCount(list_widget) <> 3 OrElse _
   listbox_GetDoubleActivationCount(list_widget) <> 1 Then
    Print "FAIL first pointer activation"
    failure_count += 1
End If
input_MockMouse list_widget->ax + 4, list_widget->ay + 4, 1
gui_UpdateAll
input_MockMouse list_widget->ax + 4, list_widget->ay + 4, 0
gui_UpdateAll
If listbox_GetActivationCount(list_widget) <> 4 OrElse _
   listbox_GetDoubleActivationCount(list_widget) <> 2 Then
    Print "FAIL same-row pointer double activation"
    failure_count += 1
End If

' Two prompt clicks on different rows remain two ordinary activations.
input_MockMouse list_widget->ax + 4, list_widget->ay + 20, 1
gui_UpdateAll
input_MockMouse list_widget->ax + 4, list_widget->ay + 20, 0
gui_UpdateAll
input_MockMouse list_widget->ax + 4, list_widget->ay + 4, 1
gui_UpdateAll
input_MockMouse list_widget->ax + 4, list_widget->ay + 4, 0
gui_UpdateAll
If listbox_GetActivationCount(list_widget) <> 6 OrElse _
   listbox_GetDoubleActivationCount(list_widget) <> 2 Then
    Print "FAIL different-row pointer activation"
    failure_count += 1
End If
If listbox_SetSelectedIndex(list_widget, -1) = 0 OrElse _
   listbox_GetSelectedIndex(list_widget) <> -1 Then
    Print "FAIL clearing selection"
    failure_count += 1
End If
If listbox_ActivateSelected(list_widget) <> 0 OrElse _
   listbox_DoubleActivateSelected(list_widget) <> 0 OrElse _
   listbox_GetActivationCount(list_widget) <> 6 OrElse _
   listbox_GetDoubleActivationCount(list_widget) <> 2 Then
    Print "FAIL rejecting activation without a selected row"
    failure_count += 1
End If

gui_ResetForTest
backend_Exit
If failure_count <> 0 Then
    Print "listbox_api_smoke: "; failure_count; " failure(s)"
    End 1
End If
Print "listbox_api_smoke: PASS"
End 0

/' end of listbox_api_smoke.bas '/
