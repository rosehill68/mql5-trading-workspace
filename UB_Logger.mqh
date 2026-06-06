//+------------------------------------------------------------------+
//|                                                                  |
//|  EA-Name    : THE UNBESTECHLICH EA                               |
//|  Datei      : UB_Logger.mqh                                      |
//|  Modul      : Protokollierungssystem (Journal + CSV-Datei)       |
//|  Version    : 5.2.1                                              |
//|  Datum      : 2026-06-04                                         |
//|                                                                  |
//|  Versionshistorie:                                               |
//|  v4.0 - Erstimplementierung mit Log-Levels und CSV-Ausgabe       |
//|  v4.1 - #pragma once durch MQL5-konforme Include-Guards ersetzt  |
//|          %I64u durch %llu ersetzt (korrekter MQL5 ulong-Specifier)|
//|          Alle Kommentare auf Deutsch                             |
//|          UB_Globals.mqh statt extern-Variablen                   |
//|  v5.2.1 - Versionsnummer aktualisiert                            |
//|                                                                  |
//|  Zweck:                                                          |
//|  Stellt zentrale Logging-Funktionen bereit. Jede Meldung wird    |
//|  im MT5-Journal mit dem Präfix [Skalpell-Core] ausgegeben.       |
//|  Optional werden alle Meldungen zusätzlich in eine datierte      |
//|  CSV-Datei im Ordner MQL5\Files\Unbestechlich\ geschrieben.      |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef UB_LOGGER_MQH
#define UB_LOGGER_MQH

#include "UB_Globals.mqh"

//+------------------------------------------------------------------+
//| Protokolldatei initialisieren                                    |
//|                                                                  |
//| Öffnet eine neue CSV-Datei mit dem aktuellen Datum im Dateinamen.|
//| Schreibt die Spaltenüberschriften als erste Zeile.               |
//|                                                                  |
//| Parameter:                                                       |
//|   enableFileLog - true: Zusätzlich in CSV-Datei schreiben        |
//|                   false: Nur MT5-Journal-Ausgabe (kein File)     |
//| Rückgabe: true bei Erfolg oder wenn File-Log deaktiviert         |
//|           false wenn Datei nicht geöffnet werden konnte          |
//|           (Betrieb läuft trotzdem weiter — nur kein CSV)         |
//+------------------------------------------------------------------+
bool Logger_Init(bool enableFileLog)
{
   // File-Logging deaktiviert: sofort zurückkehren
   if(!enableFileLog)
      return true;

   // Dateiname mit aktuellem Datum erstellen (Punkte → Bindestriche)
   string datePart = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(datePart, ".", "-");
   string filename = "Unbestechlich\\trades_" + datePart + ".csv";

   // Datei öffnen (erstellt neu oder überschreibt existierende)
   g_LogFileHandle = FileOpen(filename,
                              FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ,
                              ',');

   if(g_LogFileHandle == INVALID_HANDLE)
   {
      Print(EA_PREFIX, " [FEHLER] CSV-Protokolldatei konnte nicht geöffnet werden. "
            "Fehlercode: ", GetLastError(),
            " | Pfad: MQL5\\Files\\", filename);
      return false;
   }

   // Spaltenüberschriften schreiben
   FileWrite(g_LogFileHandle,
             "Zeitstempel",
             "Symbol",
             "Stufe",
             "Zustand",
             "Richtung",
             "Preis",
             "SL",
             "TP",
             "Lots",
             "Meldung");
   FileFlush(g_LogFileHandle);

   Print(EA_PREFIX, " CSV-Protokolldatei geöffnet: MQL5\\Files\\", filename);
   return true;
}

