//+------------------------------------------------------------------+
//|                                                                  |
//|  EA-Name    : THE UNBESTECHLICH EA                               |
//|  Datei      : UB_Defines.mqh                                     |
//|  Modul      : Zentrale Typdefinitionen, Enums und Datenstrukturen|
//|  Version    : 5.2.4                                              |
//|  Datum      : 2026-06-05                                         |
//|
//|  Versionshistorie:                                               |
//|  v4.0 - Erstimplementierung nach vollständigem Review            |
//|          Magic Number, Bar-Guard, ATR-Handle, TicketID           |
//|          EntryPrice, InitialSL, InitialRiskPoints ergänzt        |
//|  v4.1 - MQL5-Reinheit: #pragma once durch Include-Guards ersetzt |
//|          Alle Kommentare vollständig auf Deutsch                 |
//|          Selbsterklärende Feldbeschreibungen                     |
//|  v4.2 - PointSize und StopsLevelPrice als gecachte Felder        |
//|          Verhindert wiederholte SymbolInfoDouble()-Aufrufe        |
//|  v5.0 - ENUM_SYMBOL_TYPE für asset-spezifische Logik             |
//|          MaxSpreadOverride und TradeStartHour/EndHour per Asset   |
//|          S_AssetContext um Symbol-Typ und per-Asset-Felder erweit.|
//|  v5.2   - g_TrapTakeProfitMargin von int auf double              |
//|  v5.2.1 - Keine Strukturänderung, Versionsnummer aktualisiert    |
//|  v5.2.2 - Versionsnummer aktualisiert                            |
//|  v5.2.3 - MinorBoxHigh/Low/Median/Height ergänzt               |
//|  v5.2.4 - TradeHighestPrice/LowestPrice ergänzt (Chandelier)   |
//|           HasActiveMinorBox ergänzt                             |
//|                                                                  |
//|  Zweck:                                                          |
//|  Definiert alle gemeinsam genutzten Datentypen des EA.           |
//|  Wird als erstes Modul von allen anderen eingebunden.            |
//|  Enthält keine ausführbare Logik.                                |
//|                                                                  |
//+------------------------------------------------------------------+

// MQL5-konformer Include-Guard — verhindert Mehrfach-Einbindung
#ifndef UB_DEFINES_MQH
#define UB_DEFINES_MQH

// Sicherheitscheck: Nur für MetaTrader 5 kompilieren
#ifndef __MQL5__
   #error "Dieser EA erfordert MetaTrader 5 (MQL5). MQL4 wird nicht unterstützt."
#endif

//--- Versionskonstanten des EA
// Name des Expert Advisors (für Logging und Anzeige)
#define EA_NAME    "The Unbestechlich EA"
// Aktuelle Versionsnummer
#define EA_VERSION "5.2.8"
// Präfix für alle Einträge im MT5-Journal (leicht auffindbar)
#define EA_PREFIX  "[Skalpell-Core]"

//+------------------------------------------------------------------+
//| Einstiegs-Aggressivität                                          |
//| Steuert auf welchem Zeitrahmen das Signal ausgewertet wird       |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_MODE
{
   // Signal wird exakt beim Schlusskurs der H4-Kerze ausgewertet.
   // Zuverlässiger, weniger Signale, empfohlen für Einsteiger.
   MODE_PURE_H4,

   // Signal wird beim H1-Schlusskurs gegen die H4-Makrobox geprüft.
   // Früherer Einstieg, aber weniger Bestätigung durch den H4-Schluss.
   MODE_HYBRID_H1
};

//+------------------------------------------------------------------+
//| Interner Betriebszustand des EA pro überwachtem Symbol           |
//| Die State Machine wechselt zwischen diesen drei Zuständen        |
//+------------------------------------------------------------------+
enum ENUM_EA_STATE
{
   // Wartemodus: Kurs liegt innerhalb der Konsolidierungsbox.
   // Der EA scannt auf ein Ausbruchssignal.
   STATE_NONE,

   // Trendfolge-Modus: Ein Ausbruchstrade ist aktiv.
   // Der EA verwaltet Stop-Loss und Trailing.
   STATE_TREND,

