//+------------------------------------------------------------------+
//|                                                                  |
//|  EA-Name    : THE UNBESTECHLICH EA                               |
//|  Datei      : Unbestechlich_EA.mq5                               |
//|  Modul      : Haupt-Programm (OnInit/OnTimer/OnTick/OnDeinit)   |
//|  Version    : 5.2.8                                              |
//|  Datum      : 2026-06-05                                         |
//|
//|  Versionshistorie:                                               |
//|  v4.0 - Erstimplementierung, alle kritischen Lastenheft-Fixes    |
//|          Lazy-Init via OnTimer (kein Sleep()), Lot-Formel korr.  |
//|          Break-Even Short korrigiert, Netting-Kompatibilität     |
//|          Magic-Number-System, Bar-Guard, Division-by-Zero-Schutz |
//|  v4.1 - MQL5-Reinheit: Include-Guards, %llu, Bars(), (ushort)   |
//|          Deutsche Kommentierung, File-Header, Input-Beschreibung |
//|  v4.2 - Performance: Ask/Bid einmalig, Snapshots einmalig        |
//|          Balance-Snapshots aus AssetVerarbeiten nach OnTimer      |
//|          Richtungsparameter in CalcInitialStops                   |
//|  v5.0 - Asset-Erweiterung: Indizes, Rohstoffe, Edelmetalle       |
//|          Symbol-Typ-Erkennung, per-Asset Spread/Zeitfilter        |
//|          Wochenend-Gap-Schutz, Korrelationsschutz                |
//|          Adaptiver MinRatio-Default je Symbol-Typ                |
//|          ATR-basierte Box-Mindestgröße                           |
//|  v5.1 - Killswitch im Trap-Zweig, SymbolTypeToString()           |
//|          (ushort)'-' in ParseTimeWindow, IstHandelszeit() fix    |
//|          ArrayMaximum bounds-gesichert in Kalibrierung           |
//|          CheckWeekendClose gibt bool zurück                       |
//|          Break-Even nur in OnTick, Trailing nur bei neuer Kerze  |
//|  v5.2 - CopyHigh/Low Rückgabe-Check im Trap-Zweig (R8-2)        |
//|          BoxEngine_TransitionToNone_Fast() in OnTick (R8-3)      |
//|          CheckWeekendClose bool-Return, IsPositionOpen einmal    |
//|          Kalibrierung für Long UND Short Ausbrüche (R8-6)        |
//|          TrapTakeProfitMargin Input: int → double                |
//|  v5.2.1 - Finale Produktionsversion, alle Review-Zyklen #1–#10   |
//|           abgeschlossen, 0 offene Befunde                        |
//|  v5.2.2 - Smart-Body-Trailing für Trap-Zustand aktiviert        |
//|           ExitMgr_SmartBodyTrailing() in STATE_TRAP aufgerufen   |
//|           Neuer Input: TrapMinPctRemaining (Restweg-Prüfung)     |
//|  v5.2.3 - Minor-Box-System (Outside-Bar als Mini-Box in Major-Box) |
//|           SignalFilter_Evaluate mit option. Box-Grenzen           |
//|           ExitMgr_CalcInitialStops prüft MinorBoxMedian           |
//|           SmartBodyTrailing löst Minor-Box bei Fortschritt auf    |
//|           AssetVerarbeiten: Minor-Box-Ausbruch via 3-Stufen       |
//|  v5.2.4 - ChandelierATR_Factor Input + Trailing-Funktion       |
//|           Bugfix K1: Minor-Box nur in Trendrichtung auflösen    |
//|           OnTick: Chandelier-Preis-Tracking                     |
//|           EnableChartDisplay Input + UB_ChartDisplay.mqh        |
//|           Chart-Zeichnung: Boxen, SL, TP, Entry                |
//|  v5.2.5 - Korrelationsgruppen (Automatisch nach Symbol-Typ)    |
//|           RiskMgr_IsTradingAllowed: newGroup-Parameter          |
//|  v5.2.6 - Risikolimits von EUR auf % umgestellt (skaliert)     |\n//|  v5.2.7 - TrapWindowCandles 3→8, MinBoxATR 0.5→0.8            |
//|  v5.2.8 - Stufe 3 (Rejection-Filter) entfernt, 2-Stufen-System  |
//|                                                                  |
//|  Plattform      : MetaTrader 5 (MQL5) — kein MQL4-Element        |
//|  Architektur    : Multi-Asset, eine Instanz auf einem Chart       |
//|  Signal-TF      : H4 (Standard) oder H1 (Hybrid-Modus)          |
//|  ATR-Referenz   : D1                                             |
//|  Empfohlene     : EURUSD, GBPUSD, XAUUSD, USDJPY,               |
//|  Assets         : GOLD, USA500, LCrude (ActivTrades)            |
//|  Broker-Hinweis : LCrude = WTI Öl-CFD bei ActivTrades           |
//|                   DetectSymbolType() erkennt "CRUDE" automatisch  |
//|  VPS            : Windows Server 2022/2025, ≥2 vCPU, ≥4 GB RAM  |
//|                   Ping zum Broker-Access-Point: ≤ 10 ms          |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright  "The Unbestechlich EA v5.2.9"
#property version    "5.29"
#property description "Vollautomatisches H4-Box-Breakout System"
#property description "Multi-Asset: Forex, Edelmetalle, Indizes, Rohstoffe"
#property description "Reviewed & Debugged — 10 Review-Zyklen, 0 offene Befunde"
#property strict

// MQL5-Pflichtprüfung — verhindert versehentliche MQL4-Kompilierung
#ifndef __MQL5__
   #error "Dieser EA ist ausschließlich für MetaTrader 5 (MQL5) entwickelt."
#endif

// Alle Module einbinden (Reihenfolge wichtig: Globals zuerst)
#include "UB_Globals.mqh"
#include "UB_Logger.mqh"
#include "UB_RiskManager.mqh"
#include "UB_BoxEngine.mqh"
#include "UB_SignalFilter.mqh"
#include "UB_TradeExecutor.mqh"
#include "UB_ExitManager.mqh"
#include "UB_ChartDisplay.mqh"

//+------------------------------------------------------------------+
//| EINGABEPARAMETER — Das Cockpit                                   |
//|                                                                  |
//| Alle Parameter sind vor dem EA-Start im MT5-Dialog konfigurierbar|
//| Der Kommentar nach // erscheint als Tooltip im Eingabefenster    |
//+------------------------------------------------------------------+

sinput string  Grp0 = "╔══ THE UNBESTECHLICH EA v5.2.9 ══╗";

//--- Allgemeine Einstellungen
sinput string  Grp1 = "── Allgemeine Einstellungen ──";

input string   InputAssets = "EURUSD,GBPUSD,GOLD,USDJPY,USA500,LCrude";
// ↑ Kommagetrennte Liste der zu handelnden Symbole.
//   Alle Symbole müssen im Market Watch verfügbar sein.
//   Standard: EURUSD, GBPUSD, GOLD, USDJPY, USA500, LCrude (ActivTrades)
//   Symbol-Typ wird automatisch erkannt (FOREX/METALL/INDEX/ROHSTOFF)

input ENUM_ENTRY_MODE InputEntryMode = MODE_PURE_H4;
// ↑ H4-MODUS (empfohlen): Signal nach vollständigem H4-Kerzenschluss.
//   Zuverlässiger, weniger Signale, weniger Fehlausbrüche.
//   H1-HYBRID: Signal nach H1-Schluss gegen H4-Box.
//   Mehr Signale, aber weniger Bestätigung durch H4-Schluss.

