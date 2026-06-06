//+------------------------------------------------------------------+
//|                                                                  |
//|  EA-Name    : THE UNBESTECHLICH EA                               |
//|  Datei      : UB_TradeExecutor.mqh                               |
//|  Modul      : Orderausführung und Broker-Kommunikation           |
//|  Version    : 5.2.1                                              |
//|  Datum      : 2026-06-04                                         |
//|                                                                  |
//|  Versionshistorie:                                               |
//|  v4.0 - Erstimplementierung                                      |
//|          Vollständige Fehlercode-Behandlung (12 Codes)           |
//|          STOPS_LEVEL-Validierung vor jeder Order                 |
//|          Retry-Logik: temporäre vs. permanente Fehler            |
//|          Netting- und Hedging-Konten-Kompatibilität              |
//|  v4.1 - Include-Guards, %llu für ulong, deutsche Kommentierung   |
//|  v5.2.1 - Versionsnummer aktualisiert                            |
//|                                                                  |
//|  Zweck:                                                          |
//|  Kapselt die gesamte Broker-Kommunikation über die MQL5          |
//|  Standard-Library CTrade. Bei temporären Serverfehlern werden    |
//|  bis zu 3 Versuche mit 250ms Pause unternommen.                  |
//|  Permanente Fehler werden sofort abgebrochen und protokolliert.  |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef UB_TRADEEXECUTOR_MQH
#define UB_TRADEEXECUTOR_MQH

#include "UB_Globals.mqh"
#include "UB_Logger.mqh"
// MQL5 Standard-Library für strukturierte Orderabgabe
#include <Trade\Trade.mqh>

// Globale CTrade-Instanz — wird von allen Executor-Funktionen genutzt
CTrade g_Trade;

