//+------------------------------------------------------------------+
//|                                                                  |
//|  EA-Name    : THE UNBESTECHLICH EA                               |
//|  Datei      : UB_ChartDisplay.mqh                                |
//|  Modul      : Chart-Visualisierung (Boxen, Levels, Trades)       |
//|  Version    : 5.2.4                                              |
//|  Datum      : 2026-06-05                                         |
//|                                                                  |
//|  Zweck:                                                          |
//|  Zeichnet Major-Box, Minor-Box, SL, TP, Entry und               |
//|  Chandelier-Level als grafische Objekte auf dem Chart.           |
//|  Alle Objekte tragen das Präfix "UB_" + Symbolname.             |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef UB_CHARTDISPLAY_MQH
#define UB_CHARTDISPLAY_MQH

#include "UB_Globals.mqh"

#define UB_PREFIX "UB_"

//+------------------------------------------------------------------+
//| Hilfsfunktion: Alle Chart-Objekte eines Symbols löschen          |
//+------------------------------------------------------------------+
void ChartDisplay_Clear(const string symbol)
{
   string prefix = UB_PREFIX + symbol + "_";
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Hilfsfunktion: Horizontale Linie zeichnen                        |
//+------------------------------------------------------------------+
void DrawHLine(const string name, double price, color clr, int width,
               ENUM_LINE_STYLE style = STYLE_SOLID)
{
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Hilfsfunktion: Horizontale Linie verschieben                     |
//+------------------------------------------------------------------+
void MoveHLine(const string name, double price)
{
   ObjectMove(0, name, 0, 0, price);
}

//+------------------------------------------------------------------+
//| Hilfsfunktion: Rechteck zeichnen (hinter Kerzen)                 |
//+------------------------------------------------------------------+
void DrawBoxRect(const string name, double low, double high, color clr,
                 datetime lookbackHours = 0)
{
   if(lookbackHours <= 0)
      lookbackHours = 360; // 15 Tage default

   datetime tLeft  = TimeCurrent() - lookbackHours * 3600;
   datetime tRight = TimeCurrent() + 48 * 3600; // 2 Tage in die Zukunft

   ObjectCreate(0, name, OBJ_RECTANGLE, 0, tLeft, low, tRight, high);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Alle Chart-Elemente für ein Asset zeichnen                       |
//| Aufruf: Nach jeder Bar-Verarbeitung in AssetVerarbeiten()        |
//+------------------------------------------------------------------+
void ChartDisplay_DrawAll(const S_AssetContext &ctx)
{
   if(!g_EnableChartDisplay)
   {
      ChartDisplay_Clear(ctx.SymbolName);
      return;
   }

   string p = UB_PREFIX + ctx.SymbolName + "_";

   // --- Objekte aus vorherigem Durchlauf löschen ---
   ChartDisplay_Clear(ctx.SymbolName);

   // --- MAJOR-BOX (immer zeichnen wenn Box-Werte gültig) ---
   if(ctx.BoxHeight > 0.0)
   {
      DrawBoxRect(p + "BOX_RECT", ctx.BoxLow, ctx.BoxHigh,
                  g_ColorMajorBox, g_BoxPeriodCandles * 4);
      DrawHLine(p + "BOX_HIGH", ctx.BoxHigh, g_ColorMajorBox, 1);
      DrawHLine(p + "BOX_LOW",  ctx.BoxLow,  g_ColorMajorBox, 1);
      DrawHLine(p + "BOX_MED",  ctx.BoxMedian, g_ColorMajorBox, 1, STYLE_DASH);
   }

   // --- MINOR-BOX (falls aktiv) ---
   if(ctx.HasActiveMinorBox && ctx.MinorBoxHeight > 0.0)
   {
      DrawBoxRect(p + "MIN_RECT", ctx.MinorBoxLow, ctx.MinorBoxHigh,
                  g_ColorMinorBox, 48);
      DrawHLine(p + "MIN_HIGH",  ctx.MinorBoxHigh,   g_ColorMinorBox, 1, STYLE_DOT);
      DrawHLine(p + "MIN_LOW",   ctx.MinorBoxLow,    g_ColorMinorBox, 1, STYLE_DOT);
      DrawHLine(p + "MIN_MED",   ctx.MinorBoxMedian, g_ColorMinorBox, 1, STYLE_DOT);
   }

   // --- TRADE-LEVELS (nur wenn Position offen) ---
   if(ctx.TicketID > 0)
   {
      // Einstiegspreis
      if(ctx.EntryPrice > 0.0)
         DrawHLine(p + "ENTRY", ctx.EntryPrice, g_ColorEntry, 1, STYLE_DASH);

      // SL (aktuell per PositionSelectByTicket abrufbar)
      if(PositionSelectByTicket(ctx.TicketID))
      {
         double aktSL = PositionGetDouble(POSITION_SL);
         if(aktSL > 0.0)
            DrawHLine(p + "SL", aktSL, g_ColorSL, 2);
      }

      // TP (Trap)
      if(PositionSelectByTicket(ctx.TicketID))
      {
         double aktTP = PositionGetDouble(POSITION_TP);
         if(aktTP > 0.0)
            DrawHLine(p + "TP", aktTP, g_ColorTP, 2);
      }
   }
}

//+------------------------------------------------------------------+
//| SL-Chart-Linie auf jedem Tick aktualisieren                      |
//| Aufruf: in OnTick()                                              |
//+------------------------------------------------------------------+
void ChartDisplay_UpdateSL(const S_AssetContext &ctx)
{
   if(!g_EnableChartDisplay || ctx.TicketID == 0)
      return;

   string name = UB_PREFIX + ctx.SymbolName + "_SL";

   if(PositionSelectByTicket(ctx.TicketID))
   {
      double aktSL = PositionGetDouble(POSITION_SL);
      if(aktSL > 0.0)
      {
         // Linie erstellen falls nicht vorhanden
         if(ObjectFind(0, name) < 0)
            DrawHLine(name, aktSL, g_ColorSL, 2);
         else
            MoveHLine(name, aktSL);
      }
   }
}

//+------------------------------------------------------------------+
//| Alle Chart-Objekte des EA beim Beenden löschen                   |
//| Aufruf: in OnDeinit()                                            |
//+------------------------------------------------------------------+
void ChartDisplay_CleanupAll()
{
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, UB_PREFIX) == 0)
         ObjectDelete(0, name);
   }
}

#endif // UB_CHARTDISPLAY_MQH