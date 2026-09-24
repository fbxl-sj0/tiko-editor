/'
    Project: Tiko Editor Native Edit Commands
    ------------------------------------------

    File: tiko_native_edit.bi

    Purpose:

        Implement Tiko editing commands on the native omaGUI text buffer.

    Responsibilities:

        - provide selection-aware clipboard and source editing operations
        - use the textbox's bounded undo history for compound edits
        - track source bookmarks as document text changes

    This file intentionally does NOT contain:

        - generic textbox behavior owned by omaGUI
        - file persistence or compiler invocation
        - platform-specific clipboard implementations
'/

' -------------------------------------------------------------------------
' Position and line helpers
' -------------------------------------------------------------------------

Private Function tiko_ClampEditPosition( _
    ByRef textValue As Const String, ByVal position As Integer _
) As Integer

    If position < 0 Then Return 0
    If position > Len(textValue) Then Return Len(textValue)
    Return position

End Function


Private Function tiko_LineStartAt( _
    ByRef textValue As Const String, ByVal position As Integer _
) As Integer

    position = tiko_ClampEditPosition(textValue, position)
    For scanPosition As Integer = position To 1 Step -1
        If Mid(textValue, scanPosition, 1) = Chr(10) Then _
            Return scanPosition
    Next scanPosition
    Return 0

End Function


Private Sub tiko_GetLineRange( _
    ByRef textValue As Const String, ByVal lineStart As Integer, _
    ByRef lineEnd As Integer, ByRef lineAfter As Integer _
)

    Dim As Integer newlinePosition = Instr(lineStart + 1, textValue, Chr(10))
    If newlinePosition = 0 Then
        lineEnd = Len(textValue)
        lineAfter = lineEnd
    Else
        lineEnd = newlinePosition - 1
        lineAfter = newlinePosition
    End If

End Sub


Private Sub tiko_CurrentLineRange( _
    ByRef textData As TextBoxData, _
    ByRef lineStart As Integer, ByRef lineEnd As Integer, _
    ByRef lineAfter As Integer _
)

    lineStart = tiko_LineStartAt(textData.text, textData.cursor_pos)
    tiko_GetLineRange textData.text, lineStart, lineEnd, lineAfter

End Sub


Private Function tiko_ApplyEditorText( _
    ByVal replacementText As String, _
    ByVal selectionStart As Integer, ByVal selectionEnd As Integer, _
    ByVal cursorPosition As Integer _
) As Integer

    Dim As TextBoxData Ptr textData
    Dim As Integer oldHorizontalScroll
    Dim As Integer oldVerticalScroll

    tiko_ApplyEditorText = 0
    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Return 0
    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    If textData->read_only <> 0 Then
        tiko_SetStatus("The current document is read only")
        Return 0
    End If
    If Len(replacementText) > TIKO_MAX_SOURCE_BYTES Then
        tiko_SetStatus("Edit exceeds the 2 MiB source limit")
        Return 0
    End If
    If replacementText = textData->text Then Return 0

    oldHorizontalScroll = textData->scroll_offset
    oldVerticalScroll = textData->v_scroll
    If textbox_SetText(tiko_Editor, replacementText, 0) = 0 Then
        tiko_SetStatus("Could not update the source buffer")
        Return 0
    End If

    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    textData->sel_start = tiko_ClampEditPosition(textData->text, selectionStart)
    textData->sel_end = tiko_ClampEditPosition(textData->text, selectionEnd)
    If textData->sel_end < textData->sel_start Then _
        Swap textData->sel_start, textData->sel_end
    textData->selection_anchor = textData->sel_start
    textData->cursor_pos = tiko_ClampEditPosition( _
        textData->text, cursorPosition _
    )
    textData->scroll_offset = oldHorizontalScroll
    textData->v_scroll = oldVerticalScroll
    textData->viewport_dirty = -1
    textData->active = -1
    gui_SetFocus(tiko_Editor)
    tiko_CaptureActiveDocument
    tiko_ApplyEditorText = -1

End Function


Private Function tiko_LineNumberAt( _
    ByRef textValue As Const String, ByVal position As Integer _
) As Integer

    Dim As Integer lineNumber = 1

    position = tiko_ClampEditPosition(textValue, position)
    For scanPosition As Integer = 1 To position
        If Mid(textValue, scanPosition, 1) = Chr(10) Then _
            lineNumber += 1
    Next scanPosition
    Return lineNumber

End Function

' -------------------------------------------------------------------------
' Clipboard and edit commands
' -------------------------------------------------------------------------

Sub tiko_CopySelection()

    Dim As TextBoxData Ptr textData
    Dim As Integer selectionStart
    Dim As Integer selectionEnd

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Exit Sub
    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    selectionStart = tiko_ClampEditPosition(textData->text, textData->sel_start)
    selectionEnd = tiko_ClampEditPosition(textData->text, textData->sel_end)
    If selectionEnd < selectionStart Then Swap selectionStart, selectionEnd
    If selectionEnd <= selectionStart Then
        tiko_SetStatus("Select source text before copying")
        Exit Sub
    End If

    clipboard_SetText(Mid( _
        textData->text, selectionStart + 1, selectionEnd - selectionStart _
    ))
    tiko_SetStatus("Copied selection")

End Sub


Sub tiko_CutSelection()

    Dim As TextBoxData Ptr textData
    Dim As Integer selectionStart
    Dim As Integer selectionEnd
    Dim As String replacementText

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Exit Sub
    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    selectionStart = tiko_ClampEditPosition(textData->text, textData->sel_start)
    selectionEnd = tiko_ClampEditPosition(textData->text, textData->sel_end)
    If selectionEnd < selectionStart Then Swap selectionStart, selectionEnd
    If selectionEnd <= selectionStart Then
        tiko_SetStatus("Select source text before cutting")
        Exit Sub
    End If
    clipboard_SetText(Mid( _
        textData->text, selectionStart + 1, selectionEnd - selectionStart _
    ))
    replacementText = Left(textData->text, selectionStart) & _
        Mid(textData->text, selectionEnd + 1)
    If tiko_ApplyEditorText( _
        replacementText, selectionStart, selectionStart, selectionStart _
    ) <> 0 Then tiko_SetStatus("Cut selection")

