import SwiftUI
import Foundation

// MARK: - Disease Condition
// ⚠️ rawValue MUST exactly match the CLASS_NAMES the Python model was trained on.
// Python CLASS_NAMES = ["Covid", "Normal", "Tuberculosis", "Viral Pneumonia"]
// These rawValues are used as dictionary keys in allProbabilities — do NOT change them.
enum DiseaseCondition: String, Codable, CaseIterable {
    case covid     = "Covid"
    case normal    = "Normal"
    case tb        = "Tuberculosis"
    case pneumonia = "Viral Pneumonia"

    // Human-readable name for all UI display — never use .rawValue in the UI
    var displayName: String {
        switch self {
        case .covid:     return "COVID-19"
        case .normal:    return "Normal"
        case .tb:        return "Tuberculosis"
        case .pneumonia: return "Viral Pneumonia"
        }
    }

    // Short label for tight spaces like filter chips and stats bars
    var shortLabel: String {
        switch self {
        case .covid:     return "COVID-19"
        case .normal:    return "Normal"
        case .tb:        return "TB"
        case .pneumonia: return "Pneumonia"
        }
    }

    var color: Color {
        switch self {
        case .normal:    return .colorNormal
        case .pneumonia: return .colorPneumonia
        case .tb:        return .colorTB
        case .covid:     return .colorCOVID
        }
    }

    var icon: String {
        switch self {
        case .normal:    return "checkmark.shield.fill"
        case .pneumonia: return "lungs.fill"
        case .tb:        return "exclamationmark.triangle.fill"
        case .covid:     return "microbe.fill"
        }
    }

    var severityLevel: SeverityLevel {
        switch self {
        case .normal:    return .none
        case .pneumonia: return .moderate
        case .tb:        return .high
        case .covid:     return .high
        }
    }

    var shortDescription: String {
        switch self {
        case .normal:    return "No disease detected"
        case .pneumonia: return "Lung infection detected"
        case .tb:        return "Tuberculosis pattern detected"
        case .covid:     return "COVID-19 pattern detected"
        }
    }
}

// MARK: - Severity Level
enum SeverityLevel {
    case none, low, moderate, high, critical

    var label: String {
        switch self {
        case .none:     return "Clear"
        case .low:      return "Low"
        case .moderate: return "Moderate"
        case .high:     return "High"
        case .critical: return "Critical"
        }
    }

    var color: Color {
        switch self {
        case .none:     return .colorNormal
        case .low:      return .colorNormal
        case .moderate: return .colorPneumonia
        case .high:     return .colorTB
        case .critical: return .colorCOVID
        }
    }

    var shouldCallEmergency: Bool { self == .critical }
}

// MARK: - Prediction Result
struct PredictionResult {
    let condition:        DiseaseCondition
    let confidence:       Float
    let allProbabilities: [String: Float]   // keyed by rawValue e.g. "Covid"
    let timestamp:        Date

    var severity: SeverityLevel {
        if condition == .normal                       { return .none }
        if confidence > 0.85 && condition != .normal  { return .critical }
        if confidence > 0.65 && condition != .normal  { return .high }
        if confidence > 0.45 && condition != .normal  { return .moderate }
        return .low
    }
}

// MARK: - Scan History Entry
struct ScanEntry: Identifiable, Codable {
    let id:                UUID
    let timestamp:         Date
    let conditionRaw:      String       // rawValue e.g. "Covid"
    let confidence:        Float
    let probabilitiesData: Data         // JSON [rawValue: Float]
    let imageData:         Data
    let patientName:       String
    let patientAge:        String
    let patientGender:     String
    let notes:             String

    var condition: DiseaseCondition { DiseaseCondition(rawValue: conditionRaw) ?? .normal }
    var image:     UIImage?         { UIImage(data: imageData) }
    var probabilities: [String: Float] {
        (try? JSONDecoder().decode([String: Float].self, from: probabilitiesData)) ?? [:]
    }

    init(result: PredictionResult, image: UIImage,
         patientName: String = "", patientAge: String = "",
         patientGender: String = "", notes: String = "") {
        self.id                = UUID()
        self.timestamp         = result.timestamp
        self.conditionRaw      = result.condition.rawValue
        self.confidence        = result.confidence
        self.probabilitiesData = (try? JSONEncoder().encode(result.allProbabilities)) ?? Data()
        self.imageData         = image.jpegData(compressionQuality: 0.7) ?? Data()
        self.patientName       = patientName
        self.patientAge        = patientAge
        self.patientGender     = patientGender
        self.notes             = notes
    }
}

// MARK: - Patient Info
struct PatientInfo {
    var name:       String = ""
    var age:        String = ""
    var gender:     String = "Not Specified"
    var doctorName: String = ""
    var notes:      String = ""
}
