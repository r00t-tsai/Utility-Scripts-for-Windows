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
    global recording, paused
    return recording && !paused
}

IsControlKey(keyName) {
    global hkRecordStr, hkPauseStr, hkPlayStr, hkAbortStr
    if (keyName = GetBaseKey(hkRecordStr) || keyName = GetBaseKey(hkPauseStr) || keyName = GetBaseKey(hkPlayStr) || keyName = GetBaseKey(hkAbortStr))
        return true
    return false
}

GetBaseKey(hk) {
    return RegExReplace(hk, "^[~*$!+^#]+") ; Strips modifiers like Ctrl (^), Alt (!), etc.
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

PlayEvent(e) {
    switch e.type {
        case "move":
            MouseMove(e.x, e.y, 0)
        case "wheel":
            MouseMove(e.x, e.y, 0)
            Send("{" e.name "}")
        case "key":
            if HasVal(["LButton","RButton","MButton","XButton1","XButton2"], e.name)
                MouseMove(e.x, e.y, 0)
            Send("{" e.name " " e.action "}")
    }
}

HasVal(arr, val) {
    for v in arr
        if (v = val)
            return true
    return false
}

Flash(msg) {
    ToolTip(msg)
    SetTimer(() => ToolTip(), -2000) ; Hides tooltip after 2 seconds
}
