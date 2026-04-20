# MTAS v2.0 – Technische Spezifikation und Architektur-Dokumentation

Datum: 2026-04-19
Version: 2.0.0
Projekt: Multi-Asset Trading System (MTAS)

---

## 1. Architektur-Uebersicht

### Schichtenmodell

```
+----------------------------------------------------------+
|  INPUTS (Parameter, Universe, Thresholds)                |
+----------------------------------------------------------+
                          |
                          v
+----------------------------------------------------------+
|  SCHICHT 1: IndicatorEngine                              |
|  Modul: MTAS_IndicatorEngine.mqh                         |
|  Input:  Symbol, TF_HTF, TF_LTF, Perioden               |
|  Output: IndicatorState (LSMA, ATR, RSI, BBW, Z-Scores) |
+----------------------------------------------------------+
                          |
                          v
+----------------------------------------------------------+
|  SCHICHT 2: RegimeEngine                                 |
|  Modul: MTAS_RegimeEngine.mqh                            |
|  Input:  IndicatorState                                  |
|  Output: RegimeState (CHOP/TREND/EXTREME, UP/DOWN/FLAT)  |
+----------------------------------------------------------+
                          |
                          v
+----------------------------------------------------------+
|  SCHICHT 3: Filter-Layer                                 |
|  Module: MTAS_SessionFilter.mqh, MTAS_NewsFilter.mqh     |
|  Input:  UTC-Zeit, Events                                |
|  Output: session_ok (bool), news_ok (bool)               |
+----------------------------------------------------------+
                          |
                          v
+----------------------------------------------------------+
|  SCHICHT 4: SignalEngine                                 |
|  Modul: MTAS_SignalEngine.mqh                            |
|  Input:  IndicatorState, RegimeState, Preis,             |
|          session_ok, news_ok                             |
|  Output: SignalState (direction, confidence, pullback)   |
+----------------------------------------------------------+
                          |
               +----------+----------+
               |                     |
               v                     v
+--------------------+   +--------------------------+
|  SCHICHT 5a:       |   |  SCHICHT 5b:             |
|  RiskEngine        |   |  ExitEngine              |
|  (Entry)           |   |  (Offene Trades)         |
|  -> RiskState      |   |  -> ExitDecision         |
|  -> TradePlan      |   |  -> Ratchet-SL Update    |
+--------------------+   +--------------------------+
               |                     |
               +----------+----------+
                          |
                          v
+----------------------------------------------------------+
|  SCHICHT 6: ExecutionEngine                              |
|  Modul: MTAS_ExecutionEngine.mqh                         |
|  Input:  TradePlan / ticket + Grund                      |
|  Output: ExecutionResult (success, ticket, error)        |
+----------------------------------------------------------+
                          |
                          v
+----------------------------------------------------------+
|  SCHICHT 7: State-Update + Display                       |
|  AssetContext aktualisieren, ChartDisplay, Email         |
+----------------------------------------------------------+
```

---

## 2. Modul- und Klassendiagramm

