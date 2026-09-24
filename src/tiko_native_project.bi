/'
    Project: Tiko Editor Native Project Support
    -------------------------------------------

    File: tiko_native_project.bi

    Purpose:

        Load and save Tiko project files without the Windows-only config
        stream classes used by the original application.

    Responsibilities:

        - read and write the UTF-16 project format used by Tiko
        - resolve project-relative source paths on the current platform
        - restore project file types, open tabs, caret positions, and bookmarks
        - keep project membership separate from which source tabs are visible

    This file intentionally does NOT contain:

        - generic file dialogs or widget behavior
        - compiler invocation or debugger support
        - Windows API, Afx, Scintilla, or COM dependencies
'/ 

#pragma once

Type TikoProjectEntry
    As String filename
    As String file_type
    As String bookmarks
    As Integer tab_visible
    As Integer first_line
    As Integer position
End Type


Private Function tiko_ProjectByteAt( _
    ByRef byteText As Const String, ByVal byteIndex As Integer _
) As Integer

    If byteIndex < 0 OrElse byteIndex >= Len(byteText) Then Return 0
    Return Asc(Mid(byteText, byteIndex + 1, 1))

End Function


Private Sub tiko_AppendUtf8(ByRef targetText As String, ByVal codePoint As ULong)

    If codePoint <= &H7F Then
        targetText &= Chr(codePoint)
    Elseif codePoint <= &H7FF Then
        targetText &= Chr(&HC0 Or (codePoint Shr 6))
        targetText &= Chr(&H80 Or (codePoint And &H3F))
    Elseif codePoint <= &HFFFF Then
        If codePoint >= &HD800 AndAlso codePoint <= &HDFFF Then _
            codePoint = &HFFFD
        targetText &= Chr(&HE0 Or (codePoint Shr 12))
        targetText &= Chr(&H80 Or ((codePoint Shr 6) And &H3F))
        targetText &= Chr(&H80 Or (codePoint And &H3F))
    Elseif codePoint <= &H10FFFF Then
        targetText &= Chr(&HF0 Or (codePoint Shr 18))
        targetText &= Chr(&H80 Or ((codePoint Shr 12) And &H3F))
        targetText &= Chr(&H80 Or ((codePoint Shr 6) And &H3F))
        targetText &= Chr(&H80 Or (codePoint And &H3F))
    Else
        tiko_AppendUtf8(targetText, &HFFFD)
    End If

End Sub


Private Function tiko_DecodeUtf8At( _
    ByRef sourceText As Const String, ByRef bytePosition As Integer _
) As ULong

    Dim As Integer byteCount
    Dim As ULong firstByte
    Dim As ULong codePoint
    Dim As ULong nextByte

    If bytePosition < 0 OrElse bytePosition >= Len(sourceText) Then Return 0
    firstByte = tiko_ProjectByteAt(sourceText, bytePosition)

    If firstByte < &H80 Then
        bytePosition += 1
        Return firstByte
    Elseif (firstByte And &HE0) = &HC0 Then
        byteCount = 2
        codePoint = firstByte And &H1F
    Elseif (firstByte And &HF0) = &HE0 Then
        byteCount = 3
        codePoint = firstByte And &HF

    Elseif (firstByte And &HF8) = &HF0 Then
        byteCount = 4
        codePoint = firstByte And &H7
    Else
        bytePosition += 1
        Return &HFFFD
    End If

    If bytePosition + byteCount > Len(sourceText) Then
        bytePosition += 1
        Return &HFFFD
    End If

    For continuationIndex As Integer = 1 To byteCount - 1
        nextByte = tiko_ProjectByteAt(sourceText, bytePosition + continuationIndex)
        If (nextByte And &HC0) <> &H80 Then
            bytePosition += 1
            Return &HFFFD
        End If
        codePoint = (codePoint Shl 6) Or (nextByte And &H3F)
    Next continuationIndex

    Select Case byteCount
    Case 2
        If codePoint < &H80 Then codePoint = &HFFFD
    Case 3
        If codePoint < &H800 Then codePoint = &HFFFD
    Case 4
        If codePoint < &H10000 Then codePoint = &HFFFD
    End Select

    If codePoint > &H10FFFF OrElse _
       (codePoint >= &HD800 AndAlso codePoint <= &HDFFF) Then _
        codePoint = &HFFFD

    bytePosition += byteCount
    Return codePoint

