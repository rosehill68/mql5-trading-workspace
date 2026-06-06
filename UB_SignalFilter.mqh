//+------------------------------------------------------------------+
//|                                                                  |
//|  EA-Name    : THE UNBESTECHLICH EA                               |
//|  Datei      : UB_SignalFilter.mqh                                |
//|  Modul      : 2-Stufen-Signalfilter                              |
//|  Version    : 5.2.3                                              |
//|  Datum      : 2026-06-05                                         |
//|                                                                  |
//|  Versionshistorie:                                               |
//|  v4.0 - Erstimplementierung der 3-Stufen-Matrix                  |
//|          Division-by-Zero-Schutz für Doji-Kerzen (Stufe 2)       |
//|          Division-by-Zero-Schutz für Pinhead-Kerzen (Stufe 3)    |
//|          Korrekte Displacement-Logik für beide Richtungen        |
//|          Trap-Reversal-Signal-Erkennung                          |
//|  v4.1 - Include-Guards, UB_Globals.mqh, deutsche Kommentierung   |
//|  v4.2 - ZeroMemory(ergebnis) für vollständige Initialisierung    |
//|  v5.2.1 - Versionsnummer aktualisiert                            |
//|  v5.2.3 - SignalFilter_Evaluate: optionale boxHigh/boxLow        |
//|           Filter_Stage2_Displacement: optionale refBoxHigh/Low    |
//|           Kanten-Riegel nur bei Major-Box-Prüfung aktiv           |
//|                                                                  |
//|  Zweck:                                                          |
//|  Prüft potenzielle Handelssignale anhand von drei unabhängigen   |
//|  Kriterien. Alle drei müssen gleichzeitig erfüllt sein.          |
//|                                                                  |
//|  Stufe 1 - Kraft:       Kerzenstärke relativ zum D1-ATR          |
//|  Stufe 2 - Absicht:     Welcher Anteil des Körpers ist außerhalb |
//|  Stufe 3 - Nachhaltigkeit: Wo schließt die Kerze in ihrer Spanne |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef UB_SIGNALFILTER_MQH
#define UB_SIGNALFILTER_MQH

#include "UB_Globals.mqh"
#include "UB_Logger.mqh"

// Minimale Kerzenkörpergröße in Punkten um Doji-Kerzen auszuschließen.
// Kerzen mit kleinerem Körper als 2 Punkte werden als Doji gewertet
// und von Stufe 2 abgelehnt (Division-by-Zero-Schutz).
#define MIN_BODY_POINTS 2

//+------------------------------------------------------------------+
//| ATR-Wert der letzten abgeschlossenen D1-Kerze abrufen            |
//|                                                                  |
//| Liest den ATR über den in OnInit() erstellten Handle aus.        |
//| KEIN iATR()-Aufruf hier — Handle wurde in OnInit erstellt.       |
//|                                                                  |
//| Parameter: ctx - Asset-Kontext (enthält ATR_Handle_D1)           |
//| Rückgabe: ATR-Wert der letzten D1-Kerze oder 0.0 bei Fehler     |
//+------------------------------------------------------------------+
double GetATR_D1(const S_AssetContext &ctx)
{
   if(ctx.ATR_Handle_D1 == INVALID_HANDLE)
   {
      LOG_E(ctx.SymbolName,
            "ATR-Handle (D1) ist INVALID_HANDLE — wurde OnInit() korrekt ausgeführt?");
      return 0.0;
   }

   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);

   // Index 1 = letzte abgeschlossene D1-Kerze (nicht die laufende Kerze [0])
   if(CopyBuffer(ctx.ATR_Handle_D1, 0, 1, 1, atrBuffer) < 1)
   {
      LOG_W(ctx.SymbolName, "ATR D1: CopyBuffer-Aufruf fehlgeschlagen");
      return 0.0;
   }

   return atrBuffer[0];
}

