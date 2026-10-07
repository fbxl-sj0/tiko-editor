/'
    Project: omaGUI render tests
    File: opaque_render_smoke.bas
    Purpose: Verify skipping painters covered by a later opaque window.
    Responsibilities: Check clipping, ordering, callback lifetime and pixels.
    This file does not dispatch input or alter application settings.

    Counters and opacity callbacks belong to the test's GUI thread. Results
    are printed after leaving graphics so reporting cannot change the scene.
'/
#lang "fb"
#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"
#include once "test_harness.bi"
#include once "crt/string.bi"

Private Dim Shared As Integer opaqueTest_Draws(0 To 3), opaqueTest_Mode
Private Dim Shared As Integer opaqueTest_Results(0 To 31), opaqueTest_Count
Private Dim Shared As String opaqueTest_Labels(0 To 31)
Private Sub opaqueTest_Record(ByVal condition As Integer, ByVal labelText As String)
    If opaqueTest_Count > UBound(opaqueTest_Results) Then End 3
    opaqueTest_Results(opaqueTest_Count) = condition
    opaqueTest_Labels(opaqueTest_Count) = labelText
    opaqueTest_Count += 1
End Sub
Private Sub opaqueTest_PaintDesktop(ByVal w As Widget Ptr)
    opaqueTest_Draws(0) += 1
    backend_Rect 0, 0, 320, 240, RGB(71, 93, 151), -1
End Sub
Private Sub opaqueTest_PaintBack(ByVal w As Widget Ptr)
    opaqueTest_Draws(1) += 1
    backend_Rect 0, 0, 320, 240, RGB(17, 203, 31), -1
End Sub
Private Sub opaqueTest_PaintCover(ByVal w As Widget Ptr)
    opaqueTest_Draws(2) += 1
    backend_Rect w->ax, w->ay, w->w, w->h, RGB(191, 41, 57), -1
End Sub
Private Sub opaqueTest_PaintFront(ByVal w As Widget Ptr)
    opaqueTest_Draws(3) += 1
    ' The later window is transparent except for this line. It must still run.
    backend_Line 45, 45, 100, 100, RGB(247, 239, 13)
End Sub
Private Sub opaqueTest_Replacement(ByVal w As Widget Ptr)
    opaqueTest_PaintCover w
End Sub
Private Function opaqueTest_Bounds(ByVal w As Widget Ptr, ByRef x As Integer, _
    ByRef y As Integer, ByRef widthValue As Integer, ByRef heightValue As Integer) As Integer
    x = w->ax: y = w->ay: widthValue = w->w: heightValue = w->h
    If opaqueTest_Mode = 1 Then Return 0
    If opaqueTest_Mode = 2 Then widthValue = -1
    Return -1
End Function
Private Function opaqueTest_Create(ByVal painter As Sub(ByVal As Widget Ptr), _
    ByVal windowFlag As Integer, ByVal x As Integer = 0, ByVal y As Integer = 0, _
    ByVal widthValue As Integer = 320, ByVal heightValue As Integer = 240) As Widget Ptr
    Dim As Widget Ptr w = gui_CreateWidgetBase()
    If w = 0 Then End 2
    w->x = x: w->y = y: w->w = widthValue: w->h = heightValue
    w->render = painter: w->is_window = windowFlag
    gui_AddWidget w
    Return w
End Function
Private Sub opaqueTest_Render(ByVal x As Integer, ByVal y As Integer, _
    ByVal widthValue As Integer, ByVal heightValue As Integer)
    For index As Integer = 0 To 3
        opaqueTest_Draws(index) = 0
    Next index
    ScreenLock
    backend_SetClip x, y, widthValue, heightValue
    gui_RenderDesktop
    gui_RenderWindows
    backend_ResetClip
    ScreenUnlock 1, 0
End Sub

backend_Init 320, 240, BACKEND_HEADLESS_DRAWABLE, 0, BACKEND_COLOR_DEPTH_TRUE_COLOR
Dim As Widget Ptr desktopWidget = opaqueTest_Create(@opaqueTest_PaintDesktop, 0)
Dim As Widget Ptr backWidget = opaqueTest_Create(@opaqueTest_PaintBack, -1)
Dim As Widget Ptr coverWidget = opaqueTest_Create(@opaqueTest_PaintCover, -1, 40, 40, 100, 100)
Dim As Widget Ptr frontWidget = opaqueTest_Create(@opaqueTest_PaintFront, -1)
opaqueTest_Render 0, 0, 320, 240
opaqueTest_Record(opaqueTest_Draws(0) = 1 AndAlso opaqueTest_Draws(1) = 1, "unqualified windows preserve earlier painters")

Dim As Any Ptr referenceImage = ImageCreate(320, 240, 0, 32)
Dim As Any Ptr actualImage = ImageCreate(320, 240, 0, 32)
If referenceImage = 0 OrElse actualImage = 0 Then
    If referenceImage <> 0 Then ImageDestroy referenceImage
    If actualImage <> 0 Then ImageDestroy actualImage
    backend_Exit
    End 2