End Function


Private Function tiko_DecodeProjectBytes( _
    ByRef rawText As Const String, ByRef projectText As String _
) As Integer

    Dim As Integer bigEndian
    Dim As Integer bytePosition
    Dim As Integer firstCodeUnit
    Dim As Integer secondCodeUnit
    Dim As Integer codeUnit
    Dim As ULong codePoint

    projectText = ""
    If Len(rawText) < 2 Then Return 0

    If tiko_ProjectByteAt(rawText, 0) = &HFF AndAlso _
       tiko_ProjectByteAt(rawText, 1) = &HFE Then
        bigEndian = 0
        bytePosition = 2
    Elseif tiko_ProjectByteAt(rawText, 0) = &HFE AndAlso _
           tiko_ProjectByteAt(rawText, 1) = &HFF Then
        bigEndian = -1
        bytePosition = 2
    Else
        If Len(rawText) >= 3 AndAlso _
           tiko_ProjectByteAt(rawText, 0) = &HEF AndAlso _
           tiko_ProjectByteAt(rawText, 1) = &HBB AndAlso _
           tiko_ProjectByteAt(rawText, 2) = &HBF Then
            projectText = Mid(rawText, 4)
        Else
            projectText = rawText
        End If
        projectText = tiko_NormalizeLineEndings(projectText, bigEndian)
        Return -1
    End If

    If (Len(rawText) - bytePosition) Mod 2 <> 0 Then Return 0

    While bytePosition < Len(rawText)
        firstCodeUnit = tiko_ProjectByteAt(rawText, bytePosition)
        secondCodeUnit = tiko_ProjectByteAt(rawText, bytePosition + 1)
        If bigEndian <> 0 Then
            codeUnit = firstCodeUnit * 256 + secondCodeUnit
        Else
            codeUnit = secondCodeUnit * 256 + firstCodeUnit
        End If
        bytePosition += 2

        If codeUnit >= &HD800 AndAlso codeUnit <= &HDBFF Then
            If bytePosition >= Len(rawText) Then Return 0
            firstCodeUnit = tiko_ProjectByteAt(rawText, bytePosition)
            secondCodeUnit = tiko_ProjectByteAt(rawText, bytePosition + 1)
            If bigEndian <> 0 Then
                secondCodeUnit = firstCodeUnit * 256 + secondCodeUnit
            Else
                secondCodeUnit = secondCodeUnit * 256 + firstCodeUnit
            End If
            If secondCodeUnit < &HDC00 OrElse secondCodeUnit > &HDFFF Then _
                Return 0
            bytePosition += 2
            codePoint = &H10000 + _
                ((codeUnit - &HD800) * &H400) + (secondCodeUnit - &HDC00)
        Elseif codeUnit >= &HDC00 AndAlso codeUnit <= &HDFFF Then
            Return 0
        Else
            codePoint = codeUnit
        End If

        tiko_AppendUtf8(projectText, codePoint)
    Wend

    projectText = tiko_NormalizeLineEndings(projectText, bigEndian)
    If Len(projectText) > TIKO_MAX_PROJECT_BYTES Then Return 0
    Return -1

End Function


Private Function tiko_EncodeProjectBytes(ByRef projectText As Const String) As String

    Dim As Integer bytePosition
    Dim As ULong codePoint
    Dim As ULong highSurrogate
    Dim As ULong lowSurrogate
    Dim As String rawText = Chr(&HFF) & Chr(&HFE)

    bytePosition = 0
    While bytePosition < Len(projectText)
        codePoint = tiko_DecodeUtf8At(projectText, bytePosition)
        If codePoint <= &HFFFF Then
            rawText &= Chr(codePoint And &HFF)
            rawText &= Chr((codePoint Shr 8) And &HFF)
        Else
            codePoint -= &H10000
            highSurrogate = &HD800 Or (codePoint Shr 10)
            lowSurrogate = &HDC00 Or (codePoint And &H3FF)
            rawText &= Chr(highSurrogate And &HFF)
            rawText &= Chr((highSurrogate Shr 8) And &HFF)
            rawText &= Chr(lowSurrogate And &HFF)
            rawText &= Chr((lowSurrogate Shr 8) And &HFF)
        End If
    Wend

    Return rawText

