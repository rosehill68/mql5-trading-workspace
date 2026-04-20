// ============================================================================
//  Datei:       MTAS_SignalEngine.mqh
//  Projekt:     MTAS v2.0
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Schicht 3: Signal-Pipeline.
//    Eingabe: IndicatorState + RegimeState + Session/News-Status.
//    Ausgabe: SignalState mit Confidence Score.
//
//    Pipeline-Schritte:
//      1. Richtung aus RegimeState (HTF-Trend)
//      2. Pullback-Check: Abstand Preis zu LSMA_LTF <= pullback_atr_mult * ATR
//      3. RSI-Momentum: RSI > rsi_long_min fuer Long, RSI < rsi_short_max fuer Short
//      4. Session-Filter
//      5. News-Filter
//      6. Confidence Score (gewichtet)
//
//    Gewichte (Summe = 1.0):
//      Regime/Trend:    0.25
//      Trend-Staerke:   0.20
//      Pullback-Qualit: 0.20
//      RSI-Momentum:    0.15
//      Session:         0.10
//      News:            0.10
//
//  Abhaengigkeiten:
//    MTAS_DataModel.mqh, MTAS_SessionFilter.mqh, MTAS_NewsFilter.mqh,
//    MTAS_Logger.mqh
// ============================================================================
#ifndef __MTAS_SIGNALENGINE_MQH
#define __MTAS_SIGNALENGINE_MQH

#include "MTAS_DataModel.mqh"
#include "MTAS_SessionFilter.mqh"
#include "MTAS_NewsFilter.mqh"
#include "MTAS_Logger.mqh"

// ============================================================================
//  Klasse: MTAS_SignalEngine
// ============================================================================
class MTAS_SignalEngine
{
private:
    // Parameter
    double m_pullback_atr_mult; // Pullback-Toleranz in ATR-Vielfachen
    double m_rsi_long_min;      // RSI muss > diesem Wert fuer Long
    double m_rsi_short_max;     // RSI muss < diesem Wert fuer Short
    double m_min_confidence;    // Mindest-Score fuer gueltiges Signal

    // Gewichte (Summe = 1.0)
    static const double WG_REGIME  = 0.25;
    static const double WG_TREND   = 0.20;
    static const double WG_PULL    = 0.20;
    static const double WG_RSI     = 0.15;
    static const double WG_SESSION = 0.10;
    static const double WG_NEWS    = 0.10;

public:
    MTAS_SignalEngine(void) :
        m_pullback_atr_mult(0.3),
        m_rsi_long_min(54.0),
        m_rsi_short_max(46.0),
        m_min_confidence(0.65)
    {}

    void Init(const double pullback_atr_mult,
              const double rsi_long_min,
              const double rsi_short_max,
              const double min_confidence)
    {
        m_pullback_atr_mult = pullback_atr_mult;
        m_rsi_long_min      = rsi_long_min;
        m_rsi_short_max     = rsi_short_max;
        m_min_confidence    = min_confidence;
    }

    // -----------------------------------------------------------------------
    //  Evaluate – Vollstaendige Signal-Pipeline
    //
    //  Eingaben:
    //    ind           – IndicatorState (muss valid=true sein)
    //    regime        – RegimeState
    //    current_price – Aktueller Bid/Ask je nach Richtung
    //    session_ok    – Session-Filter-Ergebnis
    //    news_ok       – News-Filter-Ergebnis (true = kein News-Ereignis)
    // -----------------------------------------------------------------------
    void Evaluate(const IndicatorState &ind,
                  const RegimeState    &regime,
                  const double          current_price,
                  const bool            session_ok,
                  const bool            news_ok,
                  SignalState          &signal)
    {
        // Defaults
        signal.direction   = DIR_NONE;
        signal.pullback_ok = false;
        signal.pull_quality = 0.0;
        signal.rsi_ok      = false;
        signal.rsi_value   = ind.rsi_ltf;
        signal.session_ok  = session_ok;
        signal.news_ok     = news_ok;
        signal.confidence  = 0.0;

        if(!ind.valid || !regime.tradeable) return;

        // 1. Richtung aus HTF-Trend
        MTAS_Direction dir = DIR_NONE;
        if(regime.trend_htf == TREND_UP)   dir = DIR_LONG;
        if(regime.trend_htf == TREND_DOWN) dir = DIR_SHORT;
        if(dir == DIR_NONE) return;
        signal.direction = dir;

        // 2. Pullback-Check
        double dist      = MathAbs(current_price - ind.lsma_ltf);
        double tolerance = m_pullback_atr_mult * ind.atr_ltf;
        signal.pullback_ok   = (dist <= tolerance);
        signal.pull_quality  = signal.pullback_ok
                               ? MTAS_CLAMP(1.0 - dist / (tolerance + 1e-12), 0.0, 1.0)
                               : 0.0;

        // 3. RSI-Momentum
        double rsi = ind.rsi_ltf;
        if(dir == DIR_LONG  && rsi > m_rsi_long_min)  signal.rsi_ok = true;
        if(dir == DIR_SHORT && rsi < m_rsi_short_max) signal.rsi_ok = true;

        // 4. Confidence Score (gewichtet)
        double score = 0.0;
        score += WG_REGIME  * (regime.tradeable ? 1.0 : 0.0);
        score += WG_TREND   * regime.trend_strength;
        score += WG_PULL    * signal.pull_quality;
        score += WG_RSI     * (signal.rsi_ok ? 1.0 : 0.0);
        score += WG_SESSION * (session_ok ? 1.0 : 0.0);
        score += WG_NEWS    * (news_ok    ? 1.0 : 0.0);
        signal.confidence = ClampScore(score);

        MTAS_LogDebug(StringFormat(
            "Signal: dir=%d pull=%.2f rsi=%.1f(ok=%s) sess=%s news=%s score=%.3f",
            (int)dir, signal.pull_quality, rsi,
            signal.rsi_ok?"J":"N",
            session_ok?"J":"N", news_ok?"J":"N",
            signal.confidence));
    }

    double GetMinConfidence() const { return m_min_confidence; }
};

// ============================================================================
//  Hilfsfunktion: ClampScore (benoetigt von SignalEngine)
// ============================================================================
double ClampScore(const double v) { return MTAS_CLAMP(v, 0.0, 1.0); }

#endif // __MTAS_SIGNALENGINE_MQH
