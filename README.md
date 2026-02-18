
The EA separates **market context**, **signal quality**, **risk control**, and **execution** into clearly defined modules.

---

## Modules & Responsibilities

| Module | Responsibility |
|------|---------------|
| RegimeDetector | Market regime classification using linear regression (R²), slope, angle, and ATR percentiles |
| IndicatorLibrary | Centralized indicator handle management (ATR, EMA, Donchian, Keltner), multi-timeframe capable |
| CompositeScoreEngine | Weighted scoring of regime, volatility, entry quality, volume, and activity (0–100) |
| MultiSymbolScanner | Iterates symbols, applies regime-specific strategies, aggregates and ranks signals |
| MarketActivityAnalyzer | Session-based activity scoring (London / NY / Tokyo), volume and volatility filters |
| RiskManager | Risk-based position sizing, daily and absolute drawdown limits, trade counters |
| PositionManager | Trade execution, breakeven logic, ATR-based trailing stop, position tracking |
| SignalManager | Signal formatting and notifications (Email, Push, Alert, Sound) |
| SpreadGuard | Spread spike detection using historical spread comparison |
| NewsAndSpreadGuard | MT5 Economic Calendar integration with news blackout windows |
| TimezoneManager | Broker UTC offset handling and session time conversion |

---

## Inputs & Configuration

### Operating Mode
- Auto-trading or signal-only mode
- Optional breakeven and trailing stop activation

### Risk Management
- Fixed risk per trade (percentage-based)
- Daily drawdown limit
- Absolute drawdown protection
- Maximum trades per day

### Regime Filters
- Enable/disable range strategies
- Enable/disable trend strategies

### Indicator & Lookback Settings
- Linear regression lookback
- ATR period and percentile window
- EMA, Donchian, Keltner parameters
- Volume lookback period

### Signal Filtering
- Minimum composite score threshold
- Super-signal threshold for high-quality setups

### Trade Management
- Trailing stop period and multiplier
- Magic number
- Scan interval
- Optional on-chart panel

---

## Indicators & Market Data

### Higher Timeframe (H4 – Market Context)
- ATR
- EMA 20 / EMA 50
- Donchian Channel
- Keltner Channel
- Linear Regression (trend strength & direction)

### Execution Timeframe (H1 – Entry Logic)
- Candle close confirmation
- High / Low price tracking

### Additional Data
- Tick volume
- Real-time spread
- MT5 Economic Calendar (high-impact events)

---

## Trade Logic Flow

### Initialization
- All modules are instantiated and wired
- Indicator handles are created on demand per symbol

### Runtime Cycle

1. **Position Management**
   - Breakeven check (profit ≥ initial risk + spread)
   - ATR-based trailing stop adjustment

2. **Scan Trigger**
   - Executed at fixed intervals (default: 60 minutes)
   - Risk limits and trade counters validated

3. **Multi-Symbol Scan**
   - News blackout check
   - Spread spike detection
   - Market activity scoring
   - Regime detection (H4)
   - Regime-specific entry evaluation (H1)
   - Composite score calculation

4. **Signal Selection**
   - Signals ranked by composite score
   - Limited by remaining daily trade capacity

5. **Execution**
   - Auto mode: trades executed via `CTrade`
   - Signal mode: notifications sent only
   - Risk manager registers executed trades

---

## Risk & Safety Mechanisms

### Pre-Trade Filters
- News blackout windows
- Spread spike protection
- Market activity threshold
- Volatility (ATR percentile) filtering
- Regime-based trade blocking

### Risk Controls
- Percentage-based position sizing
- Daily drawdown limit
- Absolute drawdown limit
- Trade count restriction per day

### Exit Management
- Initial SL/TP always set
- Breakeven protection
- ATR-based trailing stop

---

## Operating Modes & Constraints

### Modes
- **Signal-Only Mode:** No trades, notifications only
- **Auto-Trading Mode:** Full execution and management

### Time Constraints
- Fixed scan interval
- Session-based activity weighting
- News blackout enforcement

### Symbol Constraints
- Market Watch symbols only
- Maximum number of scanned symbols
- Symbols must support news data

### Regime Constraints
- Range and trend strategies independently switchable
- No-trade regime blocks all entries

---

## Design Philosophy

- Capital protection over profit maximization
- Clear separation of concerns
- Deterministic, rule-based decision making
- No grid, no martingale, no position averaging
- Designed for long-term robustness and funded-account compatibility

---

## Status

- **Version:** 1.3.1
- **Compilation:** Successful
- **Current Phase:** Stable baseline, ready for review or extension