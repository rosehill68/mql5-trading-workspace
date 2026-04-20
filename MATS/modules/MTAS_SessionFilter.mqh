// ============================================================================
//  Datei:       MTAS_SessionFilter.mqh
//  Projekt:     MTAS v2.0
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Filter 1: Trading-Session-Filter.
//    Prueft ob der aktuelle UTC-Zeitpunkt innerhalb der erlaubten
//    Handelszeit liegt. Unterstuetzt Mitternachts-uebergreifende Sessions.
//    Unterstuetzt optional "Freitag 21 UTC kein Trade" (funded-safe).
//
//  Abhaengigkeiten: MTAS_Defines.mqh
// ============================================================================
#ifndef __MTAS_SESSIONFILTER_MQH
#define __MTAS_SESSIONFILTER_MQH

#include "MTAS_Defines.mqh"

// ============================================================================
//  Klasse: MTAS_SessionFilter
// ============================================================================
class MTAS_SessionFilter
{
private:
    int  m_start_utc;          // Startzeit (Stunde, inklusiv)
    int  m_end_utc;            // Endzeit   (Stunde, exklusiv)
    bool m_block_friday_close; // true = Freitag ab 21 UTC blockieren

public:
    MTAS_SessionFilter(void) : m_start_utc(8), m_end_utc(17), m_block_friday_close(true) {}

    void Init(const int start_utc, const int end_utc, const bool block_friday_close = true)
    {
        m_start_utc          = start_utc;
        m_end_utc            = end_utc;
        m_block_friday_close = block_friday_close;
    }

    // -----------------------------------------------------------------------
    //  IsActive – Gibt true zurueck wenn Trading erlaubt
    // -----------------------------------------------------------------------
    bool IsActive() const
    {
        datetime  tm = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(tm, dt);
        int h   = dt.hour;
        int dow = dt.day_of_week;   // 0=Sonntag, 5=Freitag, 6=Samstag

        // Wochenende immer blockieren
        if(dow == 0 || dow == 6) return false;

        // Freitag-Abend blockieren (funded-safe: kein offenes WE-Gap-Risiko)
        if(m_block_friday_close && dow == 5 && h >= 21) return false;

        // Session-Pruefung (Mitternacht-uebergreifend unterstuetzt)
        if(m_start_utc <= m_end_utc)
            return (h >= m_start_utc && h < m_end_utc);
        else
            return (h >= m_start_utc || h < m_end_utc);
    }
};

#endif // __MTAS_SESSIONFILTER_MQH
