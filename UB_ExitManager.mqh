//+------------------------------------------------------------------+
//|                                                                  |
//|  EA-Name    : THE UNBESTECHLICH EA                               |
//|  Datei      : UB_ExitManager.mqh                                 |
//|  Modul      : Stop-Loss, Break-Even und Trailing-Verwaltung      |
//|  Version    : 5.2.4                                              |
//|  Datum      : 2026-06-05                                         |
//|
//|  Versionshistorie:                                               |
//|  v4.0 - Erstimplementierung                                      |
//|          Break-Even korrekt für Long UND Short implementiert     |
//|          Smart-Body-Trailing mit Inside-Bar-Ausschluss            |
//|          STOPS_LEVEL-Beachtung bei jeder SL-Modifikation         |
//|          Inside-Box-Trailing für den Trap-Modus                  |
//|  v4.1 - Include-Guards, %llu, UB_Globals, deutsche Kommentierung |
//|  v4.2 - Tote Array-Variablen entfernt (open2/close2/high2/low2) |
//|          ExitMgr_CalcInitialStops erhält direction als Parameter  |
//|          StopsLevelPrice aus gecachtem ctx-Wert                  |
//|  v5.2 - ExitMgr_ModifySL_NoSelect() für doppelte Select-Vermeid. |
//|          ExitMgr_ModifySL() als öffentliche Wrapper-Funktion     |
//|          (double)-Cast für g_TrapTakeProfitMargin                |
//|          PositionSelectByTicket() Doppelaufruf eliminiert        |
//|  v5.2.1 - Versionsnummer aktualisiert                            |
//|  v5.2.2 - Smart-Body-Trailing auch für STATE_TRAP freigegeben   |
//|           ExitMgr_SmartBodyTrailing() akzeptiert jetzt Trap      |
//|  v5.2.3 - CalcInitialStops: SL an MinorBoxMedian wenn Minor-Box  |
//|           SmartBodyTrailing: löst Minor-Box bei Fortschritt auf   |
//|  v5.2.4 - ExitMgr_ChandelierTrailing() neu (ATR-basiert)       |
//|                                                                  |
//|  Zweck:                                                          |
//|  Verwaltet alle Änderungen an bestehenden Positionen:            |
//|  - Initialen SL und TP beim Handelseinstieg berechnen            |
//|  - Break-Even setzen sobald Mindestgewinn erreicht               |
//|  - Smart-Body-Trailing im Trend-Modus (nur bei echter Bewegung)  |
//|  - Inside-Box-Trailing im Trap-Modus                             |
//|  - Positions-Existenz prüfen (SL/TP ausgelöst?)                 |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef UB_EXITMANAGER_MQH
#define UB_EXITMANAGER_MQH

#include "UB_Globals.mqh"
#include "UB_Logger.mqh"
#include "UB_TradeExecutor.mqh"

