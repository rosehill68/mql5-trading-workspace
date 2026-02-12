//+------------------------------------------------------------------+
//|                                ARTS_RegimeDetector_v1.3.1.mqh    |
//+------------------------------------------------------------------+
//| VERSION: 1.3.1                                                    |
//| LETZTES ÄNDERUNGSDATUM: 2025-02-09 00:15 UTC                     |
//| ÄNDERUNGEN: Explizite Timeframe-Kontrolle, konfigurierbare      |
//|             Lookback-Perioden                                    |
//+------------------------------------------------------------------+

#property copyright "ARTS System"
#property version   "1.31"
#property strict

enum ENUM_MARKET_REGIME
{
   REGIME_RANGE,
   REGIME_WEAK_TREND,
   REGIME_STRONG_TREND,
   REGIME_NO_TRADE
};

class CRegimeDetector
{
private:
   int m_lookback_linreg;
   int m_lookback_atr_percentile;
   int m_atr_period;
   double m_r_squared_range;
   double m_r_squared_trend;
   double m_angle_range;
   double m_angle_trend;
   double m_atr_perc_high;
   double m_atr_perc_low;
   ENUM_MARKET_REGIME m_current_regime;
   double m_last_r_squared;
   double m_last_slope;
   double m_last_angle;
   double m_last_atr_percentile;
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   
public:
   CRegimeDetector(int lookback_linreg = 100, 
                   int lookback_atr_perc = 200,
                   int atr_period = 14)
   {
      m_lookback_linreg = lookback_linreg;
      m_lookback_atr_percentile = lookback_atr_perc;
      m_atr_period = atr_period;
      m_r_squared_range = 0.20;
      m_r_squared_trend = 0.60;
      m_angle_range = 15.0;
      m_angle_trend = 30.0;
      m_atr_perc_high = 85.0;
      m_atr_perc_low = 60.0;
      m_current_regime = REGIME_NO_TRADE;
      m_last_r_squared = 0;
      m_last_slope = 0;
      m_last_angle = 0;
      m_last_atr_percentile = 0;
      m_symbol = _Symbol;
      m_timeframe = PERIOD_H4;
   }
   
   void SetSymbol(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
   }
   
   void SetLookbackPeriods(int linreg, int atr_perc, int atr_period)
   {
      m_lookback_linreg = linreg;
      m_lookback_atr_percentile = atr_perc;
      m_atr_period = atr_period;
   }
   
   ENUM_MARKET_REGIME DetectRegime()
   {
      m_last_r_squared = CalculateLinearRegressionRSquared();
      m_last_slope = CalculateLinearRegressionSlope();
      m_last_angle = MathArctan(m_last_slope) * 180.0 / M_PI;
      m_last_atr_percentile = CalculateATRPercentile();
      m_current_regime = DetermineRegime();
      return m_current_regime;
   }
   
   ENUM_MARKET_REGIME GetCurrentRegime() const { return m_current_regime; }
   double GetRSquared() const { return m_last_r_squared; }
   double GetSlope() const { return m_last_slope; }
   double GetAngle() const { return m_last_angle; }
   double GetATRPercentile() const { return m_last_atr_percentile; }
   
   string GetRegimeAsString() const
   {
      switch(m_current_regime)
      {
         case REGIME_RANGE: return "RANGE";
         case REGIME_WEAK_TREND: return "SCHWACHER TREND";
         case REGIME_STRONG_TREND: return "STARKER TREND";
         case REGIME_NO_TRADE: return "KEIN TRADE";
         default: return "UNBEKANNT";
      }
   }
   
private:
   double CalculateLinearRegressionRSquared()
   {
      double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0, sum_y2 = 0;
      
      for(int i = 0; i < m_lookback_linreg; i++)
      {
         double x = i;
         double y = iClose(m_symbol, m_timeframe, i);
         sum_x += x;
         sum_y += y;
         sum_xy += x * y;
         sum_x2 += x * x;
         sum_y2 += y * y;
      }
      
      double n = m_lookback_linreg;
      double numerator = (n * sum_xy) - (sum_x * sum_y);
      double denominator = MathSqrt((n * sum_x2 - sum_x * sum_x) * (n * sum_y2 - sum_y * sum_y));
      
      if(denominator == 0) return 0;
      double r = numerator / denominator;
      return r * r;
   }
   
   double CalculateLinearRegressionSlope()
   {
      double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
      
      for(int i = 0; i < m_lookback_linreg; i++)
      {
         double x = i;
         double y = iClose(m_symbol, m_timeframe, i);
         sum_x += x;
         sum_y += y;
         sum_xy += x * y;
         sum_x2 += x * x;
      }
      
      double n = m_lookback_linreg;
      double numerator = (n * sum_xy) - (sum_x * sum_y);
      double denominator = (n * sum_x2) - (sum_x * sum_x);
      
      if(denominator == 0) return 0;
      return numerator / denominator;
   }
   
   double CalculateATRPercentile()
   {
      int atr_handle = iATR(m_symbol, m_timeframe, m_atr_period);
      if(atr_handle == INVALID_HANDLE) return 50.0;
      
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      
      if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) <= 0)
      {
         IndicatorRelease(atr_handle);
         return 50.0;
      }
      
      double current_atr = atr_buffer[0];
      double historical_atr[];
      ArrayResize(historical_atr, m_lookback_atr_percentile);
      ArraySetAsSeries(historical_atr, true);
      
      if(CopyBuffer(atr_handle, 0, 0, m_lookback_atr_percentile, historical_atr) <= 0)
      {
         IndicatorRelease(atr_handle);
         return 50.0;
      }
      
      IndicatorRelease(atr_handle);
      ArraySort(historical_atr);
      
      int rank = 0;
      for(int i = 0; i < m_lookback_atr_percentile; i++)
         if(current_atr >= historical_atr[i]) rank++;
      
      return (rank / (double)m_lookback_atr_percentile) * 100.0;
   }
   
   ENUM_MARKET_REGIME DetermineRegime()
   {
      if(m_last_atr_percentile > m_atr_perc_high) return REGIME_NO_TRADE;
      if(m_last_r_squared < m_r_squared_range && MathAbs(m_last_angle) < m_angle_range) return REGIME_RANGE;
      if(m_last_r_squared > m_r_squared_trend && MathAbs(m_last_angle) > m_angle_trend) return REGIME_STRONG_TREND;
      if(m_last_r_squared > m_r_squared_range && m_last_r_squared < m_r_squared_trend) return REGIME_WEAK_TREND;
      return REGIME_NO_TRADE;
   }
};
//+------------------------------------------------------------------+