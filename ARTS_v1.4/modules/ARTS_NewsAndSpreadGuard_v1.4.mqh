//+------------------------------------------------------------------+
//|                       ARTS_NewsAndSpreadGuard_v1.4.mqh           |
//| Non-Repainting Fixed (Claude Risk #1)                            |
//| Version 1.5 | 2026.02.19 02:00 CET                              |
//+------------------------------------------------------------------+
//| VERSION: 1.5.0 - Critical Fixes                                   |
//| FIX 1: News Filter Logik korrigiert (Zeile 50)                   |
//+------------------------------------------------------------------+

#property copyright "ARTS System"
#property version   "1.50"
#property strict

#include "ARTS_SpreadGuard_v1.4.mqh"

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
      if(!m_spread_guard->IsSpreadNormal(symbol)) return false;
      return true;
   }
   
   void SetBlackoutMinutes(int before, int after)
   {
      m_news_blackout_minutes_before = before;
      m_news_blackout_minutes_after = after;
   }
   
private:
   bool IsHighImpactNewsNear(string symbol)
   {
      string base_currency = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
      string quote_currency = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
      
      datetime from = TimeCurrent();
      datetime to = TimeCurrent() + (m_news_blackout_minutes_before * 60);
      
      MqlCalendarValue calendar_values[];
      // FIX v1.5: Keine News gefunden = Safe (Trading erlauben)
      if(CalendarValueHistory(calendar_values, from, to, NULL, NULL) <= 0)
         return false;  // Keine News = keine Blockierung = Safe
      
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