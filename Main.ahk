#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance, force
SetWorkingDir %A_ScriptDir%
#Include %A_ScriptDir%\Resources\Gdip_All.ahk


MultiInstanceTools := "RobloxAccountManager.exe,Roblox Account Manager.exe,RAM.exe,RobloxMulti.exe,MultiRoblox.exe,MultipleRoblox.exe,Multiple Roblox.exe,Bloxstrap.exe"

Loop, Parse, MultiInstanceTools, `,
{
    Process, Exist, %A_LoopField%
    if (ErrorLevel > 0)
    {
        MsgBox, 48, Error,
        (
Conflicting program detected:
%A_LoopField%

For this script to work properly, please close all Roblox multi-client utilities.
Please close them and try again.
        )
        ExitApp
    }
}


pToken := Gdip_Startup()
OnExit, CleanupGdip


global AppDataOpt := A_AppData "\UltimateMacro\Options\TDSMacro"
global LocalSettingsPath := A_WorkingDir "\Settings.tds"
global AppDataSettingsPath := AppDataOpt "\Settings.tds"
global RecordingsDir := A_AppData "\UltimateMacro\TDSMacro\Recordings"
global StateFile := A_AppData "\UltimateMacro\TDSMacro\state.ini"
global ShowIndicators := true

IfNotExist, %AppDataOpt%
    FileCreateDir, %AppDataOpt%
IfNotExist, %RecordingsDir%
    FileCreateDir, %RecordingsDir%

if FileExist(AppDataSettingsPath)
    global SettingsFile := AppDataSettingsPath
else
    global SettingsFile := LocalSettingsPath


global LogLines := []                
global OverlayHWND                   
global OverlayBitmap                 
global OverlayGraphics               
global OverlayWidth := 500
global OverlayHeight := 200
global OverlayX := 1400
global OverlayY := 820

global ChainKey, BeatKey, CaravanKey, TimeScaleMode, UseTimeScale, TimeScaleMultiplier
IniRead, ChainKey, %SettingsFile%, Hotkeys, Chain, C
IniRead, BeatKey, %SettingsFile%, Hotkeys, Beat, B
IniRead, CaravanKey, %SettingsFile%, Hotkeys, Caravan, J
IniRead, TimeScaleMode, %SettingsFile%, Options, TimeScaleMode, OFF
global DebugConsole := "OFF"              
IniRead, DebugConsole, %SettingsFile%, Options, DebugConsole, ON  
if (DebugConsole = 1)
    DebugConsole := "ON"
else if (DebugConsole = 0)
    DebugConsole := "OFF"

if (TimeScaleMode = "1.5x") {
    UseTimeScale := true, TimeScaleMultiplier := 1.5
} else if (TimeScaleMode = "2x") {
    UseTimeScale := true, TimeScaleMultiplier := 2
} else {
    UseTimeScale := false, TimeScaleMultiplier := 1
}

if (DebugConsole = "ON")
    ShowDebugConsole()

global map := "", difficulty := "", requiredTowers := ""
global autoChain := "OFF", autoCaravan := "OFF", autoDropTheBeat := "OFF"
global Commander := false, AutoSkip := "ON", moveDown := false
global unfocusX := 150, unfocusY := 200
global Towers := {}, RecordedSteps := [], Recording := false, RunningStrategy := false
global chainInterval := 10, caravanInterval := 20
global modifiers := ""

IconPath := A_WorkingDir "\icon.ico"
if FileExist(IconPath)
    Menu, Tray, Icon, %IconPath%

IniRead, autoRun, %StateFile%, State, Running, 0
IniRead, autoStrat, %StateFile%, State, Strategy, %A_Space%

if (autoRun = 1 && autoStrat != "" && FileExist(autoStrat)) {
    LoadStrategyFile(autoStrat)
    GuiControl,, CurrentStrat, %autoStrat%
    Gui, Main:Hide
    RunningStrategy := true
    WinActivate, ahk_exe RobloxPlayerBeta.exe
    RunStrategy()
    RunningStrategy := false
    Gui, Main:Show
    IniWrite, 0, %StateFile%, State, Running
}

OnMessage(0x0201, "WM_LBUTTONDOWN")
WM_LBUTTONDOWN() {
    PostMessage, 0xA1, 2,,, A
}

Gui, Main:New, +LastFound +AlwaysOnTop -Caption +Border
Gui, Color, 121212

Gui, Add, Progress, x0 y0 w400 h3 Background3A86FF vAccent, 0 

if FileExist(IconPath)
    Gui, Add, Picture, x20 y20 w32 h32, %IconPath%

Gui, Font, s16 w600 cFFFFFF, Bahnschrift
Gui, Add, Text, x65 y22 w200 vTitle, TDS MACRO

Gui, Font, s14 w400 cFFFFFF, Segoe UI
Gui, Add, Text, x335 y18 gMinimizeMain +Center w25 h25, —
Gui, Add, Text, x365 y18 gOpenSettings +Center w25 h25, ⚙

Gui, Add, Progress, x20 y65 w360 h1 Background333333, 0

Gui, Font, s9 w600 c3A86FF, Bahnschrift
Gui, Add, Text, x25 y85, STRATEGIES (.STRAT files)

Gui, Font, s10 w400 cFFFFFF, Consolas
Gui, Add, Text, x25 y110 w275 h26 vCurrentStrat Right +0x400000 Background2A2A2A cWhite

Gui, Font, s9 w400, Bahnschrift
Gui, Add, Button, x310 y109 w65 h28 gSelectStrat, BROWSE

Gui, Font, s11 w600 cFFFFFF, Bahnschrift
Gui, Add, Button, x25 y160 w170 h45 gStartStrategy Default, START STRATEGY
Gui, Add, Button, x205 y160 w170 h45 gStartRecordGUI, RECORD

Gui, Font, s9 w400, Bahnschrift
Gui, Add, Button, x25 y215 w350 h32 gStopRecord vStopButton Hidden, STOP RECORDING

Gui, Font, s8 w400 c444444, Segoe UI
Gui, Add, Text, x0 y260 w400 Center, PRESS ESC TO EXIT
Gui, Show, w400 h285, TDS Macro
return


IniRead, autoRun, %StateFile%, State, Running, 0
IniRead, autoStrat, %StateFile%, State, Strategy, %A_Space%
if (autoRun = 1 && autoStrat != "" && FileExist(autoStrat)) {
    Gui, Main:Hide
    LoadStrategyFile(autoStrat)
    RunningStrategy := true
    WinActivate, ahk_exe RobloxPlayerBeta.exe
    RunStrategy()
    RunningStrategy := false
    Gui, Main:Show
    IniWrite, 0, %StateFile%, State, Running
}

#If RunningStrategy
    Esc::
        DeleteAllIndicators()
        IniWrite, 0, %StateFile%, State, Running
        Reload
    return
#If

Esc::
    ExitApp
^r::Reload

StartStrategy:
    Gui, Main:Submit, NoHide
    GuiControlGet, stratText,, CurrentStrat
    if (stratText != "") {
        stratFile := stratText
        if !FileExist(stratFile) {
            ModernMsgBox("Error", "Strategy file not found:`n" stratFile, "OK", "Red")
            return
        }
        LoadStrategyFile(stratFile)
        if (requiredTowers != "")
            ModernMsgBox("Required Towers", requiredTowers, "OK", "Blue")
        IniWrite, 1, %StateFile%, State, Running
        IniWrite, %stratFile%, %StateFile%, State, Strategy
        Gui, Main:Hide
        RunningStrategy := true
        RunStrategy()
    }
    else {
        ModernMsgBox("Warning", "Select a strategy file first!", "OK", "Red")
    }
