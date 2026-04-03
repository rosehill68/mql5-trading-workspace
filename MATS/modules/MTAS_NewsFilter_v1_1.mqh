// ============================================================================
//  Datei:       MTAS_NewsFilter_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Autor:       [Dein Name/Team]
//  Beschreibung: News-Event-Filter (Zeitbasierter Blocker)
// ============================================================================

#ifndef __MTAS_NEWSFILTER_V1_1_MQH
#define __MTAS_NEWSFILTER_V1_1_MQH

// Diese Dummy-Version blockt immer false (kein News-Event).
// Für echtes File/Calendar-Parsing: siehe Pflichtenheft.
bool IsNewsPending()
{
    // TODO: CSV, Calendar oder Events prüfen, hier nur Dummy!
    return false;
}

#endif // __MTAS_NEWSFILTER_V1_1_MQH