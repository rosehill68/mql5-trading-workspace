//+------------------------------------------------------------------+
//|                             ARTS_PositionManager_v1.3.mqh        |
//+------------------------------------------------------------------+
//| VERSION: 1.3.0                                                    |
//| LETZTES ÄNDERUNGSDATUM: 2025-02-08 23:45 UTC                     |
//+------------------------------------------------------------------+

#property copyright "ARTS System"
#property version   "1.30"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

struct PositionTracker
{
   ulong ticket;
   datetime open_time;
   double entry_price;
   double initial_sl;
   double initial_risk_pips;
   double spread_at_entry;
   bool breakeven_set;
   bool trailing_active;
   double highest_profit_pips;
};

class CPositionManager
{
private:
   CTrade m_trade;
   CPositionInfo m_position;
   CSymbolInfo m_symbol;
   int m_magic_number;
   double m_slippage;
   bool m_use_breakeven;
   bool m_use_trailing;
   int m_trailing_period;
   double m_trailing_multiplier;
   PositionTracker m_tracked_positions[100];
   int m_tracked_count;
   
public:
   CPositionManager(int magic = 230101)
   {
      m_magic_number = magic;
      m_slippage = 3.0;
      m_use_breakeven = true;
      m_use_trailing = true;
      m_trailing_period = 10;
      m_trailing_multiplier = 2.5;
      m_tracked_count = 0;
      
      m_trade.SetExpertMagicNumber(m_magic_number);
      m_trade.SetDeviationInPoints((int)(m_slippage * 10));
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   }
   
   void SetBreakevenEnabled(bool enabled) { m_use_breakeven = enabled; }
   void SetTrailingEnabled(bool enabled) { m_use_trailing = enabled; }
   void SetTrailingParameters(int period, double multiplier)
   {
      m_trailing_period = period;
      m_trailing_multiplier = multiplier;
   }
   
   bool OpenPosition(TradingSignal &signal, bool use_trailing_tp)
   {
      if(!m_symbol.Name(signal.symbol)) return false;
      m_symbol.RefreshRates();
      
      double price, sl, tp;
      ENUM_ORDER_TYPE order_type;
      
      if(signal.signal_type == SIGNAL_LONG)
      {
         order_type = ORDER_TYPE_BUY;
         price = m_symbol.Ask();
         sl = signal.stop_loss;
         tp = use_trailing_tp ? signal.take_profit_aggressive : signal.take_profit_conservative;
      }
      else if(signal.signal_type == SIGNAL_SHORT)
      {
         order_type = ORDER_TYPE_SELL;
         price = m_symbol.Bid();
         sl = signal.stop_loss;
         tp = use_trailing_tp ? signal.take_profit_aggressive : signal.take_profit_conservative;
      }
      else return false;
      
      price = NormalizeDouble(price, m_symbol.Digits());
      sl = NormalizeDouble(sl, m_symbol.Digits());
      tp = NormalizeDouble(tp, m_symbol.Digits());
      
      bool result = m_trade.PositionOpen(signal.symbol, order_type, signal.position_size, price, sl, tp, "ARTS");
      
      if(result)
      {
         ulong ticket = m_trade.ResultOrder();
         AddPositionToTracking(ticket, price, sl);
         return true;
      }
      
      return false;
   }
   
   void ManageAllPositions()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!m_position.SelectByIndex(i)) continue;
         if(m_position.Magic() != m_magic_number) continue;
         
         ulong ticket = m_position.Ticket();
         int tracker_index = FindTrackerIndex(ticket);
         
         if(tracker_index == -1)
         {
            AddPositionToTracking(ticket, m_position.PriceOpen(), m_position.StopLoss());
            tracker_index = FindTrackerIndex(ticket);
         }
         
         if(tracker_index == -1) continue;
         ManageSinglePosition(tracker_index);
      }
      
      CleanupTracking();
   }
   
   int GetTrackedPositionsCount() const { return m_tracked_count; }
   
   string GetPositionInfo(int index)
   {
      if(index < 0 || index >= m_tracked_count) return "";
      
      PositionTracker tracker = m_tracked_positions[index];
      if(!m_position.SelectByTicket(tracker.ticket)) return "";
      
      double current_profit = CalculateProfitPips(tracker);
      return StringFormat("#%I64u | %.1f Pips | BE:%s | Trail:%s", 
                         tracker.ticket, current_profit,
                         (tracker.breakeven_set ? "Y" : "N"),
                         (tracker.trailing_active ? "Y" : "N"));
   }
   