//+------------------------------------------------------------------+
//| INTERNER Helfer: SL modifizieren OHNE erneuten Select            |
//|                                                                  |
//| Diese Funktion darf NUR aufgerufen werden wenn die Position      |
//| bereits über PositionSelectByTicket() selektiert ist!            |
//| Spart einen redundanten API-Aufruf wenn der Aufrufer bereits     |
//| selektiert hat (z.B. ExitMgr_CheckBreakEven, SmartBodyTrailing). |
//|                                                                  |
//| Führt alle nötigen Sicherheitsprüfungen durch:                   |
//|   - STOPS_LEVEL-Mindestabstand (aus gecachtem StopsLevelPrice)   |
//|   - Richtungsvalidierung (SL darf nicht auf falscher Seite sein) |
//|   - Keine unnötige Modifikation bei minimaler Änderung           |
//+------------------------------------------------------------------+
bool ExitMgr_ModifySL_NoSelect(S_AssetContext &ctx,
                                double          newSL,
                                double          newTP = 0.0)
{
   // Aktuellen Marktpreis für Richtungs- und Abstandsprüfung
   double aktuellerPreis = (ctx.ActiveDirection == DIR_LONG)
                           ? SymbolInfoDouble(ctx.SymbolName, SYMBOL_BID)
                           : SymbolInfoDouble(ctx.SymbolName, SYMBOL_ASK);

   // STOPS_LEVEL: SL zu nah am Preis? → Auf Mindestabstand korrigieren
   double minAbstand = ctx.StopsLevelPrice;
   if(MathAbs(aktuellerPreis - newSL) < minAbstand)
   {
      newSL = (ctx.ActiveDirection == DIR_LONG)
               ? aktuellerPreis - minAbstand
               : aktuellerPreis + minAbstand;
      LOG_D(ctx.SymbolName, StringFormat(
            "SL auf STOPS_LEVEL-Mindestabstand korrigiert: %.5f", newSL));
   }

   // Richtungsvalidierung: SL niemals auf der falschen Seite des Preises
   if(ctx.ActiveDirection == DIR_LONG && newSL >= aktuellerPreis)
   {
      LOG_W(ctx.SymbolName,
            "SL-Modifikation abgebrochen: LONG-SL über aktuellem Preis");
      return false;
   }
   if(ctx.ActiveDirection == DIR_SHORT && newSL <= aktuellerPreis)
   {
      LOG_W(ctx.SymbolName,
            "SL-Modifikation abgebrochen: SHORT-SL unter aktuellem Preis");
      return false;
   }

   // Aktuellen SL und TP aus der selektierten Position lesen
   double aktuellerSL = PositionGetDouble(POSITION_SL);
   double aktuellerTP = (newTP > 0.0)
                        ? newTP
                        : PositionGetDouble(POSITION_TP);

   // Keine Modifikation wenn Änderung unter Toleranzschwelle (0.1 Punkte)
   if(MathAbs(newSL - aktuellerSL) < ctx.PointSize * 0.1)
      return true;   // Keine Änderung nötig — kein Fehler

   // CTrade mit korrekter Magic Number konfigurieren
   g_Trade.SetExpertMagicNumber(ctx.MagicNumber);

   if(g_Trade.PositionModify(ctx.TicketID, newSL, aktuellerTP))
   {
      LOG_I(ctx.SymbolName, StringFormat(
            "SL angepasst: %.5f → %.5f",
            aktuellerSL, newSL));
      return true;
   }

   LOG_W(ctx.SymbolName, StringFormat(
         "SL-Modifikation fehlgeschlagen: Fehlercode %d — %s",
         g_Trade.ResultRetcode(),
         (g_Trade.ResultRetcode() == 10016) ? "STOPS_LEVEL-Verletzung" : ""));
   return false;
}

//+------------------------------------------------------------------+
//| ÖFFENTLICHE Funktion: SL modifizieren MIT eigenem Select         |
//|                                                                  |
//| Für alle Aufrufe die NICHT bereits eine Position selektiert      |
//| haben. Führt PositionSelectByTicket() selbst durch.              |
//| Wrapper um ExitMgr_ModifySL_NoSelect().                          |
//+------------------------------------------------------------------+
bool ExitMgr_ModifySL(S_AssetContext &ctx,
                       double          newSL,
                       double          newTP = 0.0)
{
   if(ctx.TicketID == 0)
      return false;

   if(!PositionSelectByTicket(ctx.TicketID))
   {
      LOG_W(ctx.SymbolName, StringFormat(
            "ModifySL: Position %llu nicht gefunden", ctx.TicketID));
      return false;
   }

   // Delegate an interne Funktion (kein erneuter Select)
   return ExitMgr_ModifySL_NoSelect(ctx, newSL, newTP);
}