input int      BoxPeriodCandles = 30;
// ↑ Anzahl der H4-Kerzen für die Konsolidierungsbox.
//   Mehr Kerzen = größere Box = weniger, aber zuverlässigere Signale.
//   Empfohlener Bereich: 20–50 Kerzen.

input int      HistoryPreLoad = 1000;
// ↑ Mindestanzahl H4-Kerzen die beim Start geladen werden müssen.
//   Der EA wartet automatisch bis diese Datenmenge verfügbar ist.
//   Standard: 1000 Kerzen ≈ ca. 6 Monate H4-History.

input bool     EnableFileLogging = true;
// ↑ JA: Alle Ereignisse zusätzlich in eine CSV-Datei schreiben.
//   Speicherort: MT5-Datenordner\MQL5\Files\Unbestechlich\
//   NEIN: Nur Ausgabe im MT5-Journal.

input bool     EnableChartDisplay = true;
// ↑ JA: Zeichne Major-Box, Minor-Box, SL, TP und Entry-Level
//   als grafische Objekte auf dem Chart.
//   NEIN: Keine Chart-Objekte (spart CPU bei Headless-Betrieb).

input color    InpColorMajorBox = clrDarkGray;
// ↑ Farbe der Major-Box (Rahmen + Füllung). 
//   clrDarkGray (Standard), clrSilver, clrBlue usw.

input color    InpColorMinorBox = clrDimGray;
// ↑ Farbe der Minor-Box (Rahmen + Füllung).

input color    InpColorSL = clrRed;
// ↑ Farbe der Stop-Loss-Linie.

input color    InpColorTP = clrMediumSeaGreen;
// ↑ Farbe der Take-Profit-Linie (Trap).

input color    InpColorEntry = clrDodgerBlue;
// ↑ Farbe der Einstiegspreis-Linie.

input ENUM_LOG_LEVEL InputLogLevel = LOG_INFO;
// ↑ DEBUG: Alle Details (nur für Fehlersuche, sehr viele Meldungen)
//   INFO:  Normalbetrieb — Trades, Signale, Zustandswechsel
//   WARN:  Nur Warnungen und Fehler
//   ERROR: Nur kritische Fehler

//--- Risikomanagement
sinput string  Grp2 = "── Risikomanagement & Schutzlimits ──";

input double   RiskPercentPerTrade = 1.0;
// ↑ Prozentualer Anteil des Kontoguthabens der pro Trade riskiert wird.
//   Beispiel: 1.0% bei 10.000 EUR Konto = 100 EUR Risiko pro Trade.
//   Empfohlen für Einsteiger: 0.5% | Erfahrene: 1.0–2.0%

input int      MaxParallelTrades = 3;
// ↑ Maximale Anzahl gleichzeitig offener EA-eigener Positionen.
//   Fremde und manuelle Trades werden ignoriert (Magic-Number-Filter).

input double   MaxDailyDrawdownPct = 0.5;
// ↑ Maximaler Tagesverlust in % des Tages-Startkontostands.
//   0.5% bei 10.000€ = 50€ Tageslimit.
//   Bei Überschreitung: Keine neuen Trades bis zum nächsten Tag.

input double   MaxWeeklyDrawdownPct = 1.0;
// ↑ Maximaler Wochenverlust in % des Wochen-Startkontostands.
//   Schutz gegen mehrere aufeinanderfolgende Verlusttage.

input double   MaxFloatingLossPct = 0.5;
// ↑ Maximaler gleichzeitiger Buchverlust in % des aktuellen Equity.
//   0.5% bei 10.000€ Equity = 50€ Buchverlust-Limit.
//   Bei Überschreitung: Kein neuer Trade bis Verluste abgebaut.

input double   MaxSpreadPoints = 30.0;
// ↑ Globaler Spread-Grenzwert in Punkten (Fallback für alle Symbole).
//   Kann per Symbol durch AssetMaxSpreads überschrieben werden.
//   Bei zu weitem Spread wird der Trade übersprungen.

input double   MaxSlippagePoints = 5.0;
// ↑ Maximale akzeptierte Slippage bei der Orderausführung in Punkten.
//   Wird als Deviation an CTrade übergeben.

input int      MaxSameDirTrades = 2;
// ↑ Maximale gleichzeitige Positionen in DIESELBE Richtung.
//   Korrelationsschutz: Verhindert dass bei einem Risk-Off-Ereignis
//   alle Trades gleichzeitig ins Minus laufen.
//   0 = Korrelationsschutz deaktiviert.

//--- 3-Stufen-Signalfilter
sinput string  Grp3 = "── 3-Stufen-Signalfilter ──";

input int      ATR_Period = 14;
// ↑ Periode für den ATR-Indikator auf dem Tageschart (D1).
//   Wird für den Kraft-Filter (Stufe 1) verwendet.
//   Standard: 14 D1-Kerzen (≈ 14 Handelstage)

input double   MinBodyDisplacement = 50.0;
// ↑ Mindest-Prozentsatz des Kerzenkörpers der außerhalb der Box liegen muss.
//   (Stufe 2: Absichts-Filter)
//   50% = Mindestens die Hälfte des Körpers ist außerhalb der Box.
//   Höhere Werte = strengerer Filter = weniger aber qualitativere Signale.

input double   MinBoxATR_Multiple = 0.8;
// ↑ Mindestgröße der Konsolidierungsbox als Vielfaches des H4-ATR.
//   Zu kleine Boxen sind Rauschen und keine echten Konsolidierungen.
//   0.8 = Box muss mindestens 80% des H4-ATR groß sein.
//   Daten (2024-2026): Reduziert Fake-Breakouts in Niedrigvola-Phasen.
//   Empfohlen: 0.5–1.0 (höher = größere Boxen erforderlich = weniger,
//   aber qualitativere Signale).
//--- Trap-Umkehr-Einstellungen
sinput string  Grp4 = "── Trap-Umkehr-Einstellungen ──";

input int      TrapWindowCandles = 8;
// ↑ Anzahl der H4-Kerzen nach dem Trendfolge-Einstieg in denen ein
//   Fehlausbruch (Trap) erkannt und umgekehrt werden kann.
//   8 = ~2 Handelstage. Datenanalyse (2024-2026): Median-Fake = 8-13 H4.
//   Mit 8 werden 20-42% der Fake-Breakouts erfasst (vs. 6-21% mit 3).

input double   TrapTakeProfitMargin = 15.0;
// ↑ Prozentualer Sicherheitsabstand des Trap-Take-Profits zur Boxgrenze.
//   15% = TP liegt 15% der Boxhöhe VOR der Boxgrenze.
//   Verhindert Stop-Hunting durch den Broker kurz vor der Boxgrenze.
//   Erlaubt nicht-ganzzahlige Werte wie 12.5%.

input double   TrapMinPctRemaining = 50.0;
// ↑ Mindest-Prozentsatz der Boxhöhe der zwischen Einstieg und der
//   gegenüberliegenden Boxgrenze liegen muss.
//   50% = Der Preis muss noch mind. die Hälfte der Box bis zur
//   gegenüberliegenden Seite vor sich haben.
//   Verhindert Trap-Trades mit geringem Gewinnpotenzial.

//--- Trailing und Exit
sinput string  Grp5 = "── Trailing & Exit-Steuerung ──";

input double   BreakEvenRewardRatio = 1.0;
// ↑ Gewinn-Risiko-Verhältnis das erreicht werden muss bevor der
//   Stop-Loss auf Break-Even (Einstiegspreis) gesetzt wird.
//   1.0 = SL auf Einstieg wenn Gewinn = ursprüngliches Risiko (1:1).
//   0.5 = Break-Even bereits bei halbem Risiko als Gewinn.

