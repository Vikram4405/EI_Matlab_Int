# EI_Matlab_Int: Edge Impulse & MATLAB Integration Framework

An end-to-end framework and bridge for deploying **Edge Impulse TinyML / Edge AI models natively inside MATLAB and Simulink**.

---

## Overview

Edge Impulse provides automated DSP and neural network training optimized for resource-constrained edge devices. MATLAB & Simulink are industry standards for dynamic system simulation, control loops, signal processing, and Hardware-in-the-Loop (HIL) testing.

**EI_Matlab_Int** bridges both worlds by compiling Edge Impulse's standalone C++ deployment packages into **native MATLAB Executables (MEX)** and **Simulink S-Functions**, enabling:
* Real-time model inference inside MATLAB scripts and functions.
* Closed-loop control simulation and Digital Twins in Simulink.
* Instant validation of Edge Impulse models on synthetic or recorded sensor datasets.

---

## Repository Structure

```
EI_Matlab_Int/
├── edge_impulse_model/         # Unpacked Edge Impulse C++ Deployment SDK
│   ├── edge-impulse-sdk/       # Core DSP, mathematical routines & TFLite Micro
│   ├── model-parameters/       # Model metadata, labels, and DSP configurations
│   └── tflite-model/           # Compiled EON neural network graph & weights
│
├── ei_classifier_mex.cpp       # Native C++ MEX Gateway (Bridge to MATLAB)
├── build_mex.m                 # Automated build script invoking MATLAB's MEX compiler
├── test_coffee_classifier.m    # Scenario verification script with waveform visualization
│
├── SCENARIO_COFFEE_MACHINE.md  # Detailed documentation for Coffee Machine vibration scenario
└── README.md                   # Project overview & architecture guide
```

---

## Active Scenarios

* **[Scenario 1: Coffee Machine Vibration Classification](SCENARIO_COFFEE_MACHINE.md)**
  * **Input:** 3-axis vibration data ($accZ, accY, accX$) at $100\text{ Hz}$ ($200\text{ samples}$ / $2.0\text{ s}$ window).
  * **DSP:** Spectral Analysis (FFT length 16, 39 features).
  * **Model:** INT8 Quantized EON Compiled Neural Network.
  * **Classes:** `extract`, `grind`, `idle`, `pump`.

---

## Prerequisites

1. **MATLAB:** R2020b or later (tested on R2025b).
2. **C++ Compiler:**
   * **Windows:** Microsoft Visual C++ 2019 / 2022 (Build Tools or Visual Studio) with C++20 support, or MinGW-w64.
   * Verify compiler setup in MATLAB with:
     ```matlab
     mex -setup cpp
     ```

---

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/Vikram4405/EI_Matlab_Int.git
   cd EI_Matlab_Int
   ```
2. Open MATLAB and navigate to the project directory.
3. Build the MEX binary:
   ```matlab
   build_mex
   ```
4. Run the test suite:
   ```matlab
   test_coffee_classifier
   ```

---

## Roadmap

- [x] **Phase 1:** Standalone C++ MEX inference engine with automated MSVC build script.
- [x] **Phase 2:** Scenario 1 (Coffee Machine Vibration Stage Classification) with visualization.
- [ ] **Phase 3:** Simulink C-MEX S-Function Block for continuous dynamic simulation.
- [ ] **Phase 4:** MATLAB App Designer GUI for interactive waveform testing and audio/vibration playback.
- [ ] **Phase 5:** Automated Edge Impulse REST API bridge to upload synthetic training data directly from MATLAB.
