/'
    Project: omaGUI
    ---------------

    File: parent_modal_smoke.bas

    Purpose:
        Smoke-test parent-relative widget layout, callback buttons, and modal
        interaction boundaries.

    Responsibilities:
        - click a child button through a subwindow offset
        - confirm nested modal roots restore their parent
        - confirm hidden and deleted trees cannot leave stale modal roots
        - confirm exact-pointer parent removal also removes registered children

    This file intentionally does NOT contain:
        - application-specific editor behavior
        - filesystem dialog tests
        - renderer snapshot comparisons
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Const PARENT_MODAL_SMOKE_WIDTH As Integer = 320
Const PARENT_MODAL_SMOKE_HEIGHT As Integer = 200
Const PARENT_MODAL_WINDOW_X As Integer = 100
Const PARENT_MODAL_WINDOW_Y As Integer = 60
Const PARENT_MODAL_BUTTON_X As Integer = 12
Const PARENT_MODAL_BUTTON_Y As Integer = 28
Const PARENT_MODAL_BUTTON_W As Integer = 64
Const PARENT_MODAL_BUTTON_H As Integer = 24

' Shared state boundary: these counters are owned by the modal test callbacks below.
Dim Shared insideClicks As Integer
Dim Shared outsideClicks As Integer
Dim Shared nestedClicks As Integer

Sub parent_modal_OnInside(ByVal w As Widget Ptr)
    insideClicks += 1
End Sub

Sub parent_modal_OnOutside(ByVal w As Widget Ptr)
    outsideClicks += 1
End Sub

Sub parent_modal_OnNested(ByVal w As Widget Ptr)
    nestedClicks += 1
End Sub

backend_Init PARENT_MODAL_SMOKE_WIDTH, PARENT_MODAL_SMOKE_HEIGHT, 1
gui_Init()

Dim As Widget Ptr windowWidget
Dim As Widget Ptr insideButton
Dim As Widget Ptr outsideButton
Dim As Widget Ptr nestedWindow
Dim As Widget Ptr nestedButton
Dim As Widget Ptr overflowModalRoots( _
    0 To GUI_MODAL_ROOT_MAXIMUM_DEPTH _
)
Dim As Widget unregisteredModalRoot = Type<Widget>()
Dim As Integer nestedClicksBeforeDepthTest

windowWidget = subwindow_Create( _
    "parent_modal_window", _
    "Window", _
    PARENT_MODAL_WINDOW_X, _
    PARENT_MODAL_WINDOW_Y, _
    160, _
    100 _
)
insideButton = button_Create( _
    "parent_modal_inside", _
    "Inside", _
    PARENT_MODAL_BUTTON_X, _
    PARENT_MODAL_BUTTON_Y, _
    PARENT_MODAL_BUTTON_W, _
    PARENT_MODAL_BUTTON_H, _
    @parent_modal_OnInside _
)
outsideButton = button_Create("parent_modal_outside", "Outside", 8, 8, 64, 24, @parent_modal_OnOutside)
nestedWindow = subwindow_Create("parent_modal_nested_window", "Nested", 180, 60, 120, 100)
nestedButton = button_Create( _
    "parent_modal_nested_button", "Nested", 12, 28, 64, 24, _
    @parent_modal_OnNested _
)
If nestedWindow = 0 OrElse nestedButton = 0 Then
    Print "parent modal smoke failed: nested widget allocation"
    End 7
End If

gui_AddWidget windowWidget
gui_AddWidget insideButton
gui_AddWidget outsideButton
gui_AddWidget nestedWindow
gui_AddWidget nestedButton
gui_SetParent insideButton, windowWidget
gui_SetParent nestedButton, nestedWindow
gui_SetModalRoot windowWidget

input_MockMouse PARENT_MODAL_WINDOW_X + PARENT_MODAL_BUTTON_X + 1, PARENT_MODAL_WINDOW_Y + PARENT_MODAL_BUTTON_Y + 1, 1
gui_UpdateAll()
input_MockMouse PARENT_MODAL_WINDOW_X + PARENT_MODAL_BUTTON_X + 1, PARENT_MODAL_WINDOW_Y + PARENT_MODAL_BUTTON_Y + 1, 0
gui_UpdateAll()

If insideClicks <> 1 Then
    Print "parent modal smoke failed: child callback did not run"
    End 1
End If

If insideButton->ax <> PARENT_MODAL_WINDOW_X + PARENT_MODAL_BUTTON_X OrElse _
   insideButton->ay <> PARENT_MODAL_WINDOW_Y + PARENT_MODAL_BUTTON_Y Then
    Print "parent modal smoke failed: child absolute position was wrong"
    End 2
End If

input_MockMouse 9, 9, 1
gui_UpdateAll()
input_MockMouse 9, 9, 0
gui_UpdateAll()

If outsideClicks <> 0 Then
    Print "parent modal smoke failed: modal root allowed outside callback"
    End 3
End If

If gui_TrySetModalRoot(nestedWindow) = 0 OrElse _
   gui_TrySetModalRoot(nestedWindow) = 0 OrElse _
   gui_TrySetModalRoot(windowWidget) = 0 Then
    Print "parent modal smoke failed: nested modal activation"
    End 8
End If
input_MockMouse PARENT_MODAL_WINDOW_X + PARENT_MODAL_BUTTON_X + 1, PARENT_MODAL_WINDOW_Y + PARENT_MODAL_BUTTON_Y + 1, 1
gui_UpdateAll()
input_MockMouse PARENT_MODAL_WINDOW_X + PARENT_MODAL_BUTTON_X + 1, PARENT_MODAL_WINDOW_Y + PARENT_MODAL_BUTTON_Y + 1, 0
gui_UpdateAll()
If insideClicks <> 1 Then
    Print "parent modal smoke failed: nested modal did not block its parent"
    End 9