//+------------------------------------------------------------------+
//| STUFE 1: Kraft-Check (Wucht-Verhältnis)                          |
//|                                                                  |
//| Misst die Stärke der Ausbruchskerze relativ zur täglichen        |
//| Durchschnittsvolatilität (D1-ATR). Schwache Kerzen ohne          |
//| ausreichendes Momentum werden abgelehnt.                         |
//|                                                                  |
//| Formel: Ratio = (High[1] - Low[1]) / ATR_D1                     |
//| Bedingung: Ratio ≥ ctx.MinRatioRequired                          |
//|                                                                  |
//| Parameter:                                                       |
//|   ctx      - Asset-Kontext (MinRatioRequired, ATR-Handle)        |
//|   high1    - Hoch der Signalkerze                                |
//|   low1     - Tief der Signalkerze                                |
//|   outRatio - Ausgabe: berechnetes Verhältnis                     |
//| Rückgabe: true = Kriterium erfüllt                               |
//+------------------------------------------------------------------+
bool Filter_Stage1_Kraft(S_AssetContext  &ctx,
                          const double     high1,
                          const double     low1,
                          double           &outRatio)
{
   double atr = GetATR_D1(ctx);
   if(atr <= 0.0)
   {
      LOG_W(ctx.SymbolName, "Stufe 1 abgelehnt: D1-ATR nicht verfügbar");
      return false;
   }

   double kerzenSpanne = high1 - low1;
   if(kerzenSpanne <= 0.0)
   {
      LOG_W(ctx.SymbolName, "Stufe 1 abgelehnt: Kerzenspanne ist null");
      return false;
   }

   outRatio = kerzenSpanne / atr;

   if(outRatio < ctx.MinRatioRequired)
   {
      LOG_D(ctx.SymbolName, StringFormat(
            "Stufe 1 abgelehnt: Verhältnis %.4f < Mindest %.4f",
            outRatio, ctx.MinRatioRequired));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| STUFE 2: Absichts-Check (Displacement / Verschiebung)            |
//|                                                                  |
//| Misst welcher Anteil des Kerzenkörpers außerhalb der             |
//| Konsolidierungsbox liegt. Hoher Wert = Kerze hat Box mit         |
//| Überzeugung verlassen, nicht nur gestreift.                      |
//|                                                                  |
//| Formel: DisplacementPct = (Außenanteil / Körpergröße) × 100      |
//| Bedingung: DisplacementPct ≥ g_MinBodyDisplacement               |
//|                                                                  |
//| Schutzmaßnahmen:                                                 |
//|   - Doji-Schutz: Körper < 2 Punkte → Ablehnung                  |
//|   - Open bereits außerhalb der Box → 100% (kein Div-by-Zero)    |
//|                                                                  |
//| Parameter:                                                       |
//|   ctx        - Asset-Kontext (BoxHigh, BoxLow)                   |
//|   open1      - Eröffnungskurs der Signalkerze                    |
//|   close1     - Schlusskurs der Signalkerze                       |
//|   direction  - Handelsrichtung (Long oder Short)                 |
//|   outDisplPct- Ausgabe: berechneter Außenanteil in Prozent       |
//| Rückgabe: true = Kriterium erfüllt                               |
//+------------------------------------------------------------------+
bool Filter_Stage2_Displacement(S_AssetContext   &ctx,
                                 const double      open1,
                                 const double      close1,
                                 const ENUM_TRADE_DIR direction,
                                 double            &outDisplPct,
                                 const double      refBoxHigh = 0.0,
                                 const double      refBoxLow  = 0.0)
{
   double boxHigh = (refBoxHigh > 0.0) ? refBoxHigh : ctx.BoxHigh;
   double boxLow  = (refBoxLow > 0.0)  ? refBoxLow  : ctx.BoxLow;

   double koerper    = MathAbs(close1 - open1);
   double minKoerper = ctx.PointSize * MIN_BODY_POINTS;

   // Doji-Schutz: Zu kleiner Körper → Division-by-Zero-Risiko
   if(koerper < minKoerper)
   {
      LOG_D(ctx.SymbolName, StringFormat(
            "Stufe 2 abgelehnt: Doji-Kerze "
            "(Körper %.5f < Mindest %.5f)",
            koerper, minKoerper));
      return false;
   }

   double aussenAnteil = 0.0;

   if(direction == DIR_LONG)
   {
      // Sonderfall: Eröffnung bereits über der Box → Körper komplett außen
      if(open1 >= boxHigh && close1 > open1)
      {
         outDisplPct = 100.0;
         return (outDisplPct >= g_MinBodyDisplacement);
      }
      // Normaler Fall: Anteil des Körpers über boxHigh
      aussenAnteil = MathMax(0.0, close1 - boxHigh);
   }
   else if(direction == DIR_SHORT)
   {
      // Sonderfall: Eröffnung bereits unter der Box
      if(open1 <= boxLow && close1 < open1)
      {
         outDisplPct = 100.0;
         return (outDisplPct >= g_MinBodyDisplacement);
      }
      // Normaler Fall: Anteil des Körpers unter boxLow
      aussenAnteil = MathMax(0.0, boxLow - close1);
   }
   else
   {
      return false;
   }

   // Prozentualer Außenanteil am Gesamtkörper
   outDisplPct = (aussenAnteil / koerper) * 100.0;

   if(outDisplPct < g_MinBodyDisplacement)
   {
      LOG_D(ctx.SymbolName, StringFormat(
            "Stufe 2 abgelehnt: Außenanteil %.1f%% < Mindest %.1f%%",
            outDisplPct, g_MinBodyDisplacement));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Gesamte 2-Stufen-Signalprüfung durchführen                       |
//|                                                                  |
//| Prüft ob auf dem angegebenen Zeitrahmen ein handelsfähiges        |
//| Signal vorliegt. Alle drei Stufen müssen bestanden werden.        |
//| Die Vorbedingung (Close außerhalb Box) wird hier geprüft.        |
//|                                                                  |
//| Parameter:                                                       |
//|   ctx - Asset-Kontext (Box-Werte, Kanten-Riegel, ATR-Handle)     |
//|   tf  - Zeitrahmen (PERIOD_H4 oder PERIOD_H1 im Hybrid-Modus)   |
//| Rückgabe: S_SignalResult mit vollständigen Detailwerten           |
//+------------------------------------------------------------------+
S_SignalResult SignalFilter_Evaluate(S_AssetContext &ctx,
                                     ENUM_TIMEFRAMES  tf = PERIOD_H4,
                                     double           boxHigh = 0.0,
                                     double           boxLow  = 0.0)
{
   S_SignalResult ergebnis;
   // Vollständige Initialisierung aller Felder (verhindert undefinierte Werte)
   ZeroMemory(ergebnis);
   ergebnis.Direction = DIR_NONE;

   // Referenz-Box: wenn boxHigh/boxLow übergeben → Minor-Box, sonst Major-Box
   double refHigh = (boxHigh > 0.0) ? boxHigh : ctx.BoxHigh;
   double refLow  = (boxLow > 0.0)  ? boxLow  : ctx.BoxLow;
   bool   isMinorCheck = (boxHigh > 0.0);

   // Kerzendaten der letzten 3 abgeschlossenen Kerzen abrufen
   // [0]=laufende Kerze (ausgeschlossen), [1]=Signalkerze, [2]=Vorgänger
   double open1[], high1[], low1[], close1[];
   ArraySetAsSeries(open1,  true);
   ArraySetAsSeries(high1,  true);
   ArraySetAsSeries(low1,   true);
   ArraySetAsSeries(close1, true);

   if(CopyOpen (ctx.SymbolName, tf, 0, 3, open1)  < 3) return ergebnis;
   if(CopyHigh (ctx.SymbolName, tf, 0, 3, high1)  < 3) return ergebnis;
   if(CopyLow  (ctx.SymbolName, tf, 0, 3, low1)   < 3) return ergebnis;
   if(CopyClose(ctx.SymbolName, tf, 0, 3, close1) < 3) return ergebnis;

   // Vorbedingung: Hat Schluss[1] die Box verlassen?
   ENUM_TRADE_DIR richtung = DIR_NONE;
   if(close1[1] > refHigh)            richtung = DIR_LONG;
   else if(close1[1] < refLow)        richtung = DIR_SHORT;
   else
      return ergebnis;   // Preis in der Box — kein Signal

   ergebnis.Direction = richtung;

   // Kanten-Riegel prüfen (NUR bei Major-Box)
   if(!isMinorCheck)
   {
      if(richtung == DIR_LONG && ctx.UpperEdgeLocked)
      {
         ergebnis.RejectReason = "Kanten-Riegel OBEN aktiv — kein erneuter Long";
         LOG_D(ctx.SymbolName, ergebnis.RejectReason);
         return ergebnis;
      }
      if(richtung == DIR_SHORT && ctx.LowerEdgeLocked)
      {
         ergebnis.RejectReason = "Kanten-Riegel UNTEN aktiv — kein erneuter Short";
         LOG_D(ctx.SymbolName, ergebnis.RejectReason);
         return ergebnis;
      }
   }

   // === STUFE 1: Kraft-Check ===
   if(!Filter_Stage1_Kraft(ctx, high1[1], low1[1], ergebnis.WuchtRatio))
   {
      ergebnis.FailedStage  = 1;
      ergebnis.RejectReason = StringFormat(
            "Stufe 1 NICHT BESTANDEN: Wucht-Verhältnis %.4f (Mindest: %.4f)",
            ergebnis.WuchtRatio, ctx.MinRatioRequired);
      LOG_I(ctx.SymbolName, ergebnis.RejectReason);
      return ergebnis;
   }

   // === STUFE 2: Displacement-Check ===
   if(!Filter_Stage2_Displacement(ctx, open1[1], close1[1],
                                   richtung, ergebnis.DisplacementPct,
                                   refHigh, refLow))
   {
      ergebnis.FailedStage  = 2;
      ergebnis.RejectReason = StringFormat(
            "Stufe 2 NICHT BESTANDEN: Außenanteil %.1f%% (Mindest: %.1f%%)",
            ergebnis.DisplacementPct, g_MinBodyDisplacement);
      LOG_I(ctx.SymbolName, ergebnis.RejectReason);
      return ergebnis;
   }

   // Beide Stufen bestanden — Signal ist handelbar
   ergebnis.IsValid = true;
   LOG_I(ctx.SymbolName, StringFormat(
            "SIGNAL ANGENOMMEN [%s] | Wucht: %.3f | "
            "Außenanteil: %.1f%%",
            (richtung == DIR_LONG) ? "LONG" : "SHORT",
            ergebnis.WuchtRatio,
            ergebnis.DisplacementPct));

   return ergebnis;
}

//+------------------------------------------------------------------+
//| Trap-Umkehrsignal prüfen (Fehlausbruch erkannt?)                 |
//|                                                                  |
//| Prüft ob innerhalb des Trap-Fensters eine Kerze zurück in die    |
//| Box geschlossen hat und Stufe 2+3 für die Gegenrichtung          |
//| erfüllt sind. Signalisiert einen Fehlausbruch.                   |
//|                                                                  |
//| Bedingungen:                                                      |
//|   1. CurrentState == STATE_TREND                                 |
//|   2. TrendCandleCounter ≤ TrapWindowCandles                     |
//|   3. Close[1] zurück innerhalb der Box                          |
//|   4. Stufe 2 (Displacement) für Gegenrichtung bestanden         |
//|   5. Stufe 3 (Rejection) für Gegenrichtung bestanden            |
//|                                                                  |
//| Parameter: ctx - Asset-Kontext                                   |
//| Rückgabe: true = Trap-Signal, Gegenposition soll eröffnet werden |
//+------------------------------------------------------------------+
bool SignalFilter_CheckTrapReversal(S_AssetContext &ctx)
{
   // Trap-Prüfung nur im Trendfolge-Modus sinnvoll
   if(ctx.CurrentState != STATE_TREND)
      return false;

   // Trap-Fenster bereits abgelaufen?
   if(ctx.TrendCandleCounter > g_TrapWindowCandles)
      return false;

   // Kerzendaten abrufen
   double close1[], open1[], high1[], low1[];
   ArraySetAsSeries(close1, true);
   ArraySetAsSeries(open1,  true);
   ArraySetAsSeries(high1,  true);
   ArraySetAsSeries(low1,   true);

   if(CopyClose(ctx.SymbolName, PERIOD_H4, 0, 3, close1) < 3) return false;
   if(CopyOpen (ctx.SymbolName, PERIOD_H4, 0, 3, open1)  < 3) return false;
   if(CopyHigh (ctx.SymbolName, PERIOD_H4, 0, 3, high1)  < 3) return false;
   if(CopyLow  (ctx.SymbolName, PERIOD_H4, 0, 3, low1)   < 3) return false;

   // Hat Kerze [1] wieder innerhalb der Makro-Box geschlossen?
   bool zurueckInBox = (close1[1] <= ctx.BoxHigh && close1[1] >= ctx.BoxLow);
   if(!zurueckInBox)
      return false;

   // Gegenrichtung für das Reversal-Signal
   ENUM_TRADE_DIR gegenRichtung = (ctx.ActiveDirection == DIR_LONG)
                                   ? DIR_SHORT : DIR_LONG;

   // Stufe 2 für die Gegenrichtung prüfen
   double displPct  = 0.0;

   if(Filter_Stage2_Displacement(ctx, open1[1], close1[1],
                                 gegenRichtung, displPct))
   {
      LOG_I(ctx.SymbolName, StringFormat(
            "TRAP-SIGNAL erkannt [%s] | Außenanteil: %.1f%%",
            (gegenRichtung == DIR_LONG) ? "LONG" : "SHORT",
            displPct));
      return true;
   }

   return false;
}

#endif // UB_SIGNALFILTER_MQH