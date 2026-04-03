// ============================================================================
//  Datei:       MTAS_ATR_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: Average True Range (ATR) Berechnung (Wilder)
// ============================================================================

#ifndef __MTAS_ATR_V1_1_MQH
#define __MTAS_ATR_V1_1_MQH

double CalcATR(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int shift = 1)
{
    if(period < 1 || shift < 1) return(-1.0);

    double high[], low[], close[];
    int bars = period + 1;
    if(CopyHigh(symbol, tf, shift, bars, high) != bars) return(-1.0);
    if(CopyLow(symbol, tf, shift, bars, low) != bars) return(-1.0);
    if(CopyClose(symbol, tf, shift, bars, close) != bars) return(-1.0);

    double sum_TR = 0.0;
    for(int i = 1; i < bars; i++) {
        double hl = high[i] - low[i];
        double hc = MathAbs(high[i] - close[i-1]);
        double lc = MathAbs(low[i] - close[i-1]);
        sum_TR += MathMax(hl, MathMax(hc, lc));
    }
    return sum_TR / period;
}

#endif // __MTAS_ATR_V1_1_MQH