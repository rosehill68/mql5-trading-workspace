//+------------------------------------------------------------------+
//| APEXPriceAction.mqh                                                |
//| Version:  6.3                                                      |
//| Datum:    2026.03.05                                               |
//|                                                                    |
//| Inhalt:   Erkennung von Umkehr-Kerzenmustern (3 bullisch, 3 baerisch)|
//+------------------------------------------------------------------+
#ifndef APEX_PRICEACTION_MQH
#define APEX_PRICEACTION_MQH

#include "APEXDefinitions.mqh"

bool APEX_GetOHLC3(const string sym, const ENUM_TIMEFRAMES tf,
                   double &o[], double &h[], double &l[], double &c[])
{
    ArraySetAsSeries(o, true);
    ArraySetAsSeries(h, true);
    ArraySetAsSeries(l, true);
    ArraySetAsSeries(c, true);
    if(CopyOpen(sym, tf, 1, 3, o)  < 3) return false;
    if(CopyHigh(sym, tf, 1, 3, h)  < 3) return false;
    if(CopyLow(sym, tf, 1, 3, l)   < 3) return false;
    if(CopyClose(sym, tf, 1, 3, c) < 3) return false;
    return true;
}

string APEX_BullPattern(const string sym, const ENUM_TIMEFRAMES tf)
{
    double o[], h[], l[], c[];
    if(!APEX_GetOHLC3(sym, tf, o, h, l, c)) return "";
    
    double b1 = c[0] - o[0], b2 = c[1] - o[1], b3 = c[2] - o[2];
    double s1 = h[0] - l[0];
    if(s1 <= 0.0) return "";
    
    if(b3 < 0.0 && MathAbs(b2) < MathAbs(b3) * 0.3 &&
       b1 > 0.0 && c[0] > (o[2] + c[2]) / 2.0)
        return "MORN_STAR";
    
    if(b2 < 0.0 && b1 > 0.0 && c[0] > o[1] && o[0] < c[1])
        return "BULL_ENGULF";
    
    double ld = MathMin(o[0], c[0]) - l[0];
    double ud = h[0] - MathMax(o[0], c[0]);
    if(ld > s1 * 0.6 && MathAbs(b1) < s1 * 0.3 && ud < s1 * 0.15)
        return "HAMMER";
    
    return "";
}

string APEX_BearPattern(const string sym, const ENUM_TIMEFRAMES tf)
{
    double o[], h[], l[], c[];
    if(!APEX_GetOHLC3(sym, tf, o, h, l, c)) return "";
    
    double b1 = c[0] - o[0], b2 = c[1] - o[1], b3 = c[2] - o[2];
    double s1 = h[0] - l[0];
    if(s1 <= 0.0) return "";
    
    if(b3 > 0.0 && MathAbs(b2) < MathAbs(b3) * 0.3 &&
       b1 < 0.0 && c[0] < (o[2] + c[2]) / 2.0)
        return "EVE_STAR";
    
    if(b2 > 0.0 && b1 < 0.0 && c[0] < o[1] && o[0] > c[1])
        return "BEAR_ENGULF";
    
    double ld = MathMin(o[0], c[0]) - l[0];
    double ud = h[0] - MathMax(o[0], c[0]);
    if(ud > s1 * 0.6 && MathAbs(b1) < s1 * 0.3 && ld < s1 * 0.15)
        return "SHOOT_STAR";
    
    return "";
}

#endif