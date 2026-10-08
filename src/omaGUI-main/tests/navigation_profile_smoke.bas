/'
    Project: omaGUI qualification
    File: navigation_profile_smoke.bas
    Purpose: Exercise navigation, scaled clipping and container sizing.
    Responsibilities: Test public behavior on a drawable null driver.
    This file does not open a desktop window or contact a controller.
'/
#lang "fb"
#define OMAGUI_NAVIGATION_EXTENSIONS
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim Shared As Integer checks
Sub require(ByVal condition As Integer, ByVal description As String)
    checks += 1
    If condition = 0 Then
        Print "NAVIGATION_FAIL "; description
        End 1
    End If
End Sub

backend_SetDisplayOptions 0, 60
backend_Init 320, 200, BACKEND_HEADLESS_DRAWABLE
gui_Init
input_ResetForTest
Dim As Widget Ptr scopeRoot = gui_BeginInputScope("scopeRoot", 0, 0, 320, 200)
require scopeRoot <> 0, "scopeRoot allocation"
Dim As Widget Ptr first = button_Create("first", "First", 10, 10, 80, 30)
Dim As Widget Ptr secondButton = button_Create("secondButton", "Second", 100, 10, 80, 30)
gui_AddWidget first: gui_AddWidget secondButton
gui_SetFocusable first, 1: gui_SetFocusable secondButton, 2
gui_SetFocusNeighbor first, INPUT_ACTION_RIGHT, secondButton
gui_SetDirectionalFocus -1
gui_FocusFirst
gui_EndInputScopeBuild
gui_UpdateAll
require gui_GetFocus() = first, "explicit focus order"
require first->parent = scopeRoot AndAlso secondButton->parent = scopeRoot, "scopeRoot membership"
input_MockGamepad 0, FB.XPAD_DPAD_RIGHT
gui_UpdateAll
require gui_GetFocus() = secondButton, "controller neighbor"
input_MockGamepad 0, 0: gui_UpdateAll
input_MockGamepad FB.XPAD_BUTTON_A, 0: gui_UpdateAll
require gui_ButtonPressed("secondButton"), "controller activation survives widget update"
require input_ActionPressed(INPUT_ACTION_ACCEPT) = 0, "action consumed once"
input_MockGamepad 0, 0: gui_UpdateAll
require gui_ButtonPressed("secondButton") = 0, "activation resets next frame"
input_MockTouchCount 1
input_MockTouch 0, 20, 20, 42
gui_UpdateAll
require input_TouchPhase(0) = INPUT_TOUCH_BEGAN AndAlso input_TouchId(0) = 42, "touch identity begins"
input_MockTouch 0, 25, 20, 42
gui_UpdateAll
require input_TouchPhase(0) = INPUT_TOUCH_MOVED, "touch moves"
input_MockTouchCount 0
gui_UpdateAll
require input_TouchCount() = 1 AndAlso input_TouchPhase(0) = INPUT_TOUCH_ENDED, "touch ending survives one frame"
require input_MouseButtons() = 0 AndAlso input_PrimaryTouchIndex() = -1, "ended touch does not hold pointer"
gui_UpdateAll
require input_TouchCount() = 0, "ending record expires"
gui_SetFocus first
gui_RemoveWidget "secondButton"
input_MockGamepad 0, FB.XPAD_DPAD_RIGHT: gui_UpdateAll
require gui_GetFocus() = first, "removed neighbor is safe"
Dim As Widget Ptr listWidget = listbox_Create("controller_list", 10, 40, 180, 120)
gui_SetParent listWidget, scopeRoot
gui_AddWidget listWidget
For itemIndex As Integer = 0 To 9
    listbox_AddItem listWidget, "Item " & itemIndex
Next
gui_SetFocus listWidget
input_MockGamepad 0, 0
input_MockMouse 20, 80, 1
gui_UpdateAll
input_MockMouse 20, 0, 1
gui_UpdateAll
input_MockMouse 20, 0, 0
gui_UpdateAll
Dim As ListBoxData Ptr touchListData = listWidget->data
require touchListData->scroll_top >= 2, "touch swipe scrolls list"
require listbox_GetActivationCount(listWidget) = 0, "swipe does not activate row"
input_MockMouse 20, 80, 1: gui_UpdateAll
input_MockMouse 20, 80, 0: gui_UpdateAll
require listbox_GetActivationCount(listWidget) = 1, "row tap activates once"
Dim As Integer selectedBefore = touchListData->selected_index
input_MockGamepad 0, FB.XPAD_DPAD_DOWN: gui_UpdateAll
require touchListData->selected_index = selectedBefore + 1, "controller moves list selection"
input_MockGamepad 0, 0: gui_UpdateAll
input_MockKey KEY_UP, -1: gui_UpdateAll
require touchListData->selected_index = selectedBefore, "keyboard moves list once"
input_MockKey KEY_UP, 0: gui_UpdateAll
gui_SetDefaultButton first
input_MockGamepad FB.XPAD_BUTTON_A, 0: gui_UpdateAll
require gui_ButtonPressed("first"), "list controller acceptance uses default command"

Dim As Widget Ptr container = layout_Create("row", 0, 50, 300, 60, GUI_LAYOUT_ROW, 5, 5)
gui_AddWidget container
Dim As Widget Ptr child = button_Create("child", "Child", 0, 0, 20, 20)
gui_AddWidget child: gui_SetParent child, container
gui_SetPreferredSize child, 20, 20
gui_SetMinimumSize child, 10, 10
gui_SetLayoutWeight child, 1
layout_Apply container
require child->x = 5 AndAlso child->w = 290, "weighted row placement"
require layout_HasOverflow(container) = 0, "row fits"
child->layout_weight = 65536
layout_Apply container
require layout_HasOverflow(container), "invalid direct metadata rejected"

Dim As Integer logicalW, logicalH, physicalW, physicalH
backend_GetSize logicalW, logicalH: ScreenInfo physicalW, physicalH
require logicalW = 320 AndAlso logicalH = 200, "logical dimensions retained"
require physicalW = 192 AndAlso physicalH = 120, "physical scale applied"
require backend_PhysicalToLogicalX(physicalW - 1) = 319, "pointer right endpoint"
require backend_PhysicalToLogicalY(physicalH - 1) = 199, "pointer bottom endpoint"
require backend_PhysicalToLogicalX(-1) = -1, "pointer outside surface"
backend_Clear RGB(0,0,0)
backend_SetClip 40, 40, 80, 60
backend_Rect 0, 0, 320, 200, RGB(255,0,0), 1
backend_ResetClip
Window: View Screen
require (Point(10,10) And &hFFFFFF) = 0, "clip protects exterior"
require (Point(40,40) And &hFFFFFF) = &hFF0000, "clipped logical drawing reaches interior"
backend_NavigationClip 0, 0, 319, 199
Dim As Integer textWidth = backend_GetTextWidth("Test")
backend_SetTextScale 2
require backend_GetTextWidth("Test") = textWidth * 2, "large text metrics"
require backend_GetTextHeight() = 28, "large text line height"
gui_ResetForTest
backend_Exit
Print "NAVIGATION_CONTRACT_PASS checks="; checks
End 0
' end of navigation_profile_smoke.bas
