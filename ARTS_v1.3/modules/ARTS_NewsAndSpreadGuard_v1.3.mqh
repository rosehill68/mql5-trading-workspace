//+------------------------------------------------------------------+
//|                       ARTS_NewsAndSpreadGuard_v1.3.mqh           |
//+------------------------------------------------------------------+
//| VERSION: 1.3.0                                                    |
//| LETZTES ÄNDERUNGSDATUM: 2025-02-08 23:50 UTC                     |
//+------------------------------------------------------------------+

#property copyright "ARTS System"
#property version   "1.30"
#property strict

#include <modules\ARTS_SpreadGuard_v1.3.mqh>

class CNewsAndSpreadGuard
{
private:
   CSpreadGuard* m_spread_guard;
   int m_news_blackout_minutes_before;
   int m_news_blackout_minutes_after;
   
public:
   CNewsAndSpreadGuard(CSpreadGuard* spread_guard)
   {
      m_spread_guard = spread_guard;
      m_news_blackout_minutes_before = 30;
      m_news_blackout_minutes_after = 15;
   }
   
   bool IsTradingSafe(string symbol)
   {
      if(IsHighImpactNewsNear(symbol)) return false;
      if(!m_spread_guard.IsSpreadNormal(symbol)) return false;
      return true;
   }
   
private:
   bool IsHighImpactNewsNear(string symbol)
   {
      string base_currency = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
      string quote_currency = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
      
      datetime from = TimeCurrent();
      datetime to = TimeCurrent() + (m_news_blackout_minutes_before * 60);
      
      MqlCalendarValue calendar_values[];
      if(CalendarValueHistory(calendar_values, from, to, NULL, NULL) <= 0)
         return false;
      
      for(int i = 0; i < ArraySize(calendar_values); i++)
      {
         MqlCalendarEvent event;
         if(!CalendarEventById(calendar_values[i].event_id, event))
            continue;
         
         if(event.importance != CALENDAR_IMPORTANCE_HIGH)
            continue;
         
         MqlCalendarCountry country;
         if(!CalendarCountryById(event.country_id, country))
            continue;
         
         string event_currency = country.currency;
         
         if(event_currency == base_currency || event_currency == quote_currency)
         {
            Print("HIGH NEWS: ", event.name, " | ", symbol, " | ", 
                  (calendar_values[i].time - TimeCurrent()) / 60, " min");
            return true;
         }
      }
      
      return false;
   }
};
//+------------------------------------------------------------------+