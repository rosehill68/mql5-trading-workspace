// ============================================================================
//  Datei:       MTAS_Email.mqh
//  Projekt:     MTAS v2.0
//  Version:     2.0
//  Erstellt:    2026-04-19
//  Beschreibung:
//    Email-Benachrichtigungsmodul.
//    Sendet formatierte Emails fuer: Signal, Trade-Closed, Fehler.
//    Wrapper um MQL5 SendMail(). Gibt Fehler als false zurueck.
//
//  Abhaengigkeiten: MTAS_DataModel.mqh, MTAS_Logger.mqh
// ============================================================================
#ifndef __MTAS_EMAIL_MQH
#define __MTAS_EMAIL_MQH

#include "MTAS_DataModel.mqh"
#include "MTAS_Logger.mqh"

// ============================================================================
//  SendTradeOpenEmail – Email nach Trade-Eroeffnung
// ============================================================================
bool SendTradeOpenEmail(const TradePlan &plan, const ulong ticket, const double balance)
{
    string dir_str = (plan.direction == DIR_LONG) ? "LONG" : "SHORT";
    string subject = StringFormat("MTAS Signal: %s %s (RR=%.2f)", plan.symbol, dir_str, plan.rr_ratio);
    string body = StringFormat(
        "=== MTAS v2.0 Trade eroeffnet ===\n"
        "Symbol:      %s\n"
        "Richtung:    %s\n"
        "Lots:        %.2f\n"
        "Entry:       Market\n"
        "Stop-Loss:   %.5f\n"
        "Take-Profit: %.5f\n"
        "Risiko:      %.2f%%\n"
        "RR:          %.2f\n"
        "Score:       %s\n"
        "Ticket:      %I64u\n"
        "Balance:     %.2f\n"
        "Zeit:        %s\n",
        plan.symbol, dir_str, plan.lots,
        plan.stop_loss, plan.take_profit,
        plan.risk_pct, plan.rr_ratio,
        plan.comment, ticket, balance,
        TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));

    bool ok = SendMail(subject, body);
    if(!ok) MTAS_LogWarn("Email-Versand fehlgeschlagen (TradeOpen)");
    return ok;
}

// ============================================================================
//  SendTradeCloseEmail – Email nach Trade-Schliessen
// ============================================================================
bool SendTradeCloseEmail(const string symbol, const double profit,
                          const double pct, const string reason, const ulong ticket)
{
    string subject = StringFormat("MTAS Close: %s %.2f (%.2f%%) %s", symbol, profit, pct, reason);
    string body = StringFormat(
        "=== MTAS v2.0 Trade geschlossen ===\n"
        "Symbol:  %s\n"
        "Ergebnis: %.2f (%.2f%%)\n"
        "Grund:   %s\n"
        "Ticket:  %I64u\n"
        "Zeit:    %s\n",
        symbol, profit, pct, reason, ticket,
        TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));

    bool ok = SendMail(subject, body);
    if(!ok) MTAS_LogWarn("Email-Versand fehlgeschlagen (TradeClose)");
    return ok;
}

// ============================================================================
//  SendErrorEmail – Email bei kritischem Fehler
// ============================================================================
bool SendErrorEmail(const string context, const string msg)
{
    string subject = StringFormat("MTAS FEHLER: %s", context);
    string body = StringFormat(
        "=== MTAS v2.0 Fehlermeldung ===\n"
        "Kontext: %s\n"
        "Fehler:  %s\n"
        "Zeit:    %s\n",
        context, msg, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));

    bool ok = SendMail(subject, body);
    if(!ok) MTAS_LogWarn("Email-Versand fehlgeschlagen (Error)");
    return ok;
}

#endif // __MTAS_EMAIL_MQH