End Sub


Sub tiko_PasteSelection()

    Dim As TextBoxData Ptr textData
    Dim As Integer selectionStart
    Dim As Integer selectionEnd
    Dim As Integer cursorPosition
    Dim As String clipboardText
    Dim As String replacementText

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Exit Sub
    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    clipboardText = clipboard_GetText()
    If clipboardText = "" Then
        tiko_SetStatus("The clipboard has no text")
        Exit Sub
    End If
    selectionStart = tiko_ClampEditPosition(textData->text, textData->sel_start)
    selectionEnd = tiko_ClampEditPosition(textData->text, textData->sel_end)
    If selectionEnd < selectionStart Then Swap selectionStart, selectionEnd
    If Len(textData->text) - (selectionEnd - selectionStart) + _
       Len(clipboardText) > TIKO_MAX_SOURCE_BYTES Then
        tiko_SetStatus("Clipboard text exceeds the 2 MiB source limit")
        Exit Sub
    End If

    cursorPosition = selectionStart + Len(clipboardText)
    replacementText = Left(textData->text, selectionStart) & _
        clipboardText & Mid(textData->text, selectionEnd + 1)
    If tiko_ApplyEditorText( _
        replacementText, cursorPosition, cursorPosition, cursorPosition _
    ) <> 0 Then tiko_SetStatus("Pasted clipboard text")

End Sub


Sub tiko_DeleteCurrentLine()

    Dim As TextBoxData Ptr textData
    Dim As Integer lineStart
    Dim As Integer lineEnd
    Dim As Integer lineAfter
    Dim As Integer deleteStart
    Dim As Integer deleteEnd
    Dim As String replacementText

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Exit Sub
    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    tiko_CurrentLineRange *textData, lineStart, lineEnd, lineAfter
    deleteStart = lineStart
    deleteEnd = lineAfter
    If deleteEnd = lineEnd AndAlso deleteStart > 0 Then deleteStart -= 1
    replacementText = Left(textData->text, deleteStart) & _
        Mid(textData->text, deleteEnd + 1)
    If tiko_ApplyEditorText( _
        replacementText, deleteStart, deleteStart, deleteStart _
    ) <> 0 Then tiko_SetStatus("Deleted current line")

End Sub


Sub tiko_DuplicateLineOrSelection()

    Dim As TextBoxData Ptr textData
    Dim As Integer selectionStart
    Dim As Integer selectionEnd
    Dim As Integer lineStart
    Dim As Integer lineEnd
    Dim As Integer lineAfter
    Dim As Integer insertPosition
    Dim As String duplicateText
    Dim As String replacementText

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Exit Sub
    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    selectionStart = tiko_ClampEditPosition(textData->text, textData->sel_start)
    selectionEnd = tiko_ClampEditPosition(textData->text, textData->sel_end)
    If selectionEnd < selectionStart Then Swap selectionStart, selectionEnd

    If selectionEnd > selectionStart Then
        duplicateText = Mid( _
            textData->text, selectionStart + 1, selectionEnd - selectionStart _
        )
        insertPosition = selectionEnd
    Else
        tiko_CurrentLineRange *textData, lineStart, lineEnd, lineAfter
        If lineAfter > lineEnd Then
            duplicateText = Mid( _
                textData->text, lineStart + 1, lineAfter - lineStart _
            )
            insertPosition = lineAfter
        Else
            duplicateText = Chr(10) & Mid( _
                textData->text, lineStart + 1, lineEnd - lineStart _
            )
            insertPosition = lineEnd
        End If
    End If

    replacementText = Left(textData->text, insertPosition) & _
        duplicateText & Mid(textData->text, insertPosition + 1)
    If tiko_ApplyEditorText( _
        replacementText, insertPosition, insertPosition + Len(duplicateText), _
        insertPosition + Len(duplicateText) _
    ) <> 0 Then tiko_SetStatus("Duplicated line or selection")

End Sub


Sub tiko_MoveCurrentLine(ByVal direction As Integer)

    Dim As TextBoxData Ptr textData
    Dim As Integer lineStart
    Dim As Integer lineEnd
    Dim As Integer lineAfter
    Dim As Integer adjacentStart
    Dim As Integer adjacentEnd
    Dim As Integer adjacentAfter
    Dim As Integer newLineStart
    Dim As Integer newCursor
    Dim As Integer cursorColumn
    Dim As String currentText
    Dim As String adjacentText
    Dim As String newSegment
    Dim As String replacementText

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Exit Sub
    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    tiko_CurrentLineRange *textData, lineStart, lineEnd, lineAfter
    cursorColumn = textData->cursor_pos - lineStart
    currentText = Mid(textData->text, lineStart + 1, lineEnd - lineStart)

    If direction < 0 Then
        If lineStart <= 0 Then Exit Sub
        adjacentStart = tiko_LineStartAt(textData->text, lineStart - 1)
        tiko_GetLineRange textData->text, adjacentStart, adjacentEnd, adjacentAfter
        adjacentText = Mid( _
            textData->text, adjacentStart + 1, adjacentEnd - adjacentStart _
        )
        newSegment = currentText & Chr(10) & adjacentText & _
            IIf(lineAfter > lineEnd, Chr(10), "")
        replacementText = Left(textData->text, adjacentStart) & _
            newSegment & Mid(textData->text, lineAfter + 1)
        newLineStart = adjacentStart
    Else
        If lineAfter >= Len(textData->text) Then Exit Sub
        adjacentStart = lineAfter
        tiko_GetLineRange textData->text, adjacentStart, adjacentEnd, adjacentAfter
        adjacentText = Mid( _
            textData->text, adjacentStart + 1, adjacentEnd - adjacentStart _
        )
        newSegment = adjacentText & Chr(10) & currentText & _
            IIf(adjacentAfter > adjacentEnd, Chr(10), "")
        replacementText = Left(textData->text, lineStart) & _
            newSegment & Mid(textData->text, adjacentAfter + 1)
        newLineStart = lineStart + Len(adjacentText) + 1
    End If

    newCursor = newLineStart + cursorColumn
    If tiko_ApplyEditorText( _
        replacementText, newCursor, newCursor, newCursor _
    ) <> 0 Then
        tiko_SetStatus(IIf(direction < 0, "Moved line up", "Moved line down"))
    End If

