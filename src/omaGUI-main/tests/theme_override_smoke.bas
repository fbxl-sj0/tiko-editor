/'
    Project: omaGUI
    ---------------

    File: theme_override_smoke.bas

    Targets:

        FreeBASIC FB dialect with a gfxlib2 or gfxlib3 desktop backend.

    Module API:

        Standalone theme-inheritance smoke executable with no exported API.

    Purpose:

        Verify inherited widget themes and render-state restoration.

    Responsibilities:

        - inherit a parent theme in a child control
        - permit a child to replace the inherited theme
        - prove rendering restores the process-wide theme
        - prove styled button geometry uses the inherited accent
        - update a classic theme frame color through its public setter

    This file intentionally does NOT contain:

        - application-specific faction themes
        - interactive pointer tests
        - filesystem snapshots
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Const THEME_OVERRIDE_WIDTH As Integer = 160
Const THEME_OVERRIDE_HEIGHT As Integer = 90

Dim As GUI_Theme classicTheme
Dim As GUI_Theme parentTheme
Dim As GUI_Theme childTheme
Dim As GUI_Theme resolvedTheme
Dim As GUI_Theme restoredTheme
Dim As Widget Ptr parentWidget
Dim As Widget Ptr childWidget
Dim As Widget Ptr classicFrameWidget

' The drawable headless mode retains pixels without requiring a desktop.
backend_Init THEME_OVERRIDE_WIDTH, THEME_OVERRIDE_HEIGHT, BACKEND_HEADLESS_DRAWABLE
gui_Init()
theme_GetCurrent classicTheme

parentTheme = classicTheme
parentTheme.bg_face = RGB(30, 50, 70)
parentTheme.bg_dark = RGB(10, 20, 30)
parentTheme.bg_light = RGB(70, 100, 130)
parentTheme.bg_select = RGB(240, 80, 40)
parentTheme.accent_secondary = RGB(255, 190, 80)
parentTheme.text_main = RGB(255, 255, 255)
parentTheme.visual_style = GUI_THEME_STYLE_FORTIFIED

childTheme = parentTheme
childTheme.bg_select = RGB(20, 220, 160)
childTheme.visual_style = GUI_THEME_STYLE_CHEVRON

parentWidget = gui_CreateWidgetBase()
parentWidget->name = "theme_parent"
parentWidget->x = 0
parentWidget->y = 0
parentWidget->w = THEME_OVERRIDE_WIDTH
parentWidget->h = THEME_OVERRIDE_HEIGHT
childWidget = button_Create("theme_child", "Inherited", 20, 20, 100, 32)
gui_AddWidget parentWidget
gui_AddWidget childWidget
gui_SetParent childWidget, parentWidget
gui_SetWidgetTheme parentWidget, parentTheme

If gui_GetEffectiveWidgetTheme(childWidget, resolvedTheme) = 0 OrElse _
   resolvedTheme.visual_style <> GUI_THEME_STYLE_FORTIFIED Then
    Print "theme override smoke failed: child did not inherit its parent theme"
    End 1
End If

backend_Clear RGB(0, 0, 0)
gui_RenderAll()
theme_GetCurrent restoredTheme
If restoredTheme.visual_style <> classicTheme.visual_style OrElse _
   restoredTheme.bg_face <> classicTheme.bg_face Then
    Print "theme override smoke failed: rendering leaked a widget theme"
    End 2
End If
If Point(26, 26) <> parentTheme.bg_face Then
    Print "theme override smoke failed: inherited button face was not rendered"
    End 3
End If

classicFrameWidget = themeframe_Create( _
    "classic_frame", 120, 60, 20, 20, RGB(80, 20, 20), -1)
If classicFrameWidget = 0 Then
    Print "theme override smoke failed: classic frame allocation failed"
    End 4
End If
gui_AddWidget classicFrameWidget
themeframe_SetClassicColor classicFrameWidget, RGB(20, 180, 80)
' The generic setter must refuse a different widget type without corrupting
' that control's private data.
themeframe_SetClassicColor childWidget, RGB(255, 0, 255)
backend_Clear RGB(0, 0, 0)
gui_RenderAll()
If Point(125, 65) <> RGB(20, 180, 80) Then
    Print "theme override smoke failed: classic frame color was not updated"
    End 5
End If

gui_SetWidgetTheme childWidget, childTheme
If gui_GetEffectiveWidgetTheme(childWidget, resolvedTheme) = 0 OrElse _
   resolvedTheme.visual_style <> GUI_THEME_STYLE_CHEVRON OrElse _
   resolvedTheme.bg_select <> childTheme.bg_select Then
    Print "theme override smoke failed: child override did not win"
    End 6
End If

' A borrowed dialog palette and a copied game palette share the same nearest
' ancestor rule. Clearing the copy exposes the still-live borrowed palette.
Dim As GUI_Theme dialogTheme
theme_InitDialog dialogTheme
parentWidget->appearance = @dialogTheme
gui_ClearWidgetTheme childWidget
gui_ClearWidgetTheme parentWidget
If gui_GetEffectiveWidgetTheme(childWidget, resolvedTheme) = 0 OrElse _
   resolvedTheme.control_style <> GUI_CONTROL_STYLE_FLAT Then End 7
gui_SetWidgetTheme childWidget, childTheme
If gui_GetEffectiveWidgetTheme(childWidget, resolvedTheme) = 0 OrElse _
   resolvedTheme.visual_style <> GUI_THEME_STYLE_CHEVRON Then End 8
gui_ClearWidgetTheme childWidget
backend_Clear RGB(0, 0, 0)
gui_RenderAll
theme_GetCurrent restoredTheme
If restoredTheme.classic_menu_background <> classicTheme.classic_menu_background _
   OrElse restoredTheme.control_style <> classicTheme.control_style Then End 9

gui_ResetForTest()
backend_Exit()
Print "omaGUI theme override smoke passed."

/' end of theme_override_smoke.bas '/
