# Tiny GP-GPU Architecture

**An Academic Implementation of a Simplified GPU Core**

## 📖 Project Overview
This repository contains the Register Transfer Level (RTL) and testbench implementation of a **Tiny-GPU architecture**. This project was developed as part of an **academic evaluation** for obtaining a **Licence degree in Electrical and Electronic Engineering (EEE)**.

The primary focus is the study and implementation of a simplified Graphics Processing Unit (GPU) to enhance understanding of:
* Parallel processing architectures.
* Instruction control flow.
* Modular hardware design using SystemVerilog.

---

## 🎓 Academic Context
* **Degree:** Licence in Electrical and Electronic Engineering (EEE)
* **Project Type:** Academic Evaluation Project
* **Purpose:** Educational study and practical implementation of GPU architecture concepts.

> **Note:** This project is intended strictly for educational and academic evaluation purposes.

---

## 🛠️ Design & Simulation Environment

### RTL Design
The hardware is described using **SystemVerilog**. This choice allows for the use of advanced language features to ensure the RTL code remains clear, compact, and maintainable.

### Verification
Simulation and functional verification are performed using **ModelSim**. The verification strategy includes:
* **Unit Testing:** Individual modules are tested in isolation.
* **System Testing:** Top-level behavior is verified through dedicated system testbenches.

---

## 📂 Source Code Organization
The repository is structured as follows:

```text
.
├── rtl/          # SystemVerilog RTL source files (Logic design)
├── testbench/    # Simulation testbenches and verification files
├── docs/         # Project documentation and diagrams
└── README.md     # Project overview and instructions
```
## 🚀 Hardware Implementation Plan
As part of the project objectives, the Tiny-GPU architecture is planned to be implemented on an **FPGA board**. This critical step aims to:
1. **Validate** the design in real hardware.
2. **Bridge the gap** between theoretical simulation and physical implementation.

---

## 📢 Acknowledgment & References
The **architectural concept and initial inspiration** for this project are based on the open-source Tiny-GPU project.

* **Original Reference:** [Tiny-GPU on GitHub](https://github.com/adam-maj/tiny-gpu)

This repository represents an **independent academic implementation** developed specifically for educational purposes, including custom simulation workflows and planned FPGA deployment.

---

## ⚠️ Disclaimer
This project is developed **solely for educational and academic evaluation purposes**. The source code is provided for review and learning and is **not intended for commercial use**.

⚠️ Disclaimer
This project is developed solely for educational and academic evaluation purposes. The source code is provided for review and learning and is not intended for commercial use.
