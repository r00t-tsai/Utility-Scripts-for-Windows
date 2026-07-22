#Requires AutoHotkey v2.0
#SingleInstance Force
global SettingsFile := A_ScriptDir . "\FilterStudio.ini"
OnExit(OnAppExit)
global colorOverlay := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
colorOverlay.BackColor := "FF7F00"

; SM_XVIRTUALSCREEN=76, SM_YVIRTUALSCREEN=77, SM_CXVIRTUALSCREEN=78, SM_CYVIRTUALSCREEN=79
global VScreenX := SysGet(76)
global VScreenY := SysGet(77)
global VScreenW := SysGet(78)
global VScreenH := SysGet(79)

colorOverlay.Show(Format("x{} y{} w{} h{} NoActivate Hide", VScreenX, VScreenY, VScreenW, VScreenH))

global FilterColors := Map(
    ; Primary Colors
    "Red",           "FF0000",
    "Yellow",        "FFFF00",
    "Blue",          "0000FF",

    ; Secondary Colors
    "Orange",        "FF7F00",
    "Green",         "00FF00",
    "Violet",        "8B00FF",

    ; Tertiary Colors
    "Red-Orange",    "FF4500",
    "Yellow-Orange", "FFBF00",
    "Yellow-Green",  "7FFF00",
    "Blue-Green",    "00FF7F",
    "Blue-Violet",   "4B0082",
    "Red-Violet",    "FF00FF"
)

global Presets := Map(
    "Eye Health",   {Bright: 70,  Strength: 70, Alpha: 35, Color: "Orange"},
    "Read",         {Bright: 85,  Strength: 40, Alpha: 25, Color: "Yellow"},
    "Game",         {Bright: 60,  Strength: 30, Alpha: 12, Color: "Blue"},
    "Movie",        {Bright: 60,  Strength: 50, Alpha: 18, Color: "Orange"},
    "Reset / Off",  {Bright: 100, Strength: 50, Alpha: 0,  Color: "Orange"}
)

global ColorList := [
    "Red", "Yellow", "Blue",
    "Orange", "Green", "Violet",
    "Red-Orange", "Yellow-Orange", "Yellow-Green", "Blue-Green", "Blue-Violet", "Red-Violet"
]

global BrightnessMethod := ""   ; "WMI", "DDCCI", or "" (none found)
global DDCMonitorHandles := []  ; cached physical monitor handles for DDC/CI
global SuppressSave := false    ; true while we're programmatically setting controls (e.g. on load)
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
btnEye   := mainGui.Add("Button", "w160 h35 xm y+8", "Eye Health")
btnRead  := mainGui.Add("Button", "w160 h35 x+10 yp", "Reading")
btnGame  := mainGui.Add("Button", "w160 h35 xm y+8", "Gaming")
btnMovie := mainGui.Add("Button", "w160 h35 x+10 yp", "Movie")
btnReset := mainGui.Add("Button", "w330 h35 xm y+8", "Turn Off")
mainGui.SetFont("s10 bold", "Segoe UI")
mainGui.Add("Text", "w330 xm y+18", "Adjustments:")
mainGui.SetFont("s9 norm", "Segoe UI")
mainGui.Add("Text", "w330 xm y+8", "Screen Brightness:")
global sliderBright := mainGui.Add("Slider", "w330 xm y+2 Range10-100 ToolTip", 100)
mainGui.Add("Text", "w330 xm y+8", "Filter Color:")
global ddlColor := mainGui.Add("DropDownList", "w330 xm y+2 Choose4", ColorList) ; Choose4 = Orange default
mainGui.Add("Text", "w330 xm y+8", "Filter Strength:")
global sliderStrength := mainGui.Add("Slider", "w330 xm y+2 Range10-100 ToolTip", 50)
mainGui.Add("Text", "w330 xm y+8", "Filter Opacity:")
global sliderAlpha := mainGui.Add("Slider", "w330 xm y+2 Range0-80 ToolTip", 0)
mainGui.SetFont("s10 bold", "Segoe UI")
mainGui.Add("Text", "w330 xm y+18", "Preferences:")
mainGui.SetFont("s9 norm", "Segoe UI")
global chkNotify := mainGui.Add("Checkbox", "w330 xm y+6 Checked1", "Show notification on minimize to tray")

