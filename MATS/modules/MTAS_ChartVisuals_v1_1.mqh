// ============================================================================
//  Datei:       MTAS_ChartVisuals_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Beschreibung: Chartvisualisierung: LSMA, Ratchet, Regimes, Pfeile, Panel
// ============================================================================

#ifndef __MTAS_CHARTVISUALS_V1_1_MQH
#define __MTAS_CHARTVISUALS_V1_1_MQH

// Zeichen LSMA-Linie
void DrawLSMA(const string obj_name, const string symbol, const double &lsma_vals[], const int n, color clr = clrCornflowerBlue)
{
    ObjectDelete(0, obj_name);
    ObjectCreate(0, obj_name, OBJ_TREND, 0, 0, 0, 0);
    for(int i=0;i<n && i<10;i++) // Max 10 Punkte, je nach Buffer
    {
        datetime t = iTime(symbol, PERIOD_CURRENT, i);
        ObjectSetInteger(0, obj_name, OBJPROP_TIME+i, t);
        ObjectSetDouble(0, obj_name, OBJPROP_PRICE+i, lsma_vals[i]);
    }
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
}

// Zeichnet einen horizontalen Ratchet-Stop
void DrawRatchetStop(const string obj_name, int bar_shift, double price, color clr = clrLimeGreen)
{
    ObjectDelete(0, obj_name);
    datetime t1 = iTime(_Symbol, PERIOD_CURRENT, bar_shift);
    datetime t2 = iTime(_Symbol, PERIOD_CURRENT, 0);
    ObjectCreate(0, obj_name, OBJ_HLINE, 0, t1, price, t2, price);
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 2);
}

// Entry/Exit Pfeile:
void DrawEntryArrow(const string obj_name, int bar_shift, double price, bool long_entry)
{
    ObjectDelete(0, obj_name);
    datetime t = iTime(_Symbol, PERIOD_CURRENT, bar_shift);
    ObjectCreate(0, obj_name, OBJ_ARROW, 0, t, price);
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, long_entry ? clrLimeGreen : clrCrimson);
    ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, long_entry ? 233 : 234);
    ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 2);
}

// Hintergrundfarbe ändern je nach Regime (Trend/Chop/Extreme)
void DrawRegimeBG(MTAS_Regime regime)
{
    long chart_id = ChartID();
    color bg = clrWhite;
    if(regime==REGIME_TREND) bg = ColorToARGB(clrGreen, 80);
    else if(regime==REGIME_CHOP) bg = ColorToARGB(clrGray, 80);
    else if(regime==REGIME_EXTREME) bg = ColorToARGB(clrRed, 80);
    ChartSetInteger(chart_id, CHART_COLOR_BACKGROUND, bg);
}

// Info-Panel (vereinfachtes Beispiel)
void DrawInfoPanel(const string info)
{
    string obj = "MTAS_InfoPanel";
    ObjectDelete(0, obj);
    ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0,obj,OBJPROP_COLOR,clrBlack);
    ObjectSetString(0,obj,OBJPROP_TEXT,info);
    ObjectSetInteger(0,obj,OBJPROP_CORNER,0);
    ObjectSetInteger(0,obj,OBJPROP_YDISTANCE,10);
    ObjectSetInteger(0,obj,OBJPROP_XDISTANCE,10);
    ObjectSetInteger(0,obj,OBJPROP_FONTSIZE,10);
}

#endif // __MTAS_CHARTVISUALS_V1_1_MQH