return

SelectStrat:
    FileSelectFile, stratFile, 3, %RecordingsDir%, Выберите файл стратегии, Strategy (*.strat)
    if (stratFile != "") {
        GuiControl,, CurrentStrat, %stratFile%
        LoadStrategyFile(stratFile)
    }
return

StartRecordGUI:
    ShowSettingsGUI()
return

StopRecord:
    if (!Recording)
        return
    Recording := false
    Gui, Main:Font, s16 w600 cFFFFFF, Bahnschrift
    GuiControl, Main:Font, Title
    GuiControl, Main:, Title, TDS MACRO
    GuiControl, Main:Hide, StopButton

    DeleteAllIndicators()
    if (ModernMsgBox("Save", "Save the recorded strategy?", "YES|NO", "Blue") = "YES")
    {
        InputBox, fileName, Save, File name (without .strat):,,,,,,,,MyStrategy
        if ErrorLevel
        {
            Gui, Main:Show
            return
        }
        filePath := RecordingsDir . "\" . fileName . ".strat"
        FileDelete, %filePath%
        FileAppend, [Settings]`nmap=%map%`ndifficulty=%difficulty%`nrequiredTowers=%requiredTowers%`nmodifiers=%modifiers%`nchainInterval=%chainInterval%`ncaravanInterval=%caravanInterval%`nautoChain=%autoChain%`nautoCaravan=%autoCaravan%`nautoDropTheBeat=%autoDropTheBeat%`nautoSkip=%AutoSkip%`nmoveDown=%moveDown%`n`n[Steps]`n, %filePath%
        for i, step in RecordedSteps
            FileAppend, %step%`n, %filePath%
        LogToConsole("Strategy saved: " . filePath)
        GuiControl,, CurrentStrat, %filePath%
    }
    else
    {
        LogToConsole("Recording cancelled, strategy not saved")
        GuiControl,, CurrentStrat, (recording cancelled)
    }
    Gui, Main:Show
return

MinimizeMain:
    Gui, Main:Minimize
return


OpenSettings:
    Gui, Settings:New, +AlwaysOnTop -Caption +Border +OwnerMain
    Gui, Color, 1A1A1A, 2A2A2A 
    Gui, Add, Progress, x0 y0 w340 h2 Background3A86FF, 0
    Gui, Font, s12 w600 cFFFFFF, Bahnschrift
    Gui, Add, Text, x20 y15 w300, SETTINGS

    Gui, Font, s10 w400 c888888, Bahnschrift
    Gui, Add, Text, x20 y55, Commander (Call of Arms):
    Gui, Font, s10 w600 cFFFFFF
    Gui, Add, Edit, x220 y52 w60 h24 vChainKey Center -E0x200, %ChainKey%
    Gui, Add, Button, x290 y51 w30 h26 gHelpChain, ?

    Gui, Font, s10 w400 c888888
    Gui, Add, Text, x20 y95, DJ (Drop The Beat):
    Gui, Font, s10 w600 cFFFFFF
    Gui, Add, Edit, x220 y92 w60 h24 vBeatKey Center -E0x200, %BeatKey%
    Gui, Add, Button, x290 y91 w30 h26 gHelpBeat, ?

    Gui, Font, s10 w400 c888888
    Gui, Add, Text, x20 y135, Support Caravan:
    Gui, Font, s10 w600 cFFFFFF
    Gui, Add, Edit, x220 y132 w60 h24 vCaravanKey Center -E0x200, %CaravanKey%
    Gui, Add, Button, x290 y131 w30 h26 gHelpCaravan, ?

    Gui, Font, s10 w400 c888888
    Gui, Add, Text, x20 y175, Timescale:
    Gui, Add, DropDownList, x160 y172 w80 vTimeScaleMode, OFF|1.5x|2x
    GuiControl, ChooseString, TimeScaleMode, %TimeScaleMode%
    Gui, Font, s9 w400 cFFFFFF
    Gui, Add, Button, x250 y171 w70 h26 gHelpTimeScale, INFO


    Gui, Font, s10 w400 c2e7d04
    Gui, Add, Text, x20 y215, Debug Console
    Gui, Font, s10 w400 cFFFFFF

    dcChecked := (DebugConsole = "ON") ? 1 : 0
    Gui, Add, Checkbox, x115 y216 vDebugConsole Checked%dcChecked%

    Gui, Font, s11 w600 cFFFFFF
    Gui, Add, Button, x20 y260 w300 h40 gSaveSettings Default, SAVE CHANGES
    Gui, Font, s8 c444444
    Gui, Show, w340 h320, Hotkey & TimeScale Settings
return

SaveSettings:
    Gui, Settings:Submit, NoHide
    ChainKey   := SubStr(RegExReplace(ChainKey,   "\s", ""), 1, 1)
    BeatKey    := SubStr(RegExReplace(BeatKey,    "\s", ""), 1, 1)
    CaravanKey := SubStr(RegExReplace(CaravanKey, "\s", ""), 1, 1)
    if (ChainKey = "")
        ChainKey := "C"
    if (BeatKey = "")
        BeatKey := "B"
    if (CaravanKey = "")
        CaravanKey := "J"
    if (TimeScaleMode = "")
        TimeScaleMode := "OFF"
    if (DebugConsole = "")    
        DebugConsole := "OFF"

    IniWrite, %ChainKey%, %SettingsFile%, Hotkeys, Chain
    IniWrite, %BeatKey%, %SettingsFile%, Hotkeys, Beat
    IniWrite, %CaravanKey%, %SettingsFile%, Hotkeys, Caravan
    IniWrite, %TimeScaleMode%, %SettingsFile%, Options, TimeScaleMode

    if (DebugConsole = 1 || DebugConsole = "ON")
        DebugConsole := "ON"
    else
        DebugConsole := "OFF"

    IniWrite, %DebugConsole%, %SettingsFile%, Options, DebugConsole  

    if (TimeScaleMode = "1.5x") {
        UseTimeScale := true, TimeScaleMultiplier := 1.5
    } else if (TimeScaleMode = "2x") {
        UseTimeScale := true, TimeScaleMultiplier := 2
    } else {
        UseTimeScale := false, TimeScaleMultiplier := 1
    }

    if (DebugConsole = "ON")
        ShowDebugConsole()
    else
        HideDebugConsole()

    SyncSettings()
    Gui, Settings:Destroy
return

HelpChain:
ModernMsgBox("Info", "Configure hotkey for Commander's 'Call of Arms'.", "OK", "Blue")
return
HelpBeat:
ModernMsgBox("Info", "Configure hotkey for DJ's 'Drop The Beat'.", "OK", "Blue")
return
HelpCaravan:
ModernMsgBox("Info", "Configure hotkey for the 'Support Caravan'.", "OK", "Blue")
return
HelpTimeScale:
    ModernMsgBox("TimeScale Info", "1.5x — more stable and recommended for most cases.`n2x — requires special strategies but is much more effective.", "OK", "Blue")
return


SettingsGuiEscape:
    Gui, Settings:Destroy
return


ShowSettingsGUI() {
    global
    Gui, StrategySettings:New, +AlwaysOnTop -Caption +Border +LastFound, Strategy Setup
    Gui, Color, 1A1A1A, 2A2A2A 
    
    Gui, Add, Progress, x0 y0 w350 h2 Background3A86FF, 0

    Gui, Font, s12 w600 cFFFFFF, Bahnschrift
    Gui, Add, Text, x20 y15 w310 Center, STRATEGY CONFIGURATION

    Gui, Font, s9 w600 c3A86FF, Bahnschrift
    Gui, Add, Text, x20 y55, MAIN PARAMETERS
    Gui, Add, Progress, x20 y75 w310 h1 Background333333, 0

    Gui, Font, s10 w400 c888888, Bahnschrift
    Gui, Add, Text, x25 y85, Map:
    Gui, Add, Text, x25 y120, Difficulty:
    Gui, Add, Text, x25 y155, Towers:
    Gui, Add, Text, x25 y190, Modifiers:

    Gui, Font, s10 w600 cFFFFFF
    Gui, Add, Edit, x120 y82 w210 h24 vMap -E0x200 Center, %map%
    Gui, Font, s10 w400 c888888, Bahnschrift
    Gui, Add, DropDownList, x120 y117 w210 vDifficulty, Easy|Casual|Intermediate|Molten|Fallen|Frost|Hardcore|Pizza Party|Badlands II|Polluted Wastelands II
    GuiControl, ChooseString, Difficulty, %difficulty%
    Gui, Font, s10 w600 cFFFFFF    
    Gui, Add, Edit, x120 y152 w210 h24 vRequiredTowers -E0x200 Center, %requiredTowers%
    Gui, Add, Edit, x120 y187 w210 h24 vModifiers -E0x200 Center, %modifiers%

    Gui, Font, s9 w600 c3A86FF, Bahnschrift
    Gui, Add, Text, x20 y230, AUTOMATION & FEATURES
    Gui, Add, Progress, x20 y250 w310 h1 Background333333, 0

    Gui, Font, s10 w400 cFFFFFF, Bahnschrift
    Gui, Add, Checkbox, x25 y265 vAutoChain Checked%autoChain%, Auto-Chain
    Gui, Add, Text, x175 y265 c888888, Interval:
    Gui, Add, Edit, x255 y262 w75 h22 vChainInterval -E0x200 Center, %chainInterval%

    Gui, Add, Checkbox, x25 y295 vAutoCaravan Checked%autoCaravan%, Auto-Caravan
    Gui, Add, Text, x175 y295 c888888, Interval:
    Gui, Add, Edit, x255 y292 w75 h22 vCaravanInterval -E0x200 Center, %caravanInterval%

    Gui, Add, Checkbox, x25 y325 vAutoDropTheBeat Checked%autoDropTheBeat%, Auto-Drop Beat (DJ)
    
    Gui, Add, Checkbox, x25 y355 vAutoSkip Checked%AutoSkip%, Auto-Skip Waves
    Gui, Add, Checkbox, x195 y355 vMoveDown Checked%moveDown%, Move Down
    Gui, Add, Button, x288 y353 w22 h22 gHelpMoveDown, ?

    Gui, Font, s11 w600 cFFFFFF, Bahnschrift
    Gui, Add, Button, x20 y400 w150 h45 gStrategySettingsOK Default, START RECORD
    Gui, Add, Button, x180 y400 w150 h45 gStrategySettingsCancel, CANCEL

    Gui, Show, w350 h470, Strategy Setup
    WinWaitClose, Strategy Setup
    return


    HelpMoveDown:
        HelpText := "With this feature, the macro will move you down to get a better view of the map.`n`n"
        HelpText .= "Turn this ON if you are 100% sure the map you chose has a bad spawn point"
        ModernMsgBox("Move Down Info", HelpText, "OK", "Blue")
    return

    StrategySettingsOK:
        Gui, StrategySettings:Submit
        map := Map
        difficulty := Difficulty
        requiredTowers := RequiredTowers
        autoChain := AutoChain ? "ON" : "OFF"
        autoCaravan := AutoCaravan ? "ON" : "OFF"
        autoDropTheBeat := AutoDropTheBeat ? "ON" : "OFF"
        AutoSkip := AutoSkip ? "ON" : "OFF"
        moveDown := MoveDown
        chainInterval := (ChainInterval is number) ? ChainInterval : 10
        caravanInterval := (CaravanInterval is number) ? CaravanInterval : 20
        modifiers := Modifiers
        
        Commander := false
        Gui, StrategySettings:Destroy
        Recording := true
        RecordedSteps := []
        Towers := {}
        DeleteAllIndicators()

        Gui, Main:Font, s16 w600 cFF0000, Bahnschrift
        GuiControl, Main:Font, Title
        GuiControl, Main:, Title, TDS MACRO 🔴
        GuiControl, Main:Show, StopButton

        LogToConsole("Recording started:")
        LogToConsole("- MButton: place tower")
        LogToConsole("- Ctrl+U: upgrade")
        LogToConsole("- Ctrl+D: set DJ track")
        LogToConsole("- Ctrl+T: Align Camera")
        LogToConsole("- Ctrl+X: Sell Tower")
        LogToConsole("- Ctrl+B: Delete tower (Cancel)")
        LogToConsole("- Ctrl+X: Sell tower")

        ModernMsgBox("Recording", "Recording enabled:`n- MButton: place tower`n- Ctrl+U: upgrade`n- Ctrl+D: set DJ track`n- Ctrl+T: Align Camera`n- Ctrl+B: Delete tower (Cancel)`n- Ctrl+X: Sell tower", "OK", "Blue")
    return

    StrategySettingsCancel:
        Gui, StrategySettings:Destroy
    return
}


~MButton::
    if (!Recording)
        return

    WinMinimize, TDS Macro
    MouseGetPos, mx, my
    InputBox, slot, Слот (1-5), Enter the tower slot number (1-5):,,,,,,,,1
    if ErrorLevel
        return
    suggestedID := GetNextNumericID()
    InputBox, towerID, ID башни, Enter a specific tower id:,,,,,,,,%suggestedID%
    if ErrorLevel
        return
    slotX := (slot = 1 ? 800 : slot = 2 ? 890 : slot = 3 ? 980 : slot = 4 ? 1070 : 1160)
    slotY := 1000
    Click, %slotX%, %slotY%
    Sleep, 200
    Click, %mx%, %my%
    Sleep, 200
    RecordedSteps.Push("SpawnTower(" . mx . ", " . my . ", " . slot . ", " . towerID . ")")
    Towers[towerID] := {x: mx, y: my, slot: slot, level: 0}
    UpdateTowerIndicator(towerID)
    LogToConsole("Recorded tower " . towerID . " (slot " . slot . ")")
return

^u::
    MouseGetPos, mx, my
    closestID := FindClosestTower(mx, my)
    if (closestID != "") {
        Towers[closestID].level += 1
        UpdateTowerIndicator(closestID)
        if (Recording) {
            RecordedSteps.Push("UpgradeTower(" . closestID . ")")
            LogToConsole("Recorded upgrade tower " . closestID . " (level " . Towers[closestID].level . ")")
            if (Towers[closestID].level >= 2 && RegExMatch(closestID, "i)^Commander\d*$") && !Commander) {
                Commander := true
                if (!HasStep("Commander := true"))
                    RecordedSteps.Push("Commander := true")
                LogToConsole("Commander activated")
            }
        } else {
            LogToConsole("Tower " . closestID . " upgraded to level " . Towers[closestID].level)
        }
    } else {
        LogToConsole("Can't find the tower to upgrade")
    }
return

^d::
    WinMinimize, TDS Macro

    if (!Recording)
        return

    InputBox, track, DJ Track, Enter Track Color (Purple/Red/Green):,,,,,,,,Green
    if !ErrorLevel {
        RecordedSteps.Push("SetDJTrack(""" . track . """)")
        LogToConsole("Recorded DJ-track " . track)
    }
return

^b::
    if (!Recording)
        return
    MouseGetPos, mx, my
    closestID := FindClosestTower(mx, my)
    if (closestID != "") {
        if (Towers[closestID].hwnd) {
            hwnd := Towers[closestID].hwnd
            WinClose, ahk_id %hwnd%
            Gui, Tower%closestID%:Destroy
        }
        
        newSteps := []
        for i, step in RecordedSteps {
            if (RegExMatch(step, "i)(SpawnTower|UpgradeTower)\s*\([^)]*" . closestID . "[^)]*\)"))
                continue
            newSteps.Push(step)
        }
        RecordedSteps := newSteps
        
        Towers.Delete(closestID)
        
        LogToConsole("Deleted tower " . closestID . " and all related data")
    } else {
        LogToConsole("No tower found near cursor to delete")
    }
return

^x::
    if (!Recording)
        return
    MouseGetPos, mx, my
    closestID := FindClosestTower(mx, my)
    if (closestID != "") {
        if (Towers[closestID].hwnd) {
            hwnd := Towers[closestID].hwnd
            WinClose, ahk_id %hwnd%
            Gui, Tower%closestID%:Destroy
            Towers[closestID].hwnd := ""
        }
        
        RecordedSteps.Push("SellTower(" . closestID . ")")
        SellTower(closestID)
        
        Towers.Delete(closestID)
        
        LogToConsole("Recorded sell tower " . closestID)
    } else {
        LogToConsole("No tower found near cursor to sell")
    }
return

^t::AlignCamera()

LoadStrategyFile(file) {
    global
    Towers := {}
    RecordedSteps := []
    DeleteAllIndicators()
    IniRead, map, %file%, Settings, map, %A_Space%
    IniRead, difficulty, %file%, Settings, difficulty, %A_Space%
    IniRead, requiredTowers, %file%, Settings, requiredTowers, %A_Space%
    IniRead, autoChain, %file%, Settings, autoChain, OFF
    IniRead, autoCaravan, %file%, Settings, autoCaravan, OFF
    IniRead, autoDropTheBeat, %file%, Settings, autoDropTheBeat, OFF
    IniRead, AutoSkip, %file%, Settings, autoSkip, ON
    IniRead, moveDown, %file%, Settings, moveDown, false
    moveDown := (moveDown = "true") ? true : false
    IniRead, tempChain, %file%, Settings, chainInterval, 10
    IniRead, tempCaravan, %file%, Settings, caravanInterval, 20
    IniRead, modifiers, %file%, Settings, modifiers, %A_Space%
    if tempChain is number
        chainInterval := tempChain
    else
        chainInterval := 10
    if tempCaravan is number
        caravanInterval := tempCaravan
    else
        caravanInterval := 20
    Commander := false
    Loop, Read, %file%
    {
        if (A_LoopReadLine ~= "^\s*\[Settings\]" or A_LoopReadLine ~= "^\s*\[Steps\]")
            continue
        if (A_LoopReadLine != "")
            RecordedSteps.Push(A_LoopReadLine)
    }
}

RunStrategy() {
    global RunningStrategy, difficulty, moveDown, unfocusX, unfocusY, UseTimeScale, TimeScaleMultiplier, TimeScaleMode, SettingsFile, requiredTowers, modifiers
    if (RunningStrategy != true)
        return

    LogToConsole("Starting strategy...")
    LogToConsole("Map = " map)
    LogToConsole("Mode = " difficulty)
    LogToConsole("Timescale = " TimeScaleMode)
    LogToConsole("Required Towers: " requiredTowers)
    if (modifiers != "") {
        LogToConsole("Modifiers: " modifiers)
    }

    CheckDisconnected()
    if (difficulty != "Hardcore")
        CheckRestartForNormalGames()
    else
        CheckRestartForHardcore()

    LoadGame()

    i := 1
    while (i <= RecordedSteps.MaxIndex()) {
        step := RecordedSteps[i]

        
        if (i > 10)
        {
            CheckForSkip()
        }

        if (RegExMatch(step, "i)UpgradeTower\s*\(\s*([^\s,)]+)\s*\)", m)) {
            currentID := m1
            success := UpgradeTower(currentID, false)
            i++
            if (success) {
                while (i <= RecordedSteps.MaxIndex()) {
                    nextStep := RecordedSteps[i]
                    if (RegExMatch(nextStep, "i)UpgradeTower\s*\(\s*([^\s,)]+)\s*\)", m2) && (m21 = currentID)) {
                        success := UpgradeTower(currentID, true)
                        if (!success) {
                            i++
                            break
                        }
                        i++
                    } else {
                        break
                    }
                }
            }
            Click, %unfocusX%, %unfocusY%
            Sleep, 50
        } else {
            try {
                ExecuteStep(step)
            } catch e {
                LogToConsole("ERROR executing step " i ": " step)
            }
            i++
        }
        Sleep, 50
    }

    LogToConsole("All strategy steps completed, entering maintenance loop...")
    Loop {
        Sleep, 500
        CheckForSkip()
    }
}


ExecuteStep(step) {
    global
    step := RegExReplace(step, "\s*;.*$", "")
    step := Trim(step)
    if (step = "")
        return
    if (RegExMatch(step, "i)SpawnTower\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d)\s*,\s*([^\s,)]+)\s*\)", m)) {
        SpawnTower(m1, m2, m3, m4)
        return
    }
    if (RegExMatch(step, "i)UpgradeTower\s*\(\s*([^\s,)]+)\s*\)", m)) {
        UpgradeTower(m1)
        return
    }
    if (RegExMatch(step, "i)SetDJTrack\s*\(\s*(.+?)\s*\)", m)) {
        track := Trim(m1, " """)
        if (track != "") {
            SetDJTrack(track)
        }
        return
    }
    if (RegExMatch(step, "i)Commander\s*:=\s*true")) {
        Commander := true
        return
    }
    if (RegExMatch(step, "i)SellTower\s*\(\s*([^\s,)]+)\s*\)", m)) {
        SellTower(m1)
        return
    }
}


