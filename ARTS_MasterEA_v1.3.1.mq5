//+------------------------------------------------------------------+
//|                                      ARTS_MasterEA_v1.3.1.mq5    |
//+------------------------------------------------------------------+
//| VERSION: 1.3.1                                                    |
//| LETZTES ÄNDERUNGSDATUM: 2025-02-09 00:30 UTC                     |
//| ÄNDERUNGEN: Individuelle Lookback-Inputs, Hybrid H4/H1 Logik    |
//+------------------------------------------------------------------+

#property copyright "ARTS System"
#property version   "1.31"
#property strict

#include "modules\ARTS_RegimeDetector_v1.3.1.mqh"
#include "modules\ARTS_IndicatorLibrary_v1.3.1.mqh"
#include "modules\ARTS_RiskManager_v1.3.mqh"
#include "modules\ARTS_SignalManager_v1.3.mqh"
#include "modules\ARTS_PositionManager_v1.3.mqh"
#include "modules\ARTS_TimezoneManager_v1.3.mqh"
#include "modules\ARTS_SpreadGuard_v1.3.mqh"
#include "modules\ARTS_MarketActivityAnalyzer_v1.3.mqh"
#include "modules\ARTS_NewsAndSpreadGuard_v1.3.mqh"
#include "modules\ARTS_CompositeScoreEngine_v1.3.1.mqh"
#include "modules\ARTS_MultiSymbolScanner_v1.3.1.mqh"

input group "=== MODUS ==="
input bool InpAutoTradingMode = false;
input bool InpUseBreakeven = true;
input bool InpUseTrailing = true;

input group "=== ALLGEMEIN ==="
input double InpRiskPercent = 0.7;
input double InpMaxDailyDD = 1.5;
input int InpMaxTradesDay = 3;

input group "=== REGIME ==="
input bool InpEnableRange = true;
input bool InpEnableTrend = true;

input group "=== LOOKBACK-PERIODEN ==="
input int InpLinRegLookback = 100;
input int InpATRPercLookback = 200;
input int InpATRPeriod = 14;
input int InpDonchianPeriod = 50;
input int InpEMAPeriodFast = 20;
input int InpEMAPeriodSlow = 50;
input int InpVolumeLookback = 20;

input group "=== SIGNAL-FILTER ==="
input double InpMinSignalScore = 75.0;
input double InpSuperSignalScore = 90.0;

input group "=== TRAILING ==="
input int InpTrailingPeriod = 10;
input double InpTrailingMultiplier = 2.5;

input group "=== BENACHRICHTIGUNGEN ==="
input bool InpEnableEmail = true;
input string InpEmailAddress = "";
input bool InpEnablePush = true;
input bool InpEnableChartAlert = true;
input bool InpEnableSound = true;

input group "=== ERWEITERT ==="
input int InpMagicNumber = 230101;
input int InpScanIntervalMinutes = 60;
input bool InpShowPanel = true;

CRegimeDetector* g_RegimeDetector = NULL;
CIndicatorLibrary* g_IndicatorsH4 = NULL;
CIndicatorLibrary* g_IndicatorsH1 = NULL;
CRiskManager* g_RiskManager = NULL;
CSignalManager* g_SignalManager = NULL;
CPositionManager* g_PositionManager = NULL;
CTimezoneManager* g_TimezoneManager = NULL;
CSpreadGuard* g_SpreadGuard = NULL;
CMarketActivityAnalyzer* g_ActivityAnalyzer = NULL;
CNewsAndSpreadGuard* g_NewsGuard = NULL;
CCompositeScoreEngine* g_ScoreEngine = NULL;
CMultiSymbolScanner* g_Scanner = NULL;

datetime g_LastScanTime = 0;