End Sub


Sub tiko_SelectCurrentLine()

    Dim As TextBoxData Ptr textData
    Dim As Integer lineStart
    Dim As Integer lineEnd
    Dim As Integer lineAfter

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Exit Sub
    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    tiko_CurrentLineRange *textData, lineStart, lineEnd, lineAfter
    textData->sel_start = lineStart
    textData->sel_end = lineEnd
    textData->selection_anchor = lineStart
    textData->cursor_pos = lineEnd
    textData->viewport_dirty = -1
    gui_SetFocus(tiko_Editor)

End Sub


Sub tiko_CommentSelectedLines(ByVal addComment As Integer)

    Dim As TextBoxData Ptr textData
    Dim As Integer selectionStart
    Dim As Integer selectionEnd
    Dim As Integer lineStart
    Dim As Integer firstLineStart
    Dim As Integer lastLineStart
    Dim As Integer lastLineEnd
    Dim As Integer lastLineAfter
    Dim As Integer lineEnd
    Dim As Integer lineAfter
    Dim As Integer oldPosition
    Dim As Integer totalAdded
    Dim As Integer totalRemoved
    Dim As Integer cursorPosition
    Dim As Integer firstCommentPosition
    Dim As String commentText
    Dim As String lineText
    Dim As String newText

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 OrElse _
       tiko_ActiveDocument < 0 OrElse _
       tiko_ActiveDocument >= tiko_DocumentCount Then Exit Sub
    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    selectionStart = tiko_ClampEditPosition(textData->text, textData->sel_start)
    selectionEnd = tiko_ClampEditPosition(textData->text, textData->sel_end)
    If selectionEnd < selectionStart Then Swap selectionStart, selectionEnd
    firstLineStart = tiko_LineStartAt(textData->text, selectionStart)
    lastLineStart = tiko_LineStartAt(textData->text, selectionEnd)
    If selectionEnd > selectionStart AndAlso selectionEnd > 0 AndAlso _
       Mid(textData->text, selectionEnd, 1) = Chr(10) Then _
        lastLineStart = tiko_LineStartAt(textData->text, selectionEnd - 1)
    tiko_GetLineRange textData->text, lastLineStart, lastLineEnd, lastLineAfter

    commentText = "'"
    If LCase(Right(tiko_Documents(tiko_ActiveDocument).path, 3)) = ".rc" Then _
        commentText = "//"

    oldPosition = 0
    lineStart = firstLineStart
    firstCommentPosition = -1
    Do
        tiko_GetLineRange textData->text, lineStart, lineEnd, lineAfter
        newText &= Mid(textData->text, oldPosition + 1, lineStart - oldPosition)
        lineText = Mid(textData->text, lineStart + 1, lineEnd - lineStart)

        If addComment <> 0 Then
            If Trim(lineText) <> "" Then
                If firstCommentPosition < 0 Then _
                    firstCommentPosition = lineStart + totalAdded
                newText &= commentText
                totalAdded += Len(commentText)
            End If
            newText &= lineText
        Else
            Dim As Integer firstTextPosition = 0
            While firstTextPosition < Len(lineText)
                Dim As String firstCharacter = Mid( _
                    lineText, firstTextPosition + 1, 1 _
                )
                If firstCharacter <> " " AndAlso firstCharacter <> Chr(9) Then _
                    Exit While
                firstTextPosition += 1
            Wend

            If firstTextPosition < Len(lineText) AndAlso _
               Mid(lineText, firstTextPosition + 1, Len(commentText)) = commentText Then
                newText &= Left(lineText, firstTextPosition)
                newText &= Mid( _
                    lineText, firstTextPosition + Len(commentText) + 1 _
                )
                totalRemoved += Len(commentText)
            Else
                newText &= lineText
            End If
        End If

        If lineAfter > lineEnd Then newText &= Chr(10)
        oldPosition = lineAfter
        If lineStart = lastLineStart Then Exit Do
        lineStart = lineAfter
    Loop
    newText &= Mid(textData->text, oldPosition + 1)

    If newText = textData->text Then
        tiko_SetStatus(IIf( _
            addComment <> 0, "No lines to comment", "No comments to remove" _
        ))
        Exit Sub
    End If

    cursorPosition = textData->cursor_pos + totalAdded - totalRemoved
    If selectionStart = selectionEnd AndAlso addComment <> 0 AndAlso _
       firstCommentPosition >= 0 Then _
        cursorPosition = firstCommentPosition + Len(commentText)
    If selectionStart = selectionEnd Then
        selectionStart = cursorPosition
        selectionEnd = cursorPosition
    Else
        selectionEnd += totalAdded - totalRemoved
    End If

    If tiko_ApplyEditorText( _
        newText, selectionStart, selectionEnd, cursorPosition _
    ) <> 0 Then
        tiko_SetStatus(IIf( _
            addComment <> 0, "Commented selected lines", _
            "Uncommented selected lines" _
        ))
    End If

End Sub

' -------------------------------------------------------------------------
' Bookmark state
' -------------------------------------------------------------------------

