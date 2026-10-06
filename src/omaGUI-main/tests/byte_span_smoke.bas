/'
    Project: omaGUI memory tests
    File: byte_span_smoke.bas
    Purpose: Verify exact equality for bounded and unaligned byte spans.
    Responsibilities: Compare the word path with the C library, including every
        changed byte position, short tails, NULs and protected page boundaries.
    This file contains no renderer, timing benchmark or user file access.
'/
#lang "fb"
#define OMAGUI_IMPLEMENTATION
#include once "src/system/byte_span.bi"
#ifdef __FB_WIN32__
#include once "windows.bi"
#endif

Dim Shared As Integer byteSpan_Failures
Dim Shared As UInteger byteSpan_Comparisons
Private Sub byteSpan_Compare(ByVal firstBytes As Const Any Ptr, _
    ByVal secondBytes As Const Any Ptr, ByVal byteCount As Integer)
    Dim As Integer expected = IIf(memcmp(firstBytes, secondBytes, byteCount) = 0, -1, 0)
    byteSpan_Comparisons += 1
    If oma_BytesEqual(firstBytes, secondBytes, byteCount) <> expected Then
        If byteSpan_Failures < 8 Then Print "FAIL byte count "; byteCount
        byteSpan_Failures += 1
    End If
End Sub

Dim As UByte firstBytes(0 To 79), secondBytes(0 To 79)
Dim As UByte changedValues(0 To 7) = {0, 1, 127, 128, 129, 253, 254, 255}
For firstOffset As Integer = 0 To 3
    For secondOffset As Integer = 0 To 3
        For byteCount As Integer = 0 To 65
            For position As Integer = 0 To byteCount - 1
                firstBytes(firstOffset + position) = (position * 37 + 129) And 255
                secondBytes(secondOffset + position) = firstBytes(firstOffset + position)
            Next position
            firstBytes(firstOffset + byteCount) = 0
            secondBytes(secondOffset + byteCount) = 255
            byteSpan_Compare @firstBytes(firstOffset), @secondBytes(secondOffset), byteCount
            For position As Integer = 0 To byteCount - 1
                Dim As UByte originalValue = secondBytes(secondOffset + position)
                For valueIndex As Integer = 0 To UBound(changedValues)
                    secondBytes(secondOffset + position) = changedValues(valueIndex)
                    byteSpan_Compare @firstBytes(firstOffset), @secondBytes(secondOffset), byteCount
                Next valueIndex
                secondBytes(secondOffset + position) = originalValue
            Next position
        Next byteCount
    Next secondOffset
Next firstOffset
If oma_BytesEqual(0, 0, 0) <> -1 OrElse oma_BytesEqual(0, 0, 1) <> 0 OrElse _
   oma_BytesEqual(@firstBytes(0), @secondBytes(0), -1) <> 0 Then byteSpan_Failures += 1

#ifdef __FB_WIN32__
Dim As SYSTEM_INFO systemInfo
GetSystemInfo @systemInfo
Dim As Any Ptr firstPages = VirtualAlloc(0, systemInfo.dwPageSize * 2, _
    MEM_COMMIT Or MEM_RESERVE, PAGE_READWRITE)
Dim As Any Ptr secondPages = VirtualAlloc(0, systemInfo.dwPageSize * 2, _
    MEM_COMMIT Or MEM_RESERVE, PAGE_READWRITE)
Dim As DWORD previousProtection
If firstPages = 0 OrElse secondPages = 0 Then
    byteSpan_Failures += 1
ElseIf VirtualProtect(firstPages + systemInfo.dwPageSize, systemInfo.dwPageSize, _
        PAGE_NOACCESS, @previousProtection) = 0 OrElse _
       VirtualProtect(secondPages + systemInfo.dwPageSize, systemInfo.dwPageSize, _
        PAGE_NOACCESS, @previousProtection) = 0 Then
    byteSpan_Failures += 1
Else
    memset firstPages, 129, systemInfo.dwPageSize
    memset secondPages, 129, systemInfo.dwPageSize
    For byteCount As Integer = 0 To 257
        Dim As UByte Ptr firstEdge = firstPages + systemInfo.dwPageSize - byteCount
        Dim As UByte Ptr secondEdge = secondPages + systemInfo.dwPageSize - byteCount
        byteSpan_Compare firstEdge, secondEdge, byteCount
        If byteCount > 0 Then
            secondEdge[byteCount - 1] = 255
            byteSpan_Compare firstEdge, secondEdge, byteCount
            secondEdge[byteCount - 1] = 129
        End If
    Next byteCount
End If
If firstPages <> 0 Then VirtualFree firstPages, 0, MEM_RELEASE
If secondPages <> 0 Then VirtualFree secondPages, 0, MEM_RELEASE
#endif
Print "byte_span_smoke: "; byteSpan_Comparisons; " comparisons, "; byteSpan_Failures; " failures"
If byteSpan_Failures <> 0 Then End 1
' end of byte_span_smoke.bas
