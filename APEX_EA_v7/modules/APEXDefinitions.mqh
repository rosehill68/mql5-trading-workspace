//+------------------------------------------------------------------+
//| APEXDefinitions.mqh                                                |
//| Version:  7.2                                                      |
//| Datum:    2026.03.05                                               |
//|                                                                    |
//| Inhalt:   Alle Aufzaehlungstypen (Enums), Eingabeparameter         |
//|           (Inputs) und Datenstrukturen fuer den APEX EA.           |
//+------------------------------------------------------------------+
#ifndef APEX_DEFINITIONS_MQH
#define APEX_DEFINITIONS_MQH

//+------------------------------------------------------------------+
//| Aufzaehlungstypen                                                  |
//+------------------------------------------------------------------+

enum ENUM_APEX_SIGNAL
{
    SIG_NONE = 0,
    SIG_BUY  = 1,
    SIG_SELL = 2
};

enum ENUM_APEX_REGIME
{
    REG_TREND_UP   = 0,
    REG_TREND_DOWN = 1,
    REG_RANGE      = 2,
    REG_UNDEF      = 3
};

enum ENUM_ASSET_CLASS
{
    ASSET_FOREX     = 0,
    ASSET_INDEX     = 1,
    ASSET_COMMODITY = 2,
    ASSET_CRYPTO    = 3
};

//+------------------------------------------------------------------+
//| Eingabeparameter (Inputs)                                          |
//+------------------------------------------------------------------+

// --- Grundeinstellungen ---
input group    "══════ GRUNDEINSTELLUNGEN ══════"
input int      InpMagic              = 20240601;      // Eindeutige Kennnummer dieses EAs
input bool     InpLiveTrade          = false;         // Echte Trades ausfuehren? (false = nur Signale)
input bool     InpSendEmail          = true;          // Email bei Signal senden?
input bool     InpSendPush           = false;         // Push ans Smartphone senden?

// --- Maerkte und Zeitrahmen ---
input group    "══════ MAERKTE UND ZEITRAHMEN ══════"
input string   InpSymbols            = "EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,XAUUSD,GBPJPY,NZDUSD,USDCHF,EURJPY,USOIL,US500,DE40,BTCUSD,ETHUSD";
input ENUM_TIMEFRAMES InpTF_Entry    = PERIOD_H4;     // Zeitrahmen fuer Einstieg
input ENUM_TIMEFRAMES InpTF_Regime   = PERIOD_D1;     // Zeitrahmen fuer Marktphasen

// --- Z-Score ---
input group    "══════ Z-SCORE (PREIS-EXTREMWERTE) ══════"
input int      InpZ_Period           = 50;            // Lookback-Periode
input double   InpZ_Threshold        = 2.0;           // Schwelle fuer Extrem-Signal

// --- Regime ---
input group    "══════ REGIME-ERKENNUNG ══════"
input int      InpER_Period          = 10;            // Efficiency Ratio Periode
input double   InpER_Trend           = 0.45;          // ER > 0.45 = Trend
input double   InpER_Range           = 0.25;          // ER < 0.25 = Range
input int      InpADX_Period         = 10;            // ADX Periode (nur Score-Bonus)

// --- Range ---
input group    "══════ RANGE-ERKENNUNG ══════"
input int      InpRange_Period       = 50;
input double   InpRange_UpperPct     = 90.0;
input double   InpRange_LowerPct     = 10.0;
input double   InpRange_EntryZone    = 15.0;
input double   InpRange_ExitZone     = 15.0;
input bool     InpRange_UseForSL     = true;
input bool     InpRange_UseForTP     = true;

// --- AOI ---
input group    "══════ AOI (AREAS OF INTEREST) ══════"
input bool     InpAOI_UsePivots      = true;          // Floor Pivot Points?
input bool     InpAOI_UseLevels      = true;          // Vorherige D1/W1 Hochs/Tiefs?
input bool     InpAOI_UseRoundNr     = true;          // Runde Zahlen?
input double   InpAOI_ZoneWidth      = 0.15;          // Zonen-Breite in Prozent vom Preis
input int      InpAOI_MinCluster     = 2;             // Ab wann gilt es als Cluster?

// --- Trailing Stop: Supertrend ---
input group    "══════ SUPERTREND (TRAILING STOP) ══════"
input int      InpST_ATR_Period      = 10;            // ATR-Periode fuer den Supertrend
input double   InpST_Mult_Base       = 3.0;           // Multiplikator (3.0 = TV-Standard)
input bool     InpST_Adaptive        = false;         // Adaptiv? (false = Standard, TV-kompatibel)
input int      InpRVOL_Period        = 20;            // RVOL-Periode (nur bei adaptiv relevant)

