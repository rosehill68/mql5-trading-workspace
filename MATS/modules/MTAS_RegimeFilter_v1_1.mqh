// ============================================================================
//  Datei:       MTAS_RegimeFilter_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: Regime-Filter für Chop/Trend/Extrem (BBW Z-Score)
// ============================================================================

#ifndef __MTAS_REGIMEFILTER_V1_1_MQH
#define __MTAS_REGIMEFILTER_V1_1_MQH

enum MTAS_Regime { REGIME_CHOP, REGIME_TREND, REGIME_EXTREME };

MTAS_Regime CheckRegime(const double bbw_zscore, const double chop_z = 0.5, const double extreme_z = 2.0)
{
    if(bbw_zscore < chop_z)
        return REGIME_CHOP;
    else if(bbw_zscore > extreme_z)
        return REGIME_EXTREME;
    else
        return REGIME_TREND;
}

#endif // __MTAS_REGIMEFILTER_V1_1_MQH