Sub tiko_AdjustBookmarks( _
    ByRef document As TikoDocument, _
    ByRef oldText As Const String, _
    ByRef newText As Const String _
)

    Dim As Integer commonPrefix = 0
    Dim As Integer commonSuffix = 0
    Dim As Integer oldChangeEnd
    Dim As Integer newChangeEnd
    Dim As Integer changeLength
    Dim As Integer bookmarkIndex

    If document.bookmark_count <= 0 Then Exit Sub

    While commonPrefix < Len(oldText) AndAlso _
          commonPrefix < Len(newText) AndAlso _
          Mid(oldText, commonPrefix + 1, 1) = Mid(newText, commonPrefix + 1, 1)
        commonPrefix += 1
    Wend
    While commonSuffix < Len(oldText) - commonPrefix AndAlso _
          commonSuffix < Len(newText) - commonPrefix AndAlso _
          Mid(oldText, Len(oldText) - commonSuffix, 1) = _
          Mid(newText, Len(newText) - commonSuffix, 1)
        commonSuffix += 1
    Wend

    oldChangeEnd = Len(oldText) - commonSuffix
    newChangeEnd = Len(newText) - commonSuffix
    changeLength = newChangeEnd - oldChangeEnd
    For bookmarkIndex = 0 To document.bookmark_count - 1
        If document.bookmark_offsets(bookmarkIndex) >= oldChangeEnd Then
            document.bookmark_offsets(bookmarkIndex) += changeLength
        Elseif document.bookmark_offsets(bookmarkIndex) > commonPrefix Then
            document.bookmark_offsets(bookmarkIndex) = commonPrefix
        End If
        document.bookmark_offsets(bookmarkIndex) = tiko_LineStartAt( _
            newText, document.bookmark_offsets(bookmarkIndex) _
        )
    Next bookmarkIndex

    For firstIndex As Integer = 0 To document.bookmark_count - 1
        For secondIndex As Integer = firstIndex + 1 To document.bookmark_count - 1
            If document.bookmark_offsets(secondIndex) < _
               document.bookmark_offsets(firstIndex) Then
                Swap document.bookmark_offsets(firstIndex), _
                    document.bookmark_offsets(secondIndex)
            End If
        Next secondIndex
    Next firstIndex

    bookmarkIndex = 0
    While bookmarkIndex < document.bookmark_count - 1
        If document.bookmark_offsets(bookmarkIndex) = _
           document.bookmark_offsets(bookmarkIndex + 1) Then
            For moveIndex As Integer = bookmarkIndex + 1 To _
                document.bookmark_count - 2
                document.bookmark_offsets(moveIndex) = _
                    document.bookmark_offsets(moveIndex + 1)
            Next moveIndex
            document.bookmark_count -= 1
        Else
            bookmarkIndex += 1
        End If
    Wend

End Sub


Sub tiko_ToggleBookmark()

    Dim As TextBoxData Ptr textData
    Dim As Integer lineStart
    Dim As Integer bookmarkIndex
    Dim As Integer moveIndex

    If tiko_ActiveDocument < 0 OrElse _
       tiko_ActiveDocument >= tiko_DocumentCount OrElse _
       tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Exit Sub
    tiko_CaptureActiveDocument
    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    lineStart = tiko_LineStartAt(textData->text, textData->cursor_pos)

    For bookmarkIndex = 0 To _
        tiko_Documents(tiko_ActiveDocument).bookmark_count - 1
        If tiko_Documents(tiko_ActiveDocument).bookmark_offsets(bookmarkIndex) = _
           lineStart Then
            For moveIndex = bookmarkIndex To _
                tiko_Documents(tiko_ActiveDocument).bookmark_count - 2
                tiko_Documents(tiko_ActiveDocument).bookmark_offsets(moveIndex) = _
                    tiko_Documents(tiko_ActiveDocument).bookmark_offsets(moveIndex + 1)
            Next moveIndex
            tiko_Documents(tiko_ActiveDocument).bookmark_count -= 1
            tiko_SetStatus("Removed bookmark from line " & _
                LTrim(Str(tiko_LineNumberAt(textData->text, lineStart))))
            Return
        End If
    Next bookmarkIndex

    If tiko_Documents(tiko_ActiveDocument).bookmark_count >= _
       TIKO_MAX_BOOKMARKS Then
        tiko_SetStatus("The document bookmark limit is 64")
        Exit Sub
    End If
    bookmarkIndex = tiko_Documents(tiko_ActiveDocument).bookmark_count
    tiko_Documents(tiko_ActiveDocument).bookmark_offsets(bookmarkIndex) = lineStart
    tiko_Documents(tiko_ActiveDocument).bookmark_count += 1

    For firstIndex As Integer = 0 To bookmarkIndex - 1
        For secondIndex As Integer = firstIndex + 1 To bookmarkIndex
            If tiko_Documents(tiko_ActiveDocument).bookmark_offsets(secondIndex) < _
               tiko_Documents(tiko_ActiveDocument).bookmark_offsets(firstIndex) Then
                Swap tiko_Documents(tiko_ActiveDocument).bookmark_offsets(firstIndex), _
                    tiko_Documents(tiko_ActiveDocument).bookmark_offsets(secondIndex)
            End If
        Next secondIndex
    Next firstIndex

    tiko_SetStatus("Added bookmark to line " & _
        LTrim(Str(tiko_LineNumberAt(textData->text, lineStart))))

End Sub


Sub tiko_GotoBookmarkByIndex(ByVal bookmarkIndex As Integer)

    Dim As TextBoxData Ptr textData
    Dim As Integer targetPosition

    If tiko_ActiveDocument < 0 OrElse _
       tiko_ActiveDocument >= tiko_DocumentCount OrElse _
       tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Exit Sub
    If bookmarkIndex < 0 OrElse bookmarkIndex >= _
       tiko_Documents(tiko_ActiveDocument).bookmark_count Then Exit Sub
    tiko_CaptureActiveDocument
    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    targetPosition = tiko_ClampEditPosition( _
        textData->text, _
        tiko_Documents(tiko_ActiveDocument).bookmark_offsets(bookmarkIndex) _
    )
    textData->cursor_pos = targetPosition
    textData->sel_start = targetPosition
    textData->sel_end = targetPosition
    textData->selection_anchor = targetPosition
    textData->viewport_dirty = -1
    textData->active = -1
    gui_SetFocus(tiko_Editor)
    tiko_SetStatus("Bookmark line " & _
        LTrim(Str(tiko_LineNumberAt(textData->text, targetPosition))))

