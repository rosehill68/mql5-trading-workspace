//+------------------------------------------------------------------+
//|                            ARTS_TimezoneManager_v1.4.mqh         |
//| Non-Repainting Fixed (Claude Risk #1)                            |
//| Version 1.4 | 2026.02.18 21:30 CET                              |
//+------------------------------------------------------------------+
//| VERSION: 1.4.0                                                    |
//+------------------------------------------------------------------+

#property copyright "ARTS System"
#property version   "1.40"
#property strict

class CTimezoneManager
{
private:
   int m_broker_offset_hours;
   
public:
   CTimezoneManager()
   {
      m_broker_offset_hours = CalculateBrokerOffset();
      Print("Timezone Manager v1.4 | Broker Offset: UTC", 
            (m_broker_offset_hours >= 0 ? "+" : ""), m_broker_offset_hours);
   }
   
   int GetBrokerOffset() const { return m_broker_offset_hours; }
   
   datetime ConvertServerTimeToUTC(datetime server_time)
   {
      return server_time - (m_broker_offset_hours * 3600);
   }
   
   datetime ConvertUTCToServerTime(datetime utc_time)
   {
      return utc_time + (m_broker_offset_hours * 3600);
   }
   
   datetime GetGermanTime()
   {
      datetime utc_time = TimeGMT();
      MqlDateTime dt;
      TimeToStruct(utc_time, dt);
      
      int german_offset = 1;
      if(dt.mon >= 4 && dt.mon <= 10) 
         german_offset = 2;
      
      return utc_time + (german_offset * 3600);
   }
   
   int GetCurrentHourUTC()
   {
      datetime utc_time = TimeGMT();
      MqlDateTime dt;
      TimeToStruct(utc_time, dt);
      return dt.hour;
   }
   
   int GetCurrentHourGerman()
   {
      datetime german_time = GetGermanTime();
      MqlDateTime dt;
      TimeToStruct(german_time, dt);
      return dt.hour;
   }
   
   string GetTimezoneInfo()
   {
      string info = "";
      info += StringFormat("Broker Zeit: %s\n", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
      info += StringFormat("UTC Zeit: %s\n", TimeToString(TimeGMT(), TIME_DATE|TIME_MINUTES));
      info += StringFormat("Deutsche Zeit: %s\n", TimeToString(GetGermanTime(), TIME_DATE|TIME_MINUTES));
      info += StringFormat("Broker Offset: UTC%s%d\n", 
                          (m_broker_offset_hours >= 0 ? "+" : ""), 
                          m_broker_offset_hours);
      return info;
   }
   
private:
   int CalculateBrokerOffset()
   {
      datetime server_time = TimeCurrent();
      datetime gmt_time = TimeGMT();
      int offset_seconds = (int)(server_time - gmt_time);
      int offset_hours = offset_seconds / 3600;
      return offset_hours;
   }
};
//+------------------------------------------------------------------+