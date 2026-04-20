// ============================================================================
//  Datei:       MTAS_Indicators.mqh
//  Projekt:     MTAS v2.0
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Schicht 1 der Pipeline: Indikatorberechnungen.
//    Enthaelt: LSMA (Least Squares MA + Slope), ATR (Wilder), RSI (Wilder),
//    BBW (Bollinger Band Width).
//    Alle Funktionen sind zustandslos (pure functions).
//    Eingabe: Symbol, Timeframe, Parameter.
//    Ausgabe: Berechneter Wert oder -1.0 bei Fehler.
//
//  Abhaengigkeiten: MTAS_Defines.mqh, MTAS_Logger.mqh
// ============================================================================
#ifndef __MTAS_INDICATORS_MQH
#define __MTAS_INDICATORS_MQH

#include "MTAS_Defines.mqh"
#include "MTAS_Logger.mqh"

// ============================================================================
//  Struct: LSMA_Result
// ============================================================================
struct LSMA_Result
{
    double value;   // LSMA-Endpunkt (Preisniveau am aktuellsten Bar)
    double slope;   // Steigung der Regressionslinie (Preis/Bar, raw)
    bool   valid;
};

// ============================================================================
//  Funktion: CalcLSMA
//  Berechnet Least-Squares Moving Average und Slope per linearer Regression.
//
//  Parameter:
//    symbol  – Handelsinstrument
//    tf      – Timeframe
//    period  – Anzahl Bars fuer Regression
//    shift   – Barversatz (1 = letzter abgeschlossener Bar, kein repainting)
//
//  Mathematik:
//    OLS auf N Punkte (x=1..N, y=close[N-1..0]).
//    slope = (N*sum_xy - sum_x*sum_y) / (N*sum_x2 - sum_x^2)
//    intercept = (sum_y - slope*sum_x) / N
//    value = intercept + slope * N   (Endpunkt = aktuellster Wert)
// ============================================================================
LSMA_Result CalcLSMA(const string symbol, const ENUM_TIMEFRAMES tf,
                     const int period, const int shift = 1)
{
    LSMA_Result r = {0.0, 0.0, false};
    if(period < 2 || shift < 0) return r;

    double close[];
    ArraySetAsSeries(close, false);
    if(CopyClose(symbol, tf, shift, period, close) != period)
    {
        MTAS_LogDebug(StringFormat("CalcLSMA: CopyClose fehlgeschlagen fuer %s TF=%d", symbol, (int)tf));
        return r;
    }

    double N     = (double)period;
    double sx    = 0.0, sx2  = 0.0, sy = 0.0, sxy = 0.0;
    for(int i = 0; i < period; i++)
    {
        double x = (double)(i + 1);
        double y = close[i];   // close[0]=aeltester, close[period-1]=neuester
        sx  += x;
        sx2 += x * x;
        sy  += y;
        sxy += x * y;
    }

    double denom = N * sx2 - sx * sx;
    if(MathAbs(denom) < 1e-12) return r;

    double slope     = (N * sxy - sx * sy) / denom;
    double intercept = (sy - slope * sx) / N;

    r.value = intercept + slope * N;   // Endpunkt
    r.slope = slope;
    r.valid = true;
    return r;
}

// ============================================================================
//  Funktion: CalcATR
//  Average True Range nach Wilder (Simple-Seed, dann Wilder-Smoothing).
//
//  Parameter:
//    period – ATR-Periode (Standard: 14)
//    shift  – Barversatz
//
//  Rueckgabe: ATR in Preis-Einheiten; -1.0 bei Datenfehler
// ============================================================================
double CalcATR(const string symbol, const ENUM_TIMEFRAMES tf,
               const int period, const int shift = 1)
{
    if(period < 1 || shift < 0) return -1.0;

    int    bars = period + 1 + shift;
    double high[], low[], close[];
    ArraySetAsSeries(high,  false);
    ArraySetAsSeries(low,   false);
    ArraySetAsSeries(close, false);

    // Hole bars ab shift (shift = Offset vom aktuellen Bar)
    if(CopyHigh (symbol, tf, shift, period + 1, high)  != period + 1) return -1.0;
    if(CopyLow  (symbol, tf, shift, period + 1, low)   != period + 1) return -1.0;
    if(CopyClose(symbol, tf, shift, period + 1, close) != period + 1) return -1.0;

    // Wilder-Seed: einfacher Durchschnitt der ersten 'period' TRs
    double atr = 0.0;
    for(int i = 1; i <= period; i++)
    {
        double hl = high[i] - low[i];
        double hc = MathAbs(high[i] - close[i - 1]);
        double lc = MathAbs(low[i]  - close[i - 1]);
        atr += MathMax(hl, MathMax(hc, lc));
    }
    atr /= period;
    return atr;
}

// ============================================================================
//  Funktion: CalcRSI
//  Relative Strength Index (Wilder, Simple Seed).
//
//  Rueckgabe: RSI 0..100; -1.0 bei Datenfehler
// ============================================================================
double CalcRSI(const string symbol, const ENUM_TIMEFRAMES tf,
               const int period, const int shift = 1)
{
    if(period < 1 || shift < 0) return -1.0;

    int    bars = period + 1;
    double close[];
    ArraySetAsSeries(close, false);
    if(CopyClose(symbol, tf, shift, bars, close) != bars) return -1.0;

    double avg_gain = 0.0, avg_loss = 0.0;
    for(int i = 1; i <= period; i++)
    {
        double diff = close[i] - close[i - 1];
        if(diff > 0.0) avg_gain += diff;
        else           avg_loss -= diff;
    }
    avg_gain /= period;
    avg_loss /= period;

    if(avg_loss == 0.0) return 100.0;
    double rs = MTAS_SAFE_DIV(avg_gain, avg_loss);
    return 100.0 - 100.0 / (1.0 + rs);
}

// ============================================================================
//  Funktion: CalcBBW
//  Bollinger Band Width = (Upper - Lower) / Middle
//  Normiert, asset-unabhaengig vergleichbar.
//
//  Rueckgabe: BBW >= 0.0; -1.0 bei Datenfehler
// ============================================================================
double CalcBBW(const string symbol, const ENUM_TIMEFRAMES tf,
               const int period, const double stdev_mult, const int shift = 1)
{
    if(period < 2 || stdev_mult <= 0.0 || shift < 0) return -1.0;

    double close[];
    ArraySetAsSeries(close, false);
    if(CopyClose(symbol, tf, shift, period, close) != period) return -1.0;

    double sum = 0.0;
    for(int i = 0; i < period; i++) sum += close[i];
    double sma = sum / period;
    if(MathAbs(sma) < 1e-12) return -1.0;

    double var = 0.0;
    for(int i = 0; i < period; i++) var += (close[i] - sma) * (close[i] - sma);
    double sd = MathSqrt(var / period);

    return (2.0 * stdev_mult * sd) / sma;
}

#endif // __MTAS_INDICATORS_MQH