int OnInit()
{
   g_RegimeDetector = new CRegimeDetector(InpLinRegLookback, InpATRPercLookback, InpATRPeriod);
   g_IndicatorsH4 = new CIndicatorLibrary();
   g_IndicatorsH1 = new CIndicatorLibrary();
   g_RiskManager = new CRiskManager(InpRiskPercent, InpMaxDailyDD, InpMaxTradesDay, InpMagicNumber);
   g_SignalManager = new CSignalManager();
   g_PositionManager = new CPositionManager(InpMagicNumber);
   g_TimezoneManager = new CTimezoneManager();
   g_SpreadGuard = new CSpreadGuard();
   g_ActivityAnalyzer = new CMarketActivityAnalyzer(g_TimezoneManager);
   g_NewsGuard = new CNewsAndSpreadGuard(g_SpreadGuard);
   g_ScoreEngine = new CCompositeScoreEngine(g_RegimeDetector, g_IndicatorsH4, g_IndicatorsH1, g_ActivityAnalyzer);
   g_Scanner = new CMultiSymbolScanner(g_RegimeDetector, g_IndicatorsH4, g_IndicatorsH1, g_ScoreEngine, g_ActivityAnalyzer, g_NewsGuard, g_RiskManager);
   
   g_IndicatorsH4.SetPeriods(InpATRPeriod, InpEMAPeriodFast, InpEMAPeriodSlow, InpDonchianPeriod);
   g_IndicatorsH1.SetPeriods(InpATRPeriod, InpEMAPeriodFast, InpEMAPeriodSlow, InpDonchianPeriod);
   g_ScoreEngine.SetVolumeLookback(InpVolumeLookback);
   g_PositionManager.SetBreakevenEnabled(InpUseBreakeven);
   g_PositionManager.SetTrailingEnabled(InpUseTrailing);
   g_PositionManager.SetTrailingParameters(InpTrailingPeriod, InpTrailingMultiplier);
   g_SignalManager.SetEmailAddress(InpEmailAddress);
   g_SignalManager.SetNotificationOptions(InpEnableEmail, InpEnablePush, InpEnableChartAlert, InpEnableSound);
   g_Scanner.SetMinimumScore(InpMinSignalScore);
   
   Print("ARTS EA v1.3.1 gestartet");
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_RegimeDetector != NULL) delete g_RegimeDetector;
   if(g_IndicatorsH4 != NULL) delete g_IndicatorsH4;
   if(g_IndicatorsH1 != NULL) delete g_IndicatorsH1;
   if(g_RiskManager != NULL) delete g_RiskManager;
   if(g_SignalManager != NULL) delete g_SignalManager;
   if(g_PositionManager != NULL) delete g_PositionManager;
   if(g_TimezoneManager != NULL) delete g_TimezoneManager;
   if(g_SpreadGuard != NULL) delete g_SpreadGuard;
   if(g_ActivityAnalyzer != NULL) delete g_ActivityAnalyzer;
   if(g_NewsGuard != NULL) delete g_NewsGuard;
   if(g_ScoreEngine != NULL) delete g_ScoreEngine;
   if(g_Scanner != NULL) delete g_Scanner;
}

void OnTick()
{
   if(InpAutoTradingMode)
      g_PositionManager.ManageAllPositions();
   
   datetime current_time = TimeCurrent();
   if(current_time - g_LastScanTime < InpScanIntervalMinutes * 60) return;
   
   g_LastScanTime = current_time;
   
   if(!g_RiskManager.IsTradingAllowed()) return;
   
   SymbolSignal best_signals[];
   int signal_count = g_Scanner.ScanAllSymbols(best_signals);
   
   if(signal_count == 0) return;
   
   int trades_remaining = InpMaxTradesDay - g_RiskManager.GetTradesToday();
   int trades_to_execute = MathMin(signal_count, trades_remaining);
   
   for(int i = 0; i < trades_to_execute; i++)
   {
      if(best_signals[i].composite_score >= InpSuperSignalScore)
         Print("SUPER-SIGNAL: ", best_signals[i].symbol, " Score: ", best_signals[i].composite_score);
      
      ExecuteSignal(best_signals[i]);
   }
}

void ExecuteSignal(SymbolSignal &signal_data)
{
   g_SignalManager.SendSignal(signal_data.signal, signal_data.composite_score);
   
   if(InpAutoTradingMode)
   {
      if(g_PositionManager.OpenPosition(signal_data.signal, InpUseTrailing))
         g_RiskManager.RegisterTrade();
   }
   else
   {
      g_RiskManager.RegisterTrade();
   }
}
//+------------------------------------------------------------------+