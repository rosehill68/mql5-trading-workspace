// ============================================================================
//  Datei:       MTAS_Logger_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Beschreibung: Logging (Konsole & Datei), Severity
// ============================================================================

#ifndef __MTAS_LOGGER_V1_1_MQH
#define __MTAS_LOGGER_V1_1_MQH

enum MTAS_LogLevel { LOG_ERROR, LOG_INFO, LOG_DEBUG };

void MTAS_Log(const string msg, MTAS_LogLevel lvl=LOG_INFO)
{
    string prefix = (lvl==LOG_ERROR)?"[ERROR] ":(lvl==LOG_DEBUG)?"[DEBUG] ":"[INFO] ";
    Print(prefix + msg);

    // Optional: Logging in Datei "MTAS_log.txt"
    int handle = FileOpen("MTAS_log.txt", FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_READ);
    if(handle != INVALID_HANDLE)
    {
        FileSeek(handle, 0, SEEK_END);
        FileWrite(handle, TimeToString(TimeLocal(), TIME_SECONDS) + " " + prefix + msg);
        FileClose(handle);
    }
}

#endif // __MTAS_LOGGER_V1_1_MQH