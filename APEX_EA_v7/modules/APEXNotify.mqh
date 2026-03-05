//+------------------------------------------------------------------+
//| APEXNotify.mqh                                                     |
//| Version:  7.2                                                      |
//| Datum:    2026.03.05                                               |
//|                                                                    |
//| Inhalt:   Email/Push mit allen 7 Dimensionen, AOI-Info,            |
//|           TV-Positionsgroesse und TV-Supertrend-Einstellungen.     |
//+------------------------------------------------------------------+
#ifndef APEX_NOTIFY_MQH
#define APEX_NOTIFY_MQH

#include "APEXDefinitions.mqh"

string APEX_ScoreBar(const double score)
{
    int f = (int)MathRound(MathMax(0.0, MathMin(10.0, score)));
    string b = "[";
    for(int i = 0; i < 10; i++) b += (i < f) ? "#" : ".";
    b += "]";
    return b;
}

string APEX_RegimeText(const ENUM_APEX_REGIME r)
{
    switch(r)
    {
        case REG_RANGE:      return "SEITWAERTS (Mean Reversion)";
        case REG_TREND_UP:   return "AUFWAERTSTREND (Pullback)";
        case REG_TREND_DOWN: return "ABWAERTSTREND (Pullback)";
        default:             return "UNKLAR";
    }
}

string APEX_AssetText(const ENUM_ASSET_CLASS k)
{
    switch(k)
    {
        case ASSET_FOREX:     return "Forex";
        case ASSET_INDEX:     return "Index";
        case ASSET_COMMODITY: return "Rohstoff";
        case ASSET_CRYPTO:    return "Krypto";
        default:              return "Unbekannt";
    }
}

double APEX_CalcSLPips(const string sym, const double sl_d, const ENUM_ASSET_CLASS k)
{
    double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
    if(pt <= 0.0) return 0.0;
    int dig = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
    if(k == ASSET_CRYPTO) return sl_d;
    if(dig == 5 || dig == 3) return sl_d / (pt * 10.0);
    return sl_d / pt;
}

