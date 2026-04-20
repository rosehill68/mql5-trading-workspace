// ============================================================================
//  Datei:       MTAS_ValueBuffer.mqh
//  Projekt:     MTAS v2.0
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Zirkulaerer Ringpuffer fuer Zeitreihen-Werte.
//    Verwendet fuer rollende Z-Score-Normalisierung von BBW und LSMA-Slope.
//    Kein dynamisches Allozieren nach Init.
//
//  Abhaengigkeiten: MTAS_Defines.mqh
// ============================================================================
#ifndef __MTAS_VALUEBUFFER_MQH
#define __MTAS_VALUEBUFFER_MQH

#include "MTAS_Defines.mqh"

// ============================================================================
//  Klasse: MTAS_ValueBuffer
//  Kapazitaet: fest bei Konstruktion, kein Resize nach Init.
//  Zugriff: neuester Wert zuerst (LIFO-Ansicht via GetValues()).
// ============================================================================
class MTAS_ValueBuffer
{
private:
    double m_data[];
    int    m_size;
    int    m_pos;      // Naechste Schreibposition (0-basiert, zirkulaer)
    bool   m_filled;   // true sobald >= m_size Werte hinzugefuegt wurden

public:
    // Konstruktor – Standard-Kapazitaet
    MTAS_ValueBuffer(void) : m_size(MTAS_ZSCORE_LOOKBACK), m_pos(0), m_filled(false)
    {
        ArrayResize(m_data, m_size);
        ArrayInitialize(m_data, 0.0);
    }

    // Konstruktor – benutzerdefinierte Kapazitaet
    MTAS_ValueBuffer(const int capacity) : m_pos(0), m_filled(false)
    {
        m_size = MathMax(2, capacity);
        ArrayResize(m_data, m_size);
        ArrayInitialize(m_data, 0.0);
    }

    // Reset – Puffer leeren
    void Reset()
    {
        m_pos    = 0;
        m_filled = false;
        ArrayInitialize(m_data, 0.0);
    }

    // Neuen Wert hinzufuegen
    void Add(const double value)
    {
        m_data[m_pos] = value;
        m_pos++;
        if(m_pos >= m_size)
        {
            m_pos    = 0;
            m_filled = true;
        }
    }

    // Anzahl gueltiger Werte
    int Count() const { return m_filled ? m_size : m_pos; }

    // Ist der Puffer vollstaendig gefuellt?
    bool IsFull() const { return m_filled; }

    // Werte lesen: out[0] = neuester Wert, out[Count()-1] = aeltester
    void GetValues(double &out[]) const
    {
        int n = Count();
        ArrayResize(out, n);
        for(int i = 0; i < n; i++)
            out[i] = m_data[(m_pos - i - 1 + m_size) % m_size];
    }

    // Z-Score des neuesten Wertes gegenueber den letzten N Werten
    // Gibt 0.0 zurueck wenn nicht genuegend Daten vorhanden
    double ZScore() const
    {
        int n = Count();
        if(n < 2) return 0.0;

        double vals[];
        GetValues(vals);

        double mean = 0.0;
        for(int i = 0; i < n; i++) mean += vals[i];
        mean /= n;

        double var = 0.0;
        for(int i = 0; i < n; i++) var += (vals[i] - mean) * (vals[i] - mean);
        double sd = MathSqrt(var / n);

        if(sd == 0.0) return 0.0;
        return MTAS_SAFE_DIV(vals[0] - mean, sd);
    }

    // Mittelwert der letzten N Werte
    double Mean() const
    {
        int n = Count();
        if(n == 0) return 0.0;
        double vals[];
        GetValues(vals);
        double s = 0.0;
        for(int i = 0; i < n; i++) s += vals[i];
        return s / n;
    }
};

#endif // __MTAS_VALUEBUFFER_MQH
