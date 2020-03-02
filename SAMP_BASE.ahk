#Include <stdLog>
#Include <common>
global LOG_LVL := 1

class SAMP_BASE
{ 
	hGTA                                 := 0x0
	dwGTAPID                             := 0x0
	dwSAMP                               := 0x0
	dwSAMPSize                           := 0x0
	pMemory                              := {}
	dwSAMPAddr							 := {}
	iRefreshHandles                      := 0
	
	static szWindow                      := "CR-MP.COM" ;"GTA:SA:MP" ;"CR-MP.COM"
	static patternPath                   := A_ScriptDir . "\patterns.ini"
	
	__Delete() {
		if (this.hGTA && this.pMemory[1]) {
			stdLog("Freeing memory", 5)
			this.virtualFreeEx(this.pMemory[1], 0, 0x8000)
		} else if (this.hGTA) {
			stdLog("Closing handle", 5)
			closeProcess(this.hGTA)
		}
	}
	
	checkHandles() {
		if (A_TickCount + 500 < iRefreshHandles && hGTA) {
			return true
		} else {
			stdLog("Refreshing handles", 5)
			iRefreshHandles := A_TickCount
			return this.refreshGTA() && this.refreshSAMP() && this.refreshMemory()
		}
	}
	
	refreshGTA() {
		stdLog("Rerfesh GTA handle", 5)
		newPID := 0
		WinGet, newPID, PID, % this.szWindow
		if(!newPID) {
			stdLog("Pid not found for " . this.szWindow,, true)
			if(this.hGTA) {
				stdLog("GTA handle open, closing handle", 3)
				this.virtualFreeEx(this.pMemory[1], 0, 0x8000)
				closeProcess(this.hGTA)
				this.hGTA := 0x0
			}
			this.dwGTAPID := 0
			this.hGTA := 0x0
			this.dwSAMP := 0x0
			this.pMemory := []
			return false
		}
		
		if(!this.hGTA || (this.dwGTAPID != newPID)) {
			stdLog("PID changed or handle closed, openning process with PID - " . newPID, 3)
			this.hGTA := openProcess(newPID)
			if(!this.hGTA) { ; openProcess fail
				this.dwGTAPID := 0
				this.hGTA := 0x0
				this.dwSAMP := 0x0
				this.pMemory := []
				return false
			}
			this.dwGTAPID := newPID
			this.dwSAMP := 0x0
			this.pMemory := []
		}
		return true
	}
	
	refreshSAMP() {
		stdLog("Rerfesh SAMP", 5)
		if(this.dwSAMP) {
			stdLog("SAMP module base adress already set", 5)
			return true
		}
		stdLog("Getting SAMP module adress", 5)
		this.dwSAMP := this.getModuleBaseAddress("samp.dll")
		if(!this.dwSAMP) {
			return false
		}
		stdLog("Getting SAMP module size", 5)
		this.dwSAMPSize := this.getModuleSize(this.dwSAMP)
		if(!this.dwSAMPSize) {
			return false
		}
		return true
	}

	refreshMemory() {
		stdLog("Rerfeshing memory", 5)
		if(!this.pMemory.Length()) {
			stdLog("Allocating memory", 5)
			pMem := this.virtualAllocEx(6144, 0x1000 | 0x2000, 0x40)
			if(!pMem) {
				return false
			}
			loop 6 {
				this.pMemory[(A_Index = 6 ? "InjectFunc" : A_Index)] := pMem + (A_Index-1) * 1024
			}
		} else {
			stdLog("Memory already allocated", 5)
		}
		return true
	}
	
