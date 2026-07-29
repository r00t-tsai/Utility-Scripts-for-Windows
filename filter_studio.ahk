#Requires AutoHotkey v2.0
#SingleInstance Force
global SettingsFile := A_ScriptDir . "\FilterStudio.ini"
OnExit(OnAppExit)

global FilterColors := Map(
    "Red",           "FF0000",
    "Yellow",        "FFFF00",
    "Blue",          "0000FF",

    "Orange",        "FF7F00",
    "Green",         "00FF00",
    "Violet",        "8B00FF",

    "Red-Orange",    "FF4500",
    "Yellow-Orange", "FFBF00",
    "Yellow-Green",  "7FFF00",
    "Blue-Green",    "00FF7F",
    "Blue-Violet",   "4B0082",
    "Red-Violet",    "FF00FF"
)

global Presets := Map(
    "Eye Health",   {Bright: 85,  Strength: 55, Color: "Orange"},
    "Read",         {Bright: 90,  Strength: 30, Color: "Yellow-Orange"},
    "Game",         {Bright: 80,  Strength: 15, Color: "Blue"},
    "Movie",        {Bright: 55,  Strength: 45, Color: "Red-Orange"},
    "Custom",       {Bright: 100, Strength: 0,  Color: "Orange"},
    "Reset / Off",  {Bright: 100, Strength: 0,  Color: "Orange"}
)
global PresetOrder := ["Eye Health", "Read", "Game", "Movie", "Custom", "Reset / Off"]

global ColorList := [
    "Red", "Yellow", "Blue",
    "Orange", "Green", "Violet",
    "Red-Orange", "Yellow-Orange", "Yellow-Green", "Blue-Green", "Blue-Violet", "Red-Violet"
]

global BrightnessMethod    := ""
global DDCMonitorHandles   := []
global GammaMonitorDCs     := []
global SuppressSave        := false
global Schedule            := []
global lastAppliedScheduleKey := ""
global ApplyingPreset      := false
global CurrentPresetSource := ""
global lastAppliedRampKey  := ""
global StartupEnabled      := false
global Uses24HourClock     := true
global StartMinimized      := false
global RequirementsMet     := {brightness: false, colorFilter: false}

A_IconTip := "Filter Studio"
Tray := A_TrayMenu
Tray.Delete()
Tray.Add("Show Filter Studio", (*) => mainGui.Show())
Tray.Add("Exit Filter Studio", (*) => ExitApp())
Tray.Default := "Show Filter Studio"

global mainGui := Gui("+AlwaysOnTop", "Filter Studio")
mainGui.MarginX := 15
mainGui.MarginY := 15
mainGui.SetFont("s10 bold", "Segoe UI")
mainGui.Add("Text", "w330 xm", "Quick Presets:")
mainGui.SetFont("s9 norm", "Segoe UI")
btnEye    := mainGui.Add("Button", "w160 h35 xm y+8", "Eye Health")
btnRead   := mainGui.Add("Button", "w160 h35 x+10 yp", "Reading")
btnGame   := mainGui.Add("Button", "w160 h35 xm y+8", "Gaming")
btnMovie  := mainGui.Add("Button", "w160 h35 x+10 yp", "Movie")
btnCustom := mainGui.Add("Button", "w160 h35 xm y+8", "Custom")
btnReset  := mainGui.Add("Button", "w160 h35 x+10 yp", "Turn Off")

mainGui.SetFont("s10 bold", "Segoe UI")
mainGui.Add("Text", "w330 xm y+18", "Adjustments:")
mainGui.SetFont("s9 norm", "Segoe UI")
mainGui.Add("Text", "w330 xm y+8", "Screen Brightness:")
global sliderBright := mainGui.Add("Slider", "w330 xm y+2 Range10-100 ToolTip", 100)
mainGui.Add("Text", "w330 xm y+8", "Filter Color:")
global ddlColor := mainGui.Add("DropDownList", "w330 xm y+2 Choose4", ColorList)
mainGui.Add("Text", "w330 xm y+8", "Filter Strength:")
global sliderStrength := mainGui.Add("Slider", "w330 xm y+2 Range0-100 ToolTip", 50)

