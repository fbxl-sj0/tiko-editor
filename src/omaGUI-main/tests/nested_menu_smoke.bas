/'
    Project: omaGUI Test Suite
    --------------------------

    File: nested_menu_smoke.bas

    Purpose:
        Exercise real nested popup trees through the GUI input dispatcher.

    Responsibilities:
        - verify ownership, cycle rejection, and cleanup
        - verify mouse and keyboard selection across three menu levels
        - check viewport placement, drawing order, and focus restoration
        - ensure disabled commands and held presses cannot activate

    Targets:

        The FreeBASIC compiler and host selected by the omaGUI smoke-test suite.

    Module API:

        Standalone smoke-test entry point; this file exposes no reusable library API.

    This file intentionally does NOT contain:
        - application-specific menu commands
        - native operating-system menu calls
'/

#lang "fb"
#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"
#include once "test_harness.bi"

Dim Shared As Integer activationCount, lastCommand

Private Sub nestedMenu_Selected(ByVal context As Any Ptr, ByVal itemIndex As Integer)
    Dim As Widget Ptr selectedMenu = context
    activationCount += 1
    lastCommand = Cast(MenuData Ptr, selectedMenu->data)->command_ids(itemIndex)
End Sub

Private Sub nestedMenu_Key(ByVal scanCode As Integer)
    input_MockKeyPress(scanCode)
    gui_UpdateAll
End Sub

Private Sub nestedMenu_Mouse(ByVal x As Integer, ByVal y As Integer, ByVal buttons As Integer)
    input_MockMouse(x, y, buttons)
    gui_UpdateAll
End Sub

Private Sub nestedMenu_RemoveOnActivation(ByVal context As Any Ptr, ByVal itemIndex As Integer)
    Dim As Widget Ptr selectedMenu = context
    gui_RemoveWidget(selectedMenu->name)
End Sub

backend_Init 640, 400, BACKEND_HEADLESS_DRAWABLE
gui_Init
input_ResetForTest
input_MockMouse(0, 0, 0)

Dim As Widget Ptr editor = textbox_Create("menu_return_focus", "", 4, 4, 100, 24, 0, 0, TEXTBOX_SCROLLBAR_NONE)
gui_AddWidget(editor)
gui_SetFocus(editor)
Dim As Widget Ptr root = menu_Create("nested_root", 0, 0)
Dim As Widget Ptr child = menu_Create("nested_child", 0, 0)
Dim As Widget Ptr grandchild = menu_Create("nested_grandchild", 0, 0)
gui_AddWidget(root)
menu_AddCommand(root, "Unavailable", 10)
menu_SetItemDetails(root, 0, "", 0)
menu_AddSeparator(root)
menu_AddCommand(grandchild, "Execute deeply nested command", 42)
menu_SetSelectionHandler(grandchild, @nestedMenu_Selected, grandchild)
AssertTrue(menu_AddSubmenu(child, "Deeper choices", grandchild) = 0, "attach the deepest menu first")
menu_AddCommand(child, "Run", 37)
menu_SetSelectionHandler(child, @nestedMenu_Selected, child)
AssertTrue(menu_AddSubmenu(root, "Nested choices", child) = 2, "attach the child to its parent item")
menu_AddCommand(root, "Root command", 50)
menu_SetSelectionHandler(root, @nestedMenu_Selected, root)

test_Section("ownership and validation")
AssertTrue(child->parent = root AndAlso grandchild->parent = child, "submenus belong to the widget tree")
AssertTrue(menu_GetRoot(grandchild) = root, "grandchild resolves its root")
AssertTrue(menu_SetSubmenu(grandchild, 0, root) = 0, "reject an ancestor cycle")
AssertTrue(menu_SetSubmenu(root, -1, child) = 0, "reject a negative item index")
AssertTrue(menu_SetSubmenu(root, MENU_MAX_ITEMS, child) = 0, "reject an out-of-range item index")
AssertTrue(menu_SetSubmenu(root, 3, child) = 0, "reject a second owner for an attached submenu")