```
MTAS_Defines.mqh
  └── Konstanten, Enums (MTAS_Regime, MTAS_Trend, MTAS_Direction,
                         MTAS_TradeState, MTAS_LogLevel, MTAS_ExcType)
      Makros: MTAS_SAFE_DIV, MTAS_CLAMP

MTAS_Logger.mqh
  └── void MTAS_Log(msg, level)
      void MTAS_LogError/Warn/Info/Debug(msg)
      Konfiguration: g_LogLevel, g_LogToFile

MTAS_DataModel.mqh
  └── Structs:
      MarketSnapshot     (Rohdaten: bid, ask, spread, point)
      IndicatorState     (LSMA, ATR, RSI, BBW, Z-Scores)
      RegimeState        (regime, trend_htf, trend_ltf, strength)
      SignalState        (direction, pullback, rsi, confidence)
      RiskState          (allowed, reason, balance, equity, dd_pct)
      TradePlan          (symbol, dir, entry, sl, tp, lots, magic)
      ExecutionResult    (success, ticket, retries, error)
      AssetContext       (alle States + Trade-Status, Ringpuffer)

MTAS_ValueBuffer.mqh
  └── class MTAS_ValueBuffer
      + Add(value)
      + ZScore() -> double
      + Mean()   -> double
      + Count()  -> int
      + IsFull() -> bool

MTAS_Indicators.mqh  (pure functions, zustandslos)
  └── LSMA_Result CalcLSMA(symbol, tf, period, shift)
      double CalcATR(symbol, tf, period, shift)
      double CalcRSI(symbol, tf, period, shift)
      double CalcBBW(symbol, tf, period, stdev, shift)

MTAS_Normalizer.mqh  (pure functions)
  └── double CalcZScore(arr[], lookback)
      double NormalizeSlope(slope, atr)
      double ClampScore(v)

MTAS_IndicatorEngine.mqh
  └── class MTAS_IndicatorEngine
      + Init(symbol, tf_htf, tf_ltf, ...)
      + Update(IndicatorState &out) -> bool
      + Reset()

MTAS_RegimeEngine.mqh
  └── class MTAS_RegimeEngine
      + Init(chop_thresh, extreme_thresh, slope_thresh)
      + Classify(IndicatorState, RegimeState &out)

MTAS_SessionFilter.mqh
  └── class MTAS_SessionFilter
      + Init(start_utc, end_utc, block_friday)
      + IsActive() -> bool

MTAS_NewsFilter.mqh
  └── struct NewsEvent (event_time, impact, currency)
      class MTAS_NewsFilter
      + Init(buffer_before, buffer_after, min_impact)
      + SetEvents(events[], count)
      + ClearEvents()
      + IsNewsPending(symbol) -> bool

MTAS_SignalEngine.mqh
  └── class MTAS_SignalEngine
      + Init(pullback_mult, rsi_long, rsi_short, min_conf)
      + Evaluate(IndicatorState, RegimeState, price,
                 session_ok, news_ok, SignalState &out)

MTAS_RiskEngine.mqh
  └── class MTAS_RiskEngine
      + Init(max_trades, daily_loss, equity_stop, spread_atr,
             min_atr, risk_pct, sl_k, tp_atr, magic_min, max)
      + UpdateDailyState()
      + Evaluate(symbol, IndicatorState, RiskState &out)
      + BuildTradePlan(symbol, sig, ind, rs, magic, TradePlan &out) -> bool
      + CalcRatchetStop(is_long, lsma, atr, prev_sl) -> double

MTAS_ExitEngine.mqh
  └── struct ExitDecision (should_exit, reason, new_ratchet_sl)
      class MTAS_ExitEngine
      + Init(exit_chop, exit_flip, exit_news, exit_session, sl_k)
      + Evaluate(AssetContext, IndicatorState, RegimeState,
                 SignalState, cur_price) -> ExitDecision

MTAS_ExecutionEngine.mqh
  └── class MTAS_ExecutionEngine (nutzt CTrade)
      + Init(max_retries, delay_ms, slippage_pts)
      + OpenTrade(TradePlan) -> ExecutionResult
      + ModifyStopLoss(ticket, new_sl, symbol) -> bool
      + CloseTrade(ticket, reason) -> bool

MTAS_Email.mqh  (pure functions)
  └── bool SendTradeOpenEmail(plan, ticket, balance)
      bool SendTradeCloseEmail(symbol, profit, pct, reason, ticket)
      bool SendErrorEmail(context, msg)

MTAS_ChartDisplay.mqh  (pure functions)
  └── void MTAS_DeleteAllChartObjects(prefix)
      void DrawInfoPanel(text, x, y)
      void DrawRegimeBG(regime)
      void DrawEntryArrow(symbol, shift, price, is_long)
      void DrawRatchetLine(symbol, price, is_long)
      void UpdateInfoPanelFull(symbol, ind, regime, sig, rs, ctx)
```

---

## 3. Datenfluss im Detail