   // Umkehr-Modus (Trap): Ein Gegentrade nach Fehlausbruch ist aktiv.
   // Der EA verwaltet SL und den festen Take-Profit.
   STATE_TRAP
};

//+------------------------------------------------------------------+
//| Protokoll-Detailstufen für das Logging-System                    |
//| Steuert welche Meldungen im MT5-Journal erscheinen               |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   // Alle Details ausgeben — nur für Entwicklung und Fehlersuche geeignet.
   // Erzeugt sehr viele Journaleinträge.
   LOG_DEBUG = 0,

   // Normalbetrieb: Trades, Zustandswechsel und Signale werden protokolliert.
   // Empfohlen für den täglichen Betrieb.
   LOG_INFO  = 1,

   // Nur Warnungen ausgeben: Unerwartete Zustände die keinen Abbruch erfordern.
   LOG_WARN  = 2,

   // Nur kritische Fehler: Situationen die einen Trade verhindert haben.
   LOG_ERROR = 3
};

//+------------------------------------------------------------------+
//| Handelsrichtung des aktiven Trades                               |
//+------------------------------------------------------------------+
enum ENUM_TRADE_DIR
{
   DIR_NONE  =  0,   // Kein aktiver Trade
   DIR_LONG  =  1,   // Kaufposition (Long) — Preis soll steigen
   DIR_SHORT = -1    // Verkaufsposition (Short) — Preis soll fallen
};

//+------------------------------------------------------------------+
//| Symbol-Klassifizierung für asset-spezifische Logik              |
//| Wird automatisch in OnInit() durch DetectSymbolType() gesetzt    |
//+------------------------------------------------------------------+
enum ENUM_SYMBOL_TYPE
{
   // Währungspaar (z.B. EURUSD, GBPUSD, USDJPY)
   // Handelt 24h/5 Tage, engste Spreads, höchste Liquidität
   SYMTYPE_FOREX,

   // Edelmetall-CFD (z.B. XAUUSD = Gold, XAGUSD = Silber)
   // Gute H4-Strukturen, moderate Spreads
   SYMTYPE_METAL,

   // Aktienindex-CFD (z.B. US500, GER40, NAS100)
   // Handelszeiten beachten, Wochenend-Gaps möglich
   SYMTYPE_INDEX,

   // Rohstoff-CFD (z.B. LCrude = WTI Öl, USOIL, BRENT)
   // Höhere Spreads, News-sensitiv (EIA Mittwoch)
   SYMTYPE_COMMODITY,

   // Unbekannter Typ — wird als Forex behandelt
   SYMTYPE_UNKNOWN
};

//+------------------------------------------------------------------+
//| Haupt-Datensatz (Kontext) pro überwachtem Handelssymbol          |
//|                                                                  |
//| Für jedes Symbol in InputAssets wird genau eine Instanz          |
//| dieses Structs in g_Contexts[] verwaltet. Alle EA-Zustände,      |
//| Box-Werte, Trade-Daten und gecachte Parameter sind hier          |
//| zentral gespeichert.                                             |
//+------------------------------------------------------------------+
struct S_AssetContext
{
   //--- Identifikation des Symbols
   // Name des Handelssymbols (z.B. "EURUSD", "LCrude")
   string           SymbolName;

   // Eindeutige Kennnummer für alle Orders dieses EA auf diesem Symbol.
   // Verhindert Verwechslung mit manuell platzierten oder fremden Orders.
   // Berechnet als: MAGIC_BASE + Symbolindex
   ulong            MagicNumber;

   //--- Symbol-Klassifizierung (automatisch erkannt in OnInit)
   // Bestimmt adaptive Standardwerte (MinRatioRequired etc.)
   ENUM_SYMBOL_TYPE SymbolType;

   //--- Gecachte Symbol-Parameter (einmalig in OnInit befüllt)
   // Gespeicherter SYMBOL_POINT-Wert. Vermeidet wiederholte API-Aufrufe
   // auf jedem Tick. Niemals manuell ändern.
   double           PointSize;

