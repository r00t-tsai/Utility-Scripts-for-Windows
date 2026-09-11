; Macro Recorder (Overhauled)
; Installation: Download AutoHotkey v2 and double-click to run.
; LIMITATIONS: This is a blind script relying on predictable environments (such as repetitive tasks/quests in games, logging redundant informations, etc.). It may fail with interactive tasks that require different setups.
#Requires AutoHotkey v2.0
#SingleInstance Force
if not A_IsAdmin {
    try {
        Run('*RunAs "' A_ScriptFullPath '"')
    } catch {
        MsgBox("The macro recorder needs Administrator rights to interact with system windows.", "Admin Required", 48)
    }
    ExitApp()
}

CoordMode "Mouse", "Screen"
SendMode "Event" 

global moveSampleMs     := 15      
global recording        := false
global paused           := false
global playing          := false
global stopPlaybackFlag := false
global events           := []
global recStart         := 0
global pausedTotal      := 0
global pauseStartTick   := 0
global lastMouseX       := -999999
global lastMouseY       := -999999
global hkRecordStr := "F9"
global hkPauseStr  := "F10"
global hkPlayStr   := "F11"
global hkAbortStr  := "F12"
A_IconTip := "Macro Recorder"
A_TrayMenu.Delete()
A_TrayMenu.Add("Show Menu", (*) => myGui.Show())
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Show Menu"

myGui := Gui("+MinSize -MaximizeBox", "Macro Recorder")
myGui.OnEvent("Close", (*) => myGui.Hide())
myGui.Add("GroupBox", "w220 h140", "Configurable Hotkeys")
myGui.Add("Text", "xp+10 yp+20 w80", "Record / Stop:")
myGui.Add("Hotkey", "vHkRecord x+10 w100", hkRecordStr)
myGui.Add("Text", "xs+10 y+10 w80", "Pause / Res.:")
myGui.Add("Hotkey", "vHkPause x+10 w100", hkPauseStr)
myGui.Add("Text", "xs+10 y+10 w80", "Play:")
myGui.Add("Hotkey", "vHkPlay x+10 w100", hkPlayStr)
myGui.Add("Text", "xs+10 y+10 w80", "Abort Playback:")
myGui.Add("Hotkey", "vHkAbort x+10 w100", hkAbortStr)
myGui.Add("GroupBox", "x10 y+20 w220 h85", "Playback Options")
myGui.Add("CheckBox", "vDoLoop xp+10 yp+20", "Enable Looping")
myGui.Add("Text", "y+10 w70", "Loop Count:")
myGui.Add("Edit", "vLoopCount x+5 w50 Number", "0")
myGui.Add("Text", "x+5", "(0 = Infinite)")
myGui.Add("Button", "x10 y+20 w220 h35", "Apply / Update Settings").OnEvent("Click", ApplySettings)
myGui.Show()
ApplySettings()


mouseButtons := ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
registeredKeys := Map()

Loop 255 {
    keyName := GetKeyName(Format("vk{:X}", A_Index))
    if (keyName != "" && !HasVal(mouseButtons, keyName))
        registeredKeys[keyName] := 1
}

for mb in mouseButtons
    registeredKeys[mb] := 1

for key in registeredKeys {
    try Hotkey("~*" key, RecordKeyDown, "On")
    try Hotkey("~*" key " up", RecordKeyUp, "On")
}

try Hotkey("~*WheelUp", RecordWheelUp, "On")
try Hotkey("~*WheelDown", RecordWheelDown, "On")
try Hotkey("~*WheelLeft", RecordWheelLeft, "On")
try Hotkey("~*WheelRight", RecordWheelRight, "On")

SetTimer(SampleMouse, moveSampleMs)

ApplySettings(*) {
    global hkRecordStr, hkPauseStr, hkPlayStr, hkAbortStr
    try Hotkey(hkRecordStr, "Off")
    try Hotkey(hkPauseStr, "Off")
    try Hotkey(hkPlayStr, "Off")
    try Hotkey(hkAbortStr, "Off")
    saved := myGui.Submit(false)
    hkRecordStr := saved.HkRecord
    hkPauseStr  := saved.HkPause
    hkPlayStr   := saved.HkPlay
    hkAbortStr  := saved.HkAbort
    try Hotkey(hkRecordStr, ToggleRecording, "On")
    try Hotkey(hkPauseStr, TogglePause, "On")
    try Hotkey(hkPlayStr, StartPlayback, "On")
    try Hotkey(hkAbortStr, AbortPlayback, "On")
    
    Flash("Settings Applied")
}

ToggleRecording(*) {
    global recording, paused, events, recStart, pausedTotal, playing
    if playing {
        Flash("Can't record during playback")
        return
    }
    if !recording {
        events := []
        recording := true
        paused := false
        pausedTotal := 0
        recStart := A_TickCount
        ToolTip("Recording...")
    } else {
        recording := false
        paused := false
        Flash("Stopped — " events.Length " events captured")
    }
}

TogglePause(*) {
    global recording, paused, pauseStartTick, pausedTotal
    if !recording
        return
    if !paused {
        paused := true
        pauseStartTick := A_TickCount
        ToolTip("Paused")
    } else {
        paused := false
        pausedTotal += A_TickCount - pauseStartTick
        ToolTip("Recording...")
    }
}