End Function


Private Function tiko_ProjectDirectory(ByVal filename As String) As String

    Dim As Integer lastSeparator

    For charPosition As Integer = 1 To Len(filename)
        If Mid(filename, charPosition, 1) = "/" OrElse _
           Mid(filename, charPosition, 1) = Chr(92) Then _
            lastSeparator = charPosition
    Next charPosition

    If lastSeparator = 0 Then Return "."
    If lastSeparator = 1 Then Return Left(filename, 1)
    Return Left(filename, lastSeparator - 1)

End Function


Private Function tiko_NormalizeProjectPath(ByVal filename As String) As String

    Dim As String normalizedPath

    For charPosition As Integer = 1 To Len(filename)
        If Mid(filename, charPosition, 1) = Chr(92) Then
            normalizedPath &= "/"
        Else
            normalizedPath &= Mid(filename, charPosition, 1)
        End If
    Next charPosition

    Return normalizedPath

End Function


Private Function tiko_ResolveProjectPath( _
    ByVal projectFilename As String, ByVal sourceFilename As String _
) As String

    Dim As String normalizedSource = tiko_NormalizeProjectPath(sourceFilename)
    Dim As String projectDirectory = tiko_NormalizeProjectPath( _
        tiko_ProjectDirectory(projectFilename) _
    )

    If normalizedSource = "" Then Return ""
    If Left(normalizedSource, 1) = "/" Then Return normalizedSource
    If Len(normalizedSource) >= 2 AndAlso _
       Mid(normalizedSource, 2, 1) = ":" Then
#If Defined(__FB_WIN32__)
        Return normalizedSource
#Else
        Return ""
#EndIf
    End If

    While Left(normalizedSource, 2) = "./"
        normalizedSource = Mid(normalizedSource, 3)
    Wend
    If projectDirectory = "." Then Return "./" & normalizedSource
    If Right(projectDirectory, 1) = "/" Then _
        Return projectDirectory & normalizedSource
    Return projectDirectory & "/" & normalizedSource

End Function


Function tiko_InferFileType(ByVal filename As String) As Integer

    Dim As String extension = LCase(Right(filename, Len(filename) - _
        InStrRev(filename, ".") + 1))

    Select Case extension
    Case "bas", "inc": Return 3
    Case "rc": Return 4
    Case "bi": Return 5
    Case Else: Return 3
    End Select

End Function


Private Function tiko_LineOffsetForIndex( _
    ByRef sourceText As Const String, ByVal lineIndex As Integer _
) As Integer

    Dim As Integer currentLine

    If lineIndex <= 0 Then Return 0
    For charPosition As Integer = 0 To Len(sourceText) - 1
        If sourceText[charPosition] = 10 Then
            currentLine += 1
            If currentLine >= lineIndex Then Return charPosition + 1
        End If
    Next charPosition

    Return Len(sourceText)

End Function


Private Sub tiko_LoadProjectBookmarks( _
    ByVal documentIndex As Integer, ByVal bookmarkText As String _
)

    Dim As Integer tokenStart = 1

    If documentIndex < 0 OrElse documentIndex >= tiko_DocumentCount Then Exit Sub
    tiko_Documents(documentIndex).bookmark_count = 0

    While tokenStart <= Len(bookmarkText) AndAlso _
          tiko_Documents(documentIndex).bookmark_count < TIKO_MAX_BOOKMARKS
        Dim As Integer separatorPosition = InStr(tokenStart, bookmarkText, ",")
        Dim As String tokenText
        If separatorPosition = 0 Then
            tokenText = Mid(bookmarkText, tokenStart)
            tokenStart = Len(bookmarkText) + 1
        Else
            tokenText = Mid(bookmarkText, tokenStart, separatorPosition - tokenStart)
            tokenStart = separatorPosition + 1
        End If

        If Trim(tokenText) <> "" Then
            Dim As Integer lineNumber = Val(Trim(tokenText))
            If lineNumber >= 0 Then
                Dim As Integer bookmarkIndex = _
                    tiko_Documents(documentIndex).bookmark_count
                tiko_Documents(documentIndex).bookmark_offsets(bookmarkIndex) = _
                    tiko_LineOffsetForIndex( _
                        tiko_Documents(documentIndex).text, lineNumber _
                    )
                tiko_Documents(documentIndex).bookmark_count += 1
            End If
        End If
    Wend