CheckDisconnected() {
    ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *10 Resources\Disconnected.png
    if (ErrorLevel = 0)
        Reload
}

CheckRestartForNormalGames() {
    processName := "ahk_exe RobloxPlayerBeta.exe"
    if WinExist(processName) {
        WinActivate, %processName%
        Sleep, 500
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *20 Resources\Restart.png
        if (ErrorLevel = 0) {
            Click, % (FoundX + 80) " " (FoundY + 20)
            if (moveDown = true) {
                Send {W down}
                sleep, 750
                Send {W Up}
                sleep, 50
            }
        } else {
            RunRoblox()
            JoinGame(difficulty)
        }
    } else {
        RunRoblox()
        JoinGame(difficulty)
    }
}

CheckRestartForHardcore() {
    if WinExist("ahk_exe RobloxPlayerBeta.exe") {
        WinActivate, ahk_exe RobloxPlayerBeta.exe
        sleep, 500
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *10 Resources/Restart.png
        if (ErrorLevel = 1) {
            RunRoblox()
            JoinHardcore()
        }
        if (ErrorLevel = 0) {
            targetX := FoundX + 80
            targetY := FoundY + 20
            click, %targetX%, %targetY%
        }
    } else {
        RunRoblox()
        JoinHardcore()
    }
}

