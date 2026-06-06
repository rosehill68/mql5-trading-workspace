//+------------------------------------------------------------------+
//|                                                                  |
//|  EA-Name    : THE UNBESTECHLICH EA                               |
//|  Datei      : UB_BoxEngine.mqh                                   |
//|  Modul      : Box-Berechnung und Zustandsmaschine               |
//|  Version    : 5.2.4                                              |
//|  Datum      : 2026-06-05                                         |
//|                                                                  |
//|  Versionshistorie:                                               |
//|  v4.0 - Erstimplementierung                                      |
//|          Bar-Guard gegen Mehrfachauswertung (LastBarTime)        |
//|          Vollständige State Machine mit allen Transitionen       |
//|          TrendCandleCounter-Management                           |
//|          Outside-Bar-Erkennung und Verarbeitung                  |
//|  v4.1 - Include-Guards, UB_Globals.mqh, deutsche Kommentierung   |
//|          Bars() statt iBars() (nativer MQL5-Aufruf)             |
//|  v4.2 - Korrekte Index-Benennung in SmartBodyTrailing            |
//|  v5.0 - ATR-basierte Box-Mindestgröße (MinBoxATR_Multiple)       |
//|  v5.2.1 - BoxEngine_TransitionToNone_Fast() für OnTick ergänzt   |
//|           Schneller Reset ohne CalcMacroBox() für OnTick-Kontext |
//|  v5.2.3 - Outside-Bar setzt Minor-Box (fix), überschreibt keine  |
//|           Major-Box mehr. Keine verschachtelten Minor-Boxen.      |
//|           TransitionToNone/Fast setzt Minor-Box zurück            |
//|  v5.2.4 - TransitionToTrend/Trap initialisiert TradeHigh/Low    |
//|                                                                  |
//|  Zweck:                                                          |
//|  Berechnet die H4-Konsolidierungsbox und verwaltet die           |
//|  interne Zustandsmaschine (NONE / TREND / TRAP).                 |
//|  Steuert Bar-Guard, Kanten-Riegel, Kerzen-Zähler und            |
//|  Outside-Bar-Verarbeitung.                                       |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef UB_BOXENGINE_MQH
#define UB_BOXENGINE_MQH

#include "UB_Globals.mqh"
#include "UB_Logger.mqh"