```
Tick/Bar arrives
    |
    v
[Bar-Check] iTime(sym, TF_LTF, 1) != LastBarTime[idx]
    |
    v
IndicatorEngine.Update()
    CopyClose/High/Low -> CalcLSMA(HTF) -> slope_htf_norm -> ValueBuffer.Add()
    CopyClose/High/Low -> CalcBBW(HTF)  -> ValueBuffer.Add()
    Z-Score via ValueBuffer.ZScore()
    CopyClose/High/Low -> CalcLSMA(LTF), CalcATR(LTF), CalcRSI(LTF)
    -> IndicatorState {lsma_htf, slope_htf_z, bbw_htf_z, lsma_ltf, atr_ltf, rsi_ltf}
    |
    v
RegimeEngine.Classify(IndicatorState)
    bbw_htf_z < chop_thresh    => REGIME_CHOP
    bbw_htf_z > extreme_thresh => REGIME_EXTREME
    else                        => REGIME_TREND
    slope_htf_z -> trend_htf (UP/DOWN/NONE)
    slope_ltf sign -> trend_ltf
    alignment = trend_htf == trend_ltf
    tradeable = TREND && alignment
    -> RegimeState
    |
    v
SessionFilter.IsActive()  -> session_ok
NewsFilter.IsNewsPending() -> news_ok
    |
    v
SignalEngine.Evaluate(IndicatorState, RegimeState, price, session_ok, news_ok)
    direction = regime.trend_htf (LONG/SHORT)
    pullback_ok = |price - lsma_ltf| <= pullback_mult * atr_ltf
    pull_quality = 1 - dist/tolerance (geklammert 0..1)
    rsi_ok = (LONG && rsi > rsi_long_min) || (SHORT && rsi < rsi_short_max)
    confidence = 0.25*tradeable + 0.20*trend_strength + 0.20*pull + 0.15*rsi + 0.10*sess + 0.10*news
    -> SignalState
    |
    +-- [Trade OPEN] -> ExitEngine.Evaluate()
    |       Ratchet-SL = max(prev_sl, lsma_ltf - K*atr_ltf)  [Long]
    |       Check: ratchet_hit, tp_hit, regime_chop, trend_flip, news, session
    |       -> ExitDecision {should_exit, reason, new_sl}
    |       -> ExecutionEngine.ModifyStopLoss() / CloseTrade()
    |
    +-- [Trade IDLE] -> RiskEngine.Evaluate()
            max_trades, daily_dd, equity_stop, spread/atr, min_atr
            -> RiskState {allowed, reason}
            |
            +-- [allowed && confidence >= min_conf && pullback_ok && rsi_ok]
                -> RiskEngine.BuildTradePlan()
                   entry = ask/bid
                   sl = lsma_ltf -/+ K * atr_ltf
                   tp = lsma_ltf +/- TP_ATR * atr_ltf
                   lots = balance * risk_pct / (stop_ticks * tick_value)
                   -> TradePlan
                   -> ExecutionEngine.OpenTrade(TradePlan)
                      Validierung: lots, sl_dist, markt_offen
                      CTrade.Buy/Sell + Retry-Schleife
                      -> ExecutionResult {success, ticket}
```

---

## 4. Risk-Engine: Mathematische Logik

### 4.1 Max-Daily-Loss-Schutz

```
daily_dd_pct = -daily_pnl / day_start_balance * 100
daily_pnl = account_equity - day_start_balance  (inkl. offene Positionen)
BLOCK wenn: daily_dd_pct >= max_daily_loss_pct
```

### 4.2 Equity-Stop

```
open_dd_pct = (1 - account_equity / account_balance) * 100
BLOCK wenn: open_dd_pct >= equity_stop_pct
```

### 4.3 Spread/Volatilitaets-Filter

```
spread_price = spread_points * point_size
spread_atr_ratio = spread_price / atr_ltf
BLOCK wenn: spread_atr_ratio > max_spread_atr_ratio
```

### 4.4 Positionsgroessen-Berechnung (deterministisch)

```
risk_money   = account_balance * risk_pct / 100.0
stop_dist    = |entry - stop_loss|               (Preis)
ticks_in_sl  = stop_dist / tick_size             (Tick-Einheiten)
raw_lots     = risk_money / (ticks_in_sl * tick_value)
lots         = floor(raw_lots / vol_step) * vol_step
lots         = clamp(lots, vol_min, vol_max)

tick_value   = SymbolInfoDouble(SYMBOL_TRADE_TICK_VALUE)   [Kontowährung/Tick/Lot]
tick_size    = SymbolInfoDouble(SYMBOL_TRADE_TICK_SIZE)    [Preis/Tick]
```