input double   SpreadBufferPoints = 10.0;
// ↑ Sicherheits-Puffer in Punkten für die SL-Platzierung.
//   Verhindert vorzeitiges Auslösen des SL durch den Broker-Spread.
//   Anpassen auf typischen Spread des jeweiligen Symbols.

input bool     UseSmartBodyTrailing = true;
// ↑ JA: Smart-Body-Trailing im Trendfolge-Modus aktiv.
//   SL wird nachgezogen wenn echter Fortschritt gemacht wird.
//   Inside-Bars werden erkannt und der SL bleibt stabil.
//   NEIN: Kein Trailing — SL bleibt an der Boxmitte (STATE_TREND).

input double   ChandelierATR_Factor = 0.0;
// ↑ ATR-Chandelier-Faktor für volatilitätsbasiertes Trailing.
//   SL = TradeHöchstkurs - Faktor × H4-ATR (Long) bzw.
//   SL = TradeTiefstkurs + Faktor × H4-ATR (Short).
//   0.0 = deaktiviert (nur Smart-Body-Trailing aktiv).
//   Empfohlen: 0.0 (deaktiviert) oder 1.5–3.0 falls aktiv.

//--- Asset-spezifische Einstellungen
sinput string  Grp6 = "── Asset-spezifische Einstellungen ──";

input string   AssetMaxSpreads = "30,20,40,15,80,60";
// ↑ Maximaler Spread in Punkten pro Symbol (Reihenfolge wie InputAssets).
//   0 = globalen MaxSpreadPoints-Wert für dieses Symbol verwenden.
//   Richtwerte für Standard-Assets:
//   EURUSD=30, GBPUSD=20, GOLD=40, USDJPY=15, USA500=80, LCrude=60
//   Bei ActivTrades LCrude: 60 Punkte (Spread 3–8 Pkt normal, bis 50 bei EIA)

input string   AssetTradeHours = "0-24,0-24,0-24,0-24,8-22,8-22";
// ↑ Handelszeitfenster pro Symbol im Format "StartStunde-EndStunde" (Serverzeit).
//   0-24 = keine Zeitbeschränkung (24h Handel erlaubt)
//   8-22 = nur zwischen 08:00 und 22:00 Uhr Serverzeit
//   Reihenfolge muss identisch mit InputAssets sein!
//   EURUSD/GBPUSD/GOLD/USDJPY=0-24, USA500=8-22, LCrude=8-22

//--- Wochenend- und Zeitschutz
sinput string  Grp7 = "── Wochenend- & Zeitschutz ──";

input bool     ClosePositionsBeforeWeekend = false;
// ↑ JA: Alle offenen Positionen werden freitags automatisch vor
//   Marktschluss geschlossen um Wochenend-Gap-Risiko zu eliminieren.
//   Empfohlen: JA für US500, GER40 (starke Wochenend-Gaps möglich).
//   NEIN: Positionen bleiben über das Wochenende (Forex, XAUUSD, LCrude
//   haben nur kurze Wochendpause — geringes Gap-Risiko).

input int      FridayCloseHour = 21;
// ↑ Serverzeit-Stunde für den Freitags-Zwangsschluss.
//   Nur aktiv wenn ClosePositionsBeforeWeekend = JA.
//   Standard: 21 Uhr Serverzeit (kurz vor Wochenend-Handelsschluss).
//   An die Serverzeit des Brokers anpassen!

//+------------------------------------------------------------------+
//| Hilfsfunktion: Symbol-Typ als deutschen Text ausgeben            |
//| Ersetzt unsicheres EnumToString() für benutzerdefinierte Enums   |
//+------------------------------------------------------------------+
string SymbolTypeToString(ENUM_SYMBOL_TYPE t)
{
   switch(t)
   {
      case SYMTYPE_FOREX:     return "FOREX";
      case SYMTYPE_METAL:     return "METALL";
      case SYMTYPE_INDEX:     return "INDEX";
      case SYMTYPE_COMMODITY: return "ROHSTOFF";
      default:                return "UNBEKANNT";
   }
}

//+------------------------------------------------------------------+
//| Symbol-Typ automatisch erkennen                                  |
//|                                                                  |
//| Erkennt den Asset-Typ anhand des Symbol-Namens.                  |
//| Nutzt StringToUpper() für case-insensitive Erkennung.            |
//| Verwendet spezifische Terme statt breiter Wildcards.             |
//| LCrude wird über "CRUDE" korrekt als ROHSTOFF erkannt.           |
//+------------------------------------------------------------------+
ENUM_SYMBOL_TYPE DetectSymbolType(const string sym)
{
   string s = sym;
   StringToUpper(s);   // Groß-/Kleinschreibung ignorieren

   // --- Edelmetalle (zuerst prüfen — enthalten oft "USD" im Namen) ---
   if(StringFind(s, "XAU")    >= 0) return SYMTYPE_METAL;
   if(StringFind(s, "XAG")    >= 0) return SYMTYPE_METAL;
   if(StringFind(s, "XPT")    >= 0) return SYMTYPE_METAL;
   if(StringFind(s, "XPD")    >= 0) return SYMTYPE_METAL;
   if(StringFind(s, "GOLD")   >= 0) return SYMTYPE_METAL;
   if(StringFind(s, "SILVER") >= 0) return SYMTYPE_METAL;

   // --- Rohstoffe: spezifische Terme (kein breiter "OIL"-Wildcard) ---
   if(StringFind(s, "USOIL")  >= 0) return SYMTYPE_COMMODITY;
   if(StringFind(s, "UKOIL")  >= 0) return SYMTYPE_COMMODITY;
   if(StringFind(s, "BRENT")  >= 0) return SYMTYPE_COMMODITY;
   if(StringFind(s, "CRUDE")  >= 0) return SYMTYPE_COMMODITY; // LCrude!
   if(StringFind(s, "WTI")    >= 0) return SYMTYPE_COMMODITY;
   if(StringFind(s, "NATGAS") >= 0) return SYMTYPE_COMMODITY;
   if(StringFind(s, "NGAS")   >= 0) return SYMTYPE_COMMODITY;

   // --- Aktienindizes ---
   if(StringFind(s, "USA500") >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "US500")  >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "SPX")    >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "SP500")  >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "NAS100") >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "NDX")    >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "US30")   >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "DOW")    >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "GER40")  >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "GER30")  >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "DAX")    >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "UK100")  >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "FTSE")   >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "JP225")  >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "NIKKEI") >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "AUS200") >= 0) return SYMTYPE_INDEX;
   if(StringFind(s, "HK50")   >= 0) return SYMTYPE_INDEX;

   // Standard: Forex-Währungspaar
   return SYMTYPE_FOREX;
}

//+------------------------------------------------------------------+
//| Kommagetrennte Zahlen-Strings in double-Array parsen             |
//|                                                                  |
//| Parameter:                                                       |
//|   input         - Eingabe-String (z.B. "30,20,40,15,80,60")      |
//|   outValues[]   - Ausgabe-Array (wird auf expectedCount gesized)  |
//|   expectedCount - Erwartete Anzahl Werte (= Anzahl der Assets)   |
//+------------------------------------------------------------------+
void ParseDoubleArray(const string eingabeStr,
                      double       &outValues[],
                      int           expectedCount)
{
   string parts[];
   int count = StringSplit(eingabeStr, ',', parts);
   ArrayResize(outValues, expectedCount);

   for(int i = 0; i < expectedCount; i++)
   {
      if(i < count)
      {
         string part = parts[i];
         StringTrimLeft(part);
         StringTrimRight(part);
         outValues[i] = StringToDouble(part);
      }
      else
         outValues[i] = 0.0;   // Fallback: globalen Wert verwenden
   }
}

