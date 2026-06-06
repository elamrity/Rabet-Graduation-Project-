# Rabet: An Enterprise Corporate Management & Indoor Tracking Ecosystem 

**Rabet** (رابط) is a comprehensive, production-ready **Corporate Management System** designed to streamline enterprise operations, optimize resource management, and enhance workplace productivity. Beyond traditional management software, Rabet integrates an IoT-based **Indoor Positioning System (IPS)** as a core subsystem, bridging physical space tracking with digital corporate administration.

---

## 🏢 Core Modules & Ecosystem
Rabet is built to handle multiple dimensions of corporate operations:

### 1. Enterprise Resource & Corporate Management
* **Personnel & Asset Management:** Centralized dashboard to manage corporate assets, employees, and roles.
* **Workflow Automation:** Streamlining task assignments and tracking organizational workflows.
* **Real-Time Analytics:** Data-driven insights into corporate efficiency and resource utilization.

### 2. Integrated Indoor Positioning Subsystem (IPS)
* **Live Location Auditing:** Real-time tracking of high-value corporate assets and personnel within the facility.
* **Smart Noise Filtering:** Uses a localized **Exponential Moving Average (EMA)** algorithm to stabilize Wi-Fi signals (RSSI), ensuring smooth and accurate positioning on the floor map.
* **Geofencing & Security:** Automated alerts when restricted assets or personnel enter/leave specified corporate zones.

---

## 🛠️ System Architecture & Tech Stack
The ecosystem employs a robust multi-tier architecture to handle heavy corporate data load and live IoT streaming:

* **Application Layer (Client):** **Flutter Framework** for a premium, cross-platform (Android/iOS/Web) corporate dashboard.
* **Cloud & Real-Time Backend:** **Firebase Realtime Database & Auth** for instant data synchronization, corporate user authentication, and secure data pipelines.
* **Hardware Layer (Edge Infrastructure):** **ESP8266 Wi-Fi Modules** acting as enterprise anchors and tracking tags to feed location data into the system.

---

## 📉 Signal Processing (IPS Subsystem)
To maintain enterprise-grade accuracy inside challenging indoor corporate environments, raw signal noise is filtered via an **EMA filter**:

$$S_t = \alpha \cdot Y_t + (1 - \alpha) \cdot S_{t-1}$$

Where:
* $S_t$ = Filtered corporate tracking metric at time $t$.
* $Y_t$ = Raw incoming RSSI measurement.
* $\alpha$ = Environmental smoothing factor ($0 < \alpha \le 1$).

---

## 📂 Repository Structure
```text
├── Mobile_App/      # Flutter Enterprise Management Application (Admin & User Dashboards)
├── Hardware/        # Arduino/C++ source code for corporate IoT tracking nodes
└── README.md        # Comprehensive system documentation
