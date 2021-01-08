#NoEnv
#Include <ThrowsNonexistent>

class SampBase extends ThrowsNonexistent {
    #IncludeAgain Logger.ahk
    #IncludeAgain Common.ahk

    hGTA                                 := 0x0
    dwGTAPID                             := 0x0
    pMemory                              := {}
    knownModules                         := {}
    knownAddr                            := {}
    iRefreshHandles                      := 0
    
    static szWindow                      := "CR-MP.COM" ;"GTA:SA:MP" ;"CR-MP.COM"

    
    __Delete() {
        if (this.hGTA && this.pMemory[1]) {
            this.Logger.stdLog("Freeing memory", 5)
            this.virtualFreeEx(this.pMemory[1], 0, 0x8000)
        } else if (this.hGTA) {
            this.Logger.stdLog("Closing handle", 5)
            this.Common.closeProcess(this.hGTA)
        }
    }
    
    checkHandles() {
        if (A_TickCount + 500 < iRefreshHandles && hGTA) {
            return true
        } else {
            this.Logger.stdLog("Refreshing handles", 5)
            iRefreshHandles := A_TickCount
            return this.refreshGTA() && this.refreshMemory()
        }
    }
    
    refreshGTA() {
        this.Logger.stdLog("Rerfesh GTA handle", 5)
        newPID := 0
        WinGet, newPID, PID, % this.szWindow
        if(!newPID) {
            this.Logger.stdLog("Pid not found for " . this.szWindow,, true)
            if(this.hGTA) {
                this.Logger.stdLog("GTA handle open, closing handle", 3)
                this.virtualFreeEx(this.pMemory[1], 0, 0x8000)
                this.Common.closeProcess(this.hGTA)
                this.hGTA := 0x0
            }
            this.dwGTAPID := 0
            this.knownModules := {}
            this.pMemory := {}
            return false
        }
        
        if(!this.hGTA || (this.dwGTAPID != newPID)) {
            this.Logger.stdLog("PID changed or handle closed, openning process with PID - " . newPID, 3)
            this.pMemory := {}
            this.knownModules := {}
            this.hGTA := this.Common.openProcess(newPID)
            if(!this.hGTA) { ; this.Common.openProcess fail
                this.dwGTAPID := 0
                this.hGTA := 0x0
                return false
            }
        }
        this.dwGTAPID := newPID
        return true
    }

    refreshMemory() {
        this.Logger.stdLog("Rerfeshing memory", 5)
        if(!this.pMemory.Length()) {
            this.Logger.stdLog("Allocating memory", 5)
            pMem := this.virtualAllocEx(6144, 0x1000 | 0x2000, 0x40)
            if(!pMem) {
                return false
            }
            loop 6 {
                this.pMemory[(A_Index = 6 ? "InjectFunc" : A_Index)] := pMem + (A_Index-1) * 1024
            }
        } else {
            this.Logger.stdLog("Memory already allocated", 5)
        }
        return true
    }
    
    getAddr(patternObj, key) {
        if (!patternObj || !key) {
            this.Logger.stdLog("Invalid args",,true)
            return false
        }
        if (!this.checkHandles()) {
            return false
        }
        if (!(moduleBaseAddr := this.getModuleBaseAddress(patternObj.module))) {
                return false
        }
        if (this.knownAddr[patternObj][key]) {
            return this.knownAddr[patternObj][key] + moduleBaseAddr
        }

        for k, pat in patternObj[key]
        {
            if (offset := this.modulePatternScan(moduleBaseAddr, this.getModuleSize(patternObj.module), pat.pattern)) {
                this.knownAddr[patternObj] := Object(key, offset + round(pat.offset))
                return this.knownAddr[patternObj][key] + moduleBaseAddr
            }
        }

        this.Logger.stdLog("Pattern not found for - " . key,, true)
        return false
    }
    
