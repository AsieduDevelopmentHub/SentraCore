# Behavioral Intelligence Layer

SentraCore moves beyond static thresholds (e.g., "Alert if CPU > 90%") to implement context-aware, statistical analysis of system behavior.

## 1. Time-of-Day Segmenting
System behavior changes throughout the day. A backup script running at 2 AM might spike the CPU to 100%, which is *normal* for that time, but a spike to 100% at 2 PM might be an anomaly.
We break the day into 4 segments:
- **Night:** 00:00 - 06:00
- **Morning:** 06:00 - 12:00
- **Afternoon:** 12:00 - 18:00
- **Evening:** 18:00 - 24:00

The `BaselineModel` stores separate standard deviations and means for each segment.

## 2. Statistical Anomaly Detection (Z-Scores)
The `AnomalyDetector` evaluates the current snapshot against the active Time-of-Day segment.
- Instead of raw percentages, it calculates the Z-Score: `(Current - Mean) / Standard Deviation`.
- Anomalies must be **sustained** over multiple cycles to trigger an elevated stress response, preventing micro-spikes from causing false alarms.

## 3. Trend Analysis
The `TrendAnalyzer` performs linear regression over the short-term buffer (last 60 seconds).
- **CPU Slope:** Detects run-away processes before they hit 100%.
- **Memory Slope:** Acts as a real-time memory leak detector.
- **Volatility:** Calculates short-term standard deviation to measure system instability.

## 4. Multi-State Stress Engine
The final Stress Score (0-100) is a composite of:
1. Raw instantaneous resource pressure.
2. Trend modifiers (growing slopes add penalty points).
3. Anomaly modifiers (sustained z-score deviations multiply the pressure).
