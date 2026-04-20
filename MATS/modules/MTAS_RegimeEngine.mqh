// ============================================================================
//  Datei:       MTAS_RegimeEngine.mqh
//  Projekt:     MTAS v2.0
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Schicht 2: Regime- und Trend-Klassifikation.
//    Eingabe: IndicatorState.
//    Ausgabe: RegimeState.
//
//    Regime-Logik (BBW Z-Score):
//      bbw_z < chop_thresh  => REGIME_CHOP    (kein Trade)
//      bbw_z > extreme_thresh => REGIME_EXTREME (kein neuer Trade)
//      sonst                => REGIME_TREND   (Trade erlaubt)
//
//    Trend-Logik (LSMA Slope Z-Score):
//      |slope_z| < slope_thresh => TREND_NONE
//      slope_z > thresh         => TREND_UP
//      slope_z < -thresh        => TREND_DOWN
//
//    Trend-Staerke:
//      trend_strength = clamp(|slope_htf_z| / 2.0, 0.0, 1.0)
//      (Normiert: Z-Score 2 entspricht max. Staerke 1.0)
//
//  Abhaengigkeiten: MTAS_DataModel.mqh, MTAS_Defines.mqh
// ============================================================================
#ifndef __MTAS_REGIMEENGINE_MQH
#define __MTAS_REGIMEENGINE_MQH

#include "MTAS_DataModel.mqh"
#include "MTAS_Logger.mqh"

// ============================================================================
//  Klasse: MTAS_RegimeEngine
//  Zustandslos – nur Klassifikationslogik, keine Puffer.
// ============================================================================
class MTAS_RegimeEngine
{
private:
    double m_chop_thresh;      // BBW-Z unterhalb => CHOP   (Standard: 0.3)
    double m_extreme_thresh;   // BBW-Z ueber     => EXTREME (Standard: 2.0)
    double m_slope_thresh;     // Slope-Z minimal fuer Trend (Standard: 0.5)

public:
    MTAS_RegimeEngine(void)
        : m_chop_thresh(0.3), m_extreme_thresh(2.0), m_slope_thresh(0.5) {}

    void Init(const double chop_thresh, const double extreme_thresh,
              const double slope_thresh)
    {
        m_chop_thresh    = chop_thresh;
        m_extreme_thresh = extreme_thresh;
        m_slope_thresh   = slope_thresh;
    }

    // -----------------------------------------------------------------------
    //  Classify – Fuellt RegimeState basierend auf IndicatorState
    // -----------------------------------------------------------------------
    void Classify(const IndicatorState &ind, RegimeState &regime)
    {
        // --- Regime ---
        if(!ind.valid)
        {
            regime.regime        = REGIME_UNKNOWN;
            regime.trend_htf     = TREND_NONE;
            regime.trend_ltf     = TREND_NONE;
            regime.trend_strength = 0.0;
            regime.tradeable     = false;
            return;
        }

        double bbwz = ind.bbw_htf_z;
        if(bbwz < m_chop_thresh)
            regime.regime = REGIME_CHOP;
        else if(bbwz > m_extreme_thresh)
            regime.regime = REGIME_EXTREME;
        else
            regime.regime = REGIME_TREND;

        // --- HTF-Trend ---
        double sz = ind.slope_htf_z;
        if(MathAbs(sz) < m_slope_thresh)
            regime.trend_htf = TREND_NONE;
        else if(sz > 0.0)
            regime.trend_htf = TREND_UP;
        else
            regime.trend_htf = TREND_DOWN;

        // --- LTF-Trend (Confirmation via LTF-Slope sign) ---
        if(ind.slope_ltf > 0.0)
            regime.trend_ltf = TREND_UP;
        else if(ind.slope_ltf < 0.0)
            regime.trend_ltf = TREND_DOWN;
        else
            regime.trend_ltf = TREND_NONE;

        // --- Trend-Staerke ---
        regime.trend_strength = MTAS_CLAMP(MathAbs(sz) / 2.0, 0.0, 1.0);

        // --- Handelbarkeit ---
        // Bedingung: TREND-Regime + HTF-Trend != NONE
        // + LTF-Trend muss mit HTF uebereinstimmen (Alignment)
        bool alignment = (regime.trend_htf != TREND_NONE) &&
                         (regime.trend_ltf == regime.trend_htf);
        regime.tradeable = (regime.regime == REGIME_TREND) && alignment;

        MTAS_LogDebug(StringFormat(
            "Regime: bbwz=%.2f regime=%d htf=%d ltf=%d strength=%.2f tradeable=%s",
            bbwz, (int)regime.regime, (int)regime.trend_htf, (int)regime.trend_ltf,
            regime.trend_strength, regime.tradeable ? "JA" : "NEIN"));
    }
};

#endif // __MTAS_REGIMEENGINE_MQH