btnEye.OnEvent("Click", (*) => ApplyPreset("Eye Health"))
btnRead.OnEvent("Click", (*) => ApplyPreset("Read"))
btnGame.OnEvent("Click", (*) => ApplyPreset("Game"))
btnMovie.OnEvent("Click", (*) => ApplyPreset("Movie"))
btnReset.OnEvent("Click", (*) => ApplyPreset("Reset / Off"))

sliderBright.OnEvent("Change", (*) => UpdateDisplay())
sliderStrength.OnEvent("Change", (*) => UpdateDisplay())
sliderAlpha.OnEvent("Change", (*) => UpdateDisplay())
ddlColor.OnEvent("Change", (*) => UpdateDisplay())
chkNotify.OnEvent("Click", (*) => SaveSettings())

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

DetectBrightnessMethod()
LoadSettings()
mainGui.Show("Center")

ApplyPreset(name) {
    p := Presets[name]
    sliderBright.Value   := p.Bright
    sliderStrength.Value := p.Strength
    sliderAlpha.Value    := p.Alpha
    ddlColor.Text        := p.Color
    UpdateDisplay()
}

UpdateDisplay() {
    brightVal   := sliderBright.Value   ; 10% to 100%
    strengthVal := sliderStrength.Value ; 10% to 100%
    alphaVal    := sliderAlpha.Value    ; 0% to 80%
    colorName   := ddlColor.Text
    baseHex     := FilterColors[colorName]

    SetSystemBrightness(brightVal)

    sRatio := strengthVal / 100.0
    rBase := Integer("0x" . SubStr(baseHex, 1, 2))
    gBase := Integer("0x" . SubStr(baseHex, 3, 2))
    bBase := Integer("0x" . SubStr(baseHex, 5, 2))

    rFinal := Integer(255 - sRatio * (255 - rBase))
    gFinal := Integer(255 - sRatio * (255 - gBase))
    bFinal := Integer(255 - sRatio * (255 - bBase))

    finalHex := Format("{:02X}{:02X}{:02X}", rFinal, gFinal, bFinal)
    colorOverlay.BackColor := finalHex

    filterAlphaByte := Integer(alphaVal * 2.55)
    if (filterAlphaByte > 0) {
        WinSetTransparent(filterAlphaByte, colorOverlay)
        colorOverlay.Show("NoActivate")
    } else {
        colorOverlay.Hide()
    }

    SaveSettings()
}

SaveSettings() {
    global SuppressSave
    if (SuppressSave)
        return
    try {
        IniWrite(sliderBright.Value, SettingsFile, "Settings", "Brightness")
        IniWrite(sliderStrength.Value, SettingsFile, "Settings", "Strength")
        IniWrite(sliderAlpha.Value, SettingsFile, "Settings", "Alpha")
        IniWrite(ddlColor.Text, SettingsFile, "Settings", "Color")
        IniWrite(chkNotify.Value, SettingsFile, "Settings", "Notify")
    } catch as err {
        ; Non-fatal: settings just won't persist this run
        ToolTip("Could not save settings: " . err.Message)
        SetTimer(() => ToolTip(), -3000)
    }
}

LoadSettings() {
    global SuppressSave
    if !FileExist(SettingsFile) {
        UpdateDisplay()
        return
    }

    SuppressSave := true
    try {
        sliderBright.Value   := Integer(IniRead(SettingsFile, "Settings", "Brightness", 100))
        sliderStrength.Value := Integer(IniRead(SettingsFile, "Settings", "Strength", 50))
        sliderAlpha.Value    := Integer(IniRead(SettingsFile, "Settings", "Alpha", 0))
        savedColor           := IniRead(SettingsFile, "Settings", "Color", "Orange")
        if FilterColors.Has(savedColor)
            ddlColor.Text := savedColor
        chkNotify.Value      := Integer(IniRead(SettingsFile, "Settings", "Notify", 1))
    } catch as err {
        ToolTip("Could not load saved settings: " . err.Message)
        SetTimer(() => ToolTip(), -3000)
    }
    SuppressSave := false

    UpdateDisplay() ; applies loaded values and saves normalized values back
}

OnAppExit(*) {
    SaveSettings()
    colorOverlay.Destroy()
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