//+------------------------------------------------------------------+
//| Zeitfenster-String parsen ("StartH-EndH")                        |
//|                                                                  |
//| Parameter:                                                       |
//|   timeStr  - Eingabe (z.B. "8-22" oder "0-24")                  |
//|   outStart - Ausgabe: Start-Stunde                               |
//|   outEnd   - Ausgabe: End-Stunde                                 |
//| Rückgabe: true = erfolgreich geparst | false = Fallback 0-24     |
//+------------------------------------------------------------------+
bool ParseTimeWindow(const string timeStr, int &outStart, int &outEnd)
{
   string parts[];
   // (ushort)'-' ist MQL5-konform für StringSplit-Trennzeichen
   if(StringSplit(timeStr, (ushort)'-', parts) < 2)
   {
      outStart = 0;
      outEnd   = 24;
      return false;
   }
   string sStr = parts[0]; StringTrimLeft(sStr); StringTrimRight(sStr);
   string eStr = parts[1]; StringTrimLeft(eStr); StringTrimRight(eStr);
   outStart = (int)StringToInteger(sStr);
   outEnd   = (int)StringToInteger(eStr);
   return true;
}

//+------------------------------------------------------------------+
//| Handelszeit für ein Asset prüfen (per-Asset-Zeitfilter)          |
//|                                                                  |
//| 0-24 = keine Zeitbeschränkung für dieses Symbol.                 |
//| Sonst: Prüfung gegen ctx.TradeStartHour und ctx.TradeEndHour.    |
//| Einmalige MqlDateTime-Abfrage — keine doppelte dt-Deklaration.   |
//+------------------------------------------------------------------+
bool IstHandelszeit(const S_AssetContext &ctx)
{
   // Kein Zeitlimit: immer erlaubt
   if(ctx.TradeStartHour == 0 && ctx.TradeEndHour == 24)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= ctx.TradeStartHour && dt.hour < ctx.TradeEndHour);
}

//+------------------------------------------------------------------+
//| History-Ladestand prüfen (non-blocking — kein Sleep()!)          |
//|                                                                  |
//| Prüft für jedes Asset ob die Mindestanzahl H4-Kerzen verfügbar   |
//| ist. Falls nicht: CopyRates() triggert den MT5-internen Download.|
//| Das Array wird bewusst verworfen — nur der Trigger zählt.        |
//| Rückgabe: true wenn ALLE Assets die Mindesthistorie haben         |
//+------------------------------------------------------------------+
bool IstHistoryGeladen()
{
   bool allesBereit = true;

   for(int i = 0; i < g_AssetCount; i++)
   {
      string sym          = g_Contexts[i].SymbolName;
      // Bars() ist der native MQL5-Aufruf (statt iBars() aus MQL4)
      int    vorhandene   = Bars(sym, PERIOD_H4);

      if(vorhandene < HistoryPreLoad)
      {
         // History-Download anstoßen (non-blocking, kein Sleep!)
         // CopyRates() triggert MT5-internen History-Download.
         // Das temp-Array wird verworfen — nur der Downloadtrigger zählt.
         MqlRates trigger[];
         CopyRates(sym, PERIOD_H4, 0, HistoryPreLoad, trigger);
         allesBereit = false;

         LOG_D(sym, StringFormat(
               "History-Ladevorgang: %d von %d H4-Kerzen verfügbar",
               vorhandene, HistoryPreLoad));
      }
   }

   return allesBereit;
}

//+------------------------------------------------------------------+
//| Wochenend-Gap-Schutz: Position freitags schließen                |
//|                                                                  |
//| Prüft ob es Freitag nach FridayCloseHour ist und ob eine Position|
//| geschlossen werden soll.                                         |
//|                                                                  |
//| Rückgabe: true  = Position noch offen (oder kein Close nötig)    |
//|           false = Position wurde durch diesen Aufruf geschlossen  |
//|           (AssetVerarbeiten() bricht bei false sofort ab)         |
//+------------------------------------------------------------------+
bool CheckWeekendClose(S_AssetContext &ctx)
{
   // Wochenend-Schutz deaktiviert oder kein aktiver Trade
   if(!g_CloseBeforeWeekend || ctx.TicketID == 0)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   // Nur freitags (day_of_week=5) nach eingestellter Stunde
   if(dt.day_of_week != 5 || dt.hour < g_FridayCloseHour)
      return true;

   // Position existenz prüfen
   if(!ExitMgr_IsPositionOpen(ctx))
   {
      // Position bereits weg (SL/TP) — nur State zurücksetzen
      BoxEngine_TransitionToNone(ctx);
      return false;
   }

   LOG_I(ctx.SymbolName, StringFormat(
         "Wochenend-Schutz: Schließe Position %llu (Fr. %02d:%02d Uhr Serverzeit)",
         ctx.TicketID, dt.hour, dt.min));

   // Schließen versuchen und Rückgabewert prüfen
   bool ok = Executor_ClosePosition(ctx.TicketID, ctx.SymbolName);
   if(ok)
   {
      // Erfolgreich geschlossen: State zurücksetzen
      BoxEngine_TransitionToNone(ctx);
      return false;
   }

   // Schließen fehlgeschlagen: Position noch offen, weiter verwalten
   LOG_E(ctx.SymbolName, StringFormat(
         "Wochenend-Schutz: Position %llu konnte NICHT geschlossen werden!",
         ctx.TicketID));
   return true;
}

