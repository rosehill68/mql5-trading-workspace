// ============================================================================
//  Datei:       MTAS_DataModel.mqh
//  Projekt:     MTAS v2.0
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Zentrale Datenmodelle (Structs) fuer das gesamte System.
//    Alle Daten fliessen als Instanzen dieser Structs durch die Pipeline.
//    Kein Code (keine Funktionen) in dieser Datei – nur Typdefinitionen.
//
//    Datenfluss:
//      MarketSnapshot --> IndicatorState --> RegimeState -->
//      SignalState --> RiskState --> TradePlan --> ExecutionResult
//
//  Abhaengigkeiten: MTAS_Defines.mqh
// ============================================================================
#ifndef __MTAS_DATAMODEL_MQH
#define __MTAS_DATAMODEL_MQH

#include "MTAS_Defines.mqh"

// ============================================================================
//  1. MarketSnapshot – Rohe Marktdaten fuer einen Bar/Tick
// ============================================================================
struct MarketSnapshot
{
    string   symbol;
    datetime bar_time;          // Zeitstempel des letzten abgeschlossenen Bars
    double   bid;
    double   ask;
    double   spread_points;     // In Points (z.B. 1.5 fuer EURUSD = 1.5 Punkte)
    double   point_size;        // SymbolInfoDouble(SYMBOL_POINT)
    double   tick_value;        // SymbolInfoDouble(SYMBOL_TRADE_TICK_VALUE)
    double   tick_size;         // SymbolInfoDouble(SYMBOL_TRADE_TICK_SIZE)
    double   vol_min;
    double   vol_max;
    double   vol_step;
};

// ============================================================================
//  2. IndicatorState – Berechnete Indikatorwerte fuer HTF und LTF
// ============================================================================
struct IndicatorState
{
    // HTF (Higher Time Frame, z.B. H4)
    double lsma_htf;            // LSMA-Wert
    double slope_htf;           // LSMA-Steigung (raw, in Preis/Bar)
    double slope_htf_norm;      // Slope / ATR (normalisiert)
    double slope_htf_z;         // Z-Score der Slope-Serie
    double bbw_htf;             // Bollinger Band Width (normiert auf Preis)
    double bbw_htf_z;           // Z-Score der BBW-Serie

    // LTF (Lower Time Frame, z.B. H1)
    double lsma_ltf;            // LSMA-Wert
    double slope_ltf;           // LSMA-Steigung
    double atr_ltf;             // ATR (14)
    double rsi_ltf;             // RSI (14)

    bool   valid;               // true = alle Werte berechnet
};

// ============================================================================
//  3. RegimeState – Marktregime und Trendqualitaet
// ============================================================================
struct RegimeState
{
    MTAS_Regime   regime;       // CHOP / TREND / EXTREME
    MTAS_Trend    trend_htf;    // Trendrichtung auf HTF
    MTAS_Trend    trend_ltf;    // Trendrichtung auf LTF (Confirmation)
    double        trend_strength; // 0.0 ... 1.0 (|slope_htf_z| normiert)
    bool          tradeable;    // Kombination aus Regime + Trend
};

// ============================================================================
//  4. SignalState – Ergebnis der Signal-Pipeline
// ============================================================================
struct SignalState
{
    MTAS_Direction direction;    // LONG / SHORT / NONE
    bool           pullback_ok;  // Preis nahe LSMA_LTF
    double         pull_quality; // 0.0 ... 1.0 (Guete des Pullbacks)
    bool           rsi_ok;       // RSI bestaetigt Richtung
    double         rsi_value;    // aktueller RSI-Wert
    bool           session_ok;   // Trading-Session aktiv
    bool           news_ok;      // kein News-Event
    double         confidence;   // Gesamt-Score 0.0 ... 1.0
};

// ============================================================================
//  5. RiskState – Ergebnis der Risk-Engine
// ============================================================================
struct RiskState
{
    bool   trade_allowed;        // darf ein Trade geoeffnet werden
    string block_reason;         // falls !trade_allowed: Grund

    double account_balance;
    double account_equity;
    double daily_pnl;            // Gewinn/Verlust heute (alle Trades)
    double weekly_pnl;           // Gewinn/Verlust diese Woche
    double open_dd_pct;          // Offener Drawdown in Prozent des Balance
    int    open_trade_count;     // Anzahl offener Trades (EA-weit)
    double spread_atr_ratio;     // Spread / ATR (0 = kein Spread-Problem)
};

// ============================================================================
//  6. TradePlan – Vollstaendiger Plan vor Ausfuehrung
// ============================================================================
struct TradePlan
{
    bool           valid;        // true = Plan vollstaendig und verifiziert
    string         symbol;
    MTAS_Direction direction;
    double         entry_price;  // 0 = Market
    double         stop_loss;
    double         take_profit;
    double         lots;
    long           magic;
    string         comment;
    double         risk_pct;     // Erwartetes Risiko in % des Balance
    double         rr_ratio;     // Reward/Risk-Verhaeltnis
};

// ============================================================================
//  7. ExecutionResult – Ergebnis nach Order-Senden
// ============================================================================
struct ExecutionResult
{
    bool   success;
    ulong  ticket;           // 0 falls fehlgeschlagen
    int    retries;          // Anzahl Versuche
    int    last_error;       // GetLastError()
    string error_msg;
};

// ============================================================================
//  8. AssetContext – Vollstaendiger Status je Asset (persistent)
// ============================================================================
struct AssetContext
{
    string         symbol;
    int            asset_index;    // Index in Universe-Array

    // Zustand des offenen Trades
    MTAS_TradeState trade_state;
    ulong           ticket;
    MTAS_Direction  trade_dir;
    double          entry_price;
    double          ratchet_sl;    // laufend aktualisierter Stop
    double          initial_sl;
    double          take_profit;
    double          lots;
    datetime        open_time;

    // Zuletzt berechnete Zust‑nde
    IndicatorState  indicators;
    RegimeState     regime;
    SignalState     signal;
    RiskState       risk;
    TradePlan       plan;

    // Puffer fuer Z-Score-Berechnung (BBW und Slope)
    double          bbw_buf[MTAS_ZSCORE_LOOKBACK];
    double          slope_buf[MTAS_ZSCORE_LOOKBACK];
    int             buf_pos;
    bool            buf_filled;
};

#endif // __MTAS_DATAMODEL_MQH
