#Include <stdLog> ; required

closeProcess(hProcess) {
    if(!hProcess) {
        stdLog("Invalid handle",,true)
        return false
    }
    dwRet := DllCall(    "CloseHandle"
                        , "Uint", hProcess
                        , "UInt")
    if(!dwRet) {
        stdLog("CloseHandle system error - " . A_LastError,,true)
    }
    return dwRet
}

openProcess(dwPID, dwRights = 0x1F0FFF) {
    hProcess := DllCall("OpenProcess"
                        , "UInt", dwRights
                        , "int",  0
                        , "UInt", dwPID
                        , "Uint")
    if(!hProcess) {
        stdLog("OpenProcess system error - " . A_LastError,,true)
    }
    return hProcess
}

waitForSingleObject(hThread, dwMilliseconds) {
    if(!hThread) {
        stdLog("Invalid handle",,true)
        return false
    }
    dwRet := DllCall("WaitForSingleObject"
                        , "UInt", hThread
                        , "UInt", dwMilliseconds
                        , "UInt")
    if(dwRet == 0xFFFFFFFF) {
        stdLog("WaitForSingleObject system error - " . A_LastError,,true)
        return false
    }
    return dwRet
}

unicodeToAnsi(wString, nLen = 0) {
    pString := (wString + 1) > 65536 ? wString : &wString

    If !nLen
    {
      nLen := DllCall("WideCharToMultiByte"
      , "Uint", 0
      , "Uint", 0
      , "Uint", pString
      , "int",  -1
      , "Uint", 0
      , "int",  0
      , "Uint", 0
      , "Uint", 0)
    }
    if(!nLen) {
        stdLog("WideCharToMultiByte system error - " . A_LastError,,true)
        return false
    }
    VarSetCapacity(sString, nLen)

    nLen := DllCall("WideCharToMultiByte"
      , "Uint", 0
      , "Uint", 0
      , "Uint", pString
      , "int",  -1
      , "str",  sString
      , "int",  nLen
      , "Uint", 0
      , "Uint", 0)
    if(!nLen) {
        stdLog("WideCharToMultiByte system error - " . A_LastError,,true)
        return false
    }
    return sString
}

getNeedleFromPatternStr(byRef patternMask, byRef needleBuffer, aPatternStr)
{
    patternMask := ""
    VarSetCapacity(needleBuffer, StrLen(aPatternStr))
    byteCnt := StrLen(aPatternStr) / 2
    loop %byteCnt%
    {
        byte := SubStr(aPatternStr, A_Index*2-1, 2)
        patternMask .= (RegExMatch(byte, "i)[0-9a-f]{2}") ? "x" : "?")
        NumPut(round("0x" . byte), needleBuffer, A_Index - 1, "UChar")
    }
    return round(StrLen(patternMask))
}

bufferScanForMaskedPattern(byRef hayStackAddress, sizeOfHayStackBytes, patternMask, byRef needleAddress, startOffset := 0) {
    
    if (A_PtrSize = 4) {   
        p := MCode("1,x86:8B44240853558B6C24182BC5568B74242489442414573BF0773E8B7C241CBB010000008B4424242BF82BD8EB038D49008B54241403D68A0C073A0A740580383F750B8D0C033BCD74174240EBE98B442424463B74241876D85F5E5D83C8FF5BC35F8BC65E5D5BC3")
    } else {
        p := MCode("1,x64:48895C2408488974241048897C2418448B5424308BF2498BD8412BF1488BF9443BD6774A4C8B5C24280F1F800000000033C90F1F400066660F1F840000000000448BC18D4101418D4AFF03C80FB60C3941380C18740743803C183F7509413BC1741F8BC8EBDA41FFC2443BD676C283C8FF488B5C2408488B742410488B7C2418C3488B5C2408488B742410488B7C2418418BC2C3")
    }
    if ((needleSize := StrLen(patternMask)) + startOffset > sizeOfHayStackBytes) {
        stdLog("Needle can't exist inside this region",,true)
        return false
    }
    
    if (sizeOfHayStackBytes <= 0) {
        stdLog("Invalid sizeOfHayStackBytes parameter",,true)
        return false
    }
    
    offset := DllCall(p
        , "Ptr", hayStackAddress
        , "UInt", sizeOfHayStackBytes
        , "Ptr", needleAddress
        , "UInt", needleSize
        , "AStr", patternMask
        , "UInt", startOffset
        , "cdecl int")
    DllCall("GlobalFree", "Ptr", p)
    return offset
}

MCode(mcode) {
    e := {1:4, 2:1}
    c := (A_PtrSize=8) ? "x64" : "x86"
    if (!regexmatch(mcode, "^([0-9]+),(" c ":|.*?," c ":)([^,]+)", m)) {
        stdLog("Invalid mcode - " . mcode,,true)
        return false
    }
    dwRet := DllCall("crypt32\CryptStringToBinary"
        , "Str", m3
        , "UInt", 0
        , "UInt", e[m1]
        , "Ptr", 0
        , "UInt*", s
        , "Ptr", 0
        , "Ptr", 0
        , "UInt")
    if(!dwRet) {
        stdLog("crypt32\CryptStringToBinary system error - " . A_LastError,,true)
        return false
    }
    
    p := DllCall("GlobalAlloc"
        , "UInt", 0
        , "Ptr", s
        , "Ptr")
    if(!p) {
        stdLog("GlobalAlloc system error - " . A_LastError,,true)
        return false
    }
        
    dwRet := DllCall("VirtualProtect"
        , "Ptr", p
        , "Ptr", s
        , "UInt", 0x40
        , "UInt*", op
        , "UInt")
    if(!dwRet) {
        stdLog("VirtualProtect system error - " . A_LastError,,true)
        DllCall("GlobalFree", "Ptr", p)
        return false
    }    
    
    dwRet := DllCall("crypt32\CryptStringToBinary"
        , "Str", m3
        , "UInt", 0
        , "UInt", e[m1]
        , "Ptr", p
        , "UInt*", s
        , "Ptr", 0
        , "Ptr", 0)
    if(!dwRet) {
        stdLog("crypt32\CryptStringToBinary system error - " . A_LastError,,true)
        DllCall("GlobalFree", "Ptr", p)
        return false
    }
    return p
}

HexToDec(str)
{   
    local newStr := ""
    static comp := {0:0, 1:1, 2:2, 3:3, 4:4, 5:5, 6:6, 7:7, 8:8, 9:9, "a":10, "b":11, "c":12, "d":13, "e":14, "f":15}
    StringLower, str, str
    str := RegExReplace(str, "^0x|[^a-f0-9]+", "")
    Loop, % StrLen(str) {
       newStr .= SubStr(str, (StrLen(str)-A_Index)+1, 1)
    }
    newStr := StrSplit(newStr, "")
    local ret := 0
    for i,char in newStr
       ret += comp[char]*(16**(i-1))
    return ret
}
