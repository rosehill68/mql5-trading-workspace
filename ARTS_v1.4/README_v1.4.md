# ARTS Trading System v1.4 - Benutzer-Dokumentation

## 📌 Was ist ARTS?

ARTS (Automated Regime-based Trading System) ist ein **intelligenter Trading-Roboter** für MetaTrader 5, der automatisch Handelschancen auf mehreren Währungspaaren erkennt und bewertet.

---

## ✨ Hauptfunktionen

### 1️⃣ **Multi-Symbol Scanning**
- Überwacht bis zu 10 Währungspaare gleichzeitig
- Scannt alle 60 Minuten (anpassbar)
- Findet die besten Trading-Gelegenheiten automatisch

### 2️⃣ **Zwei Handelsstrategien**

#### **Range-Reversal Strategie**
- Handelt in seitwärts laufenden Märkten
- Kauft am unteren Bereichsrand
- Verkauft am oberen Bereichsrand
- Nutzt Donchian-Kanäle zur Bereichserkennung

#### **Keltner-Breakout Strategie**
- Handelt in Trendmärkten
- Kauft bei Ausbruch nach oben
- Verkauft bei Ausbruch nach unten
- Nutzt Keltner-Kanäle als Trigger

### 3️⃣ **Intelligentes Bewertungssystem**
Jedes Signal wird mit einem **Composite Score** (0-100 Punkte) bewertet:

- **Regime Score (30 Punkte):** Passt die Marktphase zur Strategie?
- **Volatility Score (20 Punkte):** Ist die Volatilität optimal?
- **Entry Score (25 Punkte):** Wie gut ist der Einstiegspunkt?
- **Volume Score (15 Punkte):** Ist das Handelsvolumen erhöht?
- **Activity Score (10 Punkte):** Ist die Tageszeit günstig?

**Signalqualität:**
- 🟢 **90-100 Punkte:** SUPER-SIGNAL (beste Qualität)
- 🟡 **75-89 Punkte:** Gutes Signal
- 🔴 **< 75 Punkte:** Signal wird ignoriert

### 4️⃣ **Professionelles Risikomanagement**

#### **Positionsgrößen-Berechnung**
- Automatische Berechnung basierend auf Stop Loss
- Standard-Risiko: **0,7% pro Trade**
- Reduziert automatisch bei Verlusten

#### **Tägliche Limits**
- Max. **3 Trades pro Tag** (anpassbar)
- Max. **1,5% Tagesverlust** (anpassbar)
- Automatischer Trading-Stopp bei Überschreitung

#### **Drawdown-Schutz**
- Überwacht Gesamtverluste kontinuierlich
- Reduziert Positionsgröße bei Verlusten um 50%
- Stoppt Trading bei Erreichen des Limits

### 5️⃣ **Trade-Management**

#### **Breakeven-Funktion**
- Verschiebt Stop Loss auf Einstandspreis
- Aktiviert bei: Risiko + Spread in Profit
- Schützt vor Verlusten nach gutem Start

#### **Trailing Stop**
- Folgt dem Gewinn automatisch
- Nutzt ATR-basierte Berechnung
- Multiplier: 2,5 x ATR (anpassbar)

### 6️⃣ **Sicherheitsfilter**

#### **News Filter**
- Blockiert Trading 30 Min. vor High-Impact News
- Blockiert Trading 15 Min. nach High-Impact News
- Nutzt MT5 Economic Calendar

#### **Spread Filter**
- Überwacht Spreads kontinuierlich
- Blockiert Trading bei abnormalen Spreads
- Max. erlaubter Spread: 1,5x Durchschnitt

---

## 🎛️ Parameter-Erklärung

### **MODUS**
| Parameter | Standard | Beschreibung |
|-----------|----------|--------------|
| `InpAutoTradingMode` | false | **false:** Nur Signale senden<br>**true:** Trades automatisch ausführen |
| `InpUseBreakeven` | true | Breakeven-Funktion aktivieren |
| `InpUseTrailing` | true | Trailing Stop aktivieren |