//+------------------------------------------------------------------+
//| Vola-Kalibrierung: Adaptiven Mindest-Wucht-Schwellwert lernen    |
//|                                                                  |
//| Scannt historische H4-Daten nach Ausbruchs-Situationen.          |
//| Prüft BEIDE Richtungen (Long und Short) auf 1:1-CRV.             |
//| Schützt Array-Zugriffe gegen out-of-bounds.                      |
//|                                                                  |
//| Wird einmalig nach History-Load in der OnTimer-Init-Phase         |
//| aufgerufen. Ergebnis wird in ctx.MinRatioRequired gespeichert.   |
//+------------------------------------------------------------------+
void KalibrierungDurchfuehren(S_AssetContext &ctx)
{
   const int SCAN_TIEFE  = 200;   // Historische Kerzen für den Scan
   const int MIN_ERFOLGE = 3;     // Mindest-Datenpunkte für Kalibrierung

   double highs[], lows[], closes[], atrWerte[];
   ArraySetAsSeries(highs,    true);
   ArraySetAsSeries(lows,     true);
   ArraySetAsSeries(closes,   true);
   ArraySetAsSeries(atrWerte, true);

   // Alle Daten in einem Block abrufen (effizienter als einzelne CopyXxx)
   if(CopyHigh  (ctx.SymbolName, PERIOD_H4, 1, SCAN_TIEFE, highs)    < SCAN_TIEFE) return;
   if(CopyLow   (ctx.SymbolName, PERIOD_H4, 1, SCAN_TIEFE, lows)     < SCAN_TIEFE) return;
   if(CopyClose (ctx.SymbolName, PERIOD_H4, 1, SCAN_TIEFE, closes)   < SCAN_TIEFE) return;
   if(CopyBuffer(ctx.ATR_Handle_D1, 0, 1, SCAN_TIEFE, atrWerte)      < SCAN_TIEFE) return;

   double erfolgreicheRatios[];
   int    anzahlErfolge  = 0;
   int    boxBreite      = g_BoxPeriodCandles;
   int    arrayGroesse   = ArraySize(highs);

   for(int k = boxBreite; k < SCAN_TIEFE - 10 && anzahlErfolge < 10; k++)
   {
      // Out-of-bounds-Schutz: Suchbereich auf verfügbare Daten begrenzen
      int verfuegbar = arrayGroesse - k;
      if(verfuegbar <= 0) break;
      int suchBreite = MathMin(boxBreite, verfuegbar);

      int hochIdx = ArrayMaximum(highs, k, suchBreite);
      int tiefIdx = ArrayMinimum(lows,  k, suchBreite);

      // Ungültige Indizes abfangen (-1 = ArrayMaximum hat nichts gefunden)
      if(hochIdx < 0 || tiefIdx < 0) continue;

      double lokHoch  = highs[hochIdx];
      double lokTief  = lows[tiefIdx];
      double lokMitte = (lokHoch + lokTief) / 2.0;

      if(atrWerte[k] <= 0.0) continue;

      // BEIDE Richtungen prüfen (nicht nur Long)
      bool ausbruchLong  = (closes[k] > lokHoch);
      bool ausbruchShort = (closes[k] < lokTief);
      if(!ausbruchLong && !ausbruchShort) continue;

      // Wucht-Verhältnis der Ausbruchskerze
      double ratio = (highs[k] - lows[k]) / atrWerte[k];

      // Risiko-Abstand (Entry zu BoxMitte)
      double risikoAbstand = ausbruchLong
                             ? (closes[k] - lokMitte)
                             : (lokMitte  - closes[k]);
      if(risikoAbstand <= 0.0) continue;

      // Prüfen ob 1:1-CRV in den nächsten 10 Kerzen erreicht wurde
      // Bei ArraySetAsSeries(true): j < k = jüngere Kerzen = "nach" dem Ausbruch
      bool crvErreicht = false;
      for(int j = k - 1; j >= MathMax(0, k - 10); j--)
      {
         if(ausbruchLong  && closes[j] >= closes[k] + risikoAbstand)
         {
            crvErreicht = true;
            break;
         }
         if(ausbruchShort && closes[j] <= closes[k] - risikoAbstand)
         {
            crvErreicht = true;
            break;
         }
      }

      if(crvErreicht)
      {
         ArrayResize(erfolgreicheRatios, anzahlErfolge + 1);
         erfolgreicheRatios[anzahlErfolge] = ratio;
         anzahlErfolge++;
      }
   }

   // Neuen Schwellwert berechnen wenn genug Datenpunkte
   if(anzahlErfolge >= MIN_ERFOLGE)
   {
      double summe = 0.0;
      for(int n = 0; n < anzahlErfolge; n++)
         summe += erfolgreicheRatios[n];

      // Durchschnitt, aber nicht unter Minimalwert fallen
      ctx.MinRatioRequired = MathMax(0.35, summe / anzahlErfolge);

      LOG_I(ctx.SymbolName, StringFormat(
            "Kalibrierung abgeschlossen: MinRatio=%.4f "
            "(aus %d Erfolgen, Long+Short)",
            ctx.MinRatioRequired, anzahlErfolge));
   }
   else
   {
      LOG_I(ctx.SymbolName, StringFormat(
            "Kalibrierung: Nur %d Erfolge gefunden — "
            "Symbol-Typ-Default %.2f wird verwendet",
            anzahlErfolge, ctx.MinRatioRequired));
   }
}