test_Section("keyboard navigation and placement")
menu_ShowAt(root, 630, 390, -1)
gui_UpdateAll
AssertTrue(Cast(MenuData Ptr, root->data)->selected = 2, "initial selection skips disabled items and separators")
AssertTrue(root->ax >= 0 AndAlso root->ax + root->w <= 640 AndAlso root->ay + root->h <= 400, "root fits the viewport")
nestedMenu_Key(KEY_RIGHT)
AssertTrue(root->visible <> 0 AndAlso child->visible <> 0, "Right opens a child while retaining its parent")
AssertTrue(child->ax < root->ax, "a child opens to the left near the right edge")
AssertTrue(child->ay >= 0 AndAlso child->ay + child->h <= 400, "child fits vertically")
nestedMenu_Key(KEY_RIGHT)
AssertTrue(grandchild->visible <> 0 AndAlso menu_GetOpenLeaf(root) = grandchild, "Right opens the third level")
AssertTrue(grandchild->ax >= 0 AndAlso grandchild->ax + grandchild->w <= 640, "third level stays within the viewport")
nestedMenu_Key(KEY_ESCAPE)
AssertTrue(grandchild->visible = 0 AndAlso child->visible <> 0 AndAlso root->visible <> 0, "Escape closes only the deepest level")
nestedMenu_Key(KEY_LEFT)
AssertTrue(child->visible = 0 AndAlso root->visible <> 0, "Left returns to the parent")
nestedMenu_Key(KEY_RIGHT)
nestedMenu_Key(KEY_RIGHT)
nestedMenu_Key(KEY_RETURN)
AssertTrue(activationCount = 1 AndAlso lastCommand = 42, "Enter activates the third-level command exactly once")
AssertTrue(root->visible = 0 AndAlso child->visible = 0 AndAlso grandchild->visible = 0, "command activation closes the whole tree")
AssertTrue(gui_GetFocus() = editor, "closing the menu restores editor focus")
AssertTrue(menu_TakeKeyboardHandled(root) <> 0, "menu activation reports keyboard consumption")
AssertTrue(menu_TakeKeyboardHandled(root) = 0, "keyboard consumption is taken only once")

menu_ShowAt(root, 200, 40, -1)
input_MockKeyPress(KEY_END)
input_MockKeyPress(KEY_UP)
input_MockKeyPress(KEY_RIGHT)
gui_UpdateAll
AssertTrue(child->visible <> 0 AndAlso menu_GetOpenLeaf(root) = child, "several navigation keys retain their order within one frame")
input_MockKeyPress(KEY_RIGHT)
input_MockKeyPress(KEY_RETURN)
gui_UpdateAll
AssertTrue(lastCommand = 42 AndAlso root->visible = 0, "a queued submenu open and activation are processed in order")
activationCount = 1

test_Section("pointer navigation")
menu_ShowAt(root, 200, 40)
gui_UpdateAll
Dim As Integer parentRowY = root->ay + 2 + 2 * Cast(MenuData Ptr, root->data)->item_height + 5
nestedMenu_Mouse(root->ax + 34, parentRowY, 0)
Cast(MenuData Ptr, root->data)->hover_clock = Timer - 0.2
gui_UpdateAll
gui_RenderAll
AssertTrue(child->visible <> 0 AndAlso root->visible <> 0, "hover opens the child without hiding its parent")
Dim As Integer runX = child->ax + 34
Dim As Integer runY = child->ay + 2 + Cast(MenuData Ptr, child->data)->item_height + 5
nestedMenu_Mouse(runX, runY, 1)
gui_UpdateAll
AssertTrue(activationCount = 1, "a held child-item press does not activate")
nestedMenu_Mouse(runX, runY, 0)
AssertTrue(activationCount = 2 AndAlso lastCommand = 37, "releasing a child item routes its own command")
gui_UpdateAll
AssertTrue(activationCount = 2, "a completed click cannot activate again")
menu_ShowAt(root, 200, 40)
gui_UpdateAll
nestedMenu_Mouse(root->ax + 34, root->ay + 7, 1)
nestedMenu_Mouse(root->ax + 34, root->ay + 7, 0)
AssertTrue(activationCount = 2 AndAlso root->visible <> 0, "disabled items cannot activate")
nestedMenu_Mouse(620, 10, 1)
nestedMenu_Mouse(620, 10, 0)
AssertTrue(root->visible = 0 AndAlso gui_GetFocus() = editor, "outside click dismisses the tree and restores focus")