StartPlayback(*) {
    global events, playing, recording, stopPlaybackFlag
    if recording {
        Flash("Stop recording first")
        return
    }
    if events.Length = 0 {
        Flash("Nothing recorded yet")
        return
    }
    
    saved := myGui.Submit(false)
    doLoop := saved.DoLoop
    maxLoops := saved.LoopCount
    if (maxLoops = "" || maxLoops < 0)
        maxLoops := 0
        
    playing := true
    stopPlaybackFlag := false
    loopCurrent := 0
    ToolTip("Playing...")

    ; LOOPING MECHANIC
    Loop {
        if stopPlaybackFlag
            break
            
        prevT := 0
        for e in events {
            if stopPlaybackFlag
                break
            delay := e.t - prevT
            if delay > 0
                Sleep(delay)
            prevT := e.t
            PlayEvent(e)
        }
        
        loopCurrent++
        if (!doLoop || (maxLoops > 0 && loopCurrent >= maxLoops) || stopPlaybackFlag)
            break
    }

    playing := false
    Flash("Playback finished")
}

AbortPlayback(*) {
    global stopPlaybackFlag
    stopPlaybackFlag := true
    Flash("Playback Aborted!")
}

LogEvent(type, name, action) {
    global events, recStart, pausedTotal
    MouseGetPos(&mx, &my)
    events.Push({
        t: A_TickCount - recStart - pausedTotal,   ; ms offset, pause time excluded
        type: type, name: name, action: action, x: mx, y: my
    })
}