//+------------------------------------------------------------------+
//| Prüfen ob eine neue H4-Kerze erschienen ist (Bar-Guard)          |
//|                                                                  |
//| Vergleicht den Eröffnungszeitpunkt der aktuellen H4-Kerze mit    |
//| dem gespeicherten Zeitstempel der letzten Auswertung.            |
//| Verhindert Mehrfachauswertung desselben Signals innerhalb        |
//| einer noch laufenden Kerze.                                      |
//|                                                                  |
//| Parameter: ctx - Referenz auf den Asset-Kontext                  |
//| Rückgabe: true = neue Kerze vorhanden | false = selbe Kerze      |
//+------------------------------------------------------------------+
bool BoxEngine_IsNewH4Bar(S_AssetContext &ctx)
{
   // SERIES_LASTBAR_DATE = Eröffnungszeit der neuesten (laufenden) Kerze
   // Ändert sich genau dann wenn eine neue H4-Kerze geöffnet hat
   datetime lastBar = (datetime)SeriesInfoInteger(ctx.SymbolName,
                                                   PERIOD_H4,
                                                   SERIES_LASTBAR_DATE);
   if(lastBar != ctx.LastBarTimeH4)
   {
      ctx.LastBarTimeH4 = lastBar;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Prüfen ob eine neue H1-Kerze erschienen ist (für Hybrid-Modus)   |
//| Nur relevant wenn InputEntryMode = MODE_HYBRID_H1                |
//+------------------------------------------------------------------+
bool BoxEngine_IsNewH1Bar(S_AssetContext &ctx)
{
   datetime lastBar = (datetime)SeriesInfoInteger(ctx.SymbolName,
                                                   PERIOD_H1,
                                                   SERIES_LASTBAR_DATE);
   if(lastBar != ctx.LastBarTimeH1)
   {
      ctx.LastBarTimeH1 = lastBar;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Makro-Konsolidierungsbox berechnen                               |
//|                                                                  |
//| Berechnet Hoch, Tief, Mittellinie und Höhe der letzten N         |
//| abgeschlossenen H4-Kerzen. Kerze [0] (noch laufend) wird         |
//| bewusst ausgeschlossen — nur bestätigte Kerzen fließen ein.      |
//|                                                                  |
//| Box-Mindestgröße: Wird ATR-basiert geprüft wenn Handle verfügbar,|
//| sonst absoluter Fallback (10 Punkte).                            |
//|                                                                  |
//| Parameter: ctx - Referenz auf den Asset-Kontext                  |
//| Rückgabe: true = Box gültig | false = Datenfehler oder zu klein  |
//+------------------------------------------------------------------+
bool BoxEngine_CalcMacroBox(S_AssetContext &ctx)
{
   int count = g_BoxPeriodCandles;
   if(count < 2)
      count = 2;

   // Arrays für Hoch- und Tief-Kurse der letzten N abgeschlossenen Kerzen
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows,  true);

   // CopyHigh/CopyLow ab Index 1 → schließt offene Kerze [0] aus
   if(CopyHigh(ctx.SymbolName, PERIOD_H4, 1, count, highs) < count)
   {
      LOG_W(ctx.SymbolName, "Box-Berechnung: Nicht genügend Hoch-Daten verfügbar");
      return false;
   }
   if(CopyLow(ctx.SymbolName, PERIOD_H4, 1, count, lows) < count)
   {
      LOG_W(ctx.SymbolName, "Box-Berechnung: Nicht genügend Tief-Daten verfügbar");
      return false;
   }

   // Box-Grenzen aus dem Maximum/Minimum der kopierten Kerzen
   ctx.BoxHigh   = highs[ArrayMaximum(highs, 0, count)];
   ctx.BoxLow    = lows [ArrayMinimum(lows,  0, count)];
   ctx.BoxMedian = (ctx.BoxHigh + ctx.BoxLow) / 2.0;
   ctx.BoxHeight = ctx.BoxHigh - ctx.BoxLow;

   // Mindestgröße berechnen: bevorzugt ATR-basiert, sonst absoluter Fallback
   double minSize = ctx.PointSize * 10.0;   // Absoluter Fallback: 10 Punkte

   if(ctx.ATR_Handle_H4 != INVALID_HANDLE && g_MinBoxATR_Multiple > 0.0)
   {
      double atrH4Buf[];
      ArraySetAsSeries(atrH4Buf, true);
      // H4-ATR der letzten abgeschlossenen Kerze lesen
      if(CopyBuffer(ctx.ATR_Handle_H4, 0, 1, 1, atrH4Buf) == 1)
         minSize = atrH4Buf[0] * g_MinBoxATR_Multiple;
   }

   // Box zu klein → kein valides Konsolidierungsmuster
   if(ctx.BoxHeight < minSize)
   {
      LOG_D(ctx.SymbolName, StringFormat(
            "Box zu klein: %.5f < Mindest %.5f (%.1f × H4-ATR) – übersprungen",
            ctx.BoxHeight, minSize, g_MinBoxATR_Multiple));
      return false;
   }

   LOG_D(ctx.SymbolName, StringFormat(
         "Box aktualisiert → Hoch: %.5f | Tief: %.5f | "
         "Mitte: %.5f | Höhe: %.5f",
         ctx.BoxHigh, ctx.BoxLow, ctx.BoxMedian, ctx.BoxHeight));

   return true;
}

//+------------------------------------------------------------------+
//| Kanten-Riegel aktualisieren (Whipsaw/Sägezan-Schutz)            |
//|                                                                  |
//| Verhindert dass nach einem Trade an der oberen Boxkante sofort   |
//| wieder ein Long-Signal ausgelöst werden kann, bevor der Preis    |
//| die Boxmitte (BoxMedian) berührt hat — und umgekehrt.            |
//|                                                                  |
//| Entsperrung: Wenn Bid ≤ BoxMedian → oberer Riegel öffnet         |
//|              Wenn Ask ≥ BoxMedian → unterer Riegel öffnet        |
//|                                                                  |
//| Aufruf: Bei jeder neuen Kerze und bei Positionscheck             |
//+------------------------------------------------------------------+
void BoxEngine_UpdateEdgeLocks(S_AssetContext &ctx)
{
   double bid = SymbolInfoDouble(ctx.SymbolName, SYMBOL_BID);
   double ask = SymbolInfoDouble(ctx.SymbolName, SYMBOL_ASK);

   // Oberer Riegel entsperren wenn Bid die Boxmitte erreicht oder unterschreitet
   if(ctx.UpperEdgeLocked && bid <= ctx.BoxMedian)
   {
      ctx.UpperEdgeLocked = false;
      LOG_I(ctx.SymbolName,
            "Kanten-Riegel OBEN entsperrt — Preis hat die Boxmitte erreicht");
   }

   // Unterer Riegel entsperren wenn Ask die Boxmitte erreicht oder überschreitet
   if(ctx.LowerEdgeLocked && ask >= ctx.BoxMedian)
   {
      ctx.LowerEdgeLocked = false;
      LOG_I(ctx.SymbolName,
            "Kanten-Riegel UNTEN entsperrt — Preis hat die Boxmitte erreicht");
   }
}

//+------------------------------------------------------------------+
//| Outside-Bar erkennen                                             |
//|                                                                  |
//| Eine Outside-Bar umfasst das Hoch UND das Tief der Vorgängerkerze|
//| vollständig. Sie signalisiert erhöhte Volatilität und verändert  |
//| je nach Zustand die Box-Struktur des EA.                         |
//|                                                                  |
//| Erkennungskriterium:                                             |
//|   High[1] > High[2] UND Low[1] < Low[2]                         |
//|   (Kerze [1] umfasst Kerze [2] vollständig)                      |
//|                                                                  |
//| Parameter: symbol - Zu prüfendes Handelssymbol                   |
//| Rückgabe: true wenn letzte abgeschlossene Kerze eine Outside-Bar  |
//+------------------------------------------------------------------+
bool BoxEngine_IsOutsideBar(const string symbol)
{
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows,  true);

   // Zwei abgeschlossene Kerzen benötigt: [1] und [2]
   if(CopyHigh(symbol, PERIOD_H4, 1, 2, highs) < 2) return false;
   if(CopyLow (symbol, PERIOD_H4, 1, 2, lows)  < 2) return false;

   // Nach ArraySetAsSeries(true): [0]=Kerze[1], [1]=Kerze[2]
   return (highs[0] > highs[1] && lows[0] < lows[1]);
}

//+------------------------------------------------------------------+
//| Outside-Bar verarbeiten (unterschiedlich je nach Zustand)        |
//|                                                                  |
//| STATE_TREND: Makro-Box wird durch Outside-Bar ersetzt.           |
//|              Beide Kanten-Riegel werden geöffnet.                |
//|              Begründung: Die Outside-Bar definiert eine neue      |
//|              Konsolidierungsstruktur.                             |
//|                                                                  |
//| STATE_TRAP:  Makro-Box bleibt unverändert!                       |
//|              Outside-Bar setzt eine neue Mikro-Zone              |
//|              (InsideBoxHigh/Low) für das Inside-Box-Trailing.    |
//+------------------------------------------------------------------+
void BoxEngine_HandleOutsideBar(S_AssetContext &ctx)
{
   if(!BoxEngine_IsOutsideBar(ctx.SymbolName))
      return;

   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows,  true);
   CopyHigh(ctx.SymbolName, PERIOD_H4, 1, 2, highs);
   CopyLow (ctx.SymbolName, PERIOD_H4, 1, 2, lows);
   // highs[0]/lows[0] = Werte der Outside-Bar (Kerze [1])

   if(ctx.CurrentState == STATE_TREND)
   {
      // Bestehende Minor-Box nicht überschreiben (fixe Grenzen!)
      if(ctx.HasActiveMinorBox)
      {
         LOG_D(ctx.SymbolName,
               "Outside-Bar ignoriert: Minor-Box bereits aktiv");
         return;
      }

      // Minor-Box setzen — Major-Box bleibt UNVERÄNDERT!
      ctx.MinorBoxHigh      = highs[0];
      ctx.MinorBoxLow       = lows[0];
      ctx.MinorBoxMedian    = (ctx.MinorBoxHigh + ctx.MinorBoxLow) / 2.0;
      ctx.MinorBoxHeight    = ctx.MinorBoxHigh - ctx.MinorBoxLow;
      ctx.HasActiveMinorBox = true;

      LOG_I(ctx.SymbolName, StringFormat(
            "Minor-Box gesetzt → Hoch: %.5f | Tief: %.5f | "
            "Median: %.5f",
            ctx.MinorBoxHigh, ctx.MinorBoxLow, ctx.MinorBoxMedian));
   }
   else if(ctx.CurrentState == STATE_TRAP)
   {
      // Mikro-Konsolidierungszone für Inside-Box-Trailing setzen
      // Die Haupt-Makro-Box bleibt UNVERÄNDERT!
      ctx.InsideBoxHigh      = highs[0];
      ctx.InsideBoxLow       = lows[0];
      ctx.HasActiveInsideBox = true;

      LOG_I(ctx.SymbolName, StringFormat(
            "Outside-Bar (TRAP): Mikro-Zone gesetzt → "
            "Hoch: %.5f | Tief: %.5f",
            ctx.InsideBoxHigh, ctx.InsideBoxLow));
   }
}

//+------------------------------------------------------------------+
//| Trend-Kerzen-Zähler erhöhen                                      |
//|                                                                  |
//| Wird bei jeder neuen abgeschlossenen H4-Kerze im STATE_TREND     |
//| aufgerufen. Der Zähler bestimmt ob das Trap-Erkennungsfenster    |
//| noch aktiv ist (Counter ≤ TrapWindowCandles).                    |
//| Nur im STATE_TREND relevant.                                     |
//+------------------------------------------------------------------+
void BoxEngine_UpdateTrendCounter(S_AssetContext &ctx)
{
   if(ctx.CurrentState != STATE_TREND)
      return;

   ctx.TrendCandleCounter++;

   LOG_D(ctx.SymbolName, StringFormat(
         "Trend-Kerzen-Zähler: %d von %d (Trap-Fenster %s)",
         ctx.TrendCandleCounter,
         g_TrapWindowCandles,
         (ctx.TrendCandleCounter <= g_TrapWindowCandles) ? "AKTIV" : "ABGELAUFEN"));
}

//+------------------------------------------------------------------+
//| Vollständiger Zustandsreset → Wartemodus (STATE_NONE)            |
//| MIT Box-Neuberechnung                                            |
//|                                                                  |
//| Verwendung: In AssetVerarbeiten() und CheckWeekendClose()        |
//| wenn eine Position normal beendet wurde (SL/TP/manuell).         |
//| CalcMacroBox() wird sofort aufgerufen für frische Box-Daten.     |
//|                                                                  |
//| NICHT in OnTick() verwenden — dort BoxEngine_TransitionToNone_   |
//| Fast() nutzen (Performance).                                     |
//+------------------------------------------------------------------+
void BoxEngine_TransitionToNone(S_AssetContext &ctx)
{
   string vonZustand;
   switch(ctx.CurrentState)
   {
      case STATE_TREND: vonZustand = "TREND"; break;
      case STATE_TRAP:  vonZustand = "TRAP";  break;
      default:          vonZustand = "?";     break;
   }

   // Alle Trade- und Zustandsfelder zurücksetzen
   ctx.CurrentState       = STATE_NONE;
   ctx.ActiveDirection    = DIR_NONE;
   ctx.TicketID           = 0;
   ctx.EntryPrice         = 0.0;
   ctx.InitialSL          = 0.0;
   ctx.InitialRiskPoints  = 0.0;
   ctx.TrendCandleCounter = 0;
   ctx.HasActiveInsideBox = false;
   ctx.InsideBoxHigh      = 0.0;
   ctx.InsideBoxLow       = 0.0;
   ctx.HasActiveMinorBox  = false;
   ctx.MinorBoxHigh       = 0.0;
   ctx.MinorBoxLow        = 0.0;
   ctx.MinorBoxMedian     = 0.0;
   ctx.MinorBoxHeight     = 0.0;

   // Box sofort neu berechnen für den nächsten Warte-Zyklus
   BoxEngine_CalcMacroBox(ctx);

   LOG_I(ctx.SymbolName, StringFormat(
         "Zustandswechsel: %s → WARTEN (Box neu berechnet)",
         vonZustand));
}

//+------------------------------------------------------------------+
//| Schneller Zustandsreset → Wartemodus OHNE Box-Neuberechnung      |
//|                                                                  |
//| Verwendung: AUSSCHLIESSLICH in OnTick() wenn eine Position        |
//| durch SL oder TP geschlossen wurde.                              |
//| CalcMacroBox() wird bewusst NICHT aufgerufen — zu teuer für      |
//| den OnTick-Handler. Die Box wird beim nächsten H4-Kerzenschluss  |
//| in AssetVerarbeiten() automatisch neu berechnet.                 |
//|                                                                  |
//| Bestehende BoxHigh/BoxLow/BoxMedian bleiben erhalten             |
//| (letzte bekannte Box) und werden beim nächsten Bar aktualisiert. |
//+------------------------------------------------------------------+
void BoxEngine_TransitionToNone_Fast(S_AssetContext &ctx)
{
   string vonZustand;
   switch(ctx.CurrentState)
   {
      case STATE_TREND: vonZustand = "TREND"; break;
      case STATE_TRAP:  vonZustand = "TRAP";  break;
      default:          vonZustand = "?";     break;
   }

   // Trade- und Zustandsfelder zurücksetzen
   ctx.CurrentState       = STATE_NONE;
   ctx.ActiveDirection    = DIR_NONE;
   ctx.TicketID           = 0;
   ctx.EntryPrice         = 0.0;
   ctx.InitialSL          = 0.0;
   ctx.InitialRiskPoints  = 0.0;
   ctx.TrendCandleCounter = 0;
   ctx.HasActiveInsideBox = false;
   ctx.InsideBoxHigh      = 0.0;
   ctx.InsideBoxLow       = 0.0;
   ctx.HasActiveMinorBox  = false;
   ctx.MinorBoxHigh       = 0.0;
   ctx.MinorBoxLow        = 0.0;
   ctx.MinorBoxMedian     = 0.0;
   ctx.MinorBoxHeight     = 0.0;
   // BoxHigh/BoxLow/BoxMedian/BoxHeight bleiben erhalten!

   LOG_I(ctx.SymbolName, StringFormat(
         "Schnell-Reset: %s → WARTEN "
         "(Box-Neuberechnung beim nächsten Kerzenschluss)",
         vonZustand));
}

//+------------------------------------------------------------------+
//| Zustandswechsel: WARTEN → TREND                                  |
//|                                                                  |
//| Wird aufgerufen nachdem eine Trendfolge-Order erfolgreich        |
//| ausgeführt wurde.                                                |
//|                                                                  |
//| Parameter:                                                       |
//|   ctx    - Asset-Kontext                                         |
//|   dir    - Handelsrichtung (Long oder Short)                     |
//|   ticket - Ticket-Nummer der geöffneten Position                 |
//|   entry  - Tatsächlicher Einstiegspreis                          |
//|   sl     - Initialer Stop-Loss-Preis                             |
//+------------------------------------------------------------------+
void BoxEngine_TransitionToTrend(S_AssetContext  &ctx,
                                  ENUM_TRADE_DIR   dir,
                                  ulong            ticket,
                                  double           entry,
                                  double           sl)
{
   ctx.CurrentState      = STATE_TREND;
   ctx.ActiveDirection   = dir;
   ctx.TicketID          = ticket;
   ctx.EntryPrice        = entry;
   ctx.InitialSL         = sl;
   // Risiko in Punkten für Break-Even und Trailing-Berechnung
   ctx.InitialRiskPoints = MathAbs(entry - sl) / ctx.PointSize;
   ctx.TrendCandleCounter = 0;
   // Chandelier: Höchst-/Tiefstkurs mit Einstiegspreis initialisieren
   ctx.TradeHighestPrice = entry;
   ctx.TradeLowestPrice  = entry;

   // Kanten-Riegel für die genutzte Seite setzen
   if(dir == DIR_LONG)  ctx.UpperEdgeLocked = true;
   if(dir == DIR_SHORT) ctx.LowerEdgeLocked = true;

   LOG_I(ctx.SymbolName, StringFormat(
         "Zustandswechsel: WARTEN → TREND [%s] | "
         "Ticket: %llu | Einstieg: %.5f | SL: %.5f | Risiko: %.1f Punkte",
         (dir == DIR_LONG) ? "LONG" : "SHORT",
         ticket, entry, sl, ctx.InitialRiskPoints));
}

//+------------------------------------------------------------------+
//| Zustandswechsel: TREND → TRAP (Fehlausbruch erkannt)            |
//+------------------------------------------------------------------+
//| Wird aufgerufen wenn SignalFilter_CheckTrapReversal() true        |
//| zurückgibt und die Gegenposition erfolgreich eröffnet wurde.     |
//+------------------------------------------------------------------+
void BoxEngine_TransitionToTrap(S_AssetContext  &ctx,
                                 ENUM_TRADE_DIR   dir,
                                 ulong            ticket,
                                 double           entry,
                                 double           sl)
{
   ctx.CurrentState      = STATE_TRAP;
   ctx.ActiveDirection   = dir;
   ctx.TicketID          = ticket;
   ctx.EntryPrice        = entry;
   ctx.InitialSL         = sl;
   ctx.InitialRiskPoints = MathAbs(entry - sl) / ctx.PointSize;
   ctx.TrendCandleCounter = 0;
   ctx.HasActiveInsideBox = false;
   // Chandelier: Höchst-/Tiefstkurs mit Einstiegspreis initialisieren
   ctx.TradeHighestPrice = entry;
   ctx.TradeLowestPrice  = entry;

   LOG_I(ctx.SymbolName, StringFormat(
         "Zustandswechsel: TREND → TRAP [%s] | "
         "Ticket: %llu | Einstieg: %.5f | SL: %.5f",
         (dir == DIR_LONG) ? "LONG" : "SHORT",
         ticket, entry, sl));
}

#endif // UB_BOXENGINE_MQH