End Sub


Sub tiko_MoveToBookmark(ByVal direction As Integer)

    Dim As TextBoxData Ptr textData
    Dim As Integer currentLineStart
    Dim As Integer chosenIndex = -1

    If tiko_ActiveDocument < 0 OrElse _
       tiko_ActiveDocument >= tiko_DocumentCount OrElse _
       tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Exit Sub
    tiko_CaptureActiveDocument
    If tiko_Documents(tiko_ActiveDocument).bookmark_count <= 0 Then
        tiko_SetStatus("No bookmarks in the current document")
        Exit Sub
    End If

    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    currentLineStart = tiko_LineStartAt(textData->text, textData->cursor_pos)
    If direction >= 0 Then
        For bookmarkIndex As Integer = 0 To _
            tiko_Documents(tiko_ActiveDocument).bookmark_count - 1
            If tiko_Documents(tiko_ActiveDocument).bookmark_offsets(bookmarkIndex) > _
               currentLineStart Then
                chosenIndex = bookmarkIndex
                Exit For
            End If
        Next bookmarkIndex
        If chosenIndex < 0 Then chosenIndex = 0
    Else
        For bookmarkIndex As Integer = _
            tiko_Documents(tiko_ActiveDocument).bookmark_count - 1 To 0 Step -1
            If tiko_Documents(tiko_ActiveDocument).bookmark_offsets(bookmarkIndex) < _
               currentLineStart Then
                chosenIndex = bookmarkIndex
                Exit For
            End If
        Next bookmarkIndex
        If chosenIndex < 0 Then _
            chosenIndex = tiko_Documents(tiko_ActiveDocument).bookmark_count - 1
    End If
    tiko_GotoBookmarkByIndex(chosenIndex)

End Sub


Sub tiko_ClearBookmarks()

    If tiko_ActiveDocument < 0 OrElse _
       tiko_ActiveDocument >= tiko_DocumentCount Then Exit Sub
    tiko_Documents(tiko_ActiveDocument).bookmark_count = 0
    tiko_SetStatus("Cleared bookmarks in the current document")

End Sub


Function tiko_BookmarkIndexAtPanelRow(ByVal localY As Integer) As Integer

    Dim As Integer rowIndex

    tiko_BookmarkIndexAtPanelRow = -1
    If tiko_SidePanelPage <> 2 OrElse localY < 88 Then Return -1
    rowIndex = (localY - 88) \ 25
    If tiko_ActiveDocument < 0 OrElse _
       tiko_ActiveDocument >= tiko_DocumentCount Then Return -1
    If rowIndex >= tiko_Documents(tiko_ActiveDocument).bookmark_count Then Return -1
    Return rowIndex

End Function


Function tiko_GetFunctionName(ByRef lineText As Const String) As String

    Dim As Integer lastWasSpace
    Dim As Integer nameStart
    Dim As Integer nameEnd
    Dim As String normalizedText
    Dim As String upperText

    For charPosition As Integer = 1 To Len(lineText)
        Dim As Integer charCode = Asc(Mid(lineText, charPosition, 1))
        If charCode = 9 OrElse charCode = 32 Then
            If Len(normalizedText) > 0 Then lastWasSpace = -1
        Else
            If lastWasSpace <> 0 Then normalizedText &= " "
            normalizedText &= Mid(lineText, charPosition, 1)
            lastWasSpace = 0
        End If
    Next charPosition

    normalizedText = Trim(normalizedText)
    If Len(normalizedText) < 4 Then Return ""
    upperText = UCase(normalizedText)

    If Left(normalizedText, 1) = "'" OrElse _
       Left(normalizedText, 2) = "/'" OrElse _
       Left(upperText, 4) = "REM " Then Return ""

    If Left(upperText, 17) = "PRIVATE FUNCTION " Then
        nameStart = 18
    Elseif Left(upperText, 16) = "PUBLIC FUNCTION " Then
        nameStart = 17
    Elseif Left(upperText, 9) = "FUNCTION " Then
        nameStart = 10
    Elseif Left(upperText, 17) = "PRIVATE PROPERTY " Then
        nameStart = 18
    Elseif Left(upperText, 12) = "PROPERTY " Then
        nameStart = 10
    Elseif Left(upperText, 12) = "PRIVATE SUB " Then
        nameStart = 13
    Elseif Left(upperText, 11) = "PUBLIC SUB " Then
        nameStart = 12
    Elseif Left(upperText, 4) = "SUB " Then
        nameStart = 5
    Elseif Left(upperText, 12) = "CONSTRUCTOR " Then
        nameStart = 13
    Elseif Left(upperText, 11) = "DESTRUCTOR " Then
        nameStart = 12
    Else
        Return ""
    End If

    If nameStart > Len(normalizedText) Then Return ""
    If Mid(normalizedText, nameStart, 1) = "=" Then Return ""

    nameEnd = nameStart
    While nameEnd <= Len(normalizedText)
        Dim As Integer charCode = Asc(Mid(normalizedText, nameEnd, 1))
        If Not ((charCode >= 48 AndAlso charCode <= 57) OrElse _
                (charCode >= 65 AndAlso charCode <= 90) OrElse _
                (charCode >= 97 AndAlso charCode <= 122) OrElse _
                charCode = 95) Then Exit While
        nameEnd += 1
    Wend
    If nameEnd <= nameStart Then Return ""

    Return Mid(normalizedText, nameStart, nameEnd - nameStart)

End Function