	getSAMPAddr(key, num := 0) {
		if (!this.checkHandles()) {
			return false
		}
		if (this.dwSAMPAddr[key]) {
			return this.dwSAMPAddr[key] + this.dwSAMP
		}
		if (num) {
			ptrNum := "_" . num
		}
		IniRead, aPatternStr, % this.patternPath , patterns, %key%%ptrNum%, %A_Space%
		if (!aPatternStr && !num) {
			IniRead, aPatternStr, % this.patternPath , patterns, %key%_1, %A_Space%
			if (!aPatternStr) {
				stdLog("Pattern not specified for - " . key,, true)
				return false
			}
			loop 
			{
				IniRead, aPatternStr, % this.patternPath , patterns, %key%_%A_Index%, %A_Space%
				if (!aPatternStr) {
					stdLog("Pattern not found for - " . key,, true)
					return false
				}
				offset := this.modulePatternScan(this.dwSAMP, this.dwSAMPSize, aPatternStr)
				if (!ErrorLevel) {
					IniRead, pattern_offset, % this.patternPath , patterns, %key%_%A_Index%_offset, 0
					offset += round(pattern_offset)
					break
				}
			}
		} else {
			offset := this.modulePatternScan(this.dwSAMP, this.dwSAMPSize, aPatternStr)
			if (ErrorLevel) {
				stdLog("Pattern not found for - " . key,, true)
				return false
			}
			IniRead, pattern_offset, % this.patternPath , patterns, %key%%ptrNum%_offset, 0
			offset += round(pattern_offset)
		}
		this.dwSAMPAddr[key] := offset
		return this.dwSAMP + offset
	}
	
