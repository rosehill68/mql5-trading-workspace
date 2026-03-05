//+------------------------------------------------------------------+
//| APEXComposite.mqh                                                  |
//| Version:  7.0                                                      |
//| Datum:    2026.03.05                                               |
//|                                                                    |
//| Inhalt:   7-Dimensionen Composite Score.                           |
//+------------------------------------------------------------------+
#ifndef APEX_COMPOSITE_MQH
#define APEX_COMPOSITE_MQH

#include "APEXDefinitions.mqh"
#include "APEXRange.mqh"
#include "APEXAOI.mqh"

void APEX_CalcComposite(SignalData &sig)
{
    // DIM 1: PREIS (20%)
    double za = MathAbs(sig.zscore);
    double zn = MathMin(8.0, (za / 3.5) * 8.0);
    double rb = 0.0;
    if(sig.regime == REG_RANGE)
    {
        if(sig.direction == SIG_BUY && sig.roc > 0.0)        rb =  2.0;
        else if(sig.direction == SIG_SELL && sig.roc < 0.0)  rb =  2.0;
        else if(sig.direction == SIG_BUY && sig.roc < -2.0)  rb = -1.0;
        else if(sig.direction == SIG_SELL && sig.roc > 2.0)  rb = -1.0;
    }
    else
    {
        if(sig.direction == SIG_BUY && sig.roc > 0.0)        rb = 2.0;
        else if(sig.direction == SIG_SELL && sig.roc < 0.0)  rb = 2.0;
    }
    sig.sub_price = MathMax(0.0, MathMin(10.0, zn + rb));
    
    // DIM 2: TRIGGER (20%)
    if(sig.pattern == "MORN_STAR" || sig.pattern == "EVE_STAR")         sig.sub_trigger = 10.0;
    else if(sig.pattern == "BULL_ENGULF" || sig.pattern == "BEAR_ENGULF") sig.sub_trigger = 7.5;
    else if(sig.pattern == "HAMMER" || sig.pattern == "SHOOT_STAR")       sig.sub_trigger = 5.0;
    else sig.sub_trigger = 0.0;
    
    // DIM 3: REGIME (10%)
    double es = 0.0, ab = 0.0;
    if(sig.regime == REG_RANGE)
    {
        es = MathMax(0.0, MathMin(10.0, (0.30 - sig.er_regime) / 0.30 * 10.0));
        if(sig.adx < 20.0) ab = 1.5; else if(sig.adx < 25.0) ab = 0.5;
    }
    else if(sig.regime == REG_TREND_UP || sig.regime == REG_TREND_DOWN)
    {
        es = MathMin(10.0, (sig.er_regime / 0.80) * 10.0);
        if(sig.adx > 35.0) ab = 1.5; else if(sig.adx > 25.0) ab = 0.5;
    }
    sig.sub_regime = MathMax(0.0, MathMin(10.0, es + ab));
    
    // DIM 4: RANGE (10%)
    sig.sub_range = APEX_RangeScore(sig.range, sig.regime, sig.direction);
    
    // DIM 5: AOI (15%)
    sig.sub_aoi = APEX_AOI_Score(sig.aoi);
    
    // DIM 6: VOLUMEN (15%)
    if(sig.rvol >= 2.5)      sig.sub_volume = 10.0;
    else if(sig.rvol <= 0.2) sig.sub_volume = 0.0;
    else                     sig.sub_volume = MathMin(10.0, (sig.rvol / 2.5) * 10.0);
    
    // DIM 7: KONTEXT (10%)
    double vps = (sig.vol_pctile / 100.0) * 5.0;
    double nb  = (sig.natr > 0.3) ? 2.0 : (sig.natr > 0.1) ? 1.0 : 0.0;
    double mb  = sig.mtf_aligned ? 3.0 : 0.0;
    sig.sub_context = MathMin(10.0, vps + nb + mb);
    
    // GEWICHTETER SCORE
    double gs = InpW_Price + InpW_Trigger + InpW_Regime + InpW_Range
              + InpW_AOI + InpW_Volume + InpW_Context;
    if(gs <= 0.0) gs = 1.0;
    
    sig.composite = (InpW_Price   / gs) * sig.sub_price
                  + (InpW_Trigger / gs) * sig.sub_trigger
                  + (InpW_Regime  / gs) * sig.sub_regime
                  + (InpW_Range   / gs) * sig.sub_range
                  + (InpW_AOI     / gs) * sig.sub_aoi
                  + (InpW_Volume  / gs) * sig.sub_volume
                  + (InpW_Context / gs) * sig.sub_context;
    sig.composite = NormalizeDouble(sig.composite, 2);
    
    double sld = MathAbs(sig.entry - sig.sl);
    double tpd = MathAbs(sig.tp_ind - sig.entry);
    sig.actual_rrr = (sld > 0.0) ? tpd / sld : 0.0;
    
    if(sig.composite >= 8.0)       sig.grade = "A+";
    else if(sig.composite >= 6.5)  sig.grade = "A";
    else if(sig.composite >= 5.0)  sig.grade = "B";
    else                           sig.grade = "C";
}

#endif