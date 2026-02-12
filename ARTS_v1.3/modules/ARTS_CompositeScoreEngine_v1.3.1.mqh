//+------------------------------------------------------------------+
//|                     ARTS_CompositeScoreEngine_v1.3.1.mqh         |
//+------------------------------------------------------------------+
//| VERSION: 1.3.1                                                    |
//| LETZTES ÄNDERUNGSDATUM: 2025-02-09 00:20 UTC                     |
//| ÄNDERUNGEN: Explizite H4/H1 Timeframe-Nutzung, Volume-Lookback  |
//+------------------------------------------------------------------+

#property copyright "ARTS System"
#property version   "1.31"
#property strict




#include "ARTS_RegimeDetector_v1.3.1.mqh"
#include "ARTS_IndicatorLibrary_v1.3.1.mqh"
#include "ARTS_MarketActivityAnalyzer_v1.3.mqh"

struct ScoreBreakdown
{
   double regime_score;
   double volatility_score;
   double entry_score;
   double volume_score;
   double activity_score;
   double total_score;
};

class CCompositeScoreEngine
{
private:
   CRegimeDetector* m_regime_detector;
   CIndicatorLibrary* m_indicators_h4;
   CIndicatorLibrary* m_indicators_h1;
   CMarketActivityAnalyzer* m_activity_analyzer;
   int m_volume_lookback;
   
public:
   CCompositeScoreEngine(CRegimeDetector* regime, 
                         CIndicatorLibrary* indicators_h4,
                         CIndicatorLibrary* indicators_h1,
                         CMarketActivityAnalyzer* activity)
   {
      m_regime_detector = regime;
      m_indicators_h4 = indicators_h4;
      m_indicators_h1 = indicators_h1;
      m_activity_analyzer = activity;
      m_volume_lookback = 20;
   }
   
   void SetVolumeLookback(int lookback)
   {
      m_volume_lookback = lookback;
   }
   
   ScoreBreakdown CalculateRangeSignalScore(string symbol, bool is_long, double range_upper, double range_lower)
   {
      ScoreBreakdown breakdown;
      
      double current_price_h1 = iClose(symbol, PERIOD_H1, 1);
      
      breakdown.regime_score = CalculateRegimeScore();
      breakdown.volatility_score = CalculateVolatilityScore();
      breakdown.entry_score = CalculateRangeEntryScore(current_price_h1, range_upper, range_lower, is_long);
      breakdown.volume_score = CalculateVolumeScore(symbol, PERIOD_H4);
      breakdown.activity_score = m_activity_analyzer.GetActivityScore(symbol) / 10.0;
      breakdown.total_score = breakdown.regime_score + breakdown.volatility_score + breakdown.entry_score + breakdown.volume_score + breakdown.activity_score;
      
      return breakdown;
   }
   
   ScoreBreakdown CalculateTrendSignalScore(string symbol, bool is_long, double breakout_level)
   {
      ScoreBreakdown breakdown;
      
      double current_price_h1 = iClose(symbol, PERIOD_H1, 1);
      
      breakdown.regime_score = CalculateRegimeScore();
      breakdown.volatility_score = CalculateVolatilityScore();
      breakdown.entry_score = CalculateTrendEntryScore(current_price_h1, breakout_level, is_long);
      breakdown.volume_score = CalculateVolumeScore(symbol, PERIOD_H4);
      breakdown.activity_score = m_activity_analyzer.GetActivityScore(symbol) / 10.0;
      breakdown.total_score = breakdown.regime_score + breakdown.volatility_score + breakdown.entry_score + breakdown.volume_score + breakdown.activity_score;
      
      return breakdown;
   }
   
private:
   double CalculateRegimeScore()
   {
      double score = 0;
      double r_squared = m_regime_detector.GetRSquared();
      double angle = MathAbs(m_regime_detector.GetAngle());
      ENUM_MARKET_REGIME regime = m_regime_detector.GetCurrentRegime();
      
      if(regime == REGIME_RANGE)
      {
         if(r_squared < 0.15) score += 15;
         else if(r_squared < 0.25) score += 10;
         else if(r_squared < 0.35) score += 5;
         
         if(angle < 10) score += 15;
         else if(angle < 20) score += 10;
         else if(angle < 30) score += 5;
      }
      else if(regime == REGIME_STRONG_TREND)
      {
         if(r_squared > 0.70) score += 15;
         else if(r_squared > 0.60) score += 10;
         else if(r_squared > 0.50) score += 5;
         
         if(angle > 35) score += 15;
         else if(angle > 25) score += 10;
         else if(angle > 15) score += 5;
      }
      
      return score;
   }
   
