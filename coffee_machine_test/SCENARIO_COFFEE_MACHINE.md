# Scenario 1: Coffee Machine Vibration Classification

This scenario demonstrates the integration of an Edge Impulse trained machine learning model with MATLAB for real-time vibration classification of coffee machine operational stages.

---

## 1. Physical System & Problem Definition

Coffee machines generate distinct mechanical vibration signatures depending on their internal state (motors, heating pumps, grinding burrs). By analyzing high-frequency 3-axis accelerometer data, we can classify the machine's current state in real time:

| State | Physical Meaning | Vibration Characteristics |
| :--- | :--- | :--- |
| **`idle`** | Machine is powered on but resting. | Low amplitude static sensor noise around gravity ($9.8\text{ m/s}^2$ on Z-axis). |
| **`grind`** | Electric bean grinder active. | High-amplitude, high-energy wideband chaotic vibration. |
| **`pump`** | High-pressure water pump filling boiler. | Periodic harmonic oscillation (e.g. 50/60 Hz mains harmonic). |
| **`extract`** | Espresso brewing through group head. | Medium-pressure fluid flow with steady mechanical vibration. |

---

## 2. Model Specifications

* **Edge Impulse Project:** `Vibration Classification - Coffee machine stages`
* **Sensor Channels:** 3 axes (`accZ`, `accY`, `accX`)
* **Sampling Rate:** $100\text{ Hz}$ ($10\text{ ms}$ interval)
* **Window Size:** $200\text{ samples}$ ($2.0\text{ seconds}$ duration)
* **Total Raw Input Size:** $200 \times 3 = \mathbf{600\text{ floats}}$ per classification window
* **DSP Preprocessing Block:**
  * Spectral Analysis using KissFFT (FFT length 16)
  * Feature extraction: Spectral peaks, power edges, statistical moments
  * Output: **39 numerical features**
* **Inference Engine:**
  * Quantized INT8 Feedforward Neural Network
  * Compiled via **Edge Impulse EON Compiler** for standalone C++ execution without dynamic interpreter overhead

---

## 3. MATLAB Integration Pipeline

```
+-------------------------------------------------------------+
|                     MATLAB Workspace                        |
|                                                             |
|   raw_signal = [accZ, accY, accX]  (200 x 3 matrix)         |
|                         │                                   |
|                         ▼                                   |
|   res = ei_classifier_mex(raw_signal)                       |
+-------------------------│-----------------------------------+
                          ▼
+-------------------------------------------------------------+
|                 C++ MEX Gateway (Native)                    |
|                                                             |
|   1. Reorders MATLAB column-major memory into interleaved   |
|      sensor frame stream [Z0, Y0, X0, Z1, Y1, X1, ...]      |
|   2. Connects to Edge Impulse signal_t stream callback      |
|   3. Runs DSP spectral feature extraction                   |
|   4. Invokes EON INT8 compiled neural network               |
|   5. Returns predictions and timing statistics              |
+-------------------------------------------------------------+
```

---

## 4. How to Build & Run

### Step 1: Open MATLAB
Navigate to this repository folder in MATLAB:
```matlab
cd 'c:\path\to\EI_Matlab_Int'
```

### Step 2: Compile the MEX Function
Execute the one-click build script:
```matlab
build_mex
```
* Uses Microsoft Visual C++ (`cl.exe`) or MinGW with `/std:c++20`.
* Links Edge Impulse DSP + EON neural network into `ei_classifier_mex.mexw64`.

### Step 3: Run the Verification Test
```matlab
test_coffee_classifier
```
This script generates simulated vibration profiles (Idle, Pump, Grind) and displays:
* Console classification table and confidence percentages.
* An interactive MATLAB Figure with vibration waveforms and prediction bar charts.
