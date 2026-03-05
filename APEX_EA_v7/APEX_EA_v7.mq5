Alles klar. Wenn alle `.mqh`-Dateien nun in einem Unterordner namens `modules` (relativ zur Haupdatei) liegen, ändert sich die Art und Weise, wie die Dateien eingebunden (`#include`) werden:

1.  **In der Hauptdatei (`APEX_EA_v7.mq5`)**: Hier muss der Pfad auf den Ordner verweisen, also z.B. `#include "modules/APEXDefinitions.mqh"`.
2.  **In den Include-Dateien selbst**: Da diese nun alle *gemeinsam* im selben Ordner `modules` liegen, können sie sich untereinander ohne Pfadangabe aufrufen, also einfach `#include "APEXDefinitions.mqh"`.

Um dir das viele Scrollen zu ersparen, habe ich **jede einzelne Datei in einen ausklappbaren Bereich (Spoiler)** gepackt. Du kannst einfach die Datei aufklappen, die du gerade kopieren möchtest. 

Alle Datumsangaben im Header wurden auf das aktuelle Jahr **2026** aktualisiert.

---

### Hauptdatei (liegt im Hauptordner)

<details>
<summary><strong>📄 APEX_EA_v7.mq5</strong> (Klick zum Ausklappen)</summary>