### **ALLGEMEIN**
| Parameter | Standard | Beschreibung |
|-----------|----------|--------------|
| `InpRiskPercent` | 0.7 | Risiko pro Trade in % (0,1 - 10,0) |
| `InpMaxDailyDD` | 1.5 | Max. Tagesverlust in % (0,1 - 20,0) |
| `InpMaxTradesDay` | 3 | Max. Anzahl Trades pro Tag (1 - 100) |

### **REGIME**
| Parameter | Standard | Beschreibung |
|-----------|----------|--------------|
| `InpEnableRange` | true | Range-Reversal Strategie aktivieren |
| `InpEnableTrend` | true | Keltner-Breakout Strategie aktivieren |

### **LOOKBACK-PERIODEN**
| Parameter | Standard | Beschreibung |
|-----------|----------|--------------|
| `InpLinRegLookback` | 100 | Anzahl Bars für Trendberechnung |
| `InpATRPercLookback` | 200 | Anzahl Bars für Volatilitäts-Percentil |
| `InpATRPeriod` | 14 | Periode für ATR-Indikator |
| `InpDonchianPeriod` | 50 | Periode für Donchian-Kanal |
| `InpEMAPeriodFast` | 20 | Periode für schnellen EMA |
| `InpEMAPeriodSlow` | 50 | Periode für langsamen EMA |
| `InpVolumeLookback` | 20 | Anzahl Bars für Volumen-Durchschnitt |

### **SIGNAL-FILTER**
| Parameter | Standard | Beschreibung |
|-----------|----------|--------------|
| `InpMinSignalScore` | 75.0 | Mindest-Score für Signale (0 - 100) |
| `InpSuperSignalScore` | 90.0 | Score-Schwelle für SUPER-SIGNAL |

### **TRAILING**
| Parameter | Standard | Beschreibung |
|-----------|----------|--------------|
| `InpTrailingPeriod` | 10 | ATR-Periode für Trailing Stop |
| `InpTrailingMultiplier` | 2.5 | ATR-Multiplikator (1,0 - 5,0) |

### **BENACHRICHTIGUNGEN**
| Parameter | Standard | Beschreibung |
|-----------|----------|--------------|
| `InpEnableEmail` | true | Email-Benachrichtigungen senden |
| `InpEmailAddress` | "" | Email-Adresse (leer = MT5-Standard) |
| `InpEnablePush` | true | Push-Benachrichtigungen senden |
| `InpEnableChartAlert` | true | Chart-Alerts anzeigen |
| `InpEnableSound` | true | Sound-Alerts abspielen |

### **ERWEITERT**
| Parameter | Standard | Beschreibung |
|-----------|----------|--------------|
| `InpMagicNumber` | 230101 | Magic Number für Trade-Identifikation |
| `InpScanIntervalMinutes` | 60 | Scan-Intervall in Minuten |
| `InpShowPanel` | true | Info-Panel anzeigen (zukünftig) |

---

## 🚀 Erste Schritte

### **1. Installation**
1. Alle `.mqh` Dateien in `MQL5/Include/modules/` kopieren
2. `ARTS_MasterEA_v1.4.mq5` in `MQL5/Experts/` kopieren
3. MetaEditor öffnen → Kompilieren (F7)

### **2. Watchlist einrichten**
1. Marktübersicht öffnen (Strg+M)
2. Gewünschte Symbole mit Rechtsklick → "Symbol anzeigen"
3. Empfohlen: EUR/USD, GBP/USD, USD/JPY, AUD/USD

### **3. EA aktivieren**
1. Chart öffnen (beliebiges Symbol)
2. EA per Drag & Drop auf Chart ziehen
3. **WICHTIG:** `InpAutoTradingMode = false` lassen (Testphase)
4. AutoTrading aktivieren (grüner Button oben)

### **4. Signale testen**
- EA sendet Benachrichtigungen bei Signalen
- Prüfen Sie Email/Push-Empfang
- Beobachten Sie Signal-Qualität (Score)

