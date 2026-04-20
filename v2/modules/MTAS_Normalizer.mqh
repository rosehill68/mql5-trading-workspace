// ============================================================================
//  Datei:       MTAS_Normalizer.mqh
//  Projekt:     MTAS v2.0
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Normalisierungsfunktionen: Z-Score, Slope/ATR, Percentile-Clamp.
//    Alle Funktionen zustandslos. Z-Score-Berechnung ueber uebergebene Arrays.
//
//  Abhaengigkeiten: MTAS_Defines.mqh
// ============================================================================
#ifndef __MTAS_NORMALIZER_MQH
#define __MTAS_NORMALIZER_MQH

#include "MTAS_Defines.mqh"

// ============================================================================
//  CalcZScore – Z-Score des ersten Elements gegenueber dem gesamten Array
//
//  arr[0] = neuester Wert, arr[n-1] = aeltester Wert
//  Gibt 0.0 zurueck wenn n < 2 oder StdDev == 0
// ============================================================================
double CalcZScore(const double &arr[], const int lookback)
{
    int n = MathMin(lookback, ArraySize(arr));
    if(n < 2) return 0.0;

    double mean = 0.0;
    for(int i = 0; i < n; i++) mean += arr[i];
    mean /= n;

    double var = 0.0;
    for(int i = 0; i < n; i++) var += (arr[i] - mean) * (arr[i] - mean);
    double sd = MathSqrt(var / n);

    if(sd == 0.0) return 0.0;
    return MTAS_SAFE_DIV(arr[0] - mean, sd);
}

// ============================================================================
//  NormalizeSlope – Slope in ATR-Einheiten (asset-unabhaengig)
//  Gibt 0.0 zurueck wenn ATR == 0
// ============================================================================
double NormalizeSlope(const double slope, const double atr)
{
    return MTAS_SAFE_DIV(slope, atr);
}

// ============================================================================
//  ClampScore – Begrenzt Score auf [0.0, 1.0]
// ============================================================================
double ClampScore(const double v) { return MTAS_CLAMP(v, 0.0, 1.0); }

#endif // __MTAS_NORMALIZER_MQH
