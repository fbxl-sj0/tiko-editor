/'
    Project: omaGUI Tests
    ---------------------

    File: filesystemlistbox_smoke.bas

    Purpose:

        Verify portable directory, drive, and file list factories.

    Responsibilities:

        - enumerate known repository directories and files
        - require stable case-insensitive ordering
        - distinguish unsafe patterns and missing paths without mutation
        - expose and select the current host drive or filesystem root

    This file intentionally does NOT contain:

        - host file mutations
        - modal file dialog interaction
        - platform SDK calls
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

#If Defined(__FB_WIN32__)
Const TEST_PATH_SEPARATOR As String = "\"
#Else
Const TEST_PATH_SEPARATOR As String = "/"
#EndIf

Private Function filesystemlistboxSmoke_HasItem( _
    ByVal w As Widget Ptr, _
    ByRef itemText As Const String _
) As Integer
    Dim As ListBoxData Ptr listData
    Dim As Integer itemIndex

    If w = 0 OrElse w->data = 0 Then Return 0
    listData = Cast(ListBoxData Ptr, w->data)
    For itemIndex = 0 To listData->item_count - 1
        If LCase(listData->items(itemIndex)) = LCase(itemText) Then Return -1
    Next itemIndex
    Return 0
End Function


Dim As Widget Ptr directory_widget
Dim As Widget Ptr drive_widget
Dim As Widget Ptr file_widget
Dim As ListBoxData Ptr file_data
Dim As String assets_path
Dim As String source_path
Dim As Integer failure_count
Dim As Integer original_file_count
Dim As String current_drive

backend_Init 480, 300, -1
gui_Init

source_path = CurDir & TEST_PATH_SEPARATOR & "src"
assets_path = CurDir & TEST_PATH_SEPARATOR & "tests" & _
    TEST_PATH_SEPARATOR & "assets"

directory_widget = directorylistbox_Create( _
    "directories", 10, 10, 140, 120, source_path _
)
file_widget = filelistbox_Create( _
    "files", 160, 10, 180, 120, assets_path, "*.html" _
)
drive_widget = drivelistbox_Create("drives", 350, 10, 120, 120)

If directory_widget = 0 OrElse file_widget = 0 OrElse drive_widget = 0 Then
    Print "filesystemlistbox_smoke: constructor failed"
    gui_ResetForTest
    backend_Exit
    End 1
End If
gui_AddWidget directory_widget
gui_AddWidget file_widget
gui_AddWidget drive_widget

If filesystemlistboxSmoke_HasItem(directory_widget, "backend") = 0 OrElse _
   filesystemlistboxSmoke_HasItem(directory_widget, "images") = 0 OrElse _
   filesystemlistboxSmoke_HasItem(directory_widget, "widgets") = 0 Then
    Print "FAIL directory enumeration"
    failure_count += 1
End If
If filesystemlistboxSmoke_HasItem(file_widget, "htmlview_sample.html") = 0 Then
    Print "FAIL file-pattern enumeration"
    failure_count += 1
End If

file_data = Cast(ListBoxData Ptr, file_widget->data)
original_file_count = file_data->item_count
If filelistbox_Refresh(file_widget, assets_path, "..\*.html") <> 0 OrElse _
   file_data->item_count <> original_file_count Then
    Print "FAIL unsafe pattern rejection"
    failure_count += 1
End If
If filelistbox_TryRefresh(file_widget, assets_path, "..\*.html") <> _
   FILESYSTEMLISTBOX_REFRESH_INVALID_PATTERN Then
    Print "FAIL unsafe pattern status"
    failure_count += 1
End If
#If Defined(__FB_WIN32__)
current_drive = UCase(Left(CurDir, 2))
#Else
current_drive = TEST_PATH_SEPARATOR
#EndIf
If Cast(ListBoxData Ptr, drive_widget->data)->item_count < 1 OrElse _
   filesystemlistboxSmoke_HasItem(drive_widget, current_drive) = 0 OrElse _
   LCase(listbox_GetSelectedItem(drive_widget)) <> LCase(current_drive) Then
    Print "FAIL host root enumeration"
    Print "  current="; current_drive; " selected="; _
        listbox_GetSelectedItem(drive_widget)
    For item_index As Integer = 0 To _
        Cast(ListBoxData Ptr, drive_widget->data)->item_count - 1
        Print "  drive["; item_index; "]="; _
            Cast(ListBoxData Ptr, drive_widget->data)->items(item_index)
    Next item_index
    failure_count += 1
End If

listbox_SetSelectedIndex file_widget, 0
If filelistbox_Refresh(file_widget, assets_path & TEST_PATH_SEPARATOR & _
    "missing_directory", "*") <> 0 OrElse file_data->item_count <> original_file_count OrElse _
    listbox_GetSelectedIndex(file_widget) <> 0 Then
    Print "FAIL invalid path must preserve content and selection"
    failure_count += 1
End If
If filelistbox_TryRefresh(file_widget, assets_path & TEST_PATH_SEPARATOR & _
   "missing_directory", "*") <> FILESYSTEMLISTBOX_REFRESH_INVALID_PATH Then
    Print "FAIL invalid path status"
    failure_count += 1
End If
If filelistbox_Refresh(file_widget, assets_path, "*") = 0 Then
    Print "FAIL valid path refresh"
    failure_count += 1
End If
If filelistbox_TryRefresh(file_widget, assets_path, "*") <> _
   FILESYSTEMLISTBOX_REFRESH_OK Then
    Print "FAIL successful refresh status"
    failure_count += 1
End If
For item_index As Integer = 1 To file_data->item_count - 1
    If LCase(file_data->items(item_index - 1)) > LCase(file_data->items(item_index)) Then
        Print "FAIL entry ordering"
        failure_count += 1
        Exit For
    End If
Next item_index
If filelistbox_Refresh(file_widget, assets_path, "no_such_omagui_test_file.*") = 0 OrElse _
   listbox_GetItemCount(file_widget) <> 0 Then
    Print "FAIL empty match set is a successful refresh"
    failure_count += 1
End If

gui_ResetForTest
backend_Exit

If failure_count <> 0 Then
    Print "filesystemlistbox_smoke: "; failure_count; " failure(s)"
    End 1
End If

Print "filesystemlistbox_smoke: PASS"
End 0

/' end of filesystemlistbox_smoke.bas '/