RunRoblox() {
    PlaceID := "3260590327"
    DeepLink := "roblox://experiences/start?placeId=" . PlaceID
    Run, %DeepLink%, , , outputPID
    WinWait, ahk_exe RobloxPlayerBeta.exe, , 10
    if !ErrorLevel {
        WinActivate, ahk_exe RobloxPlayerBeta.exe
        ExitFullScreen()
        WinMinimize, ahk_exe RobloxPlayerBeta.exe
        WinMaximize, ahk_exe RobloxPlayerBeta.exe
    }
    Sleep, 12000
    Loop {
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *25 %A_WorkingDir%/Resources/Play.png
        if (ErrorLevel = 0)
            break
        if (ErrorLevel = 1) {
            ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *25 %A_WorkingDir%/Resources/Claim.png
            if (ErrorLevel = 0)
                click, %FoundX%, %FoundY%
        }
        Sleep, 1500
    }
    LogToConsole("Joining " difficulty "...")
}

ExitFullScreen() {
    if WinExist("ahk_exe RobloxPlayerBeta.exe") {
        WinActivate, ahk_exe RobloxPlayerBeta.exe
        WinGet, Style, Style, ahk_exe RobloxPlayerBeta.exe
        if !(Style & 0xC00000) {
            Send, {F11}
            Sleep, 500
        }
        WinRestore, ahk_exe RobloxPlayerBeta.exe
    }
}