```mql5
//+------------------------------------------------------------------+
//| APEX_EA_v7.mq5                                                     |
//| Version:  7.2                                                      |
//| Datum:    2026.03.05                                               |
//|                                                                    |
//| APEX – Adaptive Price-action EXtreme Strategy                      |
//| 7-Dimensionen Composite Score | AOI | Standard-Supertrend          |
//|                                                                    |
//| Ordnerstruktur: Alle Module liegen im Unterordner "modules/"       |
//+------------------------------------------------------------------+
#property copyright "APEX Strategy EA v7.2"
#property version   "7.20"
#property strict
#property description "APEX v7.2: 7D Composite | AOI | Standard-ST (TV-kompatibel)"
#property description "Non-Repaint | Non-Lag | Alle Indikatoren intern | KISS"

#include <Trade\Trade.mqh>
#include <Trade\AccountInfo.mqh>

// --- Einbindung der lokalen Module aus dem Unterordner "modules" ---
#include "modules/APEXDefinitions.mqh"
#include "modules/APEXCore.mqh"
#include "modules/APEXRange.mqh"
#include "modules/APEXAOI.mqh"
#include "modules/APEXPriceAction.mqh"
#include "modules/APEXSupertrend.mqh"
#include "modules/APEXComposite.mqh"
#include "modules/APEXRisk.mqh"
#include "modules/APEXNotify.mqh"
#include "modules/APEXUtils.mqh"

//+------------------------------------------------------------------+
//| Globale Variablen                                                  |
//+------------------------------------------------------------------+
CTrade       g_trade;
CAccountInfo g_konto;
SymbolState  g_symbole[];
int          g_sym_anz = 0;
int          g_trades_heute = 0;
datetime     g_heute = 0;
double       g_peak = 0;
string       g_parsed[];

//+------------------------------------------------------------------+
//| INIT                                                               |
//+------------------------------------------------------------------+
int OnInit()
{
    g_sym_anz = StringSplit(InpSymbols, ',', g_parsed);
    if(g_sym_anz <= 0) { Print("APEX: Keine Symbole!"); return INIT_PARAMETERS_INCORRECT; }
    if(g_sym_anz > MAX_SYMBOLS) g_sym_anz = MAX_SYMBOLS;
    
    ArrayResize(g_symbole, g_sym_anz);
    int aktiv = 0;
    
    for(int i = 0; i < g_sym_anz; i++)
    {
        StringTrimLeft(g_parsed[i]);
        StringTrimRight(g_parsed[i]);
        g_symbole[i].name = g_parsed[i];
        g_symbole[i].last_bar = 0;
        g_symbole[i].ok = SymbolSelect(g_parsed[i], true);
        if(g_symbole[i].ok) aktiv++;
        else PrintFormat("APEX: %s nicht verfuegbar!", g_parsed[i]);
    }
    
    g_trade.SetExpertMagicNumber(InpMagic);
    g_trade.SetDeviationInPoints(15);
    g_trade.SetTypeFilling(ORDER_FILLING_IOC);
    g_peak = g_konto.Balance();
    
    if(!EventSetTimer(30)) { Print("APEX: Timer-Fehler!"); return INIT_FAILED; }
    
    double gw = InpW_Price + InpW_Trigger + InpW_Regime + InpW_Range
              + InpW_AOI + InpW_Volume + InpW_Context;
    
    PrintFormat("═══════════════════════════════════════════");
    PrintFormat("  APEX EA v7.2 gestartet (Wartung 2026)");
    PrintFormat("  Symbole: %d/%d aktiv", aktiv, g_sym_anz);
    PrintFormat("  Regime: %s | Einstieg: %s",
                EnumToString(InpTF_Regime), EnumToString(InpTF_Entry));
    PrintFormat("  Supertrend: %s (ATR %d, Mult %.1f)",
                InpST_Adaptive ? "ADAPTIV" : "STANDARD (TV-kompatibel)",
                InpST_ATR_Period, InpST_Mult_Base);
    PrintFormat("  Score: 7D | Gewichte: %.2f", gw);
    PrintFormat("  AOI: Pivots=%s Level=%s Rund=%s",
                InpAOI_UsePivots ? "AN" : "AUS",
                InpAOI_UseLevels ? "AN" : "AUS",
                InpAOI_UseRoundNr ? "AN" : "AUS");
    PrintFormat("  TV-Kapital: $%.0f | Risiko: %.2f%%", InpTV_Capital, InpRiskPct);
    PrintFormat("═══════════════════════════════════════════");
    
    return INIT_SUCCEEDED;
}

void OnDeinit(const int r)
{
    EventKillTimer();
    PrintFormat("APEX v7.2 beendet. Trades heute: %d", g_trades_heute);
}

//+------------------------------------------------------------------+
//| TIMER: Scanner (alle 30 Sekunden)                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
    MqlDateTime dt;
    TimeCurrent(dt);
    datetime tag = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
    if(tag != g_heute) { g_trades_heute = 0; g_heute = tag; }
    
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;
    if(g_trades_heute >= InpMaxTrades) return;
    if(APEX_DrawdownHit(g_konto.Equity(), g_peak)) return;
    
    for(int i = 0; i < g_sym_anz && g_trades_heute < InpMaxTrades; i++)
    {
        if(!g_symbole[i].ok) continue;
        datetime bz = iTime(g_symbole[i].name, InpTF_Entry, 0);
        if(bz == g_symbole[i].last_bar) continue;
        if(APEX_HasPosition(g_symbole[i].name, InpMagic)) continue;
        
        SignalData sig;
        ZeroMemory(sig);
        sig.symbol = g_symbole[i].name;
        sig.asset_class = APEX_GetAssetClass(sig.symbol);
        
        int erg = ProcessSignal(sig);
        
        if(erg == 1)
        {
            g_symbole[i].last_bar = bz;
            if(InpLiveTrade) APEX_ExecuteTrade(g_trade, sig);
            if(InpSendEmail) APEX_SendEmail(sig);
            if(InpSendPush)  APEX_SendPush(sig);
            g_trades_heute++;
            PrintFormat("APEX #%d: %s %s [%s %.2f] CRV:%.1f %s AOI:%s ST:%s",
                        g_trades_heute, sig.symbol,
                        sig.direction == SIG_BUY ? "KAUF" : "VERK",
                        sig.grade, sig.composite, sig.actual_rrr,
                        sig.pattern, sig.aoi.in_zone ? "JA" : "NEIN",
                        InpST_Adaptive ? "ADAPTIV" : "STD");
        }
        else if(erg == 0)
        {
            g_symbole[i].last_bar = bz;
            if(InpSendEmail) APEX_SendEmail(sig);
        }
    }
}

//+------------------------------------------------------------------+
//| TICK: Trailing Stop nachziehen                                     |
//+------------------------------------------------------------------+
void OnTick()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(tk == 0) continue;
        if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
        APEX_TrailPosition(g_trade,
                           PositionGetString(POSITION_SYMBOL), tk,
                           (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE),
                           PositionGetDouble(POSITION_SL));
    }
}

//+------------------------------------------------------------------+
//| PIPELINE: 7 Schritte zur Trade-Entscheidung                       |
//+------------------------------------------------------------------+
int ProcessSignal(SignalData &sig)
{
    string s = sig.symbol;
    
    // 1. Session
    if(!APEX_TimeOK_ForAsset(s)) return -1;
    
    // 2. Marktumfeld
    double mn = APEX_GetMinNATR(sig.asset_class);
    sig.vol_pctile = APEX_VolPercentile(s, InpTF_Entry, 100);
    sig.natr = APEX_NATR(s, InpTF_Entry, 14);
    if(sig.vol_pctile < 10.0 || sig.natr < mn) return -1;
    
    // 3. Regime
    sig.er_regime  = APEX_ER(s, InpTF_Regime, InpER_Period);
    sig.adx        = APEX_ADX(s, InpTF_Regime, InpADX_Period);
    sig.er_entry   = APEX_ER(s, InpTF_Entry, InpER_Period);
    sig.htf_zscore = APEX_ZScore(s, InpTF_Regime, InpZ_Period);
    sig.regime     = APEX_ClassifyRegime(sig.er_regime, sig.htf_zscore);
    if(sig.regime == REG_UNDEF) return -1;
    
    // 4. Z-Score + Range + AOI
    sig.zscore = APEX_ZScore(s, InpTF_Entry, InpZ_Period);
    sig.roc    = APEX_ROC(s, InpTF_Entry, 10);
    
    double zt = APEX_GetZThreshold(sig.asset_class);
    bool kb = false, vs = false;
    
    if(sig.regime == REG_RANGE)
    {
        kb = (sig.zscore <= -zt);
        vs = (sig.zscore >=  zt);
    }
    else if(sig.regime == REG_TREND_UP)
        kb = (sig.zscore > -1.5 && sig.zscore < 0.0);
    else if(sig.regime == REG_TREND_DOWN)
        vs = (sig.zscore < 1.5 && sig.zscore > 0.0);
    
    if(!kb && !vs) return -1;
    
    ENUM_APEX_SIGNAL vr = kb ? SIG_BUY : SIG_SELL;
    APEX_CalcRange(s, InpTF_Entry, vr, sig.range);
    APEX_CalcAOI(s, sig.aoi);
    
    if(sig.regime == REG_RANGE && sig.range.valid)
    {
        if(kb && !sig.range.at_lower) kb = false;
        if(vs && !sig.range.at_upper) vs = false;
    }
    if(!kb && !vs) return -1;
    
    // 5. Price Action
    sig.pattern = "";
    if(kb)
    {
        sig.pattern = APEX_BullPattern(s, InpTF_Entry);
        if(sig.pattern == "") return -1;
        sig.direction = SIG_BUY;
    }
    else
    {
        sig.pattern = APEX_BearPattern(s, InpTF_Entry);
        if(sig.pattern == "") return -1;
        sig.direction = SIG_SELL;
    }
    
    // 6. Trade-Parameter
    sig.rvol = APEX_RVOL(s, InpTF_Entry, InpRVOL_Period);
    
    double st_w, st_m;
    bool   st_b;
    APEX_Supertrend(s, st_w, st_b, st_m);
    sig.st_mult = st_m;
    
    int    dg  = (int)SymbolInfoInteger(s, SYMBOL_DIGITS);
    double atr = APEX_ATR(s, InpTF_Entry, 14);
    
    if(sig.direction == SIG_BUY)
    {
        sig.entry = SymbolInfoDouble(s, SYMBOL_ASK);
        sig.sl = NormalizeDouble(st_w, dg);
        if(sig.sl >= sig.entry)
            sig.sl = NormalizeDouble(sig.entry - atr * InpST_Mult_Base, dg);
        if(InpRange_UseForSL && sig.range.valid && sig.regime == REG_RANGE)
        {
            double rsl = NormalizeDouble(sig.range.lower - atr * 0.5, dg);
            if(rsl < sig.entry && rsl < sig.sl) sig.sl = rsl;
        }
        if(InpRange_UseForTP && sig.range.valid && sig.regime == REG_RANGE)
            sig.tp_ind = NormalizeDouble(sig.range.tp_level, dg);
        else
            sig.tp_ind = NormalizeDouble(sig.entry + MathAbs(sig.entry - sig.sl) * InpMinCRV, dg);
    }
    else
    {
        sig.entry = SymbolInfoDouble(s, SYMBOL_BID);
        sig.sl = NormalizeDouble(st_w, dg);
        if(sig.sl <= sig.entry)
            sig.sl = NormalizeDouble(sig.entry + atr * InpST_Mult_Base, dg);
        if(InpRange_UseForSL && sig.range.valid && sig.regime == REG_RANGE)
        {
            double rsl = NormalizeDouble(sig.range.upper + atr * 0.5, dg);
            if(rsl > sig.entry && rsl > sig.sl) sig.sl = rsl;
        }
        if(InpRange_UseForTP && sig.range.valid && sig.regime == REG_RANGE)
            sig.tp_ind = NormalizeDouble(sig.range.tp_level, dg);
        else
            sig.tp_ind = NormalizeDouble(sig.entry - MathAbs(sig.sl - sig.entry) * InpMinCRV, dg);
    }
    
    double sl_ab = MathAbs(sig.entry - sig.sl);
    if(sl_ab <= 0.0) return -1;
    
    double msp = APEX_GetMaxSpreadPct(sig.asset_class);
    if(!APEX_SpreadOK(s, sl_ab, msp)) return -1;
    
    double sp = SymbolInfoDouble(s, SYMBOL_ASK) - SymbolInfoDouble(s, SYMBOL_BID);
    sig.spread_pct = (sl_ab > 0.0) ? (sp / sl_ab) * 100.0 : 0.0;
    
    sig.lots_mt5    = APEX_CalcLots(s, sl_ab, g_konto.Balance());
    sig.risk_tv_usd = InpTV_Capital * (InpRiskPct / 100.0);
    APEX_CalcTV_Position(s, sl_ab, sig.asset_class, sig.tv_pos);
    if(sig.lots_mt5 <= 0.0) return -1;
    
    // MTF Alignment
    sig.mtf_aligned = false;
    if(sig.regime == REG_RANGE)
    {
        if(sig.direction == SIG_BUY  && sig.htf_zscore < 0.0) sig.mtf_aligned = true;
        if(sig.direction == SIG_SELL && sig.htf_zscore > 0.0) sig.mtf_aligned = true;
    }
    if(sig.regime == REG_TREND_UP   && sig.direction == SIG_BUY)  sig.mtf_aligned = true;
    if(sig.regime == REG_TREND_DOWN && sig.direction == SIG_SELL) sig.mtf_aligned = true;
    
    // 7. Composite Score
    APEX_CalcComposite(sig);
    if(sig.actual_rrr < InpMinCRV) return -1;
    
    if(sig.composite >= InpMinComposite_Trade) return 1;
    if(sig.composite >= InpMinComposite_Email) return 0;
    return -1;
}
//+------------------------------------------------------------------+
```

