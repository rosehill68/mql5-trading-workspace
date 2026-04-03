// ============================================================================
//  Datei:       MTAS_Normalizer_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: Z-Score- und Volatilitäts-Normalisierung
// ============================================================================

#ifndef __MTAS_NORMALIZER_V1_1_MQH
#define __MTAS_NORMALIZER_V1_1_MQH

// arr[]: muss mindestens lookback Elemente enthalten (akt. Wert an [0])
double CalcZScore(const double &arr[], const int lookback)
{
    if(ArraySize(arr) < lookback || lookback < 2) return(0.0);

    double mean = 0.0;
    for(int i = 0; i < lookback; i++)
        mean += arr[i];
    mean /= lookback;

    double var = 0.0;
    for(int i = 0; i < lookback; i++)
        var += (arr[i] - mean) * (arr[i] - mean);

    double stddev = MathSqrt(var / lookback);
    if(stddev == 0.0) return(0.0);

    double last = arr[0];
    return (last - mean) / stddev;
}

// Slope durch ATR teilen (Wert/ATR)
double NormalizeSlope(const double slope, const double atr)
{
    if(atr == 0.0) return 0.0;
    return slope / atr;
}

#endif // __MTAS_NORMALIZER_V1_1_MQH