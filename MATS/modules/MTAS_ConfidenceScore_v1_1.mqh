// ============================================================================
//  Datei:       MTAS_ConfidenceScore_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: Signal-Score aus Teilwerten berechnen
// ============================================================================

#ifndef __MTAS_CONFIDENCESCORE_V1_1_MQH
#define __MTAS_CONFIDENCESCORE_V1_1_MQH

double CalcScore(
    const bool regime_ok,           // 0/1
    const double trend_value,       // 0..1
    const double pull_quality,      // 0..1
    const bool rsi_ok,              // 0/1
    const bool session_ok,          // 0/1
    const bool news_ok              // 0/1
) {
    const double wg_regime = 0.20, wg_trend = 0.25, wg_pull = 0.20, wg_rsi = 0.15, wg_session = 0.10, wg_news = 0.10;
    double score = 0.0;
    score += (regime_ok   ? 1.0 : 0.0)      * wg_regime;
    score += MathMin(MathAbs(trend_value) / 2.0, 1.0) * wg_trend;
    score += MathMax(pull_quality, 0.0)     * wg_pull;
    score += (rsi_ok      ? 1.0 : 0.0)      * wg_rsi;
    score += (session_ok  ? 1.0 : 0.0)      * wg_session;
    score += (news_ok     ? 1.0 : 0.0)      * wg_news;
    return score;
}

#endif // __MTAS_CONFIDENCESCORE_V1_1_MQH