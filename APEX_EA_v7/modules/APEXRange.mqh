//+------------------------------------------------------------------+
//| APEXRange.mqh                                                      |
//| Version:  6.3                                                      |
//| Datum:    2026.03.05                                               |
//|                                                                    |
//| Inhalt:   Adaptive Percentile Range mit Entry/Exit-Zonen.          |
//+------------------------------------------------------------------+
#ifndef APEX_RANGE_MQH
#define APEX_RANGE_MQH

#include "APEXDefinitions.mqh"

void APEX_SortAscending(double &arr[], const int sz)
{
    for(int i = 1; i < sz; i++)
    {
        double key = arr[i];
        int j = i - 1;
        while(j >= 0 && arr[j] > key) { arr[j + 1] = arr[j]; j--; }
        arr[j + 1] = key;
    }
}

double APEX_Percentile(const double &sorted[], const int sz, const double pct)
{
    if(sz <= 0) return 0.0;
    if(sz == 1) return sorted[0];
    double idx = (pct / 100.0) * (double)(sz - 1);
    int lo = (int)MathFloor(idx);
    int hi = lo + 1;
    if(hi >= sz) return sorted[sz - 1];
    if(lo < 0)   return sorted[0];
    double frac = idx - (double)lo;
    return sorted[lo] + frac * (sorted[hi] - sorted[lo]);
}

void APEX_CalcRange(const string sym, const ENUM_TIMEFRAMES tf,
                    const ENUM_APEX_SIGNAL dir, RangeData &rd)
{
    rd.valid = false;
    rd.tp_level = 0.0;
    
    double c[];
    ArraySetAsSeries(c, true);
    if(CopyClose(sym, tf, 1, InpRange_Period, c) < InpRange_Period) return;
    
    double s[];
    ArrayResize(s, InpRange_Period);
    for(int i = 0; i < InpRange_Period; i++) s[i] = c[i];
    APEX_SortAscending(s, InpRange_Period);
    
    rd.upper = APEX_Percentile(s, InpRange_Period, InpRange_UpperPct);
    rd.lower = APEX_Percentile(s, InpRange_Period, InpRange_LowerPct);
    rd.mid   = (rd.upper + rd.lower) / 2.0;
    rd.width = rd.upper - rd.lower;
    if(rd.width <= 0.0) return;
    
    rd.width_pct = (c[0] > 0.0) ? (rd.width / c[0]) * 100.0 : 0.0;
    rd.position  = ((c[0] - rd.lower) / rd.width) * 100.0;
    rd.at_lower  = (rd.position <= InpRange_EntryZone);
    rd.at_upper  = (rd.position >= (100.0 - InpRange_EntryZone));
    rd.outside   = (rd.position < -5.0 || rd.position > 105.0);
    
    double exit_off = rd.width * (InpRange_ExitZone / 100.0);
    if(dir == SIG_BUY)       rd.tp_level = rd.upper - exit_off;
    else if(dir == SIG_SELL) rd.tp_level = rd.lower + exit_off;
    else                     rd.tp_level = rd.mid;
    
    rd.valid = true;
}

double APEX_RangeScore(const RangeData &rd, const ENUM_APEX_REGIME regime,
                       const ENUM_APEX_SIGNAL dir)
{
    if(!rd.valid) return 5.0;
    double score = 0.0;
    
    if(regime == REG_RANGE)
    {
        if(dir == SIG_BUY && rd.at_lower)
        {
            double d = MathMax(0.0, InpRange_EntryZone - rd.position);
            score = 5.0 + (d / InpRange_EntryZone) * 5.0;
        }
        else if(dir == SIG_SELL && rd.at_upper)
        {
            double d = MathMax(0.0, rd.position - (100.0 - InpRange_EntryZone));
            score = 5.0 + (d / InpRange_EntryZone) * 5.0;
        }
        else score = 2.0;
    }
    else
    {
        double dist = MathAbs(rd.position - 50.0);
        score = MathMax(0.0, 10.0 - (dist / 50.0) * 10.0);
    }
    return MathMax(0.0, MathMin(10.0, score));
}

#endif