RecordKeyDown(hk) {
    if !ShouldRecord()
        return
    keyName := StrReplace(hk, "~*", "")#Requires AutoHotkey v2.0
#SingleInstance Force

if not A_IsAdmin {
    try {
        Run('*RunAs "' A_ScriptFullPath '"')
    } catch {
        MsgBox("The macro recorder needs Administrator rights to interact with system windows.", "Admin Required", 48)
    }
    ExitApp()
}

CoordMode "Mouse", "Screen"
SendMode "Event"

DllCall("Winmm.dll\timeBeginPeriod", "UInt", 1)
OnExit((*) => DllCall("Winmm.dll\timeEndPeriod", "UInt", 1))

SetKeyDelay -1, -1
SetMouseDelay -1

global moveSampleMs             := 15
global maxCatchupMs             := 50
global verifyTimeoutMs          := 40
global verifyPollMs             := 2
global latencyBaselineMs        := 0
global latencyBaselineReady     := false
global latencyBaselineAlpha     := 0.15
global latencyExcessToleranceMs := 5
global latencyExcessCapMs       := 200
global latencyActive            := false

global recording                := false
global playing                  := false
global stopPlaybackFlag         := false
global playbackDrawingActive    := false
global events                   := []
global recStart                 := 0
global playbackStartTick        := 0
global lastMouseX               := -999999
global lastMouseY               := -999999

global hkRecordStr  := "F9"
global hkPlayStr    := "F11"
global hkAbortStr   := "F12"
global hkOverlayStr := "F8"

global overlayGui           := 0
global hudGui               := 0
global hudGuiCtrl           := 0
global sideHudGui           := 0
global sideHudCtrl          := 0
global overlayVisible       := false

global overlayOriginX       := 0
global overlayOriginY       := 0
global overlayWidth         := 0
global overlayHeight        := 0

global overlayLastX         := -1
global overlayLastY         := -1
global overlayStartTick     := 0

global overlayEventNumber   := 0
global overlayLastLagMs     := 0
global overlayLastEventType := ""
global overlayLastEventName := ""
global overlayLastEventAction := ""

global overlayElements      := []

global hkRecordCtrl, hkPlayCtrl, hkAbortCtrl, hkOverlayCtrl
global chkDoLoop, edtLoopCount, btnExport, btnLoad

A_IconTip := "Macro Recorder"
A_TrayMenu.Delete()
A_TrayMenu.Add("Show Menu", (*) => myGui.Show())
A_TrayMenu.Add("Toggle Overlay", ToggleOverlay)
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Show Menu"

myGui := Gui("+MinSize -MaximizeBox", "Macro Recorder")
myGui.OnEvent("Close", (*) => myGui.Hide())

myGui.Add("GroupBox", "w240 h135", "Configurable Hotkeys")
myGui.Add("Text", "xp+10 yp+20 w90", "Record / Stop:")
hkRecordCtrl := myGui.Add("Hotkey", "vHkRecord x+10 w110", hkRecordStr)
hkRecordCtrl.OnEvent("Change", ApplySettings)

myGui.Add("Text", "xs+10 y+10 w90", "Play:")
hkPlayCtrl := myGui.Add("Hotkey", "vHkPlay x+10 w110", hkPlayStr)
hkPlayCtrl.OnEvent("Change", ApplySettings)

myGui.Add("Text", "xs+10 y+10 w90", "Abort:")
hkAbortCtrl := myGui.Add("Hotkey", "vHkAbort x+10 w110", hkAbortStr)
hkAbortCtrl.OnEvent("Change", ApplySettings)

myGui.Add("Text", "xs+10 y+10 w90", "Overlay:")
hkOverlayCtrl := myGui.Add("Hotkey", "vHkOverlay x+10 w110", hkOverlayStr)
hkOverlayCtrl.OnEvent("Change", ApplySettings)

myGui.Add("GroupBox", "x10 y+20 w240 h85", "Playback Options")
chkDoLoop := myGui.Add("CheckBox", "vDoLoop xp+10 yp+20", "Enable Looping")
myGui.Add("Text", "y+10 w70", "Loop Count:")
edtLoopCount := myGui.Add("Edit", "vLoopCount x+5 w50 Number", "0")
myGui.Add("Text", "x+5", "(0 = Infinite)")

btnExport := myGui.Add("Button", "x10 y+20 w115 h35 Disabled", "Export Macro")
btnExport.OnEvent("Click", ExportMacro)

btnLoad := myGui.Add("Button", "x+10 w115 h35", "Load Macro")
btnLoad.OnEvent("Click", LoadMacro)

myGui.Show()
ApplySettings()

mouseButtons := ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
registeredKeys := Map()
Loop 255 {
    keyName := GetKeyName(Format("vk{:X}", A_Index))
    if (keyName != "" && !HasVal(mouseButtons, keyName))
        registeredKeys[keyName] := 1
}
for mb in mouseButtons
    registeredKeys[mb] := 1

for key in registeredKeys {
    try Hotkey("~*" key, RecordKeyDown, "On")
    try Hotkey("~*" key " up", RecordKeyUp, "On")
}
try Hotkey("~*WheelUp", RecordWheelUp, "On")
try Hotkey("~*WheelDown", RecordWheelDown, "On")
try Hotkey("~*WheelLeft", RecordWheelLeft, "On")
try Hotkey("~*WheelRight", RecordWheelRight, "On")

SetTimer(SampleMouse, moveSampleMs)
SetTimer(UpdateOverlayHud, 16)

ApplySettings(*) {
    global hkRecordStr, hkPlayStr, hkAbortStr, hkOverlayStr

    if (hkRecordStr != "")
        try Hotkey(hkRecordStr, "Off")
    if (hkPlayStr != "")
        try Hotkey(hkPlayStr, "Off")
    if (hkAbortStr != "")
        try Hotkey(hkAbortStr, "Off")
    if (hkOverlayStr != "")
        try Hotkey(hkOverlayStr, "Off")

    saved := myGui.Submit(false)
    hkRecordStr := saved.HkRecord
    hkPlayStr   := saved.HkPlay
    hkAbortStr  := saved.HkAbort
    hkOverlayStr := saved.HkOverlay

    if (hkRecordStr != "")
        try Hotkey(hkRecordStr, ToggleRecording, "On")
    if (hkPlayStr != "")
        try Hotkey(hkPlayStr, StartPlayback, "On")
    if (hkAbortStr != "")
        try Hotkey(hkAbortStr, AbortPlayback, "On")
    if (hkOverlayStr != "")
        try Hotkey(hkOverlayStr, ToggleOverlay, "On")
}

ToggleOverlay(*) {
    global overlayVisible, playing
    if !playing {
        Flash("Overlay toggle is only available during playback")
        return
    }
    if overlayVisible {
        HideOverlay()
        return
    }
    EnsureOverlay()
    ShowOverlay()
}

UpdateScreenMetrics() {
    global overlayOriginX, overlayOriginY, overlayWidth, overlayHeight
    overlayOriginX := SysGet(76)
    overlayOriginY := SysGet(77)
    overlayWidth   := SysGet(78)
    overlayHeight  := SysGet(79)
}

EnsureOverlay() {
    global overlayGui, hudGui, hudGuiCtrl, sideHudGui, sideHudCtrl
    global overlayOriginX, overlayOriginY, overlayWidth, overlayHeight
    if overlayGui
        return

    UpdateScreenMetrics()

    overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x8000020 +LastFound", "Macro Recorder Canvas Overlay")
    overlayGui.BackColor := "101018"
    overlayGui.MarginX := 0
    overlayGui.MarginY := 0
    overlayGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", overlayOriginX, overlayOriginY, overlayWidth, overlayHeight))
    WinSetTransparent(75, overlayGui.Hwnd)
    overlayGui.Hide()

    OnMessage(0x000F, OnPaintOverlay)

    hudGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x8000020", "Macro Cursor HUD")
    hudGui.BackColor := "101018"
    hudGui.MarginX := 5
    hudGui.MarginY := 5
    hudGuiCtrl := hudGui.Add("Text", "x5 y5 w200 h70 cFFFFFF", "")
    hudGuiCtrl.SetFont("s10 Bold", "Segoe UI")
    hudGui.Show("x0 y0 w210 h80 NoActivate")
    WinSetTransparent(210, hudGui.Hwnd)
    hudGui.Hide()

    sideHudGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x8000020", "Macro Side HUD")
    sideHudGui.BackColor := "000000"
    sideHudGui.MarginX := 10
    sideHudGui.MarginY := 10
    sideHudCtrl := sideHudGui.Add("Text", "x10 y10 w300 h270 cFFFFFF", "")
    sideHudCtrl.SetFont("s11", "Segoe UI")
    sideX := overlayOriginX + overlayWidth - 340
    sideY := overlayOriginY + 30
    sideHudGui.Show(Format("x{1} y{2} w320 h290 NoActivate", sideX, sideY))
    WinSetTransparent(210, sideHudGui.Hwnd)
    sideHudGui.Hide()
}

ShowOverlay() {
    global overlayGui, hudGui, sideHudGui, overlayVisible, overlayStartTick, overlayLastX, overlayLastY
    EnsureOverlay()
    overlayVisible := true
    overlayStartTick := A_TickCount
    MouseGetPos(&mx, &my)
    overlayLastX := mx
    overlayLastY := my

    WinShow(overlayGui.Hwnd)
    hudGui.Show("NoActivate")
    sideHudGui.Show("NoActivate")

    DllCall("user32\InvalidateRect", "ptr", overlayGui.Hwnd, "ptr", 0, "int", 1)
    UpdateOverlayHud()
}

HideOverlay() {
    global overlayGui, hudGui, sideHudGui, overlayVisible
    if !overlayGui
        return
    overlayVisible := false
    overlayGui.Hide()
    hudGui.Hide()
    sideHudGui.Hide()
}

ClearOverlay() {
    global overlayGui, overlayElements, overlayLastX, overlayLastY
    global overlayEventNumber, overlayLastLagMs, overlayLastEventType, overlayLastEventName, overlayLastEventAction
    global hudGuiCtrl, sideHudCtrl
    if !overlayGui
        return

    overlayElements := []
    MouseGetPos(&mx, &my)
    overlayLastX := mx
    overlayLastY := my
    overlayEventNumber := 0
    overlayLastLagMs := 0
    overlayLastEventType := ""
    overlayLastEventName := ""
    overlayLastEventAction := ""

    try hudGuiCtrl.Text := ""
    try sideHudCtrl.Text := ""

    hdc := DllCall("GetDC", "ptr", overlayGui.Hwnd, "ptr")
    if hdc {
        brush := DllCall("gdi32\CreateSolidBrush", "uint", 0x00181010, "ptr")
        rc := Buffer(16, 0)
        DllCall("user32\GetClientRect", "ptr", overlayGui.Hwnd, "ptr", rc)
        DllCall("user32\FillRect", "ptr", hdc, "ptr", rc, "ptr", brush)
        DllCall("gdi32\DeleteObject", "ptr", brush)
        DrawCenterGuidesOnDc(hdc)
        DllCall("ReleaseDC", "ptr", overlayGui.Hwnd, "ptr", hdc)
    }
}

OnPaintOverlay(wParam, lParam, msg, hwnd) {
    global overlayGui, overlayElements, overlayOriginX, overlayOriginY
    if (overlayGui && hwnd == overlayGui.Hwnd) {
        PAINTSTRUCT := Buffer(64, 0)
        hdc := DllCall("user32\BeginPaint", "ptr", hwnd, "ptr", PAINTSTRUCT, "ptr")
        if hdc {
            brush := DllCall("gdi32\CreateSolidBrush", "uint", 0x00181010, "ptr")
            rc := Buffer(16, 0)
            DllCall("user32\GetClientRect", "ptr", hwnd, "ptr", rc)
            DllCall("user32\FillRect", "ptr", hdc, "ptr", rc, "ptr", brush)
            DllCall("gdi32\DeleteObject", "ptr", brush)

            DrawCenterGuidesOnDc(hdc)
            for elem in overlayElements {
                if (elem.type == "line")
                    RenderLine(hdc, elem, overlayOriginX, overlayOriginY)
                else if (elem.type == "circle")
                    RenderCircle(hdc, elem, overlayOriginX, overlayOriginY)
                else if (elem.type == "square")
                    RenderSquare(hdc, elem, overlayOriginX, overlayOriginY)
            }
            DllCall("user32\EndPaint", "ptr", hwnd, "ptr", PAINTSTRUCT)
        }
        return 0
    }
}

DrawCenterGuidesOnDc(hdc) {
    global overlayWidth, overlayHeight
    if !hdc || overlayWidth <= 0 || overlayHeight <= 0
        return
    cx := overlayWidth // 2
    cy := overlayHeight // 2
    pen := DllCall("gdi32\CreatePen", "int", 0, "int", 1, "uint", 0x00808070, "ptr")
    old := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", pen, "ptr")
    DllCall("gdi32\MoveToEx", "ptr", hdc, "int", cx-24, "int", cy, "ptr", 0)
    DllCall("gdi32\LineTo", "ptr", hdc, "int", cx+24, "int", cy)
    DllCall("gdi32\MoveToEx", "ptr", hdc, "int", cx, "int", cy-24, "ptr", 0)
    DllCall("gdi32\LineTo", "ptr", hdc, "int", cx, "int", cy+24)
    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", old)
    DllCall("gdi32\DeleteObject", "ptr", pen)
}

OverlayMove(x, y) {
    global overlayLastX, overlayLastY, playbackDrawingActive
    if !playbackDrawingActive
        return
    if (overlayLastX >= 0 && (x != overlayLastX || y != overlayLastY))
        DrawTrailLine(overlayLastX, overlayLastY, x, y)
    overlayLastX := x
    overlayLastY := y
}

OverlayEvent(e, verifyMs, extraMs, eventNumber) {
    global overlayEventNumber, overlayLastLagMs, overlayLastEventType, overlayLastEventName, overlayLastEventAction, playbackDrawingActive

    overlayEventNumber := eventNumber
    overlayLastLagMs := extraMs
    overlayLastEventType := e.type
    overlayLastEventName := e.name
    overlayLastEventAction := e.action

    if !playbackDrawingActive
        return

    switch e.type {
        case "move":
            OverlayMove(e.x, e.y)

        case "wheel":
            OverlayMove(e.x, e.y)
            symbol := InStr(e.name, "Up") ? "↑" : InStr(e.name, "Down") ? "↓" : InStr(e.name, "Left") ? "←" : "→"
            DrawCircleMarker(e.x, e.y, symbol, 0xFFD166)

        case "key":
            if HasVal(["LButton","RButton","MButton","XButton1","XButton2"], e.name) {
                if (e.action == "Down") {
                    OverlayMove(e.x, e.y)
                    lbl := (e.name == "LButton") ? "L" : (e.name == "RButton") ? "R" : (e.name == "MButton") ? "M" : (e.name == "XButton1") ? "X1" : "X2"
                    clr := (e.name == "LButton") ? 0x7CFC00 : (e.name == "RButton") ? 0xFF4D4D : 0xFFD166
                    DrawCircleMarker(e.x, e.y, lbl, clr)
                }
            } else if (e.action == "Down") {
                MouseGetPos(&kx, &ky)
                OverlayMove(kx, ky)
                DrawSquareMarker(kx, ky, FormatKeyLabel(e.name), 0x6EC8FF)
            }
    }
    UpdateOverlayHud()
}

DrawTrailLine(x1, y1, x2, y2) {
    global overlayGui, overlayVisible, overlayOriginX, overlayOriginY, overlayElements
    elem := {type: "line", x1: x1, y1: y1, x2: x2, y2: y2, color: 0x00E0FFFF, width: 3}
    overlayElements.Push(elem)
    if overlayElements.Length > 2500
        overlayElements.RemoveAt(1)

    if (!overlayGui || !overlayVisible)
        return

    hdc := DllCall("GetDC", "ptr", overlayGui.Hwnd, "ptr")
    if !hdc
        return

    RenderLine(hdc, elem, overlayOriginX, overlayOriginY)
    DllCall("ReleaseDC", "ptr", overlayGui.Hwnd, "ptr", hdc)
}

DrawCircleMarker(x, y, text, colorHex) {
    global overlayGui, overlayVisible, overlayOriginX, overlayOriginY, overlayElements
    elem := {type: "circle", x: x, y: y, text: text, color: colorHex}
    overlayElements.Push(elem)
    if overlayElements.Length > 2000
        overlayElements.RemoveAt(1)

    if (!overlayGui || !overlayVisible)
        return

    hdc := DllCall("GetDC", "ptr", overlayGui.Hwnd, "ptr")
    if !hdc
        return

    RenderCircle(hdc, elem, overlayOriginX, overlayOriginY)
    DllCall("ReleaseDC", "ptr", overlayGui.Hwnd, "ptr", hdc)
}

DrawSquareMarker(x, y, text, colorHex) {
    global overlayGui, overlayVisible, overlayOriginX, overlayOriginY, overlayElements
    elem := {type: "square", x: x, y: y, text: text, color: colorHex}
    overlayElements.Push(elem)
    if overlayElements.Length > 2000
        overlayElements.RemoveAt(1)

    if (!overlayGui || !overlayVisible)
        return

    hdc := DllCall("GetDC", "ptr", overlayGui.Hwnd, "ptr")
    if !hdc
        return

    RenderSquare(hdc, elem, overlayOriginX, overlayOriginY)
    DllCall("ReleaseDC", "ptr", overlayGui.Hwnd, "ptr", hdc)
}

RenderLine(hdc, elem, originX, originY) {
    localX1 := elem.x1 - originX
    localY1 := elem.y1 - originY
    localX2 := elem.x2 - originX
    localY2 := elem.y2 - originY

    gdiColor := ToGdiColor(elem.color)
    pen := DllCall("gdi32\CreatePen", "int", 0, "int", elem.width, "uint", gdiColor, "ptr")
    oldPen := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", pen, "ptr")

    DllCall("gdi32\MoveToEx", "ptr", hdc, "int", localX1, "int", localY1, "ptr", 0)
    DllCall("gdi32\LineTo", "ptr", hdc, "int", localX2, "int", localY2)

    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldPen)
    DllCall("gdi32\DeleteObject", "ptr", pen)
}