//+------------------------------------------------------------------+
//| VOLLSTAENDIGE EMAIL                                                |
//+------------------------------------------------------------------+
void APEX_SendEmail(const SignalData &sig)
{
    string dir = (sig.direction == SIG_BUY) ? "LONG" : "SHORT";
    int    dig = (int)SymbolInfoInteger(sig.symbol, SYMBOL_DIGITS);
    datetime dt_de = TimeCurrent() + (InpGermanUTC - InpBrokerUTC) * 3600;
    double sl_d = MathAbs(sig.entry - sig.sl);
    double sl_p = APEX_CalcSLPips(sig.symbol, sl_d, sig.asset_class);
    double tv_r = InpTV_Capital * (InpRiskPct / 100.0);
    
    // Betreffzeile
    string subj = StringFormat("[%s %.1f] %s %s | CRV %.1f | %s%s",
                               sig.grade, sig.composite, sig.symbol, dir,
                               sig.actual_rrr, sig.pattern,
                               sig.aoi.cluster ? " [AOI-CLUSTER]" : "");
    
    string b = "";
    
    // Kopfzeile
    if(sig.composite >= 8.0)       b += "=== A+ ELITE SIGNAL ===\n\n";
    else if(sig.composite >= 6.5)  b += "=== A PREMIUM SIGNAL ===\n\n";
    else                           b += "=== B INFO (nur beobachten) ===\n\n";
    
    // Grundinfo
    b += StringFormat("Symbol:        %s (%s)\n", sig.symbol, APEX_AssetText(sig.asset_class));
    b += StringFormat("Richtung:      %s\n", dir);
    b += StringFormat("Muster:        %s\n", sig.pattern);
    b += StringFormat("Marktphase:    %s\n", APEX_RegimeText(sig.regime));
    b += StringFormat("Supertrend:    %s (Mult %.1f, ATR %d)\n",
                      InpST_Adaptive ? "ADAPTIV" : "STANDARD", sig.st_mult, InpST_ATR_Period);
    b += StringFormat("Zeit (DE):     %s\n\n", TimeToString(dt_de));
    
    // === TV-HANDELSANWEISUNG ===
    b += "+-----------------------------------------+\n";
    b += "|    TRADINGVIEW - HANDELSANWEISUNG       |\n";
    b += "+-----------------------------------------+\n\n";
    
    b += StringFormat("TV-Kontostand:   $%.0f\n", InpTV_Capital);
    b += StringFormat("Risiko (%.2f%%):   $%.2f\n\n", InpRiskPct, tv_r);
    
    b += "  TRADE EINGEBEN:\n";
    b += StringFormat("  Richtung:      %s\n", dir);
    b += StringFormat("  Einstieg:      %s\n", DoubleToString(sig.entry, dig));
    b += StringFormat("  Stop-Loss:     %s (Supertrend)\n", DoubleToString(sig.sl, dig));
    b += StringFormat("  Take-Profit:   %s (indikativ)\n\n", DoubleToString(sig.tp_ind, dig));
    
    b += "  STOP-LOSS DETAILS:\n";
    b += StringFormat("  SL-Abstand:    %s", DoubleToString(sl_d, dig));
    if(sig.asset_class != ASSET_CRYPTO)
        b += StringFormat(" (%.1f Pips)", sl_p);
    else
        b += StringFormat(" ($%.2f)", sl_d);
    b += "\n";
    b += StringFormat("  Spread:        %.1f%% des SL\n\n", sig.spread_pct);
    
    // TV-Supertrend Einstellungen (damit der Nutzer den gleichen ST in TV einstellen kann)
    b += "  SUPERTREND IN TV EINSTELLEN:\n";
    b += StringFormat("  Zeitrahmen:    %s\n", EnumToString(InpTF_Entry));
    b += StringFormat("  ATR-Periode:   %d\n", InpST_ATR_Period);
    b += StringFormat("  Multiplikator: %.1f\n", InpST_Mult_Base);
    b += "  → TV Indikator: 'Supertrend' (Standard)\n\n";
    
    // TV-Positionsgroesse
    if(sig.tv_pos.valid)
    {
        b += "  POSITIONSGROESSE FUER TV:\n";
        b += StringFormat("  >>> %s <<<\n", sig.tv_pos.groessen_text);
        b += StringFormat("  Risiko:        $%.2f\n\n", sig.tv_pos.risiko_usd);
        
        b += "  BEI ANDEREM KONTOSTAND:\n";
        double stufen[] = {30000, 40000, 50000, 60000, 75000, 100000};
        for(int t = 0; t < ArraySize(stufen); t++)
        {
            double r = stufen[t] * (InpRiskPct / 100.0);
            b += StringFormat("  $%.0f -> $%.2f Risiko", stufen[t], r);
            if(sig.tv_pos.risiko_usd > 0.0)
            {
                double fak = r / sig.tv_pos.risiko_usd;
                b += StringFormat(" -> ~%.2f %s", sig.tv_pos.lots * fak, sig.tv_pos.einheit_name);
            }
            b += "\n";
        }
        b += "\n";
    }
    
    // === AOI ===
    if(sig.aoi.valid && sig.aoi.anzahl > 0)
    {
        b += "--- AREAS OF INTEREST ---\n";
        if(sig.aoi.in_zone)
        {
            b += StringFormat(">>> PREIS IN AOI-ZONE! (%d Level nah) <<<\n", sig.aoi.nahe_level);
            if(sig.aoi.cluster) b += ">>> CLUSTER ERKANNT <<<\n";
        }
        b += StringFormat("Naechstes:     %s bei %s (%.2f%%)\n",
                          sig.aoi.naechster_name,
                          DoubleToString(sig.aoi.naechstes, dig),
                          sig.aoi.abstand_pct);
        
        double zone = sig.entry * (InpAOI_ZoneWidth / 100.0);
        for(int i = 0; i < sig.aoi.anzahl; i++)
        {
            double ad = MathAbs(sig.entry - sig.aoi.levels[i].preis);
            if(ad <= zone * 3.0)
            {
                string mk = (ad <= zone) ? " <<<" : "";
                b += StringFormat("  [%s] %s: %s%s\n",
                                  sig.aoi.levels[i].typ, sig.aoi.levels[i].name,
                                  DoubleToString(sig.aoi.levels[i].preis, dig), mk);
            }
        }
        b += "\n";
    }
    
    // === RANGE ===
    if(sig.range.valid)
    {
        b += "--- RANGE-ANALYSE ---\n";
        b += StringFormat("Obere:  %s (P%.0f)  Untere: %s (P%.0f)\n",
                          DoubleToString(sig.range.upper, dig), InpRange_UpperPct,
                          DoubleToString(sig.range.lower, dig), InpRange_LowerPct);
        b += StringFormat("Position: %.1f%%", sig.range.position);
        if(sig.range.at_lower) b += " [UNTERER RAND]";
        else if(sig.range.at_upper) b += " [OBERER RAND]";
        b += "\n\n";
    }
    
    // === SCORECARD ===
    b += StringFormat("=== APEX SCORE: %.2f / 10.00  [%s] ===\n\n", sig.composite, sig.grade);
    b += StringFormat("PREIS    %s %.1f (%.0f%%) Z=%.2f ROC=%.1f%%\n",
                      APEX_ScoreBar(sig.sub_price), sig.sub_price, InpW_Price*100, sig.zscore, sig.roc);
    b += StringFormat("TRIGGER  %s %.1f (%.0f%%) %s\n",
                      APEX_ScoreBar(sig.sub_trigger), sig.sub_trigger, InpW_Trigger*100, sig.pattern);
    b += StringFormat("REGIME   %s %.1f (%.0f%%) ER=%.2f ADX=%.0f\n",
                      APEX_ScoreBar(sig.sub_regime), sig.sub_regime, InpW_Regime*100, sig.er_regime, sig.adx);
    b += StringFormat("RANGE    %s %.1f (%.0f%%) Pos=%.0f%%\n",
                      APEX_ScoreBar(sig.sub_range), sig.sub_range, InpW_Range*100, sig.range.position);
    b += StringFormat("AOI      %s %.1f (%.0f%%) %s%s\n",
                      APEX_ScoreBar(sig.sub_aoi), sig.sub_aoi, InpW_AOI*100,
                      sig.aoi.in_zone ? "IN ZONE" : "aussen",
                      sig.aoi.cluster ? " [CLUSTER]" : "");
    b += StringFormat("VOLUMEN  %s %.1f (%.0f%%) RVOL=%.2f\n",
                      APEX_ScoreBar(sig.sub_volume), sig.sub_volume, InpW_Volume*100, sig.rvol);
    b += StringFormat("KONTEXT  %s %.1f (%.0f%%) VP=%.0f%% MTF=%s\n\n",
                      APEX_ScoreBar(sig.sub_context), sig.sub_context, InpW_Context*100,
                      sig.vol_pctile, sig.mtf_aligned ? "JA" : "NEIN");
    b += StringFormat("GESAMT   %s %.2f\n\n", APEX_ScoreBar(sig.composite), sig.composite);
    
    // Handlungsanweisung
    if(sig.composite >= InpMinComposite_Trade)
    {
        b += ">>> HANDELN <<<\n";
        b += "1. Trade in TV eingeben (siehe oben)\n";
        b += "2. In TV den Supertrend-Indikator aktivieren\n";
        b += StringFormat("   (ATR %d, Mult %.1f, Zeitrahmen %s)\n",
                          InpST_ATR_Period, InpST_Mult_Base, EnumToString(InpTF_Entry));
        b += "3. SL alle 4h auf den Supertrend-Wert nachziehen\n";
    }
    else
        b += ">>> NUR BEOBACHTEN <<<\n";
    
    if(!SendMail(subj, b))
        PrintFormat("APEX: Email fehlgeschlagen fuer %s", sig.symbol);
}

void APEX_SendPush(const SignalData &sig)
{
    int d = (int)SymbolInfoInteger(sig.symbol, SYMBOL_DIGITS);
    string m = StringFormat("[%s%.1f] %s %s @%s SL:%s CRV:%.1f $%.2f %s%s",
                            sig.grade, sig.composite, sig.symbol,
                            sig.direction == SIG_BUY ? "BUY" : "SELL",
                            DoubleToString(sig.entry, d), DoubleToString(sig.sl, d),
                            sig.actual_rrr, InpTV_Capital * (InpRiskPct / 100.0),
                            sig.pattern, sig.aoi.cluster ? " [AOI]" : "");
    if(!SendNotification(m))
        PrintFormat("APEX: Push fehlgeschlagen fuer %s", sig.symbol);
}

#endif