// ============================================================================
//  Datei:       MTAS_Email_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Beschreibung: Email-Benachrichtigungen (Signal, Close, Reminder)
// ============================================================================

#ifndef __MTAS_EMAIL_V1_1_MQH
#define __MTAS_EMAIL_V1_1_MQH

bool SendSignalEmail(const string symbol, const string direction, double score, double entry, double sl, double tp, double lots, double acc, int open_trades)
{
    string subject = StringFormat("📊 MATS SIGNAL: %s %s (Score %.2f)", symbol, direction, score);

    string body = StringFormat(
        "============================\n"
        "Signal %s %s\n"
        "Score:      %.2f\n"
        "Entry:      %.5f\n"
        "Stop-Loss:  %.5f\n"
        "TakeProfit: %.5f\n"
        "Lots:       %.2f\n"
        "Balance:    %.2f\n"
        "Open Trades:%d\n"
        "============================\n"
        "Stand: %s\n",
        symbol, direction, score, entry, sl, tp, lots, acc, open_trades, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
    );
    return SendMail(subject, body);
}

bool SendCloseEmail(const string symbol, double result, double pct, string reason)
{
    string subject = StringFormat("✅ MATS CLOSE: %s %.2fpips (%.2f%%) %s", symbol, result, pct, reason);
    string body = StringFormat(
        "Trade closed on %s\n"
        "Result: %.2fpips (%.2f%%)\n"
        "Reason: %s\n",
        symbol, result, pct, reason
    );
    return SendMail(subject, body);
}

bool SendErrorEmail(const string message)
{
    string subject = "⚠️ MATS ERROR: Attention required!";
    return SendMail(subject, message);
}

#endif // __MTAS_EMAIL_V1_1_MQH