/'
    Project: omaGUI timing tests
    File: backend_idle_smoke.bas
    Purpose: Verify that foreground polling waits are bounded and return.
    Responsibilities: Check nonpositive input, a short wait and the upper cap.
    This file does not render a window or test platform input dispatch.
'/
#lang "fb"
#include once "../src/backend/backend_idle.bi"

Private Function idleSmokeElapsed(ByVal started As Double) As Double
    Dim As Double elapsed = Timer - started
    If elapsed < -43200 Then
        elapsed += 86400
    ElseIf elapsed < 0 Then
        elapsed = 0
    End If
    Return elapsed
End Function
Private Sub idleSmokeRequire(ByVal condition As Integer, ByRef message As Const String)
    If condition <> 0 Then Exit Sub
    Print "backend_idle_smoke: FAIL "; message
    End 1
End Sub

Dim As Double started = Timer
backend_Idle -1
backend_Idle 0
idleSmokeRequire idleSmokeElapsed(started) < 1, "nonpositive wait blocked"
started = Timer
backend_Idle 10
Dim As Double elapsed = idleSmokeElapsed(started)
#If Defined(__FB_DOS__) And Not Defined(OMAGUI_DOSBOX_X_IDLE)
' The conservative DOS runtime rounds sub-tick sleeps down. This fallback
' deliberately preserves it; precise idle timing is qualified in the opt-in path.
idleSmokeRequire elapsed < 3, "legacy short wait did not return"
#Else
idleSmokeRequire elapsed >= 0.005 AndAlso elapsed < 3, "short wait did not respect its interval"
#EndIf
started = Timer
backend_Idle 2000
elapsed = idleSmokeElapsed(started)
idleSmokeRequire elapsed >= 0.9 AndAlso elapsed < 3, "polling wait was not capped at one second"
Print "backend_idle_smoke: PASS"
End 0
' end of backend_idle_smoke.bas
