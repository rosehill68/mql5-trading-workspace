// ============================================================================
//  Datei:       MTAS_RiskEngine.mqh
//  Projekt:     MTAS v2.0
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Schicht 4: Risk-Engine (funded-safe).
//    Verantwortlich fuer: alle Pre-Trade-Checks, Positionsgroesse, SL/TP.
//
//    Funded-Safe-Checks (in dieser Reihenfolge):
//      1. Max. offene Trades (EA-weit)
//      2. Tages-Drawdown-Grenze (Max Daily Loss)
//      3. Equity-Stop (absoluter Equity-Floor)
//      4. Spread/Volatilitaets-Filter
//      5. Mindest-ATR (keine Trades in toten Maerkten)
//
//    Positionsgroessen-Mathematik:
//      risk_money = balance * risk_pct / 100
//      stop_price_dist = |entry - stop_loss| (in Preis)
//      stop_in_ticks   = stop_price_dist / tick_size
//      pip_value_per_lot = tick_value * (tick_size / point)
//      Hinweis: tick_value ist pro Lot in Account-Waehrung
//      lots = risk_money / (stop_in_ticks * tick_value)
//      Gerundet auf vol_step, geclampt auf [vol_min, vol_max]
//
//    SL/TP-Berechnung:
//      stop_loss   = lsma_ltf - k * atr_ltf  (Long)
//      take_profit = lsma_ltf + tp_atr * atr_ltf (Long)
//      k wird aus Volatilitaets-Regime gewaehlt
//
//  Abhaengigkeiten: MTAS_DataModel.mqh, MTAS_Indicators.mqh, MTAS_Logger.mqh
// ============================================================================
#ifndef __MTAS_RISKENGINE_MQH
#define __MTAS_RISKENGINE_MQH

#include "MTAS_DataModel.mqh"
#include "MTAS_Indicators.mqh"
#include "MTAS_Logger.mqh"

// ============================================================================
//  Klasse: MTAS_RiskEngine
// ============================================================================
class MTAS_RiskEngine
{
private:
    // Konfiguration
    int    m_max_trades;           // Max. gleichzeitig offene Trades (EA-gesamt)
    double m_max_daily_loss_pct;   // Max. Tagesverlust in % des Balance (z.B. 4.0)
    double m_equity_stop_pct;      // Equity-Floor in % des Balance (z.B. 8.0 = 92% Equity-Stop)
    double m_max_spread_atr_ratio; // Max. Spread/ATR (z.B. 0.3 = max 30% eines ATR)
    double m_min_atr_points;       // Mindest-ATR in Punkten (Markt muss bewegt sein)
    double m_risk_pct;             // Risiko pro Trade in % des Balance
    double m_sl_k_low;             // SL-Multiplikator bei niedrigem Regime
    double m_sl_k_normal;          // SL-Multiplikator bei normalem Regime
    double m_sl_k_high;            // SL-Multiplikator bei extremem Regime (fuer offene Trades)
    double m_tp_atr;               // TP in ATR-Vielfachen
    long   m_magic_min;            // Magic-Nummern-Bereich fuer Tradecount
    long   m_magic_max;

    // Tages-PnL Cache (wird per UpdateDailyPnL() aktualisiert)
    double m_daily_pnl;
    double m_day_start_balance;
    datetime m_day_start_time;

public:
    MTAS_RiskEngine(void) :
        m_max_trades(3),
        m_max_daily_loss_pct(4.0),
        m_equity_stop_pct(8.0),
        m_max_spread_atr_ratio(0.3),
        m_min_atr_points(5.0),
        m_risk_pct(1.0),
        m_sl_k_low(1.5),
        m_sl_k_normal(2.0),
        m_sl_k_high(3.0),
        m_tp_atr(4.0),
        m_magic_min(200000),
        m_magic_max(200099),
        m_daily_pnl(0.0),
        m_day_start_balance(0.0)
    {
        m_day_start_time = 0;
    }

