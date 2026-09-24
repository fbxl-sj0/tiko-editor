/'
    Project: Tiko Editor Native UI
    -----------------------------

    File: tiko_native_ui.bi

    Purpose:

        Build Tiko's main editor shell from omaGUI widgets and application-owned
        drawing callbacks.

    Responsibilities:

        - reproduce Tiko's menu, explorer, toolbar, document tabs, and statusbar
        - connect the visible native controls to editor operations
        - keep layout and appearance policy in the Tiko application layer

    This file intentionally does NOT contain:

        - generic widget behavior that belongs in omaGUI
        - platform window, input, or clipboard implementations
        - the Windows-only editor implementation
'/

#pragma once

Const TIKO_VISUAL_MENU_BAR As Integer = 1
Const TIKO_VISUAL_PANEL As Integer = 2
Const TIKO_VISUAL_TAB_STRIP As Integer = 3
Const TIKO_VISUAL_STATUS_BAR As Integer = 4
Const TIKO_VISUAL_OUTPUT_TABS As Integer = 5
Const TIKO_VISUAL_FIND_BAR As Integer = 6

Declare Function tiko_TabVisibleDocumentAt(ByVal tabIndex As Integer) As Integer
Declare Function tiko_ExplorerCategoryAt(ByVal localY As Integer) As Integer
Declare Sub tiko_OutputTabsRender(ByVal w As Widget Ptr)
Declare Sub tiko_OutputTabsUpdate(ByVal w As Widget Ptr)
Declare Sub tiko_FindBarRender(ByVal w As Widget Ptr)
Declare Function tiko_OutputTabLeft(ByVal tabIndex As Integer) As Integer
Declare Function tiko_OutputTabWidth(ByVal tabIndex As Integer) As Integer

Const TIKO_OUTPUT_TAB_COUNT As Integer = 5
Dim Shared As ZString * 24 tiko_OutputTabNames(0 To TIKO_OUTPUT_TAB_COUNT - 1) = _
    {"COMPILER RESULTS", "COMPILER LOG FILE", "SEARCH RESULTS", "TODO", "NOTES"}

Function tiko_CreateVisualWidget( _
    ByVal widgetName As String, ByVal x As Integer, ByVal y As Integer, _
    ByVal widgetWidth As Integer, ByVal widgetHeight As Integer, _
    ByVal controlKind As Integer _
) As Widget Ptr

    Dim As Widget Ptr wgt = New Widget
    Dim As TikoVisualData Ptr visualData = New TikoVisualData

    If wgt = 0 OrElse visualData = 0 Then
        If wgt <> 0 Then Delete wgt
        If visualData <> 0 Then Delete visualData
        Return 0
    End If

    wgt->name = widgetName
    wgt->x = x
    wgt->y = y
    wgt->w = widgetWidth
    wgt->h = widgetHeight
    wgt->visible = -1
    wgt->enabled = -1
    wgt->data = visualData
    wgt->destroy = @tiko_VisualDestroy

    Select Case controlKind
    Case TIKO_VISUAL_MENU_BAR
        wgt->render = @tiko_MenuBarRender
        wgt->update = @tiko_MenuBarUpdate
    Case TIKO_VISUAL_PANEL
        wgt->render = @tiko_PanelRender
        wgt->update = @tiko_PanelUpdate
    Case TIKO_VISUAL_TAB_STRIP
        wgt->render = @tiko_TabStripRender
        wgt->update = @tiko_TabStripUpdate
    Case TIKO_VISUAL_STATUS_BAR
        wgt->render = @tiko_StatusBarRender
        wgt->update = 0
    Case TIKO_VISUAL_OUTPUT_TABS
        wgt->render = @tiko_OutputTabsRender
        wgt->update = @tiko_OutputTabsUpdate
    Case TIKO_VISUAL_FIND_BAR
        wgt->render = @tiko_FindBarRender
        wgt->update = 0
    Case Else
        Delete visualData
        Delete wgt
        Return 0
    End Select

    Return wgt

End Function


Sub tiko_VisualDestroy(ByVal w As Widget Ptr)
    If w <> 0 AndAlso w->data <> 0 Then Delete Cast(TikoVisualData Ptr, w->data)
End Sub


Function tiko_MenuLeft(ByVal menuIndex As Integer) As Integer

    Dim As Integer leftPosition = 10

    If menuIndex < 0 OrElse menuIndex >= TIKO_MENU_COUNT Then Return leftPosition

    For itemIndex As Integer = 0 To menuIndex - 1
        leftPosition += backend_GetTextWidth(tiko_MenuNames(itemIndex)) + 18
    Next itemIndex

    Return leftPosition

End Function


Function tiko_MenuIndexAt(ByVal mouseX As Integer, ByVal mouseY As Integer) As Integer

    If mouseY < 0 OrElse mouseY >= TIKO_MENU_HEIGHT Then Return -1

    For itemIndex As Integer = 0 To TIKO_MENU_COUNT - 1
        Dim As Integer itemLeft = tiko_MenuLeft(itemIndex)
        Dim As Integer itemRight = itemLeft + _
            backend_GetTextWidth(tiko_MenuNames(itemIndex)) + 18
        If mouseX >= itemLeft AndAlso mouseX < itemRight Then Return itemIndex
    Next itemIndex

    Return -1

End Function


Sub tiko_MenuBarRender(ByVal w As Widget Ptr)

    Dim As Integer mouseX = input_MouseX()
    Dim As Integer mouseY = input_MouseY()

    backend_Rect(w->ax, w->ay, w->w, w->h, tiko_ColorMenu, -1)

    For itemIndex As Integer = 0 To TIKO_MENU_COUNT - 1
        Dim As Integer itemLeft = tiko_MenuLeft(itemIndex)
        Dim As Integer itemWidth = backend_GetTextWidth(tiko_MenuNames(itemIndex)) + 18
        Dim As ULong itemColor = tiko_ColorMenu

        If tiko_ActiveMenuIndex = itemIndex OrElse _
           (mouseY >= w->ay AndAlso mouseY < w->ay + w->h AndAlso _
            mouseX >= itemLeft AndAlso mouseX < itemLeft + itemWidth) Then
            itemColor = tiko_ColorHover
        End If

        backend_Rect(itemLeft, w->ay + 2, itemWidth, w->h - 4, itemColor, -1)
        backend_Print(itemLeft + 9, w->ay + 8, tiko_ColorText, tiko_MenuNames(itemIndex))
    Next itemIndex

    backend_Line(w->ax, w->ay + w->h - 1, w->ax + w->w - 1, _
        w->ay + w->h - 1, tiko_ColorLine)

End Sub


Sub tiko_MenuBarUpdate(ByVal w As Widget Ptr)

    Dim As TikoVisualData Ptr visualData = Cast(TikoVisualData Ptr, w->data)
    Dim As Integer mouseButtons = input_MouseButtons()

    If mouseButtons And 1 Then
        If visualData->pointer_down = 0 Then
            Dim As Integer menuIndex = tiko_MenuIndexAt(input_MouseX(), input_MouseY())
            visualData->pointer_down = -1

            If menuIndex >= 0 Then
                If menuIndex = tiko_ActiveMenuIndex AndAlso _
                   tiko_PopupMenu <> 0 AndAlso tiko_PopupMenu->visible <> 0 Then
                    tiko_CloseMenu
                Else
                    tiko_ShowMenu(menuIndex, tiko_MenuLeft(menuIndex))
                End If
            End If
        End If
    Else
        visualData->pointer_down = 0
    End If

End Sub


Sub tiko_DismissMenuOnOutsideClick()

    Static As Integer previousButtons
    Dim As Integer mouseButtons = input_MouseButtons()

    If mouseButtons = 0 Then
        previousButtons = 0
        Exit Sub
    End If
    If previousButtons <> 0 Then Exit Sub
    previousButtons = -1

    If tiko_ActiveMenuIndex < 0 OrElse tiko_PopupMenu = 0 OrElse _
       tiko_PopupMenu->visible = 0 Then Exit Sub

    Dim As Integer mouseX = input_MouseX()
    Dim As Integer mouseY = input_MouseY()
    If (mouseX >= tiko_PopupMenu->ax AndAlso _
        mouseX < tiko_PopupMenu->ax + tiko_PopupMenu->w AndAlso _
        mouseY >= tiko_PopupMenu->ay AndAlso _
        mouseY < tiko_PopupMenu->ay + tiko_PopupMenu->h) Then Exit Sub
    If mouseY >= 0 AndAlso mouseY < TIKO_MENU_HEIGHT Then Exit Sub

    tiko_CloseMenu

End Sub


Sub tiko_AddPopupItem(ByVal labelText As String, ByVal actionId As Integer)

    If tiko_PopupMenu = 0 OrElse _
       tiko_CurrentMenuActionCount >= UBound(tiko_CurrentMenuActions) + 1 Then Exit Sub

    tiko_CurrentMenuActions(tiko_CurrentMenuActionCount) = actionId
    menu_AddItem(tiko_PopupMenu, labelText, 0)
    tiko_CurrentMenuActionCount += 1

End Sub


Sub tiko_AddPopupSeparator()

    If tiko_PopupMenu = 0 OrElse _
       tiko_CurrentMenuActionCount >= UBound(tiko_CurrentMenuActions) + 1 Then Exit Sub

    tiko_CurrentMenuActions(tiko_CurrentMenuActionCount) = TIKO_ACTION_NONE
    menu_AddSeparator(tiko_PopupMenu)
    tiko_CurrentMenuActionCount += 1

End Sub


Sub tiko_ShowMenu(ByVal menuIndex As Integer, ByVal menuX As Integer)

    Dim As Integer screenHeight
    Dim As Integer screenWidth

    If tiko_PopupMenu = 0 OrElse menuIndex < 0 OrElse _
       menuIndex >= TIKO_MENU_COUNT Then Exit Sub

    menu_ClearItems(tiko_PopupMenu)
    menu_SetItemHeight(tiko_PopupMenu, 18)
    tiko_CurrentMenuActionCount = 0

    Select Case menuIndex
    Case 0
        tiko_AddPopupItem("New", TIKO_ACTION_NEW)
        tiko_AddPopupItem("Open...", TIKO_ACTION_OPEN)
        tiko_AddPopupItem("Open File As Template...", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Open Recent", TIKO_ACTION_NONE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Close", TIKO_ACTION_CLOSE)
        tiko_AddPopupItem("Close All", TIKO_ACTION_CLOSE_ALL)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Save", TIKO_ACTION_SAVE)
        tiko_AddPopupItem("Save All", TIKO_ACTION_SAVE_ALL)
        tiko_AddPopupItem("Save As...", TIKO_ACTION_SAVE_AS)
        tiko_AddPopupItem("Rename...", TIKO_ACTION_NONE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Load Session...", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Save Session...", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Close Session", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Recent Sessions", TIKO_ACTION_NONE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("User Tools", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Environment Options...", TIKO_ACTION_NONE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Exit", TIKO_ACTION_EXIT)
    Case 1
        tiko_AddPopupItem("Undo", TIKO_ACTION_UNDO)
        tiko_AddPopupItem("Redo", TIKO_ACTION_REDO)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Cut", TIKO_ACTION_CUT)
        tiko_AddPopupItem("Copy", TIKO_ACTION_COPY)
        tiko_AddPopupItem("Paste", TIKO_ACTION_PASTE)
        tiko_AddPopupItem("Delete Line", TIKO_ACTION_DELETE_LINE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Find...", TIKO_ACTION_FIND)
        tiko_AddPopupItem("Find In Files...", TIKO_ACTION_FIND_IN_FILES)
        tiko_AddPopupItem("Replace...", TIKO_ACTION_REPLACE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Duplicate Line", TIKO_ACTION_DUPLICATE_LINE)
        tiko_AddPopupItem("Move Line Up", TIKO_ACTION_MOVE_LINE_UP)
        tiko_AddPopupItem("Move Line Down", TIKO_ACTION_MOVE_LINE_DOWN)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Comment Block", TIKO_ACTION_COMMENT_BLOCK)
        tiko_AddPopupItem("UnComment Block", TIKO_ACTION_UNCOMMENT_BLOCK)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Select Line", TIKO_ACTION_SELECT_LINE)
        tiko_AddPopupItem("Select All", TIKO_ACTION_SELECT_ALL)
    Case 2
        tiko_AddPopupItem("Sub/Function Definition", TIKO_ACTION_GOTO_DEFINITION)
        tiko_AddPopupItem("Last Position", TIKO_ACTION_LAST_POSITION)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Next Function", TIKO_ACTION_NEXT_FUNCTION)
        tiko_AddPopupItem("Previous Function", TIKO_ACTION_PREVIOUS_FUNCTION)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Goto Header File", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Goto Code File", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Goto Main File", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Goto Resource File", TIKO_ACTION_NONE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Toggle Bookmark", TIKO_ACTION_BOOKMARK_TOGGLE)
        tiko_AddPopupItem("Next Bookmark", TIKO_ACTION_BOOKMARK_NEXT)
        tiko_AddPopupItem("Previous Bookmark", TIKO_ACTION_BOOKMARK_PREVIOUS)
        tiko_AddPopupItem("Clear Bookmarks", TIKO_ACTION_BOOKMARK_CLEAR)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Goto Line...", TIKO_ACTION_GOTO_LINE)
    Case 3
        tiko_AddPopupItem("View Side Panel", TIKO_ACTION_TOGGLE_PANEL)
        tiko_AddPopupItem("View Explorer Window", TIKO_ACTION_EXPLORER)
        tiko_AddPopupItem("View Output Window", TIKO_ACTION_TOGGLE_OUTPUT)
        tiko_AddPopupItem("View Function List", TIKO_ACTION_FUNCTIONS)
        tiko_AddPopupItem("View Bookmarks List", TIKO_ACTION_BOOKMARKS)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Zoom In", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Zoom Out", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Zoom Reset", TIKO_ACTION_NONE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Toggle Split Editor Left/Right", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Toggle Split Editor Top/Bottom", TIKO_ACTION_NONE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Toggle Current Fold Point", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Toggle Current And All Below", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Fold All", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Unfold All", TIKO_ACTION_NONE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Move Explorer Window Left/Right", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Restore Main Window Size", TIKO_ACTION_NONE)
    Case 4
        tiko_AddPopupItem("New Project", TIKO_ACTION_PROJECT_NEW)
        tiko_AddPopupItem("Open Project...", TIKO_ACTION_PROJECT_OPEN)
        tiko_AddPopupItem("Recent Projects", TIKO_ACTION_NONE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Close Project", TIKO_ACTION_PROJECT_CLOSE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Save Project As...", TIKO_ACTION_PROJECT_SAVE_AS)
        tiko_AddPopupItem("Save Project", TIKO_ACTION_PROJECT_SAVE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Add Files to Project...", TIKO_ACTION_NONE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Project Options...", TIKO_ACTION_NONE)
    Case 5
        tiko_AddPopupItem("Build And Execute", TIKO_ACTION_BUILD_RUN)
        tiko_AddPopupItem("Compile", TIKO_ACTION_BUILD)
        tiko_AddPopupItem("Rebuild All", TIKO_ACTION_NONE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Quick Run", TIKO_ACTION_BUILD_RUN)
        tiko_AddPopupItem("Run Executable", TIKO_ACTION_NONE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Command Line...", TIKO_ACTION_NONE)
    Case 6
        tiko_AddPopupItem("Start Debugging", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Stop Debugging", TIKO_ACTION_NONE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Step Into", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Step Over", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Step Out", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Run to Cursor", TIKO_ACTION_NONE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("Toggle Breakpoint", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Delete All Breakpoints", TIKO_ACTION_NONE)
    Case 7
        tiko_AddPopupItem("FreeBASIC Help", TIKO_ACTION_NONE)
        tiko_AddPopupItem("Tiko Editor Help", TIKO_ACTION_NONE)
        tiko_AddPopupSeparator
        tiko_AddPopupItem("About", TIKO_ACTION_ABOUT)
    End Select

    backend_GetSize screenWidth, screenHeight
    If menuX + tiko_PopupMenu->w > screenWidth Then _
        menuX = screenWidth - tiko_PopupMenu->w
    If menuX < 0 Then menuX = 0
    tiko_PopupMenu->x = menuX
    tiko_PopupMenu->y = TIKO_MENU_HEIGHT
    If tiko_PopupMenu->h > screenHeight - TIKO_MENU_HEIGHT Then _
        menu_SetItemHeight(tiko_PopupMenu, 16)
    tiko_PopupMenu->visible = -1
    tiko_ActiveMenuIndex = menuIndex
    gui_BringToFront(tiko_PopupMenu)

End Sub


Sub tiko_CloseMenu()
    If tiko_PopupMenu <> 0 Then tiko_PopupMenu->visible = 0
    tiko_ActiveMenuIndex = -1
End Sub


Private Function tiko_FirstMenuItem() As Integer

    Dim As MenuData Ptr menuData

    tiko_FirstMenuItem = -1
    If tiko_PopupMenu = 0 OrElse tiko_PopupMenu->data = 0 Then Return -1
    menuData = Cast(MenuData Ptr, tiko_PopupMenu->data)
    For itemIndex As Integer = 0 To menuData->count - 1
        If menuData->is_separator(itemIndex) = 0 Then Return itemIndex
    Next itemIndex

End Function


Private Sub tiko_MoveMenuSelection(ByVal direction As Integer)

    Dim As MenuData Ptr menuData
    Dim As Integer candidate

    If tiko_PopupMenu = 0 OrElse tiko_PopupMenu->data = 0 Then Exit Sub
    menuData = Cast(MenuData Ptr, tiko_PopupMenu->data)
    If menuData->count <= 0 Then Exit Sub

    candidate = menuData->selected
    For attempt As Integer = 0 To menuData->count - 1
        candidate += direction
        If candidate < 0 Then candidate = menuData->count - 1
        If candidate >= menuData->count Then candidate = 0
        If menuData->is_separator(candidate) = 0 Then
            menuData->selected = candidate
            Exit Sub
        End If
    Next attempt
    menuData->selected = -1

End Sub


Sub tiko_OnMenuSelection(ByVal context As Any Ptr, ByVal itemIndex As Integer)

    Dim As MenuData Ptr menuData
    Dim As String itemText

    If tiko_PopupMenu = 0 OrElse tiko_PopupMenu->data = 0 Then Return
    If itemIndex < 0 OrElse itemIndex >= tiko_CurrentMenuActionCount Then Return

    menuData = Cast(MenuData Ptr, tiko_PopupMenu->data)
    itemText = menuData->items(itemIndex)
    tiko_ExecuteMenuAction(tiko_CurrentMenuActions(itemIndex), itemText)
    tiko_CloseMenu
    If gui_IsModalOpen() = 0 Then
        If tiko_ShowFindBar <> 0 AndAlso tiko_FindBox <> 0 Then
            gui_SetFocus(tiko_FindBox)
        Elseif tiko_Editor <> 0 Then
            gui_SetFocus(tiko_Editor)
        End If
    End If

End Sub


Sub tiko_ExecuteMenuAction(ByVal actionId As Integer, ByVal itemText As String)

    Dim As TextBoxData Ptr textData

    Select Case actionId
    Case TIKO_ACTION_NEW
        tiko_CreateDocument
    Case TIKO_ACTION_OPEN
        tiko_OpenFileDialog
    Case TIKO_ACTION_SAVE
        tiko_SaveCurrentDocument
    Case TIKO_ACTION_SAVE_AS
        tiko_SaveCurrentAs
    Case TIKO_ACTION_SAVE_ALL
        tiko_SaveAllDocuments
    Case TIKO_ACTION_CLOSE_ALL
        tiko_CloseAllDocuments
    Case TIKO_ACTION_CLOSE
        tiko_RequestCloseDocument
    Case TIKO_ACTION_EXIT
        tiko_RequestExit
    Case TIKO_ACTION_BUILD
        tiko_RequestBuild(0)
    Case TIKO_ACTION_BUILD_RUN
        tiko_RequestBuild(-1)
    Case TIKO_ACTION_FIND
        tiko_ShowFind
    Case TIKO_ACTION_FIND_IN_FILES
        tiko_ShowFindInFiles
    Case TIKO_ACTION_REPLACE
        tiko_ShowReplace
    Case TIKO_ACTION_FIND_NEXT
        tiko_FindNext
    Case TIKO_ACTION_GOTO_LINE
        tiko_ShowGotoLine
    Case TIKO_ACTION_NEXT_FUNCTION
        tiko_GotoNextFunction
    Case TIKO_ACTION_PREVIOUS_FUNCTION
        tiko_GotoPreviousFunction
    Case TIKO_ACTION_GOTO_DEFINITION
        tiko_GotoDefinition
    Case TIKO_ACTION_LAST_POSITION
        tiko_GotoLastPosition
    Case TIKO_ACTION_NEXT_DOCUMENT
        tiko_ActivateRelativeDocument(1)
    Case TIKO_ACTION_PREVIOUS_DOCUMENT
        tiko_ActivateRelativeDocument(-1)
    Case TIKO_ACTION_UNDO
        If textbox_Undo(tiko_Editor) = 0 Then tiko_SetStatus("Nothing to undo")
    Case TIKO_ACTION_REDO
        If textbox_Redo(tiko_Editor) = 0 Then tiko_SetStatus("Nothing to redo")
    Case TIKO_ACTION_CUT
        tiko_CutSelection
    Case TIKO_ACTION_COPY
        tiko_CopySelection
    Case TIKO_ACTION_PASTE
        tiko_PasteSelection
    Case TIKO_ACTION_DELETE_LINE
        tiko_DeleteCurrentLine
    Case TIKO_ACTION_DUPLICATE_LINE
        tiko_DuplicateLineOrSelection
    Case TIKO_ACTION_MOVE_LINE_UP
        tiko_MoveCurrentLine(-1)
    Case TIKO_ACTION_MOVE_LINE_DOWN
        tiko_MoveCurrentLine(1)
    Case TIKO_ACTION_COMMENT_BLOCK
        tiko_CommentSelectedLines(-1)
    Case TIKO_ACTION_UNCOMMENT_BLOCK
        tiko_CommentSelectedLines(0)
    Case TIKO_ACTION_SELECT_LINE
        tiko_SelectCurrentLine
    Case TIKO_ACTION_BOOKMARK_TOGGLE
        tiko_ToggleBookmark
    Case TIKO_ACTION_BOOKMARK_NEXT
        tiko_MoveToBookmark(1)
    Case TIKO_ACTION_BOOKMARK_PREVIOUS
        tiko_MoveToBookmark(-1)
    Case TIKO_ACTION_BOOKMARK_CLEAR
        tiko_ClearBookmarks
    Case TIKO_ACTION_SELECT_ALL
        If tiko_Editor <> 0 AndAlso tiko_Editor->data <> 0 Then
            textData = Cast(TextBoxData Ptr, tiko_Editor->data)
            textData->sel_start = 0
            textData->sel_end = Len(textData->text)
            textData->selection_anchor = 0
            textData->cursor_pos = textData->sel_end
            textData->viewport_dirty = -1
            gui_SetFocus(tiko_Editor)
        End If
    Case TIKO_ACTION_TOGGLE_PANEL
        tiko_ShowSidePanel = IIf(tiko_ShowSidePanel <> 0, 0, -1)
        tiko_ResizeWidgets
    Case TIKO_ACTION_TOGGLE_OUTPUT
        tiko_ShowOutput = IIf(tiko_ShowOutput <> 0, 0, -1)
        tiko_ResizeWidgets
    Case TIKO_ACTION_EXPLORER
        tiko_SidePanelPage = 0
        tiko_ShowSidePanel = -1
        tiko_ResizeWidgets
    Case TIKO_ACTION_FUNCTIONS
        tiko_SidePanelPage = 1
        tiko_ShowSidePanel = -1
        tiko_ResizeWidgets
    Case TIKO_ACTION_BOOKMARKS
        tiko_SidePanelPage = 2
        tiko_ShowSidePanel = -1
        tiko_ResizeWidgets
    Case TIKO_ACTION_ABOUT
        tiko_SetStatus("Tiko Editor 1.3.2, native FreeBASIC port")
    Case TIKO_ACTION_PROJECT_NEW
        tiko_NewProject
    Case TIKO_ACTION_PROJECT_OPEN
        tiko_OpenProjectDialog
    Case TIKO_ACTION_PROJECT_CLOSE
        tiko_CloseProject
    Case TIKO_ACTION_PROJECT_SAVE
        tiko_SaveProject
    Case TIKO_ACTION_PROJECT_SAVE_AS
        tiko_SaveProjectAs
    Case Else
        If itemText <> "" Then _
            tiko_SetStatus(itemText & " is not ported to the native editor yet")
    End Select

End Sub


Sub tiko_ShowFind()

    If tiko_FindBox = 0 Then Exit Sub
    If tiko_Editor <> 0 AndAlso tiko_Editor->data <> 0 Then
        Dim As TextBoxData Ptr editorData = _
            Cast(TextBoxData Ptr, tiko_Editor->data)
        If editorData->sel_end > editorData->sel_start Then
            Dim As String selectionText = Mid( _
                editorData->text, editorData->sel_start + 1, _
                editorData->sel_end - editorData->sel_start _
            )
            If Instr(selectionText, Chr(10)) = 0 Then _
                textbox_SetText(tiko_FindBox, selectionText, -1)
        End If
    End If
    tiko_SetFindBarMode(TIKO_FIND_MODE_FIND)
    tiko_SetStatus("Find in current document")

End Sub


Sub tiko_ShowReplace()
    tiko_SetFindBarMode(TIKO_FIND_MODE_REPLACE)
    tiko_SetStatus("Replace in current document")
End Sub


Sub tiko_ShowFindInFiles()
    tiko_SetFindBarMode(TIKO_FIND_MODE_FILES)
    tiko_SetStatus("Find in open files")
End Sub


Sub tiko_ShowGotoLine()
    Dim As TextBoxData Ptr editorData

    If tiko_Editor <> 0 AndAlso tiko_Editor->data <> 0 AndAlso _
       tiko_FindBox <> 0 Then
        editorData = Cast(TextBoxData Ptr, tiko_Editor->data)
        textbox_SetText(tiko_FindBox, _
            LTrim(Str(tiko_LineNumberAt( _
                editorData->text, editorData->cursor_pos _
            ))), -1)
    End If
    tiko_SetFindBarMode(TIKO_FIND_MODE_GOTO)
    tiko_SetStatus("Go to source line")
End Sub


Private Sub tiko_SetButtonText( _
    ByVal buttonWidget As Widget Ptr, ByVal textValue As String _
)
    If buttonWidget <> 0 AndAlso buttonWidget->data <> 0 Then _
        Cast(ButtonData Ptr, buttonWidget->data)->text = textValue
End Sub


Sub tiko_SetFindBarMode(ByVal mode As Integer)

    If mode < TIKO_FIND_MODE_FIND OrElse mode > TIKO_FIND_MODE_FILES Then _
        mode = TIKO_FIND_MODE_FIND
    tiko_FindMode = mode
    tiko_ShowFindBar = -1

    If tiko_FindBar <> 0 Then tiko_FindBar->visible = -1
    If tiko_FindBox <> 0 Then tiko_FindBox->visible = -1
    If tiko_FindLabel <> 0 Then tiko_FindLabel->visible = -1
    If tiko_FindNextButton <> 0 Then tiko_FindNextButton->visible = -1
    If tiko_FindPreviousButton <> 0 Then _
        tiko_FindPreviousButton->visible = IIf( _
            mode <= TIKO_FIND_MODE_REPLACE, -1, 0 _
        )
    If tiko_ReplaceBox <> 0 Then _
        tiko_ReplaceBox->visible = IIf( _
            mode = TIKO_FIND_MODE_REPLACE, -1, 0 _
        )
    If tiko_ReplaceButton <> 0 Then _
        tiko_ReplaceButton->visible = IIf( _
            mode = TIKO_FIND_MODE_REPLACE, -1, 0 _
        )
    If tiko_ReplaceAllButton <> 0 Then _
        tiko_ReplaceAllButton->visible = IIf( _
            mode = TIKO_FIND_MODE_REPLACE, -1, 0 _
        )
    If tiko_FindCloseButton <> 0 Then tiko_FindCloseButton->visible = -1

    If tiko_FindLabel <> 0 AndAlso tiko_FindLabel->data <> 0 Then
        Dim As String labelText = "Find"
        Select Case mode
        Case TIKO_FIND_MODE_GOTO: labelText = "Line"
        Case TIKO_FIND_MODE_FILES: labelText = "Find in files"
        End Select
        Cast(LabelData Ptr, tiko_FindLabel->data)->text = labelText
    End If

    Select Case mode
    Case TIKO_FIND_MODE_FIND, TIKO_FIND_MODE_REPLACE
        tiko_SetButtonText(tiko_FindNextButton, "Find Next")
    Case TIKO_FIND_MODE_GOTO
        tiko_SetButtonText(tiko_FindNextButton, "Go To Line")
    Case TIKO_FIND_MODE_FILES
        tiko_SetButtonText(tiko_FindNextButton, "Find Files")
    End Select

    tiko_ResizeWidgets
    gui_SetFocus(tiko_FindBox)

End Sub


Sub tiko_HideFindBar()

    tiko_ShowFindBar = 0
    If tiko_FindBar <> 0 Then tiko_FindBar->visible = 0
    If tiko_FindBox <> 0 Then tiko_FindBox->visible = 0
    If tiko_FindLabel <> 0 Then tiko_FindLabel->visible = 0
    If tiko_FindNextButton <> 0 Then tiko_FindNextButton->visible = 0
    If tiko_FindPreviousButton <> 0 Then tiko_FindPreviousButton->visible = 0
    If tiko_ReplaceBox <> 0 Then tiko_ReplaceBox->visible = 0
    If tiko_ReplaceButton <> 0 Then tiko_ReplaceButton->visible = 0
    If tiko_ReplaceAllButton <> 0 Then tiko_ReplaceAllButton->visible = 0
    If tiko_FindCloseButton <> 0 Then tiko_FindCloseButton->visible = 0
    tiko_ResizeWidgets
    gui_SetFocus(tiko_Editor)

End Sub


Sub tiko_FindBarRender(ByVal w As Widget Ptr)
    backend_Rect(w->ax, w->ay, w->w, w->h, tiko_ColorToolbar, -1)
    backend_Line(w->ax, w->ay + w->h - 1, _
        w->ax + w->w - 1, w->ay + w->h - 1, tiko_ColorLine)
End Sub


Private Function tiko_DocumentCategory(ByVal documentIndex As Integer) As Integer

    If documentIndex < 0 OrElse documentIndex >= tiko_DocumentCount Then Return 0
    If tiko_ProjectActive = 0 Then Return 0

    Select Case tiko_Documents(documentIndex).file_type
    Case 1: Return 0
    Case 4: Return 1
    Case 5: Return 2
    Case 2: Return 3
    Case Else: Return 4
    End Select

End Function


Private Function tiko_CategoryHasDocuments(ByVal categoryIndex As Integer) As Integer

    If tiko_ProjectActive <> 0 Then
        Return IIf(categoryIndex >= 0 AndAlso categoryIndex <= 4, -1, 0)
    End If
    If categoryIndex <> 0 Then Return 0
    For documentIndex As Integer = 0 To tiko_DocumentCount - 1
        If tiko_DocumentCategory(documentIndex) = categoryIndex Then Return -1
    Next documentIndex

    Return 0

End Function


Private Function tiko_ExplorerCategoryAt(ByVal localY As Integer) As Integer

    Dim As Integer rowY = 88 - tiko_ExplorerScroll * 21
    Dim As Integer categoryCount = IIf(tiko_ProjectActive <> 0, 5, 1)

    tiko_ExplorerCategoryAt = -1
    If tiko_SidePanelPage <> 0 Then Return -1

    For categoryIndex As Integer = 0 To categoryCount - 1
        If tiko_CategoryHasDocuments(categoryIndex) = 0 Then Continue For
        If localY >= rowY AndAlso localY < rowY + 21 Then _
            Return categoryIndex
        rowY += 21

        If tiko_CategoryExpanded(categoryIndex) = 0 Then Continue For
        For documentIndex As Integer = 0 To tiko_DocumentCount - 1
            If tiko_DocumentCategory(documentIndex) <> categoryIndex Then Continue For
            rowY += 21
        Next documentIndex
    Next categoryIndex

    Return -1

End Function


Function tiko_ExplorerDocumentAt(ByVal localY As Integer) As Integer

    Dim As Integer rowY = 88 - tiko_ExplorerScroll * 21
    Dim As Integer categoryCount = IIf(tiko_ProjectActive <> 0, 5, 1)

    If tiko_SidePanelPage <> 0 Then Return -1

    For categoryIndex As Integer = 0 To categoryCount - 1
        If tiko_CategoryHasDocuments(categoryIndex) = 0 Then Continue For
        If localY >= rowY AndAlso localY < rowY + 20 Then Return -1
        rowY += 21

        If tiko_CategoryExpanded(categoryIndex) = 0 Then Continue For
        For documentIndex As Integer = 0 To tiko_DocumentCount - 1
            If tiko_DocumentCategory(documentIndex) <> categoryIndex Then Continue For
            If localY >= rowY AndAlso localY < rowY + 21 Then _
                Return documentIndex
            rowY += 21
        Next documentIndex
    Next categoryIndex

    Return -1

End Function


Private Sub tiko_DrawToolbarIcon( _
    ByVal iconIndex As Integer, ByVal iconX As Integer, ByVal iconY As Integer, _
    ByVal hot As Integer, ByVal active As Integer _
)

    Dim As ULong iconColor = tiko_ColorMuted
    Dim As Integer leftPosition = iconX + 5
    Dim As Integer topPosition = iconY + 5

    If active <> 0 Then iconColor = tiko_ColorAccent
    If hot <> 0 Then
        backend_Rect(iconX, iconY, 24, 24, tiko_ColorHover, -1)
        iconColor = tiko_ColorText
    Elseif active <> 0 Then
        backend_Rect(iconX + 1, iconY + 1, 22, 22, tiko_ColorActive, -1)
    End If

    Select Case iconIndex
    Case 0
        backend_Rect(leftPosition, topPosition, 5, 5, iconColor, 0)
        backend_Rect(leftPosition + 8, topPosition, 5, 5, iconColor, 0)
        backend_Rect(leftPosition, topPosition + 8, 5, 5, iconColor, 0)
        backend_Rect(leftPosition + 8, topPosition + 8, 5, 5, iconColor, 0)
    Case 1
        For lineIndex As Integer = 0 To 2
            backend_Rect(leftPosition, topPosition + lineIndex * 5 + 1, 2, 2, iconColor, -1)
            backend_Line(leftPosition + 5, topPosition + lineIndex * 5 + 2, _
                leftPosition + 14, topPosition + lineIndex * 5 + 2, iconColor)
        Next lineIndex
    Case 2
        backend_Line(leftPosition + 2, topPosition, leftPosition + 12, topPosition, iconColor)
        backend_Line(leftPosition + 2, topPosition, leftPosition + 2, topPosition + 14, iconColor)
        backend_Line(leftPosition + 12, topPosition, leftPosition + 12, topPosition + 14, iconColor)
        backend_Line(leftPosition + 2, topPosition + 14, leftPosition + 7, topPosition + 10, iconColor)
        backend_Line(leftPosition + 12, topPosition + 14, leftPosition + 7, topPosition + 10, iconColor)
    Case 3
        backend_Circle(leftPosition + 7, topPosition + 7, 5, iconColor, 0)
        backend_Circle(leftPosition + 7, topPosition + 7, 1, iconColor, -1)
        backend_Line(leftPosition + 7, topPosition, leftPosition + 7, topPosition + 2, iconColor)
        backend_Line(leftPosition + 7, topPosition + 12, leftPosition + 7, topPosition + 14, iconColor)
        backend_Line(leftPosition, topPosition + 7, leftPosition + 2, topPosition + 7, iconColor)
        backend_Line(leftPosition + 12, topPosition + 7, leftPosition + 14, topPosition + 7, iconColor)
    Case 4
        backend_Circle(leftPosition + 6, topPosition + 6, 5, iconColor, 0)
        backend_Line(leftPosition + 10, topPosition + 10, leftPosition + 15, topPosition + 15, iconColor)
    Case 5
        backend_Circle(leftPosition + 7, topPosition + 6, 4, iconColor, 0)
        backend_Line(leftPosition + 3, topPosition + 6, leftPosition, topPosition + 4, iconColor)
        backend_Line(leftPosition + 11, topPosition + 6, leftPosition + 14, topPosition + 4, iconColor)
        backend_Line(leftPosition + 3, topPosition + 11, leftPosition, topPosition + 14, iconColor)
        backend_Line(leftPosition + 11, topPosition + 11, leftPosition + 14, topPosition + 14, iconColor)
        backend_Line(leftPosition + 7, topPosition + 2, leftPosition + 7, topPosition - 1, iconColor)
    Case 6
        backend_Rect(leftPosition + 1, topPosition, 13, 14, iconColor, 0)
        backend_Rect(leftPosition + 4, topPosition + 1, 7, 4, iconColor, 0)
        backend_Rect(leftPosition + 4, topPosition + 8, 7, 5, iconColor, 0)
    Case 7
        backend_Line(leftPosition + 2, topPosition + 13, leftPosition + 12, topPosition + 3, iconColor)
        backend_Line(leftPosition + 1, topPosition + 10, leftPosition + 6, topPosition + 15, iconColor)
        backend_Line(leftPosition + 10, topPosition + 2, leftPosition + 14, topPosition + 6, iconColor)
        backend_Line(leftPosition + 9, topPosition + 3, leftPosition + 13, topPosition + 7, iconColor)
    Case 8
        backend_Line(leftPosition + 3, topPosition + 1, leftPosition + 13, topPosition + 7, iconColor)
        backend_Line(leftPosition + 13, topPosition + 7, leftPosition + 3, topPosition + 13, iconColor)
        backend_Line(leftPosition + 3, topPosition + 13, leftPosition + 3, topPosition + 1, iconColor)
    End Select

End Sub


Private Sub tiko_FindBarAction(ByVal w As Widget Ptr)

    Select Case tiko_FindMode
    Case TIKO_FIND_MODE_FIND
        tiko_FindNext
    Case TIKO_FIND_MODE_REPLACE
        tiko_FindNext
    Case TIKO_FIND_MODE_GOTO
        tiko_GotoLine
    Case TIKO_FIND_MODE_FILES
        tiko_FindInFiles
    End Select

End Sub


Private Sub tiko_ReplaceAction(ByVal w As Widget Ptr)
    tiko_ReplaceCurrent
End Sub


Private Sub tiko_FindPreviousAction(ByVal w As Widget Ptr)
    tiko_FindPrevious
End Sub


Private Sub tiko_ReplaceAllAction(ByVal w As Widget Ptr)
    tiko_ReplaceAll
End Sub


Private Sub tiko_HideFindAction(ByVal w As Widget Ptr)
    tiko_HideFindBar
End Sub


Sub tiko_PanelRender(ByVal w As Widget Ptr)

    Dim As Integer iconY = w->ay + 8
    Dim As Integer mainRowY = 88 - tiko_ExplorerScroll * 21

    backend_Rect(w->ax, w->ay, w->w, w->h, tiko_ColorPanel, -1)
    backend_Rect(w->ax, w->ay, w->w, TIKO_PANEL_TOOLBAR_HEIGHT, tiko_ColorToolbar, -1)
    backend_Line(w->ax, w->ay + TIKO_PANEL_TOOLBAR_HEIGHT - 1, _
        w->ax + w->w - 1, w->ay + TIKO_PANEL_TOOLBAR_HEIGHT - 1, tiko_ColorLine)
    backend_Line(w->ax + w->w - 1, w->ay, w->ax + w->w - 1, _
        w->ay + w->h - 1, tiko_ColorLine)

    For iconIndex As Integer = 0 To 3
        Dim As Integer iconX = w->ax + 10 + iconIndex * 24
        Dim As Integer hot = IIf(input_MouseX() >= iconX AndAlso _
            input_MouseX() < iconX + 24 AndAlso input_MouseY() >= iconY AndAlso _
            input_MouseY() < iconY + 24, -1, 0)
        tiko_DrawToolbarIcon(iconIndex, iconX, iconY, hot, _
            IIf(tiko_SidePanelPage = iconIndex AndAlso iconIndex < 3, -1, 0))
    Next iconIndex

    Dim As Integer rightStart = w->ax + w->w - 6 - 5 * 24
    For buttonIndex As Integer = 0 To 4
        Dim As Integer iconIndex = buttonIndex + 4
        Dim As Integer iconX = rightStart + buttonIndex * 24
        Dim As Integer hot = IIf(input_MouseX() >= iconX AndAlso _
            input_MouseX() < iconX + 24 AndAlso input_MouseY() >= iconY AndAlso _
            input_MouseY() < iconY + 24, -1, 0)
        tiko_DrawToolbarIcon(iconIndex, iconX, iconY, hot, 0)
    Next buttonIndex

    Select Case tiko_SidePanelPage
    Case 1
        tiko_RebuildFunctionList
        backend_Print(w->ax + 12, w->ay + 64, tiko_ColorText, "FUNCTIONS")
        If tiko_FunctionCount = 0 Then
            backend_Print(w->ax + 12, w->ay + 100, tiko_ColorMuted, _
                "No Sub or Function declarations")
        Elseif tiko_Editor <> 0 AndAlso tiko_Editor->data <> 0 Then
            Dim As TextBoxData Ptr textData = _
                Cast(TextBoxData Ptr, tiko_Editor->data)
            Dim As Integer rowY = 88
            Dim As Integer activeLine = tiko_LineNumberAt( _
                textData->text, textData->cursor_pos _
            )

            For functionIndex As Integer = tiko_FunctionScroll To _
                tiko_FunctionCount - 1
                If rowY >= w->h - 76 Then Exit For
                Dim As Integer itemY = w->ay + rowY
                If tiko_FunctionEntries(functionIndex).line_number = activeLine Then
                    backend_Rect(w->ax + 1, itemY, w->w - 3, 23, tiko_ColorActive, -1)
                Elseif input_MouseX() >= w->ax AndAlso _
                       input_MouseX() < w->ax + w->w AndAlso _
                       input_MouseY() >= itemY AndAlso input_MouseY() < itemY + 23 Then
                    backend_Rect(w->ax + 1, itemY, w->w - 3, 23, tiko_ColorHover, -1)
                End If
                backend_Print(w->ax + 10, itemY + 6, tiko_ColorMuted, _
                    LTrim(Str(tiko_FunctionEntries(functionIndex).line_number)))
                Dim As String functionName = tiko_FunctionEntries(functionIndex).name
                Dim As Integer maximumWidth = w->w - 56
                While Len(functionName) > 0 AndAlso _
                      backend_GetTextWidth(functionName) > maximumWidth
                    functionName = Left(functionName, Len(functionName) - 1)
                Wend
                backend_Print(w->ax + 43, itemY + 6, tiko_ColorText, functionName)
                rowY += 23
            Next functionIndex
        End If
    Case 2
        backend_Print(w->ax + 12, w->ay + 64, tiko_ColorText, "BOOKMARKS")
        If tiko_ActiveDocument < 0 OrElse _
           tiko_ActiveDocument >= tiko_DocumentCount OrElse _
           tiko_Documents(tiko_ActiveDocument).bookmark_count = 0 Then
            backend_Print(w->ax + 12, w->ay + 100, tiko_ColorMuted, _
                "No bookmarks in this document")
        Elseif tiko_Editor <> 0 AndAlso tiko_Editor->data <> 0 Then
            Dim As TextBoxData Ptr textData = _
                Cast(TextBoxData Ptr, tiko_Editor->data)
            Dim As Integer rowY = 88

            For bookmarkIndex As Integer = 0 To _
                tiko_Documents(tiko_ActiveDocument).bookmark_count - 1
                If rowY >= w->h - 76 Then Exit For
                Dim As Integer lineStart = _
                    tiko_Documents(tiko_ActiveDocument).bookmark_offsets(bookmarkIndex)
                Dim As Integer lineEnd
                Dim As Integer lineAfter
                Dim As String lineText
                tiko_GetLineRange textData->text, lineStart, lineEnd, lineAfter
                lineText = Trim(Mid( _
                    textData->text, lineStart + 1, lineEnd - lineStart _
                ))
                If lineText = "" Then lineText = "(blank line)"
                If Len(lineText) > 24 Then lineText = Left(lineText, 24)

                Dim As Integer itemY = w->ay + rowY
                Dim As Integer isHot = IIf( _
                    input_MouseX() >= w->ax AndAlso _
                    input_MouseX() < w->ax + w->w AndAlso _
                    input_MouseY() >= itemY AndAlso _
                    input_MouseY() < itemY + 23, -1, 0 _
                )
                If isHot <> 0 Then _
                    backend_Rect(w->ax + 1, itemY, w->w - 3, 23, tiko_ColorHover, -1)
                backend_Print(w->ax + 12, itemY + 6, tiko_ColorMuted, _
                    LTrim(Str(tiko_LineNumberAt(textData->text, lineStart))) & ":")
                backend_Print(w->ax + 44, itemY + 6, tiko_ColorText, lineText)
                rowY += 25
            Next bookmarkIndex
        End If
    Case Else
        backend_Print(w->ax + 12, w->ay + 64, tiko_ColorText, "EXPLORER")
        backend_Print(w->ax + w->w - 25, w->ay + 64, tiko_ColorMuted, "...")

        Dim As Integer categoryCount = IIf(tiko_ProjectActive <> 0, 5, 1)
        For categoryIndex As Integer = 0 To categoryCount - 1
            If tiko_CategoryHasDocuments(categoryIndex) = 0 Then Continue For
            Dim As String categoryName = "Files"
            Select Case categoryIndex
            Case 0: If tiko_ProjectActive <> 0 Then categoryName = "Main"
            Case 1: categoryName = "Resource"
            Case 2: categoryName = "Header"
            Case 3: categoryName = "Module"
            Case 4: categoryName = "Normal"
            End Select

            If mainRowY >= 82 AndAlso mainRowY < w->h - 76 Then
                backend_Print(w->ax + 12, w->ay + mainRowY + 6, tiko_ColorMuted, _
                    IIf(tiko_CategoryExpanded(categoryIndex) <> 0, "v", ">"))
                backend_Print(w->ax + 30, w->ay + mainRowY + 6, tiko_ColorText, categoryName)
            End If
            mainRowY += 21

            If tiko_CategoryExpanded(categoryIndex) = 0 Then Continue For
            For documentIndex As Integer = 0 To tiko_DocumentCount - 1
                If tiko_DocumentCategory(documentIndex) <> categoryIndex Then Continue For
                If mainRowY < 82 Then
                    mainRowY += 21
                    Continue For
                End If
                If mainRowY >= w->h - 76 Then Exit For

                Dim As Integer itemY = w->ay + mainRowY
                If documentIndex = tiko_ActiveDocument Then _
                    backend_Rect(w->ax + 1, itemY, w->w - 3, 21, tiko_ColorActive, -1)
                backend_Circle(w->ax + 43, itemY + 10, 2, tiko_ColorMuted, -1)
                backend_Print(w->ax + 54, itemY + 6, _
                    IIf(documentIndex = tiko_ActiveDocument, tiko_ColorText, tiko_ColorMuted), _
                    tiko_Documents(documentIndex).title & _
                    IIf(tiko_Documents(documentIndex).dirty <> 0, " *", "") & _
                    IIf(tiko_Documents(documentIndex).is_missing <> 0, " (missing)", ""))
                mainRowY += 21
            Next documentIndex
        Next categoryIndex
    End Select

    Dim As Integer functionY = w->ay + w->h - 58
    Dim As Integer bookmarkY = w->ay + w->h - 30
    backend_Line(w->ax + 1, functionY - 3, w->ax + w->w - 2, _
        functionY - 3, tiko_ColorLine)
    backend_Line(w->ax + 1, bookmarkY - 3, w->ax + w->w - 2, _
        bookmarkY - 3, tiko_ColorLine)
    backend_Print(w->ax + 12, functionY + 5, tiko_ColorText, "FUNCTION LIST")
    backend_Print(w->ax + w->w - 24, functionY + 5, tiko_ColorMuted, ">")
    backend_Print(w->ax + 12, bookmarkY + 5, tiko_ColorText, "BOOKMARKS")
    backend_Print(w->ax + w->w - 24, bookmarkY + 5, tiko_ColorMuted, ">")

End Sub


Sub tiko_PanelUpdate(ByVal w As Widget Ptr)

    Dim As TikoVisualData Ptr visualData = Cast(TikoVisualData Ptr, w->data)
    Dim As Integer mouseButtons = input_MouseButtons()
    Dim As Integer mouseX = input_MouseX()
    Dim As Integer mouseY = input_MouseY()

    If input_MouseWheel() <> 0 AndAlso _
       mouseX >= w->ax AndAlso mouseX < w->ax + w->w AndAlso _
       mouseY >= w->ay + 80 AndAlso mouseY < w->ay + w->h - 60 Then
        If tiko_SidePanelPage = 1 Then
            tiko_RebuildFunctionList
            tiko_FunctionScroll -= input_MouseWheel() * 3
            If tiko_FunctionScroll < 0 Then tiko_FunctionScroll = 0
            If tiko_FunctionScroll > tiko_FunctionCount Then _
                tiko_FunctionScroll = tiko_FunctionCount
        Elseif tiko_SidePanelPage = 2 Then
            tiko_ExplorerScroll -= input_MouseWheel() * 3
            If tiko_ExplorerScroll < 0 Then tiko_ExplorerScroll = 0
            If tiko_ExplorerScroll > TIKO_MAX_BOOKMARKS Then _
                tiko_ExplorerScroll = TIKO_MAX_BOOKMARKS
        Else
            tiko_ExplorerScroll -= input_MouseWheel() * 3
            If tiko_ExplorerScroll < 0 Then tiko_ExplorerScroll = 0
            If tiko_ExplorerScroll > TIKO_MAX_DOCUMENTS Then _
                tiko_ExplorerScroll = TIKO_MAX_DOCUMENTS
        End If
        Return
    End If

    If mouseButtons And 1 Then
        If visualData->pointer_down = 0 Then
            Dim As Integer localY = mouseY - w->ay
            visualData->pointer_down = -1

            If localY >= 8 AndAlso localY < 32 Then
                For iconIndex As Integer = 0 To 3
                    Dim As Integer iconLeft = w->ax + 10 + iconIndex * 24
                    If mouseX >= iconLeft AndAlso mouseX < iconLeft + 24 Then
                        If iconIndex < 3 Then
                            tiko_SidePanelPage = iconIndex
                        Else
                            tiko_SetStatus("Environment options are not ported yet")
                        End If
                        Return
                    End If
                Next iconIndex

                Dim As Integer rightStart = w->ax + w->w - 6 - 5 * 24
                For buttonIndex As Integer = 0 To 4
                    Dim As Integer iconLeft = rightStart + buttonIndex * 24
                    If mouseX < iconLeft OrElse mouseX >= iconLeft + 24 Then _
                        Continue For
                    Select Case buttonIndex
                    Case 0: tiko_ShowFind
                    Case 1: tiko_SaveAllDocuments
                    Case 2: tiko_SetStatus("Debugger support is not ported yet")
                    Case 3: tiko_RequestBuild(0)
                    Case 4: tiko_RequestBuild(-1)
                    End Select
                    Return
                Next buttonIndex
            End If

            If localY >= w->h - 58 AndAlso localY < w->h - 30 Then
                tiko_SidePanelPage = 1
                tiko_FunctionScroll = 0
                Return
            Elseif localY >= w->h - 30 Then
                tiko_SidePanelPage = 2
                Return
            End If

            If tiko_SidePanelPage = 2 Then
                Dim As Integer bookmarkIndex = _
                    tiko_BookmarkIndexAtPanelRow(localY)
                If bookmarkIndex >= 0 Then
                    tiko_GotoBookmarkByIndex(bookmarkIndex)
                    Return
                End If
            Elseif tiko_SidePanelPage = 1 Then
                tiko_RebuildFunctionList
                If localY >= 88 AndAlso localY < w->h - 76 Then
                    Dim As Integer functionIndex = tiko_FunctionScroll + _
                        (localY - 88) \ 23
                    If functionIndex >= 0 AndAlso _
                       functionIndex < tiko_FunctionCount Then
                        tiko_GotoFunctionIndex(functionIndex)
                        Return
                    End If
                End If
            End If

            Dim As Integer categoryIndex = tiko_ExplorerCategoryAt(localY)
            If categoryIndex >= 0 Then
                tiko_CategoryExpanded(categoryIndex) = _
                    IIf(tiko_CategoryExpanded(categoryIndex) <> 0, 0, -1)
                Return
            End If

            Dim As Integer documentIndex = tiko_ExplorerDocumentAt(localY)
            If documentIndex >= 0 AndAlso tiko_FileList <> 0 Then
                Cast(ListBoxData Ptr, tiko_FileList->data)->selected_index = documentIndex
                tiko_LastListSelection = documentIndex
            End If
        End If
    Else
        visualData->pointer_down = 0
    End If

End Sub


Function tiko_TabVisibleDocumentAt(ByVal tabIndex As Integer) As Integer

    Dim As Integer visibleIndex

    If tabIndex < 0 Then Return -1
    For documentIndex As Integer = 0 To tiko_DocumentCount - 1
        If tiko_Documents(documentIndex).tab_visible = 0 OrElse _
           tiko_Documents(documentIndex).is_missing <> 0 Then Continue For
        If visibleIndex = tabIndex Then Return documentIndex
        visibleIndex += 1
    Next documentIndex

    Return -1

End Function


Private Function tiko_TabLeft(ByVal tabIndex As Integer) As Integer

    Dim As Integer tabLeft

    If tiko_TabStrip = 0 Then Return TIKO_SIDEBAR_WIDTH
    tabLeft = tiko_TabStrip->ax + 4

    For index As Integer = 0 To tabIndex - 1
        Dim As Integer documentIndex = tiko_TabVisibleDocumentAt(index)
        If documentIndex < 0 Then Exit For
        Dim As Integer tabWidth = backend_GetTextWidth(tiko_Documents(documentIndex).title) + 48
        If tabWidth < 112 Then tabWidth = 112
        If tabWidth > 220 Then tabWidth = 220
        tabLeft += tabWidth
    Next index

    Return tabLeft

End Function


Private Function tiko_TabWidth(ByVal tabIndex As Integer) As Integer

    Dim As Integer documentIndex = tiko_TabVisibleDocumentAt(tabIndex)
    If documentIndex < 0 OrElse documentIndex >= tiko_DocumentCount Then Return 0
    Dim As Integer tabWidth = backend_GetTextWidth(tiko_Documents(documentIndex).title) + 48
    If tabWidth < 112 Then tabWidth = 112
    If tabWidth > 220 Then tabWidth = 220
    Return tabWidth

End Function


Sub tiko_TabStripRender(ByVal w As Widget Ptr)

    backend_Rect(w->ax, w->ay, w->w, w->h, tiko_ColorTab, -1)

    For tabIndex As Integer = 0 To tiko_DocumentCount - 1
        Dim As Integer documentIndex = tiko_TabVisibleDocumentAt(tabIndex)
        If documentIndex < 0 Then Exit For
        Dim As Integer tabLeft = tiko_TabLeft(tabIndex)
        Dim As Integer tabWidth = tiko_TabWidth(tabIndex)
        If tabLeft + tabWidth > w->ax + w->w - 72 Then Exit For

        If documentIndex = tiko_ActiveDocument Then
            backend_Rect(tabLeft, w->ay, tabWidth, w->h - 1, tiko_ColorEditor, -1)
            backend_Line(tabLeft, w->ay, tabLeft + tabWidth - 1, w->ay, tiko_ColorAccent)
        End If
        backend_Line(tabLeft, w->ay + 2, tabLeft, w->ay + w->h - 2, tiko_ColorLine)
        backend_Line(tabLeft + tabWidth - 1, w->ay + 2, tabLeft + tabWidth - 1, _
            w->ay + w->h - 2, tiko_ColorLine)
        backend_Print(tabLeft + 12, w->ay + 11, _
            IIf(documentIndex = tiko_ActiveDocument, tiko_ColorText, tiko_ColorMuted), _
            tiko_Documents(documentIndex).title & _
            IIf(tiko_Documents(documentIndex).dirty <> 0, " *", ""))
        backend_Print(tabLeft + tabWidth - 18, w->ay + 11, tiko_ColorMuted, "x")
    Next tabIndex

    backend_Line(w->ax, w->ay + w->h - 1, w->ax + w->w - 1, _
        w->ay + w->h - 1, tiko_ColorLine)
    backend_Print(w->ax + w->w - 66, w->ay + 11, tiko_ColorMuted, "<  >  []  ...")

End Sub


Sub tiko_TabStripUpdate(ByVal w As Widget Ptr)

    Dim As TikoVisualData Ptr visualData = Cast(TikoVisualData Ptr, w->data)
    Dim As Integer mouseButtons = input_MouseButtons()

    If mouseButtons And 1 Then
        If visualData->pointer_down = 0 Then
            Dim As Integer mouseX = input_MouseX()
            visualData->pointer_down = -1

            For tabIndex As Integer = 0 To tiko_DocumentCount - 1
                Dim As Integer documentIndex = tiko_TabVisibleDocumentAt(tabIndex)
                If documentIndex < 0 Then Exit For
                Dim As Integer tabLeft = tiko_TabLeft(tabIndex)
                Dim As Integer tabWidth = tiko_TabWidth(tabIndex)
                If tabLeft + tabWidth > w->ax + w->w - 72 Then Exit For
                If mouseX >= tabLeft AndAlso mouseX < tabLeft + tabWidth Then
                    tiko_ActivateDocument(documentIndex)
                    If mouseX >= tabLeft + tabWidth - 25 Then _
                        tiko_RequestCloseDocument
                    Return
                End If
            Next tabIndex
        End If
    Else
        visualData->pointer_down = 0
    End If

End Sub


Sub tiko_StatusBarRender(ByVal w As Widget Ptr)

    Dim As Integer lineNumber = 1
    Dim As Integer columnNumber = 1
    Dim As Integer caretPosition
    Dim As Integer rightX
    Dim As Integer rightStart
    Dim As Integer remainingWidth
    Dim As String statusSummary = tiko_StatusText
    Dim As String statusFields(0 To 4)

    backend_Rect(w->ax, w->ay, w->w, w->h, tiko_ColorTab, -1)
    backend_Line(w->ax, w->ay, w->ax + w->w - 1, w->ay, tiko_ColorLine)

    If tiko_Editor <> 0 AndAlso tiko_Editor->data <> 0 Then
        Dim As TextBoxData Ptr textData = Cast(TextBoxData Ptr, tiko_Editor->data)
        caretPosition = textData->cursor_pos
        If caretPosition < 0 Then caretPosition = 0
        If caretPosition > Len(textData->text) Then caretPosition = Len(textData->text)

        For charPosition As Integer = 0 To caretPosition - 1
            If textData->text[charPosition] = 10 Then
                lineNumber += 1
                columnNumber = 1
            Else
                columnNumber += 1
            End If
        Next charPosition
    End If

    backend_Print(w->ax + 11, w->ay + 7, tiko_ColorText, _
        "Ln " & Str(lineNumber) & ", Col " & Str(columnNumber))
    backend_Line(w->ax + 146, w->ay + 4, w->ax + 146, w->ay + w->h - 4, tiko_ColorLine)

#If Defined(__FB_WIN32__)
    statusFields(0) = "Windows"
#Elseif Defined(__FB_LINUX__)
    statusFields(0) = "Linux"
#Else
    statusFields(0) = "FreeBASIC"
#EndIf
    statusFields(1) = "Main"
    statusFields(2) = "Spaces: 4"
    statusFields(3) = "UTF-8"
    statusFields(4) = "LF"

    If tiko_ActiveDocument >= 0 AndAlso tiko_ActiveDocument < tiko_DocumentCount Then
        Select Case tiko_Documents(tiko_ActiveDocument).line_ending
        Case 1: statusFields(4) = "CRLF"
        Case 2: statusFields(4) = "CR"
        End Select
        If LCase(Right(tiko_Documents(tiko_ActiveDocument).path, 3)) = ".bi" Then _
            statusFields(1) = "Header"
        If LCase(Right(tiko_Documents(tiko_ActiveDocument).path, 3)) = ".rc" Then _
            statusFields(1) = "Resource"
    End If

    rightX = w->ax + w->w - 8
    For fieldIndex As Integer = UBound(statusFields) To LBound(statusFields) Step -1
        Dim As Integer fieldWidth = backend_GetTextWidth(statusFields(fieldIndex)) + 20
        rightX -= fieldWidth
        backend_Line(rightX - 7, w->ay + 4, rightX - 7, w->ay + w->h - 4, tiko_ColorLine)
        backend_Print(rightX, w->ay + 7, tiko_ColorMuted, statusFields(fieldIndex))
    Next fieldIndex

    rightStart = rightX - 12
    remainingWidth = rightStart - (w->ax + 164)
    If remainingWidth < 0 Then remainingWidth = 0
    If backend_GetTextWidth(statusSummary) > remainingWidth Then
        Dim As Integer allowedCharacters = remainingWidth \ 8
        If allowedCharacters < 4 Then
            statusSummary = ""
        Else
            statusSummary = Left(statusSummary, allowedCharacters - 3) & "..."
        End If
    End If
    backend_Print(w->ax + 164, w->ay + 7, tiko_ColorMuted, statusSummary)

End Sub


Function tiko_OutputTabLeft(ByVal tabIndex As Integer) As Integer

    Dim As Integer leftPosition

    If tiko_OutputHeading = 0 Then Return 0
    leftPosition = tiko_OutputHeading->ax + 10
    For itemIndex As Integer = 0 To tabIndex - 1
        If itemIndex >= 0 AndAlso itemIndex < TIKO_OUTPUT_TAB_COUNT Then _
            leftPosition += backend_GetTextWidth(tiko_OutputTabNames(itemIndex)) + 24
    Next itemIndex
    Return leftPosition

End Function


Function tiko_OutputTabWidth(ByVal tabIndex As Integer) As Integer

    If tabIndex < 0 OrElse tabIndex >= TIKO_OUTPUT_TAB_COUNT Then Return 0
    Return backend_GetTextWidth(tiko_OutputTabNames(tabIndex)) + 24

End Function


Sub tiko_OutputTabsRender(ByVal w As Widget Ptr)

    Dim As Integer mouseX = input_MouseX()
    Dim As Integer mouseY = input_MouseY()
    Dim As Integer closeLeft = w->ax + w->w - 32

    backend_Rect(w->ax, w->ay, w->w, w->h, tiko_ColorTab, -1)
    For tabIndex As Integer = 0 To TIKO_OUTPUT_TAB_COUNT - 1
        Dim As Integer tabLeft = tiko_OutputTabLeft(tabIndex)
        Dim As Integer tabWidth = tiko_OutputTabWidth(tabIndex)
        Dim As Integer tabRight = tabLeft + tabWidth
        If tabRight > closeLeft - 4 Then Exit For

        If tabIndex = tiko_OutputPage Then
            backend_Rect(tabLeft, w->ay + 1, tabWidth, w->h - 1, tiko_ColorEditor, -1)
            backend_Line(tabLeft + 3, w->ay + w->h - 2, _
                tabRight - 4, w->ay + w->h - 2, tiko_ColorAccent)
        Elseif mouseY >= w->ay AndAlso mouseY < w->ay + w->h AndAlso _
               mouseX >= tabLeft AndAlso mouseX < tabRight Then
            backend_Rect(tabLeft, w->ay + 1, tabWidth, w->h - 1, tiko_ColorHover, -1)
        End If

        backend_Print(tabLeft + 12, w->ay + 13, _
            IIf(tabIndex = tiko_OutputPage, tiko_ColorText, tiko_ColorMuted), _
            tiko_OutputTabNames(tabIndex))
        backend_Line(tabRight - 1, w->ay + 7, tabRight - 1, _
            w->ay + w->h - 7, tiko_ColorLine)
    Next tabIndex

    If mouseX >= closeLeft AndAlso mouseX < closeLeft + 22 AndAlso _
       mouseY >= w->ay + 6 AndAlso mouseY < w->ay + w->h - 6 Then
        backend_Rect(closeLeft - 2, w->ay + 5, 22, w->h - 10, tiko_ColorHover, -1)
        backend_Print(closeLeft + 5, w->ay + 13, tiko_ColorText, "x")
    Else
        backend_Print(closeLeft + 5, w->ay + 13, tiko_ColorMuted, "x")
    End If

    backend_Line(w->ax, w->ay + w->h - 1, w->ax + w->w - 1, _
        w->ay + w->h - 1, tiko_ColorLine)

End Sub


Sub tiko_OutputTabsUpdate(ByVal w As Widget Ptr)

    Dim As TikoVisualData Ptr visualData = Cast(TikoVisualData Ptr, w->data)
    Dim As Integer mouseButtons = input_MouseButtons()

    If (mouseButtons And 1) = 0 Then
        visualData->pointer_down = 0
        Exit Sub
    End If
    If visualData->pointer_down <> 0 Then Exit Sub
    visualData->pointer_down = -1

    Dim As Integer mouseX = input_MouseX()
    Dim As Integer mouseY = input_MouseY()
    If mouseY < w->ay OrElse mouseY >= w->ay + w->h Then Exit Sub

    Dim As Integer closeLeft = w->ax + w->w - 32
    If mouseX >= closeLeft AndAlso mouseX < closeLeft + 22 Then
        tiko_ShowOutput = 0
        tiko_ResizeWidgets
        gui_SetFocus(tiko_Editor)
        Return
    End If

    For tabIndex As Integer = 0 To TIKO_OUTPUT_TAB_COUNT - 1
        Dim As Integer tabLeft = tiko_OutputTabLeft(tabIndex)
        Dim As Integer tabRight = tabLeft + tiko_OutputTabWidth(tabIndex)
        If tabRight > closeLeft - 4 Then Exit For
        If mouseX >= tabLeft AndAlso mouseX < tabRight Then
            tiko_ShowOutput = -1
            tiko_ShowOutputPage(tabIndex)
            tiko_ResizeWidgets
            If tabIndex = 4 Then
                gui_SetFocus(tiko_Output)
            Else
                gui_SetFocus(tiko_Editor)
            End If
            Return
        End If
    Next tabIndex

End Sub

' end of tiko_native_ui.bi