### 4.5 SL/TP-Berechnung

```
Long:
  stop_loss   = lsma_ltf - SL_K * atr_ltf
  take_profit = lsma_ltf + TP_ATR * atr_ltf
  rr_ratio    = (take_profit - entry) / (entry - stop_loss)

Short:
  stop_loss   = lsma_ltf + SL_K * atr_ltf
  take_profit = lsma_ltf - TP_ATR * atr_ltf
  rr_ratio    = (entry - take_profit) / (stop_loss - entry)
```

### 4.6 Ratchet-Stop (Trailing Stop)

```
Je Bar:
  candidate_sl = lsma_ltf - SL_K * atr_ltf  (Long)
  new_ratchet  = max(prev_ratchet_sl, candidate_sl)  (nur in Gewinnrichtung bewegen)

  candidate_sl = lsma_ltf + SL_K * atr_ltf  (Short)
  new_ratchet  = min(prev_ratchet_sl, candidate_sl)

ModifyStopLoss wird nur gesetzt wenn new_ratchet != prev_ratchet.
```

---

## 5. Confidence Score: Gewichtungsschema

| Komponente      | Gewicht | Berechnung                                         |
|-----------------|---------|---------------------------------------------------|
| Regime/Trend    | 0.25    | regime.tradeable ? 1.0 : 0.0                      |
| Trend-Staerke   | 0.20    | clamp(|slope_htf_z| / 2.0, 0.0, 1.0)             |
| Pullback-Guete  | 0.20    | clamp(1 - dist/tolerance, 0.0, 1.0)               |
| RSI-Momentum    | 0.15    | rsi_ok ? 1.0 : 0.0                                |
| Session         | 0.10    | session_ok ? 1.0 : 0.0                            |
| News            | 0.10    | news_ok ? 1.0 : 0.0                               |
| **Summe**       | **1.00**|                                                   |

Min. Confidence fuer Trade: 0.65 (konfigurierbar via Inp_Min_Confidence)

---

## 6. Fehlerfaelle und Edge-Cases

| Situation                       | Behandlung                                              |
|---------------------------------|---------------------------------------------------------|
| Unvollstaendige Preishistory    | IndicatorEngine.Update() gibt false zurueck, Pipeline stop |
| SL >= Entry (Long)              | BuildTradePlan() gibt false zurueck, kein Trade         |
| Lots = 0                        | BuildTradePlan() gibt false zurueck                     |
| SL unter STOPS_LEVEL-Mindestabstand | ExecutionEngine Safety-Guard blockiert Order         |
| Markt geschlossen (Spread = 0)  | ExecutionEngine blockiert                               |
| Order-Fehler (Requote)          | Retry-Schleife max. 3x mit 1 Sek. Pause                 |
| Tageswechsel                    | RiskEngine.UpdateDailyState() reset                     |
| Asset-Ticket nicht mehr offen   | AssetContext wird auf IDLE gesetzt                      |
| BBW/Slope ZScore = 0 (nicht gefuellt) | Puffer gibt 0.0 zurueck, kein Trade durch Regime-Check |
| ATR = 0                         | Spread-Filter und Normalizer geben 0.0 zurueck          |
| Universe leer                   | OnInit() gibt INIT_FAILED zurueck                       |
| MaxTrades erreicht              | RiskEngine blockiert neue Eroeffnung                    |
| Freitag 21 UTC                  | SessionFilter blockiert (funded-safe)                   |
| News-Ereignis (Impact >= 2)     | NewsFilter blockiert Eroeffnung + optionaler Exit       |

---

## 7. Zustandsdiagramm: AssetContext

```
        [Start]
           |
           v
       [TRADE_IDLE]
           |
           | RunPipeline: confidence >= min, risk OK, pullback OK, rsi OK
           v
       [TRADE_OPEN]  <---------+
           |                   |
           | ExitDecision       |
           | .should_exit=true  | Ratchet-SL Update (kein Exit)
           |                   |
           v                   |
       [TRADE_CLOSING]         |
           |                   |
           | CloseTrade() OK   |
           v                   |
       [TRADE_IDLE] -----------+
```