    callWithParams(dwFunc, aParams, bCleanupStack := true) {
        if (!this.checkHandles()) {
            return false
        }
        
        if (aParams.Length() / 2 != round(aParams.Length() / 2))
        {
            this.Logger.stdLog("Parameters number not even - " . aParams.Length(),,true)
            return false
        }
        
        paramCnt := round(aParams.Length() / 2)
        dwLen := paramCnt * 5 + (bCleanupStack ? 9 : 6) ; PUSH = 5, CALL + RETN = 6, CLEAN = 3
        VarSetCapacity(injectData, dwLen, 0)
        
        
        j := 1
        loop %paramCnt% {
            if (aParams[A_Index*2-1] == "p" || aParams[A_Index*2-1] == "i") {
                dwMemAddress := aParams[A_Index*2]
            } else if (aParams[A_Index*2-1] == "s") {
                if (j>3) {
                    this.Logger.stdLog("Invalid parameter type - " . aParams[A_Index*2-1],,true)
                    return false
                }
                dwMemAddress := this.pMemory[j++]
                if (!this.writeString(dwMemAddress, aParams[A_Index*2])) {
                    return false
                }
            } else {
                this.Logger.stdLog("Invalid parameter type - " . aParams[A_Index*2-1],,true)
                return false
            }
            NumPut(0x68, injectData, (A_Index-1) * 5, "UChar")
            NumPut(dwMemAddress, injectData, (A_Index-1) * 5 + 1, "UInt")
        }
        
        offset := dwFunc - ( this.pMemory.InjectFunc + paramCnt * 5 + 5 )
        NumPut(0xE8, injectData, paramCnt * 5, "UChar")
        NumPut(offset, injectData, paramCnt * 5 + 1, "Int")
        
        if(bCleanupStack) {
            NumPut(0xC483, injectData, paramCnt * 5 + 5, "UShort")
            NumPut(paramCnt*4, injectData, paramCnt * 5 + 7, "UChar")
            NumPut(0xC3, injectData, paramCnt * 5 + 8, "UChar")
        } else {
            NumPut(0xC3, injectData, paramCnt * 5 + 5, "UChar")
        }
        
        if(!this.writeRaw(this.pMemory.InjectFunc, &injectData, dwLen)) {
            return false
        }

        hThread := this.createRemoteThread(0, 0, this.pMemory.InjectFunc, 0, 0, 0)
        if(!hThread) {
            return false
        }

        if(!this.Common.waitForSingleObject(hThread, 0xFFFFFFFF)) {
            return false
        }   
        
        this.Common.closeProcess(hThread)
        
        return true
    }
    
    getModuleBaseAddress(sModule) {
        if(!sModule) {
            this.Logger.stdLog("Invalid module",,true)
            return false
        }
        if (!this.checkHandles()) {
            return false
        }
        if (this.knownModules[sModule].addr) {
            return this.knownModules[sModule].addr
        }
        
        dwSize = 1024*4                    ; 1024 * sizeof(HMODULE = 4)
        VarSetCapacity(hMods, dwSize)    
        VarSetCapacity(cbNeeded, 4)        ; DWORD = 4
        dwRet := DllCall(    "Psapi.dll\EnumProcessModulesEx"
                            , "UInt", this.hGTA
                            , "UInt", &hMods
                            , "UInt", dwSize
                            , "UInt*", cbNeeded
                            , "UInt", 0x01 ; only 32-bit modules
                            , "UInt") 
        if(!dwRet) {
            this.Logger.stdLog("Psapi.dll\EnumProcessModulesEx system error - " . A_LastError,,true)
            return false
        }
        
        dwMods := cbNeeded / 4            ; cbNeeded / sizeof(HMDOULE = 4)
        VarSetCapacity(hModule, 4)        ; HMODULE = 4
        VarSetCapacity(sCurModulePath, 260)    ; MAX_PATH = 260
        loop %dwMods% {
            hModule := NumGet(hMods, (A_Index-1)*4)
            dwRet := DllCall("Psapi.dll\GetModuleFileNameEx"
                    , "UInt", this.hGTA
                    , "UInt", hModule
                    , "Str", sCurModulePath
                    , "UInt", 260
                    , "UInt")
            if(!dwRet && A_LastError != 0x06) { ; returns INVALID_HANDLE even if sCurModulePath is retrieved
                this.Logger.stdLog("Psapi.dll\GetModuleFileNameEx system error - " . A_LastError,,true)
                return false
            }
            SplitPath, sCurModulePath, sFilename
            if(sModule == sFilename) {
                this.knownModules[sModule] := {addr: hModule}
                return this.knownModules[sModule].addr 
            }
        }
        
        this.Logger.stdLog("Module not found - " . sModule,,true)
        return false
    }
    