JoinGame(diff) {
    Click, 968 871
    Sleep, 1400
    

    if (diff = "Pizza Party" || diff = "Badlands II" || diff = "Polluted Wastelands II")
        Click, 1209 531  ;  special
    else
        Click, 982 574  ; normal

    sleep, 800
    if (diff = "Easy")
        Click, 361 546
    else if (diff = "Casual")
        Click, 594 555
    else if (diff = "Intermediate")
        Click, 842 558
    else if (diff = "Molten")
        Click, 1070 537
    else if (diff = "Fallen")
        Click, 1317 565
    else if (diff = "Frost")
        Click, 1566 573
    else if (diff = "Pizza Party")
        Click, 1184 557
    else if (diff = "Badlands II")
        Click, 757 568
    else if (diff = "Polluted Wastelands II")
        Click, 964 565

    Sleep, 1000
    Click, 795 462

    if (diff != "Pizza Party" && diff != "Badlands II" && diff != "Polluted Wastelands II")
    {
        sleep, 3000
        Loop {
            ImageSearch, FoundX, FoundY, 749, 762, 1214, 931, *5 Resources/Ready.png
            if (ErrorLevel = 0)
                break
            Sleep, 100
        }
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *25 Resources/WrongCamera.png
        if (ErrorLevel = 0) {
            Send {Left Down}
            Sleep, 1500
            Send {Left Up}
        }
        SelectMap()
    }
}

JoinHardcore() {
    Click, 968 871
    Sleep, 1000
    Click, 491 543
    Sleep, 800
    Click, 795 462
    sleep, 3000
    Loop {
        ImageSearch, FoundX, FoundY, 749, 762, 1214, 931, *5 Resources/Ready.png
        if (ErrorLevel = 0)
            break
        Sleep, 100
    }
    SelectMap()
}

