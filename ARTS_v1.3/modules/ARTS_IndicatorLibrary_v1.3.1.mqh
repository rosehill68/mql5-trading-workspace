//+------------------------------------------------------------------+
//|                             ARTS_IndicatorLibrary_v1.3.1.mqh     |
//+------------------------------------------------------------------+
//| VERSION: 1.3.1                                                    |
//| LETZTES ÄNDERUNGSDATUM: 2025-02-09 00:15 UTC                     |
//| ÄNDERUNGEN: Explizite Timeframe-Parameter, konfigurierbare      |
//|             Lookback-Perioden                                    |
//+------------------------------------------------------------------+

#property copyright "ARTS System"
#property version   "1.31"
#property strict

class CIndicatorLibrary
{
private:
   int m_handle_atr;
   int m_handle_ema_20;
   int m_handle_ema_50;
   double m_buffer_atr[];
   double m_buffer_ema_20[];
   double m_buffer_ema_50[];
   double m_buffer_high[];
   double m_buffer_low[];
   bool m_initialized;
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int m_atr_period;
   int m_ema_period_fast;
   int m_ema_period_slow;
   int m_donchian_period;
   
public:
   CIndicatorLibrary()
   {
      m_initialized = false;
      m_symbol = _Symbol;
      m_timeframe = PERIOD_H4;
      m_atr_period = 14;
      m_ema_period_fast = 20;
      m_ema_period_slow = 50;
      m_donchian_period = 50;
      
      ArraySetAsSeries(m_buffer_atr, true);
      ArraySetAsSeries(m_buffer_ema_20, true);
      ArraySetAsSeries(m_buffer_ema_50, true);
      ArraySetAsSeries(m_buffer_high, true);
      ArraySetAsSeries(m_buffer_low, true);
      ArrayResize(m_buffer_atr, 200);
      ArrayResize(m_buffer_ema_20, 200);
      ArrayResize(m_buffer_ema_50, 200);
      ArrayResize(m_buffer_high, 200);
      ArrayResize(m_buffer_low, 200);
   }
   
   void SetPeriods(int atr, int ema_fast, int ema_slow, int donchian)
   {
      m_atr_period = atr;
      m_ema_period_fast = ema_fast;
      m_ema_period_slow = ema_slow;
      m_donchian_period = donchian;
   }
   
   bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      
      if(m_handle_atr != INVALID_HANDLE) IndicatorRelease(m_handle_atr);
      if(m_handle_ema_20 != INVALID_HANDLE) IndicatorRelease(m_handle_ema_20);
      if(m_handle_ema_50 != INVALID_HANDLE) IndicatorRelease(m_handle_ema_50);
      
      m_handle_atr = iATR(m_symbol, m_timeframe, m_atr_period);
      m_handle_ema_20 = iMA(m_symbol, m_timeframe, m_ema_period_fast, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_ema_50 = iMA(m_symbol, m_timeframe, m_ema_period_slow, 0, MODE_EMA, PRICE_CLOSE);
      
      if(m_handle_atr == INVALID_HANDLE || m_handle_ema_20 == INVALID_HANDLE || m_handle_ema_50 == INVALID_HANDLE)
      {
         m_initialized = false;
         return false;
      }
      
      m_initialized = true;
      return true;
   }
   
   ~CIndicatorLibrary()
   {
      if(m_handle_atr != INVALID_HANDLE) IndicatorRelease(m_handle_atr);
      if(m_handle_ema_20 != INVALID_HANDLE) IndicatorRelease(m_handle_ema_20);
      if(m_handle_ema_50 != INVALID_HANDLE) IndicatorRelease(m_handle_ema_50);
   }
   
   bool IsInitialized() const { return m_initialized; }
   
   double GetATR(int shift = 0)
   {
      if(!m_initialized) return 0;
      if(CopyBuffer(m_handle_atr, 0, shift, 1, m_buffer_atr) <= 0) return 0;
      return m_buffer_atr[0];
   }
   
   double GetEMA20(int shift = 0)
   {
      if(!m_initialized) return 0;
      if(CopyBuffer(m_handle_ema_20, 0, shift, 1, m_buffer_ema_20) <= 0) return 0;
      return m_buffer_ema_20[0];
   }
   
   double GetEMA50(int shift = 0)
   {
      if(!m_initialized) return 0;
      if(CopyBuffer(m_handle_ema_50, 0, shift, 1, m_buffer_ema_50) <= 0) return 0;
      return m_buffer_ema_50[0];
   }
   
   double GetDonchianUpper(int shift = 0)
   {
      if(!m_initialized) return 0;
      if(CopyHigh(m_symbol, m_timeframe, shift, m_donchian_period, m_buffer_high) <= 0) return 0;
      return m_buffer_high[ArrayMaximum(m_buffer_high, 0, m_donchian_period)];
   }
   
   double GetDonchianLower(int shift = 0)
   {
      if(!m_initialized) return 0;
      if(CopyLow(m_symbol, m_timeframe, shift, m_donchian_period, m_buffer_low) <= 0) return 0;
      return m_buffer_low[ArrayMinimum(m_buffer_low, 0, m_donchian_period)];
   }
   
   double GetKeltnerUpper(double multiplier = 2.0, int shift = 0)
   {
      double ema = GetEMA20(shift);
      double atr = GetATR(shift);
      if(ema == 0 || atr == 0) return 0;
      return ema + (multiplier * atr);
   }
   
   double GetKeltnerLower(double multiplier = 2.0, int shift = 0)
   {
      double ema = GetEMA20(shift);
      double atr = GetATR(shift);
      if(ema == 0 || atr == 0) return 0;
      return ema - (multiplier * atr);
   }
   
   double GetKeltnerMiddle(int shift = 0)
   {
      return GetEMA20(shift);
   }
   
   int GetDonchianPeriod() const { return m_donchian_period; }
};
//+------------------------------------------------------------------+