//+------------------------------------------------------------------+
//|                       ARTS_MultiSymbolScanner_v1.3.1.mqh         |
//+------------------------------------------------------------------+
//| VERSION: 1.3.1                                                    |
//| LETZTES ÄNDERUNGSDATUM: 2025-02-09 00:25 UTC                     |
//| ÄNDERUNGEN: Hybrid H4/H1 Timeframe-Logik implementiert          |
//+------------------------------------------------------------------+

#property copyright "ARTS System"
#property version   "1.31"
#property strict

#include <modules\ARTS_RegimeDetector_v1.3.1.mqh>
#include <modules\ARTS_IndicatorLibrary_v1.3.1.mqh>
#include <modules\ARTS_CompositeScoreEngine_v1.3.1.mqh>
#include <modules\ARTS_MarketActivityAnalyzer_v1.3.mqh>
#include <modules\ARTS_NewsAndSpreadGuard_v1.3.mqh>
#include <modules\ARTS_SignalManager_v1.3.mqh>
#include <modules\ARTS_RiskManager_v1.3.mqh>

struct SymbolSignal
{
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   TradingSignal signal;
   ScoreBreakdown score_breakdown;
   double composite_score;
   datetime detected_time;
};

class CMultiSymbolScanner
{
private:
   CRegimeDetector* m_regime_detector;
   CIndicatorLibrary* m_indicators_h4;
   CIndicatorLibrary* m_indicators_h1;
   CCompositeScoreEngine* m_score_engine;
   CMarketActivityAnalyzer* m_activity_analyzer;
   CNewsAndSpreadGuard* m_news_guard;
   CRiskManager* m_risk_manager;
   int m_max_symbols;
   double m_min_signal_score;
   
public:
   CMultiSymbolScanner(CRegimeDetector* regime, 
                       CIndicatorLibrary* indicators_h4,
                       CIndicatorLibrary* indicators_h1,
                       CCompositeScoreEngine* score_engine,
                       CMarketActivityAnalyzer* activity, 
                       CNewsAndSpreadGuard* news_guard,
                       CRiskManager* risk_manager)
   {
      m_regime_detector = regime;
      m_indicators_h4 = indicators_h4;
      m_indicators_h1 = indicators_h1;
      m_score_engine = score_engine;
      m_activity_analyzer = activity;
      m_news_guard = news_guard;
      m_risk_manager = risk_manager;
      m_max_symbols = 10;
      m_min_signal_score = 75.0;
   }
   
   void SetMinimumScore(double min_score) { m_min_signal_score = min_score; }
   
   int ScanAllSymbols(SymbolSignal &best_signals[])
   {
      ArrayResize(best_signals, 0);
      int symbols_scanned = 0;
      int symbols_in_watch = SymbolsTotal(true);
      
      for(int i = 0; i < symbols_in_watch && symbols_scanned < m_max_symbols; i++)
      {
         string symbol = SymbolName(i, true);
         if(!SymbolInfoInteger(symbol, SYMBOL_SELECT)) continue;
         
         SymbolSignal found_signal;
         if(ScanSingleSymbol(symbol, found_signal))
         {
            if(found_signal.composite_score >= m_min_signal_score)
            {
               ArrayResize(best_signals, ArraySize(best_signals) + 1);
               best_signals[ArraySize(best_signals) - 1] = found_signal;
            }
         }
         
         symbols_scanned++;
      }
      
      if(ArraySize(best_signals) > 1) SortSignalsByScore(best_signals);
      
      return ArraySize(best_signals);
   }
   
private:
   bool ScanSingleSymbol(string symbol, SymbolSignal &output_signal)
   {
      if(!m_news_guard.IsTradingSafe(symbol)) return false;
      
      double activity = m_activity_analyzer.GetActivityScore(symbol);
      if(activity < 50) return false;
      
      m_regime_detector.SetSymbol(symbol, PERIOD_H4);
      ENUM_MARKET_REGIME regime = m_regime_detector.DetectRegime();
      
      if(regime == REGIME_NO_TRADE) return false;
      
      m_indicators_h4.Initialize(symbol, PERIOD_H4);
      m_indicators_h1.Initialize(symbol, PERIOD_H1);
      
      if(regime == REGIME_RANGE) return ScanRangeSignal(symbol, output_signal);
      else if(regime == REGIME_STRONG_TREND || regime == REGIME_WEAK_TREND) return ScanTrendSignal(symbol, output_signal);
      
      return false;
   }
   
