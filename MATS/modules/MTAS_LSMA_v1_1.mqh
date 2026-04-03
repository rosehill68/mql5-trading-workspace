// ============================================================================
//  Datei:       MTAS_LSMA_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: Least Squares Moving Average (LSMA) & Slope
// ============================================================================

#ifndef __MTAS_LSMA_V1_1_MQH
#define __MTAS_LSMA_V1_1_MQH

struct LSMA_Result {
    double value;      // LSMA (Endpunkt der Regressionslinie)
    double slope;      // Steigung
    bool   valid;      // true = Werte gültig
};

LSMA_Result CalcLSMA(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int shift = 1)
{
    LSMA_Result result;
    result.value = 0.0; result.slope = 0.0; result.valid = false;
    if(period < 2 || shift < 1) return(result);

    double close[];
    if(CopyClose(symbol, tf, shift, period, close) != period) return(result);

    double S_x = 0, S_x2 = 0, S_y = 0, S_xy = 0;
    for(int i = 0; i < period; i++) {
        int x = i + 1;
        double y = close[period - 1 - i];
        S_x  += x;
        S_x2 += x * x;
        S_y  += y;
        S_xy += x * y;
    }
    double N = (double)period;
    double denominator = N * S_x2 - S_x * S_x;
    if(denominator == 0) return(result);

    result.slope = (N * S_xy - S_x * S_y) / denominator;
    double intercept = (S_y - result.slope * S_x) / N;
    result.value = intercept + result.slope * N;
    result.valid = true;
    return(result);
}

#endif // __MTAS_LSMA_V1_1_MQH