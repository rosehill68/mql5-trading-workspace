// ============================================================================
//  Datei:       MTAS_TrendFilter_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: Trendrichtung-Filter über LSMA-Slope Z-Score
// ============================================================================

#ifndef __MTAS_TRENDFILTER_V1_1_MQH
#define __MTAS_TRENDFILTER_V1_1_MQH

enum MTAS_Trend { TREND_NONE, TREND_UP, TREND_DOWN };

MTAS_Trend CheckTrend(const double slope_zscore, const double thresh = 0.5)
{
    if(MathAbs(slope_zscore) < thresh)
        return TREND_NONE;
    else if(slope_zscore > thresh)
        return TREND_UP;
    else if(slope_zscore < -thresh)
        return TREND_DOWN;
    return TREND_NONE;
}

#endif // __MTAS_TRENDFILTER_V1_1_MQH