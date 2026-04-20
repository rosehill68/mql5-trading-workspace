// ============================================================================
//  Datei:       MTAS_IndicatorEngine.mqh
//  Projekt:     MTAS v2.0
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Schicht 1: Indikator-Engine.
//    Fassade: Liest alle Indikatoren fuer ein Asset, aktualisiert Puffer
//    und fuellt das IndicatorState-Struct.
//    Zentrale Stelle fuer HTF/LTF Timeframe-Zuweisung.
//
//  Abhaengigkeiten:
//    MTAS_DataModel.mqh, MTAS_Indicators.mqh, MTAS_Normalizer.mqh,
//    MTAS_ValueBuffer.mqh, MTAS_Logger.mqh
// ============================================================================
#ifndef __MTAS_INDICATORENGINE_MQH
#define __MTAS_INDICATORENGINE_MQH

#include "MTAS_DataModel.mqh"
#include "MTAS_Indicators.mqh"
#include "MTAS_Normalizer.mqh"
#include "MTAS_ValueBuffer.mqh"
#include "MTAS_Logger.mqh"

// ============================================================================
//  Klasse: MTAS_IndicatorEngine
//  Pro Asset eine Instanz. Haelt Ringpuffer fuer BBW und Slope.
// ============================================================================
class MTAS_IndicatorEngine
{
private:
    // Konfiguration
    string           m_symbol;
    ENUM_TIMEFRAMES  m_tf_htf;         // z.B. PERIOD_H4
    ENUM_TIMEFRAMES  m_tf_ltf;         // z.B. PERIOD_H1
    int              m_lsma_period_htf;
    int              m_lsma_period_ltf;
    int              m_bbw_period;
    double           m_bbw_stdev;
    int              m_atr_period;
    int              m_rsi_period;
    int              m_zscore_lookback;

    // Zustandspuffer
    MTAS_ValueBuffer m_bbw_buf;
    MTAS_ValueBuffer m_slope_buf;

public:
    // -----------------------------------------------------------------------
    //  Konstruktor
    // -----------------------------------------------------------------------
    MTAS_IndicatorEngine(void) : m_zscore_lookback(MTAS_ZSCORE_LOOKBACK)
    {
        m_symbol           = _Symbol;
        m_tf_htf           = PERIOD_H4;
        m_tf_ltf           = PERIOD_H1;
        m_lsma_period_htf  = 50;
        m_lsma_period_ltf  = 50;
        m_bbw_period       = 20;
        m_bbw_stdev        = 2.0;
        m_atr_period       = 14;
        m_rsi_period       = 14;
    }

    // -----------------------------------------------------------------------
    //  Init – Muss einmalig nach Konstruktion aufgerufen werden
    // -----------------------------------------------------------------------
    void Init(const string symbol,
              const ENUM_TIMEFRAMES tf_htf, const ENUM_TIMEFRAMES tf_ltf,
              const int lsma_htf, const int lsma_ltf,
              const int bbw_period, const double bbw_stdev,
              const int atr_period, const int rsi_period,
              const int zscore_lookback = MTAS_ZSCORE_LOOKBACK)
    {
        m_symbol           = symbol;
        m_tf_htf           = tf_htf;
        m_tf_ltf           = tf_ltf;
        m_lsma_period_htf  = lsma_htf;
        m_lsma_period_ltf  = lsma_ltf;
        m_bbw_period       = bbw_period;
        m_bbw_stdev        = bbw_stdev;
        m_atr_period       = atr_period;
        m_rsi_period       = rsi_period;
        m_zscore_lookback  = zscore_lookback;
    }

    // -----------------------------------------------------------------------
    //  Update – Wird einmal je Bar aufgerufen.
    //  Fuellt IndicatorState komplett.
    //  Rueckgabe: false bei Datenfehler (unvollstaendige History)
    // -----------------------------------------------------------------------
    bool Update(IndicatorState &state)
    {
        state.valid = false;

        // --- HTF ---
        LSMA_Result lhtf = CalcLSMA(m_symbol, m_tf_htf, m_lsma_period_htf, 1);
        if(!lhtf.valid)
        {
            MTAS_LogDebug(StringFormat("IndicatorEngine[%s]: LSMA-HTF ungueltig", m_symbol));
            return false;
        }

        double bbw = CalcBBW(m_symbol, m_tf_htf, m_bbw_period, m_bbw_stdev, 1);
        if(bbw < 0.0)
        {
            MTAS_LogDebug(StringFormat("IndicatorEngine[%s]: BBW-HTF ungueltig", m_symbol));
            return false;
        }

        // Puffer aktualisieren
        double atr_htf_raw = CalcATR(m_symbol, m_tf_htf, m_atr_period, 1);
        if(atr_htf_raw <= 0.0) return false;

        double slope_norm = NormalizeSlope(lhtf.slope, atr_htf_raw);
        m_slope_buf.Add(slope_norm);
        m_bbw_buf.Add(bbw);

        state.lsma_htf       = lhtf.value;
        state.slope_htf      = lhtf.slope;
        state.slope_htf_norm = slope_norm;
        state.slope_htf_z    = m_slope_buf.ZScore();
        state.bbw_htf        = bbw;
        state.bbw_htf_z      = m_bbw_buf.ZScore();

        // --- LTF ---
        LSMA_Result lltf = CalcLSMA(m_symbol, m_tf_ltf, m_lsma_period_ltf, 1);
        if(!lltf.valid)
        {
            MTAS_LogDebug(StringFormat("IndicatorEngine[%s]: LSMA-LTF ungueltig", m_symbol));
            return false;
        }

        double atr = CalcATR(m_symbol, m_tf_ltf, m_atr_period, 1);
        double rsi = CalcRSI(m_symbol, m_tf_ltf, m_rsi_period, 1);

        if(atr < 0.0 || rsi < 0.0)
        {
            MTAS_LogDebug(StringFormat("IndicatorEngine[%s]: ATR/RSI ungueltig", m_symbol));
            return false;
        }

        state.lsma_ltf  = lltf.value;
        state.slope_ltf = lltf.slope;
        state.atr_ltf   = atr;
        state.rsi_ltf   = rsi;
        state.valid     = true;

        MTAS_LogDebug(StringFormat(
            "Ind[%s] LSMAhtf=%.5f slopeZ=%.2f BBWz=%.2f | LSMAltf=%.5f ATR=%.5f RSI=%.2f",
            m_symbol, state.lsma_htf, state.slope_htf_z, state.bbw_htf_z,
            state.lsma_ltf, state.atr_ltf, state.rsi_ltf));

        return true;
    }

    // Puffer zuruecksetzen (z.B. nach Parameter-Aenderung)
    void Reset()
    {
        m_bbw_buf.Reset();
        m_slope_buf.Reset();
    }
};

#endif // __MTAS_INDICATORENGINE_MQH
