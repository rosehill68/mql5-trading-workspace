// ============================================================================
//  Datei:       MTAS_ExitEngine.mqh
//  Projekt:     MTAS v2.0
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Exit-Engine: Entscheidet ob ein offener Trade geschlossen werden soll.
//    Wird je Bar fuer jeden offenen Trade aufgerufen.
//
//    Exit-Gruende (in Pruefungsreihenfolge):
//      1. Ratchet-Stop ausgeloest (Preis hat laufend aktualisierten SL durchbrochen)
//      2. Take-Profit erreicht (Preis hat TP-Level erreicht)
//      3. Regime-Exit (Markt wechselt in CHOP)
//      4. HTF-Trend-Flip (Trendrichtung dreht)
//      5. News-Exit (News-Event beginnt)
//      6. Session-Ende (Trading-Stunden ueberschritten)
//
//    Ratchet-Stop:
//      Wird je Bar in RiskEngine.CalcRatchetStop() neu berechnet.
//      Die ExecutionEngine.ModifyStopLoss() passt den realen SL an.
//
//  Abhaengigkeiten: MTAS_DataModel.mqh, MTAS_Logger.mqh
// ============================================================================
#ifndef __MTAS_EXITENGINE_MQH
#define __MTAS_EXITENGINE_MQH

#include "MTAS_DataModel.mqh"
#include "MTAS_Logger.mqh"

// ============================================================================
//  Struct: ExitDecision
// ============================================================================
struct ExitDecision
{
    bool   should_exit;
    string reason;
    double new_ratchet_sl;   // Aktualisierter Ratchet-SL (immer berechnet)
};

// ============================================================================
//  Klasse: MTAS_ExitEngine
// ============================================================================
class MTAS_ExitEngine
{
private:
    bool   m_exit_on_regime_chop;    // Exit wenn Regime auf CHOP wechselt
    bool   m_exit_on_trend_flip;     // Exit bei HTF-Trend-Flip
    bool   m_exit_on_news;           // Exit vor News
    bool   m_exit_on_session_end;    // Exit wenn Session endet
    double m_sl_k_normal;            // K-Faktor fuer Ratchet-SL

public:
    MTAS_ExitEngine(void) :
        m_exit_on_regime_chop(true),
        m_exit_on_trend_flip(true),
        m_exit_on_news(true),
        m_exit_on_session_end(false),
        m_sl_k_normal(2.0)
    {}

    void Init(const bool   exit_on_chop,
              const bool   exit_on_flip,
              const bool   exit_on_news,
              const bool   exit_on_session_end,
              const double sl_k_normal)
    {
        m_exit_on_regime_chop  = exit_on_chop;
        m_exit_on_trend_flip   = exit_on_flip;
        m_exit_on_news         = exit_on_news;
        m_exit_on_session_end  = exit_on_session_end;
        m_sl_k_normal          = sl_k_normal;
    }

    // -----------------------------------------------------------------------
    //  Evaluate – Entscheidet Exit-Aktion fuer einen offenen Trade
    //
    //  Parameter:
    //    ctx       – AssetContext des offenen Trades
    //    ind       – Aktuelle IndicatorState
    //    regime    – Aktuelle RegimeState
    //    sig       – Aktuelle SignalState (enthaelt session_ok, news_ok)
    //    cur_price – Aktueller Bid (Long) oder Ask (Short)
    // -----------------------------------------------------------------------
    ExitDecision Evaluate(const AssetContext   &ctx,
                          const IndicatorState &ind,
                          const RegimeState    &regime,
                          const SignalState    &sig,
                          const double          cur_price)
    {
        ExitDecision dec = {false, "", ctx.ratchet_sl};

        if(ctx.trade_state != TRADE_OPEN) return dec;

        bool is_long = (ctx.trade_dir == DIR_LONG);

        // Ratchet-SL aktualisieren (immer, auch wenn kein Exit)
        if(ind.valid)
        {
            double new_sl = is_long
                            ? ind.lsma_ltf - m_sl_k_normal * ind.atr_ltf
                            : ind.lsma_ltf + m_sl_k_normal * ind.atr_ltf;
            if(is_long)  dec.new_ratchet_sl = MathMax(ctx.ratchet_sl, new_sl);
            else         dec.new_ratchet_sl = MathMin(ctx.ratchet_sl, new_sl);
        }

        // --- Check 1: Ratchet-Stop ---
        bool ratchet_hit = is_long
                           ? (cur_price <= dec.new_ratchet_sl)
                           : (cur_price >= dec.new_ratchet_sl);
        if(ratchet_hit)
        {
            dec.should_exit = true;
            dec.reason      = StringFormat("Ratchet-Stop (Preis=%.5f SL=%.5f)",
                                            cur_price, dec.new_ratchet_sl);
            MTAS_LogInfo(StringFormat("Exit[%s]: %s", ctx.symbol, dec.reason));
            return dec;
        }

        // --- Check 2: Take-Profit ---
        bool tp_hit = is_long
                      ? (cur_price >= ctx.take_profit)
                      : (cur_price <= ctx.take_profit);
        if(tp_hit)
        {
            dec.should_exit = true;
            dec.reason      = StringFormat("Take-Profit erreicht (%.5f)", ctx.take_profit);
            MTAS_LogInfo(StringFormat("Exit[%s]: %s", ctx.symbol, dec.reason));
            return dec;
        }

        // --- Check 3: Regime-Exit ---
        if(m_exit_on_regime_chop && regime.regime == REGIME_CHOP)
        {
            dec.should_exit = true;
            dec.reason      = "Regime-Exit (CHOP erkannt)";
            MTAS_LogInfo(StringFormat("Exit[%s]: %s", ctx.symbol, dec.reason));
            return dec;
        }

        // --- Check 4: Trend-Flip ---
        if(m_exit_on_trend_flip)
        {
            bool flip = (is_long  && regime.trend_htf == TREND_DOWN) ||
                        (!is_long && regime.trend_htf == TREND_UP);
            if(flip)
            {
                dec.should_exit = true;
                dec.reason      = StringFormat("Trend-Flip (HTF-Trend=%d)", (int)regime.trend_htf);
                MTAS_LogInfo(StringFormat("Exit[%s]: %s", ctx.symbol, dec.reason));
                return dec;
            }
        }

        // --- Check 5: News-Exit ---
        if(m_exit_on_news && !sig.news_ok)
        {
            dec.should_exit = true;
            dec.reason      = "News-Exit (News-Ereignis bevorsteht)";
            MTAS_LogInfo(StringFormat("Exit[%s]: %s", ctx.symbol, dec.reason));
            return dec;
        }

        // --- Check 6: Session-Ende ---
        if(m_exit_on_session_end && !sig.session_ok)
        {
            dec.should_exit = true;
            dec.reason      = "Session-Ende";
            MTAS_LogInfo(StringFormat("Exit[%s]: %s", ctx.symbol, dec.reason));
            return dec;
        }

        return dec;  // kein Exit
    }
};

#endif // __MTAS_EXITENGINE_MQH