mainGui.SetFont("s10 bold", "Segoe UI")
mainGui.Add("Text", "w330 xm y+18", "Preferences:")
mainGui.SetFont("s9 norm", "Segoe UI")
global chkNotify := mainGui.Add("Checkbox", "w330 xm y+6 Checked1", "Show notifications")
global chkStartup := mainGui.Add("Checkbox", "w330 xm y+6", "Run automatically at Windows startup")

mainGui.SetFont("s10 bold", "Segoe UI")
mainGui.Add("Text", "w330 xm y+18", "Auto Schedule:")
mainGui.SetFont("s9 norm", "Segoe UI")
global chkAutoSchedule := mainGui.Add("Checkbox", "w330 xm y+6", "Automatic Switching")
global lvSchedule := mainGui.Add("ListView", "w330 h100 xm y+8", ["Time", "Preset"])
lvSchedule.ModifyCol(1, 115)
lvSchedule.ModifyCol(2, 205)
btnSchedAdd    := mainGui.Add("Button", "w105 y+6 xm", "Add...")
btnSchedEdit   := mainGui.Add("Button", "w105 x+7 yp", "Edit...")
btnSchedRemove := mainGui.Add("Button", "w105 x+7 yp", "Remove")

global txtStatus := mainGui.Add("Text", "w330 xm y+14 cRed", "")

btnEye.OnEvent("Click", (*) => ApplyPreset("Eye Health"))
btnRead.OnEvent("Click", (*) => ApplyPreset("Read"))
btnGame.OnEvent("Click", (*) => ApplyPreset("Game"))
btnMovie.OnEvent("Click", (*) => ApplyPreset("Movie"))
btnCustom.OnEvent("Click", (*) => ApplyPreset("Custom"))
btnReset.OnEvent("Click", (*) => ApplyPreset("Reset / Off"))

sliderBright.OnEvent("Change", (*) => OnAdjustmentChanged())
sliderStrength.OnEvent("Change", (*) => OnAdjustmentChanged())
ddlColor.OnEvent("Change", (*) => OnAdjustmentChanged())
chkNotify.OnEvent("Click", (*) => SaveSettings())
chkAutoSchedule.OnEvent("Click", (*) => OnAutoScheduleToggled())
chkStartup.OnEvent("Click", (*) => OnStartupToggled())
btnSchedAdd.OnEvent("Click", (*) => OpenScheduleEditor(false))
btnSchedEdit.OnEvent("Click", (*) => OpenScheduleEditor(true))
btnSchedRemove.OnEvent("Click", (*) => RemoveScheduleEntry())

mainGui.OnEvent("Close", MinimizeToTray)

MinimizeToTray(*) {
    mainGui.Hide()
    if (chkNotify.Value = 1) {
        TrayTip("Filter Studio is minimized in the system tray.`nPress Ctrl + Shift + F to reopen.", "Filter Studio", 1)
    }
}

^+f:: {
    if WinExist("Filter Studio")
        mainGui.Hide()
    else
        mainGui.Show()
}

GammaMonitorDCs := GetMonitorDCs()
DetectBrightnessMethod()
Uses24HourClock := DetectSystemTimeFormat()

for arg in A_Args {
    if (StrLower(arg) = "/minimized" || StrLower(arg) = "-minimized") {
        StartMinimized := true
        break
    }
}

CheckMinimumRequirements()
LoadSettings()

if (StartMinimized) {
    MinimizeToTray()
} else {
    mainGui.Show("Center")
}

SchedulerTick()
SetTimer(SchedulerTick, 30000)


