// ============================================================================
//  Datei:       MTAS_Logger.mqh
//  Projekt:     MTAS v2.0
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Zentrales Logging-Modul. Schreibt in Konsole und optional in Logdatei.
//    Unterstuetzt Log-Level (ERROR, WARN, INFO, DEBUG).
//    Thread-sicher durch sequenzielle Ausfuehrung in MQL5.
//
//  Abhaengigkeiten: MTAS_Defines.mqh
// ============================================================================
#ifndef __MTAS_LOGGER_MQH
#define __MTAS_LOGGER_MQH

#include "MTAS_Defines.mqh"

// ---------- Konfiguration ---------------------------------------------------
// Wird durch Input-Parameter aus der Hauptdatei gesetzt.
static MTAS_LogLevel g_LogLevel     = LOG_INFO;
static bool          g_LogToFile    = true;
static string        g_LogFileName  = "MTAS_v2_log.txt";

// ---------- Konfiguration setzen --------------------------------------------
void MTAS_LogSetLevel(MTAS_LogLevel lvl)   { g_LogLevel   = lvl; }
void MTAS_LogSetFile(bool enable, string fname = "MTAS_v2_log.txt")
{
    g_LogToFile   = enable;
    g_LogFileName = fname;
}

// ---------- Kern-Logging-Funktion -------------------------------------------
void MTAS_Log(const string msg, MTAS_LogLevel lvl = LOG_INFO)
{
    if(lvl > g_LogLevel) return;   // Level-Filter

    string prefix;
    switch(lvl)
    {
        case LOG_ERROR: prefix = "[ERROR] "; break;
        case LOG_WARN:  prefix = "[WARN]  "; break;
        case LOG_INFO:  prefix = "[INFO]  "; break;
        case LOG_DEBUG: prefix = "[DEBUG] "; break;
        default:        prefix = "[?]     "; break;
    }

    string ts      = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
    string fullmsg = ts + " " + prefix + msg;

    Print(fullmsg);

    if(g_LogToFile)
    {
        int h = FileOpen(g_LogFileName, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_READ | FILE_SHARE_READ);
        if(h != INVALID_HANDLE)
        {
            FileSeek(h, 0, SEEK_END);
            FileWriteLine(h, fullmsg);
            FileClose(h);
        }
    }
}

// ---------- Kurzformen ------------------------------------------------------
void MTAS_LogError(const string msg)  { MTAS_Log(msg, LOG_ERROR); }
void MTAS_LogWarn(const string msg)   { MTAS_Log(msg, LOG_WARN);  }
void MTAS_LogInfo(const string msg)   { MTAS_Log(msg, LOG_INFO);  }
void MTAS_LogDebug(const string msg)  { MTAS_Log(msg, LOG_DEBUG); }

#endif // __MTAS_LOGGER_MQH
