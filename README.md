# Projekt: Pulse Detection and Trigger Generation
## Temat nr 5 | FPGA AMD Zynq UltraScale+ ZCU106

---

## Struktura projektu

```
pulse_project/
├── jupyter/
│   └── pulse_detector_projekt.ipynb   ← GŁÓWNY NOTEBOOK (oddaj to)
├── rtl/
│   ├── pulse_detector.v               ← rdzeń RTL (syntezowalny)
│   └── pulse_detector_axi.v           ← wrapper AXI-Lite
├── sim/
│   ├── tb_pulse_detector.v            ← testbench
│   └── run_sim.tcl                    ← skrypt Vivado do symulacji
└── README.md
```

---

## Jak uruchomić

### 1. Jupyter Notebook (Python)
```bash
pip install numpy matplotlib jupyter
jupyter notebook jupyter/pulse_detector_projekt.ipynb
```
Uruchom wszystkie komórki: **Kernel → Restart & Run All**

### 2. Symulacja Vivado (testbench)
```bash
vivado -mode batch -source sim/run_sim.tcl
```
Lub w Vivado GUI:
1. Otwórz Vivado
2. File → Add Sources → dodaj `rtl/` i `sim/`
3. Ustaw `tb_pulse_detector` jako top modułu symulacji
4. Flow → Run Simulation → Run Behavioral Simulation
5. Kliknij "Run All" w oknie symulacji

Oczekiwany wynik konsoli:
```
=== TB START: pulse_detector ===
[...] Reset released
[...] Sending 20 baseline samples
[...] PASS: trigger_flag asserted, trigger_time=...
[...] PASS: capture_done asserted. buf[X..Y]
[...] PASS: no trigger when disabled
=== ALL TESTS PASSED ===
```

---

## Mapa rejestrów AXI-Lite

| Offset | Rejestr      | R/W | Opis                        |
|--------|-------------|-----|-----------------------------|
| 0x00   | CTRL        | R/W | [0]=enable, [1]=soft_reset  |
| 0x04   | THRESHOLD   | R/W | Próg detekcji               |
| 0x08   | HYSTERESIS  | R/W | Strefa nieczułości          |
| 0x0C   | PRE_SAMPLES | R/W | Próbki przed triggerem      |
| 0x10   | POST_SAMPLES| R/W | Próbki po trigerze          |
| 0x14   | STATUS      | RO  | [0]=trig_flag, [1]=cap_done |
| 0x18   | TRIG_TIME   | RO  | Timestamp triggera          |
| 0x1C   | BUF_START   | RO  | Początek okna w buforze     |
| 0x20   | BUF_END     | RO  | Koniec okna w buforze       |
| 0x24   | BUF_DATA    | RO  | Próbka z bufora             |
| 0x28   | RD_ADDR     | R/W | Adres odczytu bufora        |

---

## Co robi algorytm (skrót)

1. Próbki wchodzą ciągłym strumieniem → zapisywane do **bufora kołowego** (256 × 16b BRAM)
2. Gdy `sample >= threshold` → **TRIGGER**: zapisz timestamp, wskaźnik pre-buffora, przejdź do ARMED
3. Gdy sygnał spadnie poniżej `threshold - hysteresis` → zbieraj `post_samples` próbek (CAPTURING)
4. Po zebraniu → `capture_done=1`, ARM odczytuje dane przez AXI-Lite
