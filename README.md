# Rabet: An IoT-Based Indoor Positioning System (IPS) 🚀🎯

**Rabet** is an advanced Indoor Positioning System (IPS) developed as a graduation project for the **Electronics and Communications Engineering** degree. The system leverages IoT hardware, cloud infrastructure, and a cross-platform mobile application to provide accurate, real-time indoor tracking and positioning where traditional GPS falls short.

---

## 📌 Key Features
* **Real-Time Indoor Tracking:** Continuous location monitoring within indoor environments using RSSI tri-lateration/fingerprinting.
* **Advanced Noise Reduction:** Implements a localized **Exponential Moving Average (EMA)** filtering algorithm to stabilize fluctuating Wi-Fi signals and eliminate environmental interference.
* **Cloud-Native Synchronization:** Ultra-low latency data pipeline between IoT nodes and the user interface.
* **Intuitive Mobile Dashboard:** Dynamic floor-plan rendering and real-time asset tracking.

---

## 🛠️ System Architecture & Tech Stack

The project is built on a robust 3-tier architecture:

* **Hardware Layer (Edge):** **ESP8266 Wi-Fi Modules** acting as anchors/tags to scan and transmit signal strengths.
* **Cloud & Database Layer:** **Firebase Realtime Database** for instant data synchronization, storage, and cloud functions.
* **Application Layer (Client):** **Flutter Framework** for a seamless, cross-platform (Android/iOS) responsive user experience.

---

## 📉 Signal Processing & Filtering
To overcome multi-path fading and noise inherent in indoor radio propagation, the system processes raw RSSI data on the fly using an **Exponential Moving Average (EMA)** filter:

$$S_t = \alpha \cdot Y_t + (1 - \alpha) \cdot S_{t-1}$$

Where:
* $S_t$ = The smoothed/filtered signal value at time $t$.
* $Y_t$ = The raw, incoming RSSI measurement.
* $\alpha$ = The smoothing factor ($0 < \alpha \le 1$), mathematically optimized for our specific indoor environment.

---

## 📂 Project Structure
```text
├── Hardware/        # Arduino/C++ source code for ESP8266 nodes & circuitry
├── Mobile_App/      # Flutter application source code (UI & Firebase integration)
└── README.md        # System documentation
