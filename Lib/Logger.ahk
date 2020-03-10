class Logger extends ThrowsNonexistent {
    
    stdLog(msg, logLvlMin := 1, err := false, traceback := false, stream := "stdout") {
        EnvGet, LOG_LVL, LOG_LVL
        if (logLvlMin > (LOG_LVL ? LOG_LVL : 1) && !err) {
            return
        }
        msg := (err ? "Error caused by: " : "") . msg
        if (traceback || err) {
            Loop
            {
                e := Exception(".", offset := -A_Index)
                if (e.What == offset) {
                    break
                }
                msg .= "`r`n`tat " . e.file . " (" . e.What . ":" . e.Line . ")"
            }
        }
        if (stream == "stdout") {
            FileAppend, %msg%`r`n, *
        } else if (stream == "stderr") {
            FileAppend, %msg%`r`n, **
        } else {
            this.stdLog("Invalid stream",,true)
        }
    }
}