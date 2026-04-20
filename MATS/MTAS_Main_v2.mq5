// ============================================================================
//  Datei:       MTAS_Main_v2.mq5
//  Projekt:     MTAS v2.0 – Multi-Asset Trading System
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Hauptdatei des Expert Advisors. Orchestriert alle Module.
//    Kein Trading-Logic-Code hier – nur Initialisierung, Verdrahtung und
//    den Pipeline-Aufruf je Asset und Bar.
//
//    Architektur (Schichtenmodell):
//      Inputs --> Init --> [OnTick/OnTimer] --> RunPipeline(Asset)
//        1. IndicatorEngine.Update()   -> IndicatorState
//        2. RegimeEngine.Classify()    -> RegimeState
//        3. SignalEngine.Evaluate()    -> SignalState
//        4. RiskEngine.Evaluate()      -> RiskState
//        5. ExitEngine.Evaluate()      -> ExitDecision (fuer offene Trades)
//        6. ExecutionEngine.CloseTrade() / OpenTrade()
//        7. ChartDisplay.Update()
//
//    Multi-Asset:
//      Pro Asset eine Instanz von IndicatorEngine + AssetContext.
//      RegimeEngine, SignalEngine, RiskEngine, ExitEngine, ExecutionEngine
//      sind gemeinsam (zustandslos, nur einmal instanziiert).
//
//  Abhaengigkeiten:
//    Alle MTAS_*.mqh Module in ./modules/
// ============================================================================

#include "modules/MTAS_Defines.mqh"
#include "modules/MTAS_Logger.mqh"
#include "modules/MTAS_DataModel.mqh"
#include "modules/MTAS_ValueBuffer.mqh"
#include "modules/MTAS_Indicators.mqh"
#include "modules/MTAS_Normalizer.mqh"
#include "modules/MTAS_IndicatorEngine.mqh"
#include "modules/MTAS_RegimeEngine.mqh"
#include "modules/MTAS_SessionFilter.mqh"
#include "modules/MTAS_NewsFilter.mqh"
#include "modules/MTAS_SignalEngine.mqh"
#include "modules/MTAS_RiskEngine.mqh"
#include "modules/MTAS_ExitEngine.mqh"
#include "modules/MTAS_ExecutionEngine.mqh"
#include "modules/MTAS_Email.mqh"
#include "modules/MTAS_ChartDisplay.mqh"

// ============================================================================
//  INPUT-PARAMETER
// ============================================================================

// --- Universe ---------------------------------------------------------------
input string   Inp_Universe          = "EURUSD,GBPUSD,XAUUSD,US500";
                                       // Kommagetrennte Asset-Liste

// --- Timeframes -------------------------------------------------------------
input ENUM_TIMEFRAMES Inp_TF_HTF     = PERIOD_H4;   // Higher Timeframe
input ENUM_TIMEFRAMES Inp_TF_LTF     = PERIOD_H1;   // Lower  Timeframe

// --- Indikatoren ------------------------------------------------------------
input int      Inp_LSMA_HTF          = 50;    // LSMA Periode HTF
input int      Inp_LSMA_LTF          = 50;    // LSMA Periode LTF
input int      Inp_BBW_Period        = 20;    // Bollinger Band Width Periode
input double   Inp_BBW_StdDev        = 2.0;   // BB StdDev-Multiplikator
input int      Inp_ATR_Period        = 14;    // ATR Periode
input int      Inp_RSI_Period        = 14;    // RSI Periode
input int      Inp_ZScore_Lookback   = 100;   // Ringpuffer-Groesse Z-Score

// --- Regime/Trend -----------------------------------------------------------
input double   Inp_Chop_Thresh       = 0.3;   // BBW-Z < Wert => CHOP
input double   Inp_Extreme_Thresh    = 2.0;   // BBW-Z > Wert => EXTREME
input double   Inp_Slope_Thresh      = 0.5;   // Slope-Z Schwelle fuer Trend

// --- Signal -----------------------------------------------------------------
input double   Inp_Pullback_ATR      = 0.3;   // Pullback-Toleranz in ATR
input double   Inp_RSI_Long          = 54.0;  // RSI muss > Wert fuer Long
input double   Inp_RSI_Short         = 46.0;  // RSI muss < Wert fuer Short
input double   Inp_Min_Confidence    = 0.65;  // Min. Score fuer Trade

// --- Session ----------------------------------------------------------------
input int      Inp_Sess_Start_UTC    = 8;     // Session-Start (Stunde UTC)
input int      Inp_Sess_End_UTC      = 17;    // Session-Ende  (Stunde UTC)
input bool     Inp_Block_Friday      = true;  // Freitag ab 21 UTC blockieren