### **5. Live-Trading aktivieren** (nach Testphase)
- `InpAutoTradingMode = true` setzen
- Risiko-Parameter überprüfen
- Mit kleinem Kapital starten

---

## 📊 Signal-Benachrichtigung verstehen

### **Beispiel-Signal:**
```
ARTS v1.4 SIGNAL

Type: LONG
Symbol: EUR/USD
Score: 87.5/100

Entry: 1.08450
SL: 1.08200
TP Conservative: 1.08950 (RR 1:2.0)
TP Aggressive: 1.09200 (RR 1:3.0)

Lot Size: 0.10
Regime: RANGE
Strategy: Range Reversal
```

### **Was bedeutet das?**
- **Type:** Kaufen (LONG) oder Verkaufen (SHORT)
- **Score:** Signalqualität (höher = besser)
- **Entry:** Einstiegspreis
- **SL:** Stop Loss (maximaler Verlust)
- **TP Conservative:** Gewinnziel 1 (sicherer)
- **TP Aggressive:** Gewinnziel 2 (ambitionierter)
- **RR:** Risk-Reward-Verhältnis (1:2 = doppelter Gewinn wie Risiko)
- **Regime:** Marktphase (RANGE / TREND)
- **Strategy:** Verwendete Strategie

---

## 🔒 Risiko-Hinweise

### ⚠️ **WICHTIG ZU WISSEN:**

1. **Non-Repainting Fix v1.4**
   - System nutzt **nur geschlossene Bars** (bar 1)
   - Signale ändern sich **nicht nachträglich**
   - Aber: Kein Backtest möglich für diese Version

2. **Bekannte Limitierungen:**
   - Volume Score nutzt Tick Volume (nicht Real Volume)
   - News Filter kann bei fehlendem Calendar fehlschlagen
   - Trailing Stop basiert auf HL-Average (kann volatil sein)

3. **Empfehlungen:**
   - Starten Sie mit **Demo-Konto**
   - Testen Sie **mindestens 4 Wochen**
   - Überwachen Sie **Daily Drawdown**
   - Passen Sie **Risiko an Kontostand** an

4. **Nicht geeignet für:**
   - Extrem volatile Märkte (hohe Spreads)
   - News-Events ohne Calendar-Zugang
   - Broker mit requotes/delays

---

## 📈 Performance-Überwachung

### **Täglich prüfen:**
- [ ] Anzahl Signale empfangen
- [ ] Anzahl ausgeführte Trades
- [ ] Täglicher Gewinn/Verlust
- [ ] Drawdown-Level

### **Wöchentlich prüfen:**
- [ ] Win-Rate der Signale
- [ ] Durchschnittlicher Score
- [ ] Beste/Schlechteste Symbole
- [ ] Regime-Verteilung (Range vs. Trend)

### **Monatlich anpassen:**
- [ ] Risiko-Parameter überprüfen
- [ ] Watchlist optimieren
- [ ] Signal-Score-Schwelle anpassen
- [ ] Strategie-Aktivierung prüfen

---

## 🛠️ Fehlerbehebung

### **Problem: Keine Signale**
✅ **Lösungen:**
- Prüfen Sie Watchlist (min. 3 Symbole)
- Reduzieren Sie `InpMinSignalScore` auf 70
- Erhöhen Sie Scan-Frequenz (30 Minuten)
- Aktivieren Sie beide Strategien

### **Problem: Zu viele Signale**
✅ **Lösungen:**
- Erhöhen Sie `InpMinSignalScore` auf 85
- Reduzieren Sie Watchlist
- Deaktivieren Sie eine Strategie

### **Problem: Keine Trades ausgeführt**
✅ **Lösungen:**
- Prüfen Sie `InpAutoTradingMode = true`
- Prüfen Sie AutoTrading-Button (grün)
- Prüfen Sie Daily Limits (max. Trades erreicht?)
- Prüfen Sie Spread (zu hoch?)

