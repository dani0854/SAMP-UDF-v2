#Include <stdLog>
#Include <common>
#Include SAMP_BASE.ahk

class SAMP_UDF_V2 extends SAMP_BASE {
	
	static ADDR_SAMP_CHATMSG_PTR  := 0x21a0ec
	static FUNC_SAMP_ADDTOCHATWND := 0x645f0
	
	__Call(method, byRef args*) {
		if (ObjHasKey(SAMP_BASE, method)) {
			return this[method].(this, args*)
		} else if (ObjHasKey(SAMP_UDF_V2, method)) {
			if(base.checkHandles()) {
				return this[method].(this, args*)
			}
			return false
		} else {
			throw Exception( "Unknown method '" method "' requested from object '" this.__Class "'", -1 )
		}
    }
	
	addChatMessage(wText, msgColor := -1) {
		wText := "" wText
		
		if (!(chatFunc := this.getSAMPAddr("FUNC_SAMP_ADDTOCHATWND")) || !(chatPtr := this.readDWORD(this.getSAMPAddr("ADDR_SAMP_CHATMSG_PTR")))) {
			return false
		}

		if (msgColor != -1) {
			VarSetCapacity(colorData, 4, 0)
			NumPut(HexToDec(msgColor),colorData,0,"Int")
			VarSetCapacity(oldColor, 4, 0)
			NumPut(this.readDWORD(chatPtr + 0x12A), oldColor,0,"Int")
			this.writeRaw(chatPtr + 0x12A, &colorData, 4)
		}

		this.callWithParams(chatFunc, ["s", wText, "p", chatPtr])

		if (msgColor != -1) {
			this.writeRaw(chatPtr + 0x12A, &oldColor, 4)
		}
		
		return true
	}
}