Sub tiko_RebuildFunctionList()

    Dim As Integer lineEnd
    Dim As Integer lineAfter
    Dim As Integer lineNumber = 1
    Dim As Integer lineStart
    Dim As Integer currentSerial
    Dim As String lineText
    Dim As TextBoxData Ptr textData

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 OrElse _
       tiko_ActiveDocument < 0 OrElse _
       tiko_ActiveDocument >= tiko_DocumentCount Then
        tiko_FunctionCount = 0
        tiko_FunctionDocument = -1
        Return
    End If

    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    currentSerial = CInt(textData->change_serial And &H7FFFFFFF)
    If tiko_FunctionDocument = tiko_ActiveDocument AndAlso _
       tiko_FunctionChangeSerial = textData->change_serial Then Return

    tiko_FunctionCount = 0
    lineStart = 0
    While lineStart <= Len(textData->text)
        tiko_GetLineRange(textData->text, lineStart, lineEnd, lineAfter)
        lineText = Mid(textData->text, lineStart + 1, lineEnd - lineStart)
        Dim As String functionName = tiko_GetFunctionName(lineText)
        If functionName <> "" AndAlso _
           tiko_FunctionCount < TIKO_MAX_FUNCTIONS Then
            tiko_FunctionEntries(tiko_FunctionCount).line_number = lineNumber
            tiko_FunctionEntries(tiko_FunctionCount).position = lineStart
            tiko_FunctionEntries(tiko_FunctionCount).name = functionName
            tiko_FunctionCount += 1
        End If

        lineNumber += 1
        If lineAfter <= lineStart Then Exit While
        lineStart = lineAfter
    Wend

    tiko_FunctionDocument = tiko_ActiveDocument
    tiko_FunctionChangeSerial = textData->change_serial
    If tiko_FunctionScroll > tiko_FunctionCount Then _
        tiko_FunctionScroll = tiko_FunctionCount

End Sub


Sub tiko_GotoFunctionIndex(ByVal functionIndex As Integer)

    Dim As TextBoxData Ptr textData

    tiko_RebuildFunctionList
    If functionIndex < 0 OrElse functionIndex >= tiko_FunctionCount Then Return
    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Return

    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    textData->cursor_pos = tiko_FunctionEntries(functionIndex).position
    textData->sel_start = textData->cursor_pos
    textData->sel_end = textData->cursor_pos
    textData->selection_anchor = textData->cursor_pos
    textData->v_scroll = tiko_FunctionEntries(functionIndex).line_number - 1
    textData->viewport_dirty = -1
    textData->active = -1
    tiko_CaptureActiveDocument
    gui_SetFocus(tiko_Editor)
    tiko_SetStatus(tiko_FunctionEntries(functionIndex).name & " at line " & _
        LTrim(Str(tiko_FunctionEntries(functionIndex).line_number)))

End Sub


Private Sub tiko_GotoFunctionLine(ByVal targetLine As Integer)

    Dim As TextBoxData Ptr textData

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Return
    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    textData->cursor_pos = tiko_ClampEditPosition( _
        textData->text, targetLine _
    )
    textData->sel_start = textData->cursor_pos
    textData->sel_end = textData->cursor_pos
    textData->selection_anchor = textData->cursor_pos
    textData->v_scroll = tiko_LineNumberAt(textData->text, targetLine) - 1
    textData->viewport_dirty = -1
    textData->active = -1
    tiko_CaptureActiveDocument
    gui_SetFocus(tiko_Editor)

End Sub


Sub tiko_GotoNextFunction()

    Dim As Integer currentLine
    Dim As Integer chosenIndex = -1

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Return
    tiko_RebuildFunctionList
    currentLine = tiko_LineNumberAt( _
        Cast(TextBoxData Ptr, tiko_Editor->data)->text, _
        Cast(TextBoxData Ptr, tiko_Editor->data)->cursor_pos _
    )
    For functionIndex As Integer = 0 To tiko_FunctionCount - 1
        If tiko_FunctionEntries(functionIndex).line_number > currentLine Then
            chosenIndex = functionIndex
            Exit For
        End If
    Next functionIndex

    If chosenIndex < 0 Then
        tiko_SetStatus("No later Sub or Function in this file")
        Return
    End If
    tiko_GotoFunctionIndex(chosenIndex)

End Sub


Sub tiko_GotoPreviousFunction()

    Dim As Integer currentLine
    Dim As Integer chosenIndex = -1

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Return
    tiko_RebuildFunctionList
    currentLine = tiko_LineNumberAt( _
        Cast(TextBoxData Ptr, tiko_Editor->data)->text, _
        Cast(TextBoxData Ptr, tiko_Editor->data)->cursor_pos _
    )
    For functionIndex As Integer = tiko_FunctionCount - 1 To 0 Step -1
        If tiko_FunctionEntries(functionIndex).line_number < currentLine Then
            chosenIndex = functionIndex
            Exit For
        End If
    Next functionIndex

    If chosenIndex < 0 Then
        tiko_SetStatus("No earlier Sub or Function in this file")
        Return
    End If
    tiko_GotoFunctionIndex(chosenIndex)

End Sub


Sub tiko_ActivateRelativeDocument(ByVal direction As Integer)

    If tiko_ActiveDocument < 0 OrElse tiko_DocumentCount < 2 Then Return
    For attempt As Integer = 1 To tiko_DocumentCount
        Dim As Integer candidate = tiko_ActiveDocument + direction * attempt
        While candidate < 0
            candidate += tiko_DocumentCount
        Wend
        While candidate >= tiko_DocumentCount
            candidate -= tiko_DocumentCount
        Wend
        If tiko_Documents(candidate).tab_visible <> 0 Then
            tiko_ActivateDocument(candidate)
            Return
        End If
    Next attempt

End Sub


Private Function tiko_IsNameCharacter(ByVal charCode As Integer) As Integer
    Return IIf( _
        (charCode >= 48 AndAlso charCode <= 57) OrElse _
        (charCode >= 65 AndAlso charCode <= 90) OrElse _
        (charCode >= 97 AndAlso charCode <= 122) OrElse charCode = 95, _
        -1, 0 _
    )
End Function