---

## 8. Verbesserungen gegenueber v1.1

| Bereich              | v1.1 (alt)                          | v2.0 (neu)                                  |
|----------------------|--------------------------------------|---------------------------------------------|
| Architektur          | Freie Funktionen, kein Schichten-  | Klassen, klare Layer, DataModel-Trennung    |
|                      | modell, kein Datenmodell             |                                             |
| Datenmodell          | Nur MTAS_AssetState (7 Felder)       | 7 Structs, vollstaendige Pipeline-Daten     |
| NewsFilter           | Dummy (immer false)                  | Vollstaendiges Event-Array + Currency-Match |
| RiskEngine           | Daily-DD: Kommentar "TODO"           | Vollstaendig, Tageswechsel-Detection        |
| Equity-Stop          | Fehlend                              | open_dd_pct >= equity_stop_pct              |
| Positionsgroesse     | stop_pips basiert (ungenau bei Gaps) | tick_value/tick_size (exakt, asset-unabh.)  |
| Ratchet-Stop         | Berechnung nicht ins SL-Modify gebunden | ExitEngine + ExecutionEngine.Modify getrennt |
| ExecutionEngine      | 3 Retries inline, keine Guards       | Safety-Guards + fehlertyp-basierter Retry   |
| ValueBuffer          | Klasse ohne ZScore-Methode           | ZScore(), Mean(), IsFull() integriert       |
| Signal-Alignment     | LTF-Trend nicht geprueft             | HTF + LTF Alignment Bedingung               |
| Session-Filter       | Wochenende nicht blockiert           | Samstag/Sonntag + Freitag-Close blockiert   |
| Bar-Tracking         | Kein Bar-Guard (Tick-Spam moeglich) | iTime-Vergleich, nur einmal je Bar          |
| Logging              | Kein Datei-Append (Ueberschreiben)  | FileSeek(SEEK_END) = echter Append          |
| Include-Struktur     | Module in <> (MT5 Include-Pfad)     | Relative Pfade "./modules/" (portabel)      |
| Fehler-Propagation   | Return bool, kein Grund              | Structs mit reason-Feld ueberall            |
| Chart-Display        | DrawInfoPanel ohne vollst. Status    | UpdateInfoPanelFull mit allen States        |
| Funded-Safety        | Nur Max-Trades und Spread            | 5-stufiger Check (Max-Trades, Daily-DD,     |
|                      |                                      | Equity-Stop, Spread/ATR, Min-ATR)           |

---

## 9. Dateistruktur

```
MTAS/
  MTAS_Main_v2.mq5                   Hauptdatei (EA-Einstiegspunkt)
  modules/
    MTAS_Defines.mqh                 Konstanten, Enums, Makros
    MTAS_Logger.mqh                  Logging (Konsole + Datei)
    MTAS_DataModel.mqh               Alle Datenstructs (Pipeline-Typen)
    MTAS_ValueBuffer.mqh             Ringpuffer + Z-Score
    MTAS_Indicators.mqh              Pure-Function Indikatorberechnungen
    MTAS_Normalizer.mqh              Z-Score, Slope-Norm, ClampScore
    MTAS_IndicatorEngine.mqh         Schicht 1: Indikator-Fassade
    MTAS_RegimeEngine.mqh            Schicht 2: Regime + Trend
    MTAS_SessionFilter.mqh           Filter: Session-Zeit
    MTAS_NewsFilter.mqh              Filter: News-Events
    MTAS_SignalEngine.mqh            Schicht 3: Signal + Confidence
    MTAS_RiskEngine.mqh              Schicht 4: Risk + TradePlan
    MTAS_ExitEngine.mqh              Exit-Logik + Ratchet-Stop
    MTAS_ExecutionEngine.mqh         Schicht 5: Order-Ausfuehrung
    MTAS_Email.mqh                   Email-Benachrichtigungen
    MTAS_ChartDisplay.mqh            Chart-Visualisierung
```

Gesamt: 1 EA-Datei + 16 Header-Module = 17 Dateien.
