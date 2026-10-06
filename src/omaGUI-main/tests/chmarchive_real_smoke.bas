/'
    Project: omaGUI Tests
    File: chmarchive_real_smoke.bas
    Purpose: Read a member from a real CHM help archive.
    Responsibilities: Check directory parsing and bounded member decoding.
    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain: HTML layout or extraction.
'/

#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"

Dim As String errorText, memberName, memberText
Dim As Integer sectionIndex, readCount, compressedCount
Dim As ChmArchive Ptr archive = chmarchive_Open(Command(1), errorText)

If archive = 0 Then
    Print "CHM open failed: "; errorText
    End 1
End If

For memberIndex As Integer = 0 To chmarchive_MemberCount(archive) - 1
    If chmarchive_GetMemberInfo( _
        archive, memberIndex, memberName, sectionIndex _
    ) = 0 Then Continue For
    If sectionIndex <> 1 Then Continue For
    compressedCount += 1
    If Left(memberName, 1) = "#" OrElse _
       Left(memberName, 1) = "$" OrElse _
       InStr(memberName, "::") > 0 Then Continue For
    If chmarchive_ReadFile( _
        archive, memberName, memberText, errorText, 1048576 _
    ) = 0 Then Continue For
    If Len(memberText) > 0 Then
        readCount += 1
        Exit For
    End If
Next memberIndex

chmarchive_Close archive

If readCount = 0 Then
    Print "CHM member read failed: "; compressedCount; " compressed entries; "; errorText
    End 1
End If

Print "CHM member read: "; memberName; " ("; Len(memberText); " bytes)"

' end of chmarchive_real_smoke.bas
