/'
    Project: omaGUI
    ---------------
    File: menu.bas
    Purpose: Popup menu widget implementation.
'/
#lang "fb"

#include once "src/widgets/menu.bi"
#include once "src/widgets/widgets.bi"

Const MENU_DEFAULT_WIDTH As Integer = 100
Const MENU_ITEM_HEIGHT As Integer = 20
Const MENU_MIN_ITEM_HEIGHT As Integer = 16
Const MENU_MAX_ITEM_HEIGHT As Integer = 96
Const MENU_SELECTION_INSET As Integer = 2
Const MENU_TEXT_INSET As Integer = 5

' -------------------------------------------------------------------------
' Construction
' -------------------------------------------------------------------------

Function menu_Create(ByVal nm As String, ByVal x As Integer, ByVal y As Integer) As Widget Ptr
    Dim As Widget Ptr wgt = New Widget
    Dim As MenuData Ptr d = New MenuData
    wgt->name = nm : wgt->x = x : wgt->y = y : wgt->w = MENU_DEFAULT_WIDTH : wgt->h = 0
    wgt->visible = 0 : wgt->enabled = 1
    wgt->pointer_global = -1
    wgt->render = @menu_Render : wgt->update = @menu_Update : wgt->destroy = @menu_Destroy
    d->count = 0 : d->selected = -1
    d->item_height = MENU_ITEM_HEIGHT
    d->pointer_latch = 0 : d->pointer_index = -1
    d->selection_handler = 0 : d->selection_context = 0
    wgt->data = d
    Return wgt
End Function

' -------------------------------------------------------------------------
' Menu Items
' -------------------------------------------------------------------------

Sub menu_AddItem(ByVal m As Widget Ptr, ByVal txt As String, ByVal cb As Sub(ByVal As Integer))
    Dim As MenuData Ptr d

    If m = 0 OrElse m->data = 0 Then Exit Sub
    d = Cast(MenuData Ptr, m->data)
    If d->count >= MENU_MAX_ITEMS Then Exit Sub
    d->items(d->count) = txt
    d->callbacks(d->count) = cb
    d->is_separator(d->count) = 0
    d->count += 1

    ' Auto-size
    m->h = d->count * d->item_height + 4
    Dim As Integer tw = backend_GetTextWidth(txt) + 20
    If tw > m->w Then m->w = tw
End Sub


Sub menu_AddSeparator(ByVal m As Widget Ptr)
    Dim As MenuData Ptr d

    If m = 0 OrElse m->data = 0 Then Exit Sub
    d = Cast(MenuData Ptr, m->data)
    If d->count >= MENU_MAX_ITEMS Then Exit Sub

    d->items(d->count) = ""
    d->callbacks(d->count) = 0
    d->is_separator(d->count) = -1
    d->count += 1
    m->h = d->count * d->item_height + 4
End Sub


Sub menu_SetItemHeight(ByVal m As Widget Ptr, ByVal itemHeight As Integer)
    Dim As MenuData Ptr d

    If m = 0 OrElse m->data = 0 Then Exit Sub
    If itemHeight < MENU_MIN_ITEM_HEIGHT Then itemHeight = MENU_MIN_ITEM_HEIGHT
    If itemHeight > MENU_MAX_ITEM_HEIGHT Then itemHeight = MENU_MAX_ITEM_HEIGHT

    d = Cast(MenuData Ptr, m->data)
    d->item_height = itemHeight
    m->h = d->count * d->item_height + 4
End Sub


Sub menu_ClearItems(ByVal m As Widget Ptr)
    Dim As MenuData Ptr d

    If m = 0 OrElse m->data = 0 Then Exit Sub
    d = Cast(MenuData Ptr, m->data)

    For itemIndex As Integer = 0 To MENU_MAX_ITEMS - 1
        d->items(itemIndex) = ""
        d->callbacks(itemIndex) = 0
        d->is_separator(itemIndex) = 0
    Next itemIndex

    d->count = 0
    d->selected = -1
    d->pointer_latch = 0
    d->pointer_index = -1
    m->w = MENU_DEFAULT_WIDTH
    m->h = 0
End Sub