</details>

---

### Include-Module (liegen alle im Ordner `modules`)

<details>
<summary><strong>📄 1. APEXDefinitions.mqh</strong> (Klick zum Ausklappen)</summary>

```mql5
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
```

</details>


<details>
<summary><strong>📄 2. APEXCore.mqh</strong> (Klick zum Ausklappen)</summary>

```mql5
//+------------------------------------------------------------------+
//| APEXCore.mqh                                                       |
//| Version:  6.3                                                      |
//| Datum:    2026.03.05                                               |
//|                                                                    |
//| Inhalt:   Alle Indikator-Berechnungen, komplett intern.            |
//|           Keine externen Indicator-Handles.                        |
//+------------------------------------------------------------------+
#ifndef APEX_CORE_MQH
#define APEX_CORE_MQH

#include "APEXDefinitions.mqh"

//+------------------------------------------------------------------+
//| Z-SCORE: Misst wie weit der Preis vom Durchschnitt entfernt ist    |
//+------------------------------------------------------------------+
double APEX_ZScore(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    double schlusskurse[];
    ArraySetAsSeries(schlusskurse, true);
    if(CopyClose(sym, tf, 1, periode, schlusskurse) < periode)
        return 0.0;
    
    double summe = 0.0;
    double summe_q = 0.0;
    for(int i = 0; i < periode; i++)
    {
        summe   += schlusskurse[i];
        summe_q += schlusskurse[i] * schlusskurse[i];
    }
    
    double avg = summe / (double)periode;
    double var = summe_q / (double)periode - avg * avg;
    double std = (var > 0.0) ? MathSqrt(var) : 1e-10;
    
    return (schlusskurse[0] - avg) / std;
}

//+------------------------------------------------------------------+
//| EFFICIENCY RATIO: Misst Trendstaerke (0=Range, 1=Trend)            |
//+------------------------------------------------------------------+
double APEX_ER(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    double c[];
    ArraySetAsSeries(c, true);
    if(CopyClose(sym, tf, 1, periode + 1, c) < periode + 1)
        return 0.5;
    
    double signal = MathAbs(c[0] - c[periode]);
    double noise  = 0.0;
    for(int i = 0; i < periode; i++)
        noise += MathAbs(c[i] - c[i + 1]);
    
    return (noise > 0.0) ? signal / noise : 0.0;
}

//+------------------------------------------------------------------+
//| RATE OF CHANGE: Prozentuale Preisveraenderung                      |
//+------------------------------------------------------------------+
double APEX_ROC(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    double c[];
    ArraySetAsSeries(c, true);
    if(CopyClose(sym, tf, 1, periode + 1, c) < periode + 1)
        return 0.0;
    if(c[periode] <= 0.0) return 0.0;
    return ((c[0] - c[periode]) / c[periode]) * 100.0;
}

//+------------------------------------------------------------------+
//| ATR: Durchschnittliche Schwankungsbreite (Wilder-Glaettung)        |
//+------------------------------------------------------------------+
double APEX_ATR(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    int ben = periode + 50;
    double h[], l[], c[];
    ArraySetAsSeries(h, true);
    ArraySetAsSeries(l, true);
    ArraySetAsSeries(c, true);
    
    if(CopyHigh(sym, tf, 1, ben, h)  < ben) return 0.0;
    if(CopyLow(sym, tf, 1, ben, l)   < ben) return 0.0;
    if(CopyClose(sym, tf, 1, ben, c) < ben) return 0.0;
    
    double tr[];
    ArrayResize(tr, ben);
    tr[ben - 1] = h[ben - 1] - l[ben - 1];
    
    for(int i = ben - 2; i >= 0; i--)
    {
        double hl = h[i] - l[i];
        double hc = MathAbs(h[i] - c[i + 1]);
        double lc = MathAbs(l[i] - c[i + 1]);
        tr[i] = MathMax(hl, MathMax(hc, lc));
    }
    
    double atr = 0.0;
    int sp = ben - periode;
    for(int i = ben - 1; i >= sp; i--)
        atr += tr[i];
    atr /= (double)periode;
    
    for(int i = sp - 1; i >= 0; i--)
        atr = (atr * (double)(periode - 1) + tr[i]) / (double)periode;
    
    return atr;
}

//+------------------------------------------------------------------+
//| ATR-ARRAY: Gibt mehrere ATR-Werte zurueck (fuer Supertrend)        |
//+------------------------------------------------------------------+
bool APEX_ATR_Array(const string sym, const ENUM_TIMEFRAMES tf,
                    const int periode, double &out[], const int anz)
{
    int ben = anz + periode + 50;
    double h[], l[], c[];
    ArraySetAsSeries(h, true);
    ArraySetAsSeries(l, true);
    ArraySetAsSeries(c, true);
    
    if(CopyHigh(sym, tf, 1, ben, h)  < ben) return false;
    if(CopyLow(sym, tf, 1, ben, l)   < ben) return false;
    if(CopyClose(sym, tf, 1, ben, c) < ben) return false;
    
    double tr[];
    ArrayResize(tr, ben);
    tr[ben - 1] = h[ben - 1] - l[ben - 1];
    for(int i = ben - 2; i >= 0; i--)
    {
        double hl = h[i] - l[i];
        double hc = MathAbs(h[i] - c[i + 1]);
        double lc = MathAbs(l[i] - c[i + 1]);
        tr[i] = MathMax(hl, MathMax(hc, lc));
    }
    
    ArrayResize(out, anz);
    ArraySetAsSeries(out, true);
    
    double atr = 0.0;
    int sp = ben - periode;
    for(int i = ben - 1; i >= sp; i--)
        atr += tr[i];
    atr /= (double)periode;
    
    int idx = anz - 1;
    for(int i = sp - 1; i >= 0; i--)
    {
        atr = (atr * (double)(periode - 1) + tr[i]) / (double)periode;
        if(idx >= 0 && idx < anz)
        {
            out[idx] = atr;
            idx--;
        }
    }
    return true;
}

//+------------------------------------------------------------------+
//| ADX: Average Directional Index – Trendstaerke 0-100                |
//+------------------------------------------------------------------+
double APEX_ADX(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    int ben = periode * 3 + 50;
    double h[], l[], c[];
    ArraySetAsSeries(h, true);
    ArraySetAsSeries(l, true);
    ArraySetAsSeries(c, true);
    
    if(CopyHigh(sym, tf, 1, ben, h)  < ben) return 0.0;
    if(CopyLow(sym, tf, 1, ben, l)   < ben) return 0.0;
    if(CopyClose(sym, tf, 1, ben, c) < ben) return 0.0;
    
    double pdm[], mdm[], trr[];
    ArrayResize(pdm, ben);
    ArrayResize(mdm, ben);
    ArrayResize(trr, ben);
    
    pdm[ben - 1] = 0.0;
    mdm[ben - 1] = 0.0;
    trr[ben - 1] = h[ben - 1] - l[ben - 1];
    
    for(int i = ben - 2; i >= 0; i--)
    {
        double up = h[i] - h[i + 1];
        double dn = l[i + 1] - l[i];
        pdm[i] = (up > dn && up > 0.0) ? up : 0.0;
        mdm[i] = (dn > up && dn > 0.0) ? dn : 0.0;
        double hl = h[i] - l[i];
        double hc = MathAbs(h[i] - c[i + 1]);
        double lc = MathAbs(l[i] - c[i + 1]);
        trr[i] = MathMax(hl, MathMax(hc, lc));
    }
    
    double g_pdm = 0.0, g_mdm = 0.0, g_tr = 0.0;
    int sp = ben - periode;
    for(int i = ben - 1; i >= sp; i--)
    {
        g_pdm += pdm[i];
        g_mdm += mdm[i];
        g_tr  += trr[i];
    }
    
    double adx = 0.0;
    bool init = false;
    int cnt = 0;
    double dxs = 0.0;
    
    for(int i = sp - 1; i >= 0; i--)
    {
        g_pdm = g_pdm - g_pdm / (double)periode + pdm[i];
        g_mdm = g_mdm - g_mdm / (double)periode + mdm[i];
        g_tr  = g_tr  - g_tr  / (double)periode + trr[i];
        if(g_tr <= 0.0) continue;
        
        double pdi = (g_pdm / g_tr) * 100.0;
        double mdi = (g_mdm / g_tr) * 100.0;
        double dis = pdi + mdi;
        double dx  = (dis > 0.0) ? (MathAbs(pdi - mdi) / dis) * 100.0 : 0.0;
        
        if(!init)
        {
            dxs += dx;
            cnt++;
            if(cnt >= periode) { adx = dxs / (double)periode; init = true; }
        }
        else
        {
            adx = (adx * (double)(periode - 1) + dx) / (double)periode;
        }
    }
    return adx;
}

//+------------------------------------------------------------------+
//| NATR: Normalisierte ATR in Prozent                                 |
//+------------------------------------------------------------------+
double APEX_NATR(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    double atr = APEX_ATR(sym, tf, periode);
    double c[];
    ArraySetAsSeries(c, true);
    if(CopyClose(sym, tf, 1, 1, c) < 1) return 0.0;
    return (c[0] > 0.0) ? (atr / c[0]) * 100.0 : 0.0;
}

//+------------------------------------------------------------------+
//| RVOL: Relatives Volumen (1.0 = Durchschnitt)                       |
//+------------------------------------------------------------------+
double APEX_RVOL(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    long v[];
    ArraySetAsSeries(v, true);
    if(CopyTickVolume(sym, tf, 1, periode, v) < periode) return 1.0;
    
    double sum = 0.0;
    for(int i = 1; i < periode; i++) sum += (double)v[i];
    double avg = sum / (double)(periode - 1);
    return (avg > 0.0) ? (double)v[0] / avg : 1.0;
}

//+------------------------------------------------------------------+
//| Volatilitaets-Perzentil (0-100)                                    |
//+------------------------------------------------------------------+
double APEX_VolPercentile(const string sym, const ENUM_TIMEFRAMES tf, const int periode)
{
    double h[], l[], c[];
    ArraySetAsSeries(h, true);
    ArraySetAsSeries(l, true);
    ArraySetAsSeries(c, true);
    
    if(CopyHigh(sym, tf, 1, periode + 1, h)  < periode + 1) return 50.0;
    if(CopyLow(sym, tf, 1, periode + 1, l)   < periode + 1) return 50.0;
    if(CopyClose(sym, tf, 1, periode + 1, c) < periode + 1) return 50.0;
    
    double tr[];
    ArrayResize(tr, periode);
    for(int i = 0; i < periode; i++)
    {
        double hl = h[i] - l[i];
        double hc = MathAbs(h[i] - c[i + 1]);
        double lc = MathAbs(l[i] - c[i + 1]);
        tr[i] = MathMax(hl, MathMax(hc, lc));
    }
    
    double akt = tr[0];
    int kleiner = 0;
    for(int i = 1; i < periode; i++)
        if(tr[i] <= akt) kleiner++;
    
    return ((double)kleiner / (double)(periode - 1)) * 100.0;
}

//+------------------------------------------------------------------+
//| REGIME-KLASSIFIKATION                                              |
//+------------------------------------------------------------------+
ENUM_APEX_REGIME APEX_ClassifyRegime(const double er, const double htf_zscore)
{
    if(er > InpER_Trend)
        return (htf_zscore > 0.0) ? REG_TREND_UP : REG_TREND_DOWN;
    if(er < InpER_Range)
        return REG_RANGE;
    return REG_UNDEF;
}

//+------------------------------------------------------------------+
//| SPREAD-FILTER (3 Pruefungen)                                       |
//+------------------------------------------------------------------+
bool APEX_SpreadOK(const string sym, const double sl_abstand, const double max_pct)
{
    double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
    double bid = SymbolInfoDouble(sym, SYMBOL_BID);
    double spread = ask - bid;
    if(spread <= 0.0) return true;
    
    double atr = APEX_ATR(sym, InpTF_Entry, 14);
    if(atr > 0.0 && spread > atr * 0.5)
    {
        PrintFormat("APEX Spread: %s