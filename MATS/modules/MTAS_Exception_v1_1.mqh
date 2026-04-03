// ============================================================================
//  Datei:       MTAS_Exception_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Beschreibung: Exception-Type und zentraler Error-Handler/Recovery
// ============================================================================
#ifndef __MTAS_EXCEPTION_V1_1_MQH
#define __MTAS_EXCEPTION_V1_1_MQH

#include <modules/MTAS_Logger_v1_1.mqh>
#include <modules/MTAS_Email_v1_1.mqh>

enum MTAS_ExceptionType { EXC_CRITICAL, EXC_WARNING, EXC_RECOVERABLE };

// Exception-Hilfsstruktur
struct MTAS_Exception {
    MTAS_ExceptionType type;
    string             msg;
    string             context;
    datetime           raised;
};

// Exception Handler: Logging, Email, ggf. Recovery
void MTAS_HandleException(const MTAS_Exception &exc)
{
    string tag = (exc.type == EXC_CRITICAL) ? "[CRITICAL]" : (exc.type == EXC_WARNING) ? "[WARNING]" : "[RECOVERABLE]";
    string fullmsg = StringFormat("%s %s (at %s): %s", tag, exc.context, TimeToString(exc.raised, TIME_SECONDS), exc.msg);

    MTAS_Log(fullmsg, (exc.type==EXC_RECOVERABLE)?LOG_DEBUG:(exc.type==EXC_WARNING)?LOG_INFO:LOG_ERROR);
    if(exc.type != EXC_RECOVERABLE)
        SendErrorEmail(fullmsg);

    if(exc.type == EXC_CRITICAL)
    {
        // Recovery-Aktion: EA pausieren, keine neuen Trades etc.
        ExpertRemove(); // EA komplett entfernen (alternativ: Flags setzen)
    }
}
#endif