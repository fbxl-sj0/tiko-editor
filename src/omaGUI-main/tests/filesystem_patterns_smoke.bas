/'
    Project: omaGUI tests
    File: filesystem_patterns_smoke.bas
    Purpose: Verify native multi-pattern listing and filesystem roots.
    Responsibilities:
        - check sorting, overlap, empty matches, and transactional failure
        - retain the single-pattern API's literal semicolon behavior
        - create and remove only this test's private fixture paths
    This file intentionally does NOT contain:
        - platform SDK calls, recursive cleanup, or VB runtime dependencies

    Targets: FreeBASIC fb dialect with the native omaGUI backend.
    Module API boundary: Standalone development checks for the behavior described above.
'/

#lang "fb"
#define OMAGUI_IMPLEMENTATION
#define OMAGUI_PORTABLE_ONLY
#include once "omaGUI.bi"

Dim As Integer failures
Dim As String fixture_root
For attempt As Integer = 1 To 1000
    Dim As String candidate = ExePath & "/filesystem_patterns_" & LTrim(Str(attempt))
    If MkDir(candidate) = 0 Then
        fixture_root = candidate
        Exit For
    End If
Next attempt
If Len(fixture_root) = 0 Then End 1
Dim As String fixture_names(0 To 4) = {"alpha.bmp", "beta.ico", "literal;name.dat", "ignored.txt", "README"}
Dim As Integer created_count
For item_index As Integer = 0 To 4
    Dim As Integer file_number = FreeFile
    If Open(fixture_root & "/" & fixture_names(item_index) For Output As #file_number) <> 0 Then Exit For
    Close #file_number
    created_count += 1
Next item_index
If created_count <> 5 Then failures += 1
Dim As Integer created_empty = IIf(MkDir(fixture_root & "/empty") = 0, -1, 0)
If created_empty = 0 Then failures += 1
backend_Init 320, 200, -1
gui_Init
Dim As Widget Ptr file_widget = listbox_Create("patterns", 10, 10, 200, 100)
Dim As Widget Ptr wrong_widget = label_Create("wrong_type", "label", 0, 0)
If file_widget = 0 OrElse wrong_widget = 0 Then End 1
gui_AddWidget file_widget
gui_AddWidget wrong_widget
Dim As String previous_directory = CurDir
If filelistbox_TryRefreshPatterns(file_widget, fixture_root, " *.ico ; *.bmp ; alpha.* ") <> FILESYSTEMLISTBOX_REFRESH_OK Then failures += 1
If listbox_GetItemCount(file_widget) <> 2 Then failures += 1
Dim As String item_text
listbox_GetItem file_widget, 0, item_text
If item_text <> "alpha.bmp" Then failures += 1
listbox_GetItem file_widget, 1, item_text
If item_text <> "beta.ico" Then failures += 1
listbox_SetSelectedIndex file_widget, 1
Dim As String invalid_patterns(0 To 4) = {"*.bmp;;*.ico", "*.bmp;", ";*.bmp", "*.bmp;../*", "*.bmp;\*"}
For item_index As Integer = 0 To 4
    If filelistbox_TryRefreshPatterns(file_widget, fixture_root, invalid_patterns(item_index)) <> FILESYSTEMLISTBOX_REFRESH_INVALID_PATTERN Then failures += 1
    If listbox_GetItemCount(file_widget) <> 2 OrElse listbox_GetSelectedItem(file_widget) <> "beta.ico" Then failures += 1
Next item_index
If filelistbox_TryRefreshPatterns(file_widget, fixture_root & "/missing", "*") <> FILESYSTEMLISTBOX_REFRESH_INVALID_PATH Then failures += 1
If filelistbox_TryRefreshPatterns(file_widget, fixture_root & "/ignored.txt", "*") <> FILESYSTEMLISTBOX_REFRESH_INVALID_PATH Then failures += 1
If filelistbox_TryRefreshPatterns(wrong_widget, fixture_root, "*") <> FILESYSTEMLISTBOX_REFRESH_INVALID_WIDGET Then failures += 1
If filelistbox_TryRefresh(file_widget, fixture_root, "literal;name.dat") <> FILESYSTEMLISTBOX_REFRESH_OK OrElse _
    listbox_GetItemCount(file_widget) <> 1 Then failures += 1
If filelistbox_TryRefresh(file_widget, fixture_root, "ALPHA.BMP") <> _
    FILESYSTEMLISTBOX_REFRESH_OK OrElse listbox_GetItemCount(file_widget) <> 1 Then
    failures += 1
Else
    listbox_GetItem file_widget, 0, item_text
    If item_text <> "alpha.bmp" Then failures += 1
End If
If filelistbox_TryRefreshPatterns(file_widget, fixture_root, "ALPHA.BMP;?ETA.ICO") <> _
    FILESYSTEMLISTBOX_REFRESH_OK OrElse listbox_GetItemCount(file_widget) <> 2 Then
    failures += 1
End If
If filelistbox_TryRefresh(file_widget, fixture_root, "*.*") <> _
    FILESYSTEMLISTBOX_REFRESH_OK OrElse listbox_GetItemCount(file_widget) <> 5 Then
    failures += 1
Else
    Dim As Integer extensionless_found
    For item_index As Integer = 0 To listbox_GetItemCount(file_widget) - 1
        listbox_GetItem file_widget, item_index, item_text
        If item_text = "README" Then extensionless_found = -1
    Next item_index
    If extensionless_found = 0 Then failures += 1
End If
If filelistbox_TryRefreshPatterns(file_widget, fixture_root & "/empty", "*.bmp;*.ico") <> FILESYSTEMLISTBOX_REFRESH_OK OrElse _
    listbox_GetItemCount(file_widget) <> 0 Then failures += 1
#If Defined(__FB_WIN32__)
Dim As String root_path = Left(CurDir, 3)
#Else
Dim As String root_path = "/"
#EndIf
If filelistbox_TryRefreshPatterns(file_widget, root_path, "__omagui_absent_71624__;__omagui_absent_71625__") <> FILESYSTEMLISTBOX_REFRESH_OK Then failures += 1
If listbox_GetItemCount(file_widget) <> 0 OrElse CurDir <> previous_directory Then failures += 1
#Ifndef __FB_WIN32__
Dim As Integer case_file_number = FreeFile
Dim As Integer created_case_file = IIf(Open(fixture_root & "/ALPHA.bmp" For Output As #case_file_number) = 0, -1, 0)
If created_case_file Then
    Close #case_file_number
    If filelistbox_TryRefreshPatterns(file_widget, fixture_root, "*.bmp;alpha.*;*.bmp") <> FILESYSTEMLISTBOX_REFRESH_OK Then failures += 1
    If listbox_GetItemCount(file_widget) <> 2 Then failures += 1
    Dim As Integer lower_found, upper_found
    For item_index As Integer = 0 To listbox_GetItemCount(file_widget) - 1
        listbox_GetItem file_widget, item_index, item_text
        If item_text = "alpha.bmp" Then lower_found = -1
        If item_text = "ALPHA.bmp" Then upper_found = -1
    Next item_index
    If lower_found = 0 OrElse upper_found = 0 Then failures += 1
Else
    failures += 1
End If
#EndIf
gui_ResetForTest
backend_Exit
' Only the exact files in the newly created fixture directory are removed.
For item_index As Integer = 0 To created_count - 1
    If Kill(fixture_root & "/" & fixture_names(item_index)) <> 0 Then failures += 1
Next item_index
#Ifndef __FB_WIN32__
If created_case_file Then
    If Kill(fixture_root & "/ALPHA.bmp") <> 0 Then failures += 1
End If
#EndIf
If created_empty Then
    If RmDir(fixture_root & "/empty") <> 0 Then failures += 1
End If
If RmDir(fixture_root) <> 0 Then failures += 1
If failures Then
    Print "filesystem_patterns_smoke: FAIL "; failures
    End 1
End If
Print "filesystem_patterns_smoke: PASS"

/' end of filesystem_patterns_smoke.bas '/
