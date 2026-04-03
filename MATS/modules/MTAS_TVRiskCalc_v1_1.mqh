// ============================================================================
//  Datei:       MTAS_TVRiskCalc_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: Lot- und DD-Prüfung für externes TV-Konto
// ============================================================================

#ifndef __MTAS_TVRISKCALC_V1_1_MQH
#define __MTAS_TVRISKCALC_V1_1_MQH

bool CanSendTVSignal(int tv_max, int tv_open, double dd_now, double dd_soft, double dd_hard)
{
    if(tv_open >= tv_max) return false;
    if(dd_now >= dd_soft) return false;
    if(dd_now >= dd_hard) return false;
    return true;
}

double CalcTVLots(double tv_balance, double risk_pct, double stop_pips, double pip_value)
{
    double risk_usd = tv_balance * risk_pct / 100.0;
    if(pip_value<=0.0 || stop_pips<=0.0) return 0.0;
    return risk_usd / (stop_pips * pip_value);
}

#endif // __MTAS_TVRISKCALC_V1_1_MQH