//+------------------------------------------------------------------+
//| Initialen Stop-Loss und Take-Profit berechnen                    |
//|                                                                  |
//| TREND-Modus:                                                     |
//|   SL liegt an der Boxmitte (BoxMedian) ± Spread-Puffer           |
//|   TP: 0 (kein fester TP — Ausstieg über Smart-Body-Trailing)     |
//|                                                                  |
//| TRAP-Modus:                                                      |
//|   SL liegt am Tief (Long) bzw. Hoch (Short) der Trap-Kerze       |
//|   TP liegt mit Front-Running-Schutz vor der Boxgrenze            |
//|   (nicht bis zur Boxgrenze — verhindert Stop-Hunting)            |
//|                                                                  |
//| Parameter:                                                       |
//|   ctx            - Asset-Kontext (BoxMedian, BoxHigh/Low etc.)   |
//|   tradeState     - STATE_TREND oder STATE_TRAP                   |
//|   direction      - Handelsrichtung (explizit — ctx nicht ändern!)  |
//|   entryPrice     - Geplanter Einstiegspreis                      |
//|   trapCandleHigh - Hoch der Trap-Kerze (nur TRAP relevant)       |
//|   trapCandleLow  - Tief der Trap-Kerze (nur TRAP relevant)       |
//|   outSL          - Ausgabe: berechneter SL-Preis                 |
//|   outTP          - Ausgabe: berechneter TP-Preis (0 = kein TP)   |
//+------------------------------------------------------------------+
void ExitMgr_CalcInitialStops(const S_AssetContext &ctx,
                               ENUM_EA_STATE         tradeState,
                               ENUM_TRADE_DIR        direction,
                               double                entryPrice,
                               double                trapCandleHigh,
                               double                trapCandleLow,
                               double                &outSL,
                               double                &outTP)
{
   // Puffer in Preiseinheiten (gecachten PointSize nutzen)
   double puffer = g_SpreadBufferPoints * ctx.PointSize;

   // Standard: Kein fester Take-Profit
   outTP = 0.0;

   if(tradeState == STATE_TREND)
   {
      if(ctx.HasActiveMinorBox)
      {
         // Minor-Box aktiv: SL an MinorBoxMedian (enger SL innerhalb Major-Box)
         outSL = (direction == DIR_LONG)
                  ? ctx.MinorBoxMedian - puffer
                  : ctx.MinorBoxMedian + puffer;
      }
      else
      {
         // Keine Minor-Box: SL an Major-BoxMedian (Fallback)
         outSL = (direction == DIR_LONG)
                  ? ctx.BoxMedian - puffer
                  : ctx.BoxMedian + puffer;
      }
      // Kein TP: Ausstieg erfolgt ausschließlich über Smart-Body-Trailing
   }
   else // STATE_TRAP
   {
      if(direction == DIR_LONG)
      {
         // Trap-Long: SL unter dem Tief der Fallenkerze
         outSL = trapCandleLow - puffer;

         // TP mit Front-Running-Schutz — nicht bis zur BoxHigh Grenze!
         // (double)-Cast verhindert int-Truncation bei der Prozent-Berechnung
         outTP = ctx.BoxHigh - (ctx.BoxHeight *
                                ((double)g_TrapTakeProfitMargin / 100.0));
      }
      else // DIR_SHORT
      {
         // Trap-Short: SL über dem Hoch der Fallenkerze
         outSL = trapCandleHigh + puffer;

         // TP mit Front-Running-Schutz — nicht bis zur BoxLow Grenze!
         outTP = ctx.BoxLow + (ctx.BoxHeight *
                               ((double)g_TrapTakeProfitMargin / 100.0));
      }
   }
}