End Sub


Private Function tiko_ProjectRelativePath( _
    ByVal projectFilename As String, ByVal sourceFilename As String _
) As String

    Dim As String projectDirectory = tiko_NormalizeProjectPath( _
        tiko_ProjectDirectory(projectFilename) _
    )
    Dim As String normalizedSource = tiko_NormalizeProjectPath(sourceFilename)
    Dim As String prefix

    If projectDirectory = "." Then
        prefix = "./"
    Elseif Right(projectDirectory, 1) = "/" Then
        prefix = projectDirectory
    Else
        prefix = projectDirectory & "/"
    End If

    If LCase(Left(normalizedSource, Len(prefix))) = LCase(prefix) Then
        normalizedSource = Mid(normalizedSource, Len(prefix) + 1)
    End If

    If Left(normalizedSource, 1) <> "/" AndAlso _
       (Len(normalizedSource) < 2 OrElse Mid(normalizedSource, 2, 1) <> ":") Then
        Dim As String projectPath
        For charPosition As Integer = 1 To Len(normalizedSource)
            If Mid(normalizedSource, charPosition, 1) = "/" Then
                projectPath &= Chr(92)
            Else
                projectPath &= Mid(normalizedSource, charPosition, 1)
            End If
        Next charPosition
        Return ".\" & projectPath
    End If

    Return normalizedSource

End Function


Private Sub tiko_ClearProjectEntry(ByRef entry As TikoProjectEntry)

    entry.filename = ""
    entry.file_type = ""
    entry.bookmarks = ""
    entry.tab_visible = 0
    entry.first_line = 0
    entry.position = 0

End Sub


Private Sub tiko_AddProjectDocument( _
    ByRef entry As TikoProjectEntry, ByVal projectFilename As String _
)

    Dim As Integer fileLineEnding
    Dim As Integer fileHasUtf8Bom
    Dim As String errorText
    Dim As String fileText
    Dim As String sourcePath = tiko_ResolveProjectPath( _
        projectFilename, entry.filename _
    )
    Dim As Integer documentIndex = tiko_DocumentCount

    If documentIndex >= TIKO_MAX_DOCUMENTS Then Exit Sub
    If entry.filename = "" Then Exit Sub

    With tiko_Documents(documentIndex)
        .path = sourcePath
        .title = tiko_GetBaseName(entry.filename)
        .text = ""
        .saved_text = ""
        .cursor_pos = 0
        .vertical_scroll = 0
        .dirty = 0
        .utf8_bom = 0
        .line_ending = 0
        .file_type = Val(entry.file_type)
        .tab_visible = entry.tab_visible
        .bookmark_count = 0
        .is_missing = 0
    End With

    If sourcePath = "" OrElse tiko_ReadFile( _
        sourcePath, fileText, errorText, fileHasUtf8Bom, fileLineEnding _
    ) = 0 Then
        tiko_Documents(documentIndex).is_missing = -1
        tiko_Documents(documentIndex).tab_visible = 0
        tiko_ProjectMissingCount += 1
    Else
        tiko_Documents(documentIndex).text = fileText
        tiko_Documents(documentIndex).saved_text = fileText
        tiko_Documents(documentIndex).utf8_bom = fileHasUtf8Bom
        tiko_Documents(documentIndex).line_ending = fileLineEnding
        If tiko_Documents(documentIndex).file_type <= 0 Then _
            tiko_Documents(documentIndex).file_type = _
                tiko_InferFileType(sourcePath)
        tiko_Documents(documentIndex).cursor_pos = entry.position
        tiko_Documents(documentIndex).vertical_scroll = entry.first_line
        tiko_LoadProjectBookmarks(documentIndex, entry.bookmarks)
    End If

    tiko_DocumentCount += 1

End Sub