// --- News-Filter ------------------------------------------------------------
input int      Inp_News_Before_Min   = 30;    // Minuten vor News blockieren
input int      Inp_News_After_Min    = 30;    // Minuten nach News blockieren

// --- Risiko (funded-safe) ---------------------------------------------------
input int      Inp_Max_Trades        = 3;     // Max. gleichzeitige Trades
input double   Inp_Risk_Pct          = 1.0;   // Risiko pro Trade in %
input double   Inp_Max_Daily_Loss    = 4.0;   // Max. Tagesverlust in %
input double   Inp_Equity_Stop       = 8.0;   // Equity-Stop in % DD
input double   Inp_Max_Spread_ATR    = 0.3;   // Max. Spread/ATR
input double   Inp_Min_ATR_Points    = 5.0;   // Min. ATR in Punkten
input double   Inp_SL_K_Normal       = 2.0;   // SL = LSMA - K * ATR
input double   Inp_TP_ATR            = 4.0;   // TP = LSMA + TP_ATR * ATR

// --- Exit -------------------------------------------------------------------
input bool     Inp_Exit_Chop         = true;  // Exit bei CHOP
input bool     Inp_Exit_TrendFlip    = true;  // Exit bei Trend-Flip
input bool     Inp_Exit_News         = true;  // Exit vor News
input bool     Inp_Exit_Session      = false; // Exit nach Session-Ende

// --- Logging ----------------------------------------------------------------
input MTAS_LogLevel Inp_LogLevel     = LOG_INFO;
input bool     Inp_LogToFile         = true;
input bool     Inp_SendEmails        = false; // Email-Benachrichtigungen

// --- Magic ------------------------------------------------------------------
input long     Inp_Magic_Base        = 200000; // Magic-Basis (+ Asset-Index)

// ============================================================================
//  GLOBALE OBJEKTE
// ============================================================================

// Engines (einmalig, teilen sich alle Assets)
MTAS_RegimeEngine    g_RegimeEngine;
MTAS_SignalEngine    g_SignalEngine;
MTAS_RiskEngine      g_RiskEngine;
MTAS_ExitEngine      g_ExitEngine;
MTAS_ExecutionEngine g_ExecEngine;
MTAS_SessionFilter   g_SessionFilter;
MTAS_NewsFilter      g_NewsFilter;

// Pro Asset eine IndicatorEngine und ein AssetContext
MTAS_IndicatorEngine g_IndEngines[MTAS_MAX_ASSETS];
AssetContext         g_Assets[MTAS_MAX_ASSETS];
int                  g_NumAssets = 0;

// Bar-Tracking (verhindert mehrfaches Ausfuehren auf demselben Bar)
datetime g_LastBarTime[MTAS_MAX_ASSETS];

// ============================================================================
//  OnInit
// ============================================================================
int OnInit()
{
    // Logger konfigurieren
    MTAS_LogSetLevel(Inp_LogLevel);
    MTAS_LogSetFile(Inp_LogToFile);
    MTAS_LogInfo("=== MTAS v2.0 OnInit ===");

    // Universe parsen
    string raw_assets[];
    int cnt = StringSplit(Inp_Universe, ',', raw_assets);
    g_NumAssets = 0;
    for(int i = 0; i < cnt && i < MTAS_MAX_ASSETS; i++)
    {
        StringTrimLeft(raw_assets[i]);
        StringTrimRight(raw_assets[i]);
        if(StringLen(raw_assets[i]) == 0) continue;

        string sym = raw_assets[i];

        // Asset initialisieren
        g_Assets[g_NumAssets].symbol       = sym;
        g_Assets[g_NumAssets].asset_index  = g_NumAssets;
        g_Assets[g_NumAssets].trade_state  = TRADE_IDLE;
        g_Assets[g_NumAssets].ticket       = 0;
        g_Assets[g_NumAssets].ratchet_sl   = 0.0;
        g_LastBarTime[g_NumAssets]         = 0;

        // IndicatorEngine initialisieren
        g_IndEngines[g_NumAssets].Init(
            sym,
            Inp_TF_HTF, Inp_TF_LTF,
            Inp_LSMA_HTF, Inp_LSMA_LTF,
            Inp_BBW_Period, Inp_BBW_StdDev,
            Inp_ATR_Period, Inp_RSI_Period,
            Inp_ZScore_Lookback);

        MTAS_LogInfo(StringFormat("Asset %d: %s", g_NumAssets, sym));
        g_NumAssets++;
    }

    if(g_NumAssets == 0)
    {
        MTAS_LogError("Kein gueltiges Asset in Universe! EA wird gestoppt.");
        return INIT_FAILED;
    }

    // Engines initialisieren
    g_RegimeEngine.Init(Inp_Chop_Thresh, Inp_Extreme_Thresh, Inp_Slope_Thresh);

    g_SignalEngine.Init(
        Inp_Pullback_ATR,
        Inp_RSI_Long, Inp_RSI_Short,
        Inp_Min_Confidence);

    g_RiskEngine.Init(
        Inp_Max_Trades, Inp_Max_Daily_Loss, Inp_Equity_Stop,
        Inp_Max_Spread_ATR, Inp_Min_ATR_Points,
        Inp_Risk_Pct, Inp_SL_K_Normal, Inp_TP_ATR,
        Inp_Magic_Base, Inp_Magic_Base + MTAS_MAX_ASSETS);

    g_ExitEngine.Init(
        Inp_Exit_Chop, Inp_Exit_TrendFlip, Inp_Exit_News, Inp_Exit_Session,
        Inp_SL_K_Normal);

    g_ExecEngine.Init(3, 1000, 10);

    g_SessionFilter.Init(Inp_Sess_Start_UTC, Inp_Sess_End_UTC, Inp_Block_Friday);
    g_NewsFilter.Init(Inp_News_Before_Min, Inp_News_After_Min, 2);

    // Chart aufraumen
    MTAS_DeleteAllChartObjects("MTAS_");

    // Tages-State initialisieren
    g_RiskEngine.UpdateDailyState();

    // Timer fuer Tages-Updates
    EventSetTimer(60);

    MTAS_LogInfo(StringFormat("MTAS v2.0 bereit: %d Assets, Magic=%I64d-%I64d",
                               g_NumAssets, Inp_Magic_Base, Inp_Magic_Base + MTAS_MAX_ASSETS));
    return INIT_SUCCEEDED;
}