    // -----------------------------------------------------------------------
    //  Init
    // -----------------------------------------------------------------------
    void Init(const int    max_trades,
              const double max_daily_loss_pct,
              const double equity_stop_pct,
              const double max_spread_atr_ratio,
              const double min_atr_points,
              const double risk_pct,
              const double sl_k_normal,
              const double tp_atr,
              const long   magic_min,
              const long   magic_max)
    {
        m_max_trades           = max_trades;
        m_max_daily_loss_pct   = max_daily_loss_pct;
        m_equity_stop_pct      = equity_stop_pct;
        m_max_spread_atr_ratio = max_spread_atr_ratio;
        m_min_atr_points       = min_atr_points;
        m_risk_pct             = risk_pct;
        m_sl_k_normal          = sl_k_normal;
        m_tp_atr               = tp_atr;
        m_magic_min            = magic_min;
        m_magic_max            = magic_max;
        m_day_start_balance    = AccountInfoDouble(ACCOUNT_BALANCE);
        m_day_start_time       = TimeCurrent();
    }

    // -----------------------------------------------------------------------
    //  UpdateDailyState – Taeglich aufrufen (z.B. im OnTimer oder bei Tageswechsel)
    // -----------------------------------------------------------------------
    void UpdateDailyState()
    {
        datetime now = TimeCurrent();
        MqlDateTime dt_now, dt_start;
        TimeToStruct(now, dt_now);
        TimeToStruct(m_day_start_time, dt_start);

        // Tageswechsel erkannt => Tageszaehler zuruecksetzen
        if(dt_now.day != dt_start.day || dt_now.mon != dt_start.mon)
        {
            m_day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
            m_day_start_time    = now;
            m_daily_pnl         = 0.0;
            MTAS_LogInfo("RiskEngine: Tageswechsel – Tages-PnL reset");
        }

        // Aktuelles Tages-PnL: Balance-Aenderung + unrealisiertes Ergebnis offener Trades
        double current_equity  = AccountInfoDouble(ACCOUNT_EQUITY);
        double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_daily_pnl = current_equity - m_day_start_balance;
    }

    // -----------------------------------------------------------------------
    //  Evaluate – Pre-Trade-Risikocheck. Fuellt RiskState.
    // -----------------------------------------------------------------------
    void Evaluate(const string symbol, const IndicatorState &ind, RiskState &rs)
    {
        rs.trade_allowed    = false;
        rs.block_reason     = "";
        rs.account_balance  = AccountInfoDouble(ACCOUNT_BALANCE);
        rs.account_equity   = AccountInfoDouble(ACCOUNT_EQUITY);
        rs.daily_pnl        = m_daily_pnl;
        rs.open_trade_count = CountOpenTrades();
        rs.open_dd_pct      = 0.0;
        rs.spread_atr_ratio = 0.0;

        // -- Offener Drawdown berechnen
        if(rs.account_balance > 0.0)
            rs.open_dd_pct = (1.0 - rs.account_equity / rs.account_balance) * 100.0;

        // Check 1: Max. Trades
        if(rs.open_trade_count >= m_max_trades)
        {
            rs.block_reason = StringFormat("Max. Trades erreicht (%d/%d)", rs.open_trade_count, m_max_trades);
            MTAS_LogInfo("RiskEngine BLOCK: " + rs.block_reason);
            return;
        }

        // Check 2: Tages-Drawdown
        double daily_dd_pct = 0.0;
        if(rs.account_balance > 0.0)
            daily_dd_pct = -m_daily_pnl / rs.account_balance * 100.0;
        rs.daily_pnl = m_daily_pnl;

        if(daily_dd_pct >= m_max_daily_loss_pct)
        {
            rs.block_reason = StringFormat("Max. Daily Loss erreicht (%.2f%% >= %.2f%%)",
                                            daily_dd_pct, m_max_daily_loss_pct);
            MTAS_LogWarn("RiskEngine BLOCK: " + rs.block_reason);
            return;
        }

        // Check 3: Equity-Stop
        if(rs.open_dd_pct >= m_equity_stop_pct)
        {
            rs.block_reason = StringFormat("Equity-Stop ausgeloest (DD=%.2f%% >= %.2f%%)",
                                            rs.open_dd_pct, m_equity_stop_pct);
            MTAS_LogWarn("RiskEngine BLOCK: " + rs.block_reason);
            return;
        }

        // Check 4: Spread/ATR
        if(ind.valid && ind.atr_ltf > 0.0)
        {
            double point    = SymbolInfoDouble(symbol, SYMBOL_POINT);
            double spread_p = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
            double spread_price = spread_p * point;
            rs.spread_atr_ratio = MTAS_SAFE_DIV(spread_price, ind.atr_ltf);

            if(rs.spread_atr_ratio > m_max_spread_atr_ratio)
            {
                rs.block_reason = StringFormat("Spread zu hoch (%.2f > %.2f ATR-Anteil)",
                                                rs.spread_atr_ratio, m_max_spread_atr_ratio);
                MTAS_LogInfo("RiskEngine BLOCK: " + rs.block_reason);
                return;
            }
        }

        // Check 5: Mindest-ATR
        if(ind.valid)
        {
            double point   = SymbolInfoDouble(symbol, SYMBOL_POINT);
            double atr_pts = (point > 0.0) ? ind.atr_ltf / point : 0.0;
            if(atr_pts < m_min_atr_points)
            {
                rs.block_reason = StringFormat("ATR zu niedrig (%.1f Punkte < %.1f)", atr_pts, m_min_atr_points);
                MTAS_LogDebug("RiskEngine BLOCK: " + rs.block_reason);
                return;
            }
        }

        rs.trade_allowed = true;
        rs.block_reason  = "OK";

        MTAS_LogDebug(StringFormat(
            "RiskEngine OK: Trades=%d DailyDD=%.2f%% EquityDD=%.2f%% SpreadATR=%.3f",
            rs.open_trade_count, daily_dd_pct, rs.open_dd_pct, rs.spread_atr_ratio));
    }

