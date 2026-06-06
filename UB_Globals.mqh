//+------------------------------------------------------------------+
//|                                                                  |
//|  EA-Name    : THE UNBESTECHLICH EA                               |
//|  Datei      : UB_Globals.mqh                                     |
//|  Modul      : Zentrale globale Variablen (einmalige Definition)  |
//|  Version    : 5.2.6                                              |
//|  Datum      : 2026-06-05                                         |
//|                                                                  |
//|  Versionshistorie:                                               |
//  v4.1 - Erstellt: Ersetzt das fehlerhafte extern-Variablen-Muster|
//          Alle geteilten Variablen werden hier einmal definiert   |
//          und von allen Modulen per #include genutzt              |
//  v5.0 - g_MaxSameDirTrades (Korrelationsschutz) ergänzt          |
//          g_MinBoxATR_Multiple (ATR-basierte Box-Mindestgröße)    |
//          g_CloseBeforeWeekend und g_FridayCloseHour ergänzt      |
//  v5.2 - g_TrapTakeProfitMargin von int auf double geändert       |
//          Erlaubt nicht-ganzzahlige Prozentwerte (z.B. 12.5%)     |
//  v5.2.1 - Versionsnummer aktualisiert, keine inhaltlichen Änder. |
//|  v5.2.2 - g_TrapMinPctRemaining ergänzt (Restweg-Prüfung)        |
//|  v5.2.4 - g_ChandelierATR_Factor ergänzt                       |
//|           g_EnableChartDisplay ergänzt                        |
//|  v5.2.6 - Risikolimits von EUR auf % umgestellt               |\n//|  v5.2.7 - TrapWindowCandles 3→8, MinBoxATR 0.5→0.8          |
//|                                                                  |
//|  Zweck:                                                          |
//|  In MQL5 ist ein Programm eine einzige Kompiliereinheit.         |
//|  Globale Variablen müssen exakt einmal definiert sein.           |
//|  Dieses Modul stellt diese Definition bereit.                    |
//|  Alle anderen Module binden diese Datei ein — keine              |
//|  extern-Deklarationen erforderlich.                              |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef UB_GLOBALS_MQH
#define UB_GLOBALS_MQH

#include "UB_Defines.mqh"

//+------------------------------------------------------------------+
//| Laufzeit-Konfigurationsvariablen                                 |
//| Werden in OnInit() aus den Input-Parametern befüllt.             |
//| Standardwerte entsprechen den Input-Defaults.                    |
//+------------------------------------------------------------------+

//--- Risikomanagement
// Risiko pro Trade in Prozent des aktuellen Kontoguthabens
double  g_RiskPct              = 1.0;

// Maximale Anzahl gleichzeitig offener EA-eigener Positionen
int     g_MaxParallelTrades    = 3;

// Maximaler Tagesverlust in % des Tages-Startkontostands
// Bei Überschreitung: Keine neuen Trades für den Rest des Tages
double  g_MaxDailyDD_Pct       = 0.5;

// Maximaler Wochenverlust in % des Wochen-Startkontostands
// Bei Überschreitung: Keine neuen Trades für den Rest der Woche
double  g_MaxWeeklyDD_Pct      = 1.0;

// Maximaler gleichzeitiger Buchverlust in % des aktuellen Equity
// Bei Überschreitung: Kein neuer Trade bis Verluste abgebaut
double  g_MaxFloatingLoss_Pct  = 0.5;

// Maximale akzeptierte Slippage bei Orderausführung in Punkten
double  g_MaxSlippagePoints    = 5.0;

// Globaler Spread-Grenzwert in Punkten (Fallback für alle Assets)
// Kann per Asset durch MaxSpreadOverride überschrieben werden
double  g_MaxSpreadPoints      = 30.0;

// Maximale gleichzeitige Trades in dieselbe Richtung (Korrelationsschutz)
// 0 = Korrelationsschutz deaktiviert
int     g_MaxSameDirTrades     = 2;

//--- Signalfilter
// Periode für den ATR-Indikator auf D1 (Kraft-Filter Stufe 1)
int     g_ATR_Period           = 14;