private:
   void AddPositionToTracking(ulong ticket, double entry, double sl)
   {
      if(m_tracked_count >= 100) return;
      if(!m_position.SelectByTicket(ticket)) return;
      
      string symbol = m_position.Symbol();
      m_symbol.Name(symbol);
      m_symbol.RefreshRates();
      
      double spread = (m_symbol.Ask() - m_symbol.Bid()) / m_symbol.Point();
      double risk_pips = MathAbs(entry - sl) / m_symbol.Point();
      
      PositionTracker tracker;
      tracker.ticket = ticket;
      tracker.open_time = (datetime)m_position.Time();
      tracker.entry_price = entry;
      tracker.initial_sl = sl;
      tracker.initial_risk_pips = risk_pips;
      tracker.spread_at_entry = spread;
      tracker.breakeven_set = false;
      tracker.trailing_active = false;
      tracker.highest_profit_pips = 0;
      
      m_tracked_positions[m_tracked_count] = tracker;
      m_tracked_count++;
   }
   
   void ManageSinglePosition(int tracker_index)
   {
      PositionTracker tracker = m_tracked_positions[tracker_index];
      if(!m_position.SelectByTicket(tracker.ticket)) return;
      
      m_symbol.Name(m_position.Symbol());
      m_symbol.RefreshRates();
      
      double current_profit_pips = CalculateProfitPips(tracker);
      if(current_profit_pips > tracker.highest_profit_pips)
         m_tracked_positions[tracker_index].highest_profit_pips = current_profit_pips;
      
      if(!tracker.breakeven_set && m_use_breakeven)
      {
         double breakeven_trigger = tracker.initial_risk_pips + tracker.spread_at_entry;
         if(current_profit_pips >= breakeven_trigger)
            SetBreakeven(tracker_index);
      }
      
      if(tracker.breakeven_set && m_use_trailing)
      {
         if(!tracker.trailing_active)
            m_tracked_positions[tracker_index].trailing_active = true;
         UpdateTrailingStop(tracker_index);
      }
   }
   
   double CalculateProfitPips(PositionTracker &tracker)
   {
      double current_price = m_position.PositionType() == POSITION_TYPE_BUY ? m_symbol.Bid() : m_symbol.Ask();
      double profit_distance = m_position.PositionType() == POSITION_TYPE_BUY ? 
                               current_price - tracker.entry_price : 
                               tracker.entry_price - current_price;
      return profit_distance / m_symbol.Point();
   }
   
   void SetBreakeven(int tracker_index)
   {
      PositionTracker tracker = m_tracked_positions[tracker_index];
      double new_sl = NormalizeDouble(tracker.entry_price, m_symbol.Digits());
      
      if(m_trade.PositionModify(tracker.ticket, new_sl, m_position.TakeProfit()))
         m_tracked_positions[tracker_index].breakeven_set = true;
   }
   
   void UpdateTrailingStop(int tracker_index)
   {
      PositionTracker tracker = m_tracked_positions[tracker_index];
      
      int handle_atr = iATR(m_position.Symbol(), PERIOD_CURRENT, m_trailing_period);
      if(handle_atr == INVALID_HANDLE) return;
      
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      if(CopyBuffer(handle_atr, 0, 0, 1, atr_buffer) <= 0)
      {
         IndicatorRelease(handle_atr);
         return;
      }
      
      double atr = atr_buffer[0];
      IndicatorRelease(handle_atr);
      
      double high = iHigh(m_position.Symbol(), PERIOD_CURRENT, 1);
      double low = iLow(m_position.Symbol(), PERIOD_CURRENT, 1);
      double hl_avg = (high + low) / 2.0;
      
      double new_sl;
      double current_sl = m_position.StopLoss();
      
      if(m_position.PositionType() == POSITION_TYPE_BUY)
      {
         new_sl = hl_avg - (m_trailing_multiplier * atr);
         if(new_sl > current_sl)
         {
            new_sl = NormalizeDouble(new_sl, m_symbol.Digits());
            m_trade.PositionModify(tracker.ticket, new_sl, m_position.TakeProfit());
         }
      }
      else
      {
         new_sl = hl_avg + (m_trailing_multiplier * atr);
         if(new_sl < current_sl || current_sl == 0)
         {
            new_sl = NormalizeDouble(new_sl, m_symbol.Digits());
            m_trade.PositionModify(tracker.ticket, new_sl, m_position.TakeProfit());
         }
      }
   }
   
   int FindTrackerIndex(ulong ticket)
   {
      for(int i = 0; i < m_tracked_count; i++)
         if(m_tracked_positions[i].ticket == ticket) return i;
      return -1;
   }
   
   void CleanupTracking()
   {
      for(int i = m_tracked_count - 1; i >= 0; i--)
      {
         if(!m_position.SelectByTicket(m_tracked_positions[i].ticket))
         {
            for(int j = i; j < m_tracked_count - 1; j++)
               m_tracked_positions[j] = m_tracked_positions[j + 1];
            m_tracked_count--;
         }
      }
   }
};
//+------------------------------------------------------------------+