//+------------------------------------------------------------------+
//| Break-Even prüfen und setzen                                     |
//|                                                                  |
//| Sobald der Trade ein Gewinn-Risiko-Verhältnis von                 |
//| BreakEvenRatio × InitialRisk erreicht hat, wird der SL auf den   |
//| Einstiegspreis gesetzt (± aktueller Spread für minimalen         |
//| Restgewinn).                                                     |
//|                                                                  |
//| Long:  BE-SL = EntryPrice + Spread (knapp über Einstieg)         |
//| Short: BE-SL = EntryPrice - Spread (knapp unter Einstieg)        |
//|                                                                  |
//| Wichtig: SL wird nur in die vorteilhafte Richtung bewegt.        |
//| Long: SL nur erhöhen. Short: SL nur senken.                      |
//|                                                                  |
//| Wird in OnTick() aufgerufen für schnelle Reaktion.               |
//| Nutzt einmaligen PositionSelectByTicket() und dann               |
//| ExitMgr_ModifySL_NoSelect() für keine Doppel-Selects.            |
//+------------------------------------------------------------------+
void ExitMgr_CheckBreakEven(S_AssetContext &ctx)
{
   if(ctx.TicketID == 0 || ctx.InitialRiskPoints <= 0.0)
      return;

   // Einmalig selektieren (ExitMgr_ModifySL_NoSelect() macht keinen weiteren)
   if(!PositionSelectByTicket(ctx.TicketID))
      return;

   double ask          = SymbolInfoDouble(ctx.SymbolName, SYMBOL_ASK);
   double bid          = SymbolInfoDouble(ctx.SymbolName, SYMBOL_BID);
   double spread       = ask - bid;
   double aktuellerSL  = PositionGetDouble(POSITION_SL);
   double beTriggerPkt = ctx.InitialRiskPoints * g_BreakEvenRatio;

   if(ctx.ActiveDirection == DIR_LONG)
   {
      // Gewinn in Punkten: Bid (Verkaufskurs für Long) minus Einstieg
      double gewinnPkt = (bid - ctx.EntryPrice) / ctx.PointSize;

      if(gewinnPkt >= beTriggerPkt)
      {
         // Break-Even Long: SL auf Entry + Spread (minimaler Restgewinn)
         double beSL = ctx.EntryPrice + spread;

         // Nur hochziehen wenn neuer SL über aktuellem SL liegt
         if(beSL > aktuellerSL + ctx.PointSize)
         {
            LOG_I(ctx.SymbolName, StringFormat(
                  "Break-Even LONG gesetzt: SL → %.5f "
                  "(Gewinn: %.1f Pkte, Auslöser: %.1f Pkte)",
                  beSL, gewinnPkt, beTriggerPkt));
            // Kein erneuter Select — bereits oben selektiert
            ExitMgr_ModifySL_NoSelect(ctx, beSL);
         }
      }
   }
   else if(ctx.ActiveDirection == DIR_SHORT)
   {
      // Gewinn in Punkten: Einstieg minus Ask (Kaufkurs für Short)
      double gewinnPkt = (ctx.EntryPrice - ask) / ctx.PointSize;

      if(gewinnPkt >= beTriggerPkt)
      {
         // Break-Even Short: SL auf Entry - Spread (minimaler Restgewinn)
         // KORREKT: Short-BE liegt UNTER dem Einstiegspreis!
         double beSL = ctx.EntryPrice - spread;

         // Nur runterziehen wenn neuer SL unter aktuellem SL liegt
         if(beSL < aktuellerSL - ctx.PointSize)
         {
            LOG_I(ctx.SymbolName, StringFormat(
                  "Break-Even SHORT gesetzt: SL → %.5f "
                  "(Gewinn: %.1f Pkte, Auslöser: %.1f Pkte)",
                  beSL, gewinnPkt, beTriggerPkt));
            ExitMgr_ModifySL_NoSelect(ctx, beSL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Smart-Body-Trailing (nur im TREND-Modus)                         |
//|                                                                  |
//| Zieht den SL nach wenn der Preis echten Fortschritt macht.       |
//| "Echter Fortschritt" bedeutet: Die neue Kerze schließt über dem  |
//| Hoch der Vorgängerkerze (Long) bzw. unter dem Tief (Short).      |
//|                                                                  |
//| Inside-Bar-Schutz: Liegt der Körper der neuen Kerze vollständig  |
//| innerhalb des Körpers der Vorgängerkerze → SL wird NICHT bewegt. |
//| Er bleibt am Extremwert der Vorgängerkerze verankert.            |
//|                                                                  |
//| SL-Anker: Tief der Vorgängerkerze (Long) oder                    |
//|           Hoch der Vorgängerkerze (Short) ± Spread-Puffer        |
//|                                                                  |
//| Index-Konvention (ArraySetAsSeries=true):                        |
//|   arrXxx[0] = letzte abgeschl. H4-Kerze (Serienindex [1])        |
//|   arrXxx[1] = vorletzte abgeschl. H4-Kerze (Serienindex [2])     |
//|                                                                  |
//| Wird in OnTimer() bei neuer Kerze aufgerufen.                    |
//| Nutzt PositionSelectByTicket() einmalig und dann _NoSelect().    |
//+------------------------------------------------------------------+
void ExitMgr_SmartBodyTrailing(S_AssetContext &ctx)
{
   if(!g_UseSmartBodyTrailing)  return;
   if(ctx.TicketID == 0 || (ctx.CurrentState != STATE_TREND && ctx.CurrentState != STATE_TRAP)) return;

   // Position selektieren (einmalig — _NoSelect() macht keinen weiteren)
   if(!PositionSelectByTicket(ctx.TicketID)) return;

   // Zwei abgeschlossene H4-Kerzen abrufen
   // arrXxx[0] = Kerze [1] (jüngste abgeschlossen)
   // arrXxx[1] = Kerze [2] (Vorgänger)
   double arrOpen[], arrClose[], arrHigh[], arrLow[];
   ArraySetAsSeries(arrOpen,  true);
   ArraySetAsSeries(arrClose, true);
   ArraySetAsSeries(arrHigh,  true);
   ArraySetAsSeries(arrLow,   true);

   // CopyXxx ab Serienindex 1 (nicht 0 = laufende Kerze)
   if(CopyOpen (ctx.SymbolName, PERIOD_H4, 1, 2, arrOpen)  < 2) return;
   if(CopyClose(ctx.SymbolName, PERIOD_H4, 1, 2, arrClose) < 2) return;
   if(CopyHigh (ctx.SymbolName, PERIOD_H4, 1, 2, arrHigh)  < 2) return;
   if(CopyLow  (ctx.SymbolName, PERIOD_H4, 1, 2, arrLow)   < 2) return;

   double puffer      = g_SpreadBufferPoints * ctx.PointSize;
   double aktuellerSL = PositionGetDouble(POSITION_SL);

   // Körpergrenzen berechnen (für Inside-Bar-Erkennung)
   // Aktuelle Kerze: arrXxx[0] (= Serienindex [1])
   double koerperHochAkt  = MathMax(arrOpen[0], arrClose[0]);
   double koerperTiefAkt  = MathMin(arrOpen[0], arrClose[0]);
   // Vorgängerkerze: arrXxx[1] (= Serienindex [2])
   double koerperHochVorg = MathMax(arrOpen[1], arrClose[1]);
   double koerperTiefVorg = MathMin(arrOpen[1], arrClose[1]);

   if(ctx.ActiveDirection == DIR_LONG)
   {
      // Fortschritt prüfen: Schließt aktuelle Kerze über dem Hoch des Vorgängers?
      if(arrClose[0] <= arrHigh[1])
      {
         LOG_D(ctx.SymbolName,
               "Smart-Trailing LONG: Kein Fortschritt (Schluss ≤ Hoch[2])");
         return;
      }

      // Inside-Bar-Schutz: Liegt Körper[1] komplett in Körper[2]?
      if(koerperHochAkt <= koerperHochVorg &&
         koerperTiefAkt >= koerperTiefVorg)
      {
         LOG_D(ctx.SymbolName,
               "Smart-Trailing LONG: Inside-Bar erkannt — SL bleibt stabil");
         return;
      }

      // Fortschritt bestätigt: Minor-Box ggf. auflösen
      if(ctx.HasActiveMinorBox)
      {
         ctx.HasActiveMinorBox = false;
         LOG_I(ctx.SymbolName, "Minor-Box aufgelöst — Fortschritt bestätigt");
      }

      // SL unter das Tief der Vorgängerkerze setzen (mit Spread-Puffer)
      double neuerSL = arrLow[1] - puffer;

      // Nur hochziehen wenn neuer SL über aktuellem liegt
      if(neuerSL > aktuellerSL + ctx.PointSize)
      {
         LOG_I(ctx.SymbolName, StringFormat(
               "Smart-Trailing LONG: SL %.5f → %.5f",
               aktuellerSL, neuerSL));
         ExitMgr_ModifySL_NoSelect(ctx, neuerSL);
      }
   }
   else if(ctx.ActiveDirection == DIR_SHORT)
   {
      // Fortschritt prüfen: Schließt aktuelle Kerze unter dem Tief des Vorgängers?
      if(arrClose[0] >= arrLow[1])
      {
         LOG_D(ctx.SymbolName,
               "Smart-Trailing SHORT: Kein Fortschritt (Schluss ≥ Tief[2])");
         return;
      }

      // Inside-Bar-Schutz
      if(koerperHochAkt <= koerperHochVorg &&
         koerperTiefAkt >= koerperTiefVorg)
      {
         LOG_D(ctx.SymbolName,
               "Smart-Trailing SHORT: Inside-Bar erkannt — SL bleibt stabil");
         return;
      }

      // Fortschritt bestätigt: Minor-Box ggf. auflösen
      if(ctx.HasActiveMinorBox)
      {
         ctx.HasActiveMinorBox = false;
         LOG_I(ctx.SymbolName, "Minor-Box aufgelöst — Fortschritt bestätigt");
      }

      // SL über das Hoch der Vorgängerkerze setzen
      double neuerSL = arrHigh[1] + puffer;

      // Nur runterziehen wenn neuer SL unter aktuellem liegt
      if(neuerSL < aktuellerSL - ctx.PointSize)
      {
         LOG_I(ctx.SymbolName, StringFormat(
               "Smart-Trailing SHORT: SL %.5f → %.5f",
               aktuellerSL, neuerSL));
         ExitMgr_ModifySL_NoSelect(ctx, neuerSL);
      }
   }
}

//+------------------------------------------------------------------+
//| ATR-Chandelier Trailing (Trend + Trap, ergänzend zu SmartBody)  |
//|                                                                  |
//| Berechnet einen volatilitätsbasierten SL:                         |
//|   Long:  SL = TradeHighestPrice - Faktor × H4-ATR                |
//|   Short: SL = TradeLowestPrice  + Faktor × H4-ATR                |
//|                                                                  |
//| Der Chandelier greift nur wenn sein SL enger ist als der         |
//| aktuelle SL (schnellerer Nachzug bei starken Bewegungen).        |
//| Bei 0.0 deaktiviert (nur Smart-Body-Trailing aktiv).             |
//|                                                                  |
//| TradeHighestPrice/LowestPrice wird in OnTick tick-genau          |
//| aktualisiert.                                                    |
//+------------------------------------------------------------------+
void ExitMgr_ChandelierTrailing(S_AssetContext &ctx)
{
   if(g_ChandelierATR_Factor <= 0.0)
      return;
   if(ctx.TicketID == 0)
      return;
   if(ctx.CurrentState != STATE_TREND && ctx.CurrentState != STATE_TRAP)
      return;

   // H4-ATR abrufen (Handle in OnInit erstellt)
   if(ctx.ATR_Handle_H4 == INVALID_HANDLE)
      return;
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(ctx.ATR_Handle_H4, 0, 1, 1, atrBuf) < 1)
      return;

   double h4ATR     = atrBuf[0];
   double abstand   = g_ChandelierATR_Factor * h4ATR;
   double neuerSL   = 0.0;

   if(ctx.ActiveDirection == DIR_LONG)
   {
      // Chandelier: Höchstkurs minus ATR-Abstand
      neuerSL = ctx.TradeHighestPrice - abstand;

      // Nicht unter InitialSL fallen (Trade würde sonst mehr riskieren)
      if(neuerSL < ctx.InitialSL - ctx.PointSize)
         neuerSL = ctx.InitialSL;
   }
   else if(ctx.ActiveDirection == DIR_SHORT)
   {
      // Chandelier: Tiefstkurs plus ATR-Abstand
      neuerSL = ctx.TradeLowestPrice + abstand;

      // Nicht über InitialSL steigen
      if(neuerSL > ctx.InitialSL + ctx.PointSize)
         neuerSL = ctx.InitialSL;
   }
   else
      return;

   if(neuerSL > 0.0)
   {
      LOG_D(ctx.SymbolName, StringFormat(
            "Chandelier [%s]: Höchst=%.5f | ATR=%.5f | Ziel-SL=%.5f",
            (ctx.ActiveDirection == DIR_LONG) ? "LONG" : "SHORT",
            (ctx.ActiveDirection == DIR_LONG) ? ctx.TradeHighestPrice : ctx.TradeLowestPrice,
            h4ATR, neuerSL));
      ExitMgr_ModifySL(ctx, neuerSL);
   }
}

//+------------------------------------------------------------------+
//| Inside-Box-Trailing (nur im TRAP-Modus, nur bei aktiver Zone)    |
//|                                                                  |
//| Sobald im Trap-Modus eine Mikro-Konsolidierungszone erkannt      |
//| wurde (HasActiveInsideBox = true durch Outside-Bar im TRAP),     |
//| wird der SL an die Grenze dieser Zone gezogen.                   |
//|                                                                  |
//| Short-Trap: SL = InsideBoxHigh + Puffer                          |
//| Long-Trap:  SL = InsideBoxLow  - Puffer                          |
//+------------------------------------------------------------------+
void ExitMgr_InsideBoxTrailing(S_AssetContext &ctx)
{
   // Nur ausführen wenn aktive Mikro-Zone vorhanden
   if(!ctx.HasActiveInsideBox) return;
   if(ctx.CurrentState != STATE_TRAP) return;
   if(ctx.TicketID == 0) return;

   double puffer  = g_SpreadBufferPoints * ctx.PointSize;
   double neuerSL = 0.0;

   if(ctx.ActiveDirection == DIR_SHORT)
      // Short: SL über die obere Grenze der Mikro-Zone
      neuerSL = ctx.InsideBoxHigh + puffer;
   else
      // Long: SL unter die untere Grenze der Mikro-Zone
      neuerSL = ctx.InsideBoxLow - puffer;

   if(neuerSL > 0.0)
   {
      LOG_I(ctx.SymbolName, StringFormat(
            "InsideBox-Trailing [%s]: SL → %.5f",
            (ctx.ActiveDirection == DIR_SHORT) ? "SHORT" : "LONG",
            neuerSL));
      // Vollständiger Select da kein vorheriger Select vorhanden
      ExitMgr_ModifySL(ctx, neuerSL);
   }
}

//+------------------------------------------------------------------+
//| Positions-Existenz prüfen                                        |
//|                                                                  |
//| Gibt false zurück wenn die Position durch SL, TP oder manuelles  |
//| Schließen nicht mehr vorhanden ist.                              |
//| Intern: PositionSelectByTicket() — true wenn Position existiert. |
//+------------------------------------------------------------------+
bool ExitMgr_IsPositionOpen(const S_AssetContext &ctx)
{
   if(ctx.TicketID == 0)
      return false;
   return PositionSelectByTicket(ctx.TicketID);
}

#endif // UB_EXITMANAGER_MQH