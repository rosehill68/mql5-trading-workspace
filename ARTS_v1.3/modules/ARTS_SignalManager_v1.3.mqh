//+------------------------------------------------------------------+
//|                               ARTS_SignalManager_v1.3.mqh        |
//+------------------------------------------------------------------+
//| VERSION: 1.3.0                                                    |
//| LETZTES ÄNDERUNGSDATUM: 2025-02-08 23:45 UTC                     |
//+------------------------------------------------------------------+

#property copyright "ARTS System"
#property version   "1.30"
#property strict

enum ENUM_SIGNAL_TYPE
{
   SIGNAL_LONG,
   SIGNAL_SHORT,
   SIGNAL_CLOSE_LONG,
   SIGNAL_CLOSE_SHORT,
   SIGNAL_MODIFY
};

struct TradingSignal
{
   ENUM_SIGNAL_TYPE signal_type;
   string symbol;
   double entry_price;
   double stop_loss;
   double take_profit_conservative;
   double take_profit_aggressive;
   bool use_trailing_stop;
   double trailing_atr_multiplier;
   int trailing_period;
   double position_size;
   string regime;
   string strategy;
   datetime signal_time;
   string additional_info;
   
   double GetConservativeRR()
   {
      double risk = MathAbs(entry_price - stop_loss);
      double reward = MathAbs(take_profit_conservative - entry_price);
      if(risk == 0) return 0;
      return reward / risk;
   }
   
   double GetAggressiveRR()
   {
      double risk = MathAbs(entry_price - stop_loss);
      double reward = MathAbs(take_profit_aggressive - entry_price);
      if(risk == 0) return 0;
      return reward / risk;
   }
};

class CSignalManager
{
private:
   bool m_enable_email;
   bool m_enable_push;
   bool m_enable_chart_alert;
   bool m_enable_sound;
   string m_email_address;
   string m_alert_sound_file;
   datetime m_last_signal_time;
   int m_min_signal_interval;
   int m_signals_today;
   int m_signals_total;
   
public:
   CSignalManager()
   {
      m_enable_email = true;
      m_enable_push = true;
      m_enable_chart_alert = true;
      m_enable_sound = true;
      m_email_address = "";
      m_alert_sound_file = "alert.wav";
      m_last_signal_time = 0;
      m_min_signal_interval = 300;
      m_signals_today = 0;
      m_signals_total = 0;
   }
   
   void SetEmailAddress(string email) { m_email_address = email; }
   
   void SetNotificationOptions(bool email, bool push, bool chart, bool sound)
   {
      m_enable_email = email;
      m_enable_push = push;
      m_enable_chart_alert = chart;
      m_enable_sound = sound;
   }
   
   bool SendSignal(TradingSignal &signal, double composite_score)
   {
      if(!ValidateSignal(signal)) return false;
      
      string signal_text = FormatSignalText(signal, composite_score);
      
      if(m_enable_email && m_email_address != "") SendEmailNotification(signal, signal_text, composite_score);
      if(m_enable_push) SendPushNotification(signal, composite_score);
      if(m_enable_chart_alert) ShowChartAlert(signal, signal_text);
      if(m_enable_sound) PlayAlertSound();
      
      m_last_signal_time = TimeCurrent();
      m_signals_today++;
      m_signals_total++;
      
      return true;
   }
   
   int GetSignalsToday() const { return m_signals_today; }
   int GetSignalsTotal() const { return m_signals_total; }
   
private:
   bool ValidateSignal(TradingSignal &signal)
   {
      if(TimeCurrent() - m_last_signal_time < m_min_signal_interval) return false;
      if(signal.symbol == "" || signal.entry_price <= 0) return false;
      if(signal.stop_loss <= 0) return false;
      if(signal.position_size <= 0) return false;
      return true;
   }
   
   string FormatSignalText(TradingSignal &signal, double score)
   {
      string text = "";
      text += "ARTS SIGNAL\n";
      text += (score >= 90 ? "SUPER-SIGNAL\n\n" : "\n");
      text += "Type: " + (signal.signal_type == SIGNAL_LONG ? "LONG" : "SHORT") + "\n";
      text += "Symbol: " + signal.symbol + "\n";
      text += StringFormat("Score: %.1f/100\n\n", score);
      text += StringFormat("Entry: %.5f\n", signal.entry_price);
      text += StringFormat("SL: %.5f\n", signal.stop_loss);
      text += StringFormat("TP Conservative: %.5f (RR 1:%.1f)\n", signal.take_profit_conservative, signal.GetConservativeRR());
      text += StringFormat("TP Aggressive: %.5f (RR 1:%.1f)\n\n", signal.take_profit_aggressive, signal.GetAggressiveRR());
      text += StringFormat("Lot Size: %.2f\n", signal.position_size);
      text += "Regime: " + signal.regime + "\n";
      text += "Strategy: " + signal.strategy + "\n";
      return text;
   }
   
   void SendEmailNotification(TradingSignal &signal, string message, double score)
   {
      if(m_email_address == "") return;
      string subject = StringFormat("ARTS %s: %s %s (Score: %.0f)", 
                                    (score >= 90 ? "SUPER" : "Signal"),
                                    (signal.signal_type == SIGNAL_LONG ? "LONG" : "SHORT"), 
                                    signal.symbol, score);
      SendMail(subject, message);
   }
   
   void SendPushNotification(TradingSignal &signal, double score)
   {
      string msg = StringFormat("%s %s | Score: %.0f | Entry: %.5f", 
                               (signal.signal_type == SIGNAL_LONG ? "LONG" : "SHORT"),
                               signal.symbol, score, signal.entry_price);
      SendNotification(msg);
   }
   
   void ShowChartAlert(TradingSignal &signal, string message)
   {
      Alert(message);
   }
   
   void PlayAlertSound()
   {
      PlaySound(m_alert_sound_file);
   }
};
//+------------------------------------------------------------------+