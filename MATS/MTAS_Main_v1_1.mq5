// ============================================================================
// Datei:       MTAS_Main_v1_1.mq5
// Projekt:     MATS (Multi-Asset Trading System)
// Version:     1.1
// Letzte Änderung: 2026-04-03
// Autor:       [Dein Name/Team]
// Beschreibung: Hauptdatei des MTAS-EA, Multi-Asset-fähig, modular
// ============================================================================

#include <modules/MTAS_GlobalState_v1_1.mqh>
#include <modules/MTAS_LSMA_v1_1.mqh>
#include <modules/MTAS_BBW_v1_1.mqh>
#include <modules/MTAS_ATR_v1_1.mqh>
#include <modules/MTAS_RSI_v1_1.mqh>
#include <modules/MTAS_Normalizer_v1_1.mqh>
#include <modules/MTAS_ValueBuffer_v1_1.mqh>
#include <modules/MTAS_RegimeFilter_v1_1.mqh>
#include <modules/MTAS_TrendFilter_v1_1.mqh>
#include <modules/MTAS_SessionFilter_v1_1.mqh>
#include <modules/MTAS_NewsFilter_v1_1.mqh>
#include <modules/MTAS_EntrySignal_v1_1.mqh>
#include <modules/MTAS_ConfidenceScore_v1_1.mqh>
#include <modules/MTAS_RiskManager_v1_1.mqh>
#include <modules/MTAS_PositionSizer_v1_1.mqh>
#include <modules/MTAS_OrderManager_v1_1.mqh>
#include <modules/MTAS_ExitSignal_v1_1.mqh>
#include <modules/MTAS_ChartVisuals_v1_1.mqh>
#include <modules/MTAS_ChartCleanup_v1_1.mqh>
#include <modules/MTAS_ChartUI_v1_1.mqh>
#include <modules/MTAS_Logger_v1_1.mqh>
#include <modules/MTAS_Email_v1_1.mqh>
#include <modules/MTAS_Exception_v1_1.mqh>
// ...importiere ggf. weitere Module

// === INPUTS ===
input string Universe            = "EURUSD,GBPUSD,XAUUSD,US500";
input int    BBW_Period         = 20;
input double BBW_StdDev         = 2.0;
input int    LSMA_Period_HTF    = 50;
input int    LSMA_Period_LTF    = 50;
input int    ATR_Period         = 14;
input int    RSI_Period         = 14;
input double Slope_Thresh       = 0.5;
input double Pullback_ATR       = 0.3;
input double RSI_Long_Thresh    = 54.0;
input double RSI_Short_Thresh   = 46.0;
input double K_Low              = 1.5;
input double K_Normal           = 2.0;
input double K_High             = 3.0;
input double MaxSpreadATR       = 0.3;
input double RiskPerTrade       = 1.0;
input int    MaxTrades          = 3;
input int    SessStart          = 8;
input int    SessEnd            = 17;
input double TP_ATR             = 4.0;
input double Confidence_Thresh  = 0.70;
input int    Debug_Level        = 1; // 0=Off, 1=Basic, 2=Full

// === STATE ===
string   assets[20];
int      n_assets=0;

// === INITIALISIERUNG ===
int OnInit()
{
    // Clean Chart beim Start
    MTAS_DeleteAllChartObjects("MTAS_");
    ArrayInitialize(assets, ""); // Init
    
    int cnt = StringSplit(Universe, ',', assets);
    n_assets = 0;
    for(int i=0; i<cnt && i<ArraySize(assets); i++) {
        StringTrimLeft(assets[i]);
        StringTrimRight(assets[i]);
        if(StringLen(assets[i])>0) n_assets++;
    }
    if(n_assets == 0) {
        Print("MTAS: Kein Asset angegeben!");
        return(INIT_FAILED);
    }
    EventSetTimer(60); // optional: alle 60 Sekunden, ansonsten per OnTick
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    MTAS_DeleteAllChartObjects("MTAS_");
    EventKillTimer();
}

void OnTimer()
{
    RunMTAS();
}

