// ============================================================================
//  Datei:       MTAS_BBW_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: Bollinger Band Width Berechnung
// ============================================================================

#ifndef __MTAS_BBW_V1_1_MQH
#define __MTAS_BBW_V1_1_MQH

double CalcBBW(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const double stdev, const int shift = 1)
{
    if(period < 2 || stdev <= 0.0 || shift < 1) return(-1.0);

    double close[];
    if(CopyClose(symbol, tf, shift, period, close) != period) return(-1.0);

    double sum = 0.0;
    for(int i=0; i<period; i++) sum += close[i];
    double sma = sum / period;

    double var = 0.0;
    for(int i=0; i<period; i++) var += (close[i] - sma) * (close[i] - sma);
    double sdev = MathSqrt(var / period);

    double upper = sma + stdev * sdev;
    double lower = sma - stdev * sdev;
    if(sma == 0.0) return(-1.0);

    return (upper - lower) / sma;
}

#endif // __MTAS_BBW_V1_1_MQH