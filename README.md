# GAIA Lung AI
### Swift Student Challenge 2026 Submission

> An on-device chest X-ray analysis app powered by a custom-trained EfficientNet B3 CoreML model. GAIA detects four pulmonary conditions — Normal, Viral Pneumonia, Tuberculosis, and COVID-19 — entirely on-device with zero data transmission.

---

## Overview

GAIA (General AI Assistant for chest Imaging Analysis) is an iOS application built for the Apple Swift Student Challenge 2026. It combines a custom-trained convolutional neural network with a clinical-grade user experience to demonstrate how machine learning can be made accessible, explainable, and privacy-first.

The app was built entirely in SwiftUI as a `.swiftpm` Swift Playground package, using Apple-native frameworks exclusively — no third-party dependencies.

---

## Features

### AI Diagnosis Engine
- **EfficientNet B3** architecture trained on ~20,000 chest X-ray images across 4 classes
- **On-device inference** via CoreML and Vision framework — no internet connection required
- **Confidence scoring** with full softmax probability breakdown across all classes
- **Severity classification** — automatically grades results from Low → Critical based on confidence and condition
- **Emergency alert** triggers only at Critical severity (85%+ confidence on a disease class) to minimise false positives

### Scan Tab
- Upload from Photo Library or Camera (auto-falls back to gallery on Simulator)
- 4 built-in sample X-rays for immediate testing (Normal, COVID-19, Pneumonia, TB)
- Optional patient information form before analysis (name, age, gender, doctor, notes)
- Animated progress ring during inference
- Full accessibility support — VoiceOver labels, `accessibilityFocused` auto-focus on result, Reduce Motion support throughout

### Result Detail View
- Condition diagnosis with confidence percentage
- Severity badge with pulsing dot for urgent cases
- 4-section guide: AI Reasoning · Immediate Steps · Doctor Questions · Precautions
- Copy-to-clipboard on individual doctor questions
- One-tap PDF report generation from the result screen

### Heatmap Tab
- Class Activation Map (CAM) visualisation overlaid on the original X-ray
- Jet colormap rendering — blue (low activation) → red (high activation)
- Bilinear upsampling from 7×7 feature map to full resolution
- Fallback to anatomically-informed approximate heatmap when CAM weights are unavailable
- Interactive: select any saved scan from history to regenerate its heatmap

### Report Tab
- Generates a full 2-page PDF medical report
- Includes: patient info, diagnosis box, probability bar chart, AI reasoning, X-ray findings, doctor questions, precautions, emergency signals
- Branded with condition-coloured header and footer page numbers
- Share via AirDrop, Mail, Files, or any iOS share sheet

### History Tab
- Persistent scan history stored via `UserDefaults` with `Codable` serialisation
- Swift Charts 14-day trend bar chart, colour-coded by condition
- Search by condition name or patient name
- Filter chips per condition
- Swipe-to-delete and Clear All (with confirmation alert)
- Stats row showing scan counts per active condition

### About Tab
- Full model specifications and training methodology
- Expandable disease information cards
- Full medical disclaimer sheet
- Emergency call buttons for 911 / 999 / 112

---

## Technical Architecture

```
GAIA.swiftpm/
├── Package.swift                  ← Swift Package manifest (iOSApplication product)
└── Sources/
    ├── GAIAApp.swift              ← @main entry, AppState, RootView
    ├── ContentView.swift          ← Custom tab bar, navigation
    ├── ScanView.swift             ← Image picker, camera, analysis trigger
    ├── ResultDetailView.swift     ← Post-analysis guide & PDF generation
    ├── HeatmapTabView.swift       ← CAM heatmap generation & rendering
    ├── HistoryView.swift          ← Scan history, Swift Charts trend
    ├── ReportView.swift           ← PDF report builder & share sheet
    ├── AboutView.swift            ← Model info, disclaimers, emergency contacts
    ├── SplashScreenView.swift     ← Animated ECG + logo intro sequence
    ├── MLClassifier.swift         ← VNCoreMLModel wrapper, Vision pipeline
    ├── ScanResult.swift           ← DiseaseCondition, PredictionResult, ScanEntry
    ├── DiseaseGuide.swift         ← Per-condition clinical content
    ├── PDFReportGenerator.swift   ← UIGraphicsPDFRenderer 2-page report
    ├── PersistenceManager.swift   ← UserDefaults + Codable persistence
    ├── DesignSystem.swift         ← Colors, fonts, gradients, reusable components
    ├── GAIA_Classifier.swift      ← Auto-generated CoreML interface
    ├── GAIA_Classifier.mlmodelc/  ← Pre-compiled CoreML model bundle
    └── Assets.xcassets/           ← App icon + 4 sample X-ray images
```

### Frameworks Used

| Framework | Purpose |
|-----------|---------|
| SwiftUI | Entire UI layer |
| CoreML | On-device model loading and inference |
| Vision | Image preprocessing and VNCoreMLRequest pipeline |
| Charts | 14-day scan trend visualisation (Swift Charts) |
| PDFKit / UIGraphicsPDFRenderer | Medical report generation |
| PhotosUI | PhotosPicker for gallery access |
| UIKit | Camera picker, haptics, share sheet |

---

## ML Model

- **Architecture:** EfficientNet B3 (image classifier)
- **Training Platform:** Apple Create ML
- **Input:** 224 × 224 RGB chest X-ray image
- **Output:** Softmax probabilities across 4 classes + predicted label
- **Classes:** `Covid` · `Normal` · `Tuberculosis` · `Viral Pneumonia`
- **Training set:** ~20,000 images (NIH ChestX-ray14, Kaggle COVID-19 Radiography, Montgomery TB dataset)
- **Inference:** `.scaleFill` crop option to match Python PIL resize behaviour exactly
- **Format:** `.mlmodelc` (pre-compiled) for SPM compatibility

---

## Privacy

All image processing and model inference occurs entirely on-device using Apple's CoreML framework. No images, scan results, or personal information are transmitted to any server or third party. Patient data is stored locally in `UserDefaults` and never leaves the device.

---

## Medical Disclaimer

GAIA Lung AI is **not** a certified medical device and has not been approved by the FDA, CE, or any regulatory authority. It is intended for educational and demonstration purposes only. Always consult a licensed physician for any medical concerns. Do not make clinical decisions based on this application's output.

---

## Requirements

- iOS 16.0 or later
- Xcode 15+ / Swift Playgrounds 4.4+
- Device or Simulator (camera falls back to photo library on Simulator automatically)

---

## Author

**Rohit Raj** — Swift Student Challenge 2026  
Built with SwiftUI · CoreML · Vision · Swift Charts · Pytorch · Kaggle
