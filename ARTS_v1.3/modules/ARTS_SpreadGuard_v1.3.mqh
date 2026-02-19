//+------------------------------------------------------------------+
//|                                ARTS_SpreadGuard_v1.3.mqh         |
//+------------------------------------------------------------------+
//| VERSION: 1.3.0                                                    |
//| LETZTES ÄNDERUNGSDATUM: 2025-02-08 23:50 UTC                     |
//+------------------------------------------------------------------+

#property copyright "ARTS System"
#property version   "1.30"
#property strict

class CSpreadGuard
{
private:
   double m_max_spread_multiplier;
   double m_spread_history[100];
   int m_history_count;
   
public:
   CSpreadGuard()
   {
      m_max_spread_multiplier = 1.5;
      m_history_count = 0;
      ArrayInitialize(m_spread_history, 0);
   }
   
   void SetMaxSpreadMultiplier(double multiplier)
   {
      if(multiplier > 0)
         m_max_spread_multiplier = multiplier;
   }
   
   bool IsSpreadNormal(string symbol)
   {
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      if(point == 0) 
      {
         Print("ERROR: Point = 0 for ", symbol);
         return false;
      }
      
      double current_spread = (ask - bid) / point;
      double typical_spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      
      if(typical_spread == 0)
         typical_spread = GetAverageHistoricalSpread(symbol);
      
      double max_allowed = typical_spread * m_max_spread_multiplier;
      
      if(current_spread > max_allowed)
      {
         Print("SPREAD SPIKE DETECTED: ", symbol);
         Print("  Typical: ", DoubleToString(typical_spread, 1), " pips");
         Print("  Current: ", DoubleToString(current_spread, 1), " pips");
         Print("  Max Allowed: ", DoubleToString(max_allowed, 1), " pips");
         return false;
      }
      
      UpdateSpreadHistory(current_spread);
      
      return true;
   }
   
   double GetCurrentSpread(string symbol)
   {
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      if(point == 0) return 0;
      
      return (ask - bid) / point;
   }
   
private:
   double GetAverageHistoricalSpread(string symbol)
   {
      if(m_history_count == 0) return 2.0;
      
      double sum = 0;
      for(int i = 0; i < m_history_count; i++)
         sum += m_spread_history[i];
      
      return sum / m_history_count;
   }
   
   void UpdateSpreadHistory(double spread)
   {
      if(m_history_count >= 100)
      {
         for(int i = 0; i < 99; i++)
            m_spread_history[i] = m_spread_history[i + 1];
         m_history_count = 99;
      }
      
      m_spread_history[m_history_count] = spread;
      m_history_count++;
   }
};
//+------------------------------------------------------------------+