    getModuleSize(sModule) {
        if(!sModule) {
            this.Logger.stdLog("Invalid module",,true)
            return false
        }
        if (!this.checkHandles()) {
            return false
        }
        if (!this.knownModules[sModule].addr) {
            if (!(this.knownModules[sModule].addr := this.getModuleBaseAddress(sModule))) {
                return false
            }
        }
        if (this.knownModules[sModule].size) {
            return this.knownModules[sModule].size
        }
        
        moduleInfoSize := (A_PtrSize = 4) ? 12 : 24
        VarSetCapacity(moduleInfo, moduleInfoSize)
        dwRet := DllCall("Psapi.dll\GetModuleInformation"
            , "Ptr", this.hGTA
            , "Ptr", knownModules[sModule].addr
            , "Ptr", &moduleInfo
            , "UInt", moduleInfoSize)
        if(!dwRet) {
            this.Logger.stdLog("Psapi.dll\GetModuleInformation system error - " . A_LastError,,true)
            return false
        }
        
        this.knownModules[sModule].size := NumGet(moduleInfo, A_PtrSize, "UInt")
        
        return this.knownModules[sModule].size
    }

    writeRaw(dwAddress, pBuffer, dwLen) {
        if (!dwAddress) {
            this.Logger.stdLog("Invalid address",,true)
            return false
        }
        if (!this.checkHandles()) {
            return false
        }
        
        dwRet := DllCall("WriteProcessMemory"
                            , "UInt", this.hGTA
                            , "UInt", dwAddress
                            , "UInt", pBuffer
                            , "UInt", dwLen
                            , "UInt", 0
                            , "UInt")
        if(!dwRet) {
            this.Logger.stdLog("WriteProcessMemory system error - " . A_LastError,,true)
            return false
        }

        return true
    }

    writeString(dwAddress, wString) {
        if (!dwAddress) {
            this.Logger.stdLog("Invalid address",,true)
            return false
        }
        if (!this.checkHandles()) {
            return false
        }
        sString := wString
        if (A_IsUnicode) {
            sString := this.Common.unicodeToAnsi(wString)
        }
        
        dwRet := DllCall("WriteProcessMemory"
                            , "UInt", this.hGTA
                            , "UInt", dwAddress
                            , "Str", sString
                            , "UInt", StrLen(wString) + 1
                            , "UInt", 0
                            , "UInt")
        if(!dwRet) {
            this.Logger.stdLog("WriteProcessMemory system error - " . A_LastError,,true)
            return false
        }
        
        return true
    }
    
    virtualAllocEx(dwSize, flAllocationType, flProtect) {
        dwRet := DllCall("VirtualAllocEx"
                            , "UInt", this.hGTA
                            , "UInt", 0
                            , "UInt", dwSize
                            , "UInt", flAllocationType
                            , "UInt", flProtect
                            , "UInt")
        if(!dwRet) {
            this.Logger.stdLog("VirtualAllocEx system error - " . A_LastError,,true)
            return false
        }
        
        return dwRet
    }
    
