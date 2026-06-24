; Tower Defense Simulator Macro by Darksen
;   Free for anyone to use
;   Modifications are welcome, however stealing credit is not.
;   You can add your name, but my original credit must remain.
;
; Started on March 30, 2026. My friend bet me that I wouldn't make a macro for TDS, but I did.
;
; Discord Server - https://discord.gg/DQnc2JDJtr

#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance, force
#Persistent

SetWorkingDir %A_ScriptDir%

if (RegExMatch(A_ScriptDir,"\.zip")){
    MsgBox, 0, % "Running From ZIP", % "You are attempting to run the script from a ZIP file.`n`nPlease Extract/Unzip the file first, then run the script in the extracted folder."
    ExitApp
}

#Include %A_ScriptDir%\lib\Gdip_All.ahk
#Include %A_ScriptDir%\lib\ocr.ahk
#Include %A_ScriptDir%\lib\Gdip_ImageSearch.ahk

ver := "1.2.6" 

pToken := Gdip_Startup()
OnExit, CleanupGdip

global AppDataOpt := A_AppData "\Ultimate_Macro\Macros\TDSMacro\Options"
global SettingsFile := AppDataOpt "\Settings.tds"
global RecordingsDir := A_AppData "\Ultimate_Macro\Macros\TDSMacro\Recordings"
global StateFile := A_AppData "\Ultimate_Macro\Macros\TDSMacro\state.ini"
global ShowIndicators := true

global WebhookQueue := []
global WebhookTimerActive := false
global WebhookLink := ""
global WebhookEnabled := false

IfNotExist, %AppDataOpt%
    FileCreateDir, %AppDataOpt%
IfNotExist, %RecordingsDir%
    FileCreateDir, %RecordingsDir%

; INIREADS
IniRead, VipLink, %SettingsFile%, Options, VipLink, %A_Space%
IniRead, UseVipServer, %SettingsFile%, Options, UseVipServer, 0
IniRead, AutoCameraCheck, %SettingsFile%, Options, AutoCameraCheck, 1
IniRead, WebhookLink, %SettingsFile%, Webhook, Link, %A_Space%
IniRead, WebhookEnabled, %SettingsFile%, Webhook, Enabled, 0
IniRead, PotatoMode, %SettingsFile%, Options, PotatoMode, 1
IniRead, SendCurrenciesEnabled, %SettingsFile%, Webhook, SendCurrencies, 1
IniRead, UseRestartBtn, %SettingsFile%, Options, UseRestartBtn, 1
IniRead, UsePlayAgainBtn, %SettingsFile%, Options, UsePlayAgainBtn, 1

WM_LBUTTONDOWN_Progress() {
    PostMessage, 0xA1, 2,,, A
}

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
global DebugConsole := 0              
IniRead, DebugConsole, %SettingsFile%, Options, DebugConsole, 0

if (TimeScaleMode = "1.5x") {
    UseTimeScale := true, TimeScaleMultiplier := 1.5
} else if (TimeScaleMode = "2x") {
    UseTimeScale := true, TimeScaleMultiplier := 2
} else {
    UseTimeScale := false, TimeScaleMultiplier := 1
}

if (DebugConsole = 1)
    ShowDebugConsole()

global map := "", difficulty := "", requiredTowers := ""
global autoChain := "OFF", autoCaravan := "OFF", autoDropTheBeat := "OFF"
global Commander := false, AutoSkip := "ON"

global MoveEnabled := false, MoveDirection := "W", MoveDuration := 750
global unfocusX := 150, unfocusY := 200
global Towers := {}, RecordedSteps := [], Recording := false, RunningStrategy := false
global chainInterval := 10, caravanInterval := 20
global modifiers := ""
global LastDisconnectCheck := 0
global LastOpenedTowerID := ""
global IsRestarting := false
global SafeExitFlag := false
global RestartLock := false

global MacroRecording := false
global MacroSteps := []
global MacroStartTime := 0
global InputHookObj := ""

global LastSkipCheck := 0

global AutorunStartTime := 0

global CheckerPID := ""
global DiscordPID := ""

global Path1Region := [1265, 651, 1340, 705]
global Path2Region := [1265, 798, 1340, 828]
global DefaultUpgradeRegion := [1106, 624, 1251, 651]

IconPath := A_WorkingDir "\icon.ico"
if FileExist(IconPath)
    Menu, Tray, Icon, %IconPath%

