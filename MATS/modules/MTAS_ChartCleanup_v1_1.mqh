// ============================================================================
//  Datei:       MTAS_ChartCleanup_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Beschreibung: Entfernt alle Objekte mit "MTAS_"-Präfix im Chart
// ============================================================================

#ifndef __MTAS_CHARTCLEANUP_V1_1_MQH
#define __MTAS_CHARTCLEANUP_V1_1_MQH

void MTAS_DeleteAllChartObjects(const string prefix = "MTAS_")
{
    for(int i=ObjectsTotal(0,0)-1; i>=0; i--) // Rückwärts wegen Löschen im Loop!
    {
        string name = ObjectName(0, i, 0);
        if(StringFind(name, prefix) == 0) // Startet mit Prefix?
            ObjectDelete(0, name);
    }
}

#endif // __MTAS_CHARTCLEANUP_V1_1_MQH