#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Mouse", "Screen"
SendMode "Event"          ; you should change to "Play" (SendPlay) if targeting games that block SendEvent

;  F9  = Start / Stop recording
;  F10 = Pause / Resume recording
;  F11 = Play back the last recording
;  F12 = Abort playback (emergency stop)

controlKeys := ["F9", "F10", "F11", "F12"]   ; never recorded themselves
mouseButtons := ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
moveSampleMs := 15                            ; how often to sample mouse position while recording
recording := false
paused    := false
playing   := false
stopPlaybackFlag := false
events := []
recStart := 0
pausedTotal := 0
pauseStartTick := 0
lastMouseX := -999999
lastMouseY := -999999

keyList := []
Loop Parse "abcdefghijklmnopqrstuvwxyz"
    keyList.Push(A_LoopField)
Loop 10
    keyList.Push(String(A_Index - 1))          ; "0".."9"
Loop 24
    keyList.Push("F" A_Index)                  ; F1..F24
Loop 10
    keyList.Push("Numpad" (A_Index - 1))        ; Numpad0..Numpad9

namedKeys := ["Space","Enter","Tab","Escape","Backspace","Delete","Insert",
    "Home","End","PgUp","PgDn","Up","Down","Left","Right",
    "LWin","RWin","LShift","RShift","LCtrl","RCtrl","LAlt","RAlt",
    "CapsLock","NumLock","ScrollLock","PrintScreen","Pause","AppsKey",
    "NumpadDot","NumpadAdd","NumpadSub","NumpadMult","NumpadDiv","NumpadEnter"]
for k in namedKeys
    keyList.Push(k)
for k in mouseButtons
    keyList.Push(k)
for k in keyList {
    if HasVal(controlKeys, k)
        continue
    try Hotkey("~*" k, RecordKeyDown, "On")
    try Hotkey("~*" k " up", RecordKeyUp, "On")
}
try Hotkey("~*WheelUp", RecordWheelUp, "On")
try Hotkey("~*WheelDown", RecordWheelDown, "On")
try Hotkey("~*WheelLeft", RecordWheelLeft, "On")
try Hotkey("~*WheelRight", RecordWheelRight, "On")

SetTimer(SampleMouse, moveSampleMs)

F9::ToggleRecording()
F10::TogglePause()
F11::StartPlayback()
F12::(stopPlaybackFlag := true)

ToggleRecording() {
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

TogglePause() {
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
    LogEvent("key", StrReplace(hk, "~*", ""), "Down")
}
RecordKeyUp(hk) {
    if !ShouldRecord()
        return
    name := StrReplace(StrReplace(hk, "~*", ""), " up", "")
    LogEvent("key", name, "Up")
}
RecordWheelUp(*)    { if ShouldRecord()
    LogEvent("wheel", "WheelUp", "") }
RecordWheelDown(*)  { if ShouldRecord()
    LogEvent("wheel", "WheelDown", "") }
RecordWheelLeft(*)  { if ShouldRecord()
    LogEvent("wheel", "WheelLeft", "") }
RecordWheelRight(*) { if ShouldRecord()
    LogEvent("wheel", "WheelRight", "") }

ShouldRecord() {
    global recording, paused
    return recording && !paused
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

StartPlayback() {
    global events, playing, recording, stopPlaybackFlag
    if recording {
        Flash("Stop recording first")
        return
    }
    if events.Length = 0 {
        Flash("Nothing recorded yet")
        return
    }
    playing := true
    stopPlaybackFlag := false
    ToolTip("▶ Playing...")

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

    playing := false
    Flash("Playback finished")
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
    SetTimer(() => ToolTip(), -1500)
}
