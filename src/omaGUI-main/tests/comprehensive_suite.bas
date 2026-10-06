/'
    Project: omaGUI
    ---------------

    File: comprehensive_suite.bas

    Purpose:

        Run the broad interaction and widget logic regression suite.

    Responsibilities:

        - verify ordinary widget pointer and keyboard behavior
        - verify list selection fires once on release inside the pressed row
        - verify textbox and list state transitions
        - report results through the common test harness

    This file intentionally does NOT contain:

        - visual screenshot comparisons
        - native window-driver tests
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION

#include once "omaGUI.bi"
#include once "tests/test_harness.bi"

Type ComprehensiveMenuContext
    As Integer selection_count
    As Integer selected_index
End Type

Private Sub comprehensive_OnMenuSelection( _
    ByVal context As Any Ptr, ByVal selectedIndex As Integer _
)
    Dim menu_context As ComprehensiveMenuContext Ptr = _
        Cast(ComprehensiveMenuContext Ptr, context)
    If menu_context = 0 Then Exit Sub
    menu_context->selection_count += 1
    menu_context->selected_index = selectedIndex
End Sub

Print "omaGUI Comprehensive Logic Test Suite"
backend_Init(800, 600, -1)
gui_Init()

' --- 1. Test Button Interaction (Hold/Exit/Release) ---
Print "Testing Button Interaction Logic..."
Dim As Widget Ptr btn = button_Create("btn", "Test", 10, 10, 50, 20)
gui_AddWidget(btn)
Dim As ButtonData Ptr bd = btn->data

AssertTrue gui_GetPointerWidgetNameAt(15, 15) = "btn", _
    "Pointer hit testing identifies the dispatched widget"
AssertTrue gui_GetPointerWidgetNameAt(200, 200) = "", _
    "Pointer hit testing reports an empty desktop"

' Hover
input_MockMouse(15, 15, 0) : gui_UpdateAll()
AssertTrue bd->state = 1, "Button hover state"

' Press
input_MockMouse(15, 15, 1) : gui_UpdateAll()
AssertTrue bd->state = 2, "Button press state"

AssertTrue gui_GetPointerCaptureName() = "btn", _
    "Pointer capture reports the pressed widget"

' Exit while holding
input_MockMouse(100, 100, 1) : gui_UpdateAll()
AssertTrue bd->state = 0, "Button exit while holding"

' Re-enter while holding
input_MockMouse(15, 15, 1) : gui_UpdateAll()
AssertTrue bd->state = 2, "Button re-enter while holding"

' Release
input_MockMouse(15, 15, 0) : gui_UpdateAll()
AssertTrue gui_ButtonPressed("btn") <> 0, "Button click release"

AssertTrue gui_GetPointerCaptureName() = "", _
    "Pointer capture clears after release"

btn->visible = 0
btn->enabled = 0
AssertTrue gui_ButtonPressed("btn") = 0, _
    "Hidden buttons cannot repeat a stale release event"
btn->visible = -1
btn->enabled = -1
gui_UpdateAll()

' --- 2. Test ListBox Release Selection ---
Print "Testing ListBox Release Logic..."
Dim As Widget Ptr releaseList = listbox_Create("release_list", 300, 10, 140, 80)
gui_AddWidget releaseList
listbox_AddItem releaseList, "Zero"
listbox_AddItem releaseList, "One"
listbox_AddItem releaseList, "Two"

input_MockMouse(310, 34, 1) : gui_UpdateAll()
input_MockMouse(310, 34, 1) : gui_UpdateAll()
AssertTrue listbox_GetSelectedIndex(releaseList) = -1, _
    "ListBox hold does not publish a selection"
input_MockMouse(500, 100, 1) : gui_UpdateAll()
input_MockMouse(500, 100, 0) : gui_UpdateAll()
AssertTrue listbox_GetSelectedIndex(releaseList) = -1, _
    "ListBox release outside cancels selection"

input_MockMouse(310, 50, 1) : gui_UpdateAll()
input_MockMouse(310, 50, 1) : gui_UpdateAll()
input_MockMouse(310, 50, 0) : gui_UpdateAll()
AssertTrue listbox_GetSelectedIndex(releaseList) = 2, _
    "ListBox release inside selects exactly one row"
listbox_Clear releaseList
listbox_AddItem releaseList, "Replacement zero"
listbox_AddItem releaseList, "Replacement one"
gui_UpdateAll()
AssertTrue listbox_GetSelectedIndex(releaseList) = -1, _
    "ListBox replacement content is not selected by the completed click"

