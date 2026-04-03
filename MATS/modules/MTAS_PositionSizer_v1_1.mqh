// ============================================================================
//  Datei:       MTAS_PositionSizer_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: Lotgrößen-Berechnung für MT5/TV
// ============================================================================

#ifndef __MTAS_POSITIONSIZER_V1_1_MQH
#define __MTAS_POSITIONSIZER_V1_1_MQH

double CalcLots(double acc_balance, double risk_pct, double stop_pips, string symbol)
{
    double risk_money = acc_balance * risk_pct / 100.0;
    double pip_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    if(pip_value <= 0.0 || stop_pips <= 0.0) return 0.0;
    double lots = risk_money / (stop_pips * pip_value);
    // Runden auf Lot-Step
    double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double minl = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxl = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    lots = MathMax(minl, MathMin(lots, maxl));
    lots = MathFloor(lots / step) * step;
    return lots;
}

#endif // __MTAS_POSITIONSIZER_V1_1_MQH