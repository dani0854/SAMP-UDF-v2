#Include stdLog.ahk

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

getModuleBaseAddress(sModule, hProcess) {
    if(!sModule) {
        stdLog("Invalid module",,true)
        return false
    }
    if(!hProcess) {
        stdLog("Invalid handle",,true)
        return false
    }
    
    dwSize = 1024*4                    ; 1024 * sizeof(HMODULE = 4)
    VarSetCapacity(hMods, dwSize)    
    VarSetCapacity(cbNeeded, 4)        ; DWORD = 4
    dwRet := DllCall(    "Psapi.dll\EnumProcessModulesEx"
                        , "UInt", hProcess
                        , "UInt", &hMods
                        , "UInt", dwSize
                        , "UInt*", cbNeeded
                        , "UInt", 0x01) ; only 32-bit modules
    if(!dwRet) {
        stdLog("Psapi.dll\EnumProcessModulesEx system error - " . A_LastError,,true)
        return false
    }
    
    dwMods := cbNeeded / 4            ; cbNeeded / sizeof(HMDOULE = 4)
    VarSetCapacity(hModule, 4)        ; HMODULE = 4
    VarSetCapacity(sCurModulePath, 260)    ; MAX_PATH = 260
    loop %dwMods% {
        hModule := NumGet(hMods, (A_Index-1)*4)
        dwRet := DllCall("Psapi.dll\GetModuleFileNameEx"
                , "UInt", hProcess
                , "UInt", hModule
                , "Str", sCurModulePath
                , "UInt", 260)
		if(!dwRet && A_LastError != 0x06) { ; returns INVALID_HANDLE even if sCurModulePath is retrieved
			stdLog("Psapi.dll\GetModuleFileNameEx system error - " . A_LastError,,true)
			return false
		}
        SplitPath, sCurModulePath, sFilename
        if(sModule == sFilename) {
            return hModule
        }
    }
    
    stdLog("Module not found - " . sModule,,true)
    return false
}

virtualAllocEx(hProcess, dwSize, flAllocationType, flProtect) {
    if(!hProcess) {
        stdLog("Invalid handle",,true)
        return false
    }
    
    dwRet := DllCall(    "VirtualAllocEx"
                        , "UInt", hProcess
                        , "UInt", 0
                        , "UInt", dwSize
                        , "UInt", flAllocationType
                        , "UInt", flProtect
                        , "UInt")
    if(!dwRet) {
        stdLog("VirtualAllocEx system error - " . A_LastError,,true)
		return false
    }
    
    return dwRet
}

virtualFreeEx(hProcess, lpAddress, dwSize, dwFreeType) {
    if(!hProcess) {
        stdLog("Invalid handle",,true)
        return false
    }
    dwRet := DllCall(    "VirtualFreeEx"
                        , "UInt", hProcess
                        , "UInt", lpAddress
                        , "UInt", dwSize
                        , "UInt", dwFreeType
                        , "UInt")
    if(!dwRet) {
        stdLog("VirtualFreeEx system error - " . A_LastError,,true)
    }
    return dwRet
}