RenderCircle(hdc, elem, originX, originY) {
    localX := elem.x - originX
    localY := elem.y - originY
    r := 16

    gdiColor := ToGdiColor(elem.color)
    pen := DllCall("gdi32\CreatePen", "int", 0, "int", 3, "uint", gdiColor, "ptr")
    oldPen := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", pen, "ptr")

    nullBrush := DllCall("gdi32\GetStockObject", "int", 5, "ptr")
    oldBrush := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", nullBrush, "ptr")

    DllCall("gdi32\Ellipse", "ptr", hdc, "int", localX - r, "int", localY - r, "int", localX + r, "int", localY + r)

    if (elem.text != "") {
        DllCall("gdi32\SetBkMode", "ptr", hdc, "int", 1)
        DllCall("gdi32\SetTextColor", "ptr", hdc, "uint", gdiColor)

        rc := Buffer(16, 0)
        NumPut("int", localX - r, rc, 0)
        NumPut("int", localY - r, rc, 4)
        NumPut("int", localX + r, rc, 8)
        NumPut("int", localY + r, rc, 12)

        DllCall("user32\DrawTextW", "ptr", hdc, "wstr", elem.text, "int", -1, "ptr", rc, "uint", 0x25)
    }

    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldPen)
    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldBrush)
    DllCall("gdi32\DeleteObject", "ptr", pen)
}