// --- Risikomanagement ---
input group    "══════ RISIKOMANAGEMENT ══════"
input double   InpRiskPct            = 0.15;          // Risiko pro Trade in Prozent (! Angepasst an Prop-Konto)
input int      InpMaxTrades          = 2;             // Max neue Trades pro Tag (! Angepasst an Prop-Konto)
input double   InpMaxDD              = 2.0;           // Max Drawdown in Prozent
input double   InpTV_Capital         = 45000.0;       // TradingView-Kontogroesse in USD
input double   InpMinCRV             = 2.0;           // Mindest-Chance-Risiko-Verhaeltnis

// --- Composite Score ---
input group    "══════ COMPOSITE SCORE (7 DIMENSIONEN) ══════"
input double   InpW_Price            = 0.20;          // Gewicht PREIS
input double   InpW_Trigger          = 0.20;          // Gewicht TRIGGER
input double   InpW_Regime           = 0.10;          // Gewicht REGIME
input double   InpW_Range            = 0.10;          // Gewicht RANGE
input double   InpW_AOI              = 0.15;          // Gewicht AOI
input double   InpW_Volume           = 0.15;          // Gewicht VOLUMEN
input double   InpW_Context          = 0.10;          // Gewicht KONTEXT
input double   InpMinComposite_Trade = 6.5;           // Mindest-Score fuer Trade
input double   InpMinComposite_Email = 5.0;           // Mindest-Score fuer Email

// --- Handelszeiten ---
input group    "══════ HANDELSZEITEN (DEUTSCHE ZEIT) ══════"
input int      InpBrokerUTC          = 2;
input int      InpGermanUTC          = 1;
input int      InpForexStartH        = 9;
input int      InpForexEndH          = 17;
input int      InpForexExtStartH     = 8;
input int      InpForexExtEndH       = 20;
input int      InpFridayEndH         = 16;

// --- Krypto ---
input group    "══════ KRYPTO (OPTIONAL) ══════"
input bool     InpCryptoEnabled      = true;
input int      InpCryptoStartH       = 20;
input int      InpCryptoEndH         = 8;
input bool     InpCryptoWeekend      = true;

//+------------------------------------------------------------------+
//| Datenstrukturen                                                    |
//+------------------------------------------------------------------+

// Einzelnes AOI-Level
struct AOI_Level
{
    double preis;
    string name;
    string typ;
};

// Alle AOI-Daten
struct AOI_Data
{
    AOI_Level levels[];
    int       anzahl;
    int       nahe_level;
    double    naechstes;
    string    naechster_name;
    double    abstand_pct;
    bool      in_zone;
    bool      cluster;
    bool      valid;
};

// Range-Daten
struct RangeData
{
    double upper;
    double lower;
    double mid;
    double width;
    double width_pct;
    double position;
    double tp_level;
    bool   at_upper;
    bool   at_lower;
    bool   outside;
    bool   valid;
};

// TradingView-Positionsgroesse
struct TV_Position
{
    double lots;              // Berechnete Lotgroesse fuer TV
    double risiko_usd;        // Risikobetrag in USD
    double mini_lots;         // Mini-Lot Aequivalent (Forex)
    double micro_lots;        // Micro-Lot Aequivalent (Forex)
    double einheiten;         // Stueckzahl (Unzen, Coins usw.)
    string einheit_name;      // Beschreibung der Einheit
    string groessen_text;     // Fertig formatiert fuer Email
    bool   valid;             // Berechnung erfolgreich?
};

// Signal-Daten (alles ueber ein erkanntes Handelssignal)
struct SignalData
{
    string            symbol;
    ENUM_APEX_SIGNAL  direction;
    ENUM_APEX_REGIME  regime;
    ENUM_ASSET_CLASS  asset_class;
    string            pattern;
    
    double            entry;
    double            sl;
    double            tp_ind;
    double            lots_mt5;
    double            risk_tv_usd;
    TV_Position       tv_pos;
    
    double            zscore;
    double            roc;
    double            er_entry;
    double            er_regime;
    double            adx;
    double            natr;
    double            rvol;
    double            vol_pctile;
    double            htf_zscore;
    double            st_mult;
    double            spread_pct;
    bool              mtf_aligned;
    
    RangeData         range;
    AOI_Data          aoi;
    
    double            sub_price;
    double            sub_trigger;
    double            sub_regime;
    double            sub_range;
    double            sub_aoi;
    double            sub_volume;
    double            sub_context;
    
    double            composite;
    double            actual_rrr;
    string            grade;
};

// Symbol-Status
struct SymbolState
{
    string   name;
    bool     ok;
    datetime last_bar;
};

#define MAX_SYMBOLS     30
#define MAX_AOI_LEVELS  30

#endif