//+------------------------------------------------------------------+
//|                    ARTS_MarketActivityAnalyzer_v1.4.mqh          |
//| Non-Repainting Fixed (Claude Risk #1)                            |
//| Version 1.4 | 2026.02.18 21:30 CET                              |
//+------------------------------------------------------------------+
//| VERSION: 1.4.0                                                    |
//+------------------------------------------------------------------+

#property copyright "ARTS System"
#property version   "1.40"
#property strict

#include "ARTS_TimezoneManager_v1.4.mqh"

class CMarketActivityAnalyzer
{
private:
   CTimezoneManager* m_timezone_manager;
   
public:
   CMarketActivityAnalyzer(CTimezoneManager* timezone_manager)
   {
      m_timezone_manager = timezone_manager;
   }
   
   double GetActivityScore(string symbol)
   {
      double score = 0;
      score += CalculateTimeScore();
      score += CalculateVolatilityScore(symbol);
      score += CalculateVolumeScore(symbol);
      return score;
   }
   
private:
   double CalculateTimeScore()
   {
      int hour_utc = m_timezone_manager->GetCurrentHourUTC();
      double score = 0;
      
      if(hour_utc >= 8 && hour_utc <= 10) score = 40;
      else if(hour_utc >= 13 && hour_utc <= 16) score = 40;
      else if(hour_utc >= 20 && hour_utc <= 22) score = 30;
      else if(hour_utc >= 0 && hour_utc <= 2) score = 20;
      else score = 10;
      
      return score;
   }
   
   double CalculateVolatilityScore(string symbol)
   {
      // FIX v1.4: Use bar 1 for non-repainting ATR
      int atr_handle = iATR(symbol, PERIOD_H1, 14);
      if(atr_handle == INVALID_HANDLE) return 0;
      
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      
      // FIX v1.4: Start from bar 1, copy 200 bars
      if(CopyBuffer(atr_handle, 0, 1, 200, atr_buffer) <= 0)
      {
         IndicatorRelease(atr_handle);
         return 0;
      }
      
      double current_atr = atr_buffer[0];
      double sorted[];
      ArrayCopy(sorted, atr_buffer);
      ArraySort(sorted);
      
      int rank = 0;
      for(int i = 0; i < 200; i++)
         if(current_atr >= sorted[i]) rank++;
      
      double atr_percentile = (rank / 200.0) * 100.0;
      
      IndicatorRelease(atr_handle);
      
      if(atr_percentile > 70) return 30;
      else if(atr_percentile > 40) return 20;
      else return 5;
   }
   
   double CalculateVolumeScore(string symbol)
   {
      // FIX v1.4: Use bar 1 for current volume (non-repainting)
      long current_volume = iVolume(symbol, PERIOD_H1, 1);
      double avg_volume = 0;
      
      // FIX v1.4: Average of bars 2-21 (exclude current bar)
      for(int i = 2; i <= 21; i++)
         avg_volume += (double)iVolume(symbol, PERIOD_H1, i);
      avg_volume /= 20;
      
      if(avg_volume == 0) return 0;
      
      double volume_ratio = (double)current_volume / avg_volume;
      
      if(volume_ratio > 1.5) return 30;
      else if(volume_ratio > 1.0) return 20;
      else return 5;
   }
};
//+------------------------------------------------------------------+