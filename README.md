# EI_Matlab_Int: Edge Impulse & MATLAB Integration Framework

An end-to-end framework and bridge for deploying **Edge Impulse TinyML / Edge AI models natively inside MATLAB and Simulink**.

---

## Repository Structure

```
EI_Matlab_Int/
│
├── coffee_machine_test/        # Self-contained scenario: Coffee machine vibration classification
│   ├── edge_impulse_model/     # C++ Deployment SDK (DSP routines + EON compiled model)
│   ├── ei_classifier_mex.cpp   # Native C++ MEX Gateway
│   ├── build_mex.m             # Compiler script for MSVC / MinGW
│   ├── test_coffee_classifier.m# Test suite with waveform plots & confidence scores
│   ├── run_coffee_test.m       # All-in-one runner (auto-builds & executes)
│   └── SCENARIO_COFFEE_MACHINE.md # Dedicated documentation for this scenario
│
├── .gitignore                  # Ignores compiled binaries (*.mexw64, *.obj) & temp files
└── README.md                   # Repository overview & architecture
```

---

## Quick Start (Coffee Machine Scenario)

1. Open MATLAB and navigate to the project directory:
   ```matlab
   cd 'c:\path\to\EI_Matlab_Int\coffee_machine_test'
   ```
2. Run the all-in-one test script:
   ```matlab
   run_coffee_test
   ```
   * Automatically compiles `ei_classifier_mex.mexw64` if not already present.
   * Feeds synthetic 3-axis vibration signals into the model.
   * Displays classification predictions (`idle`, `pump`, `grind`, `extract`) and plots the waveforms in a MATLAB figure window.

---

## Active Scenarios

* **[Coffee Machine Vibration Classification](coffee_machine_test/SCENARIO_COFFEE_MACHINE.md)**
  * **Input:** 3-axis vibration data ($accZ, accY, accX$) at $100\text{ Hz}$ ($200\text{ samples}$ / $2.0\text{ s}$ window).
  * **DSP:** Spectral Analysis (FFT length 16, 39 features).
  * **Model:** INT8 Quantized EON Compiled Neural Network.
  * **Classes:** `extract`, `grind`, `idle`, `pump`.

---

## Roadmap

- [x] **Phase 1:** Standalone C++ MEX inference engine with automated MSVC build script.
- [x] **Phase 2:** Scenario 1 (Coffee Machine Vibration Stage Classification) isolated in `coffee_machine_test/`.
- [ ] **Phase 3:** Simulink C-MEX S-Function Block for continuous dynamic simulation.
- [ ] **Phase 4:** MATLAB App Designer GUI for interactive waveform testing and audio/vibration playback.
- [ ] **Phase 5:** Automated Edge Impulse REST API bridge to upload synthetic training data directly from MATLAB.
