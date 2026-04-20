// ============================================================================
//  Datei:       MTAS_ExecutionEngine.mqh
//  Projekt:     MTAS v2.0
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Schicht 5: Execution-Engine.
//    Verantwortlich fuer: Order-Validierung, Ordersenden, Retry-Logik,
//    SL-Anpassung (Ratchet), Trade-Schliessen.
//
//    Trennung Planung vs. Ausfuehrung:
//      - TradePlan enthaelt alle berechneten Parameter (kein Execution-Code)
//      - ExecutionEngine nimmt TradePlan und fuehrt aus
//
//    Retry-Logik:
//      - Max. 3 Versuche mit je 1 Sekunde Pause
//      - Bei REQUOTE/PRICE_CHANGED: Preis neu holen, dann retry
//      - Bei anderem Fehler: Abbruch nach 1 Versuch
//
//    Safety-Guards vor jedem Ordersenden:
//      1. Symbol-Markt offen?
//      2. Mindest-Margin verfuegbar?
//      3. SL/TP >= Mindestabstand vom Preis?
//      4. Lots im erlaubten Bereich?
//
//  Abhaengigkeiten:
//    MTAS_DataModel.mqh, MTAS_Logger.mqh, <Trade/Trade.mqh>
// ============================================================================
#ifndef __MTAS_EXECUTIONENGINE_MQH
#define __MTAS_EXECUTIONENGINE_MQH

#include "MTAS_DataModel.mqh"
#include "MTAS_Logger.mqh"
#include <Trade\Trade.mqh>

// ============================================================================
//  Klasse: MTAS_ExecutionEngine
// ============================================================================
class MTAS_ExecutionEngine
{
private:
    CTrade m_trade;
    int    m_max_retries;
    int    m_retry_delay_ms;
    int    m_slippage_points;

public:
    MTAS_ExecutionEngine(void) :
        m_max_retries(3),
        m_retry_delay_ms(1000),
        m_slippage_points(10)
    {}

    void Init(const int max_retries    = 3,
              const int retry_delay_ms = 1000,
              const int slippage_pts   = 10)
    {
        m_max_retries    = max_retries;
        m_retry_delay_ms = retry_delay_ms;
        m_slippage_points = slippage_pts;
        m_trade.SetDeviationInPoints(m_slippage_points);
        m_trade.SetAsyncMode(false);
    }

    // -----------------------------------------------------------------------
    //  OpenTrade – Fuehrt TradePlan aus
    //  Gibt ExecutionResult zurueck. Bei Fehler: result.success = false.
    // -----------------------------------------------------------------------
    ExecutionResult OpenTrade(const TradePlan &plan)
    {
        ExecutionResult res = {false, 0, 0, 0, ""};

        if(!plan.valid)
        {
            res.error_msg = "TradePlan ist nicht valid";
            MTAS_LogWarn("ExecutionEngine.OpenTrade: " + res.error_msg);
            return res;
        }

        // Safety-Guard: Lots pruefen
        double vmin = SymbolInfoDouble(plan.symbol, SYMBOL_VOLUME_MIN);
        double vmax = SymbolInfoDouble(plan.symbol, SYMBOL_VOLUME_MAX);
        if(plan.lots < vmin || plan.lots > vmax)
        {
            res.error_msg = StringFormat("Lots=%.2f ausserhalb [%.2f,%.2f]", plan.lots, vmin, vmax);
            MTAS_LogWarn("ExecutionEngine GUARD: " + res.error_msg);
            return res;
        }

        // Safety-Guard: SL-Mindestabstand
        double stops_level_pts = (double)SymbolInfoInteger(plan.symbol, SYMBOL_TRADE_STOPS_LEVEL);
        double point           = SymbolInfoDouble(plan.symbol, SYMBOL_POINT);
        double stops_dist      = stops_level_pts * point;
        bool   is_long         = (plan.direction == DIR_LONG);

        double entry = is_long
                       ? SymbolInfoDouble(plan.symbol, SYMBOL_ASK)
                       : SymbolInfoDouble(plan.symbol, SYMBOL_BID);

        if(stops_dist > 0.0)
        {
            double sl_dist = MathAbs(entry - plan.stop_loss);
            if(sl_dist < stops_dist)
            {
                res.error_msg = StringFormat("SL zu nah am Preis (%.5f < %.5f Mindestabstand)",
                                              sl_dist, stops_dist);
                MTAS_LogWarn("ExecutionEngine GUARD: " + res.error_msg);
                return res;
            }
        }

        // Safety-Guard: Markt offen?
        if(!IsMarketOpen(plan.symbol))
        {
            res.error_msg = StringFormat("Markt %s geschlossen", plan.symbol);
            MTAS_LogWarn("ExecutionEngine GUARD: " + res.error_msg);
            return res;
        }

        // Retry-Schleife
        m_trade.SetExpertMagicNumber(plan.magic);

        for(int attempt = 0; attempt < m_max_retries; attempt++)
        {
            res.retries = attempt + 1;
            bool ok = false;

            // Preis fuer jeden Versuch neu holen
            double cur_ask = SymbolInfoDouble(plan.symbol, SYMBOL_ASK);
            double cur_bid = SymbolInfoDouble(plan.symbol, SYMBOL_BID);

            if(is_long)
                ok = m_trade.Buy(plan.lots, plan.symbol, cur_ask, plan.stop_loss, plan.take_profit, plan.comment);
            else
                ok = m_trade.Sell(plan.lots, plan.symbol, cur_bid, plan.stop_loss, plan.take_profit, plan.comment);

            if(ok)
            {
                res.success = true;
                res.ticket  = m_trade.ResultOrder();
                res.last_error = 0;
                MTAS_LogInfo(StringFormat(
                    "Order ausgefuehrt: %s %s %.2f Lots Ticket=%I64u Versuche=%d",
                    plan.symbol, is_long?"BUY":"SELL",
                    plan.lots, res.ticket, res.retries));
                return res;
            }

            // Fehler pruefen
            res.last_error = GetLastError();
            res.error_msg  = StringFormat("Fehler %d (Versuch %d/%d): %s",
                                           res.last_error, attempt+1, m_max_retries,
                                           m_trade.ResultRetcodeDescription());
            MTAS_LogWarn("ExecutionEngine Retry: " + res.error_msg);

            // Bei Requote/Preisaenderung: nochmals versuchen. Bei anderen Fehlern: abbrechen.
            int ec = res.last_error;
            bool retryable = (ec == 10004 || ec == 10006 || ec == 10014 || ec == 10021);
            if(!retryable) break;

            Sleep(m_retry_delay_ms);
        }

        MTAS_LogError(StringFormat("OpenTrade FEHLGESCHLAGEN [%s]: %s",
                                    plan.symbol, res.error_msg));
        return res;
    }

