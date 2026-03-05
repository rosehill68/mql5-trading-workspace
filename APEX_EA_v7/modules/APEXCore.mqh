//+------------------------------------------------------------------+
//| APEXCore.mqh                                                       |
//| Version:  6.3                                                      |
//| Datum:    2026.03.05                                               |
//|                                                                    |
//| Inhalt:   Alle Indikator-Berechnungen, komplett intern.            |
//|           Keine externen Indicator-Handles.                        |
//+------------------------------------------------------------------+
#ifndef APEX_CORE_MQH
#define APEX_CORE_MQH

#include "APEXDefinitions.mqh"

//+------------------------------------------------------------------+
//| Z-SCORE: Misst wie weit der Preis vom Durchschnitt entfernt ist    |
//+------------------------------------------------------------------+
double APEX_ZScore(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    double schlusskurse[];
    ArraySetAsSeries(schlusskurse, true);
    if(CopyClose(sym, tf, 1, periode, schlusskurse) < periode)
        return 0.0;
    
    double summe = 0.0;
    double summe_q = 0.0;
    for(int i = 0; i < periode; i++)
    {
        summe   += schlusskurse[i];
        summe_q += schlusskurse[i] * schlusskurse[i];
    }
    
    double avg = summe / (double)periode;
    double var = summe_q / (double)periode - avg * avg;
    double std = (var > 0.0) ? MathSqrt(var) : 1e-10;
    
    return (schlusskurse[0] - avg) / std;
}

//+------------------------------------------------------------------+
//| EFFICIENCY RATIO: Misst Trendstaerke (0=Range, 1=Trend)            |
//+------------------------------------------------------------------+
double APEX_ER(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    double c[];
    ArraySetAsSeries(c, true);
    if(CopyClose(sym, tf, 1, periode + 1, c) < periode + 1)
        return 0.5;
    
    double signal = MathAbs(c[0] - c[periode]);
    double noise  = 0.0;
    for(int i = 0; i < periode; i++)
        noise += MathAbs(c[i] - c[i + 1]);
    
    return (noise > 0.0) ? signal / noise : 0.0;
}

//+------------------------------------------------------------------+
//| RATE OF CHANGE: Prozentuale Preisveraenderung                      |
//+------------------------------------------------------------------+
double APEX_ROC(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    double c[];
    ArraySetAsSeries(c, true);
    if(CopyClose(sym, tf, 1, periode + 1, c) < periode + 1)
        return 0.0;
    if(c[periode] <= 0.0) return 0.0;
    return ((c[0] - c[periode]) / c[periode]) * 100.0;
}

//+------------------------------------------------------------------+
//| ATR: Durchschnittliche Schwankungsbreite (Wilder-Glaettung)        |
//+------------------------------------------------------------------+
double APEX_ATR(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    int ben = periode + 50;
    double h[], l[], c[];
    ArraySetAsSeries(h, true);
    ArraySetAsSeries(l, true);
    ArraySetAsSeries(c, true);
    
    if(CopyHigh(sym, tf, 1, ben, h)  < ben) return 0.0;
    if(CopyLow(sym, tf, 1, ben, l)   < ben) return 0.0;
    if(CopyClose(sym, tf, 1, ben, c) < ben) return 0.0;
    
    double tr[];
    ArrayResize(tr, ben);
    tr[ben - 1] = h[ben - 1] - l[ben - 1];
    
    for(int i = ben - 2; i >= 0; i--)
    {
        double hl = h[i] - l[i];
        double hc = MathAbs(h[i] - c[i + 1]);
        double lc = MathAbs(l[i] - c[i + 1]);
        tr[i] = MathMax(hl, MathMax(hc, lc));
    }
    
    double atr = 0.0;
    int sp = ben - periode;
    for(int i = ben - 1; i >= sp; i--)
        atr += tr[i];
    atr /= (double)periode;
    
    for(int i = sp - 1; i >= 0; i--)
        atr = (atr * (double)(periode - 1) + tr[i]) / (double)periode;
    
    return atr;
}

