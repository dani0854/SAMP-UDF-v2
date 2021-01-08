#Include <SampBase>

class SampUdfV2 extends SampBase {

  #IncludeAgain Lib/SampPattern.ahk
  
  addChatMessage(wText, msgColor := -1) {
    wText := "" wText
    
    if (!(chatFunc := this.getAddr(this.SampPattern, "FUNC_SAMP_ADDTOCHATWND")) || !(chatPtr := this.readDWORD(this.readDWORD(this.getAddr(this.SampPattern, "ADDR_SAMP_CHATMSG_PTR_PTR"))))) {
      return false
    }

    if (msgColor != -1) {
      VarSetCapacity(colorData, 4, 0)
      NumPut(this.Common.HexToDec(msgColor),colorData,0,"Int")
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
