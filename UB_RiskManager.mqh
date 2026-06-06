//+------------------------------------------------------------------+
//|                                                                  |
//|  EA-Name    : THE UNBESTECHLICH EA                               |
//|  Datei      : UB_RiskManager.mqh                                 |
//|  Modul      : Risikomanagement, Positionsgrößen, Killswitch       |
//|  Version    : 5.2.6                                              |
//|  Datum      : 2026-06-05                                         |
//|                                                                  |
//|  Versionshistorie:                                               |
//|  v4.0 - Erstimplementierung                                      |
//|          Korrekte Lotformel: Risk / (SLDist/TickSize × TickValue) |
//|          GlobalVariable-Persistenz für Balance-Snapshots         |
//|          Magic-Number-gefilterter Positionszähler                |
//|  v4.1 - Include-Guards, UB_Globals.mqh, deutsche Kommentierung   |
//|  v4.2 - Doppelte PositionsTotal()-Schleife zu einer zusammengef. |
//|          Floating-Loss und Trade-Zählung in einem Durchlauf      |
//|  v5.0 - Per-Asset-MaxSpread über ctx.MaxSpreadOverride           |
//|          Lot-Plausibilitätsprüfung für Indizes und Rohstoffe      |
//|          MaxSameDirTrades-Prüfung (Korrelationsschutz)           |
//|          RiskMgr_IsTradingAllowed() erhält ENUM_TRADE_DIR param. |
//|  v5.2.1 - Versionsnummer aktualisiert                            |
//|  v5.2.5 - Korrelationsgruppen-Prüfung (newGroup-Parameter)     |
//|  v5.2.6 - Risikolimits EUR → Prozent (skaliert mit Konto)     |
//|                                                                  |
//|  Zweck:                                                          |
//|  Enthält alle Schutzfunktionen vor übermäßigem Risiko:           |
//|  1. Tages- und Wochenverlustlimit (mit Persistenz über Neustarts) |
//|  2. Maximaler gleichzeitiger Buchverlust                         |
//|  3. Maximale Anzahl offener Trades                               |
//|  4. Maximale gleichzeitige Trades in dieselbe Richtung           |
//|  5. Korrekte, symbol-spezifische Lotberechnung                   |
//|  6. Spread-Überprüfung vor dem Trade                             |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef UB_RISKMANAGER_MQH
#define UB_RISKMANAGER_MQH

#include "UB_Globals.mqh"
#include "UB_Logger.mqh"

//+------------------------------------------------------------------+
//| Tages- und Wochen-Kontostand sichern                             |
//|                                                                  |
//| Speichert den Kontostand jeweils einmal pro Tag (um Mitternacht) |
//| und einmal pro Woche (montags) als GlobalVariable.               |
//| GlobalVariables überleben EA-Neustarts und Terminal-Abstürze.    |
//| Muss einmal pro OnTimer-Zyklus aufgerufen werden.                |
//+------------------------------------------------------------------+
void RiskMgr_UpdateBalanceSnapshots()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   // Eindeutiger Schlüssel für den heutigen Tages-Snapshot
   string dayKey = StringFormat("UB_DayBal_%d%02d%02d",
                                 dt.year, dt.mon, dt.day);

   // Letzten Montag berechnen für den Wochen-Schlüssel
   // day_of_week: 0=Sonntag, 1=Montag, ..., 6=Samstag
   int daysToMonday = (dt.day_of_week == 0) ? 6 : (dt.day_of_week - 1);
   datetime mondayTime = TimeCurrent() - (datetime)(daysToMonday * 86400);
   MqlDateTime mondayDt;
   TimeToStruct(mondayTime, mondayDt);
   string weekKey = StringFormat("UB_WeekBal_%d%02d%02d",
                                  mondayDt.year, mondayDt.mon, mondayDt.day);

   // Tages-Snapshot: Nur einmal pro Tag speichern
   if(!GlobalVariableCheck(dayKey))
   {
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      GlobalVariableSet(dayKey, bal);
      LOG_I("RISIKO", StringFormat(
            "Tages-Startkontostand gesichert: %.2f", bal));
   }

   // Wochen-Snapshot: Nur einmal pro Woche (montags) speichern
   if(!GlobalVariableCheck(weekKey))
   {
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      GlobalVariableSet(weekKey, bal);
      LOG_I("RISIKO", StringFormat(
            "Wochen-Startkontostand gesichert: %.2f", bal));
   }
}

