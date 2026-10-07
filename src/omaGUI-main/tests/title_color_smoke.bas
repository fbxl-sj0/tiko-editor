/'
    Project: omaGUI Tests
    File: title_color_smoke.bas
    Purpose: Verify classic palettes and native byte runs with framebuffer pixels.
    Responsibilities: Check ownership, clipping, semantic widget colors,
        theme isolation, restoration, and minimized-window titles.
    This file intentionally does NOT contain VBDOS property conversion or input.
'/
#lang "fb"
#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Private Sub Require( _
    ByVal success As Integer, ByVal source_line As Integer, _
    ByRef detail As Const String = "" _
)
    If success Then Exit Sub
    Screen 0
    Print "title_color_smoke: FAIL at line "; source_line; ": "; detail
    End 1
End Sub

Private Function PixelIs(ByVal x As Integer, ByVal y As Integer, ByVal expected_color As ULong) As Integer
    Return IIf((Point(x, y) And &hFFFFFF) = (expected_color And &hFFFFFF), -1, 0)
End Function


Private Function CountPixels( _
    ByVal expected_color As ULong, _
    ByVal screen_width As Integer, ByVal screen_height As Integer _
) As Long
    Dim As Long pixel_count
    For pixel_y As Integer = 0 To screen_height - 1
        For pixel_x As Integer = 0 To screen_width - 1
            If PixelIs(pixel_x, pixel_y, expected_color) Then pixel_count += 1
        Next pixel_x
    Next pixel_y
    Return pixel_count
End Function

backend_Init 320, 240
gui_Init
Dim As Integer screen_width, screen_height, screen_depth
ScreenInfo screen_width, screen_height, screen_depth
Require screen_width = 320 AndAlso screen_height = 240 AndAlso screen_depth = 32 AndAlso ScreenPtr <> 0, __LINE__
Dim As String initial_driver, restored_driver
ScreenControl FB.GET_DRIVER_NAME, initial_driver
Require Len(initial_driver) > 0, __LINE__
Dim As GUI_Theme saved_theme = current_theme
Dim As Widget Ptr titled = subwindow_Create("titled", "Title", 12, 18, 180, 100, 0)
Dim As Widget Ptr plain = subwindow_Create("plain", "Plain", 200, 120, 100, 100, 0)
Dim As Widget Ptr wrong_kind = label_Create("wrong_kind", "Label", 10, 130)
Require titled <> 0 AndAlso plain <> 0 AndAlso wrong_kind <> 0, __LINE__
gui_AddWidget titled
gui_AddWidget plain
gui_AddWidget wrong_kind
Dim As ULong background_color = 123
Dim As ULong foreground_color = 456
Require subwindow_GetTitleColors(titled, background_color, foreground_color) = 0, __LINE__
Require background_color = 123 AndAlso foreground_color = 456, __LINE__
Require subwindow_SetTitleColors(0, 1, 2) = 0, __LINE__
Require subwindow_SetTitleColors(wrong_kind, 1, 2) = 0, __LINE__
Require subwindow_ClearTitleColors(wrong_kind) = 0, __LINE__
Require subwindow_GetTitleColors(wrong_kind, background_color, foreground_color) = 0, __LINE__
Require background_color = 123 AndAlso foreground_color = 456, __LINE__
Require subwindow_SetTitleColors(titled, RGB(170, 0, 0), RGB(255, 255, 85)), __LINE__
Require subwindow_GetTitleColors(titled, background_color, foreground_color), __LINE__
Require background_color = RGB(170, 0, 0) AndAlso foreground_color = RGB(255, 255, 85), __LINE__
gui_UpdateAll
backend_Clear RGB(0, 0, 0)
gui_RenderAll
Require PixelIs(titled->ax + 80, titled->ay + 2, background_color), __LINE__
Require PixelIs(plain->ax + 80, plain->ay + 2, saved_theme.bg_select), __LINE__
Require subwindow_SetBorderStyle(plain, SUBWINDOW_BORDER_NONE), __LINE__
Require subwindow_SetWindowState( _
    plain, SUBWINDOW_STATE_MINIMIZED _
), __LINE__
gui_SynchronizeLayout
backend_Clear RGB(0, 0, 0)
gui_RenderAll
Require PixelIs(plain->ax + 80, plain->ay + 2, saved_theme.bg_select), __LINE__
Require subwindow_SetWindowState(plain, SUBWINDOW_STATE_NORMAL), __LINE__
Dim As Integer title_ink
For pixel_y As Integer = titled->ay + 4 To titled->ay + 17
    For pixel_x As Integer = titled->ax + 5 To titled->ax + 45
        If PixelIs(pixel_x, pixel_y, foreground_color) Then title_ink += 1
    Next pixel_x
Next pixel_y
Require title_ink > 0, __LINE__
Require current_theme.bg_select = saved_theme.bg_select AndAlso current_theme.text_select = saved_theme.text_select, __LINE__

