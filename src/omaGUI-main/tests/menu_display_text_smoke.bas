/'
    Project: omaGUI Menu Tests
    File: menu_display_text_smoke.bas
    Purpose: Verify exact display captions and ordinary text transformation.
    Responsibilities: Check translation collisions, item metadata and bounds.
    This file does not write settings, open documents or automate desktop input.
'/
#lang "fb"
#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"
#include once "test_harness.bi"

Private Dim Shared As Integer displayTest_TransformCount
Private Function displayTest_Transform(ByVal text As String) As String
    displayTest_TransformCount += 1
    If text = "Open" Then Return "Save"
    If text = "Save" Then Return "Exit"
    Return text
End Function

backend_Init 320, 240, -1
gui_SetTextTransformHandler @displayTest_Transform
Dim As Widget Ptr testMenu = menu_Create("display_text_test", 0, 0)
If testMenu = 0 OrElse testMenu->data = 0 Then End 2
Dim As MenuData Ptr menuData = testMenu->data
test_Section "display captions"
menu_AddItem testMenu, "Open", 0
AssertTrue(menuData->items(0) = "Save" AndAlso displayTest_TransformCount = 1, "ordinary item transforms once")
menu_AddDisplayItem testMenu, "Save", 0
AssertTrue(menuData->items(1) = "Save" AndAlso displayTest_TransformCount = 1, "display item preserves a translation collision")
menu_AddCommand testMenu, "Save", 17
AssertTrue(menuData->items(2) = "Exit" AndAlso displayTest_TransformCount = 2, "ordinary command transforms once")
AssertTrue(menuData->command_ids(2) = 17, "ordinary command keeps its identifier")
menu_AddDisplayCommand testMenu, "Save", 18
AssertTrue(menuData->items(3) = "Save" AndAlso displayTest_TransformCount = 2, "display command preserves exact text")
AssertTrue(menuData->command_ids(3) = 18, "display command keeps its identifier")
AssertTrue(menuData->item_enabled(3) <> 0 AndAlso menuData->item_visible(3) <> 0, "display command keeps ordinary enabled and visible defaults")
AssertTrue(menu_BeginUpdate(testMenu) <> 0, "display captions accept a sizing batch")
menu_AddDisplayItem testMenu, "A much longer &caption...", 0
AssertTrue(menuData->items(4) = "A much longer &caption...", "display caption preserves mnemonic and dialog cues")
AssertTrue(menu_EndUpdate(testMenu) <> 0 AndAlso testMenu->w > 100, "display caption publishes batch geometry")
test_Section "insertion bounds"
Dim As Integer validCount = menuData->count
menuData->count = MENU_MAX_ITEMS
menu_AddItem testMenu, "Open", 0
menu_AddDisplayCommand testMenu, "Save", 19
AssertTrue(menuData->count = MENU_MAX_ITEMS AndAlso displayTest_TransformCount = 2, "full menus reject insertion before transforming")
menuData->count = -1
menu_AddItem testMenu, "Open", 0
menu_AddCommand testMenu, "Open", 19
menu_AddDisplayItem testMenu, "Save", 0
menu_AddDisplayCommand testMenu, "Save", 19
AssertTrue(menuData->count = -1 AndAlso displayTest_TransformCount = 2, "negative counts reject insertion before array access")
menuData->count = validCount
menu_Destroy testMenu
Delete testMenu
gui_SetTextTransformHandler 0
backend_Exit
Screen 0
test_Summary
/' end of menu_display_text_smoke.bas '/