//+------------------------------------------------------------------+
//| Konto-Typ bestimmen                                              |
//|                                                                  |
//| Auf Netting-Konten (Standard bei EU-regulierten Brokern) können  |
//| keine zwei gegenläufigen Positionen auf demselben Symbol         |
//| gleichzeitig existieren. Der Trap-Modus berücksichtigt das:      |
//| erst Schließen, dann gegenläufige Position eröffnen.             |
//|                                                                  |
//| Rückgabe: true = Hedging-Konto | false = Netting-Konto           |
//+------------------------------------------------------------------+
bool Executor_IsHedgingAccount()
{
   return (AccountInfoInteger(ACCOUNT_MARGIN_MODE) ==
           ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
}

//+------------------------------------------------------------------+
//| STOPS_LEVEL-Mindestabstand prüfen                                |
//|                                                                  |
//| Jeder Broker definiert einen Mindestabstand (in Punkten) zwischen|
//| dem aktuellen Marktpreis und SL/TP-Levels. Eine Order die diesen |
//| Abstand unterschreitet wird vom Server abgelehnt (Error 10016).  |
//|                                                                  |
//| Parameter:                                                       |
//|   symbol     - Handelssymbol                                     |
//|   entryPrice - Geplanter Einstiegspreis                          |
//|   slPrice    - Geplanter SL-Preis (0 = nicht prüfen)            |
//|   tpPrice    - Geplanter TP-Preis (0 = nicht prüfen)            |
//| Rückgabe: true = Abstände korrekt | false = zu nah am Preis      |
//+------------------------------------------------------------------+
bool Executor_ValidateStops(const string symbol,
                             const double entryPrice,
                             const double slPrice,
                             const double tpPrice)
{
   long   stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point      = SymbolInfoDouble (symbol, SYMBOL_POINT);
   double minAbstand = stopsLevel * point;

   // SL-Abstand prüfen
   if(slPrice > 0.0)
   {
      double slAbstand = MathAbs(entryPrice - slPrice);
      if(slAbstand < minAbstand)
      {
         LOG_W(symbol, StringFormat(
               "STOPS_LEVEL-Verletzung: SL-Abstand %.5f < "
               "Mindest %.5f (%ld Punkte)",
               slAbstand, minAbstand, stopsLevel));
         return false;
      }
   }

   // TP-Abstand prüfen
   if(tpPrice > 0.0)
   {
      double tpAbstand = MathAbs(entryPrice - tpPrice);
      if(tpAbstand < minAbstand)
      {
         LOG_W(symbol, StringFormat(
               "STOPS_LEVEL-Verletzung: TP-Abstand %.5f < "
               "Mindest %.5f",
               tpAbstand, minAbstand));
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Fehlercode-Beschreibung auf Deutsch                              |
//|                                                                  |
//| Gibt eine verständliche Beschreibung für häufige Broker-         |
//| Fehlercodes zurück. Wird im Journal protokolliert.               |
//+------------------------------------------------------------------+
string Executor_GetErrorDescription(uint code)
{
   switch(code)
   {
      case 10004: return "Requote — Preis hat sich geändert";
      case 10006: return "Anfrage abgelehnt";
      case 10007: return "Anfrage vom Client abgebrochen";
      case 10009: return "Order erfolgreich ausgeführt";
      case 10010: return "Order nur teilweise ausgeführt";
      case 10011: return "Verarbeitungsfehler beim Broker";
      case 10012: return "Verbindungs-Zeitüberschreitung";
      case 10013: return "Ungültige Anfrage (Syntaxfehler)";
      case 10014: return "Ungültiges Volumen (Lotzahl außerhalb Grenzen)";
      case 10015: return "Ungültiger Preis (Preisänderung während Anfrage)";
      case 10016: return "Ungültige Stops (STOPS_LEVEL-Verletzung)";
      case 10017: return "Automatischer Handel deaktiviert";
      case 10018: return "Markt geschlossen";
      case 10019: return "Nicht genügend Guthaben auf dem Konto";
      case 10021: return "Keine Kurse verfügbar (temporär)";
      case 10025: return "Anfrage bereits in Bearbeitung";
      case 10026: return "Autotrading vom Server deaktiviert";
      case 10027: return "Autotrading vom Client deaktiviert";
      case 10030: return "Freeze-Level verletzt";
      case 10031: return "Keine Verbindung zum Broker-Server";
      case 4756:  return "Orderversand fehlgeschlagen (intern)";
      default:    return StringFormat("Unbekannter Fehlercode: %d", code);
   }
}

//+------------------------------------------------------------------+
//| Prüfen ob ein Fehler einen erneuten Versuch rechtfertigt         |
//|                                                                  |
//| Temporäre Fehler (Requote, Preisänderung, keine Kurse) werden    |
//| erneut versucht. Permanente Fehler (kein Guthaben, Handel        |
//| gesperrt) werden sofort abgebrochen.                             |
//+------------------------------------------------------------------+
bool Executor_IsRetryableError(uint errorCode)
{
   switch(errorCode)
   {
      case 10004: // Requote — temporär
      case 10015: // Preisänderung — temporär
      case 10021: // Keine Kurse — temporär
      case 4756:  // Versandfehler — temporär
         return true;
      default:
         return false;   // Alle anderen: permanent, kein Retry
   }
}

//+------------------------------------------------------------------+
//| Order an den Broker senden (mit Retry-Logik)                     |
//|                                                                  |
//| Versucht die Order bis zu 3 Mal abzuschicken bei temporären      |
//| Fehlern (Requote, Preisänderung). Bei permanenten Fehlern        |
//| (kein Guthaben, Handel gesperrt) wird nach dem ersten Versuch    |
//| sofort abgebrochen.                                              |
//|                                                                  |
//| Parameter: req - Vollständige Orderparameter (S_TradeRequest)    |
//| Rückgabe: Ticket-Nummer bei Erfolg | 0 bei Fehler               |
//+------------------------------------------------------------------+
ulong Executor_SendOrder(S_TradeRequest &req)
{
   // STOPS_LEVEL-Vorab-Prüfung (verhindert Error 10016)
   if(!Executor_ValidateStops(req.Symbol, req.Price, req.SL, req.TP))
   {
      LOG_W(req.Symbol,
            "Order abgebrochen: STOPS_LEVEL-Prüfung fehlgeschlagen");
      return 0;
   }

   // CTrade für diese Order konfigurieren
   g_Trade.SetExpertMagicNumber(req.Magic);
   g_Trade.SetDeviationInPoints(req.Deviation);

   // Maximale Versuche und Wartezeit zwischen Versuchen
   const int MAX_VERSUCHE = 3;
   const int WARTE_MS     = 250;   // Millisekunden

   for(int versuch = 1; versuch <= MAX_VERSUCHE; versuch++)
   {
      bool erfolgreich = false;

      if(req.OrderType == ORDER_TYPE_BUY)
         erfolgreich = g_Trade.Buy(req.Volume, req.Symbol, req.Price,
                                    req.SL, req.TP, req.Comment);
      else if(req.OrderType == ORDER_TYPE_SELL)
         erfolgreich = g_Trade.Sell(req.Volume, req.Symbol, req.Price,
                                     req.SL, req.TP, req.Comment);

      if(erfolgreich)
      {
         ulong ticket = g_Trade.ResultOrder();
         LOG_I(req.Symbol, StringFormat(
               "Order ausgeführt: Ticket %llu | %s | "
               "%.4f Lots | Einstieg: %.5f | SL: %.5f | TP: %.5f",
               ticket,
               (req.OrderType == ORDER_TYPE_BUY) ? "BUY" : "SELL",
               req.Volume, req.Price, req.SL, req.TP));
         return ticket;
      }

      // Fehlerbehandlung
      uint fehlerCode = (uint)g_Trade.ResultRetcode();
      string fehlerText = Executor_GetErrorDescription(fehlerCode);

      LOG_W(req.Symbol, StringFormat(
            "Orderversuch %d/%d fehlgeschlagen: [%d] %s",
            versuch, MAX_VERSUCHE, fehlerCode, fehlerText));

      // Permanente Fehler: Sofort abbrechen
      if(!Executor_IsRetryableError(fehlerCode))
      {
         LOG_E(req.Symbol, StringFormat(
               "Permanenter Fehler [%d] %s — Signal wird verworfen",
               fehlerCode, fehlerText));
         return 0;
      }

      // Kurze Pause vor dem nächsten Versuch (nur wenn weiterer Versuch folgt)
      if(versuch < MAX_VERSUCHE)
         Sleep(WARTE_MS);
   }

   LOG_E(req.Symbol, StringFormat(
         "Order nach %d Versuchen fehlgeschlagen — Signal verworfen",
         MAX_VERSUCHE));
   return 0;
}

//+------------------------------------------------------------------+
//| Bestehende Position schließen (mit Retry-Logik)                  |
//|                                                                  |
//| Schließt eine offene Position per Market-Order.                  |
//| Wird für den Trap-Reversal-Mechanismus und den Wochenend-Schutz  |
//| verwendet.                                                       |
//|                                                                  |
//| Parameter:                                                       |
//|   ticket - Ticket-Nummer der zu schließenden Position            |
//|   symbol - Handelssymbol (nur für Logging)                       |
//| Rückgabe: true = Position geschlossen | false = Fehler           |
//+------------------------------------------------------------------+
bool Executor_ClosePosition(const ulong  ticket,
                             const string symbol)
{
   for(int versuch = 1; versuch <= 3; versuch++)
   {
      if(g_Trade.PositionClose(ticket))
      {
         LOG_I(symbol, StringFormat(
               "Position %llu geschlossen (Versuch %d)",
               ticket, versuch));
         return true;
      }

      uint fehlerCode = (uint)g_Trade.ResultRetcode();
      LOG_W(symbol, StringFormat(
            "Schließen fehlgeschlagen (Versuch %d/3): [%d] %s",
            versuch, fehlerCode,
            Executor_GetErrorDescription(fehlerCode)));

      // Permanente Fehler: sofort aufhören
      if(!Executor_IsRetryableError(fehlerCode))
         break;

      if(versuch < 3)
         Sleep(250);
   }

   LOG_E(symbol, StringFormat(
         "Position %llu konnte NICHT geschlossen werden!", ticket));
   return false;
}

#endif // UB_TRADEEXECUTOR_MQH