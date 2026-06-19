#NoEnv
#SingleInstance, force
#NoTrayIcon

if 0 < 1
{
    MsgBox,,, You are not supposed to run it manually!
    ExitApp
}

MainPID := %1%
SetWorkingDir %A_ScriptDir%\..\

ResourcesDir := A_WorkingDir "\Resources"
DisconnectedImg := ResourcesDir "\Disconnected.png"
DisconnectedImg2 := ResourcesDir "\disconnected2.png"
TriumphImg1 := ResourcesDir "\triumph.png"
TriumphImg2 := ResourcesDir "\PlayAgain.png"
YouLostImg := ResourcesDir "\YouLost.png"
GameOverUI := ResourcesDir "\GameOverUI.png"

SetBatchLines, -1

Opt := A_AppData "\Ultimate_Macro\Macros\TDSMacro\Options"
SettingsFile := Opt "\Settings.tds"

Sleep, 15000
WinWait, ahk_exe RobloxPlayerBeta.exe, , 55
Loop {
    Process, Exist, %MainPID%
    if !ErrorLevel {
        ExitApp
    }

    if !WinExist("ahk_exe RobloxPlayerBeta.exe") {
        RestartMain()
        return
    }

    if WinExist("Roblox Crash") {
        RestartMain()
        return
    }

    if (A_Index & 1) {
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *15 %DisconnectedImg%
        if (ErrorLevel = 0) {
            RestartMain()
            return
        }
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *15 %DisconnectedImg2%
        if (ErrorLevel = 0) {
            RestartMain()
            return
        }

        ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *80 %TriumphImg1%
        if (ErrorLevel = 0) {
            RestartMain()
            return
        }
        ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *80 %TriumphImg2%
        if (ErrorLevel = 0) {
            RestartMain()
            return
        }

        ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *80 %YouLostImg%
        if (ErrorLevel = 0) {
            RestartMain()
            return
        }
        ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *50 %GameOverUI%
        if (ErrorLevel = 0) {
            RestartMain()
            return
        }
    }

    Sleep, 200
}
return

RestartMain() {
    global MainPID, SettingsFile
    Process, Close, %MainPID%

    IniRead, WebhookLink, %SettingsFile%, Webhook, Link, %A_Space%
    IniRead, tempWebhook, %SettingsFile%, Webhook, Enabled, OFF
    WebhookEnabled := (tempWebhook = "1") ? true : false

    if (!WebhookEnabled || WebhookLink = "")
    {
        Sleep, 2000
    } else {
        Sleep, 8000
    }

    Run, "%A_WorkingDir%\Main.ahk"
    ExitApp
}