CheckMinimumRequirements() {
    global GammaMonitorDCs, BrightnessMethod, RequirementsMet
    global sliderBright, sliderStrength, ddlColor
    global btnEye, btnRead, btnGame, btnMovie, btnCustom, btnReset
    global txtStatus, StartMinimized

    RequirementsMet.colorFilter := (GammaMonitorDCs.Length > 0)
    RequirementsMet.brightness  := (BrightnessMethod != "")

    warnings := []

    if !RequirementsMet.colorFilter {
        warnings.Push("No display was detected that supports color/gamma adjustment. Color filtering is disabled.")
        ddlColor.Enabled       := false
        sliderStrength.Enabled := false
    }

    if !RequirementsMet.brightness {
        warnings.Push("No supported brightness control (WMI or DDC/CI) was found on this system. Brightness adjustment is disabled.")
        sliderBright.Enabled := false
    }

    if (!RequirementsMet.colorFilter && !RequirementsMet.brightness) {
        for b in [btnEye, btnRead, btnGame, btnMovie, btnCustom, btnReset]
            b.Enabled := false
        warnings.Push("Filter Studio cannot control this display. The app will stay open but presets are disabled.")
    }

    if (warnings.Length = 0)
        return

    summary := ""
    for i, w in warnings
        summary .= (i = 1 ? "" : "  |  ") . w
    txtStatus.Text := "⚠ " . summary

    fullMsg := "Filter Studio detected the following limitations on this system:`n`n"
    for w in warnings
        fullMsg .= "• " . w . "`n`n"
    fullMsg .= "You can keep using the parts of the app that are still available."

    if (StartMinimized) {
        TrayTip("Filter Studio - Limited functionality", fullMsg, 3)
    } else {
        MsgBox(fullMsg, "Filter Studio - Limited Functionality", "Icon!")
    }
}


ApplyPreset(name) {
    global Presets, sliderBright, sliderStrength, ddlColor, ApplyingPreset, CurrentPresetSource
    p := Presets[name]
    ApplyingPreset := true
    sliderBright.Value   := p.Bright
    sliderStrength.Value := p.Strength
    ddlColor.Text         := p.Color
    ApplyingPreset := false
    CurrentPresetSource := name
    CommitDisplayUpdate()
}

OnAdjustmentChanged() {
    global ApplyingPreset, CurrentPresetSource
    if (!ApplyingPreset) {
        SaveAsCustomPreset()
        CurrentPresetSource := "Custom"
    }
    RequestDisplayUpdate()
}

SaveAsCustomPreset() {
    global Presets, sliderBright, sliderStrength, ddlColor
    Presets["Custom"] := {Bright: sliderBright.Value, Strength: sliderStrength.Value, Color: ddlColor.Text}
    SaveCustomPresetToIni()
}

SaveCustomPresetToIni() {
    global Presets, SettingsFile
    try {
        c := Presets["Custom"]
        IniWrite(c.Bright,    SettingsFile, "CustomPreset", "Brightness")
        IniWrite(c.Strength,  SettingsFile, "CustomPreset", "Strength")
        IniWrite(c.Color,     SettingsFile, "CustomPreset", "Color")
    } catch as err {
        ToolTip("Could not save Custom preset: " . err.Message)
        SetTimer(() => ToolTip(), -3000)
    }
}

RequestDisplayUpdate() {
    SetTimer(CommitDisplayUpdate, -120)
}

CommitDisplayUpdate() {
    global sliderBright, sliderStrength, ddlColor, lastAppliedRampKey, RequirementsMet
    brightVal   := sliderBright.Value
    strengthVal := sliderStrength.Value
    colorName   := ddlColor.Text

    key := brightVal . "|" . strengthVal . "|" . colorName
    if (key != lastAppliedRampKey) {
        lastAppliedRampKey := key
        if RequirementsMet.brightness
            SetSystemBrightness(brightVal)
        if RequirementsMet.colorFilter {
            ramp := BuildGammaRamp(colorName, strengthVal)
            ApplyGammaRamp(ramp)
        }
    }

    SaveSettings()
}


GetMonitorDCs() {
    dcs := []
    i := 0
    Loop {
        size := 840
        buf := Buffer(size, 0)
        NumPut("UInt", size, buf, 0)
        if !DllCall("EnumDisplayDevicesW", "ptr", 0, "uint", i, "ptr", buf, "uint", 0)
            break
        stateFlags := NumGet(buf, 324, "UInt")
        deviceName := StrGet(buf.Ptr + 4, 32, "UTF-16")
        if (stateFlags & 0x1) {
            hdc := DllCall("gdi32\CreateDCW", "wstr", "DISPLAY", "wstr", deviceName, "ptr", 0, "ptr", 0, "ptr")
            if hdc
                dcs.Push(hdc)
        }
        i++
        if (i > 16)
            break
    }
    return dcs
}

