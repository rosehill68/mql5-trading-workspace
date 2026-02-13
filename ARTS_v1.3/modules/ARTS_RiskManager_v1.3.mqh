//+------------------------------------------------------------------+
//|                                 ARTS_RiskManager_v1.3.mqh        |
//+------------------------------------------------------------------+
//| VERSION: 1.3.0                                                    |
//| LETZTES ÄNDERUNGSDATUM: 2025-02-08 23:45 UTC                     |
//+------------------------------------------------------------------+

#property copyright "ARTS System"
#property version   "1.30"
#property strict

class CRiskManager
{
private:
   double m_risk_percent;
   double m_max_daily_drawdown;
   int m_max_trades_per_day;
   int m_magic_number;
   datetime m_last_trade_date;
   int m_trades_today;
   double m_daily_profit;
   double m_account_balance_start;
   double m_max_drawdown_limit;
   double m_drawdown_warning_level;
   
public:
   CRiskManager(double risk_percent = 0.7, double max_daily_dd = 1.5, int max_trades = 3, int magic = 230101)
   {
      m_risk_percent = risk_percent;
      m_max_daily_drawdown = max_daily_dd;
      m_max_trades_per_day = max_trades;
      m_magic_number = magic;
      m_last_trade_date = 0;
      m_trades_today = 0;
      m_daily_profit = 0;
      m_account_balance_start = AccountInfoDouble(ACCOUNT_BALANCE);
      m_max_drawdown_limit = 2000.0;
      m_drawdown_warning_level = m_max_drawdown_limit * 0.6;
   }
   
   double CalculatePositionSize(string symbol, double entry_price, double stop_loss)
   {
      if(entry_price <= 0 || stop_loss <= 0) return 0;
      if(entry_price == stop_loss) return 0;
      
      double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(account_balance <= 0) return 0;
      
      double risk_amount = account_balance * (m_risk_percent / 100.0);
      
      double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      
      if(tick_value <= 0 || point <= 0 || lot_step <= 0) return 0;
      
      double sl_distance = MathAbs(entry_price - stop_loss);
      double sl_pips = sl_distance / point;
      
      if(sl_pips <= 0) return 0;
      
      double position_size = risk_amount / (sl_pips * tick_value * (tick_size / point));
      position_size = MathFloor(position_size / lot_step) * lot_step;
      
      if(position_size < min_lot) position_size = min_lot;
      if(position_size > max_lot) position_size = max_lot;
      
      double current_drawdown = GetCurrentDrawdown();
      if(current_drawdown > m_drawdown_warning_level)
      {
         position_size = position_size * 0.5;
         position_size = MathFloor(position_size / lot_step) * lot_step;
         if(position_size < min_lot) position_size = min_lot;
      }
      
      return position_size;
   }
   
   bool IsTradingAllowed()
   {
      datetime current_time = TimeCurrent();
      MqlDateTime dt_struct;
      TimeToStruct(current_time, dt_struct);
      datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dt_struct.year, dt_struct.mon, dt_struct.day));
      
      if(today != m_last_trade_date)
      {
         m_last_trade_date = today;
         m_trades_today = 0;
         m_daily_profit = 0;
         m_account_balance_start = AccountInfoDouble(ACCOUNT_BALANCE);
      }
      
      if(m_trades_today >= m_max_trades_per_day) return false;
      
      double daily_loss_percent = 0;
      if(m_account_balance_start > 0)
      {
         double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
         daily_loss_percent = ((m_account_balance_start - current_balance) / m_account_balance_start) * 100.0;
      }
      
      if(daily_loss_percent > m_max_daily_drawdown) return false;
      
      double total_drawdown = GetCurrentDrawdown();
      if(total_drawdown >= m_max_drawdown_limit) return false;
      
      return true;
   }
   
   void RegisterTrade()
   {
      m_trades_today++;
   }
   
   double GetCurrentDrawdown()
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double drawdown = balance - equity;
      if(drawdown < 0) drawdown = 0;
      return drawdown;
   }
   
   double GetDrawdownPercent()
   {
      double dd = GetCurrentDrawdown();
      return (dd / m_max_drawdown_limit) * 100.0;
   }
   
   int GetTradesToday() const { return m_trades_today; }
};
//+------------------------------------------------------------------+