//+------------------------------------------------------------------+
//| ATR-ARRAY: Gibt mehrere ATR-Werte zurueck (fuer Supertrend)        |
//+------------------------------------------------------------------+
bool APEX_ATR_Array(const string sym, const ENUM_TIMEFRAMES tf,
                    const int periode, double &out[], const int anz)
{
    int ben = anz + periode + 50;
    double h[], l[], c[];
    ArraySetAsSeries(h, true);
    ArraySetAsSeries(l, true);
    ArraySetAsSeries(c, true);
    
    if(CopyHigh(sym, tf, 1, ben, h)  < ben) return false;
    if(CopyLow(sym, tf, 1, ben, l)   < ben) return false;
    if(CopyClose(sym, tf, 1, ben, c) < ben) return false;
    
    double tr[];
    ArrayResize(tr, ben);
    tr[ben - 1] = h[ben - 1] - l[ben - 1];
    for(int i = ben - 2; i >= 0; i--)
    {
        double hl = h[i] - l[i];
        double hc = MathAbs(h[i] - c[i + 1]);
        double lc = MathAbs(l[i] - c[i + 1]);
        tr[i] = MathMax(hl, MathMax(hc, lc));
    }
    
    ArrayResize(out, anz);
    ArraySetAsSeries(out, true);
    
    double atr = 0.0;
    int sp = ben - periode;
    for(int i = ben - 1; i >= sp; i--)
        atr += tr[i];
    atr /= (double)periode;
    
    int idx = anz - 1;
    for(int i = sp - 1; i >= 0; i--)
    {
        atr = (atr * (double)(periode - 1) + tr[i]) / (double)periode;
        if(idx >= 0 && idx < anz)
        {
            out[idx] = atr;
            idx--;
        }
    }
    return true;
}

//+------------------------------------------------------------------+
//| ADX: Average Directional Index – Trendstaerke 0-100                |
//+------------------------------------------------------------------+
double APEX_ADX(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    int ben = periode * 3 + 50;
    double h[], l[], c[];
    ArraySetAsSeries(h, true);
    ArraySetAsSeries(l, true);
    ArraySetAsSeries(c, true);
    
    if(CopyHigh(sym, tf, 1, ben, h)  < ben) return 0.0;
    if(CopyLow(sym, tf, 1, ben, l)   < ben) return 0.0;
    if(CopyClose(sym, tf, 1, ben, c) < ben) return 0.0;
    
    double pdm[], mdm[], trr[];
    ArrayResize(pdm, ben);
    ArrayResize(mdm, ben);
    ArrayResize(trr, ben);
    
    pdm[ben - 1] = 0.0;
    mdm[ben - 1] = 0.0;
    trr[ben - 1] = h[ben - 1] - l[ben - 1];
    
    for(int i = ben - 2; i >= 0; i--)
    {
        double up = h[i] - h[i + 1];
        double dn = l[i + 1] - l[i];
        pdm[i] = (up > dn && up > 0.0) ? up : 0.0;
        mdm[i] = (dn > up && dn > 0.0) ? dn : 0.0;
        double hl = h[i] - l[i];
        double hc = MathAbs(h[i] - c[i + 1]);
        double lc = MathAbs(l[i] - c[i + 1]);
        trr[i] = MathMax(hl, MathMax(hc, lc));
    }
    
    double g_pdm = 0.0, g_mdm = 0.0, g_tr = 0.0;
    int sp = ben - periode;
    for(int i = ben - 1; i >= sp; i--)
    {
        g_pdm += pdm[i];
        g_mdm += mdm[i];
        g_tr  += trr[i];
    }
    
    double adx = 0.0;
    bool init = false;
    int cnt = 0;
    double dxs = 0.0;
    
    for(int i = sp - 1; i >= 0; i--)
    {
        g_pdm = g_pdm - g_pdm / (double)periode + pdm[i];
        g_mdm = g_mdm - g_mdm / (double)periode + mdm[i];
        g_tr  = g_tr  - g_tr  / (double)periode + trr[i];
        if(g_tr <= 0.0) continue;
        
        double pdi = (g_pdm / g_tr) * 100.0;
        double mdi = (g_mdm / g_tr) * 100.0;
        double dis = pdi + mdi;
        double dx  = (dis > 0.0) ? (MathAbs(pdi - mdi) / dis) * 100.0 : 0.0;
        
        if(!init)
        {
            dxs += dx;
            cnt++;
            if(cnt >= periode) { adx = dxs / (double)periode; init = true; }
        }
        else
        {
            adx = (adx * (double)(periode - 1) + dx) / (double)periode;
        }
    }
    return adx;
}

//+------------------------------------------------------------------+
//| NATR: Normalisierte ATR in Prozent                                 |
//+------------------------------------------------------------------+
double APEX_NATR(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    double atr = APEX_ATR(sym, tf, periode);
    double c[];
    ArraySetAsSeries(c, true);
    if(CopyClose(sym, tf, 1, 1, c) < 1) return 0.0;
    return (c[0] > 0.0) ? (atr / c[0]) * 100.0 : 0.0;
}