BuildGammaRamp(colorName, strengthVal) {
    global FilterColors
    baseHex := FilterColors[colorName]
    sRatio  := strengthVal / 100.0
    rBase := Integer("0x" . SubStr(baseHex, 1, 2))
    gBase := Integer("0x" . SubStr(baseHex, 3, 2))
    bBase := Integer("0x" . SubStr(baseHex, 5, 2))

    rMul := (255 - sRatio * (255 - rBase)) / 255.0
    gMul := (255 - sRatio * (255 - gBase)) / 255.0
    bMul := (255 - sRatio * (255 - bBase)) / 255.0

    buf := Buffer(1536, 0)
    Loop 256 {
        idx := A_Index - 1
        rVal := Min(65535, Round(idx * 257 * rMul))
        gVal := Min(65535, Round(idx * 257 * gMul))
        bVal := Min(65535, Round(idx * 257 * bMul))
        NumPut("UShort", rVal, buf, idx * 2)
        NumPut("UShort", gVal, buf, 512 + idx * 2)
        NumPut("UShort", bVal, buf, 1024 + idx * 2)
    }
    return buf
}

ApplyGammaRamp(buf) {
    global GammaMonitorDCs
    for hdc in GammaMonitorDCs {
        DllCall("gdi32\SetDeviceGammaRamp", "ptr", hdc, "ptr", buf)
    }
}

RestoreLinearGamma() {
    global GammaMonitorDCs
    if (GammaMonitorDCs.Length = 0)
        return
    buf := Buffer(1536, 0)
    Loop 256 {
        idx := A_Index - 1
        val := Min(65535, idx * 257)
        NumPut("UShort", val, buf, idx * 2)
        NumPut("UShort", val, buf, 512 + idx * 2)
        NumPut("UShort", val, buf, 1024 + idx * 2)
    }
    ApplyGammaRamp(buf)
}


DetectBrightnessMethod() {
    global BrightnessMethod, DDCMonitorHandles

    try {
        wmi := ComObjGet("winmgmts:\\.\root\wmi")
        found := false
        for monitor in wmi.ExecQuery("SELECT * FROM WmiMonitorBrightnessMethods") {
            found := true
            break
        }
        if (found) {
            BrightnessMethod := "WMI"
            return
        }
    }

    handles := GetDDCMonitorHandles()
    if (handles.Length > 0) {
        DDCMonitorHandles := handles
        BrightnessMethod := "DDCCI"
        return
    }

    BrightnessMethod := ""
}

GetDDCMonitorHandles() {
    handles := []

    EnumProc(hMonitor, hdcMonitor, lprcMonitor, dwData) {
        numPhysical := 0
        if !DllCall("dxva2\GetNumberOfPhysicalMonitorsFromHMONITOR", "ptr", hMonitor, "uint*", &numPhysical)
            return true
        if (numPhysical = 0)
            return true

        structSize := 8 + 256
        buf := Buffer(structSize * numPhysical, 0)
        if !DllCall("dxva2\GetPhysicalMonitorsFromHMONITOR", "ptr", hMonitor, "uint", numPhysical, "ptr", buf)
            return true

        loop numPhysical {
            offset := (A_Index - 1) * structSize
            hPhysical := NumGet(buf, offset, "ptr")
            handles.Push(hPhysical)
        }
        return true
    }

    cb := CallbackCreate(EnumProc, "F", 4)
    DllCall("EnumDisplayMonitors", "ptr", 0, "ptr", 0, "ptr", cb, "ptr", 0)
    CallbackFree(cb)

    return handles
}

SetSystemBrightness(level) {
    global BrightnessMethod, DDCMonitorHandles
    level := Max(10, Min(100, level))

    if (BrightnessMethod = "WMI") {
        try {
            wmi := ComObjGet("winmgmts:\\.\root\wmi")
            for monitor in wmi.ExecQuery("SELECT * FROM WmiMonitorBrightnessMethods") {
                monitor.WmiSetBrightness(1, level)
            }
        } catch as err {
            ToolTip("Brightness control error (WMI): " . err.Message)
            SetTimer(() => ToolTip(), -3000)
        }
    } else if (BrightnessMethod = "DDCCI") {
        for hPhysical in DDCMonitorHandles {
            ok := DllCall("dxva2\SetVCPFeature", "ptr", hPhysical, "uchar", 0x10, "uint", level)
            if !ok {
                ToolTip("Brightness control error (DDC/CI): monitor did not accept the command.")
                SetTimer(() => ToolTip(), -3000)
            }
        }
    } else {
        ToolTip("No supported brightness control found on this system.")
        SetTimer(() => ToolTip(), -3000)
    }
}