Private Function tiko_CurrentWord() As String

    Dim As Integer firstCharacter
    Dim As Integer lastCharacter
    Dim As TextBoxData Ptr textData

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 Then Return ""
    textData = Cast(TextBoxData Ptr, tiko_Editor->data)
    If textData->sel_end > textData->sel_start Then
        Return Mid(textData->text, textData->sel_start + 1, _
            textData->sel_end - textData->sel_start)
    End If

    firstCharacter = tiko_ClampEditPosition( _
        textData->text, textData->cursor_pos _
    )
    If firstCharacter = Len(textData->text) AndAlso firstCharacter > 0 Then _
        firstCharacter -= 1
    If firstCharacter < Len(textData->text) AndAlso _
       tiko_IsNameCharacter(Asc(Mid(textData->text, firstCharacter + 1, 1))) = 0 Then
        If firstCharacter = 0 OrElse _
           tiko_IsNameCharacter(Asc(Mid(textData->text, firstCharacter, 1))) = 0 Then _
            Return ""
        firstCharacter -= 1
    End If

    While firstCharacter > 0 AndAlso _
          tiko_IsNameCharacter(Asc(Mid(textData->text, firstCharacter, 1))) <> 0
        firstCharacter -= 1
    Wend
    firstCharacter += 1

    lastCharacter = firstCharacter
    While lastCharacter <= Len(textData->text) AndAlso _
          tiko_IsNameCharacter(Asc(Mid(textData->text, lastCharacter, 1))) <> 0
        lastCharacter += 1
    Wend
    If lastCharacter <= firstCharacter Then Return ""
    Return Mid(textData->text, firstCharacter, lastCharacter - firstCharacter)

End Function


Sub tiko_GotoDefinition()

    Dim As Integer originalDocument
    Dim As Integer originalPosition
    Dim As Integer lineEnd
    Dim As Integer lineAfter
    Dim As Integer lineStart
    Dim As Integer lineNumber
    Dim As String searchName
    Dim As String lineText

    If tiko_ActiveDocument < 0 OrElse _
       tiko_ActiveDocument >= tiko_DocumentCount Then Return
    tiko_CaptureActiveDocument
    searchName = Trim(tiko_CurrentWord)
    If searchName = "" Then
        tiko_SetStatus("Select a Sub or Function name first")
        Return
    End If

    originalDocument = tiko_ActiveDocument
    originalPosition = tiko_Documents(originalDocument).cursor_pos
    For documentIndex As Integer = 0 To tiko_DocumentCount - 1
        lineStart = 0
        lineNumber = 1
        While lineStart <= Len(tiko_Documents(documentIndex).text)
            tiko_GetLineRange( _
                tiko_Documents(documentIndex).text, lineStart, lineEnd, lineAfter _
            )
            lineText = Mid( _
                tiko_Documents(documentIndex).text, _
                lineStart + 1, lineEnd - lineStart _
            )
            If UCase(tiko_GetFunctionName(lineText)) = UCase(searchName) Then
                tiko_LastPositionDocument = originalDocument
                tiko_LastPositionCursor = originalPosition
                tiko_ActivateDocument(documentIndex)
                tiko_GotoFunctionLine(lineStart)
                tiko_SetStatus("Definition: " & searchName & " at line " & _
                    LTrim(Str(lineNumber)))
                Return
            End If
            If lineAfter <= lineStart Then Exit While
            lineStart = lineAfter
            lineNumber += 1
        Wend
    Next documentIndex

    tiko_SetStatus("Sub/Function definition not found: " & searchName)

End Sub


Sub tiko_GotoLastPosition()

    Dim As Integer savedPosition
    Dim As Integer savedDocument

    If tiko_LastPositionDocument < 0 OrElse _
       tiko_LastPositionDocument >= tiko_DocumentCount Then
        tiko_SetStatus("There is no previous editor position")
        Return
    End If
    savedDocument = tiko_LastPositionDocument
    savedPosition = tiko_LastPositionCursor
    tiko_ActivateDocument(savedDocument)
    tiko_GotoFunctionLine(savedPosition)
    tiko_SetStatus("Returned to previous editor position")

End Sub


Sub tiko_ReplaceCurrent()

    Dim As Integer selectionStart
    Dim As Integer selectionEnd
    Dim As String searchText
    Dim As String replacementText
    Dim As String newText
    Dim As TextBoxData Ptr editorData
    Dim As TextBoxData Ptr findData
    Dim As TextBoxData Ptr replaceData

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 OrElse _
       tiko_FindBox = 0 OrElse tiko_FindBox->data = 0 OrElse _
       tiko_ReplaceBox = 0 OrElse tiko_ReplaceBox->data = 0 Then Exit Sub

    findData = Cast(TextBoxData Ptr, tiko_FindBox->data)
    replaceData = Cast(TextBoxData Ptr, tiko_ReplaceBox->data)
    searchText = findData->text
    replacementText = replaceData->text
    If searchText = "" Then
        tiko_SetStatus("Type text in Find before replacing")
        Return
    End If

    editorData = Cast(TextBoxData Ptr, tiko_Editor->data)
    selectionStart = tiko_ClampEditPosition( _
        editorData->text, editorData->sel_start _
    )
    selectionEnd = tiko_ClampEditPosition( _
        editorData->text, editorData->sel_end _
    )
    If selectionEnd < selectionStart Then _
        Swap selectionStart, selectionEnd

    If selectionEnd - selectionStart <> Len(searchText) OrElse _
       UCase(Mid(editorData->text, selectionStart + 1, _
           selectionEnd - selectionStart)) <> UCase(searchText) Then
        tiko_FindNext
        Return
    End If

    newText = Left(editorData->text, selectionStart) & replacementText & _
        Mid(editorData->text, selectionEnd + 1)
    If tiko_ApplyEditorText( _
        newText, selectionStart, selectionStart + Len(replacementText), _
        selectionStart + Len(replacementText) _
    ) = 0 Then Return

    tiko_SetStatus("Replaced one occurrence")
    tiko_FindNext

End Sub