RenderSquare(hdc, elem, originX, originY) {
    localX := elem.x - originX
    localY := elem.y - originY
    s := 18

    gdiColor := ToGdiColor(elem.color)
    pen := DllCall("gdi32\CreatePen", "int", 0, "int", 3, "uint", gdiColor, "ptr")
    oldPen := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", pen, "ptr")

    nullBrush := DllCall("gdi32\GetStockObject", "int", 5, "ptr")
    oldBrush := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", nullBrush, "ptr")

    DllCall("gdi32\Rectangle", "ptr", hdc, "int", localX - s, "int", localY - s, "int", localX + s, "int", localY + s)

    if (elem.text != "") {
        DllCall("gdi32\SetBkMode", "ptr", hdc, "int", 1)
        DllCall("gdi32\SetTextColor", "ptr", hdc, "uint", gdiColor)

        rc := Buffer(16, 0)
        NumPut("int", localX - s, rc, 0)
        NumPut("int", localY - s, rc, 4)
        NumPut("int", localX + s, rc, 8)
        NumPut("int", localY + s, rc, 12)

        DllCall("user32\DrawTextW", "ptr", hdc, "wstr", elem.text, "int", -1, "ptr", rc, "uint", 0x25)
    }

    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldPen)
    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldBrush)
    DllCall("gdi32\DeleteObject", "ptr", pen)
}