OnAutoScheduleToggled() {
    SaveSettings()
    if (chkAutoSchedule.Value = 1)
        SchedulerTick()
}


OnStartupToggled() {
    global chkStartup, StartupEnabled
    StartupEnabled := chkStartup.Value = 1
    SetStartupRegistry(StartupEnabled)
    SaveSettings()
}

SetStartupRegistry(enable) {
    keyPath   := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
    valueName := "FilterStudio"
    try {
        if (enable) {
            cmd := A_IsCompiled ? '"' . A_ScriptFullPath . '" /minimized' : '"' . A_AhkPath . '" "' . A_ScriptFullPath . '" /minimized'
            RegWrite(cmd, "REG_SZ", keyPath, valueName)
        } else {
            RegDeleteKeyValueIfExists(keyPath, valueName)
        }
    } catch as err {
        ToolTip("Could not update startup setting: " . err.Message)
        SetTimer(() => ToolTip(), -3000)
    }
}

RegDeleteKeyValueIfExists(keyPath, valueName) {
    try RegDelete(keyPath, valueName)
}


DetectSystemTimeFormat() {
    try {
        val := RegRead("HKCU\Control Panel\International", "iTime")
        return (val = "1")
    } catch {
        return true
    }
}

OpenScheduleEditor(editMode) {
    global lvSchedule, Schedule, mainGui, PresetOrder, Uses24HourClock

    editIndex := 0
    if editMode {
        editIndex := lvSchedule.GetNext()
        if !editIndex {
            Flash("Select a schedule entry to edit first")
            return
        }
    }

    ed := Gui("+Owner" mainGui.Hwnd " +AlwaysOnTop", editMode ? "Edit Schedule Entry" : "Add Schedule Entry")
    ed.SetFont("s9", "Segoe UI")

    if (Uses24HourClock) {
        ed.Add("Text", "xm y12", "Time (24-hour):")
        edHour := ed.Add("Edit", "x+8 yp-3 w45 Number Center", "")
        ed.Add("Text", "x+4 yp3", ":")
        edMin  := ed.Add("Edit", "x+4 yp-3 w45 Number Center", "")
        ed.Add("Text", "xm y+4", "Hour 0-23, minute 0-59")
        ddlAmPm := ""
    } else {
        ed.Add("Text", "xm y12", "Time (12-hour):")
        edHour := ed.Add("Edit", "x+8 yp-3 w45 Number Center", "")
        ed.Add("Text", "x+4 yp3", ":")
        edMin   := ed.Add("Edit", "x+4 yp-3 w45 Number Center", "")
        ddlAmPm := ed.Add("DropDownList", "x+6 yp-3 w65", ["AM", "PM"])
        ed.Add("Text", "xm y+4", "Hour 1-12, minute 0-59")
    }

    ed.Add("Text", "xm y+15", "Preset:")
    ddlPreset := ed.Add("DropDownList", "x+8 yp-3 w150", PresetOrder)

    if editMode {
        entry := Schedule[editIndex]
        if (Uses24HourClock) {
            edHour.Text := entry.hour
        } else {
            h12 := Mod(entry.hour, 12)
            if (h12 = 0)
                h12 := 12
            edHour.Text := h12
            ddlAmPm.Text := (entry.hour < 12) ? "AM" : "PM"
        }
        edMin.Text     := entry.min
        ddlPreset.Text := entry.preset
    } else {
        if (Uses24HourClock) {
            edHour.Text := A_Hour
        } else {
            h12 := Mod(Integer(A_Hour), 12)
            if (h12 = 0)
                h12 := 12
            edHour.Text := h12
            ddlAmPm.Text := (Integer(A_Hour) < 12) ? "AM" : "PM"
        }
        edMin.Text := A_Min
        ddlPreset.Choose(1)
    }

    btnOK     := ed.Add("Button", "xm y+20 w110 Default", "OK")
    btnCancel := ed.Add("Button", "x+10 yp w110", "Cancel")

    btnOK.OnEvent("Click", (*) => SaveScheduleEntry(ed, edHour, edMin, ddlAmPm, ddlPreset, editMode, editIndex))
    btnCancel.OnEvent("Click", (*) => ed.Destroy())
    ed.OnEvent("Close", (*) => ed.Destroy())
    ed.Show((Uses24HourClock ? "w280" : "w320") . " h170")
}

