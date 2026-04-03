// ============================================================================
//  Datei:       MTAS_RSI_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: Relative Strength Index (RSI, Wilder) Berechnung
// ============================================================================

#ifndef __MTAS_RSI_V1_1_MQH
#define __MTAS_RSI_V1_1_MQH

double CalcRSI(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int shift = 1)
{
    if(period < 1 || shift < 1) return(-1.0);

    double close[];
    int bars = period + 1;
    if(CopyClose(symbol, tf, shift, bars, close) != bars) return(-1.0);

    double gain = 0.0, loss = 0.0;

    for(int i = 1; i <= period; i++) {
        double diff = close[i - 1] - close[i];
        if(diff > 0) gain += diff;
        else loss -= diff;
    }
    gain /= period;
    loss /= period;

    if(loss == 0.0) return 100.0;
    double rs = gain / loss;
    return 100.0 - (100.0 / (1.0 + rs));
}

#endif // __MTAS_RSI_V1_1_MQH