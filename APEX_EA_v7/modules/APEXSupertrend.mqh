//+------------------------------------------------------------------+
//| APEXSupertrend.mqh                                                 |
//| Version:  7.2                                                      |
//| Datum:    2026.03.05                                               |
//|                                                                    |
//| Inhalt:   Supertrend als Trailing Stop.                            |
//+------------------------------------------------------------------+
#ifndef APEX_SUPERTREND_MQH
#define APEX_SUPERTREND_MQH

#include "APEXDefinitions.mqh"
#include "APEXCore.mqh"

#define ST_LOOKBACK  100
#define ST_MULT_MIN  1.5
#define ST_MULT_MAX  5.0

//+------------------------------------------------------------------+
//| MULTIPLIKATOR BERECHNEN                                            |
//|                                                                    |
//| Standard-Modus (Default, TV-kompatibel):                           |
//|   mult = InpST_Mult_Base (z.B. 3.0)                               |
//| Adaptiver Modus (optional):                                        |
//|   mult = Basis × (1/√RVOL) × (1 + (1-ER) × 0.5)                  |
//+------------------------------------------------------------------+
double APEX_CalcST_Multiplier(const string sym)
{
    if(!InpST_Adaptive)
    {
        // Standard-Modus: Fester Multiplikator (TV-kompatibel)
        return InpST_Mult_Base;
    }
    
    // Adaptiver Modus: Multiplikator anpassen
    double rvol = APEX_RVOL(sym, InpTF_Entry, InpRVOL_Period);
    double er   = APEX_ER(sym, InpTF_Entry, InpER_Period);
    
    double vol_faktor = (rvol > 0.01) ? 1.0 / MathSqrt(rvol) : 1.0;
    double er_faktor  = 1.0 + (1.0 - er) * 0.5;
    
    double mult = InpST_Mult_Base * vol_faktor * er_faktor;
    return MathMax(ST_MULT_MIN, MathMin(ST_MULT_MAX, mult));
}

//+------------------------------------------------------------------+
//| SUPERTREND BERECHNEN                                               |
//+------------------------------------------------------------------+
void APEX_Supertrend(const string sym,
                     double &out_wert, bool &out_bull, double &out_mult)
{
    out_wert = 0.0;
    out_bull = true;
    out_mult = InpST_Mult_Base;
    
    // ATR-Array berechnen
    double atr[];
    if(!APEX_ATR_Array(sym, InpTF_Entry, InpST_ATR_Period, atr, ST_LOOKBACK))
        return;
    
    // Preisdaten holen
    double h[], l[], c[];
    ArraySetAsSeries(h, true);
    ArraySetAsSeries(l, true);
    ArraySetAsSeries(c, true);
    
    if(CopyHigh(sym, InpTF_Entry, 1, ST_LOOKBACK, h)  < ST_LOOKBACK) return;
    if(CopyLow(sym, InpTF_Entry, 1, ST_LOOKBACK, l)   < ST_LOOKBACK) return;
    if(CopyClose(sym, InpTF_Entry, 1, ST_LOOKBACK, c) < ST_LOOKBACK) return;
    
    // Multiplikator bestimmen
    double mult = APEX_CalcST_Multiplier(sym);
    out_mult = mult;
    
    // Supertrend-Algorithmus
    double prev_ub = 0.0, prev_lb = 0.0;
    bool   prev_dir = true;
    double st = 0.0;
    
    for(int i = ST_LOOKBACK - 2; i >= 0; i--)
    {
        double mid    = (h[i] + l[i]) / 2.0;
        double ub_raw = mid + mult * atr[i];
        double lb_raw = mid - mult * atr[i];
        
        double ub, lb;
        if(i < ST_LOOKBACK - 2)
        {
            // Oberes Band: Darf nur sinken (oder Reset bei Ausbruch)
            ub = (ub_raw < prev_ub || c[i + 1] > prev_ub) ? ub_raw : prev_ub;
            // Unteres Band: Darf nur steigen (oder Reset bei Ausbruch)
            lb = (lb_raw > prev_lb || c[i + 1] < prev_lb) ? lb_raw : prev_lb;
        }
        else
        {
            ub = ub_raw;
            lb = lb_raw;
        }
        
        // Richtung bestimmen
        bool bull;
        if(prev_dir)
        {
            if(c[i] < lb) { bull = false; st = ub; }
            else          { bull = true;  st = lb; }
        }
        else
        {
            if(c[i] > ub) { bull = true;  st = lb; }
            else          { bull = false; st = ub; }
        }
        
        prev_ub  = ub;
        prev_lb  = lb;
        prev_dir = bull;
    }
    
    out_wert = st;
    out_bull = prev_dir;
}

//+------------------------------------------------------------------+
//| TRAILING STOP NACHZIEHEN                                           |
//+------------------------------------------------------------------+
bool APEX_TrailPosition(CTrade &trade, const string sym, const ulong ticket,
                         const ENUM_POSITION_TYPE typ, const double akt_sl)
{
    double st_wert, st_mult;
    bool   st_bull;
    APEX_Supertrend(sym, st_wert, st_bull, st_mult);
    
    if(st_wert <= 0.0) return false;
    
    int    dig     = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
    double neu_sl  = NormalizeDouble(st_wert, dig);
    double punkt   = SymbolInfoDouble(sym, SYMBOL_POINT);
    long   min_lev = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
    double min_ab  = (double)min_lev * punkt;
    
    if(typ == POSITION_TYPE_BUY)
    {
        double bid = SymbolInfoDouble(sym, SYMBOL_BID);
        if(neu_sl > akt_sl && neu_sl < bid - min_ab)
            return trade.PositionModify(ticket, neu_sl, 0.0);
    }
    else if(typ == POSITION_TYPE_SELL)
    {
        double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
        if(neu_sl < akt_sl && neu_sl > ask + min_ab)
            return trade.PositionModify(ticket, neu_sl, 0.0);
    }
    return false;
}

#endif