### **Problem: Trades zu früh geschlossen**
✅ **Lösungen:**
- `InpUseBreakeven = false` (temporär)
- Erhöhen Sie `InpTrailingMultiplier` (z.B. 3.0)
- Prüfen Sie Volatilität (ATR Percentile)

---

## 📚 Technische Details

### **Verwendete Indikatoren:**
- **ATR (Average True Range):** Volatilitätsmessung
- **EMA (Exponential Moving Average):** Trendrichtung
- **Donchian Channel:** Range-Identifikation
- **Keltner Channel:** Breakout-Identifikation
- **Linear Regression:** Trendstärke (R²-Wert)

### **Marktphasen-Erkennung:**
| Regime | R² | Winkel | ATR Percentile |
|--------|-----|--------|----------------|
| **RANGE** | < 0.20 | < 15° | 15-85% |
| **WEAK TREND** | 0.20-0.60 | - | 15-85% |
| **STRONG TREND** | > 0.60 | > 30° | 15-85% |
| **NO TRADE** | - | - | > 85% |

### **Score-Komponenten:**
```
Composite Score = Regime (30) + Volatility (20) + Entry (25) 
                  + Volume (15) + Activity (10)
```

---

## 🔄 Version History

### **v1.4.0 (2026-02-18)**
- ✅ Non-Repainting Fix implementiert
- ✅ Alle Berechnungen nutzen bar 1 statt bar 0
- ✅ Verbesserte Fehlerbehandlung
- ✅ Input-Validierung in RiskManager
- ✅ Dokumentation erweitert

### **v1.3.x (Vorgänger)**
- Multi-Symbol Scanner
- Composite Score Engine
- Regime Detection
- News/Spread Guard

---

## 📞 Support

Bei Fragen oder Problemen:
1. Prüfen Sie diese Dokumentation
2. Überprüfen Sie Expertenlogs (MetaTrader Toolbox)
3. Kontaktieren Sie den Entwickler

---

## ⚖️ Haftungsausschluss

**WICHTIG:** Dieses System ist ein Werkzeug zur Unterstützung Ihrer Trading-Entscheidungen.

- ❌ **Keine Garantie** für Gewinne
- ❌ **Keine Haftung** für Verluste
- ✅ **Eigenverantwortung** beim Trading
- ✅ **Risikomanagement** ist essentiell

**Trading birgt Risiken. Investieren Sie nur Kapital, dessen Verlust Sie verkraften können.**

---

## 📖 Zusammenfassung

### **Was macht ARTS v1.4?**
ARTS ist ein **automatischer Trading-Assistent**, der:
1. Mehrere Währungspaare gleichzeitig überwacht
2. Hochwertige Trading-Signale identifiziert
3. Signale mit Punktesystem bewertet (0-100)
4. Benachrichtigungen sendet (Email/Push/Alert)
5. Optional: Trades automatisch ausführt
6. Offene Positionen intelligent verwaltet
7. Risiko kontinuierlich überwacht

### **Für wen ist ARTS geeignet?**
✅ Trader mit **Grundkenntnissen** in MetaTrader 5  
✅ Trader die **Signale bewerten** können  
✅ Trader mit **Risikobewusstsein**  
✅ Trader die **langfristig** denken  

❌ **Nicht geeignet für:**
- Absolute Anfänger ohne MT5-Erfahrung
- "Get-Rich-Quick"-Mentalität
- Emotionales Trading

### **Wichtigste Erfolgsfaktoren:**
1. 📊 **Signal-Qualität überwachen** (Score > 85)
2. 🛡️ **Risiko kontrollieren** (max. 1% pro Trade)
3. ⏱️ **Geduld haben** (nicht jedes Signal traden)
4. 📈 **Performance tracken** (Tagebuch führen)
5. 🔧 **Parameter anpassen** (basierend auf Ergebnissen)

---

**Version:** 1.4.0  
**Datum:** 2026-02-18  
**Status:** Production-Ready mit bekannten Limitierungen  
**Lizenz:** Proprietary

---

**© 2026 ARTS Trading System. Alle Rechte vorbehalten.**