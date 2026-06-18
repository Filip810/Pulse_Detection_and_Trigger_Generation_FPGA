# Projekt: Pulse Detection and Trigger Generation

## Temat nr 5 | FPGA AMD Zynq UltraScale+ ZCU106

---

## Struktura projektu

```
pulse_project/
├── jupyter/
│   └── pulse_detector_projekt.ipynb
├── rtl/
│   ├── pulse_detector.v
│   └── pulse_detector_axi.v
├── sim/
│   ├── tb_pulse_detector.v
│   └── run_sim.tcl
└── README.md
```

---

## Jak uruchomić

### 1. Jupyter Notebook (Python)

```bash
pip install numpy matplotlib jupyter
jupyter notebook jupyter/pulse_detector_projekt.ipynb
```

### 2. Symulacja Vivado (testbench)

```bash
vivado -mode batch -source sim/run_sim.tcl
```

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
| ------ | ------------ | --- | --------------------------- |
| 0x00   | CTRL         | R/W | [0]=enable, [1]=soft_reset  |
| 0x04   | THRESHOLD    | R/W | Próg detekcji               |
| 0x08   | HYSTERESIS   | R/W | Strefa nieczułości          |
| 0x0C   | PRE_SAMPLES  | R/W | Próbki przed triggerem      |
| 0x10   | POST_SAMPLES | R/W | Próbki po trigerze          |
| 0x14   | STATUS       | RO  | [0]=trig_flag, [1]=cap_done |
| 0x18   | TRIG_TIME    | RO  | Timestamp triggera          |
| 0x1C   | BUF_START    | RO  | Początek okna w buforze     |
| 0x20   | BUF_END      | RO  | Koniec okna w buforze       |
| 0x24   | BUF_DATA     | RO  | Próbka z bufora             |
| 0x28   | RD_ADDR      | R/W | Adres odczytu bufora        |

---
