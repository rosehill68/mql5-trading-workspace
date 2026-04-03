// ============================================================================
//  Datei:       MTAS_EntrySignal_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: EntrySignal-Check (Pullback + RSI + Richtung)
// ============================================================================

#ifndef __MTAS_ENTRYSIGNAL_V1_1_MQH
#define __MTAS_ENTRYSIGNAL_V1_1_MQH

struct Entry_Result {
    bool valid;           // Voraussetzungen erfüllt
    double pull_quality;  // max(1 - (Abstand/Toleranz), 0)
    double rsi_value;     // RSI zum Zeitpunkt
};

Entry_Result CheckEntry(long direction, double close, double lsma, double atr, double pullback_multi, double rsi, double rsi_long, double rsi_short)
{
    Entry_Result result = {false, 0.0, rsi};
    double dist = MathAbs(close - lsma);
    double tolerance = pullback_multi * atr;
    if(dist > tolerance) return result; // Kein Pullback

    if(direction > 0 && rsi > rsi_long)       // Long
        result.valid = true;
    else if(direction < 0 && rsi < rsi_short) // Short
        result.valid = true;
    else return result; // Momentum nicht bestätigt

    result.pull_quality = MathMax(1.0 - dist / tolerance, 0.0);
    return result;
}

#endif // __MTAS_ENTRYSIGNAL_V1_1_MQH