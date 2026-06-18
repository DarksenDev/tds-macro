#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance, force

VERSION_URL := "https://raw.githubusercontent.com/DarksenDev/tds-macro/refs/heads/main/information.ini"
SCRIPT_DIR := A_ScriptDir 
TEMP_DIR := A_Temp "\TDSMacroUpdate"

if (A_LineFile = A_ScriptFullPath) {
    ExitApp
}

CheckForUpdate(currentVer) {
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "https://api.github.com/repos/DarksenDev/tds-macro/releases/latest", false)
        whr.Send()
        
        if (whr.Status = 200) {
            json := whr.ResponseText
            
            ; Extract version
            RegExMatch(json, """tag_name"":""([^""]+)""", tag)
            latestVer := tag1
            
            ; Extract download URL
            RegExMatch(json, """browser_download_url"":""([^""]+)""", download)
            downloadURL := download1
            
            RegExMatch(json, """body"":""([^""]+)""", body)
            releaseBody := body1
            
            releaseBody := StrReplace(releaseBody, "\r\n", "`n")
            releaseBody := StrReplace(releaseBody, "\n", "`n")
            releaseBody := StrReplace(releaseBody, "\r", "")
            releaseBody := StrReplace(releaseBody, "\""", """")
            releaseBody := StrReplace(releaseBody, "\\", "\")
            
            ; Remove markdown formatting or other special chars
            releaseBody := RegExReplace(releaseBody, "\\/", "/")
            
            if (latestVer != currentVer && downloadURL != "") {
                updateMsg := "New version " latestVer " is available!`n"
                updateMsg .= "Current version: " currentVer "`n`n"
                
                if (releaseBody != "") {
                    updateMsg .= "Changelog:`n"
                    updateMsg .= "--------------------------------`n"
                    if (StrLen(releaseBody) > 500) {
                        releaseBody := SubStr(releaseBody, 1, 500) . "...`n(Full changelog on GitHub)"
                    }
                    updateMsg .= releaseBody . "`n"
                    updateMsg .= "--------------------------------`n`n"
                }
                
                updateMsg .= "Do you want to update now?"
                
                MsgBox, 4, Update Available, %updateMsg%
                
                IfMsgBox Yes
                {
                    ; %1 - URL
                    ; %2 - Current macro folder
                    ; %3 - delete old version (1=yes)
                    
                    updateBat := A_ScriptDir "\submacros\update.bat"
                    
                    if FileExist(updateBat) {
                        RunWait, %updateBat% "%downloadURL%" "%A_ScriptDir%" 1
                        return 2  ; success
                    } else {
                        MsgBox, 16, Error, update.bat not found!
                        return 0
                    }
                }
            }
        }
    } catch e {
    }
    
    return 0
}