//+------------------------------------------------------------------+
//| RVOL: Relatives Volumen (1.0 = Durchschnitt)                       |
//+------------------------------------------------------------------+
double APEX_RVOL(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    long v[];
    ArraySetAsSeries(v, true);
    if(CopyTickVolume(sym, tf, 1, periode, v) < periode) return 1.0;
    
    double sum = 0.0;
    for(int i = 1; i < periode; i++) sum += (double)v[i];
    double avg = sum / (double)(periode - 1);
    return (avg > 0.0) ? (double)v[0] / avg : 1.0;
}

//+------------------------------------------------------------------+
//| Volatilitaets-Perzentil (0-100)                                    |
//+------------------------------------------------------------------+
double APEX_VolPercentile(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    double h[], l[], c[];
    ArraySetAsSeries(h, true);
    ArraySetAsSeries(l, true);
    ArraySetAsSeries(c, true);
    
    if(CopyHigh(sym, tf, 1, periode + 1, h)  < periode + 1) return 50.0;
    if(CopyLow(sym, tf, 1, periode + 1, l)   < periode + 1) return 50.0;
    if(CopyClose(sym, tf, 1, periode + 1, c) < periode + 1) return 50.0;
    
    double tr[];
    ArrayResize(tr, periode);
    for(int i = 0; i < periode; i++)
    {
        double hl = h[i] - l[i];
        double hc = MathAbs(h[i] - c[i + 1]);
        double lc = MathAbs(l[i] - c[i + 1]);
        tr[i] = MathMax(hl, MathMax(hc, lc));
    }
    
    double akt = tr[0];
    int kleiner = 0;
    for(int i = 1; i < periode; i++)
        if(tr[i] <= akt) kleiner++;
    
    return ((double)kleiner / (double)(periode - 1)) * 100.0;
}

//+------------------------------------------------------------------+
//| REGIME-KLASSIFIKATION                                              |
//+------------------------------------------------------------------+
ENUM_APEX_REGIME APEX_ClassifyRegime(const double er, const double htf_zscore)
{
    if(er > InpER_Trend)
        return (htf_zscore > 0.0) ? REG_TREND_UP : REG_TREND_DOWN;
    if(er < InpER_Range)
        return REG_RANGE;
    return REG_UNDEF;
}

//+------------------------------------------------------------------+
//| SPREAD-FILTER (3 Pruefungen)                                       |
//+------------------------------------------------------------------+
bool APEX_SpreadOK(const string sym, const double sl_abstand, const double max_pct)
{
    double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
    double bid = SymbolInfoDouble(sym, SYMBOL_BID);
    double spread = ask - bid;
    if(spread <= 0.0) return true;
    
    double atr = APEX_ATR(sym, InpTF_Entry, 14);
    if(atr > 0.0 && spread > atr * 0.5)
    {
        PrintFormat("APEX Spread: %s zu breit (ATR-Haelfte)", sym);
        return false;
    }
    
    if(sl_abstand > 0.0)
    {
        double pct = (spread / sl_abstand) * 100.0;
        if(pct > max_pct)
        {
            PrintFormat("APEX Spread: %s = %.1f%% des SL (Max %.0f%%)", sym, pct, max_pct);
            return false;
        }
    }
    
    double h[], l[];
    ArraySetAsSeries(h, true);
    ArraySetAsSeries(l, true);
    int vgl = 20;
    if(CopyHigh(sym, InpTF_Entry, 1, vgl, h) >= vgl &&
       CopyLow(sym, InpTF_Entry, 1, vgl, l)  >= vgl)
    {
        double avg_sp = 0.0;
        for(int i = 0; i < vgl; i++) avg_sp += (h[i] - l[i]);
        avg_sp /= (double)vgl;
        double erw = avg_sp * 0.05;
        if(erw > 0.0 && spread > erw * 3.0)
        {
            PrintFormat("APEX Spread: %s Spike erkannt!", sym);
            return false;
        }
    }
    return true;
}

//+------------------------------------------------------------------+
//| Asset-spezifische Schwellenwerte                                   |
//+------------------------------------------------------------------+
double APEX_GetMinNATR(const ENUM_ASSET_CLASS k)
{
    return (k == ASSET_CRYPTO) ? 0.30 : 0.05;
}

double APEX_GetZThreshold(const ENUM_ASSET_CLASS k)
{
    return (k == ASSET_CRYPTO) ? InpZ_Threshold + 0.5 : InpZ_Threshold;
}

double APEX_GetMaxSpreadPct(const ENUM_ASSET_CLASS k)
{
    return (k == ASSET_CRYPTO) ? 30.0 : 20.0;
}

#endif