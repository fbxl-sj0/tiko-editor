/'
    Project: Tiko Editor
    -------------------

    File: tiko.bas

    Purpose:

        Provide the native FreeBASIC application entry point for Tiko.

    Responsibilities:

        - compose the editor interface from omaGUI widgets
        - manage a bounded set of open source documents
        - load and save source files through the FreeBASIC runtime
        - build and run source through the configured FreeBASIC compiler
        - provide FreeBASIC syntax colors and editor keyboard commands

    This file intentionally does NOT contain:

        - omaGUI widget or platform backend implementation
        - Windows API, Afx, Scintilla, or COM dependencies
        - compiler parsing or debugger implementation

    Tiko Editor is Copyright (C) 2016-2026 Paul Squires,
    PlanetSquires Software. It is distributed under the GNU GPLv3 or later.
'/

#lang "fb"

#If Defined(__FB_WIN32__)
#cmdline "-s gui"
#EndIf

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

' -------------------------------------------------------------------------
' Application limits and command state
' -------------------------------------------------------------------------

Const TIKO_INITIAL_WIDTH As Integer = 1280
Const TIKO_INITIAL_HEIGHT As Integer = 800
Const TIKO_MENU_HEIGHT As Integer = 28
Const TIKO_PANEL_TOOLBAR_HEIGHT As Integer = 44
Const TIKO_TAB_HEIGHT As Integer = 32
Const TIKO_STATUS_HEIGHT As Integer = 24
Const TIKO_OUTPUT_HEIGHT As Integer = 128
Const TIKO_OUTPUT_HEADER_HEIGHT As Integer = 36
Const TIKO_FIND_BAR_HEIGHT As Integer = 38
Const TIKO_SIDEBAR_WIDTH As Integer = 250
Const TIKO_MENU_COUNT As Integer = 8
Const TIKO_MAX_DOCUMENTS As Integer = 256
Const TIKO_MAX_SOURCE_BYTES As Integer = 2097152
Const TIKO_MAX_SOURCE_FILE_BYTES As Integer = 4194304
Const TIKO_MAX_OUTPUT_BYTES As Integer = 131072
Const TIKO_MAX_PROJECT_BYTES As Integer = 4194304
Const TIKO_TEMP_PATH_ATTEMPTS As Integer = 32
Const TIKO_MAX_BOOKMARKS As Integer = 64
Const TIKO_MAX_FUNCTIONS As Integer = 512

Const TIKO_DIALOG_NONE As Integer = 0
Const TIKO_DIALOG_OPEN As Integer = 1
Const TIKO_DIALOG_SAVE As Integer = 2
Const TIKO_DIALOG_CONFIRM As Integer = 3
Const TIKO_DIALOG_PROJECT_OPEN As Integer = 4
Const TIKO_DIALOG_PROJECT_SAVE As Integer = 5

Const TIKO_AFTER_SAVE_NONE As Integer = 0
Const TIKO_AFTER_SAVE_BUILD As Integer = 1
Const TIKO_AFTER_SAVE_RUN As Integer = 2
Const TIKO_AFTER_SAVE_SAVE_ALL As Integer = 3

Const TIKO_CONFIRM_NONE As Integer = 0
Const TIKO_CONFIRM_CLOSE_DOCUMENT As Integer = 1
Const TIKO_CONFIRM_EXIT As Integer = 2
Const TIKO_CONFIRM_CLOSE_ALL As Integer = 3

Const TIKO_ACTION_NONE As Integer = 0
Const TIKO_ACTION_NEW As Integer = 1
Const TIKO_ACTION_OPEN As Integer = 2
Const TIKO_ACTION_SAVE As Integer = 3
Const TIKO_ACTION_SAVE_AS As Integer = 4
Const TIKO_ACTION_CLOSE As Integer = 5
Const TIKO_ACTION_EXIT As Integer = 6
Const TIKO_ACTION_BUILD As Integer = 7
Const TIKO_ACTION_BUILD_RUN As Integer = 8
Const TIKO_ACTION_FIND As Integer = 9
Const TIKO_ACTION_FIND_NEXT As Integer = 10
Const TIKO_ACTION_SELECT_ALL As Integer = 11
Const TIKO_ACTION_UNDO As Integer = 12
Const TIKO_ACTION_REDO As Integer = 13
Const TIKO_ACTION_TOGGLE_PANEL As Integer = 14
Const TIKO_ACTION_TOGGLE_OUTPUT As Integer = 15
Const TIKO_ACTION_EXPLORER As Integer = 16
Const TIKO_ACTION_FUNCTIONS As Integer = 17
Const TIKO_ACTION_BOOKMARKS As Integer = 18
Const TIKO_ACTION_ABOUT As Integer = 19
Const TIKO_ACTION_CUT As Integer = 20
Const TIKO_ACTION_COPY As Integer = 21
Const TIKO_ACTION_PASTE As Integer = 22
Const TIKO_ACTION_DELETE_LINE As Integer = 23
Const TIKO_ACTION_DUPLICATE_LINE As Integer = 24
Const TIKO_ACTION_MOVE_LINE_UP As Integer = 25
Const TIKO_ACTION_MOVE_LINE_DOWN As Integer = 26
Const TIKO_ACTION_COMMENT_BLOCK As Integer = 27
Const TIKO_ACTION_UNCOMMENT_BLOCK As Integer = 28
Const TIKO_ACTION_SELECT_LINE As Integer = 29
Const TIKO_ACTION_BOOKMARK_TOGGLE As Integer = 30
Const TIKO_ACTION_BOOKMARK_NEXT As Integer = 31
Const TIKO_ACTION_BOOKMARK_PREVIOUS As Integer = 32
Const TIKO_ACTION_BOOKMARK_CLEAR As Integer = 33
Const TIKO_ACTION_SAVE_ALL As Integer = 34
Const TIKO_ACTION_CLOSE_ALL As Integer = 35
Const TIKO_ACTION_PROJECT_NEW As Integer = 36
Const TIKO_ACTION_PROJECT_OPEN As Integer = 37
Const TIKO_ACTION_PROJECT_CLOSE As Integer = 38
Const TIKO_ACTION_PROJECT_SAVE As Integer = 39
Const TIKO_ACTION_PROJECT_SAVE_AS As Integer = 40
Const TIKO_ACTION_FIND_IN_FILES As Integer = 41
Const TIKO_ACTION_REPLACE As Integer = 42
Const TIKO_ACTION_GOTO_LINE As Integer = 43
Const TIKO_ACTION_NEXT_FUNCTION As Integer = 44
Const TIKO_ACTION_PREVIOUS_FUNCTION As Integer = 45
Const TIKO_ACTION_GOTO_DEFINITION As Integer = 46
Const TIKO_ACTION_LAST_POSITION As Integer = 47
Const TIKO_ACTION_NEXT_DOCUMENT As Integer = 48
Const TIKO_ACTION_PREVIOUS_DOCUMENT As Integer = 49

Const TIKO_FIND_MODE_FIND As Integer = 0
Const TIKO_FIND_MODE_REPLACE As Integer = 1
Const TIKO_FIND_MODE_GOTO As Integer = 2
Const TIKO_FIND_MODE_FILES As Integer = 3

Type TikoDocument
    As String path
    As String title
    As String text
    As String saved_text
    As Integer cursor_pos
    As Integer vertical_scroll
    As Integer dirty
    As Integer utf8_bom
    As Integer line_ending
    As Integer file_type
    As Integer tab_visible
    As Integer is_missing
    As Integer bookmark_count
    As Integer bookmark_offsets(0 To TIKO_MAX_BOOKMARKS - 1)
End Type

Type TikoVisualData
    As Integer pointer_down
End Type

Type TikoFunctionEntry
    As Integer line_number
    As Integer position
    As String name
End Type

Dim Shared As TikoDocument tiko_Documents(0 To TIKO_MAX_DOCUMENTS - 1)
Dim Shared As Integer tiko_DocumentCount
Dim Shared As Integer tiko_ActiveDocument
Dim Shared As Widget Ptr tiko_Editor
Dim Shared As Widget Ptr tiko_FileList
Dim Shared As Widget Ptr tiko_FindBox
Dim Shared As Widget Ptr tiko_FindLabel
Dim Shared As Widget Ptr tiko_FindNextButton
Dim Shared As Widget Ptr tiko_FindBar
Dim Shared As Widget Ptr tiko_FindPreviousButton
Dim Shared As Widget Ptr tiko_ReplaceBox
Dim Shared As Widget Ptr tiko_ReplaceButton
Dim Shared As Widget Ptr tiko_ReplaceAllButton
Dim Shared As Widget Ptr tiko_FindCloseButton
Dim Shared As Widget Ptr tiko_Output
Dim Shared As Widget Ptr tiko_OutputHeading
Dim Shared As Widget Ptr tiko_Status
Dim Shared As Widget Ptr tiko_MenuBar
Dim Shared As Widget Ptr tiko_Panel
Dim Shared As Widget Ptr tiko_TabStrip
Dim Shared As Widget Ptr tiko_StatusBar
Dim Shared As Widget Ptr tiko_PopupMenu
Dim Shared As Widget Ptr tiko_ActiveDialog
Dim Shared As Integer tiko_ActiveDialogKind
Dim Shared As Integer tiko_AfterSaveAction
Dim Shared As Integer tiko_SaveAllPending
Dim Shared As Integer tiko_SaveAllOriginalActive
Dim Shared As Integer tiko_SaveAllNextDocument
Dim Shared As Integer tiko_ConfirmAction
Dim Shared As Integer tiko_PendingDocument
Dim Shared As Integer tiko_ExitRequested
Dim Shared As Integer tiko_ProjectActive
Dim Shared As Integer tiko_ProjectActiveTab
Dim Shared As Integer tiko_ProjectMissingCount
Dim Shared As Integer tiko_ExplorerScroll
Dim Shared As Integer tiko_FunctionScroll
Dim Shared As Integer tiko_FunctionCount
Dim Shared As Integer tiko_FunctionDocument = -1
Dim Shared As ULong tiko_FunctionChangeSerial
Dim Shared As TikoFunctionEntry tiko_FunctionEntries(0 To TIKO_MAX_FUNCTIONS - 1)
Dim Shared As Integer tiko_CategoryExpanded(0 To 4) = {-1, -1, 0, 0, -1}
Dim Shared As Integer tiko_TempNameCounter
Dim Shared As Integer tiko_KeyHeld(0 To 511)
Dim Shared As Integer tiko_LastListSelection
Dim Shared As Integer tiko_LastPositionDocument = -1
Dim Shared As Integer tiko_LastPositionCursor
Dim Shared As ULong tiko_LastCapturedChange
Dim Shared As Integer tiko_ShowOutput
Dim Shared As Integer tiko_OutputPage
Dim Shared As ULong tiko_OutputChangeSerial
Dim Shared As Integer tiko_ShowFindBar
Dim Shared As Integer tiko_FindMode
Dim Shared As Integer tiko_ShowSidePanel
Dim Shared As Integer tiko_SidePanelPage
Dim Shared As Integer tiko_ActiveMenuIndex
Dim Shared As Integer tiko_CurrentMenuActionCount
Dim Shared As Integer tiko_CurrentMenuActions(0 To 31)
Dim Shared As String tiko_LastWindowTitle
Dim Shared As String tiko_LastFindText
Dim Shared As String tiko_ProjectPath
Dim Shared As String tiko_ProjectName
Dim Shared As String tiko_ProjectBuildId
Dim Shared As String tiko_ProjectOther32
Dim Shared As String tiko_ProjectOther64
Dim Shared As String tiko_ProjectCommandLine
Dim Shared As String tiko_ProjectNotes
Dim Shared As String tiko_UserNotes
Dim Shared As String tiko_BuildOutput
Dim Shared As String tiko_CompilerLogOutput
Dim Shared As String tiko_SearchOutput
Dim Shared As String tiko_StatusText
Dim Shared As ZString * 16 tiko_MenuNames(0 To TIKO_MENU_COUNT - 1) = _
    {"File", "Edit", "Search", "View", "Project", "Compile", "Debug", "Help"}

Dim Shared As ULong tiko_ColorWindow = RGB(30, 34, 42)
Dim Shared As ULong tiko_ColorMenu = RGB(31, 35, 43)
Dim Shared As ULong tiko_ColorPanel = RGB(32, 36, 44)
Dim Shared As ULong tiko_ColorToolbar = RGB(36, 41, 49)
Dim Shared As ULong tiko_ColorEditor = RGB(33, 37, 45)
Dim Shared As ULong tiko_ColorTab = RGB(29, 33, 40)
Dim Shared As ULong tiko_ColorLine = RGB(54, 59, 68)
Dim Shared As ULong tiko_ColorHover = RGB(49, 56, 68)
Dim Shared As ULong tiko_ColorActive = RGB(41, 47, 57)
Dim Shared As ULong tiko_ColorText = RGB(197, 204, 216)
Dim Shared As ULong tiko_ColorMuted = RGB(139, 149, 165)
Dim Shared As ULong tiko_ColorAccent = RGB(95, 173, 210)

' -------------------------------------------------------------------------
' Application procedure declarations
' -------------------------------------------------------------------------