Function tiko_LoadProjectFile(ByVal filename As String) As Integer

    Dim As Integer fileNumber
    Dim As Integer lineStart
    Dim As Integer lineEnd
    Dim As Integer activeTab = 0
    Dim As Integer currentTab
    Dim As Integer entryCount
    Dim As Integer projectMissingCount
    Dim As Integer projectLength
    Dim As Integer rawLength
    Dim As LongInt fileLength
    Dim As String rawText
    Dim As String projectText
    Dim As String projectBuild
    Dim As String projectOther32
    Dim As String projectOther64
    Dim As String projectCommandLine
    Dim As String projectNotes
    Dim As String keyText
    Dim As String valueText
    Dim As String lineText
    Dim As TikoProjectEntry entries(0 To TIKO_MAX_DOCUMENTS - 1)
    Dim As TikoProjectEntry currentEntry
    Dim As Integer hasCurrentFile
    Dim As Integer readingNotes
    Dim As Integer haveNoteLine

    If filename = "" Then Return 0
    fileNumber = FreeFile
    If Open(filename For Binary Access Read As #fileNumber) <> 0 Then
        tiko_SetStatus("Could not open project " & filename)
        Return 0
    End If

    fileLength = LOF(fileNumber)
    If fileLength < 2 OrElse fileLength > TIKO_MAX_PROJECT_BYTES Then
        Close #fileNumber
        tiko_SetStatus("Project file is empty or exceeds the 4 MiB limit")
        Return 0
    End If

    rawText = String(CInt(fileLength), Chr(0))
    If Get(fileNumber, , rawText) <> 0 Then
        Close #fileNumber
        tiko_SetStatus("Could not read project " & filename)
        Return 0
    End If
    Close #fileNumber

    If tiko_DecodeProjectBytes(rawText, projectText) = 0 Then
        tiko_SetStatus("Project file has an invalid text encoding")
        Return 0
    End If

    projectLength = Len(projectText)
    lineStart = 1
    While lineStart <= projectLength + 1
        lineEnd = InStr(lineStart, projectText, Chr(10))
        If lineEnd = 0 Then
            lineText = Mid(projectText, lineStart)
            lineStart = projectLength + 2
        Else
            lineText = Mid(projectText, lineStart, lineEnd - lineStart)
            lineStart = lineEnd + 1
        End If

        If lineText = "NOTES-START" Then
            readingNotes = -1
            haveNoteLine = 0
            Continue While
        Elseif lineText = "NOTES-END" Then
            readingNotes = 0
            Continue While
        End If
        If readingNotes <> 0 Then
            If haveNoteLine <> 0 Then projectNotes &= Chr(10)
            projectNotes &= lineText
            haveNoteLine = -1
            Continue While
        End If
        If lineText = "" OrElse Left(lineText, 1) = "'" OrElse _
           Left(lineText, 1) = "[" Then Continue While

        Dim As Integer equalsPosition = InStr(lineText, "=")
        If equalsPosition <= 1 Then Continue While
        keyText = Left(lineText, equalsPosition - 1)
        valueText = Mid(lineText, equalsPosition + 1)

        Select Case keyText
        Case "ProjectBuild": projectBuild = valueText
        Case "ProjectOther32": projectOther32 = valueText
        Case "ProjectOther64": projectOther64 = valueText
        Case "ProjectCommandLine": projectCommandLine = valueText
        Case "ActiveTab": activeTab = Val(valueText)
        Case "File"
            tiko_ClearProjectEntry(currentEntry)
            currentEntry.filename = valueText
            hasCurrentFile = -1
        Case "FileType": currentEntry.file_type = valueText
        Case "TabIndex": currentEntry.tab_visible = IIf(Val(valueText) <> 0, -1, 0)
        Case "FirstLine": currentEntry.first_line = Val(valueText)
        Case "Position": currentEntry.position = Val(valueText)
        Case "Bookmarks": currentEntry.bookmarks = valueText
        Case "FileEnd"
            If hasCurrentFile <> 0 Then
                If entryCount >= TIKO_MAX_DOCUMENTS Then
                    tiko_SetStatus("Project contains more than 256 source files")
                    Return 0
                End If
                entries(entryCount) = currentEntry
                entryCount += 1
                tiko_ClearProjectEntry(currentEntry)
                hasCurrentFile = 0
            End If
        End Select
    Wend

    If hasCurrentFile <> 0 Then
        tiko_SetStatus("Project file ended inside a source file entry")
        Return 0
    End If

    tiko_DocumentCount = 0
    tiko_ActiveDocument = -1
    tiko_ProjectPath = filename
    tiko_ProjectName = tiko_GetBaseName(filename)
    tiko_ProjectBuildId = projectBuild
    tiko_ProjectOther32 = projectOther32
    tiko_ProjectOther64 = projectOther64
    tiko_ProjectCommandLine = projectCommandLine
    tiko_ProjectNotes = projectNotes
    tiko_ProjectMissingCount = 0
    tiko_ProjectActive = -1
    tiko_ExplorerScroll = 0

    For entryIndex As Integer = 0 To entryCount - 1
        tiko_AddProjectDocument(entries(entryIndex), filename)
    Next entryIndex
    projectMissingCount = tiko_ProjectMissingCount

    For categoryIndex As Integer = 0 To 4
        tiko_CategoryExpanded(categoryIndex) = 0
    Next categoryIndex
    tiko_CategoryExpanded(0) = -1
    tiko_CategoryExpanded(1) = -1
    tiko_CategoryExpanded(4) = -1

    currentTab = 0
    For documentIndex As Integer = 0 To tiko_DocumentCount - 1
        If tiko_Documents(documentIndex).tab_visible = 0 Then Continue For
        If currentTab = activeTab Then
            tiko_ActiveDocument = documentIndex
            Exit For
        End If
        currentTab += 1
    Next documentIndex

    If tiko_ActiveDocument < 0 Then
        For documentIndex As Integer = 0 To tiko_DocumentCount - 1
            If tiko_Documents(documentIndex).is_missing <> 0 Then Continue For
            tiko_Documents(documentIndex).tab_visible = -1
            tiko_ActiveDocument = documentIndex
            Exit For
        Next documentIndex
    End If

    If tiko_DocumentCount = 0 Then
        tiko_CreateDocument
        tiko_Documents(0).file_type = 1
        tiko_Documents(0).tab_visible = -1
    Elseif tiko_ActiveDocument < 0 Then
        tiko_ActiveDocument = 0
        tiko_Documents(0).tab_visible = -1
    End If

    tiko_DisplayDocument(tiko_ActiveDocument)
    tiko_RefreshDocumentList
    tiko_UpdateWindowTitle
    If tiko_OutputPage = 4 Then tiko_ShowOutputPage(4)
    tiko_ResizeWidgets
    If projectMissingCount > 0 Then
        tiko_SetStatus("Project opened with " & _
            LTrim(Str(projectMissingCount)) & " missing or unreadable file(s)")
    Else
        tiko_SetStatus("Opened project " & tiko_ProjectName)
    End If

    Return -1

End Function


Private Function tiko_ProjectBookmarksText( _
    ByVal documentIndex As Integer _
) As String

    Dim As Integer lineNumber
    Dim As Integer lineStart
    Dim As String bookmarkText
    Dim As String sourceText = tiko_Documents(documentIndex).text

    For bookmarkIndex As Integer = 0 To _
        tiko_Documents(documentIndex).bookmark_count - 1
        If bookmarkIndex > 0 Then bookmarkText &= ","
        lineStart = tiko_Documents(documentIndex).bookmark_offsets(bookmarkIndex)
        lineNumber = tiko_LineNumberAt(sourceText, lineStart) - 1
        If lineNumber < 0 Then lineNumber = 0
        bookmarkText &= LTrim(Str(lineNumber))
    Next bookmarkIndex

    Return bookmarkText

End Function


Function tiko_SaveProjectFile(ByVal filename As String) As Integer

    Dim As Integer activeTab = 0
    Dim As Integer fileType
    Dim As String errorText
    Dim As String projectText
    Dim As String relativePath
    Dim As String sourceLineEnding = Chr(13) & Chr(10)

    If filename = "" Then Return 0
    tiko_CaptureActiveDocument
    tiko_CaptureOutputNotes

    If tiko_ActiveDocument >= 0 AndAlso _
       tiko_ActiveDocument < tiko_DocumentCount AndAlso _
       tiko_Documents(tiko_ActiveDocument).tab_visible <> 0 Then
        For documentIndex As Integer = 0 To tiko_ActiveDocument - 1
            If tiko_Documents(documentIndex).tab_visible <> 0 Then activeTab += 1
        Next documentIndex
    End If

    projectText = "' PROJECT FILE" & sourceLineEnding
    projectText &= "ProjectBuild=" & tiko_ProjectBuildId & sourceLineEnding
    projectText &= "ProjectOther32=" & tiko_ProjectOther32 & sourceLineEnding
    projectText &= "ProjectOther64=" & tiko_ProjectOther64 & sourceLineEnding
    projectText &= "ProjectCommandLine=" & tiko_ProjectCommandLine & sourceLineEnding
    projectText &= "ActiveTab=" & LTrim(Str(activeTab)) & sourceLineEnding

    For documentIndex As Integer = 0 To tiko_DocumentCount - 1
        If tiko_Documents(documentIndex).path = "" Then Continue For
        relativePath = tiko_ProjectRelativePath( _
            filename, tiko_Documents(documentIndex).path _
        )
        fileType = tiko_Documents(documentIndex).file_type
        If fileType < 1 OrElse fileType > 5 Then _
            fileType = tiko_InferFileType(tiko_Documents(documentIndex).path)
        projectText &= "File=" & relativePath & sourceLineEnding
        projectText &= "FileType=" & LTrim(Str(fileType)) & sourceLineEnding
        projectText &= "TabIndex=" & _
            IIf(tiko_Documents(documentIndex).tab_visible <> 0, "-1", "0") & _
            sourceLineEnding
        projectText &= "Bookmarks=" & _
            tiko_ProjectBookmarksText(documentIndex) & sourceLineEnding
        projectText &= "BreakPoints=" & sourceLineEnding
        projectText &= "FoldPoints=" & sourceLineEnding
        projectText &= "FirstLine=" & _
            LTrim(Str(tiko_Documents(documentIndex).vertical_scroll)) & _
            sourceLineEnding
        projectText &= "Position=" & _
            LTrim(Str(tiko_Documents(documentIndex).cursor_pos)) & _
            sourceLineEnding
        projectText &= "FirstLine1=0" & sourceLineEnding
        projectText &= "Position1=0" & sourceLineEnding
        projectText &= "SplitMode=0" & sourceLineEnding
        projectText &= "SplitPositionX=0" & sourceLineEnding
        projectText &= "SplitPositionY=0" & sourceLineEnding
        projectText &= "FocusEdit=0" & sourceLineEnding
        projectText &= "FileEnd=[-]" & sourceLineEnding
        If Len(projectText) > TIKO_MAX_PROJECT_BYTES Then
            tiko_SetStatus("Project is larger than the 4 MiB project limit")
            Return 0
        End If
    Next documentIndex

    projectText &= sourceLineEnding & "[Notes]" & sourceLineEnding
    projectText &= "NOTES-START" & sourceLineEnding
    projectText &= tiko_ProjectNotes & sourceLineEnding
    projectText &= "NOTES-END" & sourceLineEnding
    If Len(projectText) > TIKO_MAX_PROJECT_BYTES Then
        tiko_SetStatus("Project is larger than the 4 MiB project limit")
        Return 0
    End If
    If tiko_SaveFile(filename, tiko_EncodeProjectBytes(projectText), errorText) = 0 Then
        tiko_SetStatus(errorText)
        Return 0
    End If

    tiko_ProjectPath = filename
    tiko_ProjectName = tiko_GetBaseName(filename)
    tiko_ProjectActive = -1
    tiko_ProjectMissingCount = 0
    tiko_UpdateWindowTitle
    tiko_SetStatus("Saved project " & tiko_ProjectName)
    Return -1

End Function


Private Sub tiko_OpenProjectSaveDialog()

    Dim As Integer dialogHeight = 340
    Dim As Integer dialogWidth = 400
    Dim As Integer screenHeight
    Dim As Integer screenWidth
    Dim As String suggestedName = "untitled.tiko"

    If tiko_ProjectPath <> "" Then _
        suggestedName = tiko_GetBaseName(tiko_ProjectPath)
    backend_GetSize screenWidth, screenHeight
    tiko_ActiveDialog = filedialog_CreateSaveAtPath( _
        "tiko_project_save_dialog", _
        (screenWidth - dialogWidth) \ 2, _
        (screenHeight - dialogHeight) \ 2, CurDir, suggestedName _
    )
    If tiko_ActiveDialog <> 0 Then
        tiko_ActiveDialogKind = TIKO_DIALOG_PROJECT_SAVE
        gui_AddWidget(tiko_ActiveDialog)
    End If

End Sub


Sub tiko_OpenProjectDialog()

    Dim As Integer dialogHeight = 340
    Dim As Integer dialogWidth = 400
    Dim As Integer screenHeight
    Dim As Integer screenWidth

    If tiko_ActiveDialog <> 0 Then Exit Sub
    backend_GetSize screenWidth, screenHeight
    tiko_ActiveDialog = filedialog_CreateAtPath( _
        "tiko_project_open_dialog", _
        (screenWidth - dialogWidth) \ 2, _
        (screenHeight - dialogHeight) \ 2, CurDir _
    )
    If tiko_ActiveDialog <> 0 Then
        tiko_ActiveDialogKind = TIKO_DIALOG_PROJECT_OPEN
        gui_AddWidget(tiko_ActiveDialog)
    End If

End Sub


Sub tiko_SaveProject()

    If tiko_ProjectActive = 0 Then
        tiko_SetStatus("There is no active project")
        Return
    End If
    If tiko_ProjectPath = "" Then
        tiko_SaveProjectAs
        Return
    End If
    tiko_SaveProjectFile(tiko_ProjectPath)

End Sub


Sub tiko_SaveProjectAs()

    If tiko_ActiveDialog <> 0 Then Return
    tiko_OpenProjectSaveDialog

End Sub


Sub tiko_LoadProject(ByVal filename As String)

    tiko_CaptureActiveDocument
    For documentIndex As Integer = 0 To tiko_DocumentCount - 1
        If tiko_Documents(documentIndex).dirty <> 0 Then
            tiko_SetStatus("Save or close modified files before opening a project")
            Return
        End If
    Next documentIndex

    tiko_LoadProjectFile(filename)

End Sub


Sub tiko_NewProject()

    tiko_CaptureOutputNotes
    tiko_CaptureActiveDocument
    For documentIndex As Integer = 0 To tiko_DocumentCount - 1
        If tiko_Documents(documentIndex).dirty <> 0 Then
            tiko_SetStatus("Save or close modified files before creating a project")
            Return
        End If
    Next documentIndex

    tiko_DocumentCount = 0
    tiko_ActiveDocument = -1
    tiko_ProjectPath = ""
    tiko_ProjectName = ""
    tiko_ProjectBuildId = ""
    tiko_ProjectOther32 = ""
    tiko_ProjectOther64 = ""
    tiko_ProjectCommandLine = ""
    tiko_ProjectNotes = ""
    tiko_ProjectMissingCount = 0
    tiko_ProjectActive = -1
    tiko_CreateDocument
    tiko_Documents(0).file_type = 1
    tiko_SaveProjectAs
    If tiko_OutputPage = 4 Then tiko_ShowOutputPage(4)

End Sub


Sub tiko_CloseProject()

    tiko_CaptureOutputNotes
    tiko_CaptureActiveDocument
    For documentIndex As Integer = 0 To tiko_DocumentCount - 1
        If tiko_Documents(documentIndex).dirty <> 0 Then
            tiko_SetStatus("Save or close modified files before closing a project")
            Return
        End If
    Next documentIndex

    tiko_DocumentCount = 0
    tiko_ActiveDocument = -1
    tiko_ProjectActive = 0
    tiko_ProjectPath = ""
    tiko_ProjectName = ""
    tiko_ProjectBuildId = ""
    tiko_ProjectOther32 = ""
    tiko_ProjectOther64 = ""
    tiko_ProjectCommandLine = ""
    tiko_ProjectNotes = ""
    tiko_ProjectMissingCount = 0
    tiko_CreateDocument
    If tiko_OutputPage = 4 Then tiko_ShowOutputPage(4)
    tiko_SetStatus("Project closed")

End Sub

' end of tiko_native_project.bi