	callWithParams(dwFunc, aParams, bCleanupStack := true) {
		if (!this.checkHandles()) {
			return false
		}
		
		if (aParams.Length() / 2 != round(aParams.Length() / 2))
		{
			stdLog("Parameters number not even - " . aParams.Length(),,true)
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
					stdLog("Invalid parameter type - " . aParams[A_Index*2-1],,true)
					return false
				}
				dwMemAddress := this.pMemory[j++]
				if (!this.writeString(dwMemAddress, aParams[A_Index*2])) {
					return false
				}
			} else {
				stdLog("Invalid parameter type - " . aParams[A_Index*2-1],,true)
				return false
			}
			NumPut(0x68, injectData, (A_Index-1) * 5, "UChar")
			NumPut(dwMemAddress, injectData, (A_Index-1) * 5 + 1, "UInt")
		}
		
		offset := dwFunc - ( this.pMemory["InjectFunc"] + paramCnt * 5 + 5 )
		NumPut(0xE8, injectData, paramCnt * 5, "UChar")
		NumPut(offset, injectData, paramCnt * 5 + 1, "Int")
		
		if(bCleanupStack) {
			NumPut(0xC483, injectData, paramCnt * 5 + 5, "UShort")
			NumPut(paramCnt*4, injectData, paramCnt * 5 + 7, "UChar")
			NumPut(0xC3, injectData, paramCnt * 5 + 8, "UChar")
		} else {
			NumPut(0xC3, injectData, paramCnt * 5 + 5, "UChar")
		}
		
		if(!this.writeRaw(this.pMemory["InjectFunc"], &injectData, dwLen)) {
			return false
		}

		hThread := this.createRemoteThread(0, 0, this.pMemory["InjectFunc"], 0, 0, 0)
		if(!hThread) {
			return false
		}

		if(!waitForSingleObject(hThread, 0xFFFFFFFF)) {
			return false
		}   
		
		closeProcess(hThread)
		
		return true
	}
	
	getModuleBaseAddress(sModule) {
		if(!sModule) {
			stdLog("Invalid module",,true)
			return false
		}
		if (!this.hGTA) {
			stdLog("Invalid GTA handle",,true)
			return false
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
			stdLog("Psapi.dll\EnumProcessModulesEx system error - " . A_LastError,,true)
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
	
	getModuleSize(hModule) {
		if(!hModule) {
			stdLog("Invalid module",,true)
			return false
		}
		if (!this.hGTA) {
			stdLog("Invalid GTA handle",,true)
			return false
		}
		
		moduleInfoSize := (A_PtrSize = 4) ? 12 : 24
		VarSetCapacity(moduleInfo, moduleInfoSize)
		dwRet := DllCall("Psapi.dll\GetModuleInformation"
			, "Ptr", this.hGTA
			, "Ptr", hModule
			, "Ptr", &moduleInfo
			, "UInt", moduleInfoSize)
		if(!dwRet) {
			stdLog("Psapi.dll\GetModuleInformation system error - " . A_LastError,,true)
			return false
		}
		
		return NumGet(moduleInfo, A_PtrSize, "UInt")
	}

	writeRaw(dwAddress, pBuffer, dwLen) {
		if (!this.checkHandles()) {
			return false
		}
		if (!dwAddress) {
			stdLog("Invalid address",,true)
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
			stdLog("WriteProcessMemory system error - " . A_LastError,,true)
			return false
		}

		return true
	}

	writeString(dwAddress, wString) {
		if (!this.checkHandles()) {
			return false
		}
		if (!dwAddress) {
			stdLog("Invalid address",,true)
			return false
		}
		sString := wString
		if (A_IsUnicode) {
			sString := unicodeToAnsi(wString)
		}
		
		dwRet := DllCall("WriteProcessMemory"
							, "UInt", this.hGTA
							, "UInt", dwAddress
							, "Str", sString
							, "UInt", StrLen(wString) + 1
							, "UInt", 0
							, "UInt")
		if(!dwRet) {
			stdLog("WriteProcessMemory system error - " . A_LastError,,true)
			return false
		}
		
		return true
	}
	
	virtualAllocEx(dwSize, flAllocationType, flProtect) {
		if (!this.hGTA) {
			stdLog("Invalid GTA handle",,true)
			return false
		}
		
		dwRet := DllCall("VirtualAllocEx"
							, "UInt", this.hGTA
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
	
	virtualFreeEx(lpAddress, dwSize, dwFreeType) {
		if (!this.hGTA) {
			stdLog("Invalid GTA handle",,true)
			return false
		}
		dwRet := DllCall(    "VirtualFreeEx"
							, "UInt", this.hGTA
							, "UInt", lpAddress
							, "UInt", dwSize
							, "UInt", dwFreeType
							, "UInt")
		if(!dwRet) {
			stdLog("VirtualFreeEx system error - " . A_LastError,,true)
		}
		return dwRet
	}
	
	readDWORD(dwAddress) {		
		if (!this.hGTA) {
			ErrorLevel := 0x06 ; Invalid Handle
			stdLog("Invalid GTA handle",,true)
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
			stdLog("ReadProcessMemory system error - " . A_LastError,,true)
			return false
		}
		
		ErrorLevel := 0x0
		return NumGet(dwRead, 0, "UInt")
	}
	
	readRaw(address, bufferAddres, bytes) {
		if (!this.hGTA) {
			ErrorLevel := 0x06 ; Invalid Handle
			stdLog("Invalid GTA handle",,true)
			return false
		}
		if(!address) {
			stdLog("Invalid address",,true)
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
			stdLog("ReadProcessMemory system error - " . A_LastError,,true)
			return false
		}
		return pNumberOfBytesRead
	}
	
	createRemoteThread(lpThreadAttributes, dwStackSize, lpStartAddress, lpParameter, dwCreationFlags, lpThreadId) {
		if (!this.hGTA) {
			stdLog("Invalid GTA handle",,true)
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
			stdLog("CreateRemoteThread system error - " . A_LastError,,true)
			return false
		}
		
		return hThread
	}
	
	modulePatternScan(dwModuleBaseAddress, dwModuleSize, aPatternStr) {
		if(!this.hGTA) {
			stdLog("Invalid GTA handle",,true)
			ErrorLevel := 0x06
			return false
		} 
		if (!getNeedleFromPatternStr(patternMask, needleBuffer, aPatternStr)) {
			stdLog("Invalid pattern",,true)
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
		if(!this.hGTA) {
			stdLog("Invalid GTA handle",,true)
			ErrorLevel := 0x06
			return false
		}

		VarSetCapacity(buffer, sizeOfRegionBytes)
		if (!this.readRaw(startAddress, &buffer, sizeOfRegionBytes) || (offset := bufferScanForMaskedPattern(&buffer, sizeOfRegionBytes, patternMask, needleBufferAddress)) < 0) {
			ErrorLevel := -1
			return false
		}
		
		ErrorLevel := 0
		return offset
	}
	
}