End If
input_MockMouse 193, 89, 1
gui_UpdateAll()
input_MockMouse 193, 89, 0
gui_UpdateAll()
If nestedClicks <> 1 Then
    Print "parent modal smoke failed: nested modal child did not receive input"
    End 10
End If

gui_ClearModalRoot nestedWindow
If gui_IsModalOpen() = 0 Then
    Print "parent modal smoke failed: closing the child also cleared its parent"
    End 11
End If
input_MockMouse PARENT_MODAL_WINDOW_X + PARENT_MODAL_BUTTON_X + 1, PARENT_MODAL_WINDOW_Y + PARENT_MODAL_BUTTON_Y + 1, 1
gui_UpdateAll()
input_MockMouse PARENT_MODAL_WINDOW_X + PARENT_MODAL_BUTTON_X + 1, PARENT_MODAL_WINDOW_Y + PARENT_MODAL_BUTTON_Y + 1, 0
gui_UpdateAll()
If insideClicks <> 2 Then
    Print "parent modal smoke failed: closing the child did not restore the parent"
    End 12
End If
gui_ClearModalRoot windowWidget
If gui_IsModalOpen() <> 0 Then
    Print "parent modal smoke failed: closing the parent left a modal root"
    End 13
End If

' Removing an earlier root while a separate nested root remains active must
' not make the child lose modality or restore the removed parent later.
gui_SetModalRoot windowWidget
gui_SetModalRoot nestedWindow
gui_ClearModalRoot windowWidget
If gui_IsModalOpen() = 0 Then
    Print "parent modal smoke failed: clearing a parent released the child"
    End 14
End If
gui_ClearModalRoot nestedWindow
If gui_IsModalOpen() <> 0 Then
    Print "parent modal smoke failed: clearing the child restored a cleared parent"
    End 15
End If

' Hiding an earlier root has the same out-of-order cleanup requirement.
gui_SetModalRoot windowWidget
gui_SetModalRoot nestedWindow
If gui_SetVisible(windowWidget, 0) = 0 OrElse gui_IsModalOpen() = 0 Then
    Print "parent modal smoke failed: hiding the parent cleared the child root"
    End 16
End If
gui_ClearModalRoot nestedWindow
If gui_IsModalOpen() <> 0 Then
    Print "parent modal smoke failed: hidden parent was restored after child close"
    End 17
End If
gui_SetVisible windowWidget, -1

' The checked API refuses one root beyond its fixed bound and keeps the last
' valid modal active rather than silently dropping the input boundary.
nestedClicksBeforeDepthTest = nestedClicks
For modal_index As Integer = 0 To GUI_MODAL_ROOT_MAXIMUM_DEPTH
    overflowModalRoots(modal_index) = button_Create( _
        "parent_modal_depth_" & LTrim(Str(modal_index)), _
        "Depth", 20, 20, 48, 24, @parent_modal_OnNested _
    )
    If overflowModalRoots(modal_index) = 0 Then
        Print "parent modal smoke failed: depth-test widget allocation"
        End 19
    End If
    gui_AddWidget overflowModalRoots(modal_index)
    If modal_index < GUI_MODAL_ROOT_MAXIMUM_DEPTH Then
        If gui_TrySetModalRoot(overflowModalRoots(modal_index)) = 0 Then
            Print "parent modal smoke failed: valid modal depth was rejected"
            End 20
        End If
    ElseIf gui_TrySetModalRoot(overflowModalRoots(modal_index)) <> 0 Then
        Print "parent modal smoke failed: modal depth overflow was accepted"
        End 21
    End If
Next modal_index
input_MockMouse 24, 24, 1
gui_UpdateAll()
input_MockMouse 24, 24, 0
gui_UpdateAll()
If nestedClicks <> nestedClicksBeforeDepthTest + 1 Then
    Print "parent modal smoke failed: overflow changed the active modal"
    End 22
End If
gui_ClearModalRoot overflowModalRoots( _
    GUI_MODAL_ROOT_MAXIMUM_DEPTH - 1 _
)
gui_ClearModalRoot 0
If gui_IsModalOpen() <> 0 Then
    Print "parent modal smoke failed: depth cleanup left a modal root"
    End 23
End If
For modal_index As Integer = 0 To GUI_MODAL_ROOT_MAXIMUM_DEPTH
    gui_RemoveWidgetPtr overflowModalRoots(modal_index)
Next modal_index

If gui_TrySetModalRoot(@unregisteredModalRoot) <> 0 Then
    Print "parent modal smoke failed: unregistered modal root was accepted"
    End 24
End If

' Deleting a tree whose descendant owns the current root must clear that
' borrowed pointer before gui_DeleteWidgetTree releases the descendant.
gui_SetModalRoot insideButton
If gui_RemoveWidgetPtr(windowWidget) = 0 Then
    Print "parent modal smoke failed: exact parent removal was rejected"
    End 4
End If
If gui_IsModalOpen() <> 0 Then
    Print "parent modal smoke failed: removing a tree left a descendant modal root"
    End 18
End If

If gui_FindWidget("parent_modal_window") <> 0 OrElse _
   gui_FindWidget("parent_modal_inside") <> 0 Then
    Print "parent modal smoke failed: parent removal left child registered"
    End 5
End If

If gui_RemoveWidgetPtr(windowWidget) <> 0 Then
    Print "parent modal smoke failed: stale pointer removal was not harmless"
    End 6
End If

gui_RemoveWidget "parent_modal_outside"
gui_RemoveWidget "parent_modal_nested_window"
backend_Exit()

Print "parent modal smoke OK"
End 0

' end of parent_modal_smoke.bas
