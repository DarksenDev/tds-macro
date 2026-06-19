#NoEnv
#SingleInstance, force
#NoTrayIcon

if 0 < 1
{
    MsgBox,,, You are not supposed to run it manually!
    ExitApp
}

MainPID := %1%
SetWorkingDir, %A_LineFile%\..\..\
Opt := A_AppData "\Ultimate_Macro\Macros\TDSMacro\Options"
SettingsFile := Opt "\Settings.tds"
StateFile := A_AppData "\Ultimate_Macro\Macros\TDSMacro\state.ini"


IniRead, WebhookLink, %SettingsFile%, Webhook, Link, %A_Space%
IniRead, tempWebhook, %SettingsFile%, Webhook, Enabled, OFF
WebhookEnabled := (tempWebhook = "ON" || tempWebhook = "1") ? true : false
IniRead, SendCurrenciesEnabled, %SettingsFile%, Webhook, SendCurrencies, 1

if (!WebhookEnabled || WebhookLink = "")
{
    ExitApp
}

#Include %A_LineFile%\..\..\lib\Gdip_All.ahk
#Include %A_LineFile%\..\..\lib\ocr.ahk

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

WinWait, ahk_exe RobloxPlayerBeta.exe, , 55
Sleep, 15000

Loop
{
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
    if (ErrorLevel = 0) {
        SendScreenshot("Triumph!", "Triumph")
        SendCurrencies("Triumph")
        Sleep, 10000
    }
    
    ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *80 %TriumphImg2%
    if (ErrorLevel = 0) {
        SendScreenshot("Triumph!", "PlayAgain")
        SendCurrencies("Triumph")
        Sleep, 10000
    }

    ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *80 %YouLostImg%
    if (ErrorLevel = 0) {
        SendScreenshot("You lost!", "YouLost")
        SendCurrencies("Loss")
        Sleep, 10000
    }

    ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *50 %GameOverUI%
    if (ErrorLevel = 0)
    {
        matchResult := "Unknown"
        
        ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *80 %TriumphImg1%
        if (ErrorLevel = 1)
            ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *80 %TriumphImg2%
        
        if (ErrorLevel = 0)
        {
            matchResult := "Triumph"
            SendScreenshot("Triumph!", "Triumph")
        } else {
            ImageSearch, FoundX, FoundY, 620, 379, 1334, 850, *80 %YouLostImg%
            if (ErrorLevel = 0)
            {
                matchResult := "Loss"
                SendScreenshot("You lost!", "YouLost")
            } else {
                SendScreenshot("Failed to determinate triumph or loss. Match is ended.", "GameOver")
            }
        }

        SendCurrencies(matchResult)
        Sleep, 10000
    }
    
    Sleep, 400
}
return

SendCurrencies(matchResult := "")
{
    global WebhookLink, StateFile, SendCurrenciesEnabled

    if (SendCurrenciesEnabled = 0)
    {
        return
    }
    
    AreaW := 400
    AreaH := 200
    SearchArea := "638|540|" . AreaW . "|" . AreaH
    
    pBitmapArea := Gdip_BitmapFromScreen(SearchArea)
    
    pBitmapResized := Gdip_CreateBitmap(AreaW * 3, AreaH * 3)
    G1 := Gdip_GraphicsFromImage(pBitmapResized)
    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", G1, "Int", 7)
    Gdip_DrawImage(G1, pBitmapArea, 0, 0, AreaW * 3, AreaH * 3, 0, 0, AreaW, AreaH)
    
    ocrResult := ocrFromBitmap(pBitmapResized)
    
    Gdip_DeleteGraphics(G1)
    Gdip_DisposeImage(pBitmapResized)
    Gdip_DisposeImage(pBitmapArea)

    coinVal := 0
    gemVal := 0

    if RegExMatch(ocrResult, "i)(\d[\d,]*)\s*Coin", coinsMatch)
        coinVal := StrReplace(coinsMatch1, ",", "")
    
    if RegExMatch(ocrResult, "i)(\d[\d,]*)\s*Gem", gemsMatch)
        gemVal := StrReplace(gemsMatch1, ",", "")
    
    IniRead, totalTriumphs, %StateFile%, State, TotalTriumphs, 0
    IniRead, totalLosses, %StateFile%, State, TotalLosses, 0
    
    if (matchResult = "Triumph")
    {
        totalTriumphs += 1
        IniWrite, %totalTriumphs%, %StateFile%, State, TotalTriumphs
    }
    else if (matchResult = "Loss")
    {
        totalLosses += 1
        IniWrite, %totalLosses%, %StateFile%, State, TotalLosses
    }
    
    IniRead, startCoins, %StateFile%, State, StartCoins, 0
    IniRead, startGems, %StateFile%, State, StartGems, 0
    IniRead, savedCoins, %StateFile%, State, Coins, 0
    IniRead, savedGems, %StateFile%, State, Gems, 0
    
    totalCoins := savedCoins + coinVal
    totalGems := savedGems + gemVal
    
    IniDelete, %StateFile%, State, Coins
    IniDelete, %StateFile%, State, Gems
    IniWrite, %totalCoins%, %StateFile%, State, Coins
    IniWrite, %totalGems%, %StateFile%, State, Gems
    
    earnedCoins := totalCoins - startCoins
    earnedGems := totalGems - startGems
    
    IniRead, autorunStart, %StateFile%, State, StartTime, 0
    if (autorunStart > 0) {
        elapsedMs := A_TickCount - autorunStart
        elapsedHours := elapsedMs / 3600000
        coinsPerHour := (elapsedHours > 0.001) ? Round(earnedCoins / elapsedHours) : 0
        gemsPerHour := (elapsedHours > 0.001) ? Round(earnedGems / elapsedHours) : 0
    } else {
        coinsPerHour := 0
        gemsPerHour := 0
    }
    
    description := "Coins: " . totalCoins . " (+" . earnedCoins . ")`n"
    description .= "Gems: " . totalGems . " (+" . earnedGems . ")`n"
    description .= "Total Triumphs: " . totalTriumphs . ", Total Losses: " . totalLosses . "`n"
    description .= "`n"
    description .= "📊 " . coinsPerHour . " Coins/hr | " . gemsPerHour . " Gems/hr"
    
    description := StrReplace(description, "\", "\\")
    description := StrReplace(description, """", "\""")
    description := StrReplace(description, "`n", "\n")

    jsonPayload := "{""embeds"": [{""title"": ""Currencies"", ""description"": """ . description . """, ""color"": 5814783}]}"
    
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", WebhookLink, false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send(jsonPayload)
    } catch e {
    }
}

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
            color := 12434877
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
    
    payload_json := "{""embeds"": [{""description"": """ . escapedDescription . """, ""color"": " . color . ", ""image"": {""url"": ""attachment://screenshot.png""}}]}"
    
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