// Mindest-Prozentwert des Kerzenkörpers der außerhalb der Box liegen muss
// (Displacement-Filter Stufe 2)
double  g_MinBodyDisplacement  = 50.0;

//--- Box-Engine
// Anzahl der H4-Kerzen für die Konsolidierungsbox-Berechnung
int     g_BoxPeriodCandles     = 30;

// Anzahl H4-Kerzen nach Einstieg in denen Trap-Reversal erkannt werden kann
int     g_TrapWindowCandles    = 8;

// Mindestgröße der Box als Vielfaches des aktuellen H4-ATR
// Verhindert Signale auf Basis von Rausch-Konsolidierungen
double  g_MinBoxATR_Multiple   = 0.8;

//--- Exit-Management
// Gewinn-Risiko-Verhältnis für Break-Even-Aktivierung
// 1.0 = SL auf Einstieg wenn Gewinn = ursprüngliches Risiko (1:1)
double  g_BreakEvenRatio       = 1.0;

// Sicherheitspuffer in Punkten für SL-Platzierung
// Schützt vor vorzeitigem SL-Auslösen durch den Spread
double  g_SpreadBufferPoints   = 10.0;

// Schalter für Smart-Body-Trailing im Trend-Modus
bool    g_UseSmartBodyTrailing = true;

// Sicherheitsabstand des Trap-Take-Profits zur Boxgrenze in Prozent
// Verhindert Stop-Hunting kurz vor der Boxgrenze
// double statt int — erlaubt Werte wie 12.5%
double  g_TrapTakeProfitMargin = 15.0;

// Mindest-Prozentsatz der Boxhöhe der zwischen Einstieg und
// gegenüberliegender Boxgrenze liegen muss (Trap/Inside-Box-Trade)
// Verhindert Trap-Trades mit zu geringem Gewinnpotenzial
double  g_TrapMinPctRemaining  = 50.0;

//--- ATR-Chandelier Trailing
// Faktor für ATR-Chandelier; 0.0 = deaktiviert (nur Smart-Body-Trailing)
double  g_ChandelierATR_Factor = 0.0;

//--- Wochenend-Gap-Schutz
// Schalter: Positionen freitags vor Marktschluss schließen
bool    g_CloseBeforeWeekend   = false;

// Serverzeit-Stunde für den Freitags-Zwangsschluss
int     g_FridayCloseHour      = 21;

//+------------------------------------------------------------------+
//| Laufzeit-Zustandsvariablen                                       |
//+------------------------------------------------------------------+

// Array aller überwachten Asset-Kontexte (ein Eintrag pro Symbol)
// Größe wird in OnInit() per ArrayResize() gesetzt
S_AssetContext  g_Contexts[];

// Tatsächliche Anzahl valide initialisierter Assets
int             g_AssetCount   = 0;

// Initialisierungs-Flag: true sobald History geladen und Kalibrierung
// abgeschlossen ist. Vor diesem Zeitpunkt: kein Trading.
bool            g_InitComplete = false;

//--- Logging-System
// Schalter für Chart-Visualisierung (Boxen, Levels)
bool            g_EnableChartDisplay = true;
// Farben für Chart-Elemente
color           g_ColorMajorBox = clrDarkGray;
color           g_ColorMinorBox = clrDimGray;
color           g_ColorSL       = clrRed;
color           g_ColorTP       = clrMediumSeaGreen;
color           g_ColorEntry    = clrDodgerBlue;

// Aktuell aktiver Log-Level (aus InputLogLevel gesetzt)
ENUM_LOG_LEVEL  g_GlobalLogLevel = LOG_INFO;

// Datei-Handle für CSV-Protokoll (INVALID_HANDLE = kein File-Logging)
int             g_LogFileHandle  = INVALID_HANDLE;

//--- Magic-Number-System
// Basis-Wert für automatische Magic-Number-Vergabe.
// Jedes Symbol bekommt (MAGIC_BASE + Index) als eindeutige Nummer.
// Beispiel: 1. Symbol = 20260001, 2. Symbol = 20260002, usw.
#define MAGIC_BASE 20260001

#endif // UB_GLOBALS_MQH