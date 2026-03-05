//+------------------------------------------------------------------+
//| APEXUtils.mqh                                                      |
//| Version:  6.3                                                      |
//| Datum:    2026.03.05                                               |
//|                                                                    |
//| Inhalt:   Zeitfilter, Session-Erkennung, Asset-Klassen.            |
//+------------------------------------------------------------------+
#ifndef APEX_UTILS_MQH
#define APEX_UTILS_MQH

#include "APEXDefinitions.mqh"

ENUM_ASSET_CLASS APEX_GetAssetClass(const string sym)
{
    if(StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0 ||
       StringFind(sym, "SOL") >= 0 || StringFind(sym, "XRP") >= 0 ||
       StringFind(sym, "ADA") >= 0 || StringFind(sym, "DOGE") >= 0 ||
       StringFind(sym, "LTC") >= 0 || StringFind(sym, "BNB") >= 0 ||
       StringFind(sym, "AVAX") >= 0)
        return ASSET_CRYPTO;
    
    if(StringFind(sym, "US500") >= 0 || StringFind(sym, "US30") >= 0 ||
       StringFind(sym, "US100") >= 0 || StringFind(sym, "NAS") >= 0 ||
       StringFind(sym, "DE40") >= 0 || StringFind(sym, "DAX") >= 0 ||
       StringFind(sym, "UK100") >= 0 || StringFind(sym, "JP225") >= 0 ||
       StringFind(sym, "SPX") >= 0)
        return ASSET_INDEX;
    
    if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "XAG") >= 0 ||
       StringFind(sym, "OIL") >= 0 || StringFind(sym, "WTI") >= 0 ||
       StringFind(sym, "BRENT") >= 0 || StringFind(sym, "NGAS") >= 0)
        return ASSET_COMMODITY;
    
    return ASSET_FOREX;
}

bool APEX_TimeOK_ForAsset(const string sym)
{
    datetime dz = TimeCurrent() + (InpGermanUTC - InpBrokerUTC) * 3600;
    MqlDateTime dt;
    TimeToStruct(dz, dt);
    
    ENUM_ASSET_CLASS k = APEX_GetAssetClass(sym);
    
    if(k == ASSET_CRYPTO)
    {
        if(!InpCryptoEnabled) return false;
        if(dt.day_of_week == 0 || dt.day_of_week == 6) return InpCryptoWeekend;
        if(dt.hour >= InpForexStartH && dt.hour < InpForexEndH) return true;
        if(InpCryptoStartH > InpCryptoEndH)
        {
            if(dt.hour >= InpCryptoStartH || dt.hour < InpCryptoEndH) return true;
        }
        else
        {
            if(dt.hour >= InpCryptoStartH && dt.hour < InpCryptoEndH) return true;
        }
        return false;
    }
    
    if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
    if(dt.day_of_week == 5 && dt.hour >= InpFridayEndH) return false;
    if(dt.hour >= InpForexStartH && dt.hour < InpForexEndH) return true;
    if(dt.hour >= InpForexExtStartH && dt.hour < InpForexExtEndH) return true;
    return false;
}

int APEX_FindSymbolIndex(const SymbolState &syms[], const int anz, const string name)
{
    for(int i = 0; i < anz; i++)
        if(syms[i].name == name) return i;
    return -1;
}

#endif