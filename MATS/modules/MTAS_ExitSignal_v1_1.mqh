// ============================================================================
//  Datei:       MTAS_ExitSignal_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: Haupt-Exit-Logik, inkl. Ratchet-Stop
// ============================================================================

#ifndef __MTAS_EXITSIGNAL_V1_1_MQH
#define __MTAS_EXITSIGNAL_V1_1_MQH

struct ExitSignalResult {
    bool should_exit;
    string reason;
};

double UpdateRatchetStop(bool is_long, double lsma_ltf, double atr, double k, double prev_sl)
{
    double basis_sl = is_long 
                      ? (lsma_ltf - k * atr)
                      : (lsma_ltf + k * atr);
    if(!is_long)
        return MathMin(prev_sl, basis_sl);
    else
        return MathMax(prev_sl, basis_sl);
}

ExitSignalResult CheckExit(
    bool is_long,
    double ratchet_stop, double price, // ratchet SL, aktueller Preis
    bool hit_tp,                       // Take Profit erreicht
    bool regime_exit,                  // Chop oder Extreme
    bool htf_trend_flip,               // Trendwechsel
    bool news_exit                     // News
) {
    ExitSignalResult result = {false, ""};
    // Ratchet-Stop ausgelöst
    if((is_long && price <= ratchet_stop) || (!is_long && price >= ratchet_stop)) {
        result.should_exit = true;
        result.reason = "Ratchet-Stop";
        return result;
    }
    if(hit_tp) {
        result.should_exit = true;
        result.reason = "Take Profit";
        return result;
    }
    if(regime_exit) {
        result.should_exit = true;
        result.reason = "Regime-Exit";
        return result;
    }
    if(htf_trend_flip) {
        result.should_exit = true;
        result.reason = "Trend-Reversal";
        return result;
    }
    if(news_exit) {
        result.should_exit = true;
        result.reason = "News-Exit";
        return result;
    }
    return result;
}

#endif // __MTAS_EXITSIGNAL_V1_1_MQH