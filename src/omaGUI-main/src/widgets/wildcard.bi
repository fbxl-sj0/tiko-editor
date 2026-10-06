/'
    Project: omaGUI
    ---------------

    File: wildcard.bi

    Purpose:

        Declare the shared, platform-independent filename wildcard matcher.

    Responsibilities:

        - expose case-insensitive '*' and '?' matching to filesystem widgets
        - keep wildcard semantics independent of the host Dir implementation

    Targets:

        FreeBASIC builds with built-in gfxlib; gfxlib3 is optional when supplied by the compiler.

    Module API:

        Declarations for the wildcard component in the omaGUI include graph.

    This file intentionally does NOT contain:

        - directory enumeration
        - semicolon-separated pattern parsing
        - platform APIs
'/

#ifndef __OMAGUI_WILDCARD_BI__
#define __OMAGUI_WILDCARD_BI__

Declare Function omaguiinternal_WildcardMatches( _
    ByRef fileName As Const String, _
    ByRef patternText As Const String _
) As Integer

#endif

/' end of wildcard.bi '/