//+------------------------------------------------------------------+
//| Tages-Startkontostand abrufen                                    |
//|                                                                  |
//| Rückgabe: Gespeicherter Kontostand von 00:00 Uhr heute.          |
//|           Fallback auf aktuellen Kontostand wenn noch nicht      |
//|           gespeichert (z.B. erster EA-Start des Tages).          |
//+------------------------------------------------------------------+
double RiskMgr_GetDayStartBalance()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string dayKey = StringFormat("UB_DayBal_%d%02d%02d",
                                 dt.year, dt.mon, dt.day);
   if(GlobalVariableCheck(dayKey))
      return GlobalVariableGet(dayKey);

   // Noch kein Snapshot vorhanden: Aktuellen Kontostand als Fallback
   return AccountInfoDouble(ACCOUNT_BALANCE);
}

//+------------------------------------------------------------------+
//| Wochen-Startkontostand abrufen                                   |
//+------------------------------------------------------------------+
double RiskMgr_GetWeekStartBalance()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int daysToMonday    = (dt.day_of_week == 0) ? 6 : (dt.day_of_week - 1);
   datetime mondayTime = TimeCurrent() - (datetime)(daysToMonday * 86400);
   MqlDateTime mondayDt;
   TimeToStruct(mondayTime, mondayDt);
   string weekKey = StringFormat("UB_WeekBal_%d%02d%02d",
                                  mondayDt.year, mondayDt.mon, mondayDt.day);
   if(GlobalVariableCheck(weekKey))
      return GlobalVariableGet(weekKey);
   return AccountInfoDouble(ACCOUNT_BALANCE);
}