//+------------------------------------------------------------------+
//| Protokolldatei sauber schließen                                  |
//| Muss in OnDeinit() aufgerufen werden                             |
//+------------------------------------------------------------------+
void Logger_Deinit()
{
   if(g_LogFileHandle != INVALID_HANDLE)
   {
      FileClose(g_LogFileHandle);
      g_LogFileHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Kernfunktion: Meldung ausgeben                                   |
//|                                                                  |
//| Gibt eine formatierte Meldung ins MT5-Journal aus und optional   |
//| zusätzlich in die CSV-Protokolldatei.                            |
//|                                                                  |
//| Parameter:                                                       |
//|   level   - Schwere der Meldung (DEBUG/INFO/WARN/ERROR)          |
//|   symbol  - Betroffenes Handelssymbol (für Filterung im Journal) |
//|   message - Klartext der Meldung                                 |
//|   state   - Aktueller EA-Zustand (optional, Default: STATE_NONE) |
//|   price   - Preisreferenz in der Meldung (optional)              |
//|   sl      - Stop-Loss-Preis (optional)                           |
//|   tp      - Take-Profit-Preis (optional)                         |
//|   lots    - Lotzahl (optional)                                   |
//|   dir     - Handelsrichtung (optional)                           |
//+------------------------------------------------------------------+
void Log(ENUM_LOG_LEVEL     level,
         const string       symbol,
         const string       message,
         const ENUM_EA_STATE state  = STATE_NONE,
         const double       price   = 0.0,
         const double       sl      = 0.0,
         const double       tp      = 0.0,
         const double       lots    = 0.0,
         const ENUM_TRADE_DIR dir   = DIR_NONE)
{
   // Meldungen unterhalb des konfigurierten Log-Levels ignorieren
   if(level < g_GlobalLogLevel)
      return;

   // Level-Bezeichnung für die Ausgabe
   string levelStr;
   switch(level)
   {
      case LOG_DEBUG: levelStr = "DEBUG"; break;
      case LOG_INFO:  levelStr = "INFO "; break;
      case LOG_WARN:  levelStr = "WARN "; break;
      case LOG_ERROR: levelStr = "ERROR"; break;
      default:        levelStr = "?????"; break;
   }

   // Zustandsbezeichnung auf Deutsch
   string stateStr;
   switch(state)
   {
      case STATE_NONE:  stateStr = "WARTEN"; break;
      case STATE_TREND: stateStr = "TREND";  break;
      case STATE_TRAP:  stateStr = "TRAP";   break;
      default:          stateStr = "?";      break;
   }

   // Richtungsbezeichnung
   string dirStr;
   switch(dir)
   {
      case DIR_LONG:  dirStr = "LONG";  break;
      case DIR_SHORT: dirStr = "SHORT"; break;
      default:        dirStr = "---";   break;
   }

   // Formatierte Ausgabe ins MT5-Journal
   string fullMsg = StringFormat("%s [%s] [%s] [%s|%s] %s",
                                  EA_PREFIX, levelStr, symbol,
                                  stateStr, dirStr, message);
   Print(fullMsg);

   // Zusätzlich in CSV-Datei schreiben wenn File-Logging aktiv
   if(g_LogFileHandle != INVALID_HANDLE)
   {
      FileWrite(g_LogFileHandle,
                TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                symbol,
                levelStr,
                stateStr,
                dirStr,
                DoubleToString(price, 5),
                DoubleToString(sl,    5),
                DoubleToString(tp,    5),
                DoubleToString(lots,  4),
                message);
      FileFlush(g_LogFileHandle);
   }
}

//+------------------------------------------------------------------+
//| Kurzschreibweisen für häufig verwendete Log-Aufrufe              |
//| Reduzieren den Schreibaufwand im restlichen Code erheblich       |
//+------------------------------------------------------------------+

// Detaillierte Entwicklungsmeldung (nur sichtbar wenn LOG_DEBUG gesetzt)
#define LOG_D(sym, msg)  Log(LOG_DEBUG, sym, msg)

// Normalbetriebsmeldung (Trades, Zustandswechsel)
#define LOG_I(sym, msg)  Log(LOG_INFO,  sym, msg)

// Warnung (unerwarteter Zustand, aber kein Abbruch)
#define LOG_W(sym, msg)  Log(LOG_WARN,  sym, msg)

// Kritischer Fehler (Trade konnte nicht ausgeführt werden)
#define LOG_E(sym, msg)  Log(LOG_ERROR, sym, msg)

#endif // UB_LOGGER_MQH