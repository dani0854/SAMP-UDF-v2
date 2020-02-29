#Include <stdLog>
#Include <dllFuncs>

class SAMP_BASE
{ 
	hGTA                                 := 0x0
	dwGTAPID                             := 0x0
	dwSAMP                               := 0x0
	pMemory                              := 0x0
	pParam1                              := 0x0
	pParam2                              := 0x0
	pParam3                              := 0x0
	pParam4                              := 0x0
	pParam5                              := 0x0
	pInjectFunc                          := 0x0
	
	static szWindow                      := "CR-MP.COM"
	
	refreshHandles() {
		stdLog("Refreshing handles", 5)
		return this.refreshGTA() && this.refreshSAMP() && this.refreshMemory()
	}
	
	refreshGTA() {
		stdLog("Rerfesh GTA handle", 5)
		newPID := 0
		WinGet, newPID, PID, % this.szWindow
		if(!newPID) {
			stdLog("Pid not found for " . this.szWindow,, true)
			if(this.hGTA) {
				stdLog("GTA handle open, closing handle", 3)
				virtualFreeEx(this.hGTA, this.pMemory, 0, 0x8000)
				closeProcess(this.hGTA)
				this.hGTA := 0x0
			}
			this.dwGTAPID := 0
			this.hGTA := 0x0
			this.dwSAMP := 0x0
			this.pMemory := 0x0
			return false
		}
		
		if(!this.hGTA || (this.dwGTAPID != newPID)) { ; changed PID, closed handle
			stdLog("PID changed or handle closed, openning process with PID - " . newPID, 3)
			this.hGTA := openProcess(newPID)
			if(!this.hGTA) { ; openProcess fail
				this.dwGTAPID := 0
				this.hGTA := 0x0
				this.dwSAMP := 0x0
				this.pMemory := 0x0
				return false
			}
			this.dwGTAPID := newPID
			this.dwSAMP := 0x0
			this.pMemory := 0x0
		}
		return true
	}
	
	refreshSAMP() {
		stdLog("Rerfesh SAMP", 5)
		if(dwSAMP) {
			stdLog("SAMP module base adress already set", 5)
			return true
		}
		stdLog("Getting SAMP module adress", 5)
		dwSAMP := getModuleBaseAddress("samp.dll", this.hGTA)
		if(!dwSAMP) {
			return false
		}
		
		return true
	}

	refreshMemory() {
		stdLog("Rerfeshing memory", 5)
		if(!this.pMemory) {
			stdLog("Allocating memory", 5)
			pMemory := virtualAllocEx(this.hGTA, 6144, 0x1000 | 0x2000, 0x40)
			if(!pMemory) {
				return false
			}
			this.pMemory     := pMemory
			this.pParam1     := pMemory
			this.pParam2     := pMemory + 1024
			this.pParam3     := pMemory + 2048
			this.pParam4     := pMemory + 3072
			this.pParam5     := pMemory + 4096
			this.pInjectFunc := pMemory + 5120
		} else {
			stdLog("Memory already allocated", 5)
		}
		return true
	}
	
	
}