// === HAUPTSCHLEIFE ===
void OnTick()
{
    RunMTAS();
}

void RunMTAS()
{
    bool session_active = IsSessionActive(SessStart, SessEnd);
    bool news_block = IsNewsPending();

    for(int a=0; a<n_assets; a++)
    {
        string sym = assets[a];
        // Indikatoren laden
        LSMA_Result lhtf = CalcLSMA(sym, PERIOD_H4, LSMA_Period_HTF, 1);
        double bbw_htf   = CalcBBW(sym, PERIOD_H4, BBW_Period, BBW_StdDev, 1);
        double atr_ltf   = CalcATR(sym, PERIOD_H1, ATR_Period, 1);
        double rsi_ltf   = CalcRSI(sym, PERIOD_H1, RSI_Period, 1);
        LSMA_Result lltf = CalcLSMA(sym, PERIOD_H1, LSMA_Period_LTF, 1);

        // Z-Score-Normalisierung (Demo - für echten Betrieb Rolling Buffer je Asset verwenden!)
        double slope_htf_z = lhtf.slope; // Hier z.B. norm_slope aus ValueBuffer
        double bbw_htf_z   = bbw_htf;    // dito

        MTAS_Regime regime = CheckRegime(bbw_htf_z, 0.5, 2.0);
        MTAS_Trend  trend  = CheckTrend(slope_htf_z, Slope_Thresh);
        long direction = (trend == TREND_UP) ? 1 : ((trend == TREND_DOWN) ? -1 : 0);
        bool regime_ok = (regime == REGIME_TREND);

        // EntrySignal-Check
        double price = SymbolInfoDouble(sym, (direction>0)?SYMBOL_BID:SYMBOL_ASK);
        Entry_Result entry = CheckEntry(direction, price, lltf.value, atr_ltf, Pullback_ATR,
                                        rsi_ltf, RSI_Long_Thresh, RSI_Short_Thresh);
        bool rsi_ok = entry.valid;
        bool pull_ok = (entry.pull_quality > 0.0);

        // Score
        double score = CalcScore(regime_ok, slope_htf_z, entry.pull_quality, rsi_ok, session_active, !news_block);

        // RiskCheck
        RiskManagerResult rman = CanOpenTrade(MaxTrades, 100, 100, MaxSpreadATR, 100000, 100099, sym, ATR_Period);

        // (TradeEntry Demo - ohne AssetState, vollständiges Trading siehe volle Architektur)
        if(score >= Confidence_Thresh && rman.allowed && pull_ok && rsi_ok && direction != 0)
        {
            double stop_pips = MathAbs(lltf.value - (direction > 0 ? lltf.value - K_Normal*atr_ltf : lltf.value + K_Normal*atr_ltf)) / SymbolInfoDouble(sym,SYMBOL_POINT);
            double lots = CalcLots(AccountInfoDouble(ACCOUNT_BALANCE), RiskPerTrade, stop_pips, sym);
            double sl = (direction > 0) ? lltf.value - K_Normal*atr_ltf : lltf.value + K_Normal*atr_ltf;
            double tp = (direction > 0) ? lltf.value + TP_ATR*atr_ltf : lltf.value - TP_ATR*atr_ltf;
            string comment = "MTAS_" + sym + "_" + ((direction>0)?"LONG":"SHORT");
            ulong magic = 100001 + a;

            int open_trades = CountOpenTrades(100000, 100099);

            if(open_trades < MaxTrades)
                OpenOrder(sym, direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, lots, 0.0, sl, tp, magic, comment);

            MTAS_Log("Order für Symbol " + sym + " gesendet (" + ((direction>0)?"LONG":"SHORT") + ")", LOG_INFO);
        }

        // --- ExitCheck + Ratchet-Trading/Visualisierung nicht vollständig, Demo-Bereich s.o.

        // Chart-Panel/Regimefarbe (optional)
        DrawInfoPanel("MTAS v1.1\nAsset: " + sym + "\nScore: " + DoubleToString(score,2));
        DrawRegimeBG(regime);
    }
}