//+------------------------------------------------------------------+
//| Schutzprüfung (Killswitch) vor jeder neuen Order                 |
//|                                                                  |
//| Prüft vier Schutzbedingungen in dieser Reihenfolge:             |
//|   1. Tages-Verlustlimit                                          |
//|   2. Wochen-Verlustlimit                                         |
//|   3. Maximaler gleichzeitiger Buchverlust                        |
//|   4. Maximale Anzahl offener Trades                              |
//|   5. Maximale Trades in dieselbe Richtung (Korrelationsschutz)   |
//|                                                                  |
//| Parameter:                                                       |
//|   symbol       - Zu prüfendes Handelssymbol (nur für Logging)    |
//|   magicNumber  - Magic Number des EA (filtert eigene Positionen)  |
//|   newDirection - Richtung des geplanten Trades (für Korr.schutz) |
//|   outReason    - Ausgabe: Klartext-Ablehnungsgrund               |
//| Rückgabe: true = Handel erlaubt | false = Handel gesperrt        |
//+------------------------------------------------------------------+
bool RiskMgr_IsTradingAllowed(const string        symbol,
                               const ulong          magicNumber,
                               const ENUM_TRADE_DIR newDirection,
                               string               &outReason,
                               const ENUM_SYMBOL_TYPE newGroup = SYMTYPE_UNKNOWN)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   // --- Prüfung 1: Tages-Verlustlimit ---
   double dayBal  = RiskMgr_GetDayStartBalance();
   double dayLoss = dayBal - equity;
   double dayLimit = dayBal * (g_MaxDailyDD_Pct / 100.0);
   if(dayLoss >= dayLimit)
   {
      outReason = StringFormat(
            "Tages-Verlustlimit: %.2f (%.1f%%) verloren (Limit: %.1f%%)",
            dayLoss, (dayLoss / dayBal * 100.0), g_MaxDailyDD_Pct);
      return false;
   }

   // --- Prüfung 2: Wochen-Verlustlimit ---
   double weekBal  = RiskMgr_GetWeekStartBalance();
   double weekLoss = weekBal - equity;
   double weekLimit = weekBal * (g_MaxWeeklyDD_Pct / 100.0);
   if(weekLoss >= weekLimit)
   {
      outReason = StringFormat(
            "Wochen-Verlustlimit: %.2f (%.1f%%) verloren (Limit: %.1f%%)",
            weekLoss, (weekLoss / weekBal * 100.0), g_MaxWeeklyDD_Pct);
      return false;
   }

   // --- Prüfungen 3, 4 und 5: Einzelne Schleife über alle Positionen ---
   // Zusammengefasst in einem Durchlauf für maximale Performance
   double floatingLoss = 0.0;
   int    openCount    = 0;
   int    sameDirCount = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      // Position selektieren und Ticket abrufen
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      // Nur EA-eigene Positionen berücksichtigen (Magic-Number-Filter)
      if((ulong)PositionGetInteger(POSITION_MAGIC) != magicNumber)
         continue;

      // Buchverluste summieren (nur negative Positionen)
      double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit < 0.0)
         floatingLoss += MathAbs(profit);

      // Trade-Gesamtzähler erhöhen
      openCount++;

      // Gleiche Richtung zählen (für Korrelationsschutz)
      if(newDirection != DIR_NONE)
      {
         ENUM_POSITION_TYPE posType =
            (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         bool posIstLong = (posType == POSITION_TYPE_BUY);
         bool neuIstLong = (newDirection == DIR_LONG);
         if(posIstLong == neuIstLong)
            sameDirCount++;
      }
   }

   // --- Prüfung 3: Maximaler Buchverlust ---
   double floatingLimit = equity * (g_MaxFloatingLoss_Pct / 100.0);
   if(floatingLoss >= floatingLimit)
   {
      outReason = StringFormat(
            "Buchverlust-Limit: %.2f EUR (%.1f%%) offen (Limit: %.1f%%)",
            floatingLoss, (floatingLoss / equity * 100.0), g_MaxFloatingLoss_Pct);
      return false;
   }

   // --- Prüfung 4: Maximale parallele Trades ---
   if(openCount >= g_MaxParallelTrades)
   {
      outReason = StringFormat(
            "Max. Trades erreicht: %d offen (Limit: %d)",
            openCount, g_MaxParallelTrades);
      return false;
   }

   // --- Prüfung 5: Korrelationsschutz (Richtungs-Limit) ---
   if(g_MaxSameDirTrades > 0 && sameDirCount >= g_MaxSameDirTrades)
   {
      outReason = StringFormat(
            "Korrelationsschutz: %d Trades bereits in Richtung %s (Limit: %d)",
            sameDirCount,
            (newDirection == DIR_LONG) ? "LONG" : "SHORT",
            g_MaxSameDirTrades);
      return false;
   }

   // --- Prüfung 6: Korrelationsgruppen (nach Symbol-Typ) ---
   if(newGroup != SYMTYPE_UNKNOWN)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
         string ps = PositionGetString(POSITION_SYMBOL);
         string su = ps; StringToUpper(su);
         ENUM_SYMBOL_TYPE pt = SYMTYPE_UNKNOWN;
         if(StringFind(su,"XAU")>=0||StringFind(su,"XAG")>=0||StringFind(su,"GOLD")>=0)
            pt = SYMTYPE_METAL;
         else if(StringFind(su,"CRUDE")>=0||StringFind(su,"BRENT")>=0||StringFind(su,"NATGAS")>=0)
            pt = SYMTYPE_COMMODITY;
         else if(StringFind(su,"USA500")>=0||StringFind(su,"US500")>=0||StringFind(su,"NAS100")>=0||
                  StringFind(su,"GER40")>=0||StringFind(su,"DAX")>=0||
                  StringFind(su,"JP225")>=0||StringFind(su,"UK100")>=0||
                  StringFind(su,"AUS200")>=0)
            pt = SYMTYPE_INDEX;
         else
            pt = SYMTYPE_FOREX;
         if(pt == newGroup)
         {
            outReason = StringFormat("KorrGruppe bereits durch %s belegt",ps);
            return false;
         }
      }
   }
   // Alle Prüfungen bestanden
   return true;
}