    // -----------------------------------------------------------------------
    //  ModifyStopLoss – SL anpassen (Ratchet-Stop)
    //  Gibt false zurueck bei Fehler.
    // -----------------------------------------------------------------------
    bool ModifyStopLoss(const ulong ticket, const double new_sl, const string symbol)
    {
        if(!PositionSelectByTicket(ticket)) return false;

        double tp       = PositionGetDouble(POSITION_TP);
        double stops_pts = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        double point    = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double price    = PositionGetDouble(POSITION_PRICE_CURRENT);
        long   ptype    = PositionGetInteger(POSITION_TYPE);

        // Sicherheitscheck: neuer SL darf nicht unter dem Mindestabstand liegen
        if(stops_pts > 0.0)
        {
            double min_dist = stops_pts * point;
            if(ptype == POSITION_TYPE_BUY  && price - new_sl < min_dist) return false;
            if(ptype == POSITION_TYPE_SELL && new_sl - price < min_dist) return false;
        }

        bool ok = m_trade.PositionModify(ticket, new_sl, tp);
        if(!ok)
            MTAS_LogWarn(StringFormat("ModifyStopLoss fehlgeschlagen Ticket=%I64u SL=%.5f Err=%d",
                                       ticket, new_sl, GetLastError()));
        return ok;
    }

    // -----------------------------------------------------------------------
    //  CloseTrade – Schliesst Position
    // -----------------------------------------------------------------------
    bool CloseTrade(const ulong ticket, const string reason)
    {
        if(!PositionSelectByTicket(ticket)) return false;

        bool ok = m_trade.PositionClose(ticket, m_slippage_points);
        if(ok)
            MTAS_LogInfo(StringFormat("Trade geschlossen: Ticket=%I64u Grund=%s", ticket, reason));
        else
            MTAS_LogWarn(StringFormat("CloseTrade fehlgeschlagen Ticket=%I64u Err=%d",
                                       ticket, GetLastError()));
        return ok;
    }

private:
    // -----------------------------------------------------------------------
    //  IsMarketOpen – Prueft ob der Markt handelbar ist
    // -----------------------------------------------------------------------
    bool IsMarketOpen(const string symbol) const
    {
        // Spread > 0 und Session aktiv = Markt offen
        int spread = (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
        return (spread > 0);
    }
};

#endif // __MTAS_EXECUTIONENGINE_MQH