SaveScheduleEntry(ed, edHour, edMin, ddlAmPm, ddlPreset, editMode, editIndex) {
    global Schedule, Uses24HourClock

    hRaw := Trim(edHour.Text)
    mRaw := Trim(edMin.Text)
    if (hRaw = "" || mRaw = "" || !IsInteger(hRaw) || !IsInteger(mRaw)) {
        Flash("Enter a valid hour and minute")
        return
    }

    h := Integer(hRaw)
    m := Integer(mRaw)
    if (m < 0 || m > 59) {
        Flash("Minute must be between 0 and 59")
        return
    }

    if (Uses24HourClock) {
        if (h < 0 || h > 23) {
            Flash("Hour must be between 0 and 23")
            return
        }
        hour24 := h
    } else {
        if (h < 1 || h > 12) {
            Flash("Hour must be between 1 and 12")
            return
        }
        hour24 := Mod(h, 12)
        if (ddlAmPm.Text = "PM")
            hour24 += 12
    }

    p := ddlPreset.Text
    if (p = "") {
        Flash("Choose a preset")
        return
    }

    for i, e in Schedule {
        if (e.hour = hour24 && e.min = m && (!editMode || i != editIndex)) {
            Flash("A schedule entry already exists at this time")
            return
        }
    }

    entry := {hour: hour24, min: m, preset: p}
    if editMode
        Schedule[editIndex] := entry
    else
        Schedule.Push(entry)

    SortSchedule()
    RefreshScheduleListView()
    SaveSettings()
    ed.Destroy()
}

RemoveScheduleEntry() {
    global lvSchedule, Schedule
    idx := lvSchedule.GetNext()
    if !idx {
        Flash("Select a schedule entry to remove")
        return
    }
    Schedule.RemoveAt(idx)
    RefreshScheduleListView()
    SaveSettings()
}

SortSchedule() {
    global Schedule
    n := Schedule.Length
    Loop n - 1 {
        i := A_Index
        Loop n - i {
            j := A_Index
            a := Schedule[j].hour * 60 + Schedule[j].min
            b := Schedule[j + 1].hour * 60 + Schedule[j + 1].min
            if (a > b) {
                tmp := Schedule[j]
                Schedule[j] := Schedule[j + 1]
                Schedule[j + 1] := tmp
            }
        }
    }
}

RefreshScheduleListView() {
    global lvSchedule, Schedule
    lvSchedule.Delete()
    for e in Schedule
        lvSchedule.Add(, FormatScheduleTime(e.hour, e.min), e.preset)
}

FormatScheduleTime(hour, min) {
    global Uses24HourClock
    if (Uses24HourClock)
        return Format("{:02}:{:02}", hour, min)
    h12 := Mod(hour, 12)
    if (h12 = 0)
        h12 := 12
    ampm := (hour < 12) ? "AM" : "PM"
    return Format("{:02}:{:02} {}", h12, min, ampm)
}

SchedulerTick() {
    global chkAutoSchedule, Schedule, lastAppliedScheduleKey, Presets
    if !IsSet(chkAutoSchedule) || chkAutoSchedule.Value != 1
        return
    if Schedule.Length = 0
        return

    nowMinutes := A_Hour * 60 + A_Min
    chosen := Schedule[Schedule.Length]
    for e in Schedule {
        entryMinutes := e.hour * 60 + e.min
        if (entryMinutes <= nowMinutes)
            chosen := e
    }

    key := Format("{:02}:{:02}|{}", chosen.hour, chosen.min, chosen.preset)
    if (key != lastAppliedScheduleKey) {
        lastAppliedScheduleKey := key
        if Presets.Has(chosen.preset)
            ApplyPreset(chosen.preset)
    }
}


