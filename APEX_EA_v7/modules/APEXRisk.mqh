//+------------------------------------------------------------------+
//| APEXRisk.mqh                                                       |
//| Version:  7.2                                                      |
//| Datum:    2026.03.05                                               |
//|                                                                    |
//| Inhalt:   Positionsgroesse (MT5 und TradingView),                  |
//|           Drawdown-Ueberwachung, Trade-Ausfuehrung.                |
//+------------------------------------------------------------------+
#ifndef APEX_RISK_MQH
#define APEX_RISK_MQH

#include "APEXDefinitions.mqh"

//+------------------------------------------------------------------+
//| MT5 POSITIONSGROESSE (exakt vom Broker)                            |
//+------------------------------------------------------------------+
double APEX_CalcLots(const string sym, const double sl_ab, const double konto)
{
    // RISIKO-ANPASSUNG: Nutzt InpRiskPct, z.B. 0.15% fuer Prop-Konten
    double risiko = konto * (InpRiskPct / 100.0);
    double tg = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
    double tw = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
    if(tg <= 0.0 || tw <= 0.0 || sl_ab <= 0.0) return 0.0;
    
    double rpl = (sl_ab / tg) * tw;
    if(rpl <= 0.0) return 0.0;
    
    double lots = risiko / rpl;
    double mn = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
    double mx = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
    double st = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
    if(st <= 0.0) return 0.0;
    
    lots = MathFloor(lots / st) * st;
    lots = MathMax(mn, MathMin(mx, lots));
    return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| TRADINGVIEW POSITIONSGROESSE berechnen                              |
//+------------------------------------------------------------------+
void APEX_CalcTV_Position(const string sym, const double sl_ab,
                          const ENUM_ASSET_CLASS klasse, TV_Position &tv)
{
    tv.valid       = false;
    tv.lots        = 0.0;
    tv.mini_lots   = 0.0;
    tv.micro_lots  = 0.0;
    tv.einheiten   = 0.0;
    tv.risiko_usd  = InpTV_Capital * (InpRiskPct / 100.0);
    tv.einheit_name = "";
    tv.groessen_text = "";
    
    if(sl_ab <= 0.0 || tv.risiko_usd <= 0.0) return;
    
    int dig = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
    
    // === FOREX ===
    if(klasse == ASSET_FOREX)
    {
        double pip_sz, pip_val;
        if(dig == 3)
        {
            // JPY-Paare (3 Dezimalstellen)
            pip_sz = 0.01;
            double kurs = SymbolInfoDouble(sym, SYMBOL_BID);
            pip_val = (kurs > 0.0) ? (100000.0 * 0.01 / kurs) : 6.50;
        }
        else
        {
            // Standard 5-Steller und 4-Steller
            pip_sz = (dig == 5) ? 0.0001 : 0.0001;
            pip_val = 10.0;
        }
        
        double sl_pips = sl_ab / pip_sz;
        double vpl = sl_pips * pip_val;
        
        tv.lots = (vpl > 0.0) ? tv.risiko_usd / vpl : 0.0;
        tv.lots = MathFloor(tv.lots * 100.0) / 100.0;
        tv.mini_lots  = tv.lots * 10.0;
        tv.micro_lots = tv.lots * 100.0;
        tv.einheiten  = tv.lots * 100000.0;
        tv.einheit_name = "Lots";
        tv.groessen_text = StringFormat("%.2f Lots (%.1f Mini | %.0f Micro)",
                                        tv.lots, tv.mini_lots, tv.micro_lots);
    }
    // === ROHSTOFFE ===
    else if(klasse == ASSET_COMMODITY)
    {
        double dpe = 100.0;
        string einh = "Unzen";
        
        if(StringFind(sym, "XAU") >= 0)       { dpe = 100.0;  einh = "Unzen (100/Lot)"; }
        else if(StringFind(sym, "XAG") >= 0)  { dpe = 5000.0; einh = "Unzen (5000/Lot)"; }
        else if(StringFind(sym, "OIL") >= 0 || StringFind(sym, "WTI") >= 0 ||
                StringFind(sym, "BRENT") >= 0){ dpe = 1000.0; einh = "Barrel (1000/Lot)"; }
        
        double vpl = sl_ab * dpe;
        tv.lots = (vpl > 0.0) ? tv.risiko_usd / vpl : 0.0;
        tv.lots = MathFloor(tv.lots * 100.0) / 100.0;
        tv.einheiten = tv.lots * dpe;
        tv.einheit_name = einh;
        tv.groessen_text = StringFormat("%.2f Lots (%.1f %s)", tv.lots, tv.einheiten, einh);
    }
    // === INDIZES ===
    else if(klasse == ASSET_INDEX)
    {
        double dpp = 1.0;
        double vpl = sl_ab * dpp;
        tv.lots = (vpl > 0.0) ? tv.risiko_usd / vpl : 0.0;
        tv.lots = MathFloor(tv.lots * 10.0) / 10.0;
        tv.einheiten = tv.lots;
        tv.einheit_name = "Kontrakte";
        tv.groessen_text = StringFormat("%.1f Kontrakte (Kontraktgroesse broker-spezifisch!)", tv.lots);
    }
    // === KRYPTO ===
    else if(klasse == ASSET_CRYPTO)
    {
        tv.lots = (sl_ab > 0.0) ? tv.risiko_usd / sl_ab : 0.0;
        tv.lots = MathFloor(tv.lots * 10000.0) / 10000.0;
        tv.einheiten = tv.lots;
        tv.einheit_name = "Coins";
        tv.groessen_text = StringFormat("%.4f Coins ($%.2f Risiko)", tv.lots, tv.risiko_usd);
    }
    
    tv.valid = (tv.lots > 0.0);
}

//+------------------------------------------------------------------+
//| DRAWDOWN PRUEFEN                                                   |
//+------------------------------------------------------------------+
bool APEX_DrawdownHit(const double eq, double &peak)
{
    double bal = AccountInfoDouble(ACCOUNT_BALANCE);
    if(bal > peak) peak = bal;
    if(peak <= 0.0) return false;
    double dd = ((peak - eq) / peak) * 100.0;
    if(dd >= InpMaxDD)
    {
        PrintFormat("APEX STOPP: DD %.2f%% >= %.2f%%!", dd, InpMaxDD);
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| TRADE AUSFUEHREN                                                   |
//+------------------------------------------------------------------+
bool APEX_ExecuteTrade(CTrade &trade, const SignalData &sig)
{
    string com = StringFormat("APEX|%s|%.1f|%s", sig.grade, sig.composite, sig.pattern);
    if(sig.direction == SIG_BUY)
        return trade.Buy(sig.lots_mt5, sig.symbol, sig.entry, sig.sl, 0.0, com);
    else if(sig.direction == SIG_SELL)
        return trade.Sell(sig.lots_mt5, sig.symbol, sig.entry, sig.sl, 0.0, com);
    return false;
}

//+------------------------------------------------------------------+
//| OFFENE POSITION PRUEFEN                                            |
//+------------------------------------------------------------------+
bool APEX_HasPosition(const string sym, const int magic)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong t = PositionGetTicket(i);
        if(t == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) == sym &&
           PositionGetInteger(POSITION_MAGIC) == magic)
            return true;
    }
    return false;
}

#endif