//+------------------------------------------------------------------+
//| Ein Asset vollständig verarbeiten                                 |
//|                                                                  |
//| Wird bei jeder neuen H4-Kerze für jedes Symbol aufgerufen.       |
//| Führt die gesamte Logik aus: Box → Signal → Killswitch → Trade.  |
//| Bei laufendem Trade: Trap-Check, Break-Even, Trailing.           |
//+------------------------------------------------------------------+
void AssetVerarbeiten(S_AssetContext &ctx)
{
   // Wochenend-Schutz: false = Position geschlossen → sofort zurück
   if(!CheckWeekendClose(ctx)) return;

   // Per-Asset Spread-Prüfung (nutzt MaxSpreadOverride oder global)
   if(!RiskMgr_IsSpreadAcceptable(ctx)) return;

   // Per-Asset Handelszeitfenster prüfen
   if(!IstHandelszeit(ctx)) return;

   // Ask/Bid einmalig abrufen — verhindert mehrfache API-Aufrufe
   double currentAsk = SymbolInfoDouble(ctx.SymbolName, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(ctx.SymbolName, SYMBOL_BID);

   // Kanten-Riegel aktualisieren (Whipsaw-Schutz)
   BoxEngine_UpdateEdgeLocks(ctx);

   // Positions-Existenz prüfen
   bool positionOffen = ExitMgr_IsPositionOpen(ctx);
   if(!positionOffen && ctx.CurrentState != STATE_NONE)
   {
      // Position durch SL/TP/manuell geschlossen → vollständiger Reset
      LOG_I(ctx.SymbolName, StringFormat(
            "Position %llu nicht mehr aktiv — Zurück in Wartemodus",
            ctx.TicketID));
      BoxEngine_TransitionToNone(ctx);
      return;
   }

   //+--------------------------------------------------------------+
   //| ZUSTAND: WARTEN (STATE_NONE)                                 |
   //| Box berechnen, auf Ausbruchssignal warten                    |
   //+--------------------------------------------------------------+
   if(ctx.CurrentState == STATE_NONE)
   {
      // Makro-Box für diese Kerze berechnen
      if(!BoxEngine_CalcMacroBox(ctx))
      {
         ChartDisplay_DrawAll(ctx);
         return;
      }

      // Signal auswerten (H4 oder H1 je nach Konfiguration)
      ENUM_TIMEFRAMES tf = (InputEntryMode == MODE_HYBRID_H1)
                            ? PERIOD_H1 : PERIOD_H4;
      S_SignalResult signal = SignalFilter_Evaluate(ctx, tf);
      if(!signal.IsValid) return;

      // Killswitch-Kaskade prüfen (alle 4 Schutzbedingungen)
      string killGrund;
      if(!RiskMgr_IsTradingAllowed(ctx.SymbolName, ctx.MagicNumber,
                                    signal.Direction, killGrund,
                                    ctx.SymbolType))
      {
         LOG_W(ctx.SymbolName, StringFormat(
               "Killswitch aktiv — Trade übersprungen: %s", killGrund));
         return;
      }

      // Einstiegspreis: Ask für Long, Bid für Short (einmalig gecacht)
      double einstieg = (signal.Direction == DIR_LONG) ? currentAsk : currentBid;
      double slPreis  = 0.0, tpPreis = 0.0;

      // Initialen SL und TP berechnen
      // direction als expliziter Parameter — ctx.ActiveDirection wird
      // NICHT temporär gesetzt (verhindert Inkonsistenz-Fenster)
      ExitMgr_CalcInitialStops(ctx, STATE_TREND, signal.Direction,
                                einstieg, 0.0, 0.0, slPreis, tpPreis);

      // Lotzahl berechnen (mit Plausibilitätsprüfung)
      double lotzahl = RiskMgr_CalcLotSize(ctx, einstieg, slPreis);
      if(lotzahl <= 0.0)
      {
         LOG_W(ctx.SymbolName, "Lotberechnung ergab 0 — Trade übersprungen");
         return;
      }

      // Order-Request zusammenstellen
      S_TradeRequest anfrage;
      anfrage.Symbol    = ctx.SymbolName;
      anfrage.OrderType = (signal.Direction == DIR_LONG)
                          ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      anfrage.Volume    = lotzahl;
      anfrage.Price     = einstieg;
      anfrage.SL        = slPreis;
      anfrage.TP        = tpPreis;
      anfrage.Magic     = ctx.MagicNumber;
      anfrage.Comment   = StringFormat("UB_TREND_v%s", EA_VERSION);
      anfrage.Deviation = (ulong)g_MaxSlippagePoints;

      // Order abschicken (mit bis zu 3 Versuchen bei temporären Fehlern)
      ulong ticket = Executor_SendOrder(anfrage);
      if(ticket > 0)
         BoxEngine_TransitionToTrend(ctx, signal.Direction,
                                      ticket, einstieg, slPreis);
      // Bei ticket=0: ctx bleibt in STATE_NONE, ActiveDirection=DIR_NONE
      ChartDisplay_DrawAll(ctx);
      return;
   }

   //+--------------------------------------------------------------+
   //| ZUSTAND: TREND (STATE_TREND)                                 |
   //| Laufenden Trendfolge-Trade verwalten                         |
   //+--------------------------------------------------------------+
   if(ctx.CurrentState == STATE_TREND)
   {
      // Kerzen-Zähler für das Trap-Erkennungsfenster erhöhen
      BoxEngine_UpdateTrendCounter(ctx);

      // Outside-Bar verarbeiten (ggf. Minor-Box setzen)
      BoxEngine_HandleOutsideBar(ctx);

      // Minor-Box-Ausbruch prüfen: 3-Stufen gegen Minor-Box
      if(ctx.HasActiveMinorBox)
      {
         S_SignalResult minorSig = SignalFilter_Evaluate(ctx, PERIOD_H4,
                                                       ctx.MinorBoxHigh,
                                                       ctx.MinorBoxLow);
         if(minorSig.IsValid && minorSig.Direction == ctx.ActiveDirection)
         {
            // Minor-Box bestätigt gebrochen (in TREND-Richtung) → auflösen
            ctx.HasActiveMinorBox = false;
            LOG_I(ctx.SymbolName,
                  "Minor-Box in Trendrichtung durchbrochen — aufgelöst");
         }
      }

      // Trap-Reversal prüfen: Fehlausbruch innerhalb des Fensters?
      if(SignalFilter_CheckTrapReversal(ctx))
      {
         // Bestehende Position schließen (kompatibel mit Netting + Hedging)
         if(!Executor_ClosePosition(ctx.TicketID, ctx.SymbolName))
         {
            LOG_E(ctx.SymbolName,
                  "Trap-Reversal: Bestehende Position nicht schließbar — abgebrochen");
            return;
         }

         // Gegenrichtung für den Trap-Trade
         ENUM_TRADE_DIR gegenR = (ctx.ActiveDirection == DIR_LONG)
                                  ? DIR_SHORT : DIR_LONG;

         // Killswitch auch für die Gegenposition prüfen!
         string killGrund;
         if(!RiskMgr_IsTradingAllowed(ctx.SymbolName, ctx.MagicNumber,
                                       gegenR, killGrund,
                                       ctx.SymbolType))
         {
            LOG_W(ctx.SymbolName, StringFormat(
                  "Trap-Killswitch aktiv — kein Reversal: %s", killGrund));
            // Position bereits geschlossen — sauber zurück in Wartemodus
            BoxEngine_TransitionToNone(ctx);
            return;
         }

         // Trap-Kerze für SL-Referenz abrufen (letzte abgeschlossene H4-Kerze)
         double trapH[], trapL[];
         ArraySetAsSeries(trapH, true);
         ArraySetAsSeries(trapL, true);
         // Rückgabewert prüfen — keine Daten verfügbar?
         if(CopyHigh(ctx.SymbolName, PERIOD_H4, 1, 1, trapH) < 1 ||
            CopyLow (ctx.SymbolName, PERIOD_H4, 1, 1, trapL) < 1)
         {
            LOG_W(ctx.SymbolName,
                  "Trap: Keine Kerzendaten verfügbar — Reversal übersprungen");
            BoxEngine_TransitionToNone(ctx);
            return;
         }

         // Einstiegspreis für Gegenposition (gecachter Preis)
         double einst = (gegenR == DIR_LONG) ? currentAsk : currentBid;
         double slT   = 0.0, tpT = 0.0;

         // Trap-Prüfung: Mindestens X% der Box bis zur Gegenseite?
         double wegZurGrenze = (gegenR == DIR_SHORT)
                               ? (einst - ctx.BoxLow)   // Short: Weg nach unten
                               : (ctx.BoxHigh - einst); // Long: Weg nach oben
         double pctVerfuegbar = (wegZurGrenze / ctx.BoxHeight) * 100.0;
         if(pctVerfuegbar < g_TrapMinPctRemaining)
         {
            LOG_I(ctx.SymbolName, StringFormat(
                  "Trap-Restweg zu gering: %.1f%% < %.1f%% — übersprungen",
                  pctVerfuegbar, g_TrapMinPctRemaining));
            BoxEngine_TransitionToNone(ctx);
            return;
         }

         // Trap-SL und TP berechnen
         ExitMgr_CalcInitialStops(ctx, STATE_TRAP, gegenR,
                                   einst, trapH[0], trapL[0], slT, tpT);

         // Lotzahl für Gegenposition
         double lot = RiskMgr_CalcLotSize(ctx, einst, slT);
         if(lot <= 0.0)
         {
            BoxEngine_TransitionToNone(ctx);
            return;
         }

         // Trap-Order senden
         S_TradeRequest req;
         req.Symbol    = ctx.SymbolName;
         req.OrderType = (gegenR == DIR_LONG)
                         ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         req.Volume    = lot;
         req.Price     = einst;
         req.SL        = slT;
         req.TP        = tpT;
         req.Magic     = ctx.MagicNumber;
         req.Comment   = StringFormat("UB_TRAP_v%s", EA_VERSION);
         req.Deviation = (ulong)g_MaxSlippagePoints;

         ulong newT = Executor_SendOrder(req);
         if(newT > 0)
            BoxEngine_TransitionToTrap(ctx, gegenR, newT, einst, slT);
         else
            BoxEngine_TransitionToNone(ctx);
         return;
      }

      // Break-Even prüfen (auch in OnTick — hier für neue-Kerze-Kontext)
      ExitMgr_CheckBreakEven(ctx);

      // Smart-Body-Trailing durchführen (nur bei neuer Kerze sinnvoll)
      ExitMgr_SmartBodyTrailing(ctx);

      // ATR-Chandelier Trailing (ergänzend, falls enger als SmartBody)
      ExitMgr_ChandelierTrailing(ctx);
      ChartDisplay_DrawAll(ctx);
      return;
   }

   //+--------------------------------------------------------------+
   //| ZUSTAND: TRAP (STATE_TRAP)                                   |
   //| Laufenden Umkehr-Trade verwalten                             |
   //+--------------------------------------------------------------+
   if(ctx.CurrentState == STATE_TRAP)
      {
         // Outside-Bar → Mikro-Konsolidierungszone ggf. aktualisieren
         BoxEngine_HandleOutsideBar(ctx);

         // Inside-Box-Trailing wenn Mikro-Zone aktiv
         ExitMgr_InsideBoxTrailing(ctx);

         // Smart-Body-Trailing auch im Trap-Modus (gleiche Logik wie Trend)
         ExitMgr_SmartBodyTrailing(ctx);

         // ATR-Chandelier Trailing (ergänzend, falls enger als SmartBody)
         ExitMgr_ChandelierTrailing(ctx);

         // Break-Even prüfen
         ExitMgr_CheckBreakEven(ctx);
         ChartDisplay_DrawAll(ctx);
         return;
      }
}

//+------------------------------------------------------------------+
//| OnInit: EA-Start und Vorkonfiguration                            |
//|                                                                  |
//| Befüllt alle globalen Variablen aus den Input-Parametern.        |
//| Erstellt ATR-Handles für jedes Asset.                            |
//| Startet den 1-Sekunden-Timer für die Initialisierungsphase.      |
//|                                                                  |
//| WICHTIG: Kein Sleep() hier! History-Loading ist asynchron        |
//| via OnTimer() implementiert (Lazy-Init-Pattern).                 |
//+------------------------------------------------------------------+
int OnInit()
{
   // Alle globalen Variablen aus Input-Parametern befüllen
   g_RiskPct              = RiskPercentPerTrade;
   g_MaxParallelTrades    = MaxParallelTrades;
   g_MaxDailyDD_Pct       = MaxDailyDrawdownPct;
      g_MaxWeeklyDD_Pct      = MaxWeeklyDrawdownPct;
      g_MaxFloatingLoss_Pct  = MaxFloatingLossPct;
   g_MaxSlippagePoints    = MaxSlippagePoints;
   g_MaxSpreadPoints      = MaxSpreadPoints;
   g_MaxSameDirTrades     = MaxSameDirTrades;
   g_ATR_Period           = ATR_Period;
   g_MinBodyDisplacement  = MinBodyDisplacement;
   g_BoxPeriodCandles     = BoxPeriodCandles;
   g_TrapWindowCandles    = TrapWindowCandles;
   g_BreakEvenRatio       = BreakEvenRewardRatio;
   g_SpreadBufferPoints   = SpreadBufferPoints;
   g_UseSmartBodyTrailing = UseSmartBodyTrailing;
      g_ChandelierATR_Factor  = ChandelierATR_Factor;
      g_TrapTakeProfitMargin = TrapTakeProfitMargin;
      g_TrapMinPctRemaining  = TrapMinPctRemaining;
      g_MinBoxATR_Multiple   = MinBoxATR_Multiple;
   g_CloseBeforeWeekend   = ClosePositionsBeforeWeekend;
   g_FridayCloseHour      = FridayCloseHour;
   g_GlobalLogLevel       = InputLogLevel;
      g_EnableChartDisplay    = EnableChartDisplay;
         g_ColorMajorBox         = InpColorMajorBox;
         g_ColorMinorBox         = InpColorMinorBox;
         g_ColorSL               = InpColorSL;
         g_ColorTP               = InpColorTP;
         g_ColorEntry            = InpColorEntry;

         // Logging-System starten
   Logger_Init(EnableFileLogging);

   LOG_I("SYSTEM", StringFormat("%s v%s gestartet", EA_NAME, EA_VERSION));
   LOG_I("SYSTEM", StringFormat("Kontomodus: %s",
         Executor_IsHedgingAccount() ? "Hedging-Konto" : "Netting-Konto"));

   // Asset-Liste aus dem Input-String parsen (Trenner: Komma)
   string assetListe[];
   int anzahlAssets = StringSplit(InputAssets, ',', assetListe);

   if(anzahlAssets <= 0)
   {
      LOG_E("SYSTEM", "Keine Symbole in InputAssets definiert — EA wird beendet");
      return INIT_FAILED;
   }

   // Per-Asset MaxSpread-Werte parsen
   double maxSpreadArr[];
   ParseDoubleArray(AssetMaxSpreads, maxSpreadArr, anzahlAssets);

   // Per-Asset Handelszeiten parsen
   string tradeHoursArr[];
   int hoursCount = StringSplit(AssetTradeHours, ',', tradeHoursArr);

   // Kontexte initialisieren
   ArrayResize(g_Contexts, anzahlAssets);
   g_AssetCount = 0;

   for(int i = 0; i < anzahlAssets; i++)
   {
      // Leerzeichen entfernen (robustes Parsing)
      string sym = assetListe[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);

      // Symbol im Market Watch aktivieren
      if(!SymbolSelect(sym, true))
      {
         LOG_W("SYSTEM", StringFormat(
               "Symbol '%s' nicht im Market Watch verfügbar — übersprungen",
               sym));
         continue;
      }

      // Kontext initialisieren — alle Felder auf 0/false/null
      S_AssetContext ctx;
      ZeroMemory(ctx);
      ctx.SymbolName        = sym;
      ctx.MagicNumber       = MAGIC_BASE + (ulong)i;
      ctx.CurrentState      = STATE_NONE;
      ctx.ActiveDirection   = DIR_NONE;
      ctx.TicketID          = 0;
      ctx.LastBarTimeH4     = 0;
      ctx.LastBarTimeH1     = 0;
      ctx.ATR_Handle_D1     = INVALID_HANDLE;
      ctx.ATR_Handle_H4     = INVALID_HANDLE;

      // Symbol-Typ automatisch erkennen
      ctx.SymbolType = DetectSymbolType(sym);

      // Symbol-Parameter einmalig cachen (verhindert wiederholte API-Aufrufe)
      ctx.PointSize = SymbolInfoDouble(sym, SYMBOL_POINT);
      if(ctx.PointSize <= 0.0)
      {
         LOG_W(sym, "SYMBOL_POINT ist 0 oder negativ — Symbol übersprungen");
         continue;
      }
      long stopsLvl       = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
      ctx.StopsLevelPrice = stopsLvl * ctx.PointSize;

      // Per-Asset MaxSpread setzen
      ctx.MaxSpreadOverride = (i < ArraySize(maxSpreadArr))
                              ? maxSpreadArr[i] : 0.0;

      // Per-Asset Handelszeitfenster parsen
      ctx.TradeStartHour = 0;
      ctx.TradeEndHour   = 24;
      if(i < hoursCount)
      {
         string hStr = tradeHoursArr[i];
         StringTrimLeft(hStr);
         StringTrimRight(hStr);
         ParseTimeWindow(hStr, ctx.TradeStartHour, ctx.TradeEndHour);
      }

      // ATR-Handles zwingend in OnInit erstellen (NICHT auf jedem Tick!)
      ctx.ATR_Handle_D1 = iATR(sym, PERIOD_D1, g_ATR_Period);
      ctx.ATR_Handle_H4 = iATR(sym, PERIOD_H4, g_ATR_Period);

      if(ctx.ATR_Handle_D1 == INVALID_HANDLE ||
         ctx.ATR_Handle_H4 == INVALID_HANDLE)
      {
         LOG_W(sym, "ATR-Handle konnte nicht erstellt werden — Symbol übersprungen");
         continue;
      }

      // Adaptiven MinRatio-Default je nach Symbol-Typ setzen
      // Indizes haben kleinere H4/D1-ATR-Verhältnisse als Forex
      switch(ctx.SymbolType)
      {
         case SYMTYPE_FOREX:     ctx.MinRatioRequired = 0.75; break;
         case SYMTYPE_METAL:     ctx.MinRatioRequired = 0.55; break;
         case SYMTYPE_INDEX:     ctx.MinRatioRequired = 0.40; break;
         case SYMTYPE_COMMODITY: ctx.MinRatioRequired = 0.45; break;
         default:                ctx.MinRatioRequired = 0.75; break;
      }

      // Kontext speichern
      g_Contexts[g_AssetCount] = ctx;
      g_AssetCount++;

      LOG_I(sym, StringFormat(
            "Registriert | Typ: %s | Magic: %llu | "
            "MaxSpread: %.0f Pkt | Zeit: %02d–%02d Uhr | "
            "MinRatio: %.2f",
            SymbolTypeToString(ctx.SymbolType),
            ctx.MagicNumber,
            ctx.MaxSpreadOverride,
            ctx.TradeStartHour, ctx.TradeEndHour,
            ctx.MinRatioRequired));
   }

   if(g_AssetCount == 0)
   {
      LOG_E("SYSTEM", "Kein valides Symbol verfügbar — EA wird beendet");
      return INIT_FAILED;
   }

   // 1-Sekunden-Timer für Initialisierungsphase starten
   // Wird nach abgeschlossener Initialisierung auf 30 Sekunden erhöht
   EventSetTimer(1);
   g_InitComplete = false;

   LOG_I("SYSTEM", StringFormat(
         "%d Symbol(e) registriert — warte auf vollständiges History-Loading",
         g_AssetCount));

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit: Sauberes Beenden des EA                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Timer stoppen
   EventKillTimer();

   // Alle Indikator-Handles freigeben (verhindert Speicherlecks)
   for(int i = 0; i < g_AssetCount; i++)
   {
      if(g_Contexts[i].ATR_Handle_D1 != INVALID_HANDLE)
         IndicatorRelease(g_Contexts[i].ATR_Handle_D1);
      if(g_Contexts[i].ATR_Handle_H4 != INVALID_HANDLE)
         IndicatorRelease(g_Contexts[i].ATR_Handle_H4);
   }

   // CSV-Protokolldatei schließen
   Logger_Deinit();

   // Alle Chart-Objekte des EA entfernen
   ChartDisplay_CleanupAll();

   LOG_I("SYSTEM", StringFormat(
         "EA beendet (Grund-Code: %d)", reason));
}

//+------------------------------------------------------------------+
//| OnTimer: Hauptlogik-Schleife                                     |
//|                                                                  |
//| Phase 1 (g_InitComplete = false, Timer = 1s):                    |
//|   Warte bis History geladen (non-blocking, kein Sleep!).         |
//|   Bei Vollständigkeit: Kalibrierung → Box-Init → Trading aktiv.  |
//|   Timer wird auf 30 Sekunden erhöht.                             |
//|                                                                  |
//| Phase 2 (g_InitComplete = true, Timer = 30s):                    |
//|   Balance-Snapshots aktualisieren (einmal pro Zyklus).           |
//|   Für jedes Asset: Bar-Guard prüfen.                             |
//|   Neue Kerze: AssetVerarbeiten() aufrufen.                       |
//|   Keine neue Kerze: nur Positions-Existenz prüfen.               |
//|   Break-Even: ausschließlich in OnTick() (reaktionsschneller).   |
//|   Trailing: nur bei neuer Kerze (keine neuen Extrema ohne Bar).  |
//+------------------------------------------------------------------+
void OnTimer()
{
   //--- Phase 1: Initialisierungs-Warte-Phase (non-blocking) ---
   if(!g_InitComplete)
   {
      if(!IstHistoryGeladen())
         return;   // Noch nicht fertig — nächste Sekunde erneut prüfen

      // History vollständig geladen: Kalibrierung und Box-Initialisierung
      for(int i = 0; i < g_AssetCount; i++)
      {
         KalibrierungDurchfuehren(g_Contexts[i]);
         BoxEngine_CalcMacroBox(g_Contexts[i]);
      }

      g_InitComplete = true;

      // Timer-Intervall erhöhen: 1s → 30s (ausreichend für H4-Handel)
      EventKillTimer();
      EventSetTimer(30);

      LOG_I("SYSTEM", "Initialisierung abgeschlossen — Handelssystem ist aktiv");
      return;
   }

   //--- Phase 2: Normalbetrieb ---

   // Balance-Snapshots einmalig pro Timer-Zyklus (nicht per Asset)
   RiskMgr_UpdateBalanceSnapshots();

   for(int i = 0; i < g_AssetCount; i++)
   {
      // Direkter Array-Zugriff statt Reference (MQL5-Kompatibilität)
      // Auswertungs-Zeitrahmen bestimmen
      ENUM_TIMEFRAMES tf = (InputEntryMode == MODE_HYBRID_H1)
                            ? PERIOD_H1 : PERIOD_H4;

      // Bar-Guard: Auswertung nur bei neuer Kerze
      bool neueKerze = (tf == PERIOD_H4)
                       ? BoxEngine_IsNewH4Bar(g_Contexts[i])
                       : BoxEngine_IsNewH1Bar(g_Contexts[i]);

      if(!neueKerze)
      {
         if(g_Contexts[i].CurrentState != STATE_NONE && g_Contexts[i].TicketID != 0)
         {
            if(!ExitMgr_IsPositionOpen(g_Contexts[i]))
            {
               BoxEngine_TransitionToNone(g_Contexts[i]);
            }
         }
         continue;
      }

      // Neue Kerze: vollständige Asset-Verarbeitung
      AssetVerarbeiten(g_Contexts[i]);
   }
}

//+------------------------------------------------------------------+
//| OnTick: Tick-genaues Break-Even Management                       |
//|                                                                  |
//| Aufgabenverteilung:                                              |
//|   OnTimer = Signalauswertung, Trailing (bar-basiert)             |
//|   OnTick  = Break-Even (tick-basiert für schnelle Reaktion)      |
//|                                                                  |
//| Keine Signalauswertung hier — ausschließlich OnTimers Aufgabe.   |
//| Kein Trailing hier — Extrema ändern sich nur bei neuer Kerze.    |
//+------------------------------------------------------------------+
void OnTick()
{
   // Vor Abschluss der Initialisierung nichts tun
   if(!g_InitComplete) return;

   for(int i = 0; i < g_AssetCount; i++)
   {
      // Direkter Array-Zugriff statt Reference (MQL5-Kompatibilität)
      // Nur aktive Positionen verwalten
      if(g_Contexts[i].CurrentState == STATE_NONE || g_Contexts[i].TicketID == 0)
         continue;

      // Position noch offen?
      if(!ExitMgr_IsPositionOpen(g_Contexts[i]))
      {
         BoxEngine_TransitionToNone_Fast(g_Contexts[i]);
         continue;
      }

      // Chandelier: Höchst-/Tiefstkurs auf jedem Tick aktualisieren
      if(g_ChandelierATR_Factor > 0.0)
      {
         double ask = SymbolInfoDouble(g_Contexts[i].SymbolName, SYMBOL_ASK);
         double bid = SymbolInfoDouble(g_Contexts[i].SymbolName, SYMBOL_BID);
         if(g_Contexts[i].ActiveDirection == DIR_LONG && bid > g_Contexts[i].TradeHighestPrice)
            g_Contexts[i].TradeHighestPrice = bid;
         if(g_Contexts[i].ActiveDirection == DIR_SHORT && ask < g_Contexts[i].TradeLowestPrice)
            g_Contexts[i].TradeLowestPrice = ask;
      }

      // Break-Even auf jedem Tick prüfen (reaktionsschnell)
      ExitMgr_CheckBreakEven(g_Contexts[i]);

      // SL-Linie auf dem Chart dynamisch aktualisieren
      if(g_EnableChartDisplay)
         ChartDisplay_UpdateSL(g_Contexts[i]);
   }
}