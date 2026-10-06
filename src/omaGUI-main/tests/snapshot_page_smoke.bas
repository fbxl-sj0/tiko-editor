/'
    Project: omaGUI
    ---------------

    File: snapshot_page_smoke.bas

    Targets:

        FreeBASIC FB dialect with a gfxlib2 or gfxlib3 desktop backend.

    Module API:

        Standalone snapshot regression with no exported API.

    Purpose:

        Verify snapshots capture the displayed frame and preserve drawing state.

    Responsibilities:

        - distinguish the displayed page from a partly drawn work page
        - check that snapshot capture restores the work page
        - check the retained single-page rendering path

    This file intentionally does NOT contain:

        - application widgets or interactive input
        - a general bitmap decoder
        - image comparison utilities
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub snapshot_Require(ByVal condition As Integer, ByRef message As Const String)
    If condition <> 0 Then Exit Sub
    backend_Exit()
    Print "snapshot page smoke failed: "; message
    End 1
End Sub

Private Function snapshot_FirstPixel(ByRef filePath As Const String) As ULong
    Dim As Integer fileNumber = FreeFile()
    Dim As UByte blueValue, greenValue, redValue

    snapshot_Require Open(filePath For Binary Access Read As #fileNumber) = 0, _
        "cannot read the snapshot"
    snapshot_Require Lof(fileNumber) >= 57, "snapshot has no first pixel"
    ' A BMP written by the backend has a 54-byte header and BGR pixel bytes.
    ' FreeBASIC binary file positions begin at one, so the first pixel is 55.
    Get #fileNumber, 55, blueValue
    Get #fileNumber, , greenValue
    Get #fileNumber, , redValue
    Close #fileNumber
    Return RGB(redValue, greenValue, blueValue)
End Function

Dim As String filePath = ExePath() & "/snapshot_page_smoke.bmp"
Dim As Integer workPage

backend_Init 16, 12, BACKEND_HEADLESS_DRAWABLE
backend_Clear RGB(11, 22, 33)
backend_Flip()
backend_Clear RGB(44, 55, 66)
workPage = backend_GetWorkPage()
backend_SaveSnapshot filePath
snapshot_Require snapshot_FirstPixel(filePath) = RGB(11, 22, 33), _
    "double-buffered capture did not use the displayed frame"
snapshot_Require backend_GetWorkPage() = workPage, "capture changed the work page"
snapshot_Require Point(0, 0) = RGB(44, 55, 66), "capture did not restore drawing state"

snapshot_Require backend_UseRetainedPage() <> 0, "cannot select the retained page"
backend_Clear RGB(77, 88, 99)
backend_SaveSnapshot filePath
snapshot_Require snapshot_FirstPixel(filePath) = RGB(77, 88, 99), _
    "retained capture did not use the drawn frame"
snapshot_Require Point(0, 0) = RGB(77, 88, 99), "retained capture changed drawing state"

snapshot_Require Kill(filePath) = 0, "cannot remove the private snapshot"
backend_Exit()
Print "snapshot page smoke passed"
End 0

/' end of snapshot_page_smoke.bas '/