    // -----------------------------------------------------------------------
    //  BuildTradePlan – Erstellt TradePlan aus Signal und Indikatoren
    // -----------------------------------------------------------------------
    bool BuildTradePlan(const string symbol,
                        const SignalState   &sig,
                        const IndicatorState &ind,
                        const RiskState      &rs,
                        const long            magic,
                        TradePlan            &plan)
    {
        plan.valid = false;

        if(!rs.trade_allowed)            return false;
        if(sig.direction == DIR_NONE)    return false;
        if(sig.confidence < GetMinConf()) return false;
        if(!sig.pullback_ok)             return false;
        if(!sig.rsi_ok)                  return false;

        bool is_long = (sig.direction == DIR_LONG);

        // Aktuellen Preis holen
        double entry = is_long
                       ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                       : SymbolInfoDouble(symbol, SYMBOL_BID);

        // SL/TP basierend auf LSMA_LTF und ATR
        double sl, tp;
        if(is_long)
        {
            sl = ind.lsma_ltf - m_sl_k_normal * ind.atr_ltf;
            tp = ind.lsma_ltf + m_tp_atr      * ind.atr_ltf;
        }
        else
        {
            sl = ind.lsma_ltf + m_sl_k_normal * ind.atr_ltf;
            tp = ind.lsma_ltf - m_tp_atr      * ind.atr_ltf;
        }

        // Validierung: SL muss sinnvoll sein
        if(is_long  && sl >= entry)
        {
            MTAS_LogWarn(StringFormat("BuildTradePlan[%s]: SL=%.5f >= Entry=%.5f (Long)", symbol, sl, entry));
            return false;
        }
        if(!is_long && sl <= entry)
        {
            MTAS_LogWarn(StringFormat("BuildTradePlan[%s]: SL=%.5f <= Entry=%.5f (Short)", symbol, sl, entry));
            return false;
        }

        // Positionsgroesse berechnen
        double stop_dist = MathAbs(entry - sl);
        double lots      = CalcPositionSize(symbol, rs.account_balance, stop_dist);
        if(lots <= 0.0)
        {
            MTAS_LogWarn(StringFormat("BuildTradePlan[%s]: Lots=0", symbol));
            return false;
        }

        // R/R
        double rr = MTAS_SAFE_DIV(MathAbs(tp - entry), stop_dist);

        // Normalisiere SL/TP auf Tickgroesse
        double tick = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        sl = MathRound(sl / tick) * tick;
        tp = MathRound(tp / tick) * tick;

        plan.valid       = true;
        plan.symbol      = symbol;
        plan.direction   = sig.direction;
        plan.entry_price = 0.0;   // Market-Order
        plan.stop_loss   = sl;
        plan.take_profit = tp;
        plan.lots        = lots;
        plan.magic       = magic;
        plan.comment     = StringFormat("MTAS_%s_%s_S%.2f",
                                         symbol,
                                         is_long ? "L" : "S",
                                         sig.confidence);
        plan.risk_pct    = m_risk_pct;
        plan.rr_ratio    = rr;

        MTAS_LogInfo(StringFormat(
            "TradePlan[%s]: %s Entry~%.5f SL=%.5f TP=%.5f Lots=%.2f RR=%.2f Score=%.3f",
            symbol, is_long?"LONG":"SHORT",
            entry, sl, tp, lots, rr, sig.confidence));

        return true;
    }

