// ============================================================================
//  Datei:       MTAS_OrderManager_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: Ordermanagement für Entry, SL/TP, Closure, Errorhandling
// ============================================================================

#ifndef __MTAS_ORDERMANAGER_V1_1_MQH
#define __MTAS_ORDERMANAGER_V1_1_MQH

#include <Trade\Trade.mqh>
CTrade trade_mtas;

bool OpenOrder(const string symbol, const ENUM_ORDER_TYPE type, 
               const double lots, const double price, 
               const double sl, const double tp,
               const long magic, const string comment = "")
{
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double entry = (type==ORDER_TYPE_BUY) ? ask : bid;
    double used_price = (price > 0) ? price : entry;

    trade_mtas.SetExpertMagicNumber(magic);
    trade_mtas.SetDeviationInPoints(10);

    bool ok = false;
    // Fehlerhandling wie im Pflichtenheft (max 3 retries)
    for(int i=0; i<3; i++)
    {
        if(type==ORDER_TYPE_BUY)
            ok = trade_mtas.Buy(lots, symbol, used_price, sl, tp, comment);
        else
            ok = trade_mtas.Sell(lots, symbol, used_price, sl, tp, comment);
        if(ok) return true;
        Sleep(1000);
    }
    return false;
}

bool ModifyStop(const ulong ticket, const double new_sl)
{
    if(!PositionSelectByTicket(ticket)) return false;
    string symbol = PositionGetString(POSITION_SYMBOL);
    double tp = PositionGetDouble(POSITION_TP);
    return trade_mtas.PositionModify(ticket, new_sl, tp);
}

bool CloseOrder(const ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return false;
    string symbol = PositionGetString(POSITION_SYMBOL);
    return trade_mtas.PositionClose(ticket);
}

#endif // __MTAS_ORDERMANAGER_V1_1_MQH