IniRead, autoRun, %StateFile%, State, Running, 0
IniRead, autoStrat, %StateFile%, State, Strategy, %A_Space%
IniRead, savedStartTime, %StateFile%, State, StartTime, 0
if (savedStartTime != 0) {
    AutorunStartTime := savedStartTime
}

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
} else {
        ; --- Auto-Update Check ---
    #Include %A_ScriptDir%\submacros\updater.ahk

    updateResult := CheckForUpdate(ver)
    if (updateResult = 2) {
        SafeReload()
    }

    MultiInstanceTools := "RobloxAccountManager.exe,Roblox Account Manager.exe,RAM.exe,RobloxMulti.exe,MultiRoblox.exe,MultipleRoblox.exe,Multiple Roblox.exe"

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

    ; --- System Settings Check ---
    checkPassed := true
    errorMessages := ""

    SysGet, screenWidth, 0
    SysGet, screenHeight, 1
    if (screenWidth != 1920 || screenHeight != 1080) {
        checkPassed := false
        errorMessages .= "• Screen Resolution: " screenWidth "x" screenHeight " (Required: 1920x1080)`n"
    }

    hDC := DllCall("GetDC", "Ptr", 0)
    dpi := DllCall("GetDeviceCaps", "Ptr", hDC, "int", 88) 
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
    
    if (dpi != 96) {
        checkPassed := false
        scalingPercent := Round(dpi / 96 * 100)
        errorMessages .= "• Windows Scaling: " scalingPercent "% (Required: 100%)`n"
    }

    WinGetPos, taskbarX, taskbarY, taskbarW, taskbarH, ahk_class Shell_TrayWnd
    if (taskbarY >= screenHeight - 5 || taskbarY <= 0) {
        DetectHiddenWindows, On
        WinGet, taskbarStyle, Style, ahk_class Shell_TrayWnd
        DetectHiddenWindows, Off
        
        if (taskbarStyle & 0x10000000) { 
            VarSetCapacity(APPBARDATA, 36, 0)
            NumPut(36, APPBARDATA, 0)
            state := DllCall("Shell32.dll\SHAppBarMessage", "UInt", 0x00000004, "Ptr", &APPBARDATA) 
            if (state & 0x00000001) { 
                checkPassed := false
                errorMessages .= "• Taskbar is set to auto-hide (Turn off auto-hide!)`n"
            }
        } else {
            checkPassed := false
            errorMessages .= "• Taskbar is hidden (Required: Always visible)`n"
        }
    }

    if (!checkPassed) {
        IniRead, SkipWarnings, %SettingsFile%, Settings, SkipDisplayWarnings, 0
        if (SkipWarnings = 1)
            goto SkipDisplayCheck
        
        Gui, ErrorCheck:New, +AlwaysOnTop -Caption +Border
        Gui, Color, 1A1A1A
        
        Gui, Font, s14 w700 cFF4444, Bahnschrift
        Gui, Add, Text, x20 y15 w400 Center, ⚠ SYSTEM SETTINGS ERROR
        
        Gui, Font, s11 w400 cFFFFFF, Segoe UI
        Gui, Add, Text, x20 y+10 w360, The following issues were detected:
        
        Gui, Font, s10 w400 cFF8888, Consolas
        Gui, Add, Text, x30 y+10 w340, %errorMessages%
        
        Gui, Font, s10 w400 cCCCCCC, Segoe UI
        Gui, Add, Text, x20 y+10 w360, Required settings for TDS Macro:
        Gui, Add, Text, x30 y+5 w340, • Resolution: 1920x1080
        Gui, Add, Text, x30 y+5 w340, • Windows Scaling: 100`%
        Gui, Add, Text, x30 y+5 w340, • Taskbar: Visible
        
        Gui, Font, s9 w400 c888888, Segoe UI
        Gui, Add, Checkbox, x300 y+5 vDontShowAgain, Don't show again
        
        Gui, Font, s11 w1000 cFFFFFF, Segoe UI
        Gui, Add, Button, x30 y+10 w380 h35 gErrorCheckContinue, CONTINUE ANYWAY
        
        Gui, Add, Text, x20 y+10 w360 h1 +Hidden, .
        
        Gui, Show, w400 AutoSize, Configuration Error
        
        OnMessage(0x0201, "WM_LBUTTONDOWN_ErrorCheck")
        
        WinWaitClose, Configuration Error
    }
    
    SkipDisplayCheck:

}

WM_LBUTTONDOWN_ErrorCheck() {
    if WinActive("Configuration Error")
        PostMessage, 0xA1, 2,,, A
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
Gui, Add, Text, x65 y22 w200 vTitle, ULTIMATE MACRO

Gui, Font, s14 w400 cFFFFFF, Segoe UI

Gui, Add, Text, x295 y18 gShowFAQ +Center w25 h25, ?
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

Gui, Font, s9 w500 c444444, Segoe UI
Gui, Add, Text, x0 y260 w400 Center, PRESS ESC TO EXIT

Gui, Font, s8 w400 c444444, Segoe UI
Gui, Add, Text, x10 y260 w80 Left, %ver%

Gui, Show, w400 h285, TDS Macro (Ultimate Macro)
return


IniRead, autoRun, %StateFile%, State, Running, 0
IniRead, autoStrat, %StateFile%, State, Strategy, %A_Space%
IniRead, savedStartTime, %StateFile%, State, StartTime, 0
if (savedStartTime != 0) {
    AutorunStartTime := savedStartTime
}
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

Esc::
    KillSubmacros()
    
    if (RunningStrategy) {
        if (AutorunStartTime > 0) {
            runtime := FormatRuntime(AutorunStartTime)
            
            IniRead, startCoins, %StateFile%, State, StartCoins, 0
            IniRead, startGems, %StateFile%, State, StartGems, 0
            IniRead, earnedCoins, %StateFile%, State, Coins, 0
            IniRead, earnedGems, %StateFile%, State, Gems, 0
            
            coinsEarned := earnedCoins - startCoins
            gemsEarned := earnedGems - startGems
            
            LogToConsole("Strategy stopped. Runtime: " . runtime)

            if (startCoins > 0 || startGems > 0) {
                LogToConsole("Coins earned: " . coinsEarned . " | Gems earned: " . gemsEarned)
            }

            FormatTime, time,, HH:mm:ss
            SendToWebhookInstant("[" time "] Strategy stopped. Runtime: " . runtime)
            
            IniDelete, %StateFile%, State, StartTime
            AutorunStartTime := 0
        }
        DeleteAllIndicators()
        IniWrite, 0, %StateFile%, State, Running
        IniWrite, 0, %StateFile%, State, Strategy
        IniDelete, %StateFile%, State, StartCoins
        IniDelete, %StateFile%, State, StartGems
        IniDelete, %StateFile%, State, Coins
        IniDelete, %StateFile%, State, Gems
        IniDelete, %StateFile%, State, TotalTriumphs
        IniDelete, %StateFile%, State, TotalLosses
        SafeReload()
        return
    }
    
    DeleteAllIndicators()
    Gui, Overlay:Destroy
    Gui, Main:Destroy
    Gui, Settings:Destroy
    Gui, StrategySettings:Destroy
    Gui, Progress:Destroy
    
    IniWrite, 0, %StateFile%, State, Running
    ExitApp
return

ShowFAQ:
    faqText := 
(
"[SCREEN AND SYSTEM SETTINGS]
- Screen Resolution: Works strictly in 1920x1080.
- Windows Scale: Must be set to 100%. Right-click desktop -> Display settings -> Scale. 125% or 150% will break the macro.
- Taskbar: Must be visible. If hidden, the macro will not work.

[ROBLOX AND GAME SETTINGS]
- UI Scale: Set to Large.
- Screen Shake: Must be DISABLED.
- Roblox Chat: Close the chat before starting the macro.
- Set 'Prefer Vertical Upgrades' to Disabled.
- Fonts: Do not use custom fonts. They break the macro.

[COMMANDER ISSUES]
- Auto Chain: If it does not work, check tower IDs. Enter 'Commander1', 'Commander2', 'Commander3', etc., when placing them."
)
    ModernMsgBox("FAQ", faqText, "OK", "Blue")
return

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
        FormatTime, time,, HH:mm:ss
        SplitPath, stratFile, fileName
        startInfo := "[" time "] Started strategy: " fileName "`n"
        startInfo .= "Map = " map "`n"
        startInfo .= "Mode = " difficulty "`n"
        startInfo .= "Timescale = " TimeScaleMode "`n"
        startInfo .= "Required Towers: " requiredTowers
        
        if (modifiers != "") {
            startInfo .= "`nModifiers: " modifiers
        }
        
        SendToWebhookInstant(startInfo)
        RunStrategy()
    }
    else {
        ModernMsgBox("Warning", "Select a strategy file first!", "OK", "Red")
    }
return

SelectStrat:
    FileSelectFile, stratFile, 3, %RecordingsDir%, Select strategy file, Strategy (*.strat)
    if (stratFile != "") {
        GuiControl,, CurrentStrat, %stratFile%
        LoadStrategyFile(stratFile)
    }
return

StartRecordGUI:
    ShowSettingsGUI()
return

StopRecord:
    if (MacroRecording) {
        MacroRecording := false
        if (InputHookObj != "")
            InputHookObj.Stop()
        
        LogToConsole("Macro recording auto-stopped")
        
        if (ModernMsgBox("Add to Strategy?", "Add recorded actions to current strategy?", "YES|NO", "Blue") = "YES") {
            for i, step in MacroSteps
                RecordedSteps.Push(step)
            LogToConsole("Added " MacroSteps.MaxIndex() " macro steps to strategy")
        }
    }
    
    if (!Recording)
        return
    Recording := false
    Gui, Main:Font, s16 w600 cFFFFFF, Bahnschrift
    GuiControl, Main:Font, Title
    GuiControl, Main:, Title, ULTIMATE MACRO
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
        FileAppend, [Settings]`nmap=%map%`ndifficulty=%difficulty%`nrequiredTowers=%requiredTowers%`nmodifiers=%modifiers%`nchainInterval=%chainInterval%`ncaravanInterval=%caravanInterval%`nautoChain=%autoChain%`nautoCaravan=%autoCaravan%`nautoDropTheBeat=%autoDropTheBeat%`nautoSkip=%AutoSkip%`nmoveEnabled=%MoveEnabled%`nmoveDirection=%MoveDirection%`nmoveDuration=%MoveDuration%`n`n[Steps]`n, %filePath%
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
    Gui, Color, 121212, 1E1E1E 
    
    Gui, Add, Progress, x0 y0 w520 h3 Background3A86FF, 0
    
    Gui, Font, s14 w600 cFFFFFF, Bahnschrift
    Gui, Add, Text, x25 y18 w200 h25, SETTINGS
    
    Gui, Font, s9 w400 c666666, Bahnschrift
    Gui, Add, Text, x345 y23 w150 h20 Right, Created by Darksen
    
    Gui, Font, s10 w600 c3A86FF, Bahnschrift
    Gui, Add, Text, x25 y60 w220, KEYBINDS
    
    Gui, Font, s9 w400 cA0A0A0
    Gui, Add, Text, x25 y90 w150 h20, Commander (Call of Arms):
    Gui, Font, s10 w600 cFFFFFF
    Gui, Add, Edit, x180 y87 w40 h22 vChainKey Center -E0x200, %ChainKey%
    Gui, Font, s9 w600 cFFFFFF
    Gui, Add, Button, x225 y87 w22 h22 gHelpChain, ?

    Gui, Font, s9 w400 cA0A0A0
    Gui, Add, Text, x25 y125 w150 h20, DJ (Drop The Beat):
    Gui, Font, s10 w600 cFFFFFF
    Gui, Add, Edit, x180 y122 w40 h22 vBeatKey Center -E0x200, %BeatKey%
    Gui, Font, s9 w600 cFFFFFF
    Gui, Add, Button, x225 y122 w22 h22 gHelpBeat, ?

    Gui, Font, s9 w400 cA0A0A0
    Gui, Add, Text, x25 y160 w150 h20, Support Caravan:
    Gui, Font, s10 w600 cFFFFFF
    Gui, Add, Edit, x180 y157 w40 h22 vCaravanKey Center -E0x200, %CaravanKey%
    Gui, Font, s9 w600 cFFFFFF
    Gui, Add, Button, x225 y157 w22 h22 gHelpCaravan, ?

    Gui, Font, s10 w600 c3A86FF
    Gui, Add, Text, x275 y60 w220, OTHER
    
    Gui, Font, s9 w400 cA0A0A0
    Gui, Add, Text, x275 y90 w70 h20, Timescale:
    Gui, Add, DropDownList, x350 y86 w70 vTimeScaleMode, OFF|1.5x|2x
    GuiControl, ChooseString, TimeScaleMode, %TimeScaleMode%
    Gui, Font, s8 w600 cFFFFFF
    Gui, Add, Button, x425 y86 w70 h22 gHelpTimeScale, INFO

    Gui, Font, s9 w400 cA0A0A0
    Gui, Add, CheckBox, x275 y126 w195 vAutoCameraCheck Checked%AutoCameraCheck%, Auto camera correction

    Gui, Add, CheckBox, x275 y154 vUseRestartBtn Checked%UseRestartBtn%, Click Restart button
    Gui, Font, s9 w600 cFFFFFF
    Gui, Add, Button, x405 y152 w18 h18 gHelpRestartBtn, ?

    Gui, Font, s9 w400 cA0A0A0
    Gui, Add, CheckBox, x275 y182 vUsePlayAgainBtn Checked%UsePlayAgainBtn%, Click Play Again button
    Gui, Font, s9 w600 cFFFFFF
    Gui, Add, Button, x425 y180 w18 h18 gHelpPlayAgainBtn, ?

    Gui, Add, Progress, x25 y235 w470 h1 Background333333, 0

    Gui, Font, s9 w400 cA0A0A0
    Gui, Add, Text, x25 y250 w200, VIP Server Link:
    Gui, Font, s9 w400 cFFFFFF
    Gui, Add, Edit, x25 y270 w470 h24 vVipLink -E0x200 gCheckVipLink, %VipLink%

    Gui, Add, Checkbox, x25 y310 w16 h16 vUseVipServer Checked%UseVipServer% gCheckVipLink
    Gui, Font, s9 w400 cA0A0A0
    Gui, Add, Text, x47 y311 gClickVipLabel, Use VIP Server

    Gui, Add, Checkbox, x145 y310 w16 h16 vDebugConsole Checked%DebugConsole%
    Gui, Font, s9 w400 c4CAF50 
    Gui, Add, Text, x167 y311 gClickDebugLabel, Debug Console

    Gui, Font, s9 w400 cA0A0A0
    Gui, Add, Checkbox, x265 y311 vPotatoMode Checked%PotatoMode%, Potato Mode
    Gui, Font, s9 w600 cFFFFFF
    Gui, Add, Button, x355 y311 w18 h18 gHelpPotatoMode, ?

    Gui, Font, s9 w600 cFFFFFF
    Gui, Add, Button, x25 y350 w150 h35 gOpenWebhookSettings, ⚙ WEBHOOK
    Gui, Add, Button, x190 y350 w305 h35 gSaveSettings Default, SAVE CHANGES
    
    GoSub, CheckVipLink
    Gui, Show, w520 h410, Settings
return


ClickVipLabel:
    Gui, Settings:Submit, NoHide
    if (VipDisabled)
    {
        MsgBox, 0x1010, Error, VIP Link is invalid or empty!
        return
    }
    GuiControl,, UseVipServer, % !UseVipServer
return

ClickDebugLabel:
    Gui, Settings:Submit, NoHide
    GuiControl,, DebugConsole, % !DebugConsole
return

CheckVipLink:
    Gui, Settings:Submit, NoHide

    str := Trim(VipLink)
    
    if (StrLen(str) = 0) {
        VipDisabled := true
        GuiControl, Disable, UseVipServer
        return
    }
    
    RegExMatch(str, "i)roblox\.com\/([a-z]{2}\/)?games\/3260590327\/?([^\/]*)\?privateServerLinkCode=(?<code>[a-z0-9]{32})", NewPrivLink)
    RegExMatch(str, "i)roblox\.com\/share\?code=(?<code>[a-f0-9]{32})", NewShareCode)
    
    if (NewShareCodeCode != "") {
        link := "https://www.roblox.com/share?code=" . NewShareCodeCode . "&type=Server"
        
        wr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        wr.Open("GET", link, 1)
        wr.Send()
        
        if !(wr.WaitForResponse(3000)) || wr.Status != 200 || !InStr(wr.ResponseText, "roblox:start_place_id") {
            MsgBox, 4112, Failed to fetch link, The link could not be fetched.`nMake sure you are using a valid Share Code link and that you copied the entire link.`n`nIt's also possible that Roblox is down.
            goto LinkInvalid
        }
        
        if !InStr(wr.ResponseText, "content=""3260590327""") {
            MsgBox, 4112, Invalid Share Code, Your link is not for Tower Defense Simulator.
            goto LinkInvalid
        }
        
        VipDisabled := false
        GuiControl, Enable, UseVipServer
        return
        
    } else if (NewPrivLinkCode != "") {
        VipDisabled := false
        GuiControl, Enable, UseVipServer
        return
        
    } else {
        MsgBox, 4112, Invalid Private Server Link, Make sure your link is copied correctly and completely
        goto LinkInvalid
    }
    
LinkInvalid:
    VipDisabled := true
    GuiControl,, UseVipServer, 0
    GuiControl, Disable, UseVipServer
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

    IniWrite, %ChainKey%, %SettingsFile%, Hotkeys, Chain
    IniWrite, %BeatKey%, %SettingsFile%, Hotkeys, Beat
    IniWrite, %CaravanKey%, %SettingsFile%, Hotkeys, Caravan
    IniWrite, %TimeScaleMode%, %SettingsFile%, Options, TimeScaleMode
    IniWrite, %VipLink%, %SettingsFile%, Options, VipLink
    IniWrite, %UseVipServer%, %SettingsFile%, Options, UseVipServer
    IniWrite, %DebugConsole%, %SettingsFile%, Options, DebugConsole
    IniWrite, %AutoCameraCheck%, %SettingsFile%, Options, AutoCameraCheck
    IniWrite, %PotatoMode%, %SettingsFile%, Options, PotatoMode
    IniWrite, %UseRestartBtn%, %SettingsFile%, Options, UseRestartBtn
    IniWrite, %UsePlayAgainBtn%, %SettingsFile%, Options, UsePlayAgainBtn

    if (TimeScaleMode = "1.5x") {
        UseTimeScale := true, TimeScaleMultiplier := 1.5
    } else if (TimeScaleMode = "2x") {
        UseTimeScale := true, TimeScaleMultiplier := 2
    } else {
        UseTimeScale := false, TimeScaleMultiplier := 1
    }

    if (DebugConsole = 1) {
        ShowDebugConsole()
    } else {
        HideDebugConsole()
    }

    Gui, WebhookSettings:Submit, NoHide
    IniWrite, %WebhookEnabled%, %SettingsFile%, Webhook, Enabled
    IniWrite, %WebhookLink%, %SettingsFile%, Webhook, Link
    IniWrite, %SendCurrenciesEnabled%, %SettingsFile%, Webhook, SendCurrencies

    Gui, Settings:Destroy
    Gui, WebhookSettings:Destroy
return

CloseWebhookSettings:
Gui, WebhookSettings:Submit
Return

OpenWebhookSettings:
    Gui, WebhookSettings:New, +AlwaysOnTop -Caption +Border +OwnerMain
    Gui, Color, 121212, 1E1E1E
    Gui, Add, Progress, x0 y0 w340 h2 Background3A86FF, 0
    Gui, Font, s12 w600 cFFFFFF, Bahnschrift
    Gui, Add, Text, x20 y15 w300, DISCORD WEBHOOK

    Gui, Font, s10 w400 c888888, Bahnschrift
    Gui, Add, Text, x20 y55, Link:
    Gui, Font, s10 w200 cFFFFFF
    Gui, Add, Edit, x70 y52 w250 h24 vWebhookLink gCheckWebhookLink -E0x200, %WebhookLink%

    Gui, Font, s10 w400 c888888
    webhookChecked := WebhookEnabled
    Gui, Add, Checkbox, x20 y95 vWebhookEnabled gEnableWebhook Checked%webhookChecked%, Use webhook

    sendCurrChecked := SendCurrenciesEnabled
    Gui, Add, Checkbox, x140 y95 vSendCurrenciesEnabled Checked%sendCurrChecked%, Send Currencies
    Gui, Add, Button, x263 y95 w18 h18 gHelpSendCurrencies, ?

    Gui, Font, s11 w600 cFFFFFF
    Gui, Add, Button, x20 y135 w300 h40 gCloseWebhookSettings Default, CLOSE
    
    Gui, Show, w340 h200, Webhook Settings
Return

CheckWebhookLink:
    Gui, WebhookSettings:Submit, NoHide
    
    if (WebhookLink = "") {
        GuiControl, Disable, WebhookEnabled
        GuiControl,, WebhookEnabled, 0
        return
    }
    
    if (!InStr(WebhookLink, "discord.com/api/webhooks/") && !InStr(WebhookLink, "discordapp.com/api/webhooks/")) {
        GuiControl, Disable, WebhookEnabled
        GuiControl,, WebhookEnabled, 0
        return
    }
    
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", WebhookLink, false)
        whr.Send()
        
        if (whr.Status = 200) {
            GuiControl, Enable, WebhookEnabled
        } else {
            GuiControl, Disable, WebhookEnabled
            GuiControl,, WebhookEnabled, 0
        }
    } catch e {
        GuiControl, Disable, WebhookEnabled
        GuiControl,, WebhookEnabled, 0
    }
return

EnableWebhook:
    Gui, WebhookSettings:Submit, NoHide
    
    if (WebhookEnabled) {
        GoSub, CheckWebhookLink
    }
Return

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
    ModernMsgBox("Timescale Info", "1.5x — more stable and recommended for most cases.`n2x — requires special strategies but is much more effective.`n`nThis will automatically turn off if you run out of timescale tickets.", "OK", "Blue")
return
HelpPotatoMode:
    ModernMsgBox("Info", "Turn this on if your macro acts inconsistently or if you have lags.", "OK", "Blue")
Return
HelpSendCurrencies:
    ModernMsgBox("Info", "If you enable the 'Send currencies' toggle, the macro will send you information about your coins, gems, total matches, triumphs, and losses.`n`n May be buggy.", "OK", "Blue")
Return
HelpRestartBtn:
    ModernMsgBox("Info", "If this setting is ON, the macro will use the restart button when you lose.`n`nIt's recommended to turn it OFF if you are using a win strategy and your macro sometimes appears on the wrong map.", "OK", "Blue")
Return
HelpPlayAgainBtn:
    ModernMsgBox("Info", "If this setting is ON, the macro will use the play again button when you win.`n`nIt's recommended to turn it ON. However, if you do not own the VIP gamepass and you're using a private server link, I recommend turning it OFF", "OK", "Blue")
Return
SettingsGuiEscape:
    Gui, Settings:Destroy
return


ShowSettingsGUI() {
    global
    Gui, StrategySettings:New, +AlwaysOnTop -Caption +Border +LastFound, Strategy Setup
    Gui, Color, 1A1A1A, 2A2A2A 
    
    Gui, Add, Progress, x0 y0 w400 h2 Background3A86FF, 0

    Gui, Font, s12 w600 cFFFFFF, Bahnschrift
    Gui, Add, Text, x0 y15 w400 Center, STRATEGY CONFIGURATION

    Gui, Font, s9 w600 c3A86FF, Bahnschrift
    Gui, Add, Text, x20 y55, MAIN PARAMETERS
    Gui, Add, Progress, x20 y75 w360 h1 Background333333, 0

    Gui, Font, s10 w400 c888888, Bahnschrift
    Gui, Add, Text, x25 y85, Map:
    Gui, Add, Text, x25 y120, Difficulty:
    Gui, Add, Text, x25 y155, Towers:
    Gui, Add, Text, x25 y190, Modifiers:

    Gui, Font, s10 w600 cFFFFFF
    Gui, Add, Edit, x120 y82 w250 h24 vMap -E0x200 Center, %map%
    Gui, Font, s10 w400 c888888, Bahnschrift
    Gui, Add, DropDownList, x120 y117 w250 vDifficulty, Easy|Casual|Intermediate|Molten|Fallen|Frost|Hardcore|Voidcore|Pizza Party|Badlands II|Polluted Wasteland II
    GuiControl, ChooseString, Difficulty, %difficulty%
    Gui, Font, s10 w600 cFFFFFF    
    Gui, Add, Edit, x120 y152 w250 h24 vRequiredTowers -E0x200 Center, %requiredTowers%
    Gui, Add, Edit, x120 y187 w250 h24 vModifiers -E0x200 Center, %modifiers%

    Gui, Font, s9 w600 c3A86FF, Bahnschrift
    Gui, Add, Text, x20 y230, AUTOMATION & FEATURES
    Gui, Add, Progress, x20 y250 w360 h1 Background333333, 0

    Gui, Font, s10 w400 cFFFFFF, Bahnschrift
    Gui, Add, Checkbox, x25 y265 vAutoChain Checked%autoChain%, Auto Chain
    Gui, Add, Text, x150 y265 c888888, Interval:
    Gui, Add, Edit, x205 y262 w75 h22 vChainInterval -E0x200 Center, %chainInterval%

    Gui, Add, Checkbox, x25 y295 vAutoCaravan Checked%autoCaravan%, Auto Caravan
    Gui, Add, Text, x150 y295 c888888, Interval:
    Gui, Add, Edit, x205 y292 w75 h22 vCaravanInterval -E0x200 Center, %caravanInterval%

    Gui, Add, Checkbox, x25 y325 vAutoDropTheBeat Checked%autoDropTheBeat%, Auto Drop the Beat (DJ)
    
    Gui, Add, Checkbox, x25 y355 vAutoSkip Checked%AutoSkip%, Auto-Skip Waves

    Gui, Font, s10 w400 cFFFFFF, Bahnschrift
    Gui, Add, Checkbox, x25 y385 vMoveEnabled Checked%MoveEnabled%, Enable Move
    Gui, Add, Text, x150 y385 c888888, Dir:
    Gui, Add, DropDownList, x180 y382 w50 vMoveDirection, W||A||S||D
    GuiControl, ChooseString, MoveDirection, %MoveDirection%
    Gui, Add, Text, x240 y385 c888888, Dur (ms):
    Gui, Add, Edit, x300 y382 w50 h22 vMoveDuration -E0x200 Center, %MoveDuration%
    Gui, Add, Button, x355 y381 w22 h22 gHelpMove, ?

    Gui, Font, s11 w600 cFFFFFF, Bahnschrift
    Gui, Add, Button, x20 y430 w175 h45 gStrategySettingsOK Default, START RECORD
    Gui, Add, Button, x210 y430 w175 h45 gStrategySettingsCancel, CANCEL

    Gui, Show, w400 h505, Strategy Setup
    WinWaitClose, Strategy Setup
    return


    HelpMove:
        HelpText := "This movement will be applied at two points: when restarting for normal games (to adjust spawn), and after aligning camera."
        ModernMsgBox("Move Info", HelpText, "OK", "Blue")
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
        MoveEnabled := MoveEnabled ? true : false
        MoveDirection := MoveDirection
        MoveDuration := (MoveDuration is number) ? MoveDuration : 750
        if (MoveDirection != "W" and MoveDirection != "A" and MoveDirection != "S" and MoveDirection != "D")
            MoveDirection := "W"
        modifiers := Modifiers
        
        Commander := false
        Gui, StrategySettings:Destroy
        Recording := true
        RecordedSteps := []
        Towers := {}
        DeleteAllIndicators()

        Gui, Main:Font, s16 w600 cFF0000, Bahnschrift
        GuiControl, Main:Font, Title
        GuiControl, Main:, Title, ULTIMATE MACRO 🔴
        GuiControl, Main:Show, StopButton

        LogToConsole("Recording started:")
        LogToConsole("- Mouse Wheel Button: place tower")
        LogToConsole("- U while hovering over the tower indicator: upgrade")
        LogToConsole("- Ctrl+D: set DJ track")
        LogToConsole("- Ctrl+T: Align Camera")
        LogToConsole("- Ctrl+X: Sell Tower")
        LogToConsole("- Ctrl+B: Delete tower (Cancel)")
        LogToConsole("- Ctrl+X: Sell tower")
        LogToConsole("- Ctrl+Alt+A: Record Inputs")

        ModernMsgBox("Recording", "Recording enabled:`n- MButton: place tower`n- U: upgrade`n- Ctrl+D: set DJ track`n- Ctrl+T: Align Camera`n- Ctrl+B: Delete tower (Cancel)`n- Ctrl+X: Sell tower`n- Ctrl+Alt+A: Record Inputs", "OK", "Blue")
    return

    StrategySettingsCancel:
        Gui, StrategySettings:Destroy
    return
}


MButton::
    if (!Recording)
        return

    WinMinimize, TDS Macro (Ultimate Macro)
    MouseGetPos, mx, my
    InputBox, slot, Slot (1-5), Enter the tower slot number (1-5):,,,,,,,,1
    if ErrorLevel
        return
    suggestedID := GetNextNumericID()
    InputBox, towerID, Tower ID, Enter a specific tower id:,,,,,,,,%suggestedID%
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

~u::
    if (!Recording)
        return
        
    MouseGetPos, mx, my
    closestID := FindClosestTower(mx, my)
    if (closestID != "") {
        Towers[closestID].level += 1
        UpdateTowerIndicator(closestID)
        if (Recording) {
            if (Towers[closestID].path != 0 && Towers[closestID].path != "") {
                RecordedSteps.Push("UpgradeTower(" closestID ", false, 1, " Towers[closestID].path ", " Towers[closestID].pathLevel ")")
                LogToConsole("Recorded upgrade tower " closestID " to level " Towers[closestID].level ")")
            } else {
                RecordedSteps.Push("UpgradeTower(" closestID ")")
                LogToConsole("Recorded upgrade tower " closestID " (level " Towers[closestID].level ")")
            }
            if (Towers[closestID].level >= 2 && RegExMatch(closestID, "i)^Commander\d*$") && !Commander) {
                Commander := true
                if (!HasStep("Commander := true"))
                    RecordedSteps.Push("Commander := true")
            }
        } else {
            LogToConsole("Tower " closestID " upgraded to level " Towers[closestID].level)
        }
    } else {
        LogToConsole("Can't find the tower to upgrade")
    }
return

^d::
    WinMinimize, TDS Macro (Ultimate Macro)

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
            if (RegExMatch(step, "i)^SpawnTower\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*" . closestID . "\s*\)$"))
                continue
            if (RegExMatch(step, "i)^UpgradeTower\s*\(\s*" . closestID . "\s*(?:,.*)?\s*\)$"))
                continue
            if (RegExMatch(step, "i)^SellTower\s*\(\s*" . closestID . "\s*\)$"))
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
        
        newSteps := []
        for i, step in RecordedSteps {
            if (RegExMatch(step, "i)^SpawnTower\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*" . closestID . "\s*\)$"))
                continue
            if (RegExMatch(step, "i)^UpgradeTower\s*\(\s*" . closestID . "\s*\)$"))
                continue
            newSteps.Push(step)
        }
        RecordedSteps := newSteps
        
        Towers.Delete(closestID)
        
        LogToConsole("Recorded sell tower " . closestID)
    } else {
        LogToConsole("No tower found near cursor to sell")
    }
return

^t::AlignCamera()

^!a::
    if (!Recording) {
        return
    }
    
    if (MacroRecording) {
        MacroRecording := false
        if (InputHookObj != "")
            InputHookObj.Stop()

        LogToConsole("Recording ALL clicks and keys STOPPED. Steps: " MacroSteps.MaxIndex())
        
        if (ModernMsgBox("Add to Strategy?", "Add recorded actions to current strategy?", "YES|NO", "Blue") = "YES") {
            for i, step in MacroSteps
                RecordedSteps.Push(step)
            LogToConsole("Added " MacroSteps.MaxIndex() " steps to strategy")
        }
        
    } else {
        MacroRecording := true
        MacroSteps := []
        MacroStartTime := A_TickCount
        
        LogToConsole("Recording ALL clicks and keys...!")
        LogToConsole("Ctrl+Alt+A = Stop")
        
        InputHookObj := InputHook("V")
        InputHookObj.KeyOpt("{All}", "N")
        InputHookObj.OnKeyDown := Func("OnKeyDown")
        InputHookObj.Start()
    }
return

OnKeyDown(ih, vk, sc) {
    global MacroSteps, MacroStartTime, MacroRecording
    
    if (!MacroRecording)
        return
    
    if (vk = 0xA0 || vk = 0xA1 || vk = 0xA2 || vk = 0xA3
        || vk = 0xA4 || vk = 0xA5  ; Alt
        || vk = 0x5B || vk = 0x5C  ; Win
        || vk = 0x11 || vk = 0x12  ; Ctrl, Alt
        || vk = 0x41) 
        return
    
    elapsed := A_TickCount - MacroStartTime
    MacroStartTime := A_TickCount
    
    keyName := GetKeyNameFromVK(vk, sc)
    
    MacroSteps.Push("Sleep(" elapsed ")")
    MacroSteps.Push("Send(""" keyName """, hold:=50)")
    LogToConsole("Key: " keyName)
}

~LButton::
    if (!MacroRecording)
        return
    MouseGetPos, mx, my
    elapsed := A_TickCount - MacroStartTime
    MacroStartTime := A_TickCount
    MacroSteps.Push("Sleep(" elapsed ")")
    MacroSteps.Push("Click(" mx ", " my ")")
    LogToConsole("Click: L (" mx ", " my ")")
return

~RButton::
    if (MacroRecording) {
        MouseGetPos, mx, my
        elapsed := A_TickCount - MacroStartTime
        MacroStartTime := A_TickCount
        MacroSteps.Push("Sleep(" elapsed ")")
        MacroSteps.Push("Click(" mx ", " my ", Right)")
        LogToConsole("Click: R (" mx ", " my ")")
        return
    }
    
    MouseGetPos,,, clickedHwnd
    
    if (!clickedHwnd)
        return
        
    towerID := ""
    for id, t in Towers {
        if (t.hwnd = clickedHwnd) {
            towerID := id
            break
        }
    }
    
    if (towerID != "") {
        ShowTowerPathDialog(towerID)
    }
return

GetKeyNameFromVK(vk, sc) {
    static map := {0x08: "Backspace", 0x09: "Tab", 0x0D: "Enter"
        , 0x1B: "Escape", 0x20: "Space", 0x21: "PgUp", 0x22: "PgDn"
        , 0x23: "End", 0x24: "Home", 0x25: "Left", 0x26: "Up"
        , 0x27: "Right", 0x28: "Down", 0x2D: "Insert", 0x2E: "Delete"
        , 0x30: "0", 0x31: "1", 0x32: "2", 0x33: "3", 0x34: "4"
        , 0x35: "5", 0x36: "6", 0x37: "7", 0x38: "8", 0x39: "9"
        , 0x41: "A", 0x42: "B", 0x43: "C", 0x44: "D", 0x45: "E"
        , 0x46: "F", 0x47: "G", 0x48: "H", 0x49: "I", 0x4A: "J"
        , 0x4B: "K", 0x4C: "L", 0x4D: "M", 0x4E: "N", 0x4F: "O"
        , 0x50: "P", 0x51: "Q", 0x52: "R", 0x53: "S", 0x54: "T"
        , 0x55: "U", 0x56: "V", 0x57: "W", 0x58: "X", 0x59: "Y"
        , 0x5A: "Z", 0x70: "F1", 0x71: "F2", 0x72: "F3"
        , 0x73: "F4", 0x74: "F5", 0x75: "F6", 0x76: "F7"
        , 0x77: "F8", 0x78: "F9", 0x79: "F10", 0x7A: "F11"
        , 0x7B: "F12", 0xBC: ",", 0xBD: "-", 0xBE: ".", 0xBF: "/"
        , 0xC0: "`", 0xDB: "[", 0xDC: "\", 0xDD: "]", 0xDE: "'"
        , 0xBA: ";", 0xBB: "="}
    
    if map.HasKey(vk)
        return map[vk]
    
    lParam := (sc << 16) | (1 << 24)
    VarSetCapacity(name, 32)
    DllCall("GetKeyNameText", "UInt", lParam, "Str", name, "Int", 32)
    return name != "" ? name : "VK" . Format("{:02X}", vk)
}

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
    IniRead, tempEnabled, %file%, Settings, moveEnabled, ""
    IniRead, tempDir, %file%, Settings, moveDirection, ""
    IniRead, tempDur, %file%, Settings, moveDuration, ""

    if (tempEnabled != "") {
        MoveEnabled := (tempEnabled = "true" or tempEnabled = "1") ? true : false
        MoveDirection := (tempDir != "" and (tempDir = "W" or tempDir = "A" or tempDir = "S" or tempDir = "D")) ? tempDir : "W"
        MoveDuration := (tempDur is number) ? tempDur : 750
    } else {
        if (moveDown = "true") {
            MoveEnabled := true
            MoveDirection := "S"
            MoveDuration := 750
        } else {
            MoveEnabled := false
            MoveDirection := "W"
            MoveDuration := 750
        }
    }

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
    
    for i, step in RecordedSteps {
        if (RegExMatch(step, "i)SpawnTower\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*([^\s,)]+)\s*\)", m)) {
            towerID := m1
            Towers[towerID] := {x: 0, y: 0, slot: 0, level: 0, path: 0, pathLevel: 0}
        }
        if (RegExMatch(step, "i)UpgradeTower\s*\(\s*([^,]+?)\s*(?:,\s*(false|true)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?\s*\)", m)) {
            towerID := Trim(m1)
            if (Towers[towerID] && m4 != "") {
                Towers[towerID].path := m4
                Towers[towerID].pathLevel := (m5 != "") ? m5 : 4
            }
        }
    }
}

RunStrategy() {
    global RunningStrategy, difficulty, MoveEnabled, MoveDirection, MoveDuration, unfocusX, unfocusY, UseTimeScale, TimeScaleMultiplier, TimeScaleMode, SettingsFile, requiredTowers, modifiers, LastOpenedTowerID
    if (RunningStrategy != true)
        return

    SetBatchLines, -1

    KillSubmacros()
    currentPID := DllCall("GetCurrentProcessId")
    Run, "%A_ScriptDir%\submacros\checker.ahk" %currentPID%, , , CheckerPID
    if (WebhookEnabled)
    {
        Run, "%A_ScriptDir%\submacros\discord.ahk" %currentPID%, , , DiscordPID
    }

    LastDisconnectCheck := A_TickCount
    
    global LastSkipCheck := 0
    global SKIP_CHECK_INTERVAL := 1000
    global LastOpenedTowerID := ""

    LogToConsole("Starting strategy... Press ESC to STOP!!!")
    LogToConsole("Map = " map)
    LogToConsole("Mode = " difficulty)
    LogToConsole("Timescale = " TimeScaleMode)
    LogToConsole("Required Towers: " requiredTowers)
    if (modifiers != "") {
        LogToConsole("Modifiers: " modifiers)
    }

    IniRead, checkStart, %StateFile%, State, StartTime, 0
    if (checkStart = 0) {
        IniWrite, %A_TickCount%, %StateFile%, State, StartTime
        AutorunStartTime := A_TickCount
    } else {
        AutorunStartTime := checkStart
    }
    
    if (difficulty != "Hardcore" and difficulty != "Voidcore")
        CheckRestartForNormalGames()
    else
        CheckRestartForHardcore()

    LoadGame()

    i := 1
    while (i <= RecordedSteps.MaxIndex()) {

        step := RecordedSteps[i]
        
        isMacroStep := RegExMatch(step, "i)^(Click|Send|Sleep)\s*\(")
        
        if (i > 3 && A_TickCount - LastSkipCheck > SKIP_CHECK_INTERVAL && !isMacroStep) {
            if (i + 1 <= RecordedSteps.MaxIndex()) {
                nextStep := RecordedSteps[i + 1]
                isNextMacroStep := RegExMatch(nextStep, "i)^(Click|Send|Sleep)\s*\(")
                
                if (!isNextMacroStep && !RegExMatch(nextStep, "i)SetDJTrack")) {
                    UseAbilities()
                    LastSkipCheck := A_TickCount
                }
            } else {
                UseAbilities()
                LastSkipCheck := A_TickCount
            }
        }

        if (RegExMatch(step, "i)UpgradeTower\s*\(\s*([^,]+?)\s*(?:,\s*(false|true)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?\s*\)", m)) {
            currentID := Trim(m1)
            skipOpen := (m2 = "true") ? true : false
            countUpgrades := (m3 != "") ? m3 : 1
            currentPath := (m4 != "") ? m4 : 0
            currentpathLevel := (m5 != "") ? m5 : 4

            lookAhead := i + 1
            while (lookAhead <= RecordedSteps.MaxIndex()) {
                nextStep := RecordedSteps[lookAhead]
                if (RegExMatch(nextStep, "i)UpgradeTower\s*\(\s*" currentID "\s*(?:,\s*(false|true)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?\s*\)", mNext)) {
                    additionalCount := (mNext3 != "") ? mNext3 : 1
                    countUpgrades += additionalCount
                    lookAhead++
                } else {
                    break
                }
            }

            success := UpgradeTower(currentID, false, countUpgrades, currentPath, currentpathLevel)
            if (success)
            {
                i := lookAhead
            } else {
                i++
            }
            
            nextGlobalStep := RecordedSteps[i]
            if (!RegExMatch(nextGlobalStep, "i)SetDJTrack")) {
                Click, %unfocusX%, %unfocusY%
                LastOpenedTowerID := ""
                Sleep, 20
            }
        } else if (RegExMatch(step, "i)SetDJTrack\s*\(\s*([^\s,)]+)\s*\)", t)) {
            trackParam := t1
            SetDJTrack(trackParam)
            i++
        } else if (RegExMatch(step, "i)SpawnTower\s*\(.*\)")) {
            ExecuteStep(step)
            i++
        } else {
            if (LastOpenedTowerID != "") {
                isMacroStep := RegExMatch(step, "i)^(Click|Send|Sleep)\s*\(")
                if (!isMacroStep) {
                    Click, %unfocusX%, %unfocusY%
                    LastOpenedTowerID := ""
                    Sleep, 20
                }
            }
            try {
                ExecuteStep(step)
            } catch e {
                LogToConsole("ERROR executing step " i ": " step)
            }
            i++
        }
    }

    LogToConsole("All strategy steps completed, entering maintenance loop...")
    Loop {
        Sleep, 500
        if (A_TickCount - LastSkipCheck > SKIP_CHECK_INTERVAL) {
            UseAbilities()
            LastSkipCheck := A_TickCount
        }
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
    if (RegExMatch(step, "i)UpgradeTower\s*\(\s*([^,]+?)\s*(?:,\s*(false|true)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?\s*\)", m)) {
        towerID := Trim(m1)
        skipOpen := (m2 = "true") ? true : false
        totalUpgrades := (m3 != "") ? m3 : 1
        path := (m4 != "") ? m4 : 0
        pathLevel := (m5 != "") ? m5 : 4
        UpgradeTower(towerID, skipOpen, totalUpgrades, path, pathLevel)
        return
    }
    if (RegExMatch(step, "i)SetDJTrack\s*\(\s*(.+?)\s*\)", m)) {
        track := Trim(m1, " """)
        if (track != "") {
            SetDJTrack(track)
        }
        return
    }
    if (RegExMatch(step, "i)^Click\s*\(\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(.+?))?\s*\)$", m)) {
        mx := m1, my := m2
        button := (InStr(m3, "Right")) ? "Right" : "Left"
        Click, %button%, %mx%, %my%
        return
    }
    if (RegExMatch(step, "i)^Send\s*\(\s*""([^""]+)""\s*,\s*hold:=(\d+)\s*\)$", m)) {
        key := m1
        hold := m2
        Send, {%key% down}
        Sleep, %hold%
        Send, {%key% up}
        return
    }
    if (RegExMatch(step, "i)^Sleep\s*\(\s*(\d+)\s*\)$", m)) {
        Sleep, % m1
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

;CheckDisconnectedPeriodic() {
    ;global LastDisconnectCheck
    ;if (A_TickCount - LastDisconnectCheck > 60000) {
        ;LastDisconnectCheck := A_TickCount
        ;
       ; if !WinExist("ahk_exe RobloxPlayerBeta.exe") {
      ;      LogToConsole("Roblox not running! Reloading...")
     ;       SafeReload()
    ;    }
   ;     
  ;      CheckDisconnected()
 ;       CheckCritical()
;    }
;}
;CheckDisconnected() {
 ;   ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *15 Resources\Disconnected.png
  ;  if (ErrorLevel = 0)
   ;     SafeReload()
;}

CheckRestartForNormalGames() {
    global MoveEnabled, MoveDirection, MoveDuration, IsRestarting, difficulty, UseRestartBtn, UsePlayAgainBtn
    processName := "ahk_exe RobloxPlayerBeta.exe"
    
    if WinExist(processName) {
        WinActivate, %processName%
        Sleep, 1500
        
        if (UseRestartBtn = 1) {
            ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *40 Resources\Restart.png
            foundRestart := (ErrorLevel = 0 && FoundX > 0 && FoundY > 0)
            
            if (!foundRestart) {
                ImageSearch, FoundX2, FoundY2, 0, 0, A_ScreenWidth, A_ScreenHeight, *40 Resources\Restart2.png
                foundRestart := (ErrorLevel = 0 && FoundX2 > 0 && FoundY2 > 0)
                if (foundRestart) {
                    FoundX := FoundX2
                    FoundY := FoundY2
                }
            }
            
            if (foundRestart) {
                IsRestarting := true
                LogToConsole("Restarting the match")
                TargetX := FoundX + 40
                TargetY := FoundY + 10
                Click, %TargetX%, %TargetY%
                Sleep, 150
                Return
            }
        }
        
        if (UsePlayAgainBtn = 1) {
            ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *40 Resources\PlayAgain.png
            foundPlayAgain := (ErrorLevel = 0 && FoundX > 0 && FoundY > 0)
            
            if (!foundPlayAgain) {
                ImageSearch, FoundX3, FoundY3, 0, 0, A_ScreenWidth, A_ScreenHeight, *40 Resources\PlayAgain2.png
                foundPlayAgain := (ErrorLevel = 0 && FoundX3 > 0 && FoundY3 > 0)
                if (foundPlayAgain) {
                    FoundX := FoundX3
                    FoundY := FoundY3
                }
            }
            
            if (foundPlayAgain) {
                TargetX := FoundX + 40
                TargetY := FoundY + 10
                Click, %TargetX%, %TargetY%
                Sleep, 150
                WaitForLobbyLoad()
                return
            }
        }
    }
    
    IsRestarting := false
    RunRoblox()
    JoinGame(difficulty)
}

CheckRestartForHardcore() {
    global IsRestarting, UseRestartBtn
    if WinExist("ahk_exe RobloxPlayerBeta.exe") {
        WinActivate, ahk_exe RobloxPlayerBeta.exe
        Sleep, 1500
        
        if (UseRestartBtn = 1) {
            ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *40 Resources\Restart.png
            foundRestart := (ErrorLevel = 0 && FoundX > 0 && FoundY > 0)
            
            if (!foundRestart) {
                ImageSearch, FoundX2, FoundY2, 0, 0, A_ScreenWidth, A_ScreenHeight, *40 Resources\Restart2.png
                foundRestart := (ErrorLevel = 0 && FoundX2 > 0 && FoundY2 > 0)
                if (foundRestart) {
                    FoundX := FoundX2
                    FoundY := FoundY2
                }
            } 
        }
        
        if (!foundRestart) {
            IsRestarting := false
            RunRoblox()
            JoinHardcore()
        } else {
            IsRestarting := true
            LogToConsole("Restarting the match")
            TargetX := FoundX + 40
            TargetY := FoundY + 10
            Click, %TargetX%, %TargetY%
            Sleep, 150
        }
    } else {
        IsRestarting := false
        RunRoblox()
        JoinHardcore()
    }
}

RunRoblox() {
    global VipLink, UseVipServer
    
    PlaceID := "3260590327"
    
    if (UseVipServer = 1 && VipLink != "") {
        vipCode := ""
        
        if (InStr(VipLink, "privateServerLinkCode=")) {
            RegExMatch(VipLink, "privateServerLinkCode=([a-fA-F0-9]+)", found)
            vipCode := found1
            
         DeepLink := "roblox://placeID=" . PlaceID . "&linkcode=" . vipCode
            
        } else if (InStr(VipLink, "share?code=")) {
            RegExMatch(VipLink, "code=([a-fA-F0-9]+)", found)
            vipCode := found1
            
            DeepLink := "roblox://navigation/share_links?code=" . vipCode . "&type=Server"
        } else {
            DeepLink := "roblox://placeID=" . PlaceID
        }
    } else {
        DeepLink := "roblox://placeID=" . PlaceID
    }
    
    Run, %DeepLink%, , , outputPID
    
    WinWait, ahk_exe RobloxPlayerBeta.exe, , 60
    if !ErrorLevel {
        WinActivate, ahk_exe RobloxPlayerBeta.exe
        ExitFullScreen()
        WinMinimize, ahk_exe RobloxPlayerBeta.exe
        WinMaximize, ahk_exe RobloxPlayerBeta.exe
    } else {
        LogToConsole("ERROR: Roblox not started!", true)
        Sleep, 5000
        SafeReload()
    }
    
    Sleep, 20000
    StartTime := A_TickCount 

    Loop {
        if (A_TickCount - StartTime > 90000) {
            SafeReload() 
            Sleep, 1000
        }
        
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

WaitForLobbyLoad()
{
StartTime := A_TickCount 
    if (difficulty != "Pizza Party" && difficulty != "Badlands II" && difficulty != "Polluted Wasteland II")
    {
        sleep, 3000
        Loop {
            if (A_TickCount - StartTime > 90000) {
                SafeReload() 
                Sleep, 1000
            }

            ImageSearch, FoundX, FoundY, 749, 762, 1214, 931, *8 Resources/Ready.png
            if (ErrorLevel = 0)
            {
                break
            }

            if (ErrorLevel = 1)
            {
                ImageSearch, FoundX, FoundY, 749, 762, 1214, 931, *15 Resources/Ready2.png
                if (ErrorLevel = 0)
                {
                    break
                }
            }

            Sleep, 100
        }

        SelectMap()
    }
}

JoinGame(diff) {
    global SendCurrenciesEnabled
    StartTime := A_TickCount
    Loop
    {
        if (A_TickCount - StartTime > 5000) {
            Click, 968, 871
            break
        }
    
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *30 Resources\Play.png
        If (ErrorLevel = 0)
        {
            if (WebhookEnabled && SendCurrenciesEnabled)
            {
                SendStatsToWebhook()
            }
            LogToConsole("Joining " difficulty "...")
            Click, %FoundX%, %FoundY%
            break
        }
        Sleep, 500
    }

    Sleep, 500
    StartTime := A_TickCount
    if (diff = "Pizza Party" || diff = "Badlands II" || diff = "Polluted Wasteland II") {
        Loop
        {
            if (A_TickCount - StartTime > 5000) {
                Click, 1209, 531
                break
            }
            ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *30 Resources\SpecialMode.png
            If (ErrorLevel = 0)
            {
                Click, %FoundX%, %FoundY%
                break
            }
            Sleep, 500
        }
    } else {
        Loop
        {
            if (A_TickCount - StartTime > 5000) {
                Click, 982, 574
                break
            }
            ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *30 Resources\NormalMode.png
            If (ErrorLevel = 0)
            {
                Click, %FoundX%, %FoundY%
                break
            }
            Sleep, 500
        }
    }

    Sleep, 500
    StartTime := A_TickCount
    Loop
    {
        if (A_TickCount - StartTime > 5000) {
            if (diff = "Easy")
                Click, 361, 546
            else if (diff = "Casual")
                Click, 594, 555
            else if (diff = "Intermediate")
                Click, 842, 558
            else if (diff = "Molten")
                Click, 1070, 537
            else if (diff = "Fallen")
                Click, 1317, 565
            else if (diff = "Frost")
                Click, 1566, 573
            else if (diff = "Pizza Party")
                Click, 1184, 557
            else if (diff = "Badlands II")
                Click, 757, 568
            else if (diff = "Polluted Wasteland II")
                Click, 964, 565
            break
        }
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *30 Resources\%diff%.png
        If (ErrorLevel = 0)
        {
            Click, %FoundX%, %FoundY%
            break
        }
        Sleep, 500
    }

    Sleep, 500
    StartTime := A_TickCount
    Loop
    {
        if (A_TickCount - StartTime > 5000) {
            Click, 795, 462
            break
        }
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *30 Resources\Solo.png
        If (ErrorLevel = 0)
        {
            Click, %FoundX%, %FoundY%
            break
        }
        Sleep, 500
    }

    WaitForLobbyLoad()
}

JoinHardcore() {
    global SendCurrenciesEnabled
    StartTime := A_TickCount
    Loop
    {
        if (A_TickCount - StartTime > 5000) {
            Click, 968, 871
            break
        }
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *30 Resources\Play.png
        If (ErrorLevel = 0)
        {
            if (WebhookEnabled && SendCurrenciesEnabled)
            {
                SendStatsToWebhook()
            }
            LogToConsole("Joining " difficulty "...")
            Click, %FoundX%, %FoundY%
            break
        }
        Sleep, 500
    }

    
    Sleep, 500
    StartTime := A_TickCount
    Loop
    {
        if (A_TickCount - StartTime > 5000) {
            Click, 498, 540
            break
        }
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *30 Resources\HardcoreMode.png
        If (ErrorLevel = 0)
        {
            Click, %FoundX%, %FoundY%
            break
        }
        Sleep, 500
    }

    Sleep, 500
    StartTime := A_TickCount
    Loop
    {
        if (A_TickCount - StartTime > 5000) {
            if (difficulty = "Hardcore")
                Click, 858, 541
            else
                Click, 1102, 576
            break
        }
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *30 Resources\%difficulty%.png
        If (ErrorLevel = 0)
        {
            Click, %FoundX%, %FoundY%
            break
        }
        Sleep, 500
    }

    Sleep, 500
    StartTime := A_TickCount
    Loop
    {
        if (A_TickCount - StartTime > 5000) {
            Click, 781, 467
            break
        }
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *30 Resources\Solo.png
        If (ErrorLevel = 0)
        {
            Click, %FoundX%, %FoundY%
            break
        }
        Sleep, 500
    }

    WaitForLobbyLoad()
}

SelectMap() {
    global map, difficulty, modifiers, AutoCameraCheck
    
    LogToConsole("Selecting map: " map)

    sleep, 1200
    closeChat()
    sleep, 300
    if (AutoCameraCheck = 1) {
        if (difficulty = "Hardcore" or difficulty = "Voidcore")
        {
            color1 := 0x9D64FF
            color2 := 0x9664FF
            color3 := ""
        } else {
            color1 := 0x525BFF
            color2 := 0x4044FF
            color3 := 0x463B84
        }
        Loop, 10 {
            PixelSearch, FoundX, FoundY, 656, 308, 1250, 385, %color1%, 10, Fast
            
            if (ErrorLevel = 0) {
                FoundColor := true
                break
            }
            
            Sleep, 200
        }

        if (color3 != "") {
            Loop, 2 {
                PixelSearch, FoundX, FoundY, 656, 308, 1250, 385, %color3%, 10, Fast
                
                if (ErrorLevel = 0) {
                    FoundColor := true
                    break
                }
                
                Sleep, 200
            }
        }

        if (!FoundColor) {
            Loop, 5 {
            PixelSearch, FoundX, FoundY, 656, 308, 1250, 385, %color2%, 5, Fast
            
            if (ErrorLevel = 0) {
                FoundColor := true
                break
            }
            
                Sleep, 300
            }
        }

        if (!FoundColor) {
            LogToConsole("Wrong camera position!")
            Sleep, 200
            IfWinExist, ahk_exe RobloxPlayerBeta.exe
                WinActivate, ahk_exe RobloxPlayerBeta.exe
            Sleep, 100
            
            SendEvent, {Left down}
            Sleep, 1500
            SendEvent, {Left up}
            Sleep, 50
        }
    }

    if (difficulty = "Hardcore" or difficulty = "Voidcore")
    {   
        Sleep, 200
        IfWinExist, ahk_exe RobloxPlayerBeta.exe
            WinActivate, ahk_exe RobloxPlayerBeta.exe
        Sleep, 600
        
        SendEvent, {sc011 down} ; W down
        Sleep, 3000
        SendEvent, {sc011 up}
        Sleep, 300
        
        LogToConsole("Trying to find: " map ". Please wait..")

        pBitmap := Gdip_BitmapFromScreen("0|0|635|" Floor(A_ScreenHeight * 0.6))
        result := ocrFromBitmap(pBitmap)
        Gdip_DisposeImage(pBitmap)
        if InStr(result, map) {
            FoundSlot = 1
        } else {
            pBitmap := Gdip_BitmapFromScreen("635|0|332|" Floor(A_ScreenHeight * 0.6))
            result := ocrFromBitmap(pBitmap)
            Gdip_DisposeImage(pBitmap)
            if InStr(result, map) {
                FoundSlot = 2
            } else {
                pBitmap := Gdip_BitmapFromScreen("967|0|332|" Floor(A_ScreenHeight * 0.6))
                result := ocrFromBitmap(pBitmap)
                Gdip_DisposeImage(pBitmap)
                if InStr(result, map) {
                    FoundSlot = 3
                } else {
                    pBitmap := Gdip_BitmapFromScreen("1299|0|" A_ScreenWidth-1299 "|" Floor(A_ScreenHeight * 0.6))
                    result := ocrFromBitmap(pBitmap)
                    Gdip_DisposeImage(pBitmap)
                    if InStr(result, map) {
                        FoundSlot = 4
                    }
                }
            }
        }

        if (FoundSlot = "" or FoundSlot = 0)
        {
            LogToConsole("Map is not found! Reloading..." FoundSlot, true)
            Sleep, 1000
            SafeReload()
        }
        LogToConsole("Found in slot " . FoundSlot)

        Sleep, 300
        IfWinExist, ahk_exe RobloxPlayerBeta.exe
            WinActivate, ahk_exe RobloxPlayerBeta.exe
        Sleep, 100

        SendEvent, {sc011 down} ; W 
        Sleep, 800 
        SendEvent, {sc011 up}
        Sleep, 200

        if (FoundSlot = 1) { 
            SendEvent, {sc01e down} ; A 
            Sleep, 1400 
            SendEvent, {sc01e up} 
            Sleep, 600
        }
        else if (FoundSlot = 2) { 
            SendEvent, {sc01e down} ; A 
            Sleep, 500  
            SendEvent, {sc01e up} 
            Sleep, 600
        }
        else if (FoundSlot = 3) { 
            SendEvent, {sc020 down} ; D 
            Sleep, 500  
            SendEvent, {sc020 up} 
            Sleep, 600
        }
        else if (FoundSlot = 4) { 
            SendEvent, {sc020 down} ; D 
            Sleep, 1400 
            SendEvent, {sc020 up} 
            Sleep, 600
        }

        SendEvent, {sc012 down} ; E 
        Sleep, 1000
        SendEvent, {sc012 up} 
        Sleep, 100

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
                SendInput, ^a
                Sleep, 100
                Loop, Parse, modifier
                {
                    SendInput, %A_LoopField%
                    Sleep, 10
                }
                Sleep, 200
                Click, 958, 357
                Sleep, 300
                LogToConsole("Modifier added: " modifier)
            }
            Sleep, 100
            Click, 1125, 889
            LogToConsole("All modifiers configured")
        }

        Click, 968, 871
        Sleep, 10000
    } else {
        
        IfWinExist, ahk_exe RobloxPlayerBeta.exe
            WinActivate, ahk_exe RobloxPlayerBeta.exe
        Sleep, 150
        
        SendEvent, {sc011 down} ; W 
        Sleep, 2000
        SendEvent, {sc011 up}
        Sleep, 700
        
        ; D
        SendEvent, {sc020 down} ; D 
        Sleep, 1700
        SendEvent, {sc020 up}
        Sleep, 700
        
        ; E
        SendEvent, {sc012 down} ; E 
        Sleep, 1000
        SendEvent, {sc012 up}
        Sleep, 500
        
        Click, 840, 251
        Sleep, 300
        
        Loop, Parse, map
        {
            SendInput, %A_LoopField%
            Sleep, 40
        }
        Sleep, 300
        Click, 754, 393
        Sleep, 700
        
        pBitmap := Gdip_BitmapFromScreen("840|250|300|200")
        result := ocrFromBitmap(pBitmap)
        Gdip_DisposeImage(pBitmap)
        
        if InStr(result, "already") || InStr(result, "rotation") || InStr(result, "current") {
            LogToConsole(map " is already in the current rotation! Reloading..", true)
            Sleep, 200
            SafeReload()
            Sleep, 400
        }

        changedMap := false

        Loop, 15 {
            PixelSearch, GreenX, GreenY, 804, 265, 1027, 301, 0x00EC00, 2, Fast
            if (!ErrorLevel && GreenX > 0) {
                LogToConsole("Successfully changed the map to " map, true)
                changedMap := true
                break
            }
            sleep, 100
        }

        if (changedMap = false) {
            LogToConsole("Failed to change the map to " map, true)
            SafeReload()
        }
        
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
                SendInput, ^a
                Sleep, 100
                Loop, Parse, modifier
                {
                    SendInput, %A_LoopField%
                    Sleep, 10
                }
                Sleep, 200
                Click, 958, 357
                Sleep, 300
                LogToConsole("Modifier added: " modifier)
            }
            Sleep, 100
            Click, 1125, 889
            LogToConsole("All modifiers configured")
        }
        
        Sleep, 200
        IfWinExist, ahk_exe RobloxPlayerBeta.exe
            WinActivate, ahk_exe RobloxPlayerBeta.exe
        Sleep, 100
        
        SendEvent, {sc01e down} ; A 
        Sleep, 1700
        SendEvent, {sc01e up}
        Sleep, 200
        SendEvent, {sc011 down} ; W 
        Sleep, 1750
        SendEvent, {sc011 up}
        Sleep, 300
        SendEvent, {sc01e down} ; A 
        Sleep, 1050
        SendEvent, {sc01e up}
        Sleep, 600
        
        SendEvent, {sc012 down} ; E 
        Sleep, 800
        SendEvent, {sc012 up}
        Sleep, 100
        Click, 968, 871
        Sleep, 10000

    }

    FoundMap := false

        if (FileExist("Resources\" . map . ".png"))
        {
            FoundMap := false
            Loop, 5 {
                ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *10 Resources\%map%.png
                
                if (ErrorLevel = 0) {
                    FoundMap := true
                    break
                }
                
                Sleep, 400
            }

            if (!FoundMap) {
                LogToConsole("Can't detect the map! Reloading script...", true)
                Sleep, 500
                SafeReload()
            }
        }

    Sleep, 100
}

LoadGame() {
    Loop {
        PixelSearch, FoundX, FoundY, 691, 153, 1191, 260, 0x00EB2B, 3, Fast
        if (ErrorLevel = 0 && FoundX > 0) {
            Sleep, 300
            AlignCamera()
            Sleep, 500
            if (UseTimeScale && difficulty != "Pizza Party" && difficulty != "Badlands II" && difficulty != "Polluted Wasteland II") {
                if (difficulty = "Hardcore" or difficulty = "Voidcore")
                {
                    TimescaleX := 726
                    TimescaleY := 1002
                } else {
                    TimescaleX := 658
                    TimescaleY := 1002
                }
                LogToConsole("Applying timescale: " TimeScaleMode)
                Click, %TimescaleX%, %TimescaleY%
                Sleep, 700

                pBitmap := Gdip_BitmapFromScreen("772|293|330|350")
                result := ocrFromBitmap(pBitmap)
                Gdip_DisposeImage(pBitmap)

                if InStr(result, "Get") || InStr(result, "more")|| InStr(result, "Get more") {
                    UseTimeScale := false
                    TimeScaleMultiplier := 1
                    TimeScaleMode := "OFF"
                    IniWrite, %TimeScaleMode%, %SettingsFile%, Options, TimeScaleMode

                    Click, 955, 686
                    LogToConsole("Failed to activate timescale! You are out of tickets.")
                    Sleep, 300
                } else {
                    if (TimeScaleMode = "2x") {
                        Click, 960, 631
                        Sleep, 300
                        Click, %TimescaleX%, %TimescaleY%
                        Sleep, 100
                        Click, %TimescaleX%, %TimescaleY%
                        Sleep, 300
                    } else if (TimeScaleMode = "1.5x") {
                        Click, 960, 631
                        Sleep, 200
                        Click, %TimescaleX%, %TimescaleY%
                        Sleep, 300
                    }
                }
            }
            PixelSearch, ClickX, ClickY, 691, 153, 1191, 260, 0x00EB2B, 3, Fast
            if (ErrorLevel = 0 && ClickX > 0)
            {
                Click, 1042, 201
                Click, %ClickX%, %ClickY%
                break
            }
        }
    }
}

AlignCamera() {
    global MoveEnabled, MoveDirection, MoveDuration, IsRestarting
    if (!IsRestarting) {
        LogToConsole("Aligning camera")
        closeChat()
        sleep, 200
        
        MouseMove, 1339, 236
        Sleep, 50
        Click, Right, Down
        MouseMove, 0, 1200, 2, R
        Sleep, 50
        Click, Right, Up
        Sleep, 200
        Send, {o down}
        Sleep, 500
        Send, {o up}
        sleep, 200
        Send, {o down}
        Sleep, 500
        Send, {o up}
        Sleep, 200
        if (MoveEnabled && !IsRestarting) {
            Send {%MoveDirection% down}
            Sleep, %MoveDuration%
            Send {%MoveDirection% up}
        }
    }
}

SpawnTower(X, Y, slotNumber, towerID) {
    global Towers, LastOpenedTowerID
    LogToConsole("Placing tower " towerID " (slot " slotNumber ") at x:" X " y:" Y "...")
    static Slots := ["800 1000", "890 1000", "980 1000", "1070 1000", "1160 1000"]
    currentSlot := Slots[slotNumber]

    TowerY := Y
    if (Y > A_ScreenHeight * 0.55) {
       TowerY := Y + 3
    }
    if (Y < A_ScreenHeight * 0.45) {
      TowerY := Y - 3
    }

    Loop {
        Click, %currentSlot%
        Sleep, 100
        MouseMove, %X%, %Y%
        Sleep, 100
        Click
        Sleep, 300
        Send, {q}

        placedSuccessfully := false
        Loop, 25 {
            ImageSearch, FoundX, FoundY, 1251, 501, 1369, 590, *80 Resources\TowerUI\Variant1.png
            If (ErrorLevel)
                ImageSearch, FoundX, FoundY, 663, 843, 933, 909, *50 Resources\TowerUI\Variant2.png
            If (ErrorLevel)
                ImageSearch, FoundX, FoundY, 661, 723, 712, 773, *50 Resources\TowerUI\Variant3.png

            if (!ErrorLevel) {
                placedSuccessfully := true
                break
            }

            If (ErrorLevel)
            {
                pBitmap := Gdip_BitmapFromScreen("700|600|400|200")
                result := ocrFromBitmap(pBitmap)
                Gdip_DisposeImage(pBitmap)

                if InStr(result, "Targets") || InStr(result, "targets") || InStr(result, "target") {
                    placedSuccessfully := True
                    break
                }
            }
            Sleep, 30
            
        }  

        if (placedSuccessfully) {
            Towers[towerID] := {x: X, y: TowerY, slot: slotNumber, level: 0, path: 0, pathLevel: 0}
            LogToConsole("Tower " towerID " placed successfully")
            LastOpenedTowerID := towerID
            break
        } else {
            LogToConsole("Tower " towerID " placement failed, retrying...")
        }
    }
    UpdateTowerIndicator(towerID)
}

SellTower(towerID) {
    global Towers, unfocusX, unfocusY
    
    if (!Towers[towerID]) {
        LogToConsole("ERROR: Tower " towerID " not found for selling!")
        return false
    }
    
    LogToConsole("Selling tower " towerID "...")
    
    targetX := Towers[towerID].x
    targetY := Towers[towerID].y
    
    Click, %targetX%, %targetY%
    Sleep, 400
    
    attempts := 0
    Loop {
        UseAbilities()
        Loop, 30 {
            PixelSearch, MenuX, MenuY, 1257, 513, 1340, 574, 0x7E5C27, 5, Fast
            if (!ErrorLevel)
                break
            Sleep, 20
        }

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
        
        Click, 796, 871
        LogToConsole("Tower " towerID " sold successfully")
    
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

UpgradeTower(towerID, skipOpen := false, totalUpgrades := 1, path := 0, pathLevel := 0) {
    global Towers, unfocusX, unfocusY, LastOpenedTowerID, Path1Region, Path2Region, DefaultUpgradeRegion, PotatoMode, Recording, RecordedSteps, Commander
    if (!Towers[towerID]) {
        LogToConsole("ERROR: Tower " towerID " not found!")
        return false
    }
    
    targetX := Towers[towerID].x, targetY := Towers[towerID].y
    
    if (!skipOpen && LastOpenedTowerID != towerID) {
        Click, %targetX%, %targetY%
    }
    
    LastOpenedTowerID := towerID
    upgradesDone := 0
    attempts := 0
    
    openedSuccessfully := false

    Loop {
        Loop, 3 {
            ImageSearch, FoundX, FoundY, 1251, 501, 1369, 590, *80 Resources\TowerUI\Variant1.png
            If (ErrorLevel)
                ImageSearch, FoundX, FoundY, 663, 843, 933, 909, *50 Resources\TowerUI\Variant2.png
            If (ErrorLevel)
                ImageSearch, FoundX, FoundY, 661, 723, 712, 773, *50 Resources\TowerUI\Variant3.png

            if (!ErrorLevel) {
                openedSuccessfully := true
            }
                
            If (ErrorLevel)
            {
                pBitmap := Gdip_BitmapFromScreen("700|600|400|200")
                result := ocrFromBitmap(pBitmap)
                Gdip_DisposeImage(pBitmap)

                if InStr(result, "Targets") || InStr(result, "targets") || InStr(result, "target") {
                    openedSuccessfully := True
                }
            }

            if (openedSuccessfully) {
                break
            }
            Sleep, 200
        }

        if (!openedSuccessfully) {
            attempts++
            if (attempts > 30) {
                LogToConsole("ERROR: Tower " towerID " menu not found, reloading...", true)
                SafeReload()
            } else {
                Random, VariationY, -8, 8
                shiftedY := targetY + VariationY
                Click, %targetX%, %shiftedY%
                Sleep, 100
            }
            continue
        }

        UpgradeX := 1100
        UpgradeY := 600

        nextLevel := Towers[towerID].level + 1
        if (path != 0 && nextLevel > pathLevel && pathLevel != 0) {
            if (path = 1) {
                region := Path1Region
                UpgradeY := 700
            } else if (path = 2) {
                region := Path2Region
                UpgradeY := 820
            } else {
                region := DefaultUpgradeRegion
            }
        } else {
            region := DefaultUpgradeRegion
        }

        searchW := region[3] - region[1]
        searchH := region[4] - region[2]
        searchArea := region[1] "|" region[2] "|" searchW "|" searchH

        pBitmapHaystack := Gdip_BitmapFromScreen(searchArea)
        pBitmapNeedle := Gdip_CreateBitmapFromFile("Resources\Upgrade.png")

        isGreenFound := Gdip_ImageSearch(pBitmapHaystack, pBitmapNeedle, FoundCoords, 0, 0, 0, 0, 15, 0x000000, 1, 1)

        Gdip_DisposeImage(pBitmapHaystack)
        Gdip_DisposeImage(pBitmapNeedle)

        if (isGreenFound > 0) {
            
                upgradeAttempts := 0
                Loop {
                    Click, %UpgradeX%, %UpgradeY%
                    If (PotatoMode = 1) {
                        Sleep, 300
                    } Else {
                        Sleep, 140
                    }
                    break
                }
            
            
            Towers[towerID].level += 1
            upgradesDone++
            LogToConsole("Tower " towerID " upgraded to level " Towers[towerID].level " (" upgradesDone "/" totalUpgrades ")")
            UpdateTowerIndicator(towerID)
            
            if (Towers[towerID].level >= 2 && RegExMatch(towerID, "i)^Commander\d*$") && !Commander) {
                Commander := true
                if (Recording && !HasStep("Commander := true"))
                    RecordedSteps.Push("Commander := true")
            }
            
            if (upgradesDone >= totalUpgrades) {
                return true
            }
            
            continue
        }
    }
}

;CheckCritical() {
    ;CheckDisconnected()
    ;ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *80 Resources\triumph.png
    ;if (ErrorLevel = 0) {
    ;    LogToConsole("Triumph detected! Reloading...")
    ;    RestartLock := false
    ;    SafeReload()
    ;}
    ;if (ErrorLevel = 1) {
    ;    ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *80 Resources\PlayAgain.png
    ;    if (ErrorLevel = 0) {
    ;        LogToConsole("Triumph detected! Reloading...")
    ;        RestartLock := false
    ;        SafeReload()
    ;    }
    ;}
    ;ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *80 Resources\YouLost.png
    ;if (ErrorLevel = 0) {
       ; LogToConsole("Game over detected! Reloading...")
      ;  RestartLock := false
     ;   SafeReload()
    ;}
    ;ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *50 Resources\GameOverUI.png
     ;   if (ErrorLevel = 0) {
   ;     LogToConsole("Game over detected! Reloading...")
    ;    RestartLock := false
  ;      SafeReload()
 ;   }
;}

UseAbilities() {
    global ChainKey, BeatKey, CaravanKey, TimeScaleMultiplier, UseTimeScale, AutoSkip, autoChain, autoCaravan, autoDropTheBeat, Commander, unfocusX, unfocusY, chainInterval, caravanInterval, LastOpenedTowerID
    Send, {q}

    ;if (AutoSkip = "OFF") {
     ;   ImageSearch, FoundX, FoundY, 975, 169, 1163, 273, *10 Resources\DontSkip.png
      ;  if (ErrorLevel = 0) {
       ;     TargetX := FoundX + 10
        ;    TargetY := FoundY + 20
         ;   MouseMove, %unfocusX%, %unfocusY%
          ;  Sleep, 50
           ; Click, %TargetX%, %TargetY%
            ;MouseMove, %unfocusX%, %unfocusY%
    ;        Sleep, 100
     ;       LastOpenedTowerID := ""
      ;      LogToConsole("Voted not to skip the wave (auto-skip OFF)")
       ; }
    ;}

    if (AutoSkip = "ON") {
        ImageSearch, FoundX, FoundY, 975, 169, 1163, 273, *10 Resources\Skip.png
        if (ErrorLevel = 0) {
            MouseGetPos, currentX, currentY

            Click, %FoundX%, %FoundY%
            Sleep, 100
            MouseMove, % currentX, % currentY, 0

            Sleep, 50
            LastOpenedTowerID := ""
            LogToConsole("Voted to skip the wave (auto-skip ON)")
        }
    }

    static LastChainTime := 0
    static LastDropTime := 0
    static LastCaravanTime := 0

    if (autoChain = "ON" && Commander && (A_TickCount - LastChainTime > chainInterval * 1000 / TimeScaleMultiplier)) {
        LastChainTime := A_TickCount
        Click, %unfocusX%, %unfocusY%
        Sleep, 300
        Send, {%ChainKey%}
        Sleep, 300
        LastOpenedTowerID := ""
        LogToConsole("Call of Arms ability activated")
    }

    if (autoCaravan = "ON" && Commander && (A_TickCount - LastCaravanTime > caravanInterval * 1000 / TimeScaleMultiplier)) {
        LastCaravanTime := A_TickCount
        Click, %unfocusX%, %unfocusY%
        Sleep, 300
        Send, {%CaravanKey%}
        Sleep, 300
        LastOpenedTowerID := ""
            LogToConsole("Support Caravan ability activated")
    }

    if (autoDropTheBeat = "ON" && Towers["DJ"].x != 0 && Towers["DJ"].level >= 3 && (A_TickCount - LastDropTime > 30000 / TimeScaleMultiplier)) {
        LastDropTime := A_TickCount
        Click, %unfocusX%, %unfocusY%
        Sleep, 300
        Send, {%BeatKey%}
        Sleep, 300
        LastOpenedTowerID := ""
        LogToConsole("Tried to activate Drop the Beat")
    }
}

SetDJTrack(track) {
    global Towers, unfocusX, unfocusY, LastOpenedTowerID
    if (Towers["DJ"]) {
        LogToConsole("Setting DJ track to " track "...")
        
        cleanTrack := RegExReplace(track, "i)""|'")
        
        trackName := Format("{:L}", cleanTrack)

        if (LastOpenedTowerID != "DJ") {
            targetX := Towers["DJ"].x, targetY := Towers["DJ"].y
            Click, %targetX%, %targetY%
            Sleep, 600
        }
        
        openedSuccessfully := false

        Loop {
            Loop, 3 {
                ImageSearch, FoundX, FoundY, 1251, 501, 1369, 590, *80 Resources\TowerUI\Variant1.png
                If (ErrorLevel)
                    ImageSearch, FoundX, FoundY, 663, 843, 933, 909, *50 Resources\TowerUI\Variant2.png
                If (ErrorLevel)
                    ImageSearch, FoundX, FoundY, 661, 723, 712, 773, *50 Resources\TowerUI\Variant3.png

                if (!ErrorLevel) {
                    openedSuccessfully := true
                }
                    
                If (ErrorLevel)
                {
                    pBitmap := Gdip_BitmapFromScreen("700|600|400|200")
                    result := ocrFromBitmap(pBitmap)
                    Gdip_DisposeImage(pBitmap)

                    if InStr(result, "Targets") || InStr(result, "targets") || InStr(result, "target") {
                        openedSuccessfully := True
                    }
                }

                if (openedSuccessfully) {
                    break
                }
                Sleep, 200 
            }

            if (!openedSuccessfully) {
                Random, VariationY, -10, 10
                targetX := Towers["DJ"].x, targetY := Towers["DJ"].y + VariationY
                Click, %targetX%, %targetY%
                Sleep, 400
                continue
            }
            
            if (openedSuccessfully) {
                trackFound := false
                djLevel := Towers["DJ"].level
                
                if (djLevel < 3) {
                    purpX := 1447, purpY := 596
                    greenX := 1524, greenY := 596
                    redX := 1585, redY := 597
                } else {
                    purpX := 1454, purpY := 718
                    greenX := 1520, greenY := 718
                    redX := 1590, redY := 716
                }
                
                Loop, 3 {
                    if (trackName = "red") {
                        if (djLevel >= 2) {
                            Sleep, 400
                            Click, %redX%, %redY%
                            Sleep, 100
                            Click, %unfocusX%, %unfocusY%
                            trackFound := true
                            LastOpenedTowerID := ""
                            LogToConsole("DJ track set to Red")
                            break
                        } else {
                            Sleep, 400
                            Click, %greenX%, %greenY%
                            Sleep, 100
                            Click, %unfocusX%, %unfocusY%
                            trackFound := true
                            LastOpenedTowerID := ""
                            LogToConsole("DJ track set to Green (Red not available yet)")
                            break
                        }
                    } 
                    else if (trackName = "green") {
                        Sleep, 400
                        Click, %greenX%, %greenY%
                        Sleep, 100
                        Click, %unfocusX%, %unfocusY%
                        trackFound := true
                        LastOpenedTowerID := ""
                        LogToConsole("DJ track set to Green")
                        break
                    } 
                    else if (trackName = "purple" || trackName = "purp") {
                        Sleep, 400
                        Click, %purpX%, %purpY%
                        Sleep, 100
                        Click, %unfocusX%, %unfocusY%
                        trackFound := true
                        LastOpenedTowerID := ""
                        LogToConsole("DJ track set to Purple")
                        break
                    }
                    else {
                        LogToConsole("ERROR: Unknown track name: " trackName)
                        Click, %unfocusX%, %unfocusY%
                        LastOpenedTowerID := ""
                        return false
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
    
    if (Towers[towerID].path != 0 && Towers[towerID].path != "") {
        MultiplePaths := true
    } else {
        MultiplePaths := false
    }

    if (Towers[towerID].hwnd) {
        oldHwnd := Towers[towerID].hwnd
        WinClose, ahk_id %oldHwnd%
        Gui, Tower%towerID%:Destroy
    }
    
    x := Towers[towerID].x - 12
    y := Towers[towerID].y - 12
    
    if (MultiplePaths) {
        Gui, Tower%towerID%:New, +ToolWindow +AlwaysOnTop -Caption +Disabled +Border +E0x20 +HwndTowerHwnd, Tower%towerID%
        Gui, Color, 1A1A1A, 2A2A2A 
        Gui, Font, s12 w600 cFFFFFF, Bahnschrift
    } else {
        Gui, Tower%towerID%:New, +ToolWindow +AlwaysOnTop -Caption +Disabled +E0x20 +HwndTowerHwnd, Tower%towerID%
        Gui, Color, FFFFFF
        Gui, Font, s10 c000000, Arial
    }
    
    Gui, Add, Text, x0 y0 w24 h24 Center 0x200, %level%
    
    WinSet, TransColor, FFFFFF 255, ahk_id %TowerHwnd%
    Gui, Show, x%x% y%y% w24 h24 NoActivate
    
    Towers[towerID].hwnd := TowerHwnd
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
        MsgResult := "OK"
        GoSub, MsgCloseAnim
    Return

    MsgYES:
        MsgResult := "YES"
        GoSub, MsgCloseAnim
    return

    MsgNO:
        MsgResult := "NO"
        GoSub, MsgCloseAnim
    return

    MsgCloseAnim:
        Gui, Msg:Destroy
    return
}

global OverlayPicHWND  

ShowDebugConsole() {
    global DebugConsole, OverlayHWND, OverlayBitmap, OverlayGraphics, OverlayPicHWND, OverlayX, OverlayY, OverlayWidth, OverlayHeight
    if (DebugConsole != 1)
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

    maxLines := Floor(OverlayHeight / (fontSize * 1.4))
    startIndex := Max(1, LogLines.MaxIndex() - maxLines + 1)
    yPos := 5
    maxWidth := OverlayWidth - 20

    wrappedLines := []
    Loop, % maxLines {
        index := startIndex + A_Index - 1
        if (index > LogLines.MaxIndex())
            break
        line := LogLines[index]
        
        tempLines := []
        while (StrLen(line) > 0) {
            if (StrLen(line) * fontSize * 0.6 <= maxWidth) {
                tempLines.Push(line)
                break
            }
            cutPos := Floor(maxWidth / (fontSize * 0.6))
            tempLines.Push(SubStr(line, 1, cutPos))
            line := SubStr(line, cutPos + 1)
        }
        
        for i, wrappedLine in tempLines {
            wrappedLines.Push(wrappedLine)
        }
    }

    while (wrappedLines.MaxIndex() > maxLines)
        wrappedLines.RemoveAt(1)

    for i, line in wrappedLines {
        Gdip_FillRectangle(OverlayGraphics, pBrushBg, 5, yPos, OverlayWidth-10, fontSize * 1.4)
        CreateRectF(RC, 5, yPos, OverlayWidth-5, fontSize * 1.4)
        Gdip_DrawString(OverlayGraphics, line, hFont, hFormat, pBrushText, RC)
        yPos += fontSize * 1.4
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

LogToConsole(text, SendWebhookInstantly := false) {
    global DebugConsole, LogLines, OverlayHWND, WebhookEnabled, WebhookLink
    if (DebugConsole != 1 && !WebhookEnabled)
        return

    FormatTime, time,, HH:mm:ss
    formattedText := "[" . time . "] " . text
    
    LogLines.Push(formattedText)

    while (LogLines.MaxIndex() > 500)
        LogLines.RemoveAt(1)

    if (OverlayHWND && WinExist("ahk_id " OverlayHWND))
        UpdateOverlay()
    
    if (WebhookEnabled && WebhookLink != "" && RunningStrategy) {
        if (AutorunStartTime > 0) {
            runtime := FormatRuntime(AutorunStartTime)
            webhookText := "[" . runtime . "] " . text
        } else {
            webhookText := "[00:00] " . text
        }
        if (!SendWebhookInstantly) {
            SendToWebhook(webhookText)
        } else if (SendWebhookInstantly) {
            SendToWebhookInstant(webhookText)
        }
    }
}

FormatRuntime(StartTicks) {
    if (StartTicks = 0)
        return "00:00"
    
    elapsedMs := A_TickCount - StartTicks
    elapsedSeconds := Floor(elapsedMs / 1000)
    
    hours := Floor(elapsedSeconds / 3600)
    minutes := Floor(Mod(elapsedSeconds, 3600) / 60)
    seconds := Mod(elapsedSeconds, 60)
    
    if (hours > 0)
        return Format("{:d}:{:02d}:{:02d}", hours, minutes, seconds)
    else
        return Format("{:d}:{:02d}", minutes, seconds)
}

SendStatsToWebhook() {
    global WebhookLink, StateFile, AutorunStartTime

    gemFound := false
    coinFound := false
    StartTime := A_TickCount
    
    loop
    {
        ImageSearch, GemX, GemY, 0, 0, A_ScreenWidth, A_ScreenHeight, *30 Resources\gem.png
        if (ErrorLevel = 0) {
            gemFound := true
        }

        ImageSearch, CoinX, CoinY, 0, 0, A_ScreenWidth, A_ScreenHeight, *30 Resources\coin.png
        if (ErrorLevel = 0) {
            coinFound := true
        }

        if (coinFound && gemFound) {
            break
        }
        
        if (A_TickCount - StartTime > 15000) {
            Return
        }
        
        Sleep, 500
    }
    
    if (coinFound && gemFound)
    {
        Sleep, 500
        
        ; GEM CROP 
        AreaW := 200
        AreaH := 80
        CalcY := GemY - 30
        SearchArea := "66|" . CalcY . "|" . AreaW . "|" . AreaH
        pBitmapGem := Gdip_BitmapFromScreen(SearchArea)
        
        pBitmapGemResized := Gdip_CreateBitmap(AreaW * 3, AreaH * 3)
        G1 := Gdip_GraphicsFromImage(pBitmapGemResized)
        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", G1, "Int", 5)
        Gdip_DrawImage(G1, pBitmapGem, 0, 0, AreaW * 3, AreaH * 3, 0, 0, AreaW, AreaH)

        Gdip_LockBits(pBitmapGemResized, 0, 0, AreaW * 3, AreaH * 3, Stride1, Scan01, BitmapData1)
        Loop, % AreaH * 3 {
            Y := A_Index - 1
            Loop, % AreaW * 3 {
                X := A_Index - 1
                
                if (Y < 65) {
                    Gdip_SetLockBitPixel(0xFFFFFFFF, Scan01, X, Y, Stride1)
                    continue
                }
                
                RGB := Gdip_GetLockBitPixel(Scan01, X, Y, Stride1)
                R := (RGB & 0x00FF0000) >> 16
                G := (RGB & 0x0000FF00) >> 8
                B := RGB & 0x000000FF
                
                if (R < 95 && G < 75 && B < 45) {
                    Gdip_SetLockBitPixel(0xFF000000, Scan01, X, Y, Stride1) 
                } else {
                    Gdip_SetLockBitPixel(0xFFFFFFFF, Scan01, X, Y, Stride1) 
                }
            }
        }
        Gdip_UnlockBits(pBitmapGemResized, BitmapData1)

        GEMresult := ocrFromBitmap(pBitmapGemResized)
        
        Gdip_DeleteGraphics(G1)
        Gdip_DisposeImage(pBitmapGem)


        ; COIN CROP
        AreaW := 200
        AreaH := 75
        CalcY := CoinY - 30
        SearchArea := "66|" . CalcY . "|" . AreaW . "|" . AreaH
        pBitmapCoin := Gdip_BitmapFromScreen(SearchArea)
        
        pBitmapCoinResized := Gdip_CreateBitmap(AreaW * 3, AreaH * 3)
        G2 := Gdip_GraphicsFromImage(pBitmapCoinResized)
        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", G2, "Int", 5)
        Gdip_DrawImage(G2, pBitmapCoin, 0, 0, AreaW * 3, AreaH * 3, 0, 0, AreaW, AreaH)

        Gdip_LockBits(pBitmapCoinResized, 0, 0, AreaW * 3, AreaH * 3, Stride2, Scan02, BitmapData2)
        Loop, % AreaH * 3 {
            Y := A_Index - 1
            Loop, % AreaW * 3 {
                X := A_Index - 1
                
                if (Y < 65) {
                    Gdip_SetLockBitPixel(0xFFFFFFFF, Scan02, X, Y, Stride2)
                    continue
                }
                
                RGB := Gdip_GetLockBitPixel(Scan02, X, Y, Stride2)
                R := (RGB & 0x00FF0000) >> 16
                G := (RGB & 0x0000FF00) >> 8
                B := RGB & 0x000000FF
                
                if (R < 95 && G < 75 && B < 45) {
                    Gdip_SetLockBitPixel(0xFF000000, Scan02, X, Y, Stride2) 
                } else {
                    Gdip_SetLockBitPixel(0xFFFFFFFF, Scan02, X, Y, Stride2) 
                }
            }
        }
        Gdip_UnlockBits(pBitmapCoinResized, BitmapData2)

        COINresult := ocrFromBitmap(pBitmapCoinResized)
        
        Gdip_DeleteGraphics(G2)
        Gdip_DisposeImage(pBitmapCoin)


        coinVal := ""
        gemVal := ""
        
        cleanGemText := StrReplace(GEMresult, ",", "")
        cleanGemText := StrReplace(cleanGemText, "`n", " ")
        cleanGemText := StrReplace(cleanGemText, "`r", " ")
        
        cleanCoinText := StrReplace(COINresult, ",", "")
        cleanCoinText := StrReplace(cleanCoinText, "`n", " ")
        cleanCoinText := StrReplace(cleanCoinText, "`r", " ")
        
        Pos := 1
        while (Pos := RegExMatch(cleanGemText, "\d", match, Pos))
        {
            gemVal .= match
            Pos += 1
        }
        
        Pos := 1
        while (Pos := RegExMatch(cleanCoinText, "\d", match, Pos))
        {
            coinVal .= match
            Pos += 1
        }

        if (coinVal = "")
            coinVal := "0"
        if (gemVal = "")
            gemVal := "0"

        IniRead, checkStartCoins, %StateFile%, State, StartCoins, 0
        if (checkStartCoins = 0) {
            IniWrite, %coinVal%, %StateFile%, State, StartCoins
            IniWrite, %gemVal%, %StateFile%, State, StartGems
        }
        
        IniWrite, %coinVal%, %StateFile%, State, Coins
        IniWrite, %gemVal%, %StateFile%, State, Gems
        
        IniRead, startCoins, %StateFile%, State, StartCoins, 0
        IniRead, startGems, %StateFile%, State, StartGems, 0
        earnedCoins := coinVal - startCoins
        earnedGems := gemVal - startGems
        
        if (AutorunStartTime > 0) {
            elapsedMs := A_TickCount - AutorunStartTime
            elapsedHours := elapsedMs / 3600000
            
            if (elapsedHours > 0.001) {
                coinsPerHour := Round(earnedCoins / elapsedHours)
                gemsPerHour := Round(earnedGems / elapsedHours)
            } else {
                coinsPerHour := 0
                gemsPerHour := 0
            }
        } else {
            coinsPerHour := 0
            gemsPerHour := 0
        }
        
        IniRead, totalTriumphs, %StateFile%, State, TotalTriumphs, 0
        IniRead, totalLosses, %StateFile%, State, TotalLosses, 0
        IniRead, totalUnidentified, %StateFile%, State, TotalUnidentified, 0

        totalMatches := totalTriumphs + totalLosses + totalUnidentified

        description := "Coins: " . coinVal . " (+" . earnedCoins . ")`n"
        description .= "Gems: " . gemVal . " (+" . earnedGems . ")`n"
        description .= "Matches played: " . totalMatches . "`n"
        description .= "Triumphs: " . totalTriumphs . " | Losses: " . totalLosses . " | Unidentified: " . totalUnidentified . "`n"
        description .= "`n"
        description .= "📊 " . coinsPerHour . " Coins/hr | " . gemsPerHour . " Gems/hr"
        
        description := StrReplace(description, "\", "\\")
        description := StrReplace(description, """", "\""")
        description := StrReplace(description, "`n", "\n")

        payload_json := "{""embeds"": ["
        payload_json .= "{""title"": ""Currencies"", ""description"": """ . description . """, ""color"": 5814783, ""image"": {""url"": ""attachment://coin_crop.png""}},"
        payload_json .= "{""color"": 5814783, ""image"": {""url"": ""attachment://gem_crop.png""}}"
        payload_json .= "]}"

        fields := Object()
        fields[1] := Object("name", "payload_json", "content-type", "application/json", "content", payload_json)
        fields[2] := Object("name", "files[0]", "filename", "gem_crop.png", "content-type", "image/png", "pBitmap", pBitmapGemResized)
        fields[3] := Object("name", "files[1]", "filename", "coin_crop.png", "content-type", "image/png", "pBitmap", pBitmapCoinResized)
        
        CreateFormData(postdata, contentType, fields)
        
        try {
            whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
            whr.Open("POST", WebhookLink . "?wait=true", false)
            whr.SetRequestHeader("Content-Type", contentType)
            whr.Send(postdata)
        } catch e {
        }
        
        Gdip_DisposeImage(pBitmapGemResized)
        Gdip_DisposeImage(pBitmapCoinResized)
    }
}


FlushWebhookQueue() {
    global WebhookQueue, WebhookTimerActive, WebhookLink
    
    if (WebhookQueue.MaxIndex() = 0)
        return
    
    WebhookTimerActive := false
    SetTimer, ProcessWebhookQueue, Off
    
    allMessages := ""
    messageCount := 0
    
    while (WebhookQueue.MaxIndex() > 0) {
        message := WebhookQueue.RemoveAt(1)
        
        if (message = "" || Trim(message) = "")
            continue
        
        messageCount++
        
        escapedMessage := StrReplace(message, "\", "\\")
        escapedMessage := StrReplace(escapedMessage, """", "\""")
        escapedMessage := StrReplace(escapedMessage, "`n", "\n")
        escapedMessage := StrReplace(escapedMessage, "`r", "")
        escapedMessage := Trim(escapedMessage)
        
        if (escapedMessage = "")
            continue
        
        allMessages .= escapedMessage "\n"
    }
    
    if (messageCount = 0 || allMessages = "")
        return
    
    allMessages := RTrim(allMessages, "\n")
    
    jsonPayload := "{"
    jsonPayload .= """content"": ""``````" allMessages "``````"""
    jsonPayload .= "}"
    
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", WebhookLink, false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send(jsonPayload)
    } catch e {
    }
}

SendToWebhook(message) {
    global WebhookQueue, WebhookTimerActive, WebhookLink

    if (message = "" || Trim(message) = "")
        return
    
    WebhookQueue.Push(message)
    
    if (!WebhookTimerActive) {
        WebhookTimerActive := true
        SetTimer, ProcessWebhookQueue, -100
    }
}

SendToWebhookInstant(message) {
    global WebhookInstantQueue, WebhookInstantTimerActive, WebhookLink, WebhookEnabled

    if (!WebhookEnabled)
    {
        Return
    }

    if (message = "" || Trim(message) = "")
        return
    
    FlushWebhookQueue()

    if !IsObject(WebhookInstantQueue)
        WebhookInstantQueue := []
    
    WebhookInstantQueue.Push(message)
    
    if (!WebhookInstantTimerActive) {
        WebhookInstantTimerActive := true
        SetTimer, ProcessWebhookInstantQueue, -100 
    }
}

ProcessWebhookInstantQueue:
    global WebhookLink, WebhookInstantQueue, WebhookInstantTimerActive, map, difficulty, TimeScaleMode, requiredTowers, modifiers, ver
    
    if (!IsObject(WebhookInstantQueue) || WebhookInstantQueue.MaxIndex() = 0) {
        WebhookInstantTimerActive := false
        return
    }
    
    allMessages := ""
    Loop, % WebhookInstantQueue.MaxIndex() {
        message := WebhookInstantQueue.RemoveAt(1)
        if (message = "" || Trim(message) = "")
            continue
        
        if (allMessages != "")
            allMessages .= "`n"
        
        allMessages .= message
    }
    
    WebhookInstantTimerActive := false
    
    if (allMessages = "")
        return
    
    allMessagesLower := Format("{:L}", allMessages)
    
    embedColor := 3447003  ; blue

    if (InStr(allMessagesLower, "error") || InStr(allMessagesLower, "failed") || InStr(allMessagesLower, "reloading"))
        embedColor := 15158332 ; red
    else if (InStr(allMessagesLower, "success") || InStr(allMessagesLower, "completed") || InStr(allMessagesLower, "stopped") || InStr(allMessagesLower, "started"))
        embedColor := 3066993 ; green
    else if (InStr(allMessagesLower, "warning"))
        embedColor := 16776960 ;yellow
    

    escapedMessages := StrReplace(allMessages, "\", "\\")
    escapedMessages := StrReplace(escapedMessages, """", "\""")
    escapedMessages := StrReplace(escapedMessages, "`n", "\n")
       
    jsonPayload := "{"
    jsonPayload .= """embeds"": [{"
    jsonPayload .= """description"": """ . escapedMessages . ""","
    jsonPayload .= """color"": " . embedColor
    jsonPayload .= "}]}"
    
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", WebhookLink, true)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send(jsonPayload)
    } catch e {
    }
return

ProcessWebhookQueue:
    global WebhookQueue, WebhookTimerActive, WebhookLink, ver
    
    if (WebhookQueue.MaxIndex() = 0) {
        WebhookTimerActive := false
        return
    }
    
    maxMessages := 20

    if (WebhookQueue.MaxIndex() < maxMessages) {
        SetTimer, ProcessWebhookQueue, -2000
        return
    }
    
    allMessages := ""
    messageCount := 0
    
    Loop, % maxMessages {
        if (WebhookQueue.MaxIndex() = 0)
            break
        
        message := WebhookQueue.RemoveAt(1)
        
        if (message = "" || Trim(message) = "")
            continue
        
        messageCount++
        
        escapedMessage := StrReplace(message, "\", "\\")
        escapedMessage := StrReplace(escapedMessage, """", "\""")
        escapedMessage := StrReplace(escapedMessage, "`n", "\n")
        escapedMessage := StrReplace(escapedMessage, "`r", "")
        escapedMessage := Trim(escapedMessage)
        
        if (escapedMessage = "")
            continue
        
        allMessages .= escapedMessage "\n"
    }
    
    if (messageCount = 0 || allMessages = "") {
        if (WebhookQueue.MaxIndex() > 0) {
            SetTimer, ProcessWebhookQueue, -1000
        } else {
            WebhookTimerActive := false
        }
        return
    }
    
    allMessages := RTrim(allMessages, "\n")
    
    jsonPayload := "{"
    jsonPayload .= """content"": ""``````" allMessages "``````"""
    jsonPayload .= "}"
    
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", WebhookLink, true)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send(jsonPayload)
    } catch e {
    }
    
    if (WebhookQueue.MaxIndex() > 0) {
        SetTimer, ProcessWebhookQueue, -1000
    } else {
        WebhookTimerActive := false
    }
return

SafeReload() {
    global RestartLock, StateFile, RunningStrategy, CheckerPID
    if (RestartLock) {
        Return
    }
    RestartLock := true
    
    KillSubmacros() 
    
    Gui, Overlay:Destroy
    Gui, Main:Destroy
    Gui, Settings:Destroy
    Gui, StrategySettings:Destroy
    Gui, Progress:Destroy
    
    DeleteAllIndicators()
    
    if (RunningStrategy) {
        IniRead, currentStrat, %StateFile%, State, Strategy, %A_Space%
        if (currentStrat != "") {
            IniWrite, 1, %StateFile%, State, Running
        }
    }
    
    Run, "%A_ScriptFullPath%"
    
    Sleep, 2000
    
    ExitApp
}

GuiClose:
CleanupAndExit:
    KillSubmacros()
    DeleteAllIndicators()
    Gui, Overlay:Destroy
    Gui, Main:Destroy
    Gui, Settings:Destroy
    Gui, StrategySettings:Destroy
    Gui, Progress:Destroy
    
    DetectHiddenWindows, On
    WinGet, allWindows, List, ahk_class AutoHotkey
    currentPID := DllCall("GetCurrentProcessId")
    Loop, %allWindows% {
        WinGet, winPID, PID, % "ahk_id " allWindows%A_Index%
        if (winPID != currentPID) {
            WinClose, % "ahk_id " allWindows%A_Index%
        }
    }
    
    IniWrite, 0, %StateFile%, State, Running
ExitApp

KillSubmacros() {
    global CheckerPID, DiscordPID
    
    if (CheckerPID != "") {
        RunWait, %ComSpec% /c taskkill /PID %CheckerPID% /F /T, , Hide
        CheckerPID := ""
    }
    
    if (DiscordPID != "") {
        RunWait, %ComSpec% /c taskkill /PID %DiscordPID% /F /T, , Hide
        DiscordPID := ""
    }
    
    for process in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_Process WHERE Name = 'AutoHotkey.exe' OR Name = 'AutoHotkeyU64.exe' OR Name = 'AutoHotkeyU32.exe'") {
        cmd := process.CommandLine
        if (InStr(cmd, "checker.ahk") || InStr(cmd, "discord.ahk")) {
            Process, Close, % process.ProcessId
        }
    }
}

GetCurrentTowerID() {
    global Towers
    for id, t in Towers {
        if (t.hwnd = GuiHwnd)
            return id
    }
    return ""
}

ShowTowerPathDialog(towerID) {
    global Towers
    
    if (!Towers[towerID].path || Towers[towerID].path = 0 || Towers[towerID].path = "") {

        Gui, PathSelect:New, +AlwaysOnTop -Caption +Border +OwnerMain, Path Selection
        Gui, Color, 1A1A1A, 2A2A2A 
        Gui, Add, Progress, x0 y0 w390 h2 Background3A86FF, 0
        
        Gui, Font, s12 w600 cFFFFFF, Bahnschrift
        Gui, Add, Text, x25 y20 w350, Tower %towerID%
        
        Gui, Font, s11 w400 cFFFFFF, Segoe UI
        Gui, Add, Text, x25 y+10 w350, Choose an upgrade path
        
        global ActivePathSelectTowerID := towerID
        
        Gui, Font, s10 w600 cFFFFFF, Segoe UI
        
        Gui, Add, Button, x25 y+25 w165 h40 gSelectPath1 Section, Path 1 (Top)
        Gui, Add, Button, x+10 ys w165 h40 gSelectPath2, Path 2 (Bottom)
        
        Gui, Add, Button, x25 y+10 w340 h35 gCancelPathSelect, Cancel
        
        Gui, Add, Text, x25 y+15 w350 h1 +Hidden, .
        
        Gui, Show, w390 h200
        WinWaitClose, PathSelect
    }
}

SelectPath1:
    Gui, PathSelect:Destroy
    towerID := ActivePathSelectTowerID
    if (towerID != "") {
        InputBox, pathLevel, Level, Enter the level where the paths appears,,,,,,,,
        if !ErrorLevel && pathLevel is integer {
            Towers[towerID].path := 1
            Towers[towerID].pathLevel := pathLevel
            UpdateTowerIndicator(towerID)
            LogToConsole("Tower " towerID " set to path 1 from level " pathLevel)
        }
    }
return

SelectPath2:
    Gui, PathSelect:Destroy
    towerID := ActivePathSelectTowerID
    if (towerID != "") {
        InputBox, pathLevel, Level, Enter the level where the paths appears:,,,,,,,,
        if !ErrorLevel && pathLevel is integer {
            Towers[towerID].path := 2
            Towers[towerID].pathLevel := pathLevel
            UpdateTowerIndicator(towerID)
            LogToConsole("Tower " towerID " set to path 2 from level " pathLevel)
        }
    }
return

CancelPathSelect:
    Gui, PathSelect:Destroy
return

ErrorCheckContinue:
    Gui, ErrorCheck:Submit, NoHide
    if (DontShowAgain = 1) {
        IniWrite, 1, %SettingsFile%, Settings, SkipDisplayWarnings
    }
    Gui, ErrorCheck:Destroy
return

ErrorCheckClose:
    Gui, ErrorCheck:Submit, NoHide
    if (DontShowAgain = 1) {
        IniWrite, 1, %SettingsFile%, Settings, SkipDisplayWarnings
    }
    Gui, ErrorCheck:Destroy
return

CreateFormData(ByRef retData, ByRef contentType, fields)
{
    static chars := "0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z"
    Random,, % A_TickCount
    Sort, chars, D|
    Random, randChars
    boundary := SubStr(StrReplace(chars, "|"), 1, 12)
    
    hData := DllCall("GlobalAlloc", "UInt", 0x2, "UPtr", 0, "Ptr")
    DllCall("ole32\CreateStreamOnHGlobal", "Ptr", hData, "Int", 0, "PtrP", pStream, "UInt")
    
    for index, field in fields
    {
        str := "`r`n------------------------------" . boundary . "`r`n"
        str .= "Content-Disposition: form-data; name=""" . field["name"] . """"
        
        if (field.HasKey("filename"))
            str .= "; filename=""" . field["filename"] . """"
        
        str .= "`r`n"
        str .= "Content-Type: " . field["content-type"] . "`r`n`r`n"
        
        if (field.HasKey("content"))
            str .= field["content"] . "`r`n"
        
        VarSetCapacity(utf8, length := StrPut(str, "UTF-8") - 1)
        StrPut(str, &utf8, length, "UTF-8")
        DllCall("shlwapi\IStream_Write", "Ptr", pStream, "Ptr", &utf8, "UInt", length, "UInt")
        
        if (field.HasKey("pBitmap"))
        {
            try
            {
                pFileStream := Gdip_SaveBitmapToStream(field["pBitmap"])
                DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", size, "UInt")
                DllCall("shlwapi\IStream_Reset", "Ptr", pFileStream, "UInt")
                DllCall("shlwapi\IStream_Copy", "Ptr", pFileStream, "Ptr", pStream, "UInt", size, "UInt")
                ObjRelease(pFileStream)
            }
        }
    }
    
    str := "`r`n------------------------------" . boundary . "--`r`n"
    VarSetCapacity(utf8, length := StrPut(str, "UTF-8") - 1)
    StrPut(str, &utf8, length, "UTF-8")
    DllCall("shlwapi\IStream_Write", "Ptr", pStream, "Ptr", &utf8, "UInt", length, "UInt")
    
    ObjRelease(pStream)
    
    pData := DllCall("GlobalLock", "Ptr", hData, "Ptr")
    size := DllCall("GlobalSize", "Ptr", pData, "UPtr")
    
    retData := ComObjArray(0x11, size)
    pvData := NumGet(ComObjValue(retData), 8 + A_PtrSize, "Ptr")
    DllCall("RtlMoveMemory", "Ptr", pvData, "Ptr", pData, "Ptr", size)
    
    DllCall("GlobalUnlock", "Ptr", hData)
    DllCall("GlobalFree", "Ptr", hData, "Ptr")
    
    contentType := "multipart/form-data; boundary=----------------------------" . boundary
}

Gdip_SaveBitmapToStream(pBitmap)
{
    DllCall("ole32\CreateStreamOnHGlobal", "Ptr", 0, "Int", 1, "PtrP", pStream)
    
    VarSetCapacity(CLSID, 16)
    DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", &CLSID)
    DllCall("gdiplus\GdipSaveImageToStream", "Ptr", pBitmap, "Ptr", pStream, "Ptr", &CLSID, "Ptr", 0)
    DllCall("shlwapi\IStream_Reset", "Ptr", pStream, "UInt")
    
    return pStream
}

closeChat() {
    getRobloxPos(pX, pY, width, height)
    
    PixelGetColor, chatCheck, % pX + 140, % pY + 35, RGB

    if (compareColors(chatCheck, 0xF4F5F8) < 25) {
        MouseGetPos, currentX, currentY
        
        MouseMove, % pX + 140, % pY + 40, 2
        Sleep, 100

        MouseClick
        Sleep, 100
        
        MouseMove, % currentX, % currentY, 0

        LogToConsole("Closed chat")
    }
}

; used from natro
GetRobloxHWND()
{
	if (hwnd := WinExist("Roblox ahk_exe RobloxPlayerBeta.exe"))
		return hwnd
	else if (WinExist("Roblox ahk_exe ApplicationFrameHost.exe"))
	{
		ControlGet, hwnd, Hwnd, , ApplicationFrameInputSinkWindow1
		return hwnd
	}
	else
		return 0
}

;used from dolphsol's macro XD
getRobloxPos(ByRef x := "", ByRef y := "", ByRef width := "", ByRef height := "", hwnd := ""){
    if !hwnd
        hwnd := GetRobloxHWND()
    VarSetCapacity( buf, 16, 0 )
    DllCall( "GetClientRect" , "UPtr", hwnd, "ptr", &buf)
    DllCall( "ClientToScreen" , "UPtr", hwnd, "ptr", &buf)

    x := NumGet(&buf,0,"Int")
    y := NumGet(&buf,4,"Int")
    width := NumGet(&buf,8,"Int")
    height := NumGet(&buf,12,"Int")
}

compareColors(color1, color2) 
{
    r1 := (color1 >> 16) & 0xFF
    g1 := (color1 >> 8) & 0xFF
    b1 := color1 & 0xFF

    r2 := (color2 >> 16) & 0xFF
    g2 := (color2 >> 8) & 0xFF
    b2 := color2 & 0xFF

    return Sqrt((r1 - r2)**2 + (g1 - g2)**2 + (b1 - b2)**2)
}


CleanupGdip:
    Gdip_Shutdown(pToken)
ExitApp