ToGdiColor(rgbHex) {
    r := (rgbHex >> 16) & 0xFF
    g := (rgbHex >> 8) & 0xFF
    b := rgbHex & 0xFF
    return (b << 16) | (g << 8) | r
}

UpdateOverlayHud() {
    global overlayVisible, overlayGui, hudGui, hudGuiCtrl, sideHudGui, sideHudCtrl
    global overlayOriginX, overlayOriginY, overlayWidth, overlayHeight
    global overlayLastX, overlayLastY
    global overlayEventNumber, overlayLastLagMs, overlayLastEventType, overlayLastEventName, overlayLastEventAction
    global recording, playing, recStart, playbackStartTick, overlayStartTick, playbackDrawingActive

    MouseGetPos(&mx, &my)

    if (playing && playbackDrawingActive) {
        if (overlayLastX >= 0 && overlayLastY >= 0) {
            if (mx != overlayLastX || my != overlayLastY) {
                DrawTrailLine(overlayLastX, overlayLastY, mx, my)
            }
        }
        overlayLastX := mx
        overlayLastY := my
    }

    if !overlayVisible || !overlayGui
        return

    cx := mx - overlayOriginX
    cy := my - overlayOriginY

    elapsedMs := 0
    if recording {
        elapsedMs := A_TickCount - recStart
    } else if playing {
        elapsedMs := A_TickCount - playbackStartTick
    } else {
        elapsedMs := A_TickCount - overlayStartTick
    }
    elapsedSecStr := FormatElapsed(elapsedMs)

    hudW := 210
    hudH := 80
    gapX := 18
    gapY := 18

    hx := cx + gapX
    hy := cy + gapY

    if (hx + hudW > overlayWidth)
        hx := cx - hudW - gapX
    if (hy + hudH > overlayHeight)
        hy := cy - hudH - gapY
    if (hx < 0)
        hx := 0
    if (hy < 0)
        hy := 0

    screenHx := hx + overlayOriginX
    screenHy := hy + overlayOriginY

    hudGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", screenHx, screenHy, hudW, hudH))
    hudGuiCtrl.Text := Format("X: {1}    Y: {2}`nElapsed: {3}`nEvent: #{4}    Lag: {5} ms", mx, my, elapsedSecStr, overlayEventNumber, Round(overlayLastLagMs, 1))

    centerX := overlayOriginX + (overlayWidth // 2)
    centerY := overlayOriginY + (overlayHeight // 2)
    statusStr := recording ? "RECORDING" : playing ? "PLAYING" : "IDLE"
    sideHudCtrl.Text := Format(
        "MACRO OVERLAY [{1}]`n`n" .
        "CURSOR    X: {2}    Y: {3}`n" .
        "CENTER    X: {4}    Y: {5}`n" .
        "SCREEN    {6} x {7}`n" .
        "ELAPSED   {8}`n`n" .
        "EVENT     #{9}`n" .
        "LAG       {10} ms`n" .
        "TYPE      {11}`n" .
        "NAME      {12}`n" .
        "ACTION    {13}",
        statusStr, mx, my, centerX, centerY, overlayWidth, overlayHeight,
        elapsedSecStr, overlayEventNumber, Round(overlayLastLagMs, 1),
        overlayLastEventType, overlayLastEventName, overlayLastEventAction)
}

FormatElapsed(ms) {
    sec := ms / 1000
    mins := Floor(sec / 60)
    remSec := sec - (mins * 60)
    if mins > 0
        return Format("{:02d}:{:04.1f}s", mins, remSec)
    else
        return Format("{:.1f}s", remSec)
}

FormatKeyLabel(keyName) {
    static special := Map("Space", "␣", "Enter", "↵", "Tab", "⇥", "Backspace", "⌫", "Escape", "Esc", "Left", "←", "Right", "→", "Up", "↑", "Down", "↓", "Delete", "Del")
    if special.Has(keyName)
        return special[keyName]
    if StrLen(keyName) > 8
        return SubStr(keyName, 1, 8)
    return keyName
}

ToggleRecording(*) {
    global recording, events, recStart, playing, lastMouseX, lastMouseY
    global hkPlayCtrl, hkAbortCtrl, hkOverlayCtrl, chkDoLoop, edtLoopCount, btnExport, btnLoad
    global hkPlayStr, hkAbortStr, hkOverlayStr

    if playing {
        Flash("Can't record during playback")
        return
    }

    if !recording {
        events := []
        recording := true
        recStart := A_TickCount
        lastMouseX := -999999
        lastMouseY := -999999

        hkPlayCtrl.Enabled := false
        hkAbortCtrl.Enabled := false
        hkOverlayCtrl.Enabled := false
        chkDoLoop.Enabled := false
        edtLoopCount.Enabled := false
        btnExport.Enabled := false
        btnLoad.Enabled := false

        try Hotkey(hkPlayStr, "Off")
        try Hotkey(hkAbortStr, "Off")
        try Hotkey(hkOverlayStr, "Off")

        ToolTip("Recording...")
    } else {
        recording := false

        hkPlayCtrl.Enabled := true
        hkAbortCtrl.Enabled := true
        hkOverlayCtrl.Enabled := true
        chkDoLoop.Enabled := true
        edtLoopCount.Enabled := true
        btnLoad.Enabled := true
        if (events.Length > 0)
            btnExport.Enabled := true

        try Hotkey(hkPlayStr, StartPlayback, "On")
        try Hotkey(hkAbortStr, AbortPlayback, "On")
        try Hotkey(hkOverlayStr, ToggleOverlay, "On")

        Flash("Stopped — " events.Length " events captured")
    }
}

StartPlayback(*) {
    global events, playing, recording, stopPlaybackFlag, maxCatchupMs, latencyActive
    global latencyBaselineMs, latencyBaselineReady, playbackStartTick, playbackDrawingActive, overlayVisible
    global hkRecordCtrl, hkPlayCtrl, btnExport, btnLoad
    global hkRecordStr, hkPlayStr

    if playing {
        Flash("Already playing")
        return
    }
    if recording {
        Flash("Stop recording first")
        return
    }
    if events.Length = 0 {
        Flash("Nothing recorded yet")
        return
    }

    saved := myGui.Submit(false)
    doLoop := saved.DoLoop
    maxLoops := saved.LoopCount
    if (maxLoops = "" || maxLoops < 0)
        maxLoops := 0

    playing := true
    stopPlaybackFlag := false
    playbackDrawingActive := true
    latencyActive := false
    latencyBaselineMs := 0
    latencyBaselineReady := false
    playbackStartTick := A_TickCount
    loopCurrent := 0

    hkRecordCtrl.Enabled := false
    hkPlayCtrl.Enabled := false
    btnExport.Enabled := false
    btnLoad.Enabled := false

    try Hotkey(hkRecordStr, "Off")
    try Hotkey(hkPlayStr, "Off")

    EnsureOverlay()
    ClearOverlay()

    Loop {
        if stopPlaybackFlag
            break

        playbackDrawingActive := true
        loopStartTick := A_TickCount
        eventIndex := 0

        for e in events {
            if stopPlaybackFlag
                break
            eventIndex++

            if (eventIndex == 1) {
                DrawSquareMarker(e.x, e.y, "STR", 0x00FF00)
            }

            target := loopStartTick + e.t
            remaining := target - A_TickCount
            if remaining > 0 {
                Sleep(remaining)
                if stopPlaybackFlag
                    break
            } else if remaining < -maxCatchupMs {
                loopStartTick += -remaining
            }

            verifyMs := PlayEventVerified(e)
            extraMs := ResolveLatencyCompensation(verifyMs)
            if extraMs > 0
                loopStartTick += extraMs

            if playbackDrawingActive {
                OverlayEvent(e, verifyMs, extraMs, eventIndex)
            }

            if (eventIndex == events.Length) {
                DrawSquareMarker(e.x, e.y, "END", 0xFF0000)
                playbackDrawingActive := false
            }
        }

        loopCurrent++
        if (!doLoop || (maxLoops > 0 && loopCurrent >= maxLoops) || stopPlaybackFlag)
            break
    }

    playing := false
    playbackDrawingActive := false

    hkRecordCtrl.Enabled := true
    hkPlayCtrl.Enabled := true
    btnLoad.Enabled := true
    if (events.Length > 0)
        btnExport.Enabled := true

    try Hotkey(hkRecordStr, ToggleRecording, "On")
    try Hotkey(hkPlayStr, StartPlayback, "On")

    ClearOverlay()
    if overlayVisible {
        HideOverlay()
    }
}

AbortPlayback(*) {
    global stopPlaybackFlag
    stopPlaybackFlag := true
    ClearOverlay()
    if IsOverlayVisible()
        HideOverlay()
}

ExportMacro(*) {
    global events
    if (events.Length = 0) {
        Flash("No recorded macro to export")
        return
    }
    filePath := FileSelect("S16", A_ScriptDir "\macro.json", "Export Macro", "JSON Files (*.json);; Text Files (*.txt);; All Files (*.*)")
    if (filePath = "")
        return

    jsonStr := "[\n"
    for idx, e in events {
        cleanName := StrReplace(e.name, '"', '\"')
        jsonStr .= Format('  {{"t": {1}, "type": "{2}", "name": "{3}", "action": "{4}", "x": {5}, "y": {6}}}', e.t, e.type, cleanName, e.action, e.x, e.y)
        if (idx < events.Length)
            jsonStr .= ",\n"
        else
            jsonStr .= "\n"
    }
    jsonStr .= "]"

    try {
        if FileExist(filePath)
            FileDelete(filePath)
        FileAppend(jsonStr, filePath, "UTF-8")
        Flash("Macro exported successfully!")
    } catch Error as err {
        MsgBox("Failed to export macro: " err.Message, "Export Error", 48)
    }
}

LoadMacro(*) {
    global events, btnExport, playing, recording
    if (playing || recording) {
        Flash("Cannot load macro during recording or playback")
        return
    }
    filePath := FileSelect("1", A_ScriptDir, "Load Macro", "Macro Files (*.json; *.txt);; All Files (*.*)")
    if (filePath = "" || !FileExist(filePath))
        return

    try {
        content := FileRead(filePath, "UTF-8")
        newEvents := []

        pos := 1
        while RegExMatch(content, "s)\{[^{}]*\}", &objMatch, pos) {
            str := objMatch[0]

            tVal      := RegExMatch(str, 'i)"t"\s*:\s*(-?\d+)', &m1) ? Integer(m1[1]) : 0
            typeVal   := RegExMatch(str, 'i)"type"\s*:\s*"([^"]*)"', &m2) ? m2[1] : ""
            nameVal   := RegExMatch(str, 'i)"name"\s*:\s*"([^"]*)"', &m3) ? m3[1] : ""
            actionVal := RegExMatch(str, 'i)"action"\s*:\s*"([^"]*)"', &m4) ? m4[1] : ""
            xVal      := RegExMatch(str, 'i)"x"\s*:\s*(-?\d+)', &m5) ? Integer(m5[1]) : 0
            yVal      := RegExMatch(str, 'i)"y"\s*:\s*(-?\d+)', &m6) ? Integer(m6[1]) : 0

            if (typeVal != "" || m1) {
                newEvents.Push({
                    t: tVal,
                    type: typeVal,
                    name: StrReplace(nameVal, '\"', '"'),
                    action: actionVal,
                    x: xVal,
                    y: yVal
                })
            }
            pos := objMatch.Pos + objMatch.Len
        }

        if (newEvents.Length == 0) {
            Loop Parse, content, "`n", "`r" {
                line := Trim(A_LoopField)
                if (line == "" || SubStr(line, 1, 1) == "#" || InStr(line, "type"))
                    continue
                parts := StrSplit(line, ",")
                if (parts.Length >= 6) {
                    newEvents.Push({
                        t: Integer(Trim(parts[1])),
                        type: Trim(parts[2]),
                        name: Trim(parts[3]),
                        action: Trim(parts[4]),
                        x: Integer(Trim(parts[5])),
                        y: Integer(Trim(parts[6]))
                    })
                }
            }
        }

        if (newEvents.Length == 0) {
            MsgBox("No valid macro events found in file.", "Load Error", 48)
            return
        }

        events := newEvents
        btnExport.Enabled := true
        Flash("Loaded " events.Length " macro events!")
    } catch Error as err {
        MsgBox("Failed to load macro: " err.Message, "Load Error", 48)
    }
}

LogEvent(type, name, action) {
    global events, recStart
    MouseGetPos(&mx, &my)
    events.Push({t:A_TickCount-recStart, type:type, name:name, action:action, x:mx, y:my})
}

RecordKeyDown(hk) {
    if !ShouldRecord()
        return
    keyName := StrReplace(hk, "~*", "")
    if IsControlKey(keyName)
        return
    LogEvent("key", keyName, "Down")
}

RecordKeyUp(hk) {
    if !ShouldRecord()
        return
    keyName := StrReplace(StrReplace(hk, "~*", ""), " up", "")
    if IsControlKey(keyName)
        return
    LogEvent("key", keyName, "Up")
}

RecordWheelUp(*) {
    if ShouldRecord()
        LogEvent("wheel", "WheelUp", "")
}
RecordWheelDown(*) {
    if ShouldRecord()
        LogEvent("wheel", "WheelDown", "")
}
RecordWheelLeft(*) {
    if ShouldRecord()
        LogEvent("wheel", "WheelLeft", "")
}
RecordWheelRight(*) {
    if ShouldRecord()
        LogEvent("wheel", "WheelRight", "")
}

ShouldRecord() {
    global recording
    return recording
}

IsControlKey(keyName) {
    global hkRecordStr, hkPlayStr, hkAbortStr, hkOverlayStr
    if (keyName = GetBaseKey(hkRecordStr) || keyName = GetBaseKey(hkPlayStr) || keyName = GetBaseKey(hkAbortStr) || keyName = GetBaseKey(hkOverlayStr))
        return true
    return false
}

GetBaseKey(hk) {
    return RegExReplace(hk, "^[~*$!+^#]+")
}

SampleMouse() {
    global lastMouseX, lastMouseY
    if !ShouldRecord()
        return
    MouseGetPos(&mx, &my)
    if (mx != lastMouseX || my != lastMouseY) {
        lastMouseX := mx
        lastMouseY := my
        LogEvent("move", "", "")
    }
}

PlayEventVerified(e) {
    startVerify := A_TickCount
    switch e.type {
        case "move":
            MouseMove(e.x, e.y, 0)
            WaitForMouseAt(e.x, e.y)
        case "wheel":
            MouseMove(e.x, e.y, 0)
            WaitForMouseAt(e.x, e.y)
            Send("{" e.name "}")
        case "key":
            if HasVal(["LButton","RButton","MButton","XButton1","XButton2"], e.name) {
                MouseMove(e.x, e.y, 0)
                WaitForMouseAt(e.x, e.y)
            } else {
                MouseGetPos(&mx, &my)
            }
            Send("{" e.name " " e.action "}")
            WaitForKeyState(e.name, e.action)
    }
    return A_TickCount - startVerify
}

IsOverlayVisible() {
    global overlayVisible
    return overlayVisible
}

WaitForMouseAt(x, y) {
    global verifyTimeoutMs, verifyPollMs
    deadline := A_TickCount + verifyTimeoutMs
    Loop {
        MouseGetPos(&mx, &my)
        if (mx = x && my = y)
            return true
        if (A_TickCount >= deadline)
            return false
        Sleep(verifyPollMs)
    }
}

WaitForKeyState(keyName, action) {
    global verifyTimeoutMs, verifyPollMs
    wantDown := (action = "Down")
    deadline := A_TickCount + verifyTimeoutMs
    Loop {
        try state := GetKeyState(keyName, "P")
        catch
            return true
        if (state = wantDown)
            return true
        if (A_TickCount >= deadline)
            return false
        Sleep(verifyPollMs)
    }
}

ResolveLatencyCompensation(verifyMs) {
    global latencyBaselineMs, latencyBaselineReady, latencyBaselineAlpha
    global latencyExcessToleranceMs, latencyExcessCapMs
    if !latencyBaselineReady {
        latencyBaselineMs := verifyMs
        latencyBaselineReady := true
        return 0
    }
    excess := verifyMs - latencyBaselineMs
    latencyBaselineMs += (verifyMs - latencyBaselineMs) * latencyBaselineAlpha
    if excess <= latencyExcessToleranceMs
        return 0
    return Min(excess, latencyExcessCapMs)
}

HasVal(arr, val) {
    for v in arr
        if (v = val)
            return true
    return false
}

Flash(msg) {
    ToolTip(msg)
    SetTimer(() => ToolTip(), -2000)
}