   double CalculateVolatilityScore()
   {
      double atr_percentile = m_regime_detector.GetATRPercentile();
      
      if(atr_percentile >= 35 && atr_percentile <= 65) return 20;
      else if(atr_percentile >= 25 && atr_percentile < 35) return 15;
      else if(atr_percentile > 65 && atr_percentile <= 75) return 12;
      else if(atr_percentile >= 15 && atr_percentile < 25) return 8;
      else if(atr_percentile > 75 && atr_percentile <= 85) return 5;
      else return 0;
   }
   
   double CalculateRangeEntryScore(double price, double upper, double lower, bool is_long)
   {
      double score = 0;
      double range_width = upper - lower;
      if(range_width == 0) return 0;
      
      double position_in_range = ((price - lower) / range_width) * 100.0;
      
      if(is_long)
      {
         if(position_in_range < 10) score += 15;
         else if(position_in_range < 20) score += 12;
         else if(position_in_range < 30) score += 8;
         else if(position_in_range < 40) score += 3;
      }
      else
      {
         if(position_in_range > 90) score += 15;
         else if(position_in_range > 80) score += 12;
         else if(position_in_range > 70) score += 8;
         else if(position_in_range > 60) score += 3;
      }
      
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double range_pips = range_width / point;
      
      if(range_pips > 30 && range_pips < 100) score += 10;
      else if(range_pips >= 20 && range_pips <= 30) score += 7;
      else if(range_pips >= 100 && range_pips < 150) score += 7;
      else if(range_pips < 20) score += 2;
      else score += 2;
      
      return score;
   }
   
   double CalculateTrendEntryScore(double price, double breakout_level, bool is_long)
   {
      double score = 0;
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double atr = m_indicators_h4.GetATR(1);
      
      double distance = MathAbs(price - breakout_level);
      double distance_pips = distance / point;
      
      if(distance_pips < 5) score += 15;
      else if(distance_pips < 10) score += 12;
      else if(distance_pips < 20) score += 8;
      else if(distance_pips < 30) score += 4;
      
      double last_candle_range = iHigh(_Symbol, PERIOD_H1, 1) - iLow(_Symbol, PERIOD_H1, 1);
      double momentum_ratio = last_candle_range / atr;
      
      if(momentum_ratio > 1.5) score += 10;
      else if(momentum_ratio > 1.0) score += 7;
      else if(momentum_ratio > 0.7) score += 4;
      
      return score;
   }
   
   double CalculateVolumeScore(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      long current_volume = iVolume(symbol, timeframe, 1);
      double avg_volume = 0;
      
      for(int i = 2; i <= m_volume_lookback + 1; i++)
         avg_volume += iVolume(symbol, timeframe, i);
      avg_volume /= m_volume_lookback;
      
      if(avg_volume == 0) return 0;
      
      double volume_ratio = current_volume / avg_volume;
      
      if(volume_ratio > 1.8) return 15;
      else if(volume_ratio > 1.4) return 12;
      else if(volume_ratio > 1.1) return 9;
      else if(volume_ratio > 0.9) return 6;
      else if(volume_ratio > 0.6) return 3;
      else return 0;
   }
};
//+------------------------------------------------------------------+