SelectMap() {
    LogToConsole("Selecting map: " map )
    Send, {w down}
    Sleep, 2200
    Send, {w up}
    Sleep, 300
    Send, {d down}
    Sleep, 1700
    Send, {d up}
    Sleep, 500
    Send, {e down}
    Sleep, 500
    Send, {e up}
    Sleep, 500
    Click, 840, 251
    Sleep, 200
    SendInput %map%
    Sleep, 300
    Click, 748, 360
    Sleep, 400
    PixelSearch, FoundX, FoundY, 840, 250, 1100, 450, 0x0000EC, 0, Fast
    if (ErrorLevel = 0) {
        Reload
        sleep, 400
    }
    Send, {a down}
    Sleep, 1700
    Send, {a up}
    Sleep, 200
    
    if (modifiers != "") {
        LogToConsole("Setting up modifiers: " modifiers)
        
        Click, 59, 1014
        Sleep, 300
        
        Loop, Parse, modifiers, `,
        {
            modifier := Trim(A_LoopField)
            if (modifier = "")
                continue
                
            Click, 881, 295
            Sleep, 200
            
            Send, ^a
            Sleep, 50
            Send, %modifier%
            Sleep, 200
            
            Click, 958, 357
            Sleep, 300
            
            LogToConsole("Modifier added: " modifier)
        }
        
        Sleep, 100
        Click, 1125, 889
        LogToConsole("All modifiers configured")
    }
    ; ===================================
    
    Send, {w down}
    Sleep, 2500
    Send, {w up}
    Sleep, 200
    Send, {a down}
    Sleep, 1400
    Send, {a up}
    Sleep, 600
    Send, {e down}
    Sleep, 500
    Send, {e up}
    Sleep, 100
    Click, 968 871
    sleep, 10000
    ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *45 Resources\%map%.png
    if (ErrorLevel = 1)
        Reload
    Sleep, 100
}

LoadGame() {
    CheckDisconnected()
    Loop {
        PixelSearch, FoundX, FoundY, 0, 1080, 1920, 0, 0x00EB2B, 0, Fast
        if (ErrorLevel = 0) {
            Sleep, 300
            AlignCamera()
            Sleep, 500
            if (UseTimeScale && difficulty != "Pizza Party" && difficulty != "Badlands II" && difficulty != "Polluted Wastelands II") {
                LogToConsole("Applying timescale: " TimeScaleMode)
                Click, 654, 991
                Sleep, 500
                PixelSearch, ErrX, ErrY, 840, 250, 1100, 450, 0x0000EC, 0, Fast
                if (ErrorLevel = 0) {
                    UseTimeScale := false
                    TimeScaleMultiplier := 1
                    TimeScaleMode := "OFF"
                    IniWrite, %TimeScaleMode%, %SettingsFile%, Options, TimeScaleMode
                } else {
                    if (TimeScaleMode = "2x") {
                        Click, 960, 631
                        Sleep, 300
                        Click, 654, 991
                        Sleep, 100
                        Click, 654, 991
                        Sleep, 300
                    } else if (TimeScaleMode = "1.5x") {
                        Click, 960, 631
                        Sleep, 200
                        Click, 654, 991
                        Sleep, 300
                    }
                }
            }
            Click, %FoundX%, %FoundY%
            break
        }
    }
}

AlignCamera() {
    LogToConsole("Aligning camera")
    MouseMove, 1339, 236
    Click, Right, Down
    MouseMove, 1339, 1200
    Click, Right, Up
    Sleep, 200
    Send, {o down}
    Sleep, 500
    Send, {o up}
    Sleep, 200
    if (moveDown = true) {
        Send {S down}
        Sleep, 750
        Send {S Up}
    }
}

SpawnTower(X, Y, slotNumber, towerID) {
    CheckDisconnected()
    LogToConsole("Placing tower " towerID " (slot " slotNumber ") at x:" X " y:" Y "...")
    Towers[towerID] := {x: X, y: Y, slot: slotNumber, level: 0}
    slot1 := "800 1000"
    slot2 := "890 1000"
    slot3 := "980 1000"
    slot4 := "1070 1000"
    slot5 := "1160 1000"
    currentSlot := slot%slotNumber%
    Loop {
        CheckForSkip()
        Click, %currentSlot%
        Sleep, 100
        MouseMove, %X%, %Y%
        Sleep, 100
        Click
        Sleep, 300
        Send, {Q}
        Sleep, 100
        Click, %unfocusX%, %unfocusY%

        PixelSearch, FoundX, FoundY, 840, 250, 1100, 450, 0x0000EC, 0, Fast
        if (ErrorLevel = 1) {
            Click, %unfocusX%, %unfocusY%
            LogToConsole("Tower " towerID " placed successfully")
            break
        } else {
            LogToConsole("Tower " towerID " placement failed, retrying in 3.5s...")
            Sleep, 200
            CheckForSkip()
            Sleep, 3500
        }
    }
    CheckForSkip()
    UpdateTowerIndicator(towerID)
}


SellTower(towerID) {
    global Towers, unfocusX, unfocusY
    CheckDisconnected()
    
    if (!Towers[towerID]) {
        LogToConsole("ERROR: Tower " towerID " not found for selling!")
        return false
    }
    
    LogToConsole("Selling tower " towerID "...")
    
    targetX := Towers[towerID].x
    targetY := Towers[towerID].y
    
    Click, %targetX%, %targetY% ; Open menu
    Sleep, 400
    
    attempts := 0
    Loop {
        CheckForSkip()
        PixelSearch, FoundX, FoundY, 1257, 513, 1340, 574, 0x7E5C27, 5, Fast
        if (ErrorLevel = 1) {
            attempts++
            if (attempts > 15) {
                LogToConsole("ERROR: Tower " towerID " menu not found for selling")
                return false
            }
            
            Random, VariationY, -10, 10
            targetX := Towers[towerID].x
            targetY := Towers[towerID].y + VariationY
            Click, %targetX%, %targetY%
            Sleep, 400
            continue
        }
        
         MouseMove, %unfocusX%, %unfocusY%
         Sleep, 50
         Click, 796, 871
        Sleep, 50
        MouseMove, %unfocusX%, %unfocusY%
        LogToConsole("Tower " towerID " sold successfully")
    
        ; Remove tower data
        if (Towers[towerID].hwnd) {
            hwnd := Towers[towerID].hwnd
            WinClose, ahk_id %hwnd%
            Gui, Tower%towerID%:Destroy
         }
        Towers.Delete(towerID)
        return true
     
        break
    }
    
    Sleep, 50
    return false
}

UpgradeTower(towerID, skipOpen := false) {
    global Towers, unfocusX, unfocusY
    CheckDisconnected()
    if (!Towers[towerID]) {
        LogToConsole("ERROR: Tower " towerID " not found!")
        return false
    }
    if (!skipOpen) {
        targetX := Towers[towerID].x, targetY := Towers[towerID].y
        Click, %targetX%, %targetY%
        Sleep, 400
    }
    attempts := 0
    Loop {
        CheckCritical()
        if (skipOpen) {
            PixelSearch, MenuX, MenuY, 1257, 513, 1340, 574, 0x7E5C27, 5, Fast
            if (ErrorLevel) {
                targetX := Towers[towerID].x, targetY := Towers[towerID].y
                Click, %targetX%, %targetY%
                Sleep, 400
            }
        }
        PixelSearch, FoundX, FoundY, 1257, 513, 1340, 574, 0x7E5C27, 5, Fast
        if (ErrorLevel = 1) {
            attempts++
            if (attempts > 25) {
                LogToConsole("ERROR: Tower " towerID " menu not found after 25 attempts, respawning...")
                SpawnTower(Towers[towerID].x, Towers[towerID].y, Towers[towerID].slot, towerID)
                attempts := 0
                targetX := Towers[towerID].x, targetY := Towers[towerID].y
                Click, %targetX%, %targetY%
                Sleep, 400
                Continue
            }
            if (!skipOpen) {
                Random, VariationY, -10, 10
                targetX := Towers[towerID].x, targetY := Towers[towerID].y + VariationY
                Click, %targetX%, %targetY%
            }
            continue
        }
        PixelSearch, FoundX, FoundY, 1106, 624, 1251, 651, 0x346120, 25, Fast RGB
        if (ErrorLevel = 0) {
            upgradeAttempts := 0
            Loop {
                Click, 1100, 600
                Sleep, 400
                PixelSearch, ErrX, ErrY, 840, 250, 1100, 450, 0x0000EC, 0, Fast
                if (ErrorLevel = 0) {
                    Sleep, 4400
                    upgradeAttempts++
                    if (upgradeAttempts > 20) {
                        LogToConsole("ERROR: Tower " towerID " upgrade failed after 20 attempts")
                        Click, %unfocusX%, %unfocusY%
                        Sleep, 100
                        return false
                    }
                    LogToConsole("Tower " towerID " upgrade error, waiting 4.4s...")
                    continue
                }
                break
            }
            Towers[towerID].level += 1
            LogToConsole("Tower " towerID " upgraded to level " Towers[towerID].level)
            UpdateTowerIndicator(towerID)
            if (Towers[towerID].level >= 2 && RegExMatch(towerID, "i)^Commander\d*$") && !Commander) {
                Commander := true
                LogToConsole("Commander mode activated (tower " towerID " level " Towers[towerID].level ")")
                if (Recording && !HasStep("Commander := true"))
                    RecordedSteps.Push("Commander := true")
            }
            return true
        }
    }
}

CheckCritical() {
    CheckDisconnected()
    PixelSearch, FoundX, FoundY, 562, 325, 1404, 456, 0x213DFF, 0, Fast
    if (ErrorLevel = 0)
        Reload
    ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *25 Resources\triumph.png
    if (ErrorLevel = 0)
        Reload
    if (ErrorLevel = 1) {
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *25 Resources\PlayAgain.png
        if (ErrorLevel = 0)
            Reload
    }
    ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *30 Resources\YouLost.png
    if (ErrorLevel = 0)
        Reload
}

CheckForSkip() {
    global ChainKey, BeatKey, CaravanKey, TimeScaleMultiplier, UseTimeScale, AutoSkip, autoChain, autoCaravan, autoDropTheBeat, Commander, unfocusX, unfocusY, chainInterval, caravanInterval
    CheckDisconnected()
    Send, {Q}

    ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *80 Resources\triumph.png
    if (ErrorLevel = 0) {
        LogToConsole("Victory detected! Reloading...")
        Reload
    }

    if (ErrorLevel = 1) {
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *80 Resources\PlayAgain.png
        if (ErrorLevel = 0) {
            LogToConsole("Defeat detected! Reloading...")
            Reload
        }
    }

    ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *80 Resources\YouLost.png
    if (ErrorLevel = 0) {
        LogToConsole("Game over detected! Reloading...")
        Reload
    }

    PixelSearch, FoundX, FoundY, 562, 325, 1404, 456, 0x213DFF, 0, Fast
    if (ErrorLevel = 0) {
        LogToConsole("Disconnected detected! Reloading...")
        Reload
    }

    if (AutoSkip = "OFF") {
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *10 Resources\DontSkip.png
        if (ErrorLevel = 0) {
            TargetX := FoundX + 10
            TargetY := FoundY + 20
            MouseMove, %unfocusX%, %unfocusY%
            Sleep, 50
            Click, %TargetX%, %TargetY%
            MouseMove, %unfocusX%, %unfocusY%
            Sleep, 100
            LogToConsole("Wave skipped (auto-skip OFF)")
        }
    }
    if (AutoSkip = "ON") {
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *10 Resources\Skip.png
        if (ErrorLevel = 0) {
            TargetX := FoundX + 10
            TargetY := FoundY + 20
            MouseMove, %unfocusX%, %unfocusY%
            Sleep, 50
            Click, %TargetX%, %TargetY%
            MouseMove, %unfocusX%, %unfocusY%
            Sleep, 100
            LogToConsole("Wave skipped (auto-skip ON)")
        }
    }

    static LastChainTime := 0
    static LastDropTime := 0
    static LastCaravanTime := 0

    if (autoChain = "ON" && Commander && (A_TickCount - LastChainTime > chainInterval * 1000 / TimeScaleMultiplier)) {
        LastChainTime := A_TickCount
        Click, %unfocusX%, %unfocusY%
        Sleep, 100
        Send, {%ChainKey%}
        Sleep, 300
        PixelSearch, FoundX, FoundY, 840, 250, 1100, 450, 0xFF0000, 20, Fast RGB
        if (ErrorLevel = 0) {
            LogToConsole("Chain ability used, cooldown error detected, waiting 4.5s...")
            Sleep, 4500
        } else {
            LogToConsole("Chain ability activated")
        }
    }

    if (autoCaravan = "ON" && Commander && (A_TickCount - LastCaravanTime > caravanInterval * 1000 / TimeScaleMultiplier)) {
        LastCaravanTime := A_TickCount
        Click, %unfocusX%, %unfocusY%
        Sleep, 100
        Send, {%CaravanKey%}
        Sleep, 300
        PixelSearch, FoundX, FoundY, 840, 250, 1100, 450, 0xFF0000, 20, Fast RGB
        if (ErrorLevel = 0) {
            LogToConsole("Caravan ability used, cooldown error detected, waiting 4.5s...")
            Sleep, 4500
        } else {
            LogToConsole("Caravan ability activated")
        }
    }

    if (autoDropTheBeat = "ON" && Towers["DJ"] && (A_TickCount - LastDropTime > 30000 / TimeScaleMultiplier)) {
        LastDropTime := A_TickCount
        Click, %unfocusX%, %unfocusY%
        Sleep, 100
        Send, {%BeatKey%}
        Sleep, 300
        PixelSearch, FoundX, FoundY, 840, 250, 1100, 450, 0xFF0000, 20, Fast RGB
        if (ErrorLevel = 0) {
            LogToConsole("Drop the Beat used, cooldown error detected, waiting 4.5s...")
            Sleep, 4500
        } else {
            LogToConsole("Drop the Beat activated")
        }
    }
}

SetDJTrack(track) {
    CheckDisconnected()
    if (Towers["DJ"]) {
        LogToConsole("Setting DJ track to " track "...")
        targetX := Towers["DJ"].x, targetY := Towers["DJ"].y
        Click, %targetX%, %targetY%
        Sleep, 400
        Loop {
            CheckForSkip()
            PixelSearch, FoundX, FoundY, 1257, 513, 1340, 574, 0x7E5C27, 5, Fast
            if (ErrorLevel = 1) {
                Random, VariationY, -10, 10
                targetX := Towers["DJ"].x, targetY := Towers["DJ"].y + VariationY
                Click, %targetX%, %targetY%
                Sleep, 400
                continue
            }
            if (ErrorLevel = 0) {
                trackFound := false
                Loop, 3 {
                    if (track = "Red") {
                        if (Towers["DJ"].level >= 3) {
                            sleep, 400
                            Click, 1585, 682
                            Sleep, 100
                            Click, %unfocusX%, %unfocusY%
                            trackFound := true
                            LogToConsole("DJ track set to Red")
                            break
                        } else {
                            ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *25 Resources\Green.png
                            if (ErrorLevel = 0) {
                                targX := FoundX + 70
                                Click, %targX%, %FoundY%
                                Sleep, 100
                                Click, %unfocusX%, %unfocusY%
                                trackFound := true
                                LogToConsole("DJ track set to Green (Red not available)")
                                break
                            }
                        }
                    } else {
                        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *20 Resources\%track%.png
                        if (ErrorLevel = 0) {
                            Click, %FoundX%, %FoundY%
                            Sleep, 100
                            Click, %unfocusX%, %unfocusY%
                            trackFound := true
                            LogToConsole("DJ track set to " track)
                            break
                        }
                    }
                    if (A_Index < 3)
                        Sleep, 400
                }
                if (trackFound)
                    break
            }
        }
    } else {
        LogToConsole("ERROR: DJ tower not found!")
    }
}

FindClosestTower(mx, my) {
    global Towers
    closestID := ""
    minDist := 20
    for id, t in Towers {
        dist := Sqrt((t.x - mx)**2 + (t.y - my)**2)
        if (dist < minDist) {
            minDist := dist
            closestID := id
        }
    }
    return closestID
}

HasStep(searchStep) {
    global RecordedSteps
    for i, s in RecordedSteps
        if (s = searchStep)
            return true
    return false
}

UpdateTowerIndicator(towerID) {
    global Towers, Recording, ShowIndicators
    if (!Recording || !ShowIndicators || !Towers[towerID])
        return
    level := Towers[towerID].level
    if (Towers[towerID].hwnd) {
        hwnd := Towers[towerID].hwnd
        ControlSetText, Static1, %level%, ahk_id %hwnd%
        WinShow, ahk_id %hwnd%
    } else {
        Gui, Tower%towerID%:New, +ToolWindow +AlwaysOnTop -Caption +E0x20, Tower%towerID%
        Gui, Color, FFFFFF
        Gui, Font, s10 cBlack, Arial
        Gui, Add, Text, x0 y0 w24 h24 Center 0x200, %level%
        WinSet, TransColor, FFFFFF 255, Tower%towerID%
        x := Towers[towerID].x - 12
        y := Towers[towerID].y - 12
        Gui, Show, x%x% y%y% w24 h24 NoActivate, Tower%towerID%
        WinGet, hwnd, ID, Tower%towerID%
        Towers[towerID].hwnd := hwnd
    }
}

DeleteAllIndicators() {
    global Towers
    for id, t in Towers {
        if (t.hwnd) {
            hwnd := t.hwnd
            WinClose, ahk_id %hwnd%
        }
        Gui, Tower%id%:Destroy
    }
    for id, t in Towers
        Towers[id].hwnd := ""
}

GetNextNumericID() {
    global Towers
    maxNum := 0
    for id, t in Towers {
        if (id ~= "^\d+$") {
            num := id + 0
            if (num > maxNum)
                maxNum := num
        }
    }
    return maxNum + 1
}

ModernMsgBox(Title, Text, Buttons="OK", AccentColor="Blue") {
    global MsgResult := ""
    static hMsgGui
    
    SoundPlay, *48 
    HexColor := (AccentColor = "Orange") ? "FF8C00" : "0078D7"
    
    Gui, Msg:New, +AlwaysOnTop -Caption +Border +LastFound +HwndhMsgGui
    Gui, Color, 1E1E1E
    
    Gui, Font, s14 w700 c%HexColor%, Segoe UI
    Gui, Add, Text, x25 y20 w350, %Title%
    
    Gui, Font, s11 w400 cFFFFFF
    Gui, Add, Text, x25 y+15 w350, %Text%
    
    Gui, Font, s10 w600 cFFFFFF
    if (Buttons = "OK") {
        Gui, Add, Button, x135 y+30 w130 h40 gMsgOK Default, OK
    } else {
        Gui, Add, Button, x30 y+30 w165 h40 gMsgYES Default Section, YES
        Gui, Add, Button, x205 ys w165 h40 gMsgNO, NO
    }
    
    Gui, Add, Text, x25 y+20 w350 h1 +Hidden, .
    Gui, Show, w400 AutoSize, %Title%
    
    MsgResult := ""
    while (MsgResult = "") {
        Sleep, 100
        if !WinExist("ahk_id " hMsgGui)
            break
    }
    return MsgResult

    MsgOK:
    MsgYES:
        MsgResult := "YES"
        GoSub, MsgCloseAnim
    return

    MsgNO:
        MsgResult := "NO"
        GoSub, MsgCloseAnim
    return

    MsgCloseAnim:
        ;Loop, 10 {
         ;   WinSet, Transparent, % 255 - (A_Index * 25), ahk_id %hMsgGui%
          ;  Sleep, 15
        ;}
        Gui, Msg:Destroy
    return
}

SyncSettings() {
    global SettingsFile, AppDataSettingsPath, LocalSettingsPath
    if (SettingsFile = AppDataSettingsPath) {
        FileCopy, %AppDataSettingsPath%, %LocalSettingsPath%, 1
    } else {
        SplitPath, AppDataSettingsPath,, AppDir
        IfNotExist, %AppDir%
            FileCreateDir, %AppDir%
        FileCopy, %LocalSettingsPath%, %AppDataSettingsPath%, 1
    }
}

global OverlayPicHWND  

ShowDebugConsole() {
    global DebugConsole, OverlayHWND, OverlayBitmap, OverlayGraphics, OverlayPicHWND, OverlayX, OverlayY, OverlayWidth, OverlayHeight
    if (DebugConsole != "ON")
        return
    if (OverlayHWND && WinExist("ahk_id " OverlayHWND))
        return

    Gui, Overlay:New, +AlwaysOnTop +ToolWindow -Caption +E0x20 +LastFound +HwndOverlayHWND
    Gui, Color, 0
    Gui, Add, Picture, x0 y0 w%OverlayWidth% h%OverlayHeight% +0xE +HwndOverlayPicHWND
    WinSet, ExStyle, +0x8000000, ahk_id %OverlayHWND%
    Gui, Show, x%OverlayX% y%OverlayY% w%OverlayWidth% h%OverlayHeight% NA, DebugOverlay
    WinSet, TransColor, 0, ahk_id %OverlayHWND%

    OverlayBitmap := Gdip_CreateBitmap(OverlayWidth, OverlayHeight)
    OverlayGraphics := Gdip_GraphicsFromImage(OverlayBitmap)
    Gdip_SetSmoothingMode(OverlayGraphics, 4)
}
HideDebugConsole() {
    global OverlayHWND, OverlayBitmap, OverlayGraphics, OverlayPicHWND
    if (OverlayBitmap) {
        Gdip_DisposeImage(OverlayBitmap)
        OverlayBitmap := ""
    }
    if (OverlayGraphics) {
        Gdip_DeleteGraphics(OverlayGraphics)
        OverlayGraphics := ""
    }
    Gui, Overlay:Destroy
    OverlayHWND := ""
    OverlayPicHWND := ""
}

UpdateOverlay() {
    global OverlayBitmap, OverlayGraphics, OverlayPicHWND, LogLines, OverlayWidth, OverlayHeight
    if !OverlayGraphics
        return

    Gdip_GraphicsClear(OverlayGraphics, 0x00000000)

    fontName := "Consolas"
    fontSize := 14
    style := 1
    textColor := 0xFFFFFFFF    

    hFamily := Gdip_FontFamilyCreate(fontName)
    hFont := Gdip_FontCreate(hFamily, fontSize, style)
    hFormat := Gdip_StringFormatCreate(0x0000)
    Gdip_SetStringFormatAlign(hFormat, 0)

    pBrushText := Gdip_BrushCreateSolid(textColor)

    pBrushBg := Gdip_BrushCreateSolid(0xAA000000)

    lineHeight := fontSize * 1.4
    maxLines := Floor(OverlayHeight / lineHeight)
    startIndex := Max(1, LogLines.MaxIndex() - maxLines + 1)
    yPos := 5

    Loop, % maxLines {
        index := startIndex + A_Index - 1
        if (index > LogLines.MaxIndex())
            break
        line := LogLines[index]


        Gdip_FillRectangle(OverlayGraphics, pBrushBg, 5, yPos, OverlayWidth-10, lineHeight)

        CreateRectF(RC, 5, yPos, OverlayWidth-5, lineHeight)
        Gdip_DrawString(OverlayGraphics, line, hFont, hFormat, pBrushText, RC)

        yPos += lineHeight
    }

    Gdip_DeleteBrush(pBrushText)
    Gdip_DeleteBrush(pBrushBg)
    Gdip_DeleteStringFormat(hFormat)
    Gdip_DeleteFont(hFont)
    Gdip_DeleteFontFamily(hFamily)

    hBitmap := Gdip_CreateHBITMAPFromBitmap(OverlayBitmap)
    SetImage(OverlayPicHWND, hBitmap)
    DeleteObject(hBitmap)
}

LogToConsole(text) {
    global DebugConsole, LogLines, OverlayHWND
    if (DebugConsole != "ON")
        return

    FormatTime, time,, HH:mm:ss
    LogLines.Push("[" . time . "] " . text)

    while (LogLines.MaxIndex() > 500)
        LogLines.RemoveAt(1)

    if (OverlayHWND && WinExist("ahk_id " OverlayHWND))
        UpdateOverlay()
}


CleanupGdip:
    Gdip_Shutdown(pToken)
ExitApp