' Native runs retain descriptor length and clipping even with embedded NUL.
backend_Clear RGB(0, 0, 0)
backend_SetClip 8, 0, 8, 16
backend_PrintBytes 0, 0, RGB(255, 0, 0), Chr(219, 219, 0, 219)
backend_ResetClip
Require PixelIs(0, 0, RGB(0, 0, 0)) AndAlso PixelIs(8, 0, RGB(255, 0, 0)), __LINE__
Require PixelIs(16, 0, RGB(0, 0, 0)) AndAlso PixelIs(24, 0, RGB(0, 0, 0)), __LINE__
backend_PrintBytes 0, 0, RGB(0, 255, 0), Chr(0, 219, 0, 219)
Require PixelIs(24, 0, RGB(0, 255, 0)), __LINE__
backend_PrintBytes 0, 0, RGB(0, 0, 255), String(65537, Chr(219))
Require PixelIs(24, 0, RGB(0, 255, 0)), __LINE__
Dim As BackendDisplayState display_state
Require backend_CaptureDisplay(display_state), __LINE__
Screen 2
Require backend_RestoreDisplay(display_state), __LINE__
ScreenControl FB.GET_DRIVER_NAME, restored_driver
Require Len(restored_driver) > 0, __LINE__
backend_Clear RGB(0, 0, 0)
gui_RenderAll
Require PixelIs(titled->ax + 80, titled->ay + 2, background_color), __LINE__
Require subwindow_ClearTitleColors(titled), __LINE__
gui_RenderAll
Require PixelIs(titled->ax + 80, titled->ay + 2, saved_theme.bg_select), __LINE__

/'
    Every classic role receives a deliberately unrelated color. Finding each
    value in the resulting framebuffer proves that the API is consumed by a
    renderer instead of merely retaining an unused setting.
'/
Dim As Integer classic_roles(0 To GUI_CLASSIC_COLOR_COUNT - 1) = _
    {GUI_CLASSIC_COLOR_ACCESS_TEXT, _
     GUI_CLASSIC_COLOR_ACTIVE_BORDER_BACKGROUND, _
     GUI_CLASSIC_COLOR_ACTIVE_BORDER_TEXT, _
     GUI_CLASSIC_COLOR_COMMAND_TEXT, _
     GUI_CLASSIC_COLOR_DISABLED_TEXT, _
     GUI_CLASSIC_COLOR_MENU_BACKGROUND, _
     GUI_CLASSIC_COLOR_MENU_TEXT, _
     GUI_CLASSIC_COLOR_MENU_SELECTED_BACKGROUND, _
     GUI_CLASSIC_COLOR_MENU_SELECTED_TEXT, _
     GUI_CLASSIC_COLOR_SCROLLBAR_BACKGROUND, _
     GUI_CLASSIC_COLOR_SCROLLBAR_TEXT}
Dim As ULong classic_colors(0 To GUI_CLASSIC_COLOR_COUNT - 1)
For role_index As Integer = 0 To GUI_CLASSIC_COLOR_COUNT - 1
    classic_colors(role_index) = RGB(1 + role_index * 3, _
        2 + role_index * 3, 3 + role_index * 3)
    Require theme_SetClassicColor( _
        classic_roles(role_index), classic_colors(role_index) _
    ), __LINE__
    Require theme_GetClassicColor(classic_roles(role_index)) = _
        classic_colors(role_index), __LINE__
Next role_index
Require theme_SetClassicColor(-1, RGB(1, 1, 1)) = 0, __LINE__

Dim As Widget Ptr semantic_button = button_Create( _
    "semantic_button", "Run", 8, 120, 90, 28 _
)
Dim As Widget Ptr semantic_scrollbar = scrollbar_Create( _
    "semantic_scrollbar", 8, 210, 90, 18, 10, 1, 0 _
)
Dim As Widget Ptr semantic_bar = menubar_Create( _
    "semantic_bar", 110, 150, 200 _
)
Require semantic_button <> 0 AndAlso semantic_scrollbar <> 0 AndAlso _
    semantic_bar <> 0, __LINE__
Require scrollbar_SetArrowButtons(semantic_scrollbar, -1), __LINE__
Dim As Integer semantic_menu = menubar_AddMenu(semantic_bar, "&File")
Require semantic_menu = 0, __LINE__
Require menubar_AddMenu(semantic_bar, "&Edit") = 1, __LINE__
Require menubar_AddItem(semantic_bar, semantic_menu, "&Open") = 0, __LINE__
Require menubar_AddItem(semantic_bar, semantic_menu, "Disabled") = 1, __LINE__
Require menubar_SetItemEnabled(semantic_bar, semantic_menu, 1, 0), __LINE__
Require menubar_SetOpenMenu(semantic_bar, semantic_menu), __LINE__
gui_AddWidget semantic_button
gui_AddWidget semantic_scrollbar
gui_AddWidget semantic_bar
gui_UpdateAll
backend_Clear RGB(0, 0, 0)
gui_RenderAll
For role_index As Integer = 0 To GUI_CLASSIC_COLOR_COUNT - 1
    Dim As Long role_pixel_count = CountPixels( _
        classic_colors(role_index), screen_width, screen_height _
    )
    Require role_pixel_count > 0, __LINE__, _
        "missing classic color role " & LTrim(Str(role_index))
Next role_index
theme_SetMode GUI_THEME_MODE_NORMAL
Require theme_GetClassicColor(GUI_CLASSIC_COLOR_MENU_BACKGROUND) = _
    current_theme.bg_face, __LINE__
Require theme_GetClassicColor(GUI_CLASSIC_COLOR_MENU_SELECTED_TEXT) = _
    current_theme.text_select, __LINE__
gui_ResetForTest
backend_Exit
Screen 0
Print "title_color_smoke: PASS (semantic classic colors, title pixels, byte runs/clipping, screen restore)"
Print "title_color_smoke: drivers = "; initial_driver; " / "; restored_driver
End 0
/' end of title_color_smoke.bas '/