// ============================================================================
//  OnDeinit
// ============================================================================
void OnDeinit(const int reason)
{
    MTAS_DeleteAllChartObjects("MTAS_");
    EventKillTimer();
    MTAS_LogInfo(StringFormat("MTAS v2.0 deinitialisiert (Grund=%d)", reason));
}

// ============================================================================
//  OnTimer – Taeglich Risikostatus aktualisieren
// ============================================================================
void OnTimer()
{
    g_RiskEngine.UpdateDailyState();
}

// ============================================================================
//  OnTick – Einstiegspunkt fuer jeden Tick
//  Prueft je Asset ob ein neuer Bar vorliegt, fuehrt dann Pipeline aus.
// ============================================================================
void OnTick()
{
    for(int a = 0; a < g_NumAssets; a++)
    {
        string sym = g_Assets[a].symbol;

        // Nur auf neuem LTF-Bar ausfuehren (kein Tick-Spam)
        datetime bar_time = iTime(sym, Inp_TF_LTF, 1);
        if(bar_time == g_LastBarTime[a]) continue;
        g_LastBarTime[a] = bar_time;

        RunPipeline(a);
    }
}

// ============================================================================
//  RunPipeline – Vollstaendige Signal-Execution-Pipeline fuer ein Asset
// ============================================================================
void RunPipeline(const int asset_idx)
{
    AssetContext &ctx = g_Assets[asset_idx];
    string sym = ctx.symbol;

    MTAS_LogDebug(StringFormat("--- Pipeline Start: %s ---", sym));

    // ------------------------------------------------------------------
    //  1. Indikatoren berechnen
    // ------------------------------------------------------------------
    IndicatorState ind;
    if(!g_IndEngines[asset_idx].Update(ind))
    {
        MTAS_LogDebug(StringFormat("Pipeline[%s]: Indikatoren nicht bereit", sym));
        return;
    }
    ctx.indicators = ind;

    // ------------------------------------------------------------------
    //  2. Regime klassifizieren
    // ------------------------------------------------------------------
    RegimeState regime;
    g_RegimeEngine.Classify(ind, regime);
    ctx.regime = regime;

    // ------------------------------------------------------------------
    //  3. Filter: Session + News
    // ------------------------------------------------------------------
    bool session_ok = g_SessionFilter.IsActive();
    bool news_ok    = !g_NewsFilter.IsNewsPending(sym);

    // ------------------------------------------------------------------
    //  4. Signal evaluieren
    // ------------------------------------------------------------------
    double cur_price = (regime.trend_htf == TREND_UP)
                       ? SymbolInfoDouble(sym, SYMBOL_ASK)
                       : SymbolInfoDouble(sym, SYMBOL_BID);

    SignalState sig;
    g_SignalEngine.Evaluate(ind, regime, cur_price, session_ok, news_ok, sig);
    ctx.signal = sig;

    // ------------------------------------------------------------------
    //  5. Exit-Check fuer offenen Trade
    // ------------------------------------------------------------------
    if(ctx.trade_state == TRADE_OPEN)
    {
        // Existenz pruefen (Trade noch offen?)
        if(!PositionSelectByTicket(ctx.ticket))
        {
            MTAS_LogInfo(StringFormat("Trade[%s] ticket=%I64u nicht mehr offen", sym, ctx.ticket));
            ctx.trade_state = TRADE_IDLE;
            ctx.ticket      = 0;
        }
        else
        {
            double close_price = (ctx.trade_dir == DIR_LONG)
                                  ? SymbolInfoDouble(sym, SYMBOL_BID)
                                  : SymbolInfoDouble(sym, SYMBOL_ASK);

            ExitDecision exit = g_ExitEngine.Evaluate(ctx, ind, regime, sig, close_price);

            // Ratchet-Stop aktualisieren
            if(exit.new_ratchet_sl != ctx.ratchet_sl)
            {
                ctx.ratchet_sl = exit.new_ratchet_sl;
                g_ExecEngine.ModifyStopLoss(ctx.ticket, ctx.ratchet_sl, sym);
            }

            // Trade schliessen?
            if(exit.should_exit)
            {
                double profit     = PositionGetDouble(POSITION_PROFIT);
                double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
                double profit_pct = (balance > 0.0) ? profit / balance * 100.0 : 0.0;

                bool closed = g_ExecEngine.CloseTrade(ctx.ticket, exit.reason);
                if(closed)
                {
                    if(Inp_SendEmails)
                        SendTradeCloseEmail(sym, profit, profit_pct, exit.reason, ctx.ticket);

                    ctx.trade_state = TRADE_IDLE;
                    ctx.ticket      = 0;
                    ctx.ratchet_sl  = 0.0;
                }
            }
        }
    }

    // ------------------------------------------------------------------
    //  6. Risikocheck
    // ------------------------------------------------------------------
    RiskState rs;
    g_RiskEngine.Evaluate(sym, ind, rs);
    ctx.risk = rs;

    // ------------------------------------------------------------------
    //  7. Trade eroeffnen (nur wenn kein offener Trade auf diesem Asset)
    // ------------------------------------------------------------------
    if(ctx.trade_state == TRADE_IDLE && rs.trade_allowed)
    {
        long magic = Inp_Magic_Base + asset_idx;
        TradePlan plan;

        bool plan_ok = g_RiskEngine.BuildTradePlan(sym, sig, ind, rs, magic, plan);
        ctx.plan = plan;

        if(plan_ok)
        {
            ExecutionResult res = g_ExecEngine.OpenTrade(plan);
            if(res.success)
            {
                ctx.trade_state  = TRADE_OPEN;
                ctx.ticket       = res.ticket;
                ctx.trade_dir    = plan.direction;
                ctx.entry_price  = PositionGetDouble(POSITION_PRICE_OPEN);
                ctx.initial_sl   = plan.stop_loss;
                ctx.ratchet_sl   = plan.stop_loss;
                ctx.take_profit  = plan.take_profit;
                ctx.lots         = plan.lots;
                ctx.open_time    = TimeCurrent();

                DrawEntryArrow(sym, 0, ctx.entry_price, plan.direction == DIR_LONG);

                if(Inp_SendEmails)
                    SendTradeOpenEmail(plan, res.ticket, rs.account_balance);
            }
            else
            {
                MTAS_LogWarn(StringFormat("Trade-Ausfuehrung fehlgeschlagen [%s]: %s",
                                           sym, res.error_msg));
            }
        }
    }

    // ------------------------------------------------------------------
    //  8. Chart aktualisieren (nur fuer Haupt-Symbol)
    // ------------------------------------------------------------------
    if(asset_idx == 0)
    {
        if(ctx.trade_state == TRADE_OPEN)
            DrawRatchetLine(sym, ctx.ratchet_sl, ctx.trade_dir == DIR_LONG);

        UpdateInfoPanelFull(sym, ind, regime, sig, rs, ctx);
    }

    MTAS_LogDebug(StringFormat("--- Pipeline Ende: %s ---", sym));
}

// ============================================================================
//  OnChartEvent – Chart-Interaktion (optional fuer UI)
// ============================================================================
void OnChartEvent(const int id, const long &lparam, const double &dparam,
                  const string &sparam)
{
    // Erweiterungspunkt fuer UI-Buttons (z.B. manueller Trade-Schluss)
    // Momentan: keine Implementierung
}

// ============================================================================
//  OnTradeTransaction – Tracking gesendeter/geschlossener Trades
// ============================================================================
void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest     &request,
                         const MqlTradeResult      &result)
{
    // Wird aufgerufen wenn eine Order-Transaktion ausgefuehrt wird.
    // Derzeit: Nur Logging.
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        MTAS_LogInfo(StringFormat("TradeTransaction: Deal=%I64u Order=%I64u Symbol=%s Profit=%.2f",
                                   trans.deal, trans.order, trans.symbol, trans.deal_profit));
    }
}

// ============================================================================
// Ende MTAS_Main_v2.mq5
// ============================================================================
