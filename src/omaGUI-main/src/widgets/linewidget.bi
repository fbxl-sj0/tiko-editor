/'
    Project: omaGUI
    ---------------

    File: linewidget.bi

    Purpose:

        Declare a registry-managed line drawing widget.

    Responsibilities:

        - retain the line color
        - represent endpoints through the base widget rectangle

    Targets:

        FreeBASIC builds with built-in gfxlib; gfxlib3 is optional when supplied by the compiler.

    Module API:

        Declarations for the linewidget component in the omaGUI include graph.

    This file intentionally does NOT contain:

        - line rasterization
        - interactive drawing-tool behavior
'/

#ifndef __LINEWIDGET_BI__
#define __LINEWIDGET_BI__

#include once "src/widgets/widgets.bi"

Type LineWidgetData
    As ULong clr
End Type

Declare Function linewidget_Create( _
    ByVal nm As String, _
    ByVal x1 As Integer, ByVal y1 As Integer, _
    ByVal x2 As Integer, ByVal y2 As Integer, _
    ByVal clr As ULong _
) As Widget Ptr
Declare Sub linewidget_Render(ByVal w As Widget Ptr)
Declare Sub linewidget_Destroy(ByVal w As Widget Ptr)

#endif

' end of linewidget.bi