   // Mindestabstand von SL/TP zum aktuellen Preis in Preiseinheiten.
   // = SYMBOL_TRADE_STOPS_LEVEL × PointSize (gecacht)
   double           StopsLevelPrice;

   //--- Per-Asset-Einstellungen (aus Input-Strings geparst)
   // Maximaler Spread für dieses Symbol in Punkten.
   // 0 = globalen MaxSpreadPoints-Wert verwenden.
   double           MaxSpreadOverride;

   // Handelsfenster-Start in Stunden (Serverzeit, 0 = kein Limit)
   int              TradeStartHour;

   // Handelsfenster-Ende in Stunden (Serverzeit, 24 = kein Limit)
   int              TradeEndHour;

   //--- Aktueller Betriebszustand der State Machine
   ENUM_EA_STATE    CurrentState;

   // Richtung des derzeit offenen Trades (Long/Short/keiner)
   ENUM_TRADE_DIR   ActiveDirection;

   //--- Makro-Konsolidierungsbox (H4-Zeitrahmen)
   // Obere Grenze der erkannten Konsolidierungszone
   double           BoxHigh;

   // Untere Grenze der erkannten Konsolidierungszone
   double           BoxLow;

   // Mittellinie der Box: (BoxHigh + BoxLow) / 2
   // Wird als SL-Referenz im Trend-Modus und für Kanten-Riegel-Reset genutzt
   double           BoxMedian;

   // Gesamthöhe der Box in Preiseinheiten: BoxHigh - BoxLow
   double           BoxHeight;

   //--- Minor-Konsolidierungsbox (Inside-Box-Struktur, basierend auf Outside-Bar)
   // Nur im Trend-Modus aktiv. Einmal gesetzt, fixe Grenzen.
   // Wird aufgelöst sobald 3-Stufen-Prüfung gegen Minor-Box bestanden.
   double           MinorBoxHigh;
   double           MinorBoxLow;
   double           MinorBoxMedian;
   double           MinorBoxHeight;
   bool             HasActiveMinorBox;

   //--- Mikro-Konsolidierungszone (nur im Trap-Modus aktiv)
   // Obere Grenze der erkannten Mikro-Zone (Outside-Bar im TRAP-Modus)
   double           InsideBoxHigh;

   // Untere Grenze der erkannten Mikro-Zone
   double           InsideBoxLow;

   // true = Eine aktive Mikro-Zone ist vorhanden und wird für
   // das Inside-Box-Trailing genutzt
   bool             HasActiveInsideBox;

   //--- Kanten-Riegel (Whipsaw/Sägezan-Schutz)
   // true = Kein neues Long-Signal erlaubt bis BoxMedian berührt wird.
   // Wird gesetzt wenn ein Long-Trade an der oberen Boxkante eröffnet wurde.
   bool             UpperEdgeLocked;

   // true = Kein neues Short-Signal erlaubt bis BoxMedian berührt wird.
   bool             LowerEdgeLocked;

   //--- Trap-Erkennungsfenster
   // Zählt die H4-Kerzen seit dem letzten Trendfolge-Einstieg.
   // Wenn Counter > TrapWindowCandles: Kein Trap mehr möglich.
   int              TrendCandleCounter;

   //--- Volatilitätskalibrierung
   // Mindest-Verhältnis (Kerzenrange / D1-ATR) für ein valides Signal.
   // Wird in KalibrierungDurchfuehren() aus historischen Daten gelernt.
   // Default: 0.40–0.75 je nach Symbol-Typ
   double           MinRatioRequired;

   // Historische Wucht-Ratios der letzten erfolgreichen Ausbrüche.
   // Für die adaptive Kalibrierung des MinRatioRequired-Wertes.
   double           SuccessRatioHistory[10];

   // Anzahl der bisher gespeicherten Kalibrierungs-Datenpunkte (max. 10)
   int              RatioHistoryCount;

   //--- Daten des aktuell offenen Trades
   // Ticket-Nummer der offenen Position. 0 = kein aktiver Trade.
   // Wird für SL/TP-Modifikation und Positions-Check verwendet.
   ulong            TicketID;

   // Einstiegspreis der aktuell offenen Position
   double           EntryPrice;