Sub menu_SetSelectionHandler( _
    ByVal m As Widget Ptr, _
    ByVal selection_handler As Any Ptr, ByVal selection_context As Any Ptr _
)
    Dim As MenuData Ptr d

    If m = 0 OrElse m->data = 0 Then Exit Sub
    d = Cast(MenuData Ptr, m->data)
    d->selection_handler = selection_handler
    d->selection_context = selection_context
End Sub

' -------------------------------------------------------------------------
' Rendering
' -------------------------------------------------------------------------

Sub menu_Render(ByVal w As Widget Ptr)
    Dim As MenuData Ptr d = w->data
    backend_Rect(w->ax, w->ay, w->w, w->h, current_theme.win_border, 0)
    backend_Rect(w->ax + 1, w->ay + 1, w->w - 2, w->h - 2, current_theme.bg_face, 1)

    For i As Integer = 0 To d->count - 1
        Dim As Integer itemTop = w->ay + 2 + i * d->item_height
        If d->is_separator(i) <> 0 Then
            backend_Line( _
                w->ax + MENU_TEXT_INSET, _
                itemTop + (d->item_height \ 2), _
                w->ax + w->w - MENU_TEXT_INSET - 1, _
                itemTop + (d->item_height \ 2), current_theme.bg_dark _
            )
        Elseif d->selected = i Then
            backend_Rect(w->ax + MENU_SELECTION_INSET, itemTop, w->w - MENU_SELECTION_INSET * 2, d->item_height, current_theme.bg_select, 1)
            backend_Print(w->ax + MENU_TEXT_INSET, itemTop + ((d->item_height - 10) \ 2), current_theme.text_select, d->items(i))
        Else
            backend_Print(w->ax + MENU_TEXT_INSET, itemTop + ((d->item_height - 10) \ 2), current_theme.text_main, d->items(i))
        End If
    Next
End Sub

' -------------------------------------------------------------------------
' Processing
' -------------------------------------------------------------------------

Sub menu_Update(ByVal w As Widget Ptr)
    Dim As MenuData Ptr d = w->data
    Dim As Integer mx = input_MouseX()
    Dim As Integer my = input_MouseY()
    Dim As Integer mb = input_MouseButtons()
    Dim As Integer pointerIndex = -1
    Dim As Integer activationIndex = -1
    Dim As Integer localY

    If mx >= w->ax And mx < w->ax + w->w And my >= w->ay And my < w->ay + w->h Then
        localY = my - w->ay - MENU_SELECTION_INSET
        If localY >= 0 Then
            pointerIndex = localY \ d->item_height
            If pointerIndex >= d->count Then pointerIndex = -1
        End If
        If pointerIndex >= 0 AndAlso _
           pointerIndex < d->count AndAlso _
           d->is_separator(pointerIndex) <> 0 Then pointerIndex = -1
    Else
        pointerIndex = -1
    End If

    d->selected = pointerIndex

    /'
        A menu item behaves like a desktop push button: the press records
        which row was hit, and a matching release publishes one selection.
        Releasing outside the original row dismisses the popup without
        running a command.
    '/
    If (mb And 1) <> 0 Then
        If d->pointer_latch = 0 Then
            d->pointer_latch = -1
            d->pointer_index = pointerIndex
        End If
    ElseIf d->pointer_latch <> 0 Then
        If pointerIndex >= 0 AndAlso _
           pointerIndex = d->pointer_index Then activationIndex = pointerIndex

        d->pointer_latch = 0
        d->pointer_index = -1
        w->visible = 0

        /'
            Hide the popup before calling application code. A callback can
            remove or replace widgets, so the old menu state is not read again.
        '/
        If activationIndex >= 0 Then
            If d->selection_handler <> 0 Then
                Cast( _
                    Sub(ByVal As Any Ptr, ByVal As Integer), _
                    d->selection_handler _
                )(d->selection_context, activationIndex)
            ElseIf d->callbacks(activationIndex) <> 0 Then
                d->callbacks(activationIndex)(activationIndex)
            End If
        End If
    End If
End Sub

' -------------------------------------------------------------------------
' Lifecycle
' -------------------------------------------------------------------------

Sub menu_Destroy(ByVal w As Widget Ptr)
    Delete Cast(MenuData Ptr, w->data)
End Sub

' end of menu.bas
