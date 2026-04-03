// ============================================================================
//  Datei:       MTAS_RiskManager_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: Globales Risikomanagement (max Trades, DD, Spread etc.)
// ============================================================================

#ifndef __MTAS_RISKMANAGER_V1_1_MQH
#define __MTAS_RISKMANAGER_V1_1_MQH

struct RiskManagerResult {
    bool allowed;
    string reason;
};

int CountOpenTrades(long magic_min, long magic_max = 0)
{
    // Zählt alle offenen Trades (optional Bereich Magic Min–Max)
    int total = 0;
    for(int i=0; i<PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            long magic = PositionGetInteger(POSITION_MAGIC);
            if(magic_max>0) {
                if(magic >= magic_min && magic <= magic_max) total++;
            } else {
                if(magic == magic_min) total++;
            }
        }
    }
    return total;
}

RiskManagerResult CanOpenTrade(int max_trades, double max_day_dd, double max_week_dd, double max_spread_atr, 
                               ulong magic_min, ulong magic_max, string symbol, double atr_period)
{
    RiskManagerResult r = {false, ""};
    // 1. Offene Trades global (über den gesamten Magic-Bereich)
    int trades = CountOpenTrades(magic_min, magic_max);
    if(trades >= max_trades)
    {
        r.reason = "Max. Trades erreicht.";
        return r;
    }
    // 2. Tag/Woche-DD ggf. optional, Pseudocode - Logik nach Bedarf nachschärfen
    // ... DD-Checks (über Orderhistory/Profit&Loss) falls benötigt, hier Dummy:
    // r.reason = "Max. Tagesverlust/Drawdown erreicht."; return r;

    // 3. Spread zu hoch?
    double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
    double atr = CalcATR(symbol, PERIOD_CURRENT, int(atr_period), 1);
    if(atr > 0 && (spread / atr > max_spread_atr)) {
        r.reason = "Spread zu hoch relativ zu ATR.";
        return r;
    }

    r.allowed = true;
    r.reason = "OK";
    return r;
}

#endif // __MTAS_RISKMANAGER_V1_1_MQH