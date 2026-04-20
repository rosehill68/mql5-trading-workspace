// ============================================================================
//  Datei:       MTAS_Defines.mqh
//  Projekt:     MTAS v2.0 - Multi-Asset Trading System
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Zentrale Konstanten, Enums und Makros fuer das gesamte Projekt.
//    Alle anderen Module inkludieren diese Datei zuerst.
//    Keine Abhaengigkeiten von anderen MTAS-Modulen.
// ============================================================================
#ifndef __MTAS_DEFINES_MQH
#define __MTAS_DEFINES_MQH

// ---------- Versions-Tag ----------------------------------------------------
#define MTAS_VERSION          "2.0.0"
#define MTAS_MAGIC_BASE       200000   // Basis-Magic; asset-Index wird addiert

// ---------- Maximale Array-Groessen -----------------------------------------
#define MTAS_MAX_ASSETS       20
#define MTAS_ZSCORE_LOOKBACK  100      // Standard-Lookback fuer Z-Score-Buffer

// ---------- Log-Level -------------------------------------------------------
enum MTAS_LogLevel
{
    LOG_NONE  = 0,
    LOG_ERROR = 1,
    LOG_WARN  = 2,
    LOG_INFO  = 3,
    LOG_DEBUG = 4
};

// ---------- Marktregime -----------------------------------------------------
enum MTAS_Regime
{
    REGIME_UNKNOWN  = 0,
    REGIME_CHOP     = 1,   // BBW Z-Score zu niedrig   => kein Trade
    REGIME_TREND    = 2,   // BBW Z-Score im Band       => Trade erlaubt
    REGIME_EXTREME  = 3    // BBW Z-Score zu hoch       => kein neuer Trade
};

// ---------- Trendrichtung ---------------------------------------------------
enum MTAS_Trend
{
    TREND_NONE = 0,
    TREND_UP   = 1,
    TREND_DOWN = -1
};

// ---------- Signalrichtung --------------------------------------------------
enum MTAS_Direction
{
    DIR_NONE  = 0,
    DIR_LONG  = 1,
    DIR_SHORT = -1
};

// ---------- Trade-Status eines Assets ---------------------------------------
enum MTAS_TradeState
{
    TRADE_IDLE    = 0,   // kein offener Trade
    TRADE_OPEN    = 1,   // Trade aktiv
    TRADE_CLOSING = 2    // Schliessungsauftrag gesendet
};

// ---------- Fehler-/Exception-Klassen ---------------------------------------
enum MTAS_ExcType
{
    EXC_INFO        = 0,
    EXC_WARNING     = 1,
    EXC_RECOVERABLE = 2,
    EXC_CRITICAL    = 3
};

// ---------- Hilfsmakros -----------------------------------------------------
#define MTAS_SAFE_DIV(a,b)   ((b) == 0.0 ? 0.0 : (a)/(b))
#define MTAS_CLAMP(v,lo,hi)  (MathMax((lo), MathMin((hi), (v))))

#endif // __MTAS_DEFINES_MQH