Sub tiko_ReplaceAll()

    Dim As Integer foundPosition
    Dim As Integer replacedCount
    Dim As Integer searchPosition = 1
    Dim As String searchText
    Dim As String replacementText
    Dim As String sourceText
    Dim As String searchSource
    Dim As String searchNeedle
    Dim As String replacementResult
    Dim As TextBoxData Ptr editorData

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 OrElse _
       tiko_FindBox = 0 OrElse tiko_FindBox->data = 0 OrElse _
       tiko_ReplaceBox = 0 OrElse tiko_ReplaceBox->data = 0 Then Exit Sub

    searchText = Cast(TextBoxData Ptr, tiko_FindBox->data)->text
    replacementText = Cast(TextBoxData Ptr, tiko_ReplaceBox->data)->text
    If searchText = "" Then
        tiko_SetStatus("Type text in Find before replacing")
        Return
    End If

    editorData = Cast(TextBoxData Ptr, tiko_Editor->data)
    sourceText = editorData->text
    searchSource = UCase(sourceText)
    searchNeedle = UCase(searchText)

    While searchPosition <= Len(sourceText)
        foundPosition = Instr(searchPosition, searchSource, searchNeedle)
        If foundPosition = 0 Then Exit While

        replacementResult &= Mid( _
            sourceText, searchPosition, foundPosition - searchPosition _
        )
        If Len(replacementResult) + Len(replacementText) + _
           (Len(sourceText) - foundPosition - Len(searchText) + 1) > _
           TIKO_MAX_SOURCE_BYTES Then
            tiko_SetStatus("Replace result exceeds the 2 MiB source limit")
            Return
        End If
        replacementResult &= replacementText
        searchPosition = foundPosition + Len(searchText)
        replacedCount += 1
    Wend

    If replacedCount = 0 Then
        tiko_SetStatus("Not found: " & searchText)
        Return
    End If
    replacementResult &= Mid(sourceText, searchPosition)

    If tiko_ApplyEditorText( _
        replacementResult, Len(replacementResult), Len(replacementResult), _
        Len(replacementResult) _
    ) <> 0 Then
        tiko_SetStatus("Replaced " & LTrim(Str(replacedCount)) & _
            " occurrence(s)")
    End If

End Sub


Sub tiko_GotoLine()

    Dim As Integer targetLine
    Dim As Integer currentLine = 1
    Dim As Integer targetPosition
    Dim As TextBoxData Ptr editorData
    Dim As TextBoxData Ptr findData

    If tiko_Editor = 0 OrElse tiko_Editor->data = 0 OrElse _
       tiko_FindBox = 0 OrElse tiko_FindBox->data = 0 Then Exit Sub

    findData = Cast(TextBoxData Ptr, tiko_FindBox->data)
    If Trim(findData->text) = "" Then Return
    targetLine = Val(findData->text)
    If targetLine < 1 Then
        tiko_SetStatus("Line numbers start at 1")
        Return
    End If

    editorData = Cast(TextBoxData Ptr, tiko_Editor->data)
    If targetLine > tiko_LineNumberAt(editorData->text, Len(editorData->text)) Then
        tiko_SetStatus("Line number is past the end of this file")
        Return
    End If

    targetPosition = 0
    While currentLine < targetLine
        Dim As Integer newlinePosition = _
            Instr(targetPosition + 1, editorData->text, Chr(10))
        If newlinePosition = 0 Then Exit While
        targetPosition = newlinePosition
        currentLine += 1
    Wend

    editorData->cursor_pos = targetPosition
    editorData->sel_start = targetPosition
    editorData->sel_end = targetPosition
    editorData->selection_anchor = targetPosition
    editorData->v_scroll = targetLine - 1
    editorData->viewport_dirty = -1
    editorData->active = -1
    tiko_CaptureActiveDocument
    gui_SetFocus(tiko_Editor)
    tiko_SetStatus("Line " & LTrim(Str(targetLine)))
    tiko_HideFindBar

End Sub


Sub tiko_FindInFiles()

    Dim As Integer lineEnd
    Dim As Integer lineAfter
    Dim As Integer lineNumber
    Dim As Integer lineStart
    Dim As String searchText
    Dim As String searchNeedle
    Dim As String lineText
    Dim As String fileName
    Dim As TextBoxData Ptr findData

    If tiko_FindBox = 0 OrElse tiko_FindBox->data = 0 Then Exit Sub
    findData = Cast(TextBoxData Ptr, tiko_FindBox->data)
    searchText = Trim(findData->text)
    If searchText = "" Then
        tiko_SetStatus("Type text in Find before searching files")
        Return
    End If

    searchNeedle = UCase(searchText)
    tiko_SearchOutput = ""
    For documentIndex As Integer = 0 To tiko_DocumentCount - 1
        If tiko_Documents(documentIndex).is_missing <> 0 Then Continue For
        fileName = tiko_Documents(documentIndex).path
        If fileName = "" Then fileName = tiko_Documents(documentIndex).title
        lineStart = 0
        lineNumber = 1
        While lineStart <= Len(tiko_Documents(documentIndex).text)
            tiko_GetLineRange( _
                tiko_Documents(documentIndex).text, lineStart, lineEnd, lineAfter _
            )
            lineText = Mid( _
                tiko_Documents(documentIndex).text, _
                lineStart + 1, lineEnd - lineStart _
            )
            If Instr(UCase(lineText), searchNeedle) <> 0 Then
                If Len(tiko_SearchOutput) + Len(fileName) + _
                   Len(lineText) + 32 > TIKO_MAX_OUTPUT_BYTES Then
                    tiko_SearchOutput &= "... search output truncated ..." & Chr(10)
                    Exit For
                End If
                tiko_SearchOutput &= fileName & ":" & _
                    LTrim(Str(lineNumber)) & ":" & lineText & Chr(10)
            End If
            If lineAfter <= lineStart Then Exit While
            lineStart = lineAfter
            lineNumber += 1
        Wend
        If Len(tiko_SearchOutput) >= TIKO_MAX_OUTPUT_BYTES Then Exit For
    Next documentIndex

    If tiko_SearchOutput = "" Then _
        tiko_SearchOutput = "No matches for " & searchText
    tiko_ShowOutputPage(2)
    tiko_ShowOutput = -1
    tiko_ResizeWidgets
    tiko_SetStatus("Search complete")

End Sub

/' end of tiko_native_edit.bi '/
