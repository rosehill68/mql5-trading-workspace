// ============================================================================
//  Datei:       MTAS_NewsFilter.mqh
//  Projekt:     MTAS v2.0
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Filter 2: News/Event-Filter.
//    Blockiert Trades innerhalb eines Zeitfensters um planbare Ereignisse.
//
//    Implementierung: Zeitbasierter Filter mit manuellem Event-Array.
//    Das Array kann per SetEvents() vor jedem Trading-Tag befuellt werden.
//    Alternativ: CSV-Datei einlesen (erweiterbar, Struktur vorbereitet).
//
//    Im Standardbetrieb ohne manuelle Events: IsNewsPending() = false.
//    funded-safe: Buffer von 30 Minuten vor und nach Event.
//
//  Abhaengigkeiten: MTAS_Defines.mqh, MTAS_Logger.mqh
// ============================================================================
#ifndef __MTAS_NEWSFILTER_MQH
#define __MTAS_NEWSFILTER_MQH

#include "MTAS_Defines.mqh"
#include "MTAS_Logger.mqh"

// ============================================================================
//  Struct: NewsEvent
// ============================================================================
struct NewsEvent
{
    datetime event_time;   // UTC-Zeit des Ereignisses
    int      impact;       // 1=Low, 2=Medium, 3=High
    string   currency;     // betroffene Waehrung, z.B. "USD"
};

// ============================================================================
//  Klasse: MTAS_NewsFilter
// ============================================================================
class MTAS_NewsFilter
{
private:
    NewsEvent m_events[];
    int       m_event_count;
    int       m_buffer_min_before; // Minuten vor Event blockieren
    int       m_buffer_min_after;  // Minuten nach Event blockieren
    int       m_min_impact;        // nur ab diesem Impact-Level blockieren

public:
    MTAS_NewsFilter(void) :
        m_event_count(0),
        m_buffer_min_before(30),
        m_buffer_min_after(30),
        m_min_impact(2)
    {
        ArrayResize(m_events, 0);
    }

    void Init(const int buffer_before_min = 30,
              const int buffer_after_min  = 30,
              const int min_impact        = 2)
    {
        m_buffer_min_before = buffer_before_min;
        m_buffer_min_after  = buffer_after_min;
        m_min_impact        = min_impact;
    }

    // -----------------------------------------------------------------------
    //  SetEvents – Setzt das Event-Array (von aussen befuellen)
    // -----------------------------------------------------------------------
    void SetEvents(const NewsEvent &events[], const int count)
    {
        ArrayResize(m_events, count);
        for(int i = 0; i < count; i++) m_events[i] = events[i];
        m_event_count = count;
        MTAS_LogInfo(StringFormat("NewsFilter: %d Events geladen", count));
    }

    // -----------------------------------------------------------------------
    //  ClearEvents – Alle Events loeschen
    // -----------------------------------------------------------------------
    void ClearEvents()
    {
        ArrayResize(m_events, 0);
        m_event_count = 0;
    }

    // -----------------------------------------------------------------------
    //  IsNewsPending – true = Trade verboten (News-Buffer aktiv)
    //
    //  symbol: Optional zur Currency-Filterung (z.B. "EURUSD" filtert EUR+USD)
    // -----------------------------------------------------------------------
    bool IsNewsPending(const string symbol = "") const
    {
        if(m_event_count == 0) return false;

        datetime now = TimeCurrent();
        long     before_sec = (long)m_buffer_min_before * 60;
        long     after_sec  = (long)m_buffer_min_after  * 60;

        for(int i = 0; i < m_event_count; i++)
        {
            if(m_events[i].impact < m_min_impact) continue;

            // Currency-Match (falls Symbol angegeben)
            if(StringLen(symbol) > 0 && StringLen(m_events[i].currency) > 0)
            {
                if(StringFind(symbol, m_events[i].currency) < 0) continue;
            }

            long diff = (long)now - (long)m_events[i].event_time;
            if(diff >= -before_sec && diff <= after_sec)
            {
                MTAS_LogInfo(StringFormat(
                    "NewsFilter: Event blockiert Trade (%s Impact=%d Zeit=%s)",
                    m_events[i].currency, m_events[i].impact,
                    TimeToString(m_events[i].event_time, TIME_DATE | TIME_MINUTES)));
                return true;
            }
        }
        return false;
    }
};

#endif // __MTAS_NEWSFILTER_MQH