End If
Dim As Integer imageWidth, imageHeight, imageBpp, imagePitch
Dim As Any Ptr referencePixels, actualPixels
If ImageInfo(referenceImage, imageWidth, imageHeight, imageBpp, imagePitch, referencePixels) <> 0 OrElse _
   ImageInfo(actualImage, imageWidth, imageHeight, imageBpp, imagePitch, actualPixels) <> 0 Then End 2

opaqueTest_Render 45, 45, 55, 55
Get (0, 0)-(319, 239), referenceImage
gui_SetOpaqueRenderBoundsHandler coverWidget, @opaqueTest_Bounds
opaqueTest_Render 45, 45, 55, 55
opaqueTest_Record(opaqueTest_Draws(0) = 0 AndAlso opaqueTest_Draws(1) = 0, "covered clip skips desktop and earlier windows")
opaqueTest_Record(opaqueTest_Draws(2) = 1 AndAlso opaqueTest_Draws(3) = 1, "cover and later transparent windows keep paint order")
Get (0, 0)-(319, 239), actualImage
opaqueTest_Record(memcmp(referencePixels, actualPixels, imagePitch * imageHeight) = 0, "opaque replay preserves complete framebuffer bytes")

opaqueTest_Render 30, 30, 100, 100
opaqueTest_Record(opaqueTest_Draws(0) = 1 AndAlso opaqueTest_Draws(1) = 1, "partly covered damage preserves background replay")
opaqueTest_Mode = 1
opaqueTest_Render 45, 45, 55, 55
opaqueTest_Record(opaqueTest_Draws(0) = 1 AndAlso opaqueTest_Draws(1) = 1, "declined opacity preserves replay")
opaqueTest_Mode = 2
opaqueTest_Render 45, 45, 55, 55
opaqueTest_Record(opaqueTest_Draws(0) = 1, "negative opacity extents preserve replay")
opaqueTest_Mode = 0
coverWidget->visible = 0
opaqueTest_Render 45, 45, 55, 55
opaqueTest_Record(opaqueTest_Draws(0) = 1 AndAlso opaqueTest_Draws(2) = 0, "hidden covers cannot skip visible painters")
coverWidget->visible = -1
coverWidget->render = @opaqueTest_Replacement
opaqueTest_Render 45, 45, 55, 55
opaqueTest_Record(opaqueTest_Draws(0) = 1, "replacement painter cannot inherit opacity")
gui_SetOpaqueRenderBoundsHandler coverWidget, @opaqueTest_Bounds
opaqueTest_Render 45, 45, 55, 55
opaqueTest_Record(opaqueTest_Draws(0) = 0, "replacement painter can explicitly rebind opacity")
gui_SetOpaqueRenderBoundsHandler coverWidget, 0
opaqueTest_Render 45, 45, 55, 55
opaqueTest_Record(opaqueTest_Draws(0) = 1, "cleared opacity restores ordinary replay")
gui_SetOpaqueRenderBoundsHandler coverWidget, @opaqueTest_Bounds
coverWidget->is_window = 0
opaqueTest_Render 45, 45, 55, 55
opaqueTest_Record(opaqueTest_Draws(0) = 1, "desktop opacity cannot hide later window layers")
coverWidget->is_window = -1
coverWidget->parent = backWidget
opaqueTest_Render 45, 45, 55, 55
opaqueTest_Record(opaqueTest_Draws(0) = 1, "child opacity keeps conservative scene replay")
coverWidget->parent = 0
coverWidget->visible = 0

Dim As Widget Ptr popup = menu_Create("opaque_popup", 40, 40)
If popup = 0 Then End 2
menu_AddDisplayItem popup, "Caption", 0
gui_AddWidget popup
menu_ShowAt popup, 40, 40
opaqueTest_Render 42, 42, 5, 5
opaqueTest_Record(opaqueTest_Draws(0) = 0 AndAlso opaqueTest_Draws(1) = 0, "portable menu supplies an opaque root surface")
gui_SetOpaqueRenderBoundsHandler popup, 0
opaqueTest_Render 42, 42, 5, 5
Get (0, 0)-(319, 239), referenceImage
gui_SetOpaqueRenderBoundsHandler popup, @menu_GetOpaqueBounds
opaqueTest_Render 42, 42, 5, 5
Get (0, 0)-(319, 239), actualImage
opaqueTest_Record(memcmp(referencePixels, actualPixels, imagePitch * imageHeight) = 0, "menu opacity matches ordinary replay pixels")
Cast(MenuData Ptr, popup->data)->parent_menu = popup
opaqueTest_Render 42, 42, 5, 5
opaqueTest_Record(opaqueTest_Draws(0) = 1, "owned submenu does not claim a separately painted surface")
Cast(MenuData Ptr, popup->data)->parent_menu = 0

ImageDestroy referenceImage
ImageDestroy actualImage
gui_ResetForTest
backend_Exit
Screen 0
For index As Integer = 0 To opaqueTest_Count - 1
    AssertTrue(opaqueTest_Results(index), opaqueTest_Labels(index))
Next index
test_Summary
/' end of opaque_render_smoke.bas '/