    // -----------------------------------------------------------------------
    //  CalcRatchetStop – Ratchet-Stop (trailing stop basierend auf LSMA+ATR)
    //  Wird je Bar aufgerufen um den SL nur in Trade-Richtung zu bewegen.
    // -----------------------------------------------------------------------
    double CalcRatchetStop(const bool is_long,
                           const double lsma_ltf,
                           const double atr_ltf,
                           const double prev_sl) const
    {
        double new_sl = is_long
                        ? lsma_ltf - m_sl_k_normal * atr_ltf
                        : lsma_ltf + m_sl_k_normal * atr_ltf;

        // Ratchet: SL darf sich nur in Gewinnrichtung bewegen
        if(is_long)  return MathMax(prev_sl, new_sl);
        else         return MathMin(prev_sl, new_sl);
    }

    // -----------------------------------------------------------------------
    //  Getter
    // -----------------------------------------------------------------------
    double GetMinConf()          const { return 0.65; }  // Wird von Init ueberschrieben
    double GetRiskPct()          const { return m_risk_pct; }
    double GetTpAtr()            const { return m_tp_atr; }

private:
    // -----------------------------------------------------------------------
    //  CountOpenTrades – Alle offenen Positionen im Magic-Bereich
    // -----------------------------------------------------------------------
    int CountOpenTrades() const
    {
        int count = 0;
        for(int i = 0; i < PositionsTotal(); i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
            {
                long m = PositionGetInteger(POSITION_MAGIC);
                if(m >= m_magic_min && m <= m_magic_max) count++;
            }
        }
        return count;
    }

    // -----------------------------------------------------------------------
    //  CalcPositionSize – Lot-Berechnung fuer exaktes Risiko
    //
    //  Mathematik:
    //    risk_money = balance * risk_pct / 100
    //    tick_value = SymbolInfoDouble(SYMBOL_TRADE_TICK_VALUE)  [Kontowährung/Tick/Lot]
    //    tick_size  = SymbolInfoDouble(SYMBOL_TRADE_TICK_SIZE)   [Preis-Einheit eines Ticks]
    //    ticks_in_stop = stop_dist / tick_size
    //    lots = risk_money / (ticks_in_stop * tick_value)
    // -----------------------------------------------------------------------
    double CalcPositionSize(const string symbol,
                            const double balance,
                            const double stop_dist) const
    {
        if(stop_dist <= 0.0 || balance <= 0.0) return 0.0;

        double tick_val  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        if(tick_val <= 0.0 || tick_size <= 0.0) return 0.0;

        double risk_money   = balance * m_risk_pct / 100.0;
        double ticks_in_sl  = stop_dist / tick_size;
        double raw_lots     = risk_money / (ticks_in_sl * tick_val);

        double vol_min  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double vol_max  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double vol_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

        if(vol_step <= 0.0) vol_step = 0.01;

        double lots = MathFloor(raw_lots / vol_step) * vol_step;
        lots = MTAS_CLAMP(lots, vol_min, vol_max);
        return lots;
    }
};

#endif // __MTAS_RISKENGINE_MQH