test_Section("drawing and cleanup")
Dim As GUI_Theme childTheme
theme_InitDialog(childTheme)
childTheme.win_border = RGB(210, 40, 60)
child->appearance = @childTheme
menu_ShowAt(root, 630, 390)
menu_OpenSubmenu(root, 2)
gui_UpdateAll
backend_Clear RGB(0, 0, 0)
gui_RenderAll
AssertTrue(Point(child->ax + child->w - 1, child->ay + 5) = childTheme.win_border, "child draws above the overlapping parent edge")
AssertTrue(current_theme.control_style = GUI_CONTROL_STYLE_CLASSIC, "child appearance does not replace the desktop theme")
menu_ClearItems(root)
AssertTrue(gui_FindWidget("nested_child") = 0 AndAlso gui_FindWidget("nested_grandchild") = 0, "clearing a parent destroys all owned submenu levels")
AssertTrue(root->visible = 0, "a cleared popup cannot retain global input capture")

test_Section("long menus")
For itemIndex As Integer = 0 To MENU_MAX_ITEMS - 1
    menu_AddCommand(root, "Command " & LTrim(Str(itemIndex)), itemIndex)
Next itemIndex
menu_ShowAt(root, 30, 20, -1)
gui_UpdateAll
AssertTrue(root->h <= 400, "long menus fit the available viewport")
nestedMenu_Key(KEY_END)
AssertTrue(Cast(MenuData Ptr, root->data)->selected = MENU_MAX_ITEMS - 1 AndAlso _
    Cast(MenuData Ptr, root->data)->scroll_top > 0, "keyboard navigation reaches commands below the viewport")
menu_CloseTree(root)
menu_ClearItems(root)
menu_AddCommand(root, "Remove this popup", 70)
menu_SetSelectionHandler(root, @nestedMenu_RemoveOnActivation, root)
menu_ShowAt(root, 30, 20, -1)
nestedMenu_Key(KEY_RETURN)
AssertTrue(gui_FindWidget("nested_root") = 0, "root cleanup leaves no menu widgets")

test_Section("nesting limit and borrowed focus")
Dim As Widget Ptr depthRoot = menu_Create("depth_root", 0, 0)
gui_AddWidget(depthRoot)
Dim As Widget Ptr lastMenu = depthRoot
For level As Integer = 1 To MENU_MAX_NESTING - 1
    Dim As Widget Ptr nextMenu = menu_Create("depth_" & LTrim(Str(level)), 0, 0)
    AssertTrue(menu_AddSubmenu(lastMenu, "Next", nextMenu) = 0, "attach a valid nesting level")
    lastMenu = nextMenu
Next level
Dim As Widget Ptr overflowMenu = menu_Create("depth_overflow", 0, 0)
AssertTrue(menu_AddSubmenu(lastMenu, "Too deep", overflowMenu) = -1, "reject nesting beyond the documented limit")
menu_Destroy(overflowMenu)
Delete overflowMenu
gui_RemoveWidget("depth_root")
AssertTrue(gui_FindWidget("depth_31") = 0, "removing a root frees the deepest allowed level")
Dim As Widget Ptr focusMenu = menu_Create("borrowed_focus_menu", 0, 0)
gui_AddWidget(focusMenu)
menu_AddCommand(focusMenu, "Command", 80)
gui_SetFocus(editor)
menu_ShowAt(focusMenu, 30, 20)
gui_RemoveWidget(editor->name)
menu_CloseTree(focusMenu)
AssertTrue(gui_GetFocus() = 0, "closing a menu tolerates removal of its former focus owner")

test_Section("padded command menus")
menu_SetInsets(focusMenu, 10, 32, 32, 14)
menu_SetSelectionHandler(focusMenu, @nestedMenu_Selected, focusMenu)
menu_ShowAt(focusMenu, 30, 20)
gui_UpdateAll
Dim As Integer previousActivationCount = activationCount
nestedMenu_Mouse(focusMenu->ax + 40, focusMenu->ay + 3, 1)
nestedMenu_Mouse(focusMenu->ax + 40, focusMenu->ay + 3, 0)
AssertTrue(activationCount = previousActivationCount, "outer top padding does not activate a command")
menu_SetInsets(focusMenu, -1, 32, 32, 14)
AssertTrue(Cast(MenuData Ptr, focusMenu->data)->vertical_inset = 10, "reject invalid insets without changing the popup")
nestedMenu_Mouse(focusMenu->ax + 40, focusMenu->ay + 14, 1)
nestedMenu_Mouse(focusMenu->ax + 40, focusMenu->ay + 14, 0)
AssertTrue(activationCount = previousActivationCount + 1 AndAlso lastCommand = 80, "padded rows activate through the same pointer geometry as drawing")

gui_ResetForTest
backend_Exit
Screen 0
test_Summary

' end of nested_menu_smoke.bas
