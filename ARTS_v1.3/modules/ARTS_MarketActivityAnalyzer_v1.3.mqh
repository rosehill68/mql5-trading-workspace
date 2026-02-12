//+------------------------------------------------------------------+
//|                    ARTS_MarketActivityAnalyzer_v1.3.mqh          |
//+------------------------------------------------------------------+
//| VERSION: 1.3.0                                                    |
//| LETZTES ÄNDERUNGSDATUM: 2025-02-08 23:50 UTC                     |
//+------------------------------------------------------------------+

#property copyright "ARTS System"
#property version   "1.30"
#property strict

#include <modules\ARTS_TimezoneManager_v1.3.mqh>

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
      int hour_utc = m_timezone_manager.GetCurrentHourUTC();
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
      int atr_handle = iATR(symbol, PERIOD_H1, 14);
      if(atr_handle == INVALID_HANDLE) return 0;
      
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      
      if(CopyBuffer(atr_handle, 0, 0, 200, atr_buffer) <= 0)
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
      long current_volume = iVolume(symbol, PERIOD_H1, 0);
      double avg_volume = 0;
      
      for(int i = 1; i <= 20; i++)
         avg_volume += iVolume(symbol, PERIOD_H1, i);
      avg_volume /= 20;
      
      if(avg_volume == 0) return 0;
      
      double volume_ratio = current_volume / avg_volume;
      
      if(volume_ratio > 1.5) return 30;
      else if(volume_ratio > 1.0) return 20;
      else return 5;
   }
};
//+------------------------------------------------------------------+