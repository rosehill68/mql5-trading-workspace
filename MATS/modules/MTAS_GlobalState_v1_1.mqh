// ============================================================================
//  Datei:       MTAS_GlobalState_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Beschreibung: Zentrale EA-Variablenstruktur (Feld, Status etc.)
// ============================================================================

#ifndef __MTAS_GLOBALSTATE_V1_1_MQH
#define __MTAS_GLOBALSTATE_V1_1_MQH

struct MTAS_AssetState {
    string symbol;
    double lsma_htf, slope_htf, slope_htf_z;
    double bbw_htf, bbw_htf_z;
    double lsma_ltf, atr_ltf, rsi_ltf;
    long   direction; // 1 = Long, -1 = Short, 0 = Flat
    double entry_score;
    double ratchet_sl;
    int    open_trade; // 0/1 Flag
    ulong  trade_ticket;
};

#endif // __MTAS_GLOBALSTATE_V1_1_MQH