   bool ScanRangeSignal(string symbol, SymbolSignal &output)
   {
      double upper_h4 = m_indicators_h4.GetDonchianUpper(1);
      double lower_h4 = m_indicators_h4.GetDonchianLower(1);
      
      if(upper_h4 == 0 || lower_h4 == 0) return false;
      
      double current_price_h1 = iClose(symbol, PERIOD_H1, 1);
      double atr_h4 = m_indicators_h4.GetATR(1);
      double buffer = 0.3 * atr_h4;
      
      bool is_long = false;
      bool signal_found = false;
      
      if(current_price_h1 <= lower_h4 + buffer)
      {
         is_long = true;
         signal_found = true;
      }
      else if(current_price_h1 >= upper_h4 - buffer)
      {
         is_long = false;
         signal_found = true;
      }
      
      if(!signal_found) return false;
      
      ScoreBreakdown breakdown = m_score_engine.CalculateRangeSignalScore(symbol, is_long, upper_h4, lower_h4);
      
      if(breakdown.total_score < m_min_signal_score) return false;
      
      double entry = iClose(symbol, PERIOD_H1, 0);
      double sl = is_long ? lower_h4 - (0.5 * atr_h4) : upper_h4 + (0.5 * atr_h4);
      double risk_pips = MathAbs(entry - sl);
      double tp_conservative = is_long ? entry + (2.0 * risk_pips) : entry - (2.0 * risk_pips);
      double tp_aggressive = is_long ? upper_h4 - buffer : lower_h4 + buffer;
      
      if((is_long && tp_aggressive < tp_conservative) || (!is_long && tp_aggressive > tp_conservative))
         tp_aggressive = is_long ? entry + (2.5 * risk_pips) : entry - (2.5 * risk_pips);
      
      double position_size = m_risk_manager.CalculatePositionSize(symbol, entry, sl);
      
      output.symbol = symbol;
      output.timeframe = PERIOD_H4;
      output.score_breakdown = breakdown;
      output.composite_score = breakdown.total_score;
      output.detected_time = TimeCurrent();
      
      output.signal.signal_type = is_long ? SIGNAL_LONG : SIGNAL_SHORT;
      output.signal.symbol = symbol;
      output.signal.entry_price = entry;
      output.signal.stop_loss = sl;
      output.signal.take_profit_conservative = tp_conservative;
      output.signal.take_profit_aggressive = tp_aggressive;
      output.signal.use_trailing_stop = true;
      output.signal.trailing_atr_multiplier = 2.5;
      output.signal.trailing_period = 10;
      output.signal.position_size = position_size;
      output.signal.regime = m_regime_detector.GetRegimeAsString();
      output.signal.strategy = "Range Reversal";
      output.signal.signal_time = TimeCurrent();
      
      return true;
   }
   
   bool ScanTrendSignal(string symbol, SymbolSignal &output)
   {
      double keltner_upper_h4 = m_indicators_h4.GetKeltnerUpper(2.0, 1);
      double keltner_lower_h4 = m_indicators_h4.GetKeltnerLower(2.0, 1);
      double keltner_middle_h4 = m_indicators_h4.GetKeltnerMiddle(1);
      
      if(keltner_upper_h4 == 0 || keltner_lower_h4 == 0) return false;
      
      double current_price_h1 = iClose(symbol, PERIOD_H1, 1);
      double prev_price_h1 = iClose(symbol, PERIOD_H1, 2);
      
      bool is_long = false;
      bool signal_found = false;
      
      if(prev_price_h1 <= keltner_upper_h4 && current_price_h1 > keltner_upper_h4)
      {
         is_long = true;
         signal_found = true;
      }
      else if(prev_price_h1 >= keltner_lower_h4 && current_price_h1 < keltner_lower_h4)
      {
         is_long = false;
         signal_found = true;
      }
      
      if(!signal_found) return false;
      
      ScoreBreakdown breakdown = m_score_engine.CalculateTrendSignalScore(symbol, is_long, is_long ? keltner_upper_h4 : keltner_lower_h4);
      
      if(breakdown.total_score < m_min_signal_score) return false;
      
      double entry = iClose(symbol, PERIOD_H1, 0);
      double sl = keltner_middle_h4;
      double risk_pips = MathAbs(entry - sl);
      double tp_conservative = is_long ? entry + (2.0 * risk_pips) : entry - (2.0 * risk_pips);
      double tp_aggressive = is_long ? entry + (3.0 * risk_pips) : entry - (3.0 * risk_pips);
      
      double position_size = m_risk_manager.CalculatePositionSize(symbol, entry, sl);
      
      output.symbol = symbol;
      output.timeframe = PERIOD_H4;
      output.score_breakdown = breakdown;
      output.composite_score = breakdown.total_score;
      output.detected_time = TimeCurrent();
      
      output.signal.signal_type = is_long ? SIGNAL_LONG : SIGNAL_SHORT;
      output.signal.symbol = symbol;
      output.signal.entry_price = entry;
      output.signal.stop_loss = sl;
      output.signal.take_profit_conservative = tp_conservative;
      output.signal.take_profit_aggressive = tp_aggressive;
      output.signal.use_trailing_stop = true;
      output.signal.trailing_atr_multiplier = 2.5;
      output.signal.trailing_period = 10;
      output.signal.position_size = position_size;
      output.signal.regime = m_regime_detector.GetRegimeAsString();
      output.signal.strategy = "Keltner Breakout";
      output.signal.signal_time = TimeCurrent();
      
      return true;
   }
   
   void SortSignalsByScore(SymbolSignal &signals[])
   {
      int n = ArraySize(signals);
      for(int i = 0; i < n - 1; i++)
      {
         for(int j = 0; j < n - i - 1; j++)
         {
            if(signals[j].composite_score < signals[j + 1].composite_score)
            {
               SymbolSignal temp = signals[j];
               signals[j] = signals[j + 1];
               signals[j + 1] = temp;
            }
         }
      }
   }
};
//+------------------------------------------------------------------+