//+------------------------------------------------------------------+
//| Lotzahl berechnen                                                |
//|                                                                  |
//| Verwendet die korrekte MQL5-Formel:                              |
//|   Lots = Risiko_EUR / (SL_Abstand / TickSize × TickValue)        |
//|                                                                  |
//| Diese Formel funktioniert korrekt für alle Symbol-Typen          |
//| einschließlich Indizes (US500) und Rohstoffe (LCrude) wo         |
//| TickSize ≠ 1.0 ist.                                              |
//|                                                                  |
//| Zusätzlich: Plausibilitätsprüfung für Indizes/Rohstoffe —        |
//| verhindert dass das Mindest-Lot zu viel riskiert wenn das        |
//| berechnete Lot unter das Broker-Minimum fällt.                   |
//|                                                                  |
//| Parameter:                                                       |
//|   ctx        - Asset-Kontext (enthält gecachte Symbol-Parameter)  |
//|   entryPrice - Geplanter Einstiegspreis                          |
//|   slPrice    - Geplanter Stop-Loss-Preis                         |
//| Rückgabe: Normalisierte Lotzahl oder 0.0 bei Fehler/Ablehnung   |
//+------------------------------------------------------------------+
double RiskMgr_CalcLotSize(const S_AssetContext &ctx,
                            const double          entryPrice,
                            const double          slPrice)
{
   // Eingabe-Validierung
   if(entryPrice <= 0.0 || slPrice <= 0.0 || entryPrice == slPrice)
   {
      LOG_E(ctx.SymbolName, "Lotberechnung: Ungültige Preiseingabe (Entry oder SL = 0)");
      return 0.0;
   }

   // Aktuelles Konto-Equity und Risikobetrag in Kontowährung
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskEUR = equity * (g_RiskPct / 100.0);

   // Symbol-spezifische Handelsparameter abrufen
   double tickValue = SymbolInfoDouble(ctx.SymbolName, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(ctx.SymbolName, SYMBOL_TRADE_TICK_SIZE);
   double volMin    = SymbolInfoDouble(ctx.SymbolName, SYMBOL_VOLUME_MIN);
   double volMax    = SymbolInfoDouble(ctx.SymbolName, SYMBOL_VOLUME_MAX);
   double volStep   = SymbolInfoDouble(ctx.SymbolName, SYMBOL_VOLUME_STEP);

   // Sicherheitsprüfung der Symbol-Parameter
   if(tickValue <= 0.0 || tickSize <= 0.0 || volStep <= 0.0)
   {
      LOG_E(ctx.SymbolName, StringFormat(
            "Lotberechnung: Ungültige Symbol-Parameter "
            "(TickValue=%.5f, TickSize=%.5f, VolStep=%.5f)",
            tickValue, tickSize, volStep));
      return 0.0;
   }

   // SL-Abstand in Preiseinheiten
   double slAbstand = MathAbs(entryPrice - slPrice);

   // KORREKTE FORMEL für alle Symbol-Typen:
   // Anzahl Ticks im SL-Abstand × Wert pro Tick pro Lot
   // = Verlust in Kontowährung wenn SL bei 1 Lot getroffen wird
   double wertProLotProSL = (slAbstand / tickSize) * tickValue;

   if(wertProLotProSL <= 0.0)
   {
      LOG_E(ctx.SymbolName, "Lotberechnung: Wert pro Lot ist null oder negativ");
      return 0.0;
   }

   // Rohe Lotzahl aus Risikobetrag berechnen
   double rawLots = riskEUR / wertProLotProSL;

   // Auf den nächsten erlaubten Lot-Schritt abrunden (Floor)
   double normLots = MathFloor(rawLots / volStep) * volStep;

   // An Broker-Mindest- und Maximal-Lots anpassen
   normLots = MathMax(volMin, MathMin(normLots, volMax));

   // Plausibilitätsprüfung für Indizes und Rohstoffe (R5-3):
   // Wenn normLots durch Clamp auf volMin angehoben wurde UND
   // das tatsächliche Risiko >150% des Zielrisikos beträgt:
   // → Trade ablehnen (zu groß für das Konto)
   if(normLots > rawLots * 1.5 && normLots <= volMin + volStep)
   {
      double tatsaechlichesRisiko = normLots * wertProLotProSL;
      if(tatsaechlichesRisiko > riskEUR * 1.5)
      {
         LOG_W(ctx.SymbolName, StringFormat(
               "Lot-Plausibilität fehlgeschlagen: volMin (%.4f Lots) würde "
               "%.2f EUR riskieren (Ziel: %.2f EUR, +%.0f%%) – Trade abgelehnt",
               volMin, tatsaechlichesRisiko, riskEUR,
               ((tatsaechlichesRisiko / riskEUR) - 1.0) * 100.0));
         return 0.0;
      }
   }

   // Letzter Check: Mindest-Lot muss erreichbar sein
   if(normLots < volMin)
   {
      LOG_W(ctx.SymbolName, StringFormat(
            "Lotberechnung: Berechnetes Lot (%.4f) unter "
            "Mindest-Lot (%.4f) – Trade übersprungen",
            normLots, volMin));
      return 0.0;
   }

   LOG_D(ctx.SymbolName, StringFormat(
         "Lotberechnung: Risiko=%.2f EUR | SL-Abstand=%.5f | "
         "Wert/Lot=%.2f EUR | Lots=%.4f",
         riskEUR, slAbstand, wertProLotProSL, normLots));

   return normLots;
}

//+------------------------------------------------------------------+
//| Spread-Prüfung vor dem Trade                                     |
//|                                                                  |
//| Vergleicht den aktuellen Spread mit dem per-Asset-Maximum.       |
//| Nutzt ctx.MaxSpreadOverride wenn gesetzt, sonst g_MaxSpreadPoints.|
//| Nutzt den gecachten ctx.PointSize statt wiederholtem API-Aufruf. |
//|                                                                  |
//| Parameter:                                                       |
//|   ctx - Asset-Kontext (enthält MaxSpreadOverride und PointSize)  |
//| Rückgabe: true = Spread akzeptabel | false = zu weit             |
//+------------------------------------------------------------------+
bool RiskMgr_IsSpreadAcceptable(const S_AssetContext &ctx)
{
   // Per-Asset-Override nutzen wenn gesetzt (>0), sonst globaler Wert
   double maxSpread = (ctx.MaxSpreadOverride > 0.0)
                      ? ctx.MaxSpreadOverride
                      : g_MaxSpreadPoints;

   // PointSize muss gültig sein (wurde in OnInit geprüft)
   if(ctx.PointSize <= 0.0)
      return false;

   // Aktuellen Spread berechnen
   double ask    = SymbolInfoDouble(ctx.SymbolName, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(ctx.SymbolName, SYMBOL_BID);
   double spread = (ask - bid) / ctx.PointSize;

   if(spread > maxSpread)
   {
      LOG_W(ctx.SymbolName, StringFormat(
            "Spread zu weit: %.1f Punkte (Maximum: %.1f) – Trade übersprungen",
            spread, maxSpread));
      return false;
   }

   return true;
}

#endif // UB_RISKMANAGER_MQH