   // Ursprünglicher Stop-Loss-Preis beim Handelseinstieg.
   // Referenz für die Break-Even-Berechnung.
   double           InitialSL;

   // Risiko in Punkten beim Einstieg: MathAbs(EntryPrice - InitialSL) / PointSize
   // Referenz für Break-Even-Trigger und Trailing-Logik.
   double           InitialRiskPoints;

   //--- Chandelier-Trailing: Höchst-/Tiefstkurs seit Trade-Start
   // Wird auf jedem Tick aktualisiert für ATR-Chandelier-Berechnung.
   double           TradeHighestPrice;
   double           TradeLowestPrice;

   //--- Zeitstempel der zuletzt verarbeiteten Kerze (Bar-Guard)
   // Verhindert Mehrfachauswertung desselben Signals innerhalb einer
   // noch laufenden Kerze. Wird in BoxEngine_IsNewH4Bar() geprüft.
   datetime         LastBarTimeH4;

   // Zeitstempel für H1-Bar-Guard (nur im MODE_HYBRID_H1 relevant)
   datetime         LastBarTimeH1;

   //--- Indikator-Handles (zwingend in OnInit() erstellen!)
   // Handle für den ATR-Indikator auf D1 (für Stufe 1: Kraft-Check).
   // Darf NICHT auf jedem Tick neu erstellt werden — Performance-Killer!
   int              ATR_Handle_D1;

   // Handle für den ATR-Indikator auf H4 (für Box-Mindestgrößen-Filter)
   int              ATR_Handle_H4;
};

//+------------------------------------------------------------------+
//| Ergebnis der 3-Stufen-Signalprüfung                              |
//| Wird von SignalFilter_Evaluate() zurückgegeben                   |
//+------------------------------------------------------------------+
struct S_SignalResult
{
   // true = alle drei Filterstufen bestanden, Signal ist handelbar
   bool             IsValid;

   // Erkannte Handelsrichtung (Long oder Short)
   // Basiert auf der Position des Schlusskurses relativ zur Box
   ENUM_TRADE_DIR   Direction;

   // Ergebnis Stufe 1: Verhältnis Kerzenrange zu D1-ATR
   // Höher = stärkere Ausbruchskerze
   double           WuchtRatio;

   // Ergebnis Stufe 2: Prozentualer Körperanteil außerhalb der Box
   // 100% = Körper komplett außerhalb, 50% = halb draußen
   double           DisplacementPct;

   // Ergebnis Stufe 3: Position des Schlusskurses innerhalb der Kerze
   // 100% = Schluss am Hoch, 0% = Schluss am Tief
   double           RejectionPos;

   // Bei Ablehnung: Nummer der fehlgeschlagenen Stufe (1, 2 oder 3)
   // Bei Erfolg: 0
   int              FailedStage;

   // Klartext-Begründung für eine Signalablehnung (für das Journal)
   string           RejectReason;
};

//+------------------------------------------------------------------+
//| Interne Handelsanfrage-Struktur                                  |
//| Wird von AssetVerarbeiten() befüllt und an Executor_SendOrder()  |
//| übergeben. Kapselt alle Parameter einer einzelnen Order.         |
//+------------------------------------------------------------------+
struct S_TradeRequest
{
   // Handelssymbol für diese Order
   string           Symbol;

   // Auftragstyp: ORDER_TYPE_BUY (Long) oder ORDER_TYPE_SELL (Short)
   ENUM_ORDER_TYPE  OrderType;

   // Lotzahl der Order (bereits normalisiert)
   double           Volume;

   // Gewünschter Einstiegspreis (Ask für Long, Bid für Short)
   double           Price;

   // Stop-Loss-Preis (0 = kein SL, nicht empfohlen)
   double           SL;

   // Take-Profit-Preis (0 = kein fester TP — Ausstieg über Trailing)
   double           TP;

   // Magic Number für diese Order (zur Identifikation)
   ulong            Magic;

   // Orderkommentar (im Broker-Terminal und Kontoauszug sichtbar)
   string           Comment;

   // Maximale akzeptierte Slippage in Punkten
   ulong            Deviation;
};

#endif // UB_DEFINES_MQH