' --- 3. Test Menu Release Logic ---
Print "Testing Menu Release Logic..."
Dim As ComprehensiveMenuContext menuContext
Dim As Widget Ptr releaseMenu = menu_Create("release_menu", 500, 10)
menu_AddItem releaseMenu, "First", 0
menu_AddItem releaseMenu, "Second", 0
menu_SetSelectionHandler releaseMenu, _
    @comprehensive_OnMenuSelection, @menuContext
releaseMenu->visible = -1
gui_AddWidget releaseMenu

input_MockMouse(510, 16, 1) : gui_UpdateAll()
input_MockMouse(510, 16, 1) : gui_UpdateAll()
AssertTrue menuContext.selection_count = 0, _
    "Menu hold does not publish a selection"
input_MockMouse(510, 16, 0) : gui_UpdateAll()
AssertTrue menuContext.selection_count = 1 AndAlso _
           menuContext.selected_index = 0 AndAlso _
           releaseMenu->visible = 0, _
    "Menu release inside selects exactly one item"

releaseMenu->visible = 1
menuContext.selection_count = 0
menuContext.selected_index = -1
input_MockMouse(510, 36, 1) : gui_UpdateAll()
input_MockMouse(700, 200, 1) : gui_UpdateAll()
input_MockMouse(700, 200, 0) : gui_UpdateAll()
AssertTrue menuContext.selection_count = 0 AndAlso _
           releaseMenu->visible = 0, _
    "Menu release outside cancels the held item"

' --- 4. Test RadioBox Exclusivity ---
Print "Testing RadioBox Exclusivity..."
Dim As Widget Ptr r1 = radiobox_Create("r1", "Opt1", 10, 50, 1, 1)
Dim As Widget Ptr r2 = radiobox_Create("r2", "Opt2", 10, 70, 1, 0)
gui_AddWidget(r1) : gui_AddWidget(r2)

' Click R2
input_MockMouse(15, 75, 1) : gui_UpdateAll()
input_MockMouse(15, 75, 0) : gui_UpdateAll()

Dim As RadioBoxData Ptr rd1 = r1->data
Dim As RadioBoxData Ptr rd2 = r2->data
AssertTrue rd1->selected = 0 AndAlso rd2->selected = 1, _
    "RadioBox exclusivity"

' --- 5. Test ScrollBar Draggable ---
Print "Testing ScrollBar Dragging..."
Dim As Widget Ptr sb = scrollbar_Create("sb", 100, 100, 20, 100, 100)
gui_AddWidget(sb)
Dim As ScrollBarData Ptr sbd = sb->data

scrollbar_SetAutomaticRepeat sb, 0
scrollbar_SetValue sb, 50
input_MockMouse(110, 150, 1) : gui_UpdateAll() ' Grab the middle thumb
input_MockMouse(110, 160, 1) : gui_UpdateAll() ' Drag it down the track
AssertTrue sbd->value >= 60 AndAlso sbd->value <= 62, _
    "Scrollbar drag value"
input_MockMouse(110, 150, 0) : gui_UpdateAll()

' --- 6. Test Multi-line TextBox Entry ---
Print "Testing Multi-line Text Entry..."
Dim As Widget Ptr tb = textbox_Create("tb", "", 200, 200, 100, 50, 1, 0)
gui_AddWidget(tb)
Dim As TextBoxData Ptr tbd = tb->data

AssertTrue textbox_SetPlaceholder(tb, "Enter mission notes") <> 0, _
    "Textbox accepts bounded placeholder guidance"
AssertTrue textbox_GetPlaceholder(tb) = "Enter mission notes", _
    "Textbox returns configured placeholder guidance"
AssertTrue tbd->text = "", _
    "Placeholder guidance does not become editable text"
AssertTrue textbox_SetPlaceholder( _
    tb, String(TEXTBOX_PLACEHOLDER_MAX_LENGTH + 1, "x") _
) = 0 AndAlso _
    textbox_GetPlaceholder(tb) = "Enter mission notes", _
    "Textbox rejects oversized placeholder guidance without mutation"

input_MockMouse(210, 210, 1) : gui_UpdateAll() ' Focus
input_MockMouse(210, 210, 0) : gui_UpdateAll()
input_MockText("Line1") : gui_UpdateAll()
input_MockKey(KEY_RETURN, 1) : gui_UpdateAll() : input_MockKey(KEY_RETURN, 0) ' Newline
input_MockText("Line2") : gui_UpdateAll()

AssertTrue InStr(tbd->text, "Line1") <> 0 AndAlso _
    InStr(tbd->text, "Line2") <> 0, "Multi-line text entry"

AssertTrue textbox_GetPlaceholder(0) = "", _
    "Textbox placeholder query rejects a null widget safely"

Print "Comprehensive Tests Finished."
backend_Exit()
test_Summary()

/' end of comprehensive_suite.bas '/