SaveSettings() {
    global SuppressSave, Schedule, sliderBright, sliderStrength, ddlColor, chkNotify, chkAutoSchedule, chkStartup, Presets, SettingsFile
    if (SuppressSave)
        return
    try {
        IniWrite(sliderBright.Value, SettingsFile, "Settings", "Brightness")
        IniWrite(sliderStrength.Value, SettingsFile, "Settings", "Strength")
        IniWrite(ddlColor.Text, SettingsFile, "Settings", "Color")
        IniWrite(chkNotify.Value, SettingsFile, "Settings", "Notify")
        IniWrite(chkAutoSchedule.Value, SettingsFile, "Settings", "AutoSchedule")
        IniWrite(chkStartup.Value, SettingsFile, "Settings", "Startup")

        c := Presets["Custom"]
        IniWrite(c.Bright,    SettingsFile, "CustomPreset", "Brightness")
        IniWrite(c.Strength, SettingsFile, "CustomPreset", "Strength")
        IniWrite(c.Color,    SettingsFile, "CustomPreset", "Color")

        IniDelete(SettingsFile, "Schedule")
        IniWrite(Schedule.Length, SettingsFile, "Schedule", "Count")
        i := 0
        for e in Schedule {
            i++
            IniWrite(Format("{:02}:{:02}|{}", e.hour, e.min, e.preset), SettingsFile, "Schedule", "Item" i)
        }
    } catch as err {
        ToolTip("Could not save settings: " . err.Message)
        SetTimer(() => ToolTip(), -3000)
    }
}

LoadSettings() {
    global SuppressSave, Schedule, sliderBright, sliderStrength, ddlColor, chkNotify, chkAutoSchedule, chkStartup, StartupEnabled, Presets, SettingsFile, FilterColors

    if !FileExist(SettingsFile) {
        CommitDisplayUpdate()
        return
    }

    SuppressSave := true
    try {
        loadedBright := Integer(IniRead(SettingsFile, "Settings", "Brightness", 100))
        sliderBright.Value := Max(10, Min(100, loadedBright))

        loadedStrength := Integer(IniRead(SettingsFile, "Settings", "Strength", 50))
        sliderStrength.Value := Max(0, Min(100, loadedStrength))

        savedColor := IniRead(SettingsFile, "Settings", "Color", "Orange")
        if FilterColors.Has(savedColor)
            ddlColor.Text := savedColor
        chkNotify.Value       := Integer(IniRead(SettingsFile, "Settings", "Notify", 1))
        chkAutoSchedule.Value := Integer(IniRead(SettingsFile, "Settings", "AutoSchedule", 0))
        chkStartup.Value      := Integer(IniRead(SettingsFile, "Settings", "Startup", 0))
        StartupEnabled        := chkStartup.Value = 1
        SetStartupRegistry(StartupEnabled)

        customBright   := Max(10, Min(100, Integer(IniRead(SettingsFile, "CustomPreset", "Brightness", 100))))
        customStrength := Max(0, Min(100, Integer(IniRead(SettingsFile, "CustomPreset", "Strength", 0))))
        customColor    := IniRead(SettingsFile, "CustomPreset", "Color", "Orange")
        if !FilterColors.Has(customColor)
            customColor := "Orange"
        Presets["Custom"] := {Bright: customBright, Strength: customStrength, Color: customColor}

        count := Integer(IniRead(SettingsFile, "Schedule", "Count", 0))
        Schedule := []
        Loop count {
            raw := IniRead(SettingsFile, "Schedule", "Item" A_Index, "")
            if (raw = "")
                continue
            parts := StrSplit(raw, "|")
            if (parts.Length != 2) {
                continue
            }
            timeParts := StrSplit(parts[1], ":")
            if (timeParts.Length != 2 || !IsInteger(timeParts[1]) || !IsInteger(timeParts[2])) {
                continue
            }
            h := Integer(timeParts[1])
            m := Integer(timeParts[2])
            if (h < 0 || h > 23 || m < 0 || m > 59) {
                continue
            }
            if !Presets.Has(parts[2]) {
                continue
            }
            Schedule.Push({hour: h, min: m, preset: parts[2]})
        }
        SortSchedule()
        RefreshScheduleListView()
    } catch as err {
        ToolTip("Could not load saved settings: " . err.Message)
        SetTimer(() => ToolTip(), -3000)
    }
    SuppressSave := false

    CommitDisplayUpdate()
}

OnAppExit(*) {
    SaveSettings()
    RestoreLinearGamma()
    for hdc in GammaMonitorDCs
        DllCall("gdi32\DeleteDC", "ptr", hdc)
}

Flash(msg) {
    ToolTip(msg)
    SetTimer(() => ToolTip(), -2000)
}