    virtualFreeEx(lpAddress, dwSize, dwFreeType) {
        if (!this.checkHandles()) {
            return false
        }
        
        dwRet := DllCall(    "VirtualFreeEx"
                            , "UInt", this.hGTA
                            , "UInt", lpAddress
                            , "UInt", dwSize
                            , "UInt", dwFreeType
                            , "UInt")
        if(!dwRet) {
            this.Logger.stdLog("VirtualFreeEx system error - " . A_LastError,,true)
        }
        return dwRet
    }
    
    readDWORD(dwAddress) {      
        if (!this.checkHandles()) {
            ErrorLevel := 0x06 ; Invalid Handle
            return false
        }
        
        VarSetCapacity(dwRead, 4)    ; DWORD = 4
        dwRet := DllCall("ReadProcessMemory"
                            , "UInt",  this.hGTA
                            , "UInt",  dwAddress
                            , "Str",   dwRead
                            , "UInt",  4
                            , "UInt*", 0
                            , "UInt")
        if(!dwRet && A_LastError != 0x12B) {
            ErrorLevel := A_LastError
            this.Logger.stdLog("ReadProcessMemory system error - " . A_LastError,,true)
            return false
        }
        
        ErrorLevel := 0x0
        return NumGet(dwRead, 0, "UInt")
    }
    
    readRaw(address, bufferAddres, bytes) {
        if (!this.checkHandles()) {
            ErrorLevel := 0x06 ; Invalid Handle
            return false
        }
        if(!address) {
            this.Logger.stdLog("Invalid address",,true)
            return false
        }
        dwRet := DllCall("ReadProcessMemory"
            , "Ptr", this.hGTA
            , "Ptr", address
            , "Ptr", bufferAddres
            , "UInt", bytes
            , "UInt*", pNumberOfBytesRead
            , "UInt")
        if(!dwRet && A_LastError != 0x12B) {
            this.Logger.stdLog("ReadProcessMemory system error - " . A_LastError,,true)
            return false
        }
        return pNumberOfBytesRead
    }
    
    createRemoteThread(lpThreadAttributes, dwStackSize, lpStartAddress, lpParameter, dwCreationFlags, lpThreadId) {
        if (!this.checkHandles()) {
            return false
        }

        hThread := DllCall("CreateRemoteThread"
                            , "UInt", this.hGTA
                            , "UInt", lpThreadAttributes
                            , "UInt", dwStackSize
                            , "UInt", lpStartAddress
                            , "UInt", lpParameter
                            , "UInt", dwCreationFlags
                            , "UInt", lpThreadId
                            , "UInt")
        if(!hThread) {
            this.Logger.stdLog("CreateRemoteThread system error - " . A_LastError,,true)
            return false
        }
        
        return hThread
    }
    
    modulePatternScan(dwModuleBaseAddress, dwModuleSize, aPatternStr) {
        if (!this.checkHandles()) {
            ErrorLevel := 0x06 ; Invalid Handle
            return false
        }
        
        if (!this.Common.getNeedleFromPatternStr(patternMask, needleBuffer, aPatternStr)) {
            this.Logger.stdLog("Invalid pattern",,true)
            ErrorLevel := -1
            return false
        }

        offset := this.patternScan(dwModuleBaseAddress, dwModuleSize, patternMask, &needleBuffer)
        
        if(ErrorLevel) {
            return false
        }
        
        return offset
    }
    
    patternScan(startAddress, sizeOfRegionBytes, patternMask, needleBufferAddress) {
        if (!this.checkHandles()) {
            ErrorLevel := 0x06 ; Invalid Handle
            return false
        }

        VarSetCapacity(buffer, sizeOfRegionBytes)
        if (!this.readRaw(startAddress, &buffer, sizeOfRegionBytes) || (offset := this.Common.bufferScanForMaskedPattern(&buffer, sizeOfRegionBytes, patternMask, needleBufferAddress)) < 0) {
            ErrorLevel := -1
            return false
        }
        
        ErrorLevel := 0
        return offset
    }
    
}
