/'
    Project: omaGUI Tests
    File: filesystem_capacity_smoke.bas
    Purpose: Verify transactional filesystem-list capacity failures.
    Responsibilities:
        - create a fresh private directory with 1025 empty fixture files
        - report capacity while retaining the old list and selection
        - accept exactly 1024 entries after the overflow fixture is reduced
        - remove only the fixture files and directory created by this test
    This file intentionally does NOT contain:
        - recursive deletion, existing-file overwrites, or SDK calls
'/

#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"
#include once "dir.bi"

Dim As String fixture_root
Dim As Integer created_count, failure_count
For attempt As Integer = 1 To 1000
    fixture_root = CurDir & "/filesystem_capacity_fixture_" & _
        LTrim(Str(attempt))
    If Len(Dir(fixture_root, fbDirectory)) = 0 Then Exit For
    fixture_root = ""
Next attempt
If Len(fixture_root) = 0 OrElse MkDir(fixture_root) <> 0 Then End 1
For item_index As Integer = 0 To LISTBOX_MAX_ITEMS
    Dim As Integer file_number = FreeFile
    ' The directory must have been newly created; no existing path is reused.
    ' fblint: disable-next-line FBL760
    Dim As String file_path = fixture_root & "/row_" & LTrim(Str(item_index)) & ".fixture"
    ' Predictable rows are confined to the directory this test just created.
    ' fblint: disable-next-line FBL760
    If Open(file_path For Output As #file_number) <> 0 Then
        failure_count += 1
        Exit For
    End If
    Close #file_number
    created_count += 1
Next item_index

backend_Init 320, 200, -1
gui_Init
Dim As Widget Ptr list_widget = listbox_Create("capacity", 0, 0, 200, 150)
If list_widget = 0 Then
    failure_count += 1
Else
    gui_AddWidget list_widget
    listbox_AddItem list_widget, "prior contents"
    listbox_SetSelectedIndex list_widget, 0
    If created_count <> LISTBOX_MAX_ITEMS + 1 OrElse _
        filelistbox_TryRefresh(list_widget, fixture_root, "*") <> _
            FILESYSTEMLISTBOX_REFRESH_CAPACITY OrElse _
        listbox_GetItemCount(list_widget) <> 1 OrElse _
        listbox_GetSelectedItem(list_widget) <> "prior contents" Then
        Print "FAIL overflowing refresh changed the previous list"
        failure_count += 1
    End If
    If created_count = LISTBOX_MAX_ITEMS + 1 Then
        ' Exact file owned by this test; removing it reaches the accepted bound.
        ' fblint: disable-next-line FBL760
        If Kill(fixture_root & "/row_" & LTrim(Str(LISTBOX_MAX_ITEMS)) & ".fixture") = 0 Then
            created_count -= 1
            If filelistbox_Refresh(list_widget, fixture_root, "*") = 0 OrElse _
                listbox_GetItemCount(list_widget) <> LISTBOX_MAX_ITEMS Then
                Print "FAIL exact-capacity refresh"
                failure_count += 1
            End If
            If filelistbox_TryRefreshPatterns(list_widget, fixture_root, "*.fixture;row_0.*;*.fixture") <> _
                FILESYSTEMLISTBOX_REFRESH_OK OrElse listbox_GetItemCount(list_widget) <> LISTBOX_MAX_ITEMS Then
                Print "FAIL overlapping patterns at exact capacity"
                failure_count += 1
            End If
        Else
            failure_count += 1
        End If
    End If
End If
gui_ResetForTest
backend_Exit

' The directory was newly created above. Never enumerate or delete unrelated
' entries: remove the exact counted filenames, then require an empty directory.
For item_index As Integer = 0 To created_count - 1
    ' These are the exact counted rows created in this test's private directory.
    ' fblint: disable-next-line FBL760
    If Kill(fixture_root & "/row_" & LTrim(Str(item_index)) & ".fixture") <> 0 Then failure_count += 1
Next item_index
If RmDir(fixture_root) <> 0 Then failure_count += 1
If failure_count Then
    Print "filesystem_capacity_smoke: FAIL ("; failure_count; " failures)"
    End 1
End If
Print "filesystem_capacity_smoke: PASS (1025 rejected transactionally, 1024 accepted, fixtures removed)"
End 0

/' end of filesystem_capacity_smoke.bas '/
