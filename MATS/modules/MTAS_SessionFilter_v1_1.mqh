// ============================================================================
//  Datei:       MTAS_SessionFilter_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: Sessionfilter nach UTC-Stunden (Handelszeiten)
// ============================================================================

#ifndef __MTAS_SESSIONFILTER_V1_1_MQH
#define __MTAS_SESSIONFILTER_V1_1_MQH

bool IsSessionActive(const int start_utc, const int end_utc)
{
    datetime tm = TimeCurrent();
    MqlDateTime now;
    TimeToStruct(tm, now);
    int hour_utc = now.hour;
    if(start_utc <= end_utc)
        return (hour_utc >= start_utc && hour_utc < end_utc);
    // Über Mitternacht (z.B. 22–7)
    else
        return (hour_utc >= start_utc || hour_utc < end_utc);
}

#endif // __MTAS_SESSIONFILTER_V1_1_MQH