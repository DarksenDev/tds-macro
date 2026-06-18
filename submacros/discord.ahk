#NoEnv
#SingleInstance, force
#NoTrayIcon

if 0 < 1
{
    MsgBox,,, You are not supposed to run it manually!
    ExitApp
}

MainPID := %1%
SetWorkingDir, %A_ScriptDir%\..\AppData
Opt := A_AppData "\Ultimate_Macro\Macros\TDSMacro\Options"
SettingsFile := Opt "\Settings.tds"

IniRead, WebhookLink, %SettingsFile%, Webhook, Link, %A_Space%
IniRead, tempWebhook, %SettingsFile%, Webhook, Enabled, OFF
WebhookEnabled := (tempWebhook = "ON" || tempWebhook = "1") ? true : false

if (!WebhookEnabled || WebhookLink = "")
{
    ExitApp
}

#Include %A_ScriptDir%\..\lib\Gdip_All.ahk

pToken := Gdip_Startup()
SetBatchLines, -1

Random, screenshotDelay, 120000, 240000
SetTimer, TakeRandomScreenshot, %screenshotDelay%

ResourcesDir := A_WorkingDir "\Resources"
DisconnectedImg := ResourcesDir "\Disconnected.png"
DisconnectedImg2 := ResourcesDir "\disconnected2.png"
TriumphImg1 := ResourcesDir "\triumph.png"
TriumphImg2 := ResourcesDir "\PlayAgain.png"
YouLostImg := ResourcesDir "\YouLost.png"
GameOverUI := ResourcesDir "\GameOverUI.png"

Sleep, 7000
WinWait, ahk_exe RobloxPlayerBeta.exe, , 60
Loop
{
    Process, Exist, %MainPID%
    if !ErrorLevel
    {
        Gdip_Shutdown(pToken)
        ExitApp
    }

        if WinExist("Roblox Crash")
        {
            SendScreenshot("Roblox has crashed", "RobloxCrash")
            Sleep, 10000
        }
        
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *15 %DisconnectedImg%
        if (ErrorLevel = 0)
        {
            SendScreenshot("Disconnected from the game", "Disconnected")
            Sleep, 10000
        }
        
        ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *15 %DisconnectedImg2%
        if (ErrorLevel = 0)
        {
            SendScreenshot("Disconnected from the game", "Disconnected")
            Sleep, 10000
        }
        
        ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *80 %TriumphImg1%
        if (ErrorLevel = 0)
        {
            SendScreenshot("Triumph!", "Triumph")
            Sleep, 10000
        }
        
        ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *80 %TriumphImg2%
        if (ErrorLevel = 0)
        {
            SendScreenshot("Triumph!", "PlayAgain")
            Sleep, 10000
        }
        
        ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *80 %YouLostImg%
        if (ErrorLevel = 0)
        {
            SendScreenshot("You lost!", "YouLost")
            Sleep, 10000
        }
        
        ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *50 %GameOverUI%
        if (ErrorLevel = 0)
        {
            SendScreenshot("Match is ended.", "GameOver")
            Sleep, 10000
        }
    
    
    Sleep, 200
}
return

TakeRandomScreenshot:
    global WebhookEnabled, WebhookLink
    if (!WebhookEnabled || WebhookLink = "")
        return
    
    pBitmap := Gdip_BitmapFromScreen()
    if (pBitmap > 0)
    {
        SendEmbedScreenshot(pBitmap, "Automatic screenshot", 3447003)
        Gdip_DisposeImage(pBitmap)
    }
    
    Random, screenshotDelay, 120000, 240000
    SetTimer, TakeRandomScreenshot, %screenshotDelay%
return

SendScreenshot(description, cType := 3447003)
{
    global WebhookEnabled, WebhookLink, MainPID, pToken
    if (!WebhookEnabled || WebhookLink = "")
        return
    
    pBitmap := Gdip_BitmapFromScreen()
    if (pBitmap > 0)
    {
        color := 15158332
        if (cType = "Triumph" || cType = "PlayAgain")
            color := 3066993
        else if (cType = "YouLost" || cType = "GameOver")
            color := 16744192
        else if (cType = "RobloxNotRunning" || cType = "RobloxCrash")
            color := 16711680
        
        SendEmbedScreenshot(pBitmap, description, color)
        Gdip_DisposeImage(pBitmap)
    }
}

SendEmbedScreenshot(pBitmap, description, color)
{
    global WebhookLink
    
    escapedDescription := StrReplace(description, "\", "\\")
    escapedDescription := StrReplace(escapedDescription, """", "\""")
    escapedDescription := StrReplace(escapedDescription, "`n", "\n")
    
    payload_json := "{"
    payload_json .= """embeds"": [{"
    payload_json .= """description"": """ escapedDescription ""","
    payload_json .= """color"": " color ","
    payload_json .= """image"": {""url"": ""attachment://screenshot.png""}"
    payload_json .= "}]}"
    
    fields := Object()
    fields[1] := Object("name", "payload_json", "content-type", "application/json", "content", payload_json)
    fields[2] := Object("name", "files[0]", "filename", "screenshot.png", "content-type", "image/png", "pBitmap", pBitmap)
    
    CreateFormData(postdata, contentType, fields)
    
    try
    {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", WebhookLink . "?wait=true", false)
        whr.SetRequestHeader("Content-Type", contentType)
        whr.SetTimeouts(0, 60000, 120000, 30000)
        whr.Send(postdata)
    }
    catch e
    {
    }
}

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