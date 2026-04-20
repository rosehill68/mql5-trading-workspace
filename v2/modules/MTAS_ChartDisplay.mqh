// ============================================================================
//  Datei:       MTAS_ChartDisplay.mqh
//  Projekt:     MTAS v2.0
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Chart-Visualisierung: Info-Panel, Regime-Background, Entry/Exit-Pfeile,
//    LSMA-Linie, Ratchet-Stop-Linie.
//    Alle Objekte tragen das Praefix "MTAS_" fuer sauberes Cleanup.
//
//  Abhaengigkeiten: MTAS_DataModel.mqh
// ============================================================================
#ifndef __MTAS_CHARTDISPLAY_MQH
#define __MTAS_CHARTDISPLAY_MQH

#include "MTAS_DataModel.mqh"

// ============================================================================
//  MTAS_DeleteAllChartObjects – Loescht alle Objekte mit MTAS-Praefix
// ============================================================================
void MTAS_DeleteAllChartObjects(const string prefix = "MTAS_")
{
    for(int i = ObjectsTotal(0, 0) - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, 0);
        if(StringFind(name, prefix) == 0)
            ObjectDelete(0, name);
    }
}

// ============================================================================
//  DrawInfoPanel – Textpanel oben links mit Systemstatus
// ============================================================================
void DrawInfoPanel(const string text, const int x = 10, const int y = 20)
{
    string name = "MTAS_InfoPanel";
    if(ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
    ObjectSetString (0, name, OBJPROP_TEXT,      text);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  9);
    ObjectSetInteger(0, name, OBJPROP_COLOR,     clrWhite);
    ObjectSetString (0, name, OBJPROP_FONT,      "Courier New");
    ChartRedraw(0);
}

// ============================================================================
//  DrawRegimeBG – Hintergrundfarbe je nach Regime
// ============================================================================
void DrawRegimeBG(const MTAS_Regime regime)
{
    color bg_color;
    switch(regime)
    {
        case REGIME_CHOP:    bg_color = C'30,30,50';  break;  // Dunkelblau
        case REGIME_TREND:   bg_color = C'20,40,20';  break;  // Dunkelgruen
        case REGIME_EXTREME: bg_color = C'50,25,25';  break;  // Dunkelrot
        default:             bg_color = C'25,25,25';  break;
    }
    ChartSetInteger(0, CHART_COLOR_BACKGROUND, bg_color);
}

// ============================================================================
//  DrawEntryArrow – Pfeil bei Trade-Eroeffnung
// ============================================================================
void DrawEntryArrow(const string sym, const int bar_shift, const double price,
                    const bool is_long)
{
    string name = StringFormat("MTAS_Entry_%s_%d", sym, bar_shift);
    ObjectDelete(0, name);
    ObjectCreate(0, name, OBJ_ARROW, 0, iTime(sym, PERIOD_CURRENT, bar_shift), price);
    ObjectSetInteger(0, name, OBJPROP_ARROWCODE, is_long ? 233 : 234); // Pfeil rauf/runter
    ObjectSetInteger(0, name, OBJPROP_COLOR,     is_long ? clrLime : clrRed);
    ObjectSetInteger(0, name, OBJPROP_WIDTH,     2);
    ChartRedraw(0);
}

// ============================================================================
//  DrawRatchetLine – Horizontale Linie fuer Ratchet-Stop
// ============================================================================
void DrawRatchetLine(const string sym, const double price, const bool is_long)
{
    string name = StringFormat("MTAS_Ratchet_%s", sym);
    if(ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

    ObjectSetDouble (0, name, OBJPROP_PRICE, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR, is_long ? clrLimeGreen : clrOrangeRed);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    ChartRedraw(0);
}

// ============================================================================
//  UpdateInfoPanelFull – Vollstaendiges Status-Panel aufbauen
// ============================================================================
void UpdateInfoPanelFull(const string symbol,
                          const IndicatorState &ind,
                          const RegimeState    &regime,
                          const SignalState    &sig,
                          const RiskState      &rs,
                          const AssetContext   &ctx)
{
    string regime_str = "?";
    switch(regime.regime)
    {
        case REGIME_CHOP:    regime_str = "CHOP";    break;
        case REGIME_TREND:   regime_str = "TREND";   break;
        case REGIME_EXTREME: regime_str = "EXTREME"; break;
        default:             regime_str = "UNKNOWN"; break;
    }
    string trend_str = (regime.trend_htf == TREND_UP) ? "UP" :
                       (regime.trend_htf == TREND_DOWN) ? "DOWN" : "FLAT";
    string dir_str   = (sig.direction == DIR_LONG) ? "LONG" :
                       (sig.direction == DIR_SHORT) ? "SHORT" : "---";

    string panel = StringFormat(
        "MTAS v2.0    %s\n"
        "Regime: %-8s  Trend: %s\n"
        "LSMA_HTF: %-10.5f  Z: %.2f\n"
        "LSMA_LTF: %-10.5f  ATR: %.5f\n"
        "RSI: %-6.1f   BBW_z: %.2f\n"
        "Signal: %-6s  Score: %.3f\n"
        "Pullback: %s   RSI-OK: %s\n"
        "Trades: %d  DailyPnL: %.2f\n"
        "Trade: %-8s  SL: %.5f\n",
        symbol,
        regime_str, trend_str,
        ind.lsma_htf, ind.slope_htf_z,
        ind.lsma_ltf, ind.atr_ltf,
        ind.rsi_ltf, ind.bbw_htf_z,
        dir_str, sig.confidence,
        sig.pullback_ok ? "JA" : "NEIN",
        sig.rsi_ok      ? "JA" : "NEIN",
        rs.open_trade_count, rs.daily_pnl,
        ctx.trade_state == TRADE_OPEN ? "OPEN" : "IDLE",
        ctx.ratchet_sl);

    DrawInfoPanel(panel, 10, 20);
    DrawRegimeBG(regime.regime);
}

#endif // __MTAS_CHARTDISPLAY_MQH