Declare Sub tiko_SetStatus(ByVal message As String)
Declare Sub tiko_UpdateWindowTitle()
Declare Sub tiko_SetOutput(ByVal message As String)
Declare Sub tiko_ShowOutputPage(ByVal pageIndex As Integer)
Declare Sub tiko_CaptureOutputNotes()
Declare Sub tiko_RefreshDocumentList()
Declare Sub tiko_ResizeWidgets()
Declare Sub tiko_CaptureActiveDocument()
Declare Sub tiko_DisplayDocument(ByVal documentIndex As Integer)
Declare Sub tiko_ActivateDocument(ByVal documentIndex As Integer)
Declare Sub tiko_CreateDocument()
Declare Sub tiko_RemoveDocument(ByVal documentIndex As Integer)
Declare Sub tiko_CloseAllDocuments()
Declare Sub tiko_OpenDocument(ByVal filename As String)
Declare Sub tiko_OpenFileDialog()
Declare Sub tiko_OpenProjectDialog()
Declare Sub tiko_OpenProjectSaveDialog()
Declare Sub tiko_LoadProject(ByVal filename As String)
Declare Sub tiko_SaveProject()
Declare Sub tiko_SaveProjectAs()
Declare Sub tiko_NewProject()
Declare Sub tiko_CloseProject()
Declare Function tiko_LoadProjectFile(ByVal filename As String) As Integer
Declare Function tiko_SaveProjectFile(ByVal filename As String) As Integer
Declare Sub tiko_OpenSaveDialog(ByVal afterSaveAction As Integer)
Declare Sub tiko_ProcessDialog()
Declare Sub tiko_SaveCurrentDocument()
Declare Sub tiko_SaveCurrentAs()
Declare Sub tiko_SaveAllDocuments()
Declare Sub tiko_ContinueSaveAll(ByVal firstDocument As Integer)
Declare Sub tiko_RequestBuild(ByVal runAfterBuild As Integer)
Declare Sub tiko_BuildCurrentDocument(ByVal runAfterBuild As Integer)
Declare Sub tiko_FindNext()
Declare Sub tiko_FindPrevious()
Declare Sub tiko_FindInFiles()
Declare Sub tiko_GotoLine()
Declare Sub tiko_ReplaceCurrent()
Declare Sub tiko_ReplaceAll()
Declare Sub tiko_ShowReplace()
Declare Sub tiko_ShowFindInFiles()
Declare Sub tiko_ShowGotoLine()
Declare Sub tiko_SetFindBarMode(ByVal mode As Integer)
Declare Sub tiko_HideFindBar()
Declare Sub tiko_ActivateRelativeDocument(ByVal direction As Integer)
Declare Sub tiko_GotoNextFunction()
Declare Sub tiko_GotoPreviousFunction()
Declare Sub tiko_GotoDefinition()
Declare Sub tiko_GotoLastPosition()
Declare Sub tiko_RebuildFunctionList()
Declare Sub tiko_GotoFunctionIndex(ByVal functionIndex As Integer)
Declare Function tiko_GetFunctionName(ByRef lineText As Const String) As String
Declare Sub tiko_ProcessHotkeys()
Declare Sub tiko_ProcessDocumentSelection()
Declare Sub tiko_RequestCloseDocument()
Declare Sub tiko_RequestExit()
Declare Sub tiko_CloseAfterConfirmation()
Declare Sub tiko_ShowFind()
Declare Sub tiko_ShowMenu(ByVal menuIndex As Integer, ByVal menuX As Integer)
Declare Sub tiko_CloseMenu()
Declare Sub tiko_AddPopupItem(ByVal labelText As String, ByVal actionId As Integer)
Declare Sub tiko_AddPopupSeparator()
Declare Sub tiko_ExecuteMenuAction(ByVal actionId As Integer, ByVal itemText As String)
Declare Sub tiko_OnMenuSelection(ByVal context As Any Ptr, ByVal itemIndex As Integer)
Declare Sub tiko_MenuBarRender(ByVal w As Widget Ptr)
Declare Sub tiko_MenuBarUpdate(ByVal w As Widget Ptr)
Declare Sub tiko_PanelRender(ByVal w As Widget Ptr)
Declare Sub tiko_PanelUpdate(ByVal w As Widget Ptr)
Declare Sub tiko_TabStripRender(ByVal w As Widget Ptr)
Declare Sub tiko_TabStripUpdate(ByVal w As Widget Ptr)
Declare Sub tiko_StatusBarRender(ByVal w As Widget Ptr)
Declare Sub tiko_VisualDestroy(ByVal w As Widget Ptr)
Declare Function tiko_CreateVisualWidget( _
    ByVal widgetName As String, ByVal x As Integer, ByVal y As Integer, _
    ByVal width As Integer, ByVal height As Integer, ByVal controlKind As Integer _
) As Widget Ptr
Declare Function tiko_MenuIndexAt(ByVal mouseX As Integer, ByVal mouseY As Integer) As Integer
Declare Function tiko_MenuLeft(ByVal menuIndex As Integer) As Integer
Declare Function tiko_ExplorerDocumentAt(ByVal localY As Integer) As Integer
Declare Sub tiko_AdjustBookmarks( _
    ByRef document As TikoDocument, _
    ByRef oldText As Const String, _
    ByRef newText As Const String _
)
Declare Sub tiko_GotoBookmarkByIndex(ByVal bookmarkIndex As Integer)
Declare Function tiko_KeyJustPressed(ByVal keyCode As Integer) As Integer
Declare Function tiko_BookmarkIndexAtPanelRow(ByVal localY As Integer) As Integer

#include once "tiko_native_edit.bi"

' -------------------------------------------------------------------------
' Small string and file helpers
' -------------------------------------------------------------------------

Private Function tiko_GetBaseName(ByVal filename As String) As String

    Dim As Integer separatorPosition

    separatorPosition = 0
    For charPosition As Integer = 1 To Len(filename)
        If Mid(filename, charPosition, 1) = "/" OrElse _
           Mid(filename, charPosition, 1) = Chr(92) Then
            separatorPosition = charPosition
        End If
    Next charPosition

    Return Mid(filename, separatorPosition + 1)

End Function


Private Function tiko_PathsEqual( _
    ByVal firstPath As String, ByVal secondPath As String _
) As Integer

#If Defined(__FB_WIN32__)
    Return IIf(LCase(firstPath) = LCase(secondPath), -1, 0)
#Else
    Return IIf(firstPath = secondPath, -1, 0)
#EndIf

End Function


Private Function tiko_IsPathOpen( _
    ByVal filename As String, ByVal exceptIndex As Integer _
) As Integer

    For documentIndex As Integer = 0 To tiko_DocumentCount - 1
        If documentIndex <> exceptIndex AndAlso _
           tiko_PathsEqual(tiko_Documents(documentIndex).path, filename) <> 0 Then
            Return -1
        End If
    Next documentIndex

    Return 0

End Function


Private Function tiko_NormalizeLineEndings( _
    ByVal sourceText As String, ByRef lineEnding As Integer _
) As String

    Dim As Integer characterCode
    Dim As Integer charPosition
    Dim As Integer lineEndingFound
    Dim As Integer outputPosition
    Dim As String normalizedText

    lineEnding = 0
    lineEndingFound = 0
    normalizedText = String(Len(sourceText), Chr(0))
    charPosition = 0
    outputPosition = 0
    While charPosition < Len(sourceText)
        characterCode = sourceText[charPosition]
        Select Case characterCode
        Case 13
            If lineEndingFound = 0 Then
                If charPosition + 1 < Len(sourceText) AndAlso _
                   sourceText[charPosition + 1] = 10 Then
                    lineEnding = 1
                Else
                    lineEnding = 2
                End If
                lineEndingFound = -1
            End If
            normalizedText[outputPosition] = 10
            outputPosition += 1
            If charPosition + 1 < Len(sourceText) AndAlso _
               sourceText[charPosition + 1] = 10 Then
                charPosition += 1
            End If
        Case 10
            If lineEndingFound = 0 Then lineEndingFound = -1
            normalizedText[outputPosition] = 10
            outputPosition += 1
        Case Else
            normalizedText[outputPosition] = characterCode
            outputPosition += 1
        End Select
        charPosition += 1
    Wend

    Return Left(normalizedText, outputPosition)

End Function


Private Function tiko_ReadFile( _
    ByVal filename As String, _
    ByRef fileText As String, _
    ByRef errorText As String, _
    ByRef hasUtf8Bom As Integer, _
    ByRef lineEnding As Integer _
) As Integer

    Dim As Integer fileNumber
    Dim As LongInt fileLength

    fileText = ""
    errorText = ""
    hasUtf8Bom = 0
    lineEnding = 0

    fileNumber = FreeFile
    If Open(filename For Binary Access Read As #fileNumber) <> 0 Then
        errorText = "Could not open " & filename
        Return 0
    End If

    fileLength = LOF(fileNumber)
    If fileLength < 0 OrElse fileLength > TIKO_MAX_SOURCE_FILE_BYTES Then
        Close #fileNumber
        errorText = "File exceeds the 4 MiB input limit: " & filename
        Return 0
    End If

    If fileLength > 0 Then
        fileText = String(CInt(fileLength), Chr(0))
        If Get(fileNumber, , fileText) <> 0 Then
            Close #fileNumber
            fileText = ""
            errorText = "Could not read " & filename
            Return 0
        End If
    End If

    Close #fileNumber

    ' UTF-8 files may begin with a BOM. The editor stores the source bytes
    ' without it so the first visible character is the first source token.
    If Len(fileText) >= 3 AndAlso _
       Asc(Mid(fileText, 1, 1)) = 239 AndAlso _
       Asc(Mid(fileText, 2, 1)) = 187 AndAlso _
       Asc(Mid(fileText, 3, 1)) = 191 Then
        hasUtf8Bom = -1
        fileText = Mid(fileText, 4)
    End If

    fileText = tiko_NormalizeLineEndings(fileText, lineEnding)
    If Len(fileText) > TIKO_MAX_SOURCE_BYTES Then
        fileText = ""
        errorText = "File expands beyond the 2 MiB editor limit: " & filename
        Return 0
    End If
    Return -1

End Function


Private Function tiko_FormatDocumentForSave( _
    ByVal documentIndex As Integer _
) As String

    Dim As Integer characterCode
    Dim As Integer outputPosition
    Dim As Integer outputLength
    Dim As Integer newlineCount
    Dim As String formattedText
    Dim As String sourceText

    If documentIndex < 0 OrElse documentIndex >= tiko_DocumentCount Then _
        Return ""

    sourceText = tiko_Documents(documentIndex).text
    For charPosition As Integer = 0 To Len(sourceText) - 1
        If sourceText[charPosition] = 10 Then newlineCount += 1
    Next charPosition
    outputLength = Len(sourceText)
    If tiko_Documents(documentIndex).line_ending = 1 Then _
        outputLength += newlineCount
    formattedText = String(outputLength, Chr(0))
    outputPosition = 0

    For charPosition As Integer = 0 To Len(sourceText) - 1
        characterCode = sourceText[charPosition]
        If characterCode = 10 Then
            Select Case tiko_Documents(documentIndex).line_ending
            Case 1
                formattedText[outputPosition] = 13
                outputPosition += 1
                formattedText[outputPosition] = 10
                outputPosition += 1
            Case 2
                formattedText[outputPosition] = 13
                outputPosition += 1
            Case Else
                formattedText[outputPosition] = 10
                outputPosition += 1
            End Select
        Else
            formattedText[outputPosition] = characterCode
            outputPosition += 1
        End If
    Next charPosition

    If tiko_Documents(documentIndex).utf8_bom <> 0 Then _
        Return Chr(239) & Chr(187) & Chr(191) & formattedText

    Return formattedText

End Function


Private Function tiko_SaveFile( _
    ByVal filename As String, _
    ByVal fileText As String, _
    ByRef errorText As String _
) As Integer

    Dim As Integer fileNumber
    Dim As Integer hadOriginal
    Dim As Integer writeError
    Dim As String backupPath
    Dim As String temporaryPath

    errorText = ""
    If filename = "" Then
        errorText = "Choose a filename before saving"
        Return 0
    End If
    If Len(fileText) > TIKO_MAX_SOURCE_FILE_BYTES + 3 Then
        errorText = "The source is larger than the 4 MiB file limit"
        Return 0
    End If

    ' A sibling temporary file lets the save finish before the old file is
    ' moved out of the way. The backup remains available if the final rename
    ' fails, including on platforms that do not replace an existing target.
    temporaryPath = filename & ".tiko-tmp"
    backupPath = filename & ".tiko-backup"
    If Dir(temporaryPath) <> "" OrElse Dir(backupPath) <> "" Then
        errorText = "A Tiko save recovery file already exists beside " & filename
        Return 0
    End If

    fileNumber = FreeFile
    If Open(temporaryPath For Binary Access Write As #fileNumber) <> 0 Then
        errorText = "Could not create a temporary file beside " & filename
        Return 0
    End If

    writeError = 0
    If Len(fileText) > 0 Then writeError = Put(fileNumber, , fileText)
    Close #fileNumber

    If writeError <> 0 Then
        Kill temporaryPath
        errorText = "Could not write all source bytes to " & filename
        Return 0
    End If

    hadOriginal = IIf(Dir(filename) <> "", -1, 0)
    If hadOriginal <> 0 Then
        If Name(filename, backupPath) <> 0 Then
            Kill temporaryPath
            errorText = "Could not protect the previous file before saving"
            Return 0
        End If
    End If

    If Name(temporaryPath, filename) <> 0 Then
        If hadOriginal <> 0 Then Name(backupPath, filename)
        Kill temporaryPath
        errorText = "Could not replace " & filename
        Return 0
    End If

    If hadOriginal <> 0 Then Kill backupPath
    Return -1

End Function


Private Function tiko_GetTemporaryDirectory() As String

    Dim As String directoryPath

#If Defined(__FB_WIN32__)
    directoryPath = Environ("TEMP")
    If directoryPath = "" Then directoryPath = Environ("TMP")
#Else
    directoryPath = Environ("TMPDIR")
#EndIf

    If directoryPath = "" Then directoryPath = CurDir
    If Right(directoryPath, 1) <> "/" AndAlso _
       Right(directoryPath, 1) <> Chr(92) Then
#If Defined(__FB_WIN32__)
        directoryPath &= Chr(92)
#Else
        directoryPath &= "/"
#EndIf
    End If

    Return directoryPath

End Function


Private Function tiko_MakeTemporaryPath(ByVal extension As String) As String

    Dim As String candidatePath
    Dim As String temporaryDirectory = tiko_GetTemporaryDirectory()

    For attempt As Integer = 1 To TIKO_TEMP_PATH_ATTEMPTS
        tiko_TempNameCounter += 1
        candidatePath = temporaryDirectory & "tiko-" & _
            LTrim(Str(Int(Timer * 1000))) & "-" & _
            LTrim(Str(tiko_TempNameCounter)) & "." & extension
        If Dir(candidatePath) = "" Then Return candidatePath
    Next attempt

    Return ""

End Function


Private Function tiko_QuoteShellArgument(ByVal argumentText As String) As String

    Dim As String quotedText

    If argumentText = "" OrElse _
       Instr(argumentText, Chr(10)) <> 0 OrElse _
       Instr(argumentText, Chr(13)) <> 0 Then Return ""

#If Defined(__FB_WIN32__)
    ' cmd.exe expands these even inside double quotes. Reject them rather
    ' than risk running a command with an altered path.
    If Instr(argumentText, Chr(34)) <> 0 OrElse _
       Instr(argumentText, "%") <> 0 OrElse _
       Instr(argumentText, "!") <> 0 Then Return ""
    Return Chr(34) & argumentText & Chr(34)
#Else
    quotedText = Chr(39)
    For charPosition As Integer = 1 To Len(argumentText)
        If Mid(argumentText, charPosition, 1) = Chr(39) Then
            quotedText &= Chr(39) & Chr(92) & Chr(39) & Chr(39)
        Else
            quotedText &= Mid(argumentText, charPosition, 1)
        End If
    Next charPosition
    Return quotedText & Chr(39)
#EndIf

End Function


#include once "tiko_native_project.bi"

' -------------------------------------------------------------------------
' FreeBASIC source color callback
' -------------------------------------------------------------------------

Private Function tiko_IsWordCharacter(ByVal characterCode As Integer) As Integer

    If characterCode >= 48 AndAlso characterCode <= 57 Then Return -1
    If characterCode >= 65 AndAlso characterCode <= 90 Then Return -1
    If characterCode >= 97 AndAlso characterCode <= 122 Then Return -1
    If characterCode = 95 Then Return -1
    Return 0

End Function


Private Function tiko_IsKeyword(ByVal wordText As String) As Integer

    Static As String keywordList

    If keywordList = "" Then
        keywordList = _
            ",and,as,asm,assert,bit,byref,byval,call,case,cast,cbool,cbyte," & _
            "cint,clng,continue,csng,cstr,declare,defint,dim,do,double,else," & _
            "elseif,end,enum,erase,error,exit,extern,false,for,function,if," & _
            "include,integer,is,let,lib,loop,mod,new,next,null,or,preserve," & _
            "private,property,ptr,public,redim,return,select,shared,static," & _
            "step,stop,string,sub,then,this,to,true,type,until,using,wend," & _
            "while,with,xor,"
    End If

    Return IIf(Instr(keywordList, "," & LCase(wordText) & ",") > 0, -1, 0)

End Function


Private Function tiko_TextColor( _
    ByRef lineText As Const String, _
    ByVal characterIndex As Integer, _
    ByRef state As Integer _
) As ULong

    Dim As Integer characterCode
    Dim As Integer nextCode
    Dim As Integer tokenEnd
    Dim As String tokenText

    If characterIndex < 0 OrElse characterIndex >= Len(lineText) Then _
        Return current_theme.text_main

    characterCode = Asc(Mid(lineText, characterIndex + 1, 1))
    nextCode = 0
    If characterIndex + 1 < Len(lineText) Then _
        nextCode = Asc(Mid(lineText, characterIndex + 2, 1))

    If state = 5 Then Return RGB(112, 150, 118)

    If state = 10 Then
        If tiko_IsWordCharacter(characterCode) <> 0 Then
            If characterIndex = Len(lineText) - 1 Then state = 0
            Return RGB(125, 175, 235)
        End If
        state = 0
    End If

    If state = 1 Then
        If characterCode = 39 AndAlso nextCode = 47 Then
            state = 6
        End If
        Return RGB(112, 150, 118)
    Elseif state = 6 Then
        state = 0
        Return RGB(112, 150, 118)
    Elseif state = 2 Then
        If characterCode = 34 Then
            If nextCode <> 34 Then state = 0
        Elseif characterIndex = Len(lineText) - 1 Then
            state = 0
        End If
        Return RGB(215, 175, 125)
    End If

    If characterCode = 47 AndAlso nextCode = 39 Then
        state = 1
        Return RGB(112, 150, 118)
    End If

    If characterCode = 39 Then
        state = 5
        Return RGB(112, 150, 118)
    End If

    If characterCode = 34 Then
        state = 2
        Return RGB(215, 175, 125)
    End If

    If (characterCode >= 48 AndAlso characterCode <= 57) OrElse _
       (characterCode = 46 AndAlso nextCode >= 48 AndAlso nextCode <= 57) Then
        Return RGB(150, 190, 235)
    End If

    If tiko_IsWordCharacter(characterCode) <> 0 AndAlso _
       (characterIndex = 0 OrElse _
        tiko_IsWordCharacter(Asc(Mid(lineText, characterIndex, 1))) = 0) Then
        tokenEnd = characterIndex
        While tokenEnd < Len(lineText) AndAlso _
              tiko_IsWordCharacter(Asc(Mid(lineText, tokenEnd + 1, 1))) <> 0
            tokenEnd += 1
        Wend
        tokenText = Mid(lineText, characterIndex + 1, tokenEnd - characterIndex)

        If UCase(tokenText) = "REM" AndAlso _
           (tokenEnd = Len(lineText) OrElse _
            tiko_IsWordCharacter(Asc(Mid(lineText, tokenEnd + 1, 1))) = 0) Then
            state = 5
            Return RGB(112, 150, 118)
        End If

        If tiko_IsKeyword(tokenText) <> 0 Then
            state = 10
            If characterIndex = Len(lineText) - 1 Then state = 0
            Return RGB(125, 175, 235)
        End If
    End If

    Return current_theme.text_main

End Function

' -------------------------------------------------------------------------
' Shared user interface helpers
' -------------------------------------------------------------------------

Private Sub tiko_SetStatus(ByVal message As String)

    tiko_StatusText = message

End Sub


Private Sub tiko_SetOutput(ByVal message As String)

    If tiko_Output = 0 OrElse tiko_Output->data = 0 Then Exit Sub
    tiko_BuildOutput = message
    tiko_ShowOutputPage(0)
    tiko_ShowOutput = -1
    If tiko_OutputHeading <> 0 Then tiko_OutputHeading->visible = -1
    tiko_ResizeWidgets

End Sub


Private Sub tiko_ShowOutputPage(ByVal pageIndex As Integer)

    Dim As Integer lineStart
    Dim As Integer lineEnd
    Dim As Integer lineAfter
    Dim As Integer lineNumber = 1
    Dim As String pageText
    Dim As String sourceText

    If pageIndex < 0 OrElse pageIndex > 4 Then Return
    tiko_CaptureOutputNotes
    tiko_OutputPage = pageIndex

    Select Case pageIndex
    Case 0
        pageText = tiko_BuildOutput
    Case 1
        pageText = tiko_CompilerLogOutput
        If Trim(pageText) = "" Then pageText = "No compiler log file exists."
    Case 2
        pageText = tiko_SearchOutput
    Case 3
        For documentIndex As Integer = 0 To tiko_DocumentCount - 1
            If tiko_Documents(documentIndex).is_missing <> 0 Then Continue For
            sourceText = tiko_Documents(documentIndex).text
            Dim As String sourceName = tiko_Documents(documentIndex).path
            If sourceName = "" Then sourceName = tiko_Documents(documentIndex).title
            lineStart = 0
            lineNumber = 1
            While lineStart <= Len(sourceText)
                tiko_GetLineRange sourceText, lineStart, lineEnd, lineAfter
                Dim As String lineText = Mid( _
                    sourceText, lineStart + 1, lineEnd - lineStart _
                )
                If Instr(UCase(lineText), "TODO") <> 0 OrElse _
                   Instr(UCase(lineText), "FIXME") <> 0 Then
                    pageText &= sourceName & _
                        ":" & LTrim(Str(lineNumber)) & ": " & _
                        Trim(lineText) & Chr(10)
                    If Len(pageText) >= TIKO_MAX_OUTPUT_BYTES Then
                        pageText = Left(pageText, TIKO_MAX_OUTPUT_BYTES - 32) & _
                            "... TODO output truncated ..."
                        Exit While
                    End If
                End If
                lineNumber += 1
                If lineAfter <= lineStart Then Exit While
                lineStart = lineAfter
            Wend
            If Len(pageText) >= TIKO_MAX_OUTPUT_BYTES Then Exit For
        Next documentIndex
        If pageText = "" Then pageText = "No TODO or FIXME comments in this project."
    Case 4
        If tiko_ProjectActive <> 0 Then
            pageText = tiko_ProjectNotes
        Else
            pageText = tiko_UserNotes
        End If
    End Select

    textbox_SetText(tiko_Output, pageText, -1)
    textbox_SetReadOnly(tiko_Output, IIf(pageIndex = 4, 0, -1))
    If tiko_Output->data <> 0 Then
        tiko_OutputChangeSerial = _
            Cast(TextBoxData Ptr, tiko_Output->data)->change_serial
    End If
    If pageIndex = 4 Then gui_SetFocus(tiko_Output)

End Sub


Private Sub tiko_CaptureOutputNotes()

    Dim As TextBoxData Ptr textData

    If tiko_OutputPage <> 4 OrElse tiko_Output = 0 OrElse _
       tiko_Output->data = 0 Then Exit Sub
    textData = Cast(TextBoxData Ptr, tiko_Output->data)
    If textData->change_serial = tiko_OutputChangeSerial Then Exit Sub

    If tiko_ProjectActive <> 0 Then
        tiko_ProjectNotes = textData->text
    Else
        tiko_UserNotes = textData->text
    End If
    tiko_OutputChangeSerial = textData->change_serial

End Sub


Private Sub tiko_RefreshDocumentList()

    Dim As ListBoxData Ptr listData

    If tiko_FileList = 0 OrElse tiko_FileList->data = 0 Then Exit Sub

    listbox_Clear(tiko_FileList)
    For documentIndex As Integer = 0 To tiko_DocumentCount - 1
        Dim As String itemText = tiko_Documents(documentIndex).title
        If tiko_Documents(documentIndex).dirty <> 0 Then _
            itemText = "* " & itemText
        If documentIndex = tiko_ActiveDocument Then _
            itemText = "> " & itemText
        listbox_AddItem(tiko_FileList, itemText)
    Next documentIndex

    listData = Cast(ListBoxData Ptr, tiko_FileList->data)
    If tiko_DocumentCount > 0 Then
        listData->selected_index = tiko_ActiveDocument
    End If
    tiko_LastListSelection = tiko_ActiveDocument

End Sub


Private Sub tiko_UpdateWindowTitle()

    Dim As String titleText = "Tiko Editor"

    If tiko_ActiveDocument >= 0 AndAlso _
       tiko_ActiveDocument < tiko_DocumentCount Then
        titleText = "Tiko"
        If tiko_ProjectActive <> 0 AndAlso tiko_ProjectName <> "" Then _
            titleText &= " - [" & tiko_ProjectName & "]"
        If tiko_Documents(tiko_ActiveDocument).path <> "" Then
            titleText &= " - [" & tiko_Documents(tiko_ActiveDocument).path & "]"
        Else
            titleText &= " - [" & tiko_Documents(tiko_ActiveDocument).title & "]"
        End If
        If tiko_Documents(tiko_ActiveDocument).dirty <> 0 Then _
            titleText &= " *"
    End If

    If titleText <> tiko_LastWindowTitle Then
        WindowTitle titleText
        tiko_LastWindowTitle = titleText
    End If

End Sub


Private Sub tiko_ResizeWidgets()

    Dim As Integer screenHeight
    Dim As Integer screenWidth
    Dim As Integer editorHeight
    Dim As Integer outputHeight
    Dim As Integer sidebarWidth
    Dim As Integer editorTop
    Dim As Integer findBarTop
    Dim As Integer findBarHeight
    Dim As Integer findInputLeft
    Dim As Integer findInputWidth
    Dim As Integer previousButtonX
    Dim As Integer nextButtonX
    Dim As Integer statusTop
    Dim As Integer outputTop
    Dim As Integer findLeft

    backend_GetSize screenWidth, screenHeight
    If screenWidth < 640 Then screenWidth = 640
    If screenHeight < 480 Then screenHeight = 480

    sidebarWidth = TIKO_SIDEBAR_WIDTH
    If sidebarWidth > screenWidth \ 3 Then sidebarWidth = screenWidth \ 3
    findBarTop = TIKO_MENU_HEIGHT + TIKO_PANEL_TOOLBAR_HEIGHT + TIKO_TAB_HEIGHT
    findBarHeight = 0
    If tiko_ShowFindBar <> 0 Then
        findBarHeight = TIKO_FIND_BAR_HEIGHT
        If tiko_FindMode = TIKO_FIND_MODE_REPLACE Then findBarHeight = 64
    End If
    editorTop = findBarTop + findBarHeight
    statusTop = screenHeight - TIKO_STATUS_HEIGHT
    outputHeight = IIf(tiko_ShowOutput <> 0, TIKO_OUTPUT_HEIGHT, 0)
    If outputHeight > screenHeight - editorTop - TIKO_STATUS_HEIGHT - 100 Then _
        outputHeight = screenHeight - editorTop - TIKO_STATUS_HEIGHT - 100
    outputTop = statusTop - outputHeight
    editorHeight = outputTop - editorTop
    If editorHeight < 100 Then editorHeight = 100

    If tiko_MenuBar <> 0 Then
        tiko_MenuBar->x = 0
        tiko_MenuBar->y = 0
        tiko_MenuBar->w = screenWidth
        tiko_MenuBar->h = TIKO_MENU_HEIGHT
    End If
    If tiko_Panel <> 0 Then
        tiko_Panel->x = 0
        tiko_Panel->y = TIKO_MENU_HEIGHT
        tiko_Panel->w = sidebarWidth
        tiko_Panel->h = screenHeight - TIKO_MENU_HEIGHT - TIKO_STATUS_HEIGHT
        tiko_Panel->visible = tiko_ShowSidePanel
    End If
    If tiko_TabStrip <> 0 Then
        tiko_TabStrip->x = sidebarWidth
        tiko_TabStrip->y = TIKO_MENU_HEIGHT + TIKO_PANEL_TOOLBAR_HEIGHT
        tiko_TabStrip->w = screenWidth - sidebarWidth
        tiko_TabStrip->h = TIKO_TAB_HEIGHT
    End If
    If tiko_FileList <> 0 Then
        tiko_FileList->h = editorHeight
        tiko_FileList->visible = 0
    End If
    If tiko_Editor <> 0 Then
        tiko_Editor->x = sidebarWidth
        tiko_Editor->y = editorTop
        tiko_Editor->w = screenWidth - sidebarWidth
        tiko_Editor->h = editorHeight
    End If
    If tiko_StatusBar <> 0 Then
        tiko_StatusBar->x = 0
        tiko_StatusBar->y = statusTop
        tiko_StatusBar->w = screenWidth
        tiko_StatusBar->h = TIKO_STATUS_HEIGHT
    End If
    If tiko_Status <> 0 Then
        tiko_Status->x = 0
        tiko_Status->y = statusTop
        tiko_Status->w = screenWidth
        tiko_Status->h = TIKO_STATUS_HEIGHT
    End If
    If tiko_Output <> 0 Then
        tiko_Output->visible = IIf(tiko_ShowOutput <> 0, -1, 0)
        tiko_Output->x = sidebarWidth
        tiko_Output->y = outputTop + TIKO_OUTPUT_HEADER_HEIGHT
        tiko_Output->w = screenWidth - sidebarWidth
        tiko_Output->h = outputHeight - TIKO_OUTPUT_HEADER_HEIGHT
        If tiko_Output->h < 60 Then tiko_Output->h = 60
    End If
    If tiko_OutputHeading <> 0 Then
        tiko_OutputHeading->x = sidebarWidth
        tiko_OutputHeading->y = outputTop
        tiko_OutputHeading->w = screenWidth - sidebarWidth
        tiko_OutputHeading->h = TIKO_OUTPUT_HEADER_HEIGHT
        tiko_OutputHeading->visible = IIf(tiko_ShowOutput <> 0, -1, 0)
    End If
    If tiko_FindBar <> 0 Then
        tiko_FindBar->x = sidebarWidth
        tiko_FindBar->y = findBarTop
        tiko_FindBar->w = screenWidth - sidebarWidth
        tiko_FindBar->h = findBarHeight
        tiko_FindBar->visible = IIf(tiko_ShowFindBar <> 0, -1, 0)
    End If
    findLeft = sidebarWidth + 12
    previousButtonX = screenWidth - 210
    nextButtonX = screenWidth - 132
    If tiko_FindMode = TIKO_FIND_MODE_FILES OrElse _
       tiko_FindMode = TIKO_FIND_MODE_GOTO Then
        previousButtonX = nextButtonX
    End If
    findInputLeft = findLeft + 58
    If tiko_FindMode = TIKO_FIND_MODE_FILES Then _
        findInputLeft = findLeft + backend_GetTextWidth("Find in files") + 12
    findInputWidth = previousButtonX - findInputLeft - 8
    If tiko_FindMode <> TIKO_FIND_MODE_REPLACE Then
        nextButtonX = screenWidth - 132
        findInputWidth = nextButtonX - findInputLeft - 8
    End If
    If findInputWidth < 72 Then findInputWidth = 72
    If tiko_FindLabel <> 0 Then
        tiko_FindLabel->x = findLeft
        tiko_FindLabel->y = findBarTop + 10
    End If
    If tiko_FindBox <> 0 Then
        tiko_FindBox->x = findInputLeft
        tiko_FindBox->y = findBarTop + 5
        tiko_FindBox->w = findInputWidth
        tiko_FindBox->h = 28
    End If
    If tiko_FindNextButton <> 0 Then
        tiko_FindNextButton->x = nextButtonX
        tiko_FindNextButton->y = findBarTop + 4
        tiko_FindNextButton->w = IIf( _
            tiko_FindMode = TIKO_FIND_MODE_FILES, 94, _
            IIf(tiko_FindMode = TIKO_FIND_MODE_GOTO, 94, 72) _
        )
        tiko_FindNextButton->h = 30
    End If
    If tiko_FindPreviousButton <> 0 Then
        tiko_FindPreviousButton->x = previousButtonX
        tiko_FindPreviousButton->y = findBarTop + 4
        tiko_FindPreviousButton->w = 72
        tiko_FindPreviousButton->h = 30
    End If
    If tiko_ReplaceBox <> 0 Then
        tiko_ReplaceBox->x = findInputLeft
        tiko_ReplaceBox->y = findBarTop + 34
        tiko_ReplaceBox->w = findInputWidth
        tiko_ReplaceBox->h = 28
    End If
    If tiko_ReplaceButton <> 0 Then
        tiko_ReplaceButton->x = screenWidth - 210
        tiko_ReplaceButton->y = findBarTop + 34
        tiko_ReplaceButton->w = 72
        tiko_ReplaceButton->h = 30
    End If
    If tiko_ReplaceAllButton <> 0 Then
        tiko_ReplaceAllButton->x = screenWidth - 132
        tiko_ReplaceAllButton->y = findBarTop + 34
        tiko_ReplaceAllButton->w = 90
        tiko_ReplaceAllButton->h = 30
    End If
    If tiko_FindCloseButton <> 0 Then
        tiko_FindCloseButton->x = screenWidth - 36
        tiko_FindCloseButton->y = findBarTop + 4
        tiko_FindCloseButton->w = 28
        tiko_FindCloseButton->h = 30
    End If

End Sub


Private Sub tiko_CaptureActiveDocument()

    Dim As Integer oldDirty
    Dim As TextBoxData Ptr textData

    If tiko_ActiveDocument < 0 OrElse _
       tiko_ActiveDocument >= tiko_DocumentCount OrElse _
       tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Exit Sub

    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    tiko_Documents(tiko_ActiveDocument).cursor_pos = textData->cursor_pos
    tiko_Documents(tiko_ActiveDocument).vertical_scroll = textData->v_scroll

    If textData->change_serial <> tiko_LastCapturedChange Then
        oldDirty = tiko_Documents(tiko_ActiveDocument).dirty
        tiko_AdjustBookmarks( _
            tiko_Documents(tiko_ActiveDocument), _
            tiko_Documents(tiko_ActiveDocument).text, textData->text _
        )
        tiko_Documents(tiko_ActiveDocument).text = textData->text
        tiko_Documents(tiko_ActiveDocument).dirty = _
            IIf(textData->text <> tiko_Documents(tiko_ActiveDocument).saved_text, -1, 0)
        tiko_LastCapturedChange = textData->change_serial
        If oldDirty <> tiko_Documents(tiko_ActiveDocument).dirty Then
            tiko_RefreshDocumentList
            tiko_UpdateWindowTitle
        End If
    End If

End Sub


Private Sub tiko_DisplayDocument(ByVal documentIndex As Integer)

    Dim As TextBoxData Ptr textData

    If documentIndex < 0 OrElse documentIndex >= tiko_DocumentCount Then Exit Sub

    tiko_ActiveDocument = documentIndex
    textbox_SetText(tiko_Editor, tiko_Documents(documentIndex).text, -1)
    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    tiko_LastCapturedChange = textData->change_serial
    textData->cursor_pos = tiko_Documents(documentIndex).cursor_pos
    If textData->cursor_pos < 0 OrElse _
       textData->cursor_pos > Len(textData->text) Then _
        textData->cursor_pos = Len(textData->text)
    textData->sel_start = textData->cursor_pos
    textData->sel_end = textData->cursor_pos
    textData->selection_anchor = textData->cursor_pos
    textData->v_scroll = tiko_Documents(documentIndex).vertical_scroll
    textData->viewport_dirty = -1
    gui_SetFocus(tiko_Editor)

    tiko_RefreshDocumentList
    tiko_UpdateWindowTitle
    tiko_SetStatus(tiko_Documents(documentIndex).path)

End Sub


Private Sub tiko_ActivateDocument(ByVal documentIndex As Integer)

    If documentIndex < 0 OrElse documentIndex >= tiko_DocumentCount Then Exit Sub
    tiko_CaptureActiveDocument
    tiko_Documents(documentIndex).tab_visible = -1
    tiko_DisplayDocument(documentIndex)

End Sub


Private Sub tiko_CreateDocument()

    If tiko_DocumentCount >= TIKO_MAX_DOCUMENTS Then
        tiko_SetStatus("The open document limit is 256")
        Exit Sub
    End If

    tiko_CaptureActiveDocument
    tiko_DocumentCount += 1
    tiko_ActiveDocument = tiko_DocumentCount - 1
    tiko_Documents(tiko_ActiveDocument).path = ""
    tiko_Documents(tiko_ActiveDocument).title = _
        "Untitled " & LTrim(Str(tiko_ActiveDocument + 1))
    tiko_Documents(tiko_ActiveDocument).text = ""
    tiko_Documents(tiko_ActiveDocument).saved_text = ""
    tiko_Documents(tiko_ActiveDocument).cursor_pos = 0
    tiko_Documents(tiko_ActiveDocument).vertical_scroll = 0
    tiko_Documents(tiko_ActiveDocument).dirty = 0
    tiko_Documents(tiko_ActiveDocument).utf8_bom = 0
    tiko_Documents(tiko_ActiveDocument).line_ending = 0
    tiko_Documents(tiko_ActiveDocument).file_type = 3
    tiko_Documents(tiko_ActiveDocument).tab_visible = -1
    tiko_Documents(tiko_ActiveDocument).is_missing = 0
    tiko_Documents(tiko_ActiveDocument).bookmark_count = 0

    textbox_SetText(tiko_Editor, "", -1)
    tiko_LastCapturedChange = Cast(TextBoxData Ptr, tiko_Editor->data)->change_serial
    gui_SetFocus(tiko_Editor)
    tiko_RefreshDocumentList
    tiko_UpdateWindowTitle
    tiko_SetStatus("New FreeBASIC source file")

End Sub


Private Sub tiko_RemoveDocument(ByVal documentIndex As Integer)

    If documentIndex < 0 OrElse documentIndex >= tiko_DocumentCount Then Exit Sub
    tiko_CaptureActiveDocument

    If tiko_ProjectActive <> 0 Then
        If tiko_Documents(documentIndex).dirty <> 0 Then
            tiko_AdjustBookmarks( _
                tiko_Documents(documentIndex), tiko_Documents(documentIndex).text, _
                tiko_Documents(documentIndex).saved_text _
            )
            tiko_Documents(documentIndex).text = _
                tiko_Documents(documentIndex).saved_text
            tiko_Documents(documentIndex).dirty = 0
        End If
        tiko_Documents(documentIndex).tab_visible = 0
        If tiko_ActiveDocument = documentIndex Then
            tiko_ActiveDocument = -1
            For candidateIndex As Integer = documentIndex - 1 To 0 Step -1
                If tiko_Documents(candidateIndex).tab_visible <> 0 AndAlso _
                   tiko_Documents(candidateIndex).is_missing = 0 Then
                    tiko_ActiveDocument = candidateIndex
                    Exit For
                End If
            Next candidateIndex
            If tiko_ActiveDocument < 0 Then
                For candidateIndex As Integer = documentIndex + 1 To _
                    tiko_DocumentCount - 1
                    If tiko_Documents(candidateIndex).tab_visible <> 0 AndAlso _
                       tiko_Documents(candidateIndex).is_missing = 0 Then
                        tiko_ActiveDocument = candidateIndex
                        Exit For
                    End If
                Next candidateIndex
            End If
        End If
        If tiko_ActiveDocument >= 0 Then
            tiko_DisplayDocument(tiko_ActiveDocument)
        Else
            textbox_SetText(tiko_Editor, "", -1)
            tiko_LastCapturedChange = _
                Cast(TextBoxData Ptr, tiko_Editor->data)->change_serial
            tiko_UpdateWindowTitle
            tiko_RefreshDocumentList
        End If
        Return
    End If

    For moveIndex As Integer = documentIndex To tiko_DocumentCount - 2
        tiko_Documents(moveIndex) = tiko_Documents(moveIndex + 1)
    Next moveIndex

    tiko_DocumentCount -= 1
    tiko_Documents(tiko_DocumentCount).path = ""
    tiko_Documents(tiko_DocumentCount).title = ""
    tiko_Documents(tiko_DocumentCount).text = ""
    tiko_Documents(tiko_DocumentCount).saved_text = ""
    tiko_Documents(tiko_DocumentCount).cursor_pos = 0
    tiko_Documents(tiko_DocumentCount).vertical_scroll = 0
    tiko_Documents(tiko_DocumentCount).dirty = 0
    tiko_Documents(tiko_DocumentCount).utf8_bom = 0
    tiko_Documents(tiko_DocumentCount).line_ending = 0
    tiko_Documents(tiko_DocumentCount).file_type = 0
    tiko_Documents(tiko_DocumentCount).tab_visible = 0
    tiko_Documents(tiko_DocumentCount).is_missing = 0
    tiko_Documents(tiko_DocumentCount).bookmark_count = 0

    If tiko_DocumentCount = 0 Then
        tiko_ActiveDocument = -1
        tiko_CreateDocument
    Else
        If tiko_ActiveDocument > documentIndex Then tiko_ActiveDocument -= 1
        If tiko_ActiveDocument >= tiko_DocumentCount Then _
            tiko_ActiveDocument = tiko_DocumentCount - 1
        tiko_DisplayDocument(tiko_ActiveDocument)
    End If

End Sub


Private Sub tiko_CloseAllTabs()

    If tiko_ProjectActive <> 0 Then
        For documentIndex As Integer = 0 To tiko_DocumentCount - 1
            If tiko_Documents(documentIndex).dirty <> 0 Then
                tiko_AdjustBookmarks( _
                    tiko_Documents(documentIndex), tiko_Documents(documentIndex).text, _
                    tiko_Documents(documentIndex).saved_text _
                )
                tiko_Documents(documentIndex).text = _
                    tiko_Documents(documentIndex).saved_text
                tiko_Documents(documentIndex).dirty = 0
            End If
            tiko_Documents(documentIndex).tab_visible = 0
        Next documentIndex
        tiko_ActiveDocument = -1
        textbox_SetText(tiko_Editor, "", -1)
        tiko_LastCapturedChange = _
            Cast(TextBoxData Ptr, tiko_Editor->data)->change_serial
        tiko_RefreshDocumentList
        tiko_UpdateWindowTitle
        tiko_SetStatus("All project files closed")
    Else
        tiko_DocumentCount = 0
        tiko_ActiveDocument = -1
        tiko_CreateDocument
        tiko_SetStatus("All files closed")
    End If

End Sub


Private Sub tiko_CloseAllDocuments()

    Dim As Integer dialogHeight = 150
    Dim As Integer dialogWidth = 420
    Dim As Integer screenHeight
    Dim As Integer screenWidth

    tiko_CaptureActiveDocument
    For documentIndex As Integer = 0 To tiko_DocumentCount - 1
        If tiko_Documents(documentIndex).tab_visible = 0 Then Continue For
        If tiko_Documents(documentIndex).dirty = 0 Then Continue For
        If tiko_ActiveDialog <> 0 Then Return
        backend_GetSize screenWidth, screenHeight
        tiko_ConfirmAction = TIKO_CONFIRM_CLOSE_ALL
        tiko_ActiveDialog = confirmdialog_Create( _
            "tiko_close_all_confirm", "Unsaved source", _
            "Discard all unsaved document changes?", _
            (screenWidth - dialogWidth) \ 2, _
            (screenHeight - dialogHeight) \ 2, "Discard All" _
        )
        If tiko_ActiveDialog <> 0 Then
            tiko_ActiveDialogKind = TIKO_DIALOG_CONFIRM
            gui_AddWidget(tiko_ActiveDialog)
        End If
        Return
    Next documentIndex

    tiko_CloseAllTabs

End Sub

' -------------------------------------------------------------------------
' File dialogs and document persistence
' -------------------------------------------------------------------------

Private Sub tiko_OpenFileDialog()

    Dim As Integer dialogHeight = 340
    Dim As Integer dialogWidth = 400
    Dim As Integer screenHeight
    Dim As Integer screenWidth

    If tiko_ActiveDialog <> 0 Then Exit Sub
    backend_GetSize screenWidth, screenHeight
    tiko_ActiveDialog = filedialog_CreateAtPath( _
        "tiko_open_dialog", _
        (screenWidth - dialogWidth) \ 2, _
        (screenHeight - dialogHeight) \ 2, CurDir _
    )
    If tiko_ActiveDialog <> 0 Then
        tiko_ActiveDialogKind = TIKO_DIALOG_OPEN
        gui_AddWidget(tiko_ActiveDialog)
    End If

End Sub


Private Sub tiko_OpenSaveDialog(ByVal afterSaveAction As Integer)

    Dim As Integer dialogHeight = 340
    Dim As Integer dialogWidth = 400
    Dim As Integer screenHeight
    Dim As Integer screenWidth
    Dim As String suggestedName = "untitled.bas"

    If tiko_ActiveDialog <> 0 Then Exit Sub
    If tiko_ActiveDocument >= 0 AndAlso _
       tiko_ActiveDocument < tiko_DocumentCount AndAlso _
       tiko_Documents(tiko_ActiveDocument).path <> "" Then
        suggestedName = tiko_GetBaseName( _
            tiko_Documents(tiko_ActiveDocument).path _
        )
    End If

    backend_GetSize screenWidth, screenHeight
    tiko_ActiveDialog = filedialog_CreateSaveAtPath( _
        "tiko_save_dialog", _
        (screenWidth - dialogWidth) \ 2, _
        (screenHeight - dialogHeight) \ 2, CurDir, suggestedName _
    )
    If tiko_ActiveDialog <> 0 Then
        tiko_ActiveDialogKind = TIKO_DIALOG_SAVE
        tiko_AfterSaveAction = afterSaveAction
        gui_AddWidget(tiko_ActiveDialog)
    End If

End Sub


Private Sub tiko_OpenDocument(ByVal filename As String)

    Dim As Integer fileLineEnding
    Dim As Integer fileHasUtf8Bom
    Dim As String errorText
    Dim As String fileText

    If filename = "" Then Exit Sub

    For documentIndex As Integer = 0 To tiko_DocumentCount - 1
        If tiko_PathsEqual(tiko_Documents(documentIndex).path, filename) <> 0 Then
            tiko_ActivateDocument(documentIndex)
            tiko_SetStatus("Already open: " & filename)
            Exit Sub
        End If
    Next documentIndex

    If tiko_DocumentCount >= TIKO_MAX_DOCUMENTS Then
        tiko_SetStatus("Close a document before opening another")
        Exit Sub
    End If

    If tiko_ReadFile( _
        filename, fileText, errorText, fileHasUtf8Bom, fileLineEnding _
    ) = 0 Then
        tiko_SetStatus(errorText)
        Return
    End If

    If tiko_DocumentCount = 1 AndAlso tiko_ActiveDocument = 0 AndAlso _
       tiko_Documents(0).path = "" AndAlso _
       tiko_Documents(0).dirty = 0 AndAlso _
       tiko_Documents(0).text = "" Then
        tiko_Documents(0).path = filename
        tiko_Documents(0).title = tiko_GetBaseName(filename)
        tiko_Documents(0).text = fileText
        tiko_Documents(0).saved_text = fileText
        tiko_Documents(0).cursor_pos = 0
        tiko_Documents(0).vertical_scroll = 0
        tiko_Documents(0).dirty = 0
        tiko_Documents(0).utf8_bom = fileHasUtf8Bom
        tiko_Documents(0).line_ending = fileLineEnding
        tiko_Documents(0).file_type = tiko_InferFileType(filename)
        tiko_Documents(0).tab_visible = -1
        tiko_Documents(0).is_missing = 0
        tiko_Documents(0).bookmark_count = 0
        tiko_DisplayDocument(0)
        tiko_SetStatus("Opened " & filename)
        Return
    End If

    tiko_CaptureActiveDocument
    tiko_ActiveDocument = tiko_DocumentCount
    tiko_DocumentCount += 1
    tiko_Documents(tiko_ActiveDocument).path = filename
    tiko_Documents(tiko_ActiveDocument).title = tiko_GetBaseName(filename)
    tiko_Documents(tiko_ActiveDocument).text = fileText
    tiko_Documents(tiko_ActiveDocument).saved_text = fileText
    tiko_Documents(tiko_ActiveDocument).cursor_pos = 0
    tiko_Documents(tiko_ActiveDocument).vertical_scroll = 0
    tiko_Documents(tiko_ActiveDocument).dirty = 0
    tiko_Documents(tiko_ActiveDocument).utf8_bom = fileHasUtf8Bom
    tiko_Documents(tiko_ActiveDocument).line_ending = fileLineEnding
    tiko_Documents(tiko_ActiveDocument).file_type = tiko_InferFileType(filename)
    tiko_Documents(tiko_ActiveDocument).tab_visible = -1
    tiko_Documents(tiko_ActiveDocument).is_missing = 0
    tiko_Documents(tiko_ActiveDocument).bookmark_count = 0

    textbox_SetText(tiko_Editor, fileText, -1)
    tiko_LastCapturedChange = Cast(TextBoxData Ptr, tiko_Editor->data)->change_serial
    gui_SetFocus(tiko_Editor)
    tiko_RefreshDocumentList
    tiko_UpdateWindowTitle
    tiko_SetStatus("Opened " & filename)

End Sub


Private Sub tiko_SaveCurrentDocument()

    Dim As String errorText
    Dim As String sourceText

    If tiko_ActiveDocument < 0 OrElse _
       tiko_ActiveDocument >= tiko_DocumentCount Then Exit Sub
    tiko_CaptureActiveDocument
    If tiko_Documents(tiko_ActiveDocument).path = "" Then
        tiko_OpenSaveDialog(TIKO_AFTER_SAVE_NONE)
        Return
    End If

    sourceText = tiko_FormatDocumentForSave(tiko_ActiveDocument)
    If tiko_SaveFile( _
        tiko_Documents(tiko_ActiveDocument).path, sourceText, errorText _
    ) = 0 Then
        tiko_SetStatus(errorText)
        Return
    End If

    tiko_Documents(tiko_ActiveDocument).saved_text = _
        tiko_Documents(tiko_ActiveDocument).text
    tiko_Documents(tiko_ActiveDocument).dirty = 0
    tiko_RefreshDocumentList
    tiko_UpdateWindowTitle
    tiko_SetStatus("Saved " & tiko_Documents(tiko_ActiveDocument).path)

End Sub


Private Sub tiko_SaveCurrentAs()
    tiko_CaptureActiveDocument
    tiko_OpenSaveDialog(TIKO_AFTER_SAVE_NONE)
End Sub


Private Sub tiko_SaveAllDocuments()

    If tiko_SaveAllPending <> 0 OrElse tiko_DocumentCount <= 0 Then Return
    tiko_CaptureActiveDocument
    tiko_SaveAllOriginalActive = tiko_ActiveDocument
    tiko_SaveAllPending = -1
    tiko_ContinueSaveAll(0)

End Sub


Private Sub tiko_ContinueSaveAll(ByVal firstDocument As Integer)

    Dim As String errorText
    Dim As String sourceText

    For documentIndex As Integer = firstDocument To tiko_DocumentCount - 1
        If tiko_Documents(documentIndex).dirty = 0 Then Continue For

        If tiko_Documents(documentIndex).path = "" Then
            tiko_SaveAllNextDocument = documentIndex + 1
            tiko_DisplayDocument(documentIndex)
            tiko_OpenSaveDialog(TIKO_AFTER_SAVE_SAVE_ALL)
            If tiko_ActiveDialog = 0 Then
                tiko_SaveAllPending = 0
                If tiko_SaveAllOriginalActive >= 0 AndAlso _
                   tiko_SaveAllOriginalActive < tiko_DocumentCount Then _
                    tiko_DisplayDocument(tiko_SaveAllOriginalActive)
                tiko_SetStatus("Could not open Save As for Save All")
            End If
            Return
        End If

        sourceText = tiko_FormatDocumentForSave(documentIndex)
        If tiko_SaveFile( _
            tiko_Documents(documentIndex).path, sourceText, errorText _
        ) = 0 Then
            tiko_SaveAllPending = 0
            If tiko_SaveAllOriginalActive >= 0 AndAlso _
               tiko_SaveAllOriginalActive < tiko_DocumentCount Then _
                tiko_DisplayDocument(tiko_SaveAllOriginalActive)
            tiko_SetStatus(errorText)
            Return
        End If

        tiko_Documents(documentIndex).saved_text = _
            tiko_Documents(documentIndex).text
        tiko_Documents(documentIndex).dirty = 0
    Next documentIndex

    tiko_SaveAllPending = 0
    If tiko_SaveAllOriginalActive >= 0 AndAlso _
       tiko_SaveAllOriginalActive < tiko_DocumentCount AndAlso _
       tiko_ActiveDocument <> tiko_SaveAllOriginalActive Then _
        tiko_DisplayDocument(tiko_SaveAllOriginalActive)
    tiko_RefreshDocumentList
    tiko_UpdateWindowTitle
    tiko_SetStatus("Saved all modified documents")

End Sub


Private Sub tiko_ProcessDialog()

    Dim As Integer dialogResult
    Dim As Integer afterSaveAction
    Dim As String dialogName
    Dim As String selectedFile
    Dim As String saveAllStatus

    If tiko_ActiveDialog = 0 Then Exit Sub

    Select Case tiko_ActiveDialogKind
    Case TIKO_DIALOG_OPEN, TIKO_DIALOG_SAVE, _
         TIKO_DIALOG_PROJECT_OPEN, TIKO_DIALOG_PROJECT_SAVE
        dialogResult = filedialog_GetResultState(tiko_ActiveDialog)
        selectedFile = filedialog_GetSelectedFile(tiko_ActiveDialog)
    Case TIKO_DIALOG_CONFIRM
        dialogResult = confirmdialog_GetResultState(tiko_ActiveDialog)
    End Select

    If dialogResult = 0 Then Exit Sub

    dialogName = tiko_ActiveDialog->name
    gui_RemoveWidget(dialogName)
    tiko_ActiveDialog = 0

    Select Case tiko_ActiveDialogKind
    Case TIKO_DIALOG_OPEN
        tiko_ActiveDialogKind = TIKO_DIALOG_NONE
        If dialogResult > 0 Then tiko_OpenDocument(selectedFile)

    Case TIKO_DIALOG_SAVE
        tiko_ActiveDialogKind = TIKO_DIALOG_NONE
        afterSaveAction = tiko_AfterSaveAction
        If dialogResult > 0 AndAlso selectedFile <> "" Then
            Dim As String errorText
            Dim As String fileText
            If tiko_IsPathOpen(selectedFile, tiko_ActiveDocument) <> 0 Then
                tiko_SetStatus("That file is already open in another document")
                saveAllStatus = "Save All stopped because the file is already open"
            Else
                tiko_CaptureActiveDocument
                fileText = tiko_FormatDocumentForSave(tiko_ActiveDocument)
                If tiko_SaveFile( _
                    selectedFile, fileText, errorText _
                ) <> 0 Then
                    tiko_Documents(tiko_ActiveDocument).path = selectedFile
                    tiko_Documents(tiko_ActiveDocument).title = _
                        tiko_GetBaseName(selectedFile)
                    tiko_Documents(tiko_ActiveDocument).saved_text = _
                        tiko_Documents(tiko_ActiveDocument).text
                    tiko_Documents(tiko_ActiveDocument).dirty = 0
                    tiko_RefreshDocumentList
                    tiko_UpdateWindowTitle
                    tiko_SetStatus("Saved " & selectedFile)

                    If tiko_AfterSaveAction = TIKO_AFTER_SAVE_BUILD Then
                        tiko_BuildCurrentDocument(0)
                    Elseif tiko_AfterSaveAction = TIKO_AFTER_SAVE_RUN Then
                        tiko_BuildCurrentDocument(-1)
                    Elseif tiko_AfterSaveAction = TIKO_AFTER_SAVE_SAVE_ALL Then
                        tiko_AfterSaveAction = TIKO_AFTER_SAVE_NONE
                        tiko_ContinueSaveAll(tiko_SaveAllNextDocument)
                        Return
                    End If
                Else
                    tiko_SetStatus(errorText)
                    saveAllStatus = errorText
                End If
            End If
        End If
        If afterSaveAction = TIKO_AFTER_SAVE_SAVE_ALL Then
            tiko_SaveAllPending = 0
            If tiko_SaveAllOriginalActive >= 0 AndAlso _
               tiko_SaveAllOriginalActive < tiko_DocumentCount AndAlso _
               tiko_ActiveDocument <> tiko_SaveAllOriginalActive Then _
                tiko_DisplayDocument(tiko_SaveAllOriginalActive)
            If saveAllStatus = "" Then saveAllStatus = "Save All canceled"
            tiko_SetStatus(saveAllStatus)
        End If
        tiko_AfterSaveAction = TIKO_AFTER_SAVE_NONE

    Case TIKO_DIALOG_PROJECT_OPEN
        tiko_ActiveDialogKind = TIKO_DIALOG_NONE
        If dialogResult > 0 AndAlso selectedFile <> "" Then _
            tiko_LoadProject(selectedFile)

    Case TIKO_DIALOG_PROJECT_SAVE
        tiko_ActiveDialogKind = TIKO_DIALOG_NONE
        If dialogResult > 0 AndAlso selectedFile <> "" Then _
            tiko_SaveProjectFile(selectedFile)

    Case TIKO_DIALOG_CONFIRM
        tiko_ActiveDialogKind = TIKO_DIALOG_NONE
        If dialogResult > 0 Then tiko_CloseAfterConfirmation
        tiko_ConfirmAction = TIKO_CONFIRM_NONE
    End Select

End Sub

' -------------------------------------------------------------------------
' Compiler and run commands
' -------------------------------------------------------------------------

Private Sub tiko_RequestBuild(ByVal runAfterBuild As Integer)

    If tiko_ActiveDocument < 0 OrElse _
       tiko_ActiveDocument >= tiko_DocumentCount Then Exit Sub

    tiko_CaptureActiveDocument
    If tiko_Documents(tiko_ActiveDocument).path = "" Then
        tiko_OpenSaveDialog( _
            IIf(runAfterBuild <> 0, TIKO_AFTER_SAVE_RUN, TIKO_AFTER_SAVE_BUILD) _
        )
        Return
    End If

    If tiko_Documents(tiko_ActiveDocument).dirty <> 0 Then
        tiko_SaveCurrentDocument
        If tiko_Documents(tiko_ActiveDocument).dirty <> 0 Then Return
    End If

    tiko_BuildCurrentDocument(runAfterBuild)

End Sub


Private Sub tiko_BuildCurrentDocument(ByVal runAfterBuild As Integer)

    Dim As Integer commandResult
    Dim As Integer ignoredLineEnding
    Dim As Integer ignoredUtf8Bom
    Dim As String compilerPath
    Dim As String errorText
    Dim As String logPath
    Dim As String outputPath
    Dim As String quotedCompiler
    Dim As String quotedLog
    Dim As String quotedOutput
    Dim As String quotedSource
    Dim As String shellCommand
    Dim As String sourcePath
    Dim As String statusText

    If tiko_ActiveDocument < 0 OrElse _
       tiko_ActiveDocument >= tiko_DocumentCount Then Exit Sub
    sourcePath = tiko_Documents(tiko_ActiveDocument).path
    If sourcePath = "" Then
        tiko_SetStatus("Save the source file before building")
        Return
    End If

    compilerPath = Environ("TIKO_FBC")
    If compilerPath = "" Then compilerPath = "fbc"
    logPath = tiko_MakeTemporaryPath("log")
    If logPath = "" Then
        tiko_SetStatus("Could not create a temporary build log")
        Return
    End If

    outputPath = sourcePath
    If LCase(Right(outputPath, 4)) = ".bas" Then _
        outputPath = Left(outputPath, Len(outputPath) - 4)
#If Defined(__FB_WIN32__)
    outputPath &= "_tiko.exe"
#Else
    outputPath &= "_tiko"
    If Instr(outputPath, "/") = 0 Then outputPath = "./" & outputPath
#EndIf

    quotedCompiler = tiko_QuoteShellArgument(compilerPath)
    quotedSource = tiko_QuoteShellArgument(sourcePath)
    quotedOutput = tiko_QuoteShellArgument(outputPath)
    quotedLog = tiko_QuoteShellArgument(logPath)
    If quotedCompiler = "" OrElse quotedSource = "" OrElse _
       quotedOutput = "" OrElse quotedLog = "" Then
        tiko_SetStatus("A source or output path contains unsupported shell characters")
        Return
    End If

    shellCommand = quotedCompiler & " -x " & quotedOutput & " " & _
        quotedSource & " > " & quotedLog & " 2>&1"
    tiko_SetOutput("Building " & sourcePath & Chr(10) & shellCommand)
    tiko_SetStatus("Building with " & compilerPath)
    commandResult = Shell(shellCommand)
    errorText = ""
    tiko_ReadFile( _
        logPath, errorText, statusText, ignoredUtf8Bom, ignoredLineEnding _
    )
    If Len(errorText) > TIKO_MAX_OUTPUT_BYTES Then _
        errorText = Left(errorText, TIKO_MAX_OUTPUT_BYTES) & _
            Chr(10) & "... output truncated ..."
    Kill logPath

    If commandResult = 0 Then
        If errorText = "" Then errorText = "Build succeeded."
        tiko_SetStatus("Build succeeded: " & outputPath)
        If runAfterBuild <> 0 Then
            Dim As String runLogPath = tiko_MakeTemporaryPath("runlog")
            Dim As String quotedRunLog = tiko_QuoteShellArgument(runLogPath)
            Dim As String quotedProgram = tiko_QuoteShellArgument(outputPath)

            If runLogPath = "" OrElse quotedRunLog = "" OrElse _
               quotedProgram = "" Then
                tiko_SetOutput(errorText & Chr(10) & _
                    "Could not prepare a temporary run log.")
                tiko_SetStatus("Build succeeded; could not prepare to run")
                Return
            End If

            tiko_SetOutput(errorText & Chr(10) & "Running " & outputPath)
            commandResult = Shell( _
                quotedProgram & " > " & quotedRunLog & " 2>&1" _
            )
            statusText = ""
            tiko_ReadFile( _
                runLogPath, statusText, errorText, _
                ignoredUtf8Bom, ignoredLineEnding _
            )
            If Len(statusText) > TIKO_MAX_OUTPUT_BYTES Then _
                statusText = Left(statusText, TIKO_MAX_OUTPUT_BYTES) & _
                    Chr(10) & "... output truncated ..."
            Kill runLogPath
            If errorText <> "" Then statusText = errorText
            If statusText = "" Then _
                statusText = "Program finished with exit code " & commandResult
            tiko_SetOutput(statusText)
            tiko_SetStatus("Run finished with exit code " & commandResult)
        Else
            tiko_SetOutput(errorText)
        End If
    Else
        If errorText = "" Then _
            errorText = "Compiler command failed with exit code " & commandResult
        tiko_SetOutput(errorText)
        tiko_SetStatus("Build failed with exit code " & commandResult)
    End If

End Sub

' -------------------------------------------------------------------------
' Search, document selection, and close handling
' -------------------------------------------------------------------------

Private Sub tiko_FindNext()

    Dim As Integer foundPosition
    Dim As Integer startPosition
    Dim As String searchText
    Dim As String comparisonText
    Dim As String comparisonNeedle
    Dim As TextBoxData Ptr editorData

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 OrElse _
       tiko_FindBox = 0 OrElse tiko_FindBox->data = 0 Then Exit Sub

    searchText = Cast(TextBoxData Ptr, tiko_FindBox->data)->text
    If searchText = "" Then
        tiko_SetStatus("Type text in Find before searching")
        Return
    End If

    editorData = Cast(TextBoxData Ptr, tiko_Editor->data)
    comparisonText = UCase(editorData->text)
    comparisonNeedle = UCase(searchText)
    startPosition = editorData->cursor_pos + 1
    If searchText <> tiko_LastFindText Then startPosition = 1
    foundPosition = Instr(startPosition, comparisonText, comparisonNeedle)
    If foundPosition = 0 AndAlso startPosition > 1 Then _
        foundPosition = Instr(1, comparisonText, comparisonNeedle)

    tiko_LastFindText = searchText
    If foundPosition = 0 Then
        tiko_SetStatus("Not found: " & searchText)
        Return
    End If

    editorData->sel_start = foundPosition - 1
    editorData->sel_end = foundPosition - 1 + Len(searchText)
    editorData->selection_anchor = editorData->sel_start
    editorData->cursor_pos = editorData->sel_end
    editorData->viewport_dirty = -1
    editorData->active = -1
    gui_SetFocus(tiko_Editor)
    tiko_SetStatus("Found: " & searchText)

End Sub


Private Sub tiko_FindPrevious()

    Dim As Integer foundPosition
    Dim As Integer startPosition
    Dim As String searchText
    Dim As String comparisonText
    Dim As String comparisonNeedle
    Dim As TextBoxData Ptr editorData

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 OrElse _
       tiko_FindBox = 0 OrElse tiko_FindBox->data = 0 Then Exit Sub
    searchText = Cast(TextBoxData Ptr, tiko_FindBox->data)->text
    If searchText = "" Then
        tiko_SetStatus("Type text in Find before searching")
        Return
    End If

    editorData = Cast(TextBoxData Ptr, tiko_Editor->data)
    comparisonText = UCase(editorData->text)
    comparisonNeedle = UCase(searchText)
    startPosition = editorData->sel_start
    If editorData->sel_start = editorData->sel_end Then _
        startPosition = editorData->cursor_pos
    If searchText <> tiko_LastFindText Then startPosition = Len(editorData->text)
    If startPosition > Len(editorData->text) - Len(searchText) + 1 Then _
        startPosition = Len(editorData->text) - Len(searchText) + 1

    For scanPosition As Integer = startPosition To 1 Step -1
        If Mid(comparisonText, scanPosition, Len(searchText)) = comparisonNeedle Then
            foundPosition = scanPosition
            Exit For
        End If
    Next scanPosition
    If foundPosition = 0 Then
        For scanPosition As Integer = Len(editorData->text) - _
            Len(searchText) + 1 To startPosition + 1 Step -1
            If Mid(comparisonText, scanPosition, Len(searchText)) = comparisonNeedle Then
                foundPosition = scanPosition
                Exit For
            End If
        Next scanPosition
    End If

    tiko_LastFindText = searchText
    If foundPosition = 0 Then
        tiko_SetStatus("Not found: " & searchText)
        Return
    End If

    editorData->sel_start = foundPosition - 1
    editorData->sel_end = foundPosition - 1 + Len(searchText)
    editorData->selection_anchor = editorData->sel_start
    editorData->cursor_pos = editorData->sel_start
    editorData->viewport_dirty = -1
    editorData->active = -1
    gui_SetFocus(tiko_Editor)
    tiko_SetStatus("Found: " & searchText)

End Sub


Private Sub tiko_ProcessDocumentSelection()

    Dim As Integer selectedIndex

    If tiko_FileList = 0 Then Exit Sub
    selectedIndex = listbox_GetSelectedIndex(tiko_FileList)
    If selectedIndex < 0 OrElse selectedIndex >= tiko_DocumentCount Then Exit Sub
    If selectedIndex = tiko_ActiveDocument Then Exit Sub

    tiko_ActivateDocument(selectedIndex)

End Sub


Private Sub tiko_RequestCloseDocument()

    Dim As Integer dialogHeight = 150
    Dim As Integer dialogWidth = 420
    Dim As Integer screenHeight
    Dim As Integer screenWidth

    If tiko_ActiveDocument < 0 OrElse _
       tiko_ActiveDocument >= tiko_DocumentCount Then Return
    tiko_CaptureActiveDocument

    If tiko_Documents(tiko_ActiveDocument).dirty = 0 Then
        tiko_RemoveDocument(tiko_ActiveDocument)
        Return
    End If

    If tiko_ActiveDialog <> 0 Then Return
    backend_GetSize screenWidth, screenHeight
    tiko_ConfirmAction = TIKO_CONFIRM_CLOSE_DOCUMENT
    tiko_PendingDocument = tiko_ActiveDocument
    tiko_ActiveDialog = confirmdialog_Create( _
        "tiko_close_confirm", "Unsaved source", _
        "Discard changes to " & tiko_Documents(tiko_ActiveDocument).title & "?", _
        (screenWidth - dialogWidth) \ 2, _
        (screenHeight - dialogHeight) \ 2, "Discard" _
    )
    If tiko_ActiveDialog <> 0 Then
        tiko_ActiveDialogKind = TIKO_DIALOG_CONFIRM
        gui_AddWidget(tiko_ActiveDialog)
    End If

End Sub


Private Sub tiko_RequestExit()

    Dim As Integer dialogHeight = 150
    Dim As Integer dialogWidth = 420
    Dim As Integer screenHeight
    Dim As Integer screenWidth

    tiko_CaptureActiveDocument
    For documentIndex As Integer = 0 To tiko_DocumentCount - 1
        If tiko_Documents(documentIndex).dirty <> 0 Then
            If tiko_ActiveDialog <> 0 Then Return
            backend_GetSize screenWidth, screenHeight
            tiko_ConfirmAction = TIKO_CONFIRM_EXIT
            tiko_ActiveDialog = confirmdialog_Create( _
                "tiko_exit_confirm", "Unsaved source", _
                "Discard all unsaved document changes and exit?", _
                (screenWidth - dialogWidth) \ 2, _
                (screenHeight - dialogHeight) \ 2, "Exit" _
            )
            If tiko_ActiveDialog <> 0 Then
                tiko_ActiveDialogKind = TIKO_DIALOG_CONFIRM
                gui_AddWidget(tiko_ActiveDialog)
            End If
            Return
        End If
    Next documentIndex

    tiko_ExitRequested = -1

End Sub


Private Sub tiko_CloseAfterConfirmation()

    Select Case tiko_ConfirmAction
    Case TIKO_CONFIRM_CLOSE_DOCUMENT
        tiko_RemoveDocument(tiko_PendingDocument)
    Case TIKO_CONFIRM_CLOSE_ALL
        tiko_CloseAllTabs
    Case TIKO_CONFIRM_EXIT
        tiko_ExitRequested = -1
    End Select

End Sub

' -------------------------------------------------------------------------
' Keyboard commands
' -------------------------------------------------------------------------

#include once "tiko_native_ui.bi"

Private Function tiko_KeyJustPressed(ByVal keyCode As Integer) As Integer

    Dim As Integer isDown

    If keyCode < 0 OrElse keyCode > 511 Then Return 0
    If input_KeyPressEvent(keyCode) <> 0 Then
        tiko_KeyHeld(keyCode) = -1
        Return -1
    End If
    isDown = input_KeyPressed(keyCode)
    If isDown <> 0 AndAlso tiko_KeyHeld(keyCode) = 0 Then
        tiko_KeyHeld(keyCode) = -1
        Return -1
    End If
    If isDown = 0 Then tiko_KeyHeld(keyCode) = 0
    Return 0

End Function


Private Sub tiko_ProcessHotkeys()

    Dim As Integer controlDown = input_KeyPressed(FB.SC_CONTROL)
    Dim As Integer shiftDown = IIf( _
        input_KeyPressed(FB.SC_LSHIFT) <> 0 OrElse _
        input_KeyPressed(FB.SC_RSHIFT) <> 0, -1, 0 _
    )
    Dim As Integer altDown = input_KeyPressed(FB.SC_ALT)
    Dim As Integer keyN = tiko_KeyJustPressed(FB.SC_N)
    Dim As Integer keyO = tiko_KeyJustPressed(FB.SC_O)
    Dim As Integer keyE = tiko_KeyJustPressed(FB.SC_E)
    Dim As Integer keyS = tiko_KeyJustPressed(FB.SC_S)
    Dim As Integer keyW = tiko_KeyJustPressed(FB.SC_W)
    Dim As Integer keyF = tiko_KeyJustPressed(FB.SC_F)
    Dim As Integer keyB = tiko_KeyJustPressed(FB.SC_B)
    Dim As Integer keyV = tiko_KeyJustPressed(FB.SC_V)
    Dim As Integer keyP = tiko_KeyJustPressed(FB.SC_P)
    Dim As Integer keyC = tiko_KeyJustPressed(FB.SC_C)
    Dim As Integer keyD = tiko_KeyJustPressed(FB.SC_D)
    Dim As Integer keyY = tiko_KeyJustPressed(FB.SC_Y)
    Dim As Integer keyL = tiko_KeyJustPressed(FB.SC_L)
    Dim As Integer keyG = tiko_KeyJustPressed(FB.SC_G)
    Dim As Integer keyH = tiko_KeyJustPressed(FB.SC_H)
    Dim As Integer keyZ = tiko_KeyJustPressed(FB.SC_Z)
    Dim As Integer keyF2 = tiko_KeyJustPressed(FB.SC_F2)
    Dim As Integer keyF3 = tiko_KeyJustPressed(FB.SC_F3)
    Dim As Integer keyF4 = tiko_KeyJustPressed(FB.SC_F4)
    Dim As Integer keyF5 = tiko_KeyJustPressed(FB.SC_F5)
    Dim As Integer keyF6 = tiko_KeyJustPressed(FB.SC_F6)
    Dim As Integer keyF9 = tiko_KeyJustPressed(FB.SC_F9)
    Dim As Integer keyF10 = tiko_KeyJustPressed(FB.SC_F10)
    Dim As Integer keyF11 = tiko_KeyJustPressed(FB.SC_F11)
    Dim As Integer keyF12 = tiko_KeyJustPressed(FB.SC_F12)
    Dim As Integer keyPageUp = tiko_KeyJustPressed(FB.SC_PAGEUP)
    Dim As Integer keyPageDown = tiko_KeyJustPressed(FB.SC_PAGEDOWN)
    Dim As Integer keyTab = tiko_KeyJustPressed(FB.SC_TAB)
    Dim As Integer keyUp = tiko_KeyJustPressed(FB.SC_UP)
    Dim As Integer keyDown = tiko_KeyJustPressed(FB.SC_DOWN)
    Dim As Integer keyLeft = tiko_KeyJustPressed(FB.SC_LEFT)
    Dim As Integer keyRight = tiko_KeyJustPressed(FB.SC_RIGHT)
    Dim As Integer keyEnter = tiko_KeyJustPressed(FB.SC_ENTER)
    Dim As Integer keyEscape = tiko_KeyJustPressed(FB.SC_ESCAPE)
    Dim As Integer requestedMenu = -1

    If altDown <> 0 AndAlso controlDown = 0 Then
        If keyF <> 0 Then requestedMenu = 0
        If keyE <> 0 Then requestedMenu = 1
        If keyS <> 0 Then requestedMenu = 2
        If keyV <> 0 Then requestedMenu = 3
        If keyP <> 0 Then requestedMenu = 4
        If keyC <> 0 Then requestedMenu = 5
        If keyD <> 0 Then requestedMenu = 6
        If keyH <> 0 Then requestedMenu = 7
        If keyF4 <> 0 Then
            tiko_RequestExit
            Return
        End If
        If requestedMenu >= 0 Then
            tiko_ShowMenu(requestedMenu, tiko_MenuLeft(requestedMenu))
            If tiko_PopupMenu <> 0 AndAlso tiko_PopupMenu->data <> 0 Then _
                Cast(MenuData Ptr, tiko_PopupMenu->data)->selected = _
                    tiko_FirstMenuItem()
            gui_SetFocus(0)
        End If
    End If

    If tiko_ActiveMenuIndex >= 0 AndAlso gui_IsModalOpen() = 0 Then
        If keyEscape <> 0 Then
            tiko_CloseMenu
            gui_SetFocus(tiko_Editor)
        Elseif keyLeft <> 0 OrElse keyRight <> 0 Then
            If keyLeft <> 0 Then
                requestedMenu = tiko_ActiveMenuIndex - 1
                If requestedMenu < 0 Then requestedMenu = TIKO_MENU_COUNT - 1
            Else
                requestedMenu = tiko_ActiveMenuIndex + 1
                If requestedMenu >= TIKO_MENU_COUNT Then requestedMenu = 0
            End If
            tiko_ShowMenu(requestedMenu, tiko_MenuLeft(requestedMenu))
            If tiko_PopupMenu <> 0 AndAlso tiko_PopupMenu->data <> 0 Then _
                Cast(MenuData Ptr, tiko_PopupMenu->data)->selected = _
                    tiko_FirstMenuItem()
        Elseif keyUp <> 0 Then
            tiko_MoveMenuSelection(-1)
        Elseif keyDown <> 0 Then
            tiko_MoveMenuSelection(1)
        Elseif keyEnter <> 0 Then
            If tiko_PopupMenu <> 0 AndAlso tiko_PopupMenu->data <> 0 Then
                Dim As MenuData Ptr menuData = _
                    Cast(MenuData Ptr, tiko_PopupMenu->data)
                If menuData->selected < 0 Then _
                    menuData->selected = tiko_FirstMenuItem()
                If menuData->selected >= 0 Then _
                    tiko_OnMenuSelection(0, menuData->selected)
            End If
        End If
        Return
    End If

    If controlDown <> 0 Then
        If shiftDown <> 0 Then
            If keyS <> 0 Then tiko_SaveAllDocuments
            If keyZ <> 0 Then
                If textbox_Redo(tiko_Editor) = 0 Then tiko_SetStatus("Nothing to redo")
            End If
            If keyF <> 0 Then tiko_ShowFindInFiles
            If keyW <> 0 Then tiko_CloseAllDocuments
            If keyF2 <> 0 Then tiko_ClearBookmarks
            If keyTab <> 0 Then tiko_ActivateRelativeDocument(-1)
        Else
            If keyN <> 0 Then tiko_CreateDocument
            If keyO <> 0 Then tiko_OpenFileDialog
            If keyS <> 0 Then tiko_SaveCurrentDocument
            If keyW <> 0 Then tiko_RequestCloseDocument
            If keyF <> 0 Then tiko_ShowFind
            If keyB <> 0 Then
                tiko_ShowSidePanel = IIf(tiko_ShowSidePanel <> 0, 0, -1)
                tiko_ResizeWidgets
            End If
            If keyD <> 0 Then tiko_DuplicateLineOrSelection
            If keyY <> 0 Then tiko_DeleteCurrentLine
            If keyL <> 0 Then tiko_SelectCurrentLine
            If keyG <> 0 Then tiko_ShowGotoLine
            If keyH <> 0 Then tiko_ShowReplace
            If keyZ <> 0 Then
                If textbox_Undo(tiko_Editor) = 0 Then tiko_SetStatus("Nothing to undo")
            End If
            If keyF2 <> 0 Then tiko_ToggleBookmark
            If keyF4 <> 0 Then
                tiko_SidePanelPage = 0
                tiko_ShowSidePanel = -1
                tiko_ResizeWidgets
            End If
            If keyF9 <> 0 Then
                tiko_ShowOutput = IIf(tiko_ShowOutput <> 0, 0, -1)
                tiko_ResizeWidgets
            End If
            If keyTab <> 0 Then tiko_ActivateRelativeDocument(1)
            If keyPageDown <> 0 Then tiko_GotoNextFunction
            If keyPageUp <> 0 Then tiko_GotoPreviousFunction
        End If
    Else
        If altDown <> 0 Then
            If keyUp <> 0 Then tiko_MoveCurrentLine(-1)
            If keyDown <> 0 Then tiko_MoveCurrentLine(1)
        End If

        If keyF2 <> 0 Then
            If shiftDown <> 0 Then
                tiko_MoveToBookmark(-1)
            Else
                tiko_MoveToBookmark(1)
            End If
        End If
        If keyF3 <> 0 Then
            If shiftDown <> 0 Then tiko_FindPrevious Else tiko_FindNext
        End If
        If keyF4 <> 0 Then
            tiko_SidePanelPage = IIf(shiftDown <> 0, 2, 1)
            tiko_ShowSidePanel = -1
            tiko_ResizeWidgets
        End If
        If keyF5 <> 0 Then tiko_RequestBuild(-1)
        If keyF12 <> 0 Then
            If shiftDown <> 0 Then
                tiko_GotoLastPosition
            Else
                tiko_GotoDefinition
            End If
        End If
        If keyF6 <> 0 Then tiko_SetStatus("Debugger support is not ported yet")
        If keyF10 <> 0 Then tiko_SetStatus("Debugger support is not ported yet")
        If keyF11 <> 0 Then tiko_SetStatus("Debugger support is not ported yet")
    End If

    If controlDown <> 0 AndAlso shiftDown = 0 Then
        If keyF5 <> 0 Then tiko_RequestBuild(0)
    End If

    If keyEnter <> 0 AndAlso tiko_ShowFindBar <> 0 Then
        Dim As Integer findHasFocus
        If tiko_FindBox <> 0 AndAlso tiko_FindBox->data <> 0 Then _
            findHasFocus = Cast(TextBoxData Ptr, tiko_FindBox->data)->active
        If tiko_ReplaceBox <> 0 AndAlso tiko_ReplaceBox->data <> 0 AndAlso _
           Cast(TextBoxData Ptr, tiko_ReplaceBox->data)->active <> 0 Then _
            findHasFocus = -1
        If findHasFocus <> 0 Then
            Select Case tiko_FindMode
            Case TIKO_FIND_MODE_FIND, TIKO_FIND_MODE_REPLACE
                If shiftDown <> 0 Then tiko_FindPrevious Else tiko_FindNext
            Case TIKO_FIND_MODE_GOTO
                tiko_GotoLine
            Case TIKO_FIND_MODE_FILES
                tiko_FindInFiles
            End Select
            Return
        End If
    End If

    If keyEscape <> 0 AndAlso gui_IsModalOpen() = 0 Then
        If tiko_ShowFindBar <> 0 Then
            tiko_HideFindBar
        Elseif tiko_ActiveMenuIndex >= 0 Then
            tiko_CloseMenu
        Else
            tiko_RequestExit
        End If
    End If

End Sub

' -------------------------------------------------------------------------
' Main interface and frame loop
' -------------------------------------------------------------------------

Private Sub tiko_InitInterface()

    gui_Init

    tiko_ShowSidePanel = -1
    tiko_ShowOutput = 0
    tiko_ShowFindBar = 0
    tiko_SidePanelPage = 0
    tiko_ActiveMenuIndex = -1
    tiko_StatusText = "Ready"

    tiko_MenuBar = tiko_CreateVisualWidget( _
        "tiko_menu_bar", 0, 0, TIKO_INITIAL_WIDTH, TIKO_MENU_HEIGHT, _
        TIKO_VISUAL_MENU_BAR _
    )
    gui_AddWidget(tiko_MenuBar)

    tiko_Panel = tiko_CreateVisualWidget( _
        "tiko_main_panel", 0, TIKO_MENU_HEIGHT, TIKO_SIDEBAR_WIDTH, _
        TIKO_INITIAL_HEIGHT - TIKO_MENU_HEIGHT - TIKO_STATUS_HEIGHT, _
        TIKO_VISUAL_PANEL _
    )
    gui_AddWidget(tiko_Panel)

    tiko_TabStrip = tiko_CreateVisualWidget( _
        "tiko_document_tabs", TIKO_SIDEBAR_WIDTH, _
        TIKO_MENU_HEIGHT + TIKO_PANEL_TOOLBAR_HEIGHT, _
        TIKO_INITIAL_WIDTH - TIKO_SIDEBAR_WIDTH, TIKO_TAB_HEIGHT, _
        TIKO_VISUAL_TAB_STRIP _
    )
    gui_AddWidget(tiko_TabStrip)

    tiko_FileList = listbox_Create("tiko_file_list", 10, 68, 210, 708)
    tiko_FileList->visible = 0
    gui_AddWidget(tiko_FileList)

    tiko_Editor = textbox_Create( _
        "tiko_source_editor", "", TIKO_SIDEBAR_WIDTH, _
        TIKO_MENU_HEIGHT + TIKO_PANEL_TOOLBAR_HEIGHT + TIKO_TAB_HEIGHT, _
        TIKO_INITIAL_WIDTH - TIKO_SIDEBAR_WIDTH, 600, -1, 0, _
        TEXTBOX_SCROLLBAR_AUTO _
    )
    textbox_SetIndentBehavior(tiko_Editor, 4, -1)
    textbox_SetLineNumberGutter( _
        tiko_Editor, 48, RGB(135, 148, 164), RGB(37, 42, 50) _
    )
    textbox_SetTextColorHandler(tiko_Editor, @tiko_TextColor)
    textbox_SetMaxTextBytes(tiko_Editor, TIKO_MAX_SOURCE_BYTES)
    gui_AddWidget(tiko_Editor)

    tiko_Output = textbox_Create( _
        "tiko_build_output", "", TIKO_SIDEBAR_WIDTH, 640, _
        TIKO_INITIAL_WIDTH - TIKO_SIDEBAR_WIDTH, 132, -1, -1, _
        TEXTBOX_SCROLLBAR_AUTO _
    )
    textbox_SetReadOnly(tiko_Output, -1)
    textbox_SetMaxTextBytes(tiko_Output, TIKO_MAX_OUTPUT_BYTES)
    textbox_SetLineNumberGutter(tiko_Output, 0, 0, 0)
    tiko_Output->visible = 0
    gui_AddWidget(tiko_Output)

    tiko_OutputHeading = tiko_CreateVisualWidget( _
        "tiko_output_heading", TIKO_SIDEBAR_WIDTH, 640, _
        TIKO_INITIAL_WIDTH - TIKO_SIDEBAR_WIDTH, _
        TIKO_OUTPUT_HEADER_HEIGHT, TIKO_VISUAL_OUTPUT_TABS _
    )
    If tiko_OutputHeading = 0 Then End 1
    tiko_OutputHeading->visible = 0
    gui_AddWidget(tiko_OutputHeading)

    tiko_FindBar = tiko_CreateVisualWidget( _
        "tiko_find_bar", TIKO_SIDEBAR_WIDTH, 112, _
        TIKO_INITIAL_WIDTH - TIKO_SIDEBAR_WIDTH, TIKO_FIND_BAR_HEIGHT, _
        TIKO_VISUAL_FIND_BAR _
    )
    If tiko_FindBar = 0 Then End 1
    tiko_FindBar->visible = 0
    gui_AddWidget(tiko_FindBar)

    tiko_FindLabel = label_Create( _
        "tiko_find_label", "Find", TIKO_SIDEBAR_WIDTH + 12, 118, tiko_ColorText _
    )
    tiko_FindLabel->visible = 0
    gui_AddWidget(tiko_FindLabel)
    tiko_FindBox = textbox_Create( _
        "tiko_find_box", "", TIKO_SIDEBAR_WIDTH + 72, 114, 230, 28, 0, 0, _
        TEXTBOX_SCROLLBAR_NONE _
    )
    textbox_SetMaxTextBytes(tiko_FindBox, 1024)
    tiko_FindBox->visible = 0
    gui_AddWidget(tiko_FindBox)

    tiko_FindNextButton = button_Create( _
        "tiko_find_next", "Find Next", TIKO_INITIAL_WIDTH - 132, 113, 72, 30, _
        @tiko_FindBarAction _
    )
    tiko_FindNextButton->visible = 0
    gui_AddWidget(tiko_FindNextButton)

    tiko_FindPreviousButton = button_Create( _
        "tiko_find_previous", "Previous", TIKO_INITIAL_WIDTH - 210, _
        113, 72, 30, @tiko_FindPreviousAction _
    )
    tiko_FindPreviousButton->visible = 0
    gui_AddWidget(tiko_FindPreviousButton)

    tiko_ReplaceBox = textbox_Create( _
        "tiko_replace_box", "", TIKO_SIDEBAR_WIDTH + 72, 146, 230, 28, _
        0, 0, TEXTBOX_SCROLLBAR_NONE _
    )
    textbox_SetMaxTextBytes(tiko_ReplaceBox, 1024)
    tiko_ReplaceBox->visible = 0
    gui_AddWidget(tiko_ReplaceBox)

    tiko_ReplaceButton = button_Create( _
        "tiko_replace", "Replace", TIKO_INITIAL_WIDTH - 210, 146, 72, 30, _
        @tiko_ReplaceAction _
    )
    tiko_ReplaceButton->visible = 0
    gui_AddWidget(tiko_ReplaceButton)

    tiko_ReplaceAllButton = button_Create( _
        "tiko_replace_all", "Replace All", TIKO_INITIAL_WIDTH - 132, _
        146, 90, 30, @tiko_ReplaceAllAction _
    )
    tiko_ReplaceAllButton->visible = 0
    gui_AddWidget(tiko_ReplaceAllButton)

    tiko_FindCloseButton = button_Create( _
        "tiko_find_close", "x", TIKO_INITIAL_WIDTH - 36, 113, 28, 30, _
        @tiko_HideFindAction _
    )
    tiko_FindCloseButton->visible = 0
    gui_AddWidget(tiko_FindCloseButton)

    tiko_StatusBar = tiko_CreateVisualWidget( _
        "tiko_status_bar", 0, 776, TIKO_INITIAL_WIDTH, TIKO_STATUS_HEIGHT, _
        TIKO_VISUAL_STATUS_BAR _
    )
    tiko_Status = tiko_StatusBar
    gui_AddWidget(tiko_StatusBar)

    tiko_PopupMenu = menu_Create("tiko_popup_menu", 0, TIKO_MENU_HEIGHT)
    tiko_PopupMenu->pointer_global = 0
    menu_SetItemHeight(tiko_PopupMenu, 18)
    menu_SetSelectionHandler(tiko_PopupMenu, @tiko_OnMenuSelection, 0)
    gui_AddWidget(tiko_PopupMenu)

    tiko_CreateDocument
    tiko_ResizeWidgets
    tiko_SetStatus("Ready")

End Sub


Private Sub tiko_RenderFrame()

    Dim As Integer screenHeight
    Dim As Integer screenWidth

    backend_GetSize screenWidth, screenHeight
    backend_Clear(tiko_ColorWindow)
    gui_RenderAll
    backend_Flip

End Sub


backend_Init _
    TIKO_INITIAL_WIDTH, TIKO_INITIAL_HEIGHT, 0, _
    BACKEND_WINDOW_RESIZABLE, BACKEND_COLOR_DEPTH_TRUE_COLOR

theme_InitClassic
current_theme.bg_face = tiko_ColorToolbar
current_theme.bg_dark = RGB(15, 18, 23)
current_theme.bg_light = tiko_ColorEditor
current_theme.text_main = tiko_ColorText
current_theme.text_select = RGB(255, 255, 255)
current_theme.bg_select = RGB(57, 95, 145)
current_theme.win_border = RGB(15, 18, 23)
WindowTitle "Tiko Editor"
tiko_InitInterface

If Command(1) <> "" Then
    If LCase(Right(Command(1), 5)) = ".tiko" Then
        tiko_LoadProject(Command(1))
    Else
        tiko_OpenDocument(Command(1))
    End If
End If

Do
    tiko_ResizeWidgets
    gui_UpdateAll
    If backend_WindowCloseRequested() <> 0 Then tiko_RequestExit
    tiko_DismissMenuOnOutsideClick
    tiko_CaptureActiveDocument
    tiko_ProcessDocumentSelection
    tiko_ProcessDialog
    tiko_ProcessHotkeys
    tiko_UpdateWindowTitle
    tiko_RenderFrame

    If tiko_ExitRequested <> 0 Then Exit Do
    Sleep 10, 1
Loop

gui_ResetForTest
backend_Exit

/' end of tiko.bas '/
