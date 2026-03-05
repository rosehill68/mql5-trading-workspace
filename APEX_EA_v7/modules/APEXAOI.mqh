//+------------------------------------------------------------------+
//| APEXAOI.mqh                                                        |
//| Version:  7.0                                                      |
//| Datum:    2026.03.05                                               |
//|                                                                    |
//| Inhalt:   Areas of Interest – Pivots, Level, Runde Zahlen.         |
//+------------------------------------------------------------------+
#ifndef APEX_AOI_MQH
#define APEX_AOI_MQH

#include "APEXDefinitions.mqh"

void APEX_AddAOI(AOI_Data &aoi, const double preis, const string name, const string typ)
{
    if(aoi.anzahl >= MAX_AOI_LEVELS || preis <= 0.0) return;
    for(int i = 0; i < aoi.anzahl; i++)
        if(MathAbs(aoi.levels[i].preis - preis) < preis * 0.0001) return;
    
    aoi.levels[aoi.anzahl].preis = preis;
    aoi.levels[aoi.anzahl].name  = name;
    aoi.levels[aoi.anzahl].typ   = typ;
    aoi.anzahl++;
}

void APEX_CalcPivots(const string sym, AOI_Data &aoi)
{
    double h[], l[], c[];
    ArraySetAsSeries(h, true);
    ArraySetAsSeries(l, true);
    ArraySetAsSeries(c, true);
    if(CopyHigh(sym, PERIOD_D1, 1, 1, h)  < 1) return;
    if(CopyLow(sym, PERIOD_D1, 1, 1, l)   < 1) return;
    if(CopyClose(sym, PERIOD_D1, 1, 1, c) < 1) return;
    
    double pivot = (h[0] + l[0] + c[0]) / 3.0;
    APEX_AddAOI(aoi, pivot,                   "Pivot",    "PIVOT");
    APEX_AddAOI(aoi, 2.0 * pivot - l[0],      "Pivot R1", "PIVOT");
    APEX_AddAOI(aoi, 2.0 * pivot - h[0],      "Pivot S1", "PIVOT");
    APEX_AddAOI(aoi, pivot + (h[0] - l[0]),   "Pivot R2", "PIVOT");
    APEX_AddAOI(aoi, pivot - (h[0] - l[0]),   "Pivot S2", "PIVOT");
}

void APEX_CalcPreviousLevels(const string sym, AOI_Data &aoi)
{
    double h[], l[], c[];
    ArraySetAsSeries(h, true);
    ArraySetAsSeries(l, true);
    ArraySetAsSeries(c, true);
    
    if(CopyHigh(sym, PERIOD_D1, 1, 1, h) >= 1 &&
       CopyLow(sym, PERIOD_D1, 1, 1, l)  >= 1 &&
       CopyClose(sym, PERIOD_D1, 1, 1, c) >= 1)
    {
        APEX_AddAOI(aoi, h[0], "Gestern Hoch",   "LEVEL");
        APEX_AddAOI(aoi, l[0], "Gestern Tief",   "LEVEL");
        APEX_AddAOI(aoi, c[0], "Gestern Schluss", "LEVEL");
    }
    if(CopyHigh(sym, PERIOD_W1, 1, 1, h) >= 1 &&
       CopyLow(sym, PERIOD_W1, 1, 1, l)  >= 1)
    {
        APEX_AddAOI(aoi, h[0], "Letzte Woche Hoch", "LEVEL");
        APEX_AddAOI(aoi, l[0], "Letzte Woche Tief", "LEVEL");
    }
    if(CopyHigh(sym, PERIOD_MN1, 1, 1, h) >= 1 &&
       CopyLow(sym, PERIOD_MN1, 1, 1, l)  >= 1)
    {
        APEX_AddAOI(aoi, h[0], "Letzter Monat Hoch", "LEVEL");
        APEX_AddAOI(aoi, l[0], "Letzter Monat Tief", "LEVEL");
    }
}

void APEX_CalcRoundNumbers(const string sym, AOI_Data &aoi)
{
    double c[];
    ArraySetAsSeries(c, true);
    if(CopyClose(sym, PERIOD_D1, 0, 1, c) < 1) return;
    double preis = c[0];
    if(preis <= 0.0) return;
    
    double schritt;
    if(preis < 2.0)        schritt = 0.0050;
    else if(preis < 5.0)   schritt = 0.500;
    else if(preis < 100.0) schritt = 1.0;
    else if(preis < 1000.0)  schritt = 50.0;
    else if(preis < 10000.0) schritt = 50.0;
    else if(preis < 50000.0) schritt = 100.0;
    else                     schritt = 5000.0;
    
    if(schritt <= 0.0) return;
    double basis = MathFloor(preis / schritt) * schritt;
    int st = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
    
    for(int off = -2; off <= 3; off++)
    {
        double lv = basis + off * schritt;
        if(lv > 0.0)
        {
            string lb = StringFormat("Rund %." + IntegerToString(st) + "f", lv);
            APEX_AddAOI(aoi, lv, lb, "ROUND");
        }
    }
}

void APEX_CalcAOI(const string sym, AOI_Data &aoi)
{
    aoi.anzahl = 0;
    aoi.nahe_level = 0;
    aoi.naechstes = 0.0;
    aoi.naechster_name = "";
    aoi.abstand_pct = 999.0;
    aoi.in_zone = false;
    aoi.cluster = false;
    aoi.valid = false;
    ArrayResize(aoi.levels, MAX_AOI_LEVELS);
    
    if(InpAOI_UsePivots)  APEX_CalcPivots(sym, aoi);
    if(InpAOI_UseLevels)  APEX_CalcPreviousLevels(sym, aoi);
    if(InpAOI_UseRoundNr) APEX_CalcRoundNumbers(sym, aoi);
    if(aoi.anzahl == 0) return;
    
    double c[];
    ArraySetAsSeries(c, true);
    if(CopyClose(sym, PERIOD_CURRENT, 1, 1, c) < 1) return;
    double preis = c[0];
    if(preis <= 0.0) return;
    
    double zone = preis * (InpAOI_ZoneWidth / 100.0);
    double min_dist = 999999.0;
    
    for(int i = 0; i < aoi.anzahl; i++)
    {
        double abst = MathAbs(preis - aoi.levels[i].preis);
        double pct  = (abst / preis) * 100.0;
        if(abst < min_dist)
        {
            min_dist = abst;
            aoi.naechstes = aoi.levels[i].preis;
            aoi.naechster_name = aoi.levels[i].name;
            aoi.abstand_pct = pct;
        }
        if(abst <= zone) aoi.nahe_level++;
    }
    
    aoi.in_zone = (aoi.nahe_level > 0);
    aoi.cluster = (aoi.nahe_level >= InpAOI_MinCluster);
    aoi.valid = true;
}

double APEX_AOI_Score(const AOI_Data &aoi)
{
    if(!aoi.valid || aoi.anzahl == 0) return 3.0;
    double score = 0.0;
    if(aoi.in_zone)
    {
        score = 5.0;
        if(aoi.nahe_level > 1) score += (double)(aoi.nahe_level - 1) * 1.5;
        if(aoi.cluster) score += 2.0;
    }
    else
    {
        if(aoi.abstand_pct < 0.5)      score = 3.0;
        else if(aoi.abstand_pct < 1.0) score = 1.5;
        else                           score = 0.0;
    }
    return MathMax(0.0, MathMin(10.0, score));
}

#endif