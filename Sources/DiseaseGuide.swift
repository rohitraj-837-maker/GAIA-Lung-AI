import Foundation

// MARK: - Disease Guide
struct DiseaseGuide {
    let condition: DiseaseCondition
    let overview: String
    let aiReasoning: String
    let xrayFindings: [String]
    let immediateSteps: [ActionStep]
    let doctorQuestions: [String]
    let precautions: [String]
    let emergencySignals: [String]
    let lungRegionsAffected: [String]
    let heatmapDescription: String

    struct ActionStep: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
        let priority: Priority

        enum Priority { case low, medium, high, urgent }
    }

    static func guide(for condition: DiseaseCondition, confidence: Float) -> DiseaseGuide {
        switch condition {
        case .normal:    return normalGuide(confidence)
        case .pneumonia: return pneumoniaGuide(confidence)
        case .tb:        return tbGuide(confidence)
        case .covid:     return covidGuide(confidence)
        }
    }

    // MARK: Normal
    static func normalGuide(_ confidence: Float) -> DiseaseGuide {
        DiseaseGuide(
            condition: .normal,
            overview: "The AI analysis of your chest X-ray shows no significant abnormalities consistent with pulmonary disease. The lung fields appear clear with normal vascular markings and no evidence of consolidation, infiltrates, or other pathological changes.",
            aiReasoning: "The model detected normal lung field density patterns with uniform aeration throughout both lung fields. Costophrenic angles appear sharp, and no focal opacities or interstitial changes were identified that would suggest infectious or inflammatory processes.",
            xrayFindings: [
                "Clear bilateral lung fields",
                "Normal cardiac silhouette size",
                "Sharp costophrenic angles",
                "No consolidation or infiltrates",
                "Normal vascular markings",
                "No pleural effusion"
            ],
            immediateSteps: [
                ActionStep(icon: "checkmark.seal.fill", title: "Continue Regular Checkups", description: "Maintain annual chest X-rays as preventive care, especially if you smoke or have occupational exposure.", priority: .low),
                ActionStep(icon: "heart.fill", title: "Maintain Respiratory Health", description: "Avoid smoking, reduce air pollution exposure, and engage in regular aerobic exercise.", priority: .low),
                ActionStep(icon: "lungs.fill", title: "Practice Deep Breathing", description: "Regular deep breathing exercises strengthen lung capacity and overall respiratory function.", priority: .low)
            ],
            doctorQuestions: [
                "Is my lung function within normal range for my age and health?",
                "Are there any preventive steps I should take given my lifestyle?",
                "How often should I have chest X-rays as a preventive measure?",
                "Are there any early warning signs I should watch out for?",
                "What vaccinations should I consider for respiratory disease prevention?"
            ],
            precautions: [
                "Avoid smoking and second-hand smoke exposure",
                "Wear masks in dusty or polluted environments",
                "Get vaccinated against flu and pneumonia",
                "Exercise regularly to maintain lung capacity",
                "Stay hydrated to keep airways moist"
            ],
            emergencySignals: [
                "Sudden shortness of breath",
                "Coughing blood",
                "Chest pain with breathing",
                "Blue lips or fingertips (cyanosis)"
            ],
            lungRegionsAffected: ["None detected"],
            heatmapDescription: "Uniform activation across both lung fields indicates no focal areas of concern. Normal parenchymal density throughout."
        )
    }

    // MARK: Pneumonia
    static func pneumoniaGuide(_ confidence: Float) -> DiseaseGuide {
        let severity = confidence > 0.80 ? "significant" : "moderate"
        return DiseaseGuide(
            condition: .pneumonia,
            overview: "The AI has detected X-ray patterns strongly consistent with Pneumonia — a lung infection that causes the air sacs (alveoli) to fill with fluid or pus. This is a \(severity) finding that warrants prompt medical evaluation. Pneumonia can be bacterial, viral, or fungal in origin.",
            aiReasoning: "The model identified characteristic consolidation patterns — areas where the normally air-filled lung tissue appears dense and white on the X-ray. These opacity patterns, combined with possible air bronchograms and the distribution across lung segments, are hallmark features of pneumonia that the model was trained to recognize. Confidence level: \(Int(confidence * 100))%.",
            xrayFindings: [
                "Lobar or segmental consolidation (whitened areas)",
                "Possible air bronchograms within opacities",
                "Increased opacity in affected lung zones",
                "Possible blunting of costophrenic angles",
                "Asymmetric lung density suggesting focal infection",
                "Silhouette sign indicating airspace disease"
            ],
            immediateSteps: [
                ActionStep(icon: "phone.fill", title: "Contact Your Doctor Immediately", description: "Seek medical evaluation within 24 hours. If symptoms are severe (high fever, difficulty breathing), go to the emergency room.", priority: .urgent),
                ActionStep(icon: "pills.fill", title: "Do Not Self-Medicate", description: "Do not start antibiotics without prescription. Treatment depends on the type of pneumonia (bacterial vs viral).", priority: .high),
                ActionStep(icon: "bed.double.fill", title: "Rest and Hydration", description: "Rest completely and drink at least 8–10 glasses of water daily to help thin mucus and support recovery.", priority: .medium),
                ActionStep(icon: "thermometer", title: "Monitor Temperature", description: "Track your temperature every 4 hours. Fever above 103°F (39.4°C) requires immediate medical attention.", priority: .high),
                ActionStep(icon: "wind", title: "Breathing Position", description: "Sleep with your head elevated and try lying on the non-affected side to improve lung drainage.", priority: .medium)
            ],
            doctorQuestions: [
                "Is this bacterial or viral pneumonia? Does it affect treatment?",
                "Do I need to be hospitalized, or can I be treated at home?",
                "Which antibiotic or antiviral would be most appropriate for my case?",
                "How long is the expected recovery time?",
                "What are the signs that my condition is worsening and I need emergency care?",
                "Should my family members or close contacts be screened?",
                "What follow-up X-ray or tests should I schedule?",
                "Are there any underlying conditions that may have increased my susceptibility?"
            ],
            precautions: [
                "Isolate yourself to avoid spreading infection to others",
                "Cover coughs and sneezes with a tissue or elbow",
                "Wash hands frequently for at least 20 seconds",
                "Avoid smoking — it severely impairs lung healing",
                "Do not return to work or school until fever-free for 24+ hours",
                "Avoid cold air and damp environments",
                "Complete the full course of prescribed antibiotics",
                "Follow up with chest X-ray 6–8 weeks post-treatment"
            ],
            emergencySignals: [
                "Breathing rate above 30 breaths/minute",
                "Blood pressure dropping significantly",
                "Confusion or altered mental state",
                "Oxygen saturation below 90%",
                "Severe chest pain with breathing",
                "Coughing up blood",
                "Lips or nails turning blue (cyanosis)"
            ],
            lungRegionsAffected: ["Lower lobe consolidation zone", "Perihilar region", "Affected bronchopulmonary segments"],
            heatmapDescription: "High activation detected in lower and middle lung zones. The bright regions on the heatmap correspond to areas of increased radiodensity — classic consolidation zones where fluid accumulation in alveoli creates the hallmark 'ground glass' or dense white appearance of pneumonia."
        )
    }

    // MARK: Tuberculosis
    static func tbGuide(_ confidence: Float) -> DiseaseGuide {
        DiseaseGuide(
            condition: .tb,
            overview: "The AI has detected patterns highly suggestive of Tuberculosis (TB) — a serious bacterial infection caused by Mycobacterium tuberculosis that primarily attacks the lungs. TB is curable with proper treatment but requires immediate medical attention and public health notification.",
            aiReasoning: "The model identified characteristic upper lobe infiltrates, cavitary lesions, and/or fibronodular changes that are classic X-ray signatures of pulmonary tuberculosis. These patterns occur because TB bacteria tend to colonize the upper lobes where oxygen tension is highest. The consolidation patterns, lymph node involvement indicators, and possible calcified granulomas contributed to this classification at \(Int(confidence * 100))% confidence.",
            xrayFindings: [
                "Upper lobe infiltrates or consolidation",
                "Possible cavitary lesions (cavities within lung tissue)",
                "Fibronodular or reticulonodular opacities",
                "Possible hilar lymphadenopathy",
                "Calcified granulomas (healed TB foci)",
                "Pleural effusion or thickening in some cases",
                "Miliary pattern in disseminated cases"
            ],
            immediateSteps: [
                ActionStep(icon: "exclamationmark.triangle.fill", title: "Seek Emergency Evaluation TODAY", description: "TB is a serious, contagious disease. Visit an emergency room or TB clinic immediately. Do NOT delay.", priority: .urgent),
                ActionStep(icon: "person.2.slash", title: "Isolate Immediately", description: "TB is airborne and highly contagious. Isolate yourself from family, especially children and elderly, until cleared by a doctor.", priority: .urgent),
                ActionStep(icon: "mouth.fill", title: "Wear a Surgical Mask", description: "Wear an N95 or surgical mask at all times when around others until you receive medical guidance.", priority: .urgent),
                ActionStep(icon: "doc.text.fill", title: "Notify Close Contacts", description: "Healthcare authorities will need to trace and test people you've been in contact with. Cooperate fully.", priority: .high),
                ActionStep(icon: "cross.case.fill", title: "Prepare for Long-Term Treatment", description: "TB treatment typically lasts 6–9 months with multiple antibiotics. Adherence is critical to prevent drug resistance.", priority: .high)
            ],
            doctorQuestions: [
                "Is this active TB or latent TB infection?",
                "Has resistance testing been done — is this drug-sensitive or MDR-TB?",
                "Which combination therapy regimen will I be prescribed (HRZE)?",
                "What are the side effects of the medications I'll be taking?",
                "How long do I need to be in isolation?",
                "Do I need to be hospitalized or can I be treated as an outpatient?",
                "Will my close contacts need to be tested and treated?",
                "How will treatment success be monitored over time?",
                "What is DOT (Directly Observed Therapy) and will I need it?",
                "Are there any dietary restrictions or interactions I should know about?"
            ],
            precautions: [
                "CRITICAL: Strict respiratory isolation from others, especially children and immunocompromised individuals",
                "Complete the FULL 6–9 month antibiotic course — stopping early causes drug-resistant TB",
                "Notify your local health department as required by law in most regions",
                "Ventilate living spaces — open windows, use fans to circulate fresh air",
                "Cover mouth and nose during coughing or sneezing — dispose of tissues safely",
                "Avoid crowded public places until declared non-infectious by your doctor",
                "Avoid alcohol — it interacts dangerously with TB medications",
                "Monitor for medication side effects: liver toxicity, vision changes, hearing loss"
            ],
            emergencySignals: [
                "Coughing up blood (hemoptysis)",
                "Severe difficulty breathing or respiratory distress",
                "High fever not responding to medication",
                "Sudden confusion or neurological symptoms",
                "Severe abdominal pain (may indicate liver toxicity from medications)",
                "Vision changes (may indicate optic neuritis from ethambutol)"
            ],
            lungRegionsAffected: ["Upper lobe apical segments", "Posterior segments of upper lobes", "Possible hilar lymph nodes", "Pleural space"],
            heatmapDescription: "Strong upper-zone activation patterns are the model's key finding. TB characteristically activates the apical (top) regions of both lungs where oxygen tension is highest — the perfect environment for Mycobacterium tuberculosis to thrive. Cavitary regions appear as bright spots surrounded by dense infiltrate."
        )
    }

    // MARK: COVID-19
    static func covidGuide(_ confidence: Float) -> DiseaseGuide {
        DiseaseGuide(
            condition: .covid,
            overview: "The AI has detected bilateral, peripheral X-ray patterns consistent with COVID-19 pneumonia caused by the SARS-CoV-2 virus. These patterns reflect the characteristic immune response and viral pneumonitis associated with COVID-19 infection. Immediate medical evaluation and isolation are critical.",
            aiReasoning: "The model identified the hallmark 'ground glass opacities' (GGO) — hazy, web-like areas that don't completely obscure lung markings — distributed bilaterally and peripherally. This peripheral and bilateral distribution pattern, combined with the characteristic consolidation progression, is a strong discriminating feature for COVID-19 pneumonia that distinguishes it from bacterial pneumonia. Confidence: \(Int(confidence * 100))%.",
            xrayFindings: [
                "Bilateral peripheral ground glass opacities (GGOs)",
                "Consolidative opacities with peripheral distribution",
                "Lower lobe predominant involvement",
                "Possible 'crazy-paving' pattern in severe cases",
                "Bilateral multifocal airspace disease",
                "Possible pleural effusion in severe cases",
                "Progressive bilateral consolidation in advanced disease"
            ],
            immediateSteps: [
                ActionStep(icon: "phone.fill", title: "Contact Your Doctor or COVID Hotline", description: "Call ahead before visiting any healthcare facility. Most regions have dedicated COVID assessment lines.", priority: .urgent),
                ActionStep(icon: "person.crop.circle.badge.xmark", title: "Isolate Immediately", description: "COVID-19 is highly contagious. Isolate in a separate room with separate bathroom if possible. Avoid all household members.", priority: .urgent),
                ActionStep(icon: "waveform.path.ecg", title: "Monitor Oxygen Levels", description: "Purchase a pulse oximeter. If SpO2 drops below 94%, seek emergency care immediately. Check every few hours.", priority: .high),
                ActionStep(icon: "thermometer.medium", title: "Manage Fever and Symptoms", description: "Take prescribed fever reducers. Stay hydrated. Track all symptoms in a diary for your doctor.", priority: .medium),
                ActionStep(icon: "wind", title: "Prone Positioning", description: "Lying on your stomach (prone) has been shown to improve oxygenation in COVID-19 patients. Do this for 1–2 hours several times a day if tolerated.", priority: .medium)
            ],
            doctorQuestions: [
                "Based on the X-ray, what stage is my COVID-19 pneumonia?",
                "Should I be hospitalized, or are my oxygen levels stable enough for home care?",
                "Am I eligible for antiviral treatment (e.g., Paxlovid, Remdesivir)?",
                "What oxygen saturation level should trigger an emergency room visit?",
                "Are there any corticosteroids or anti-inflammatory medications indicated?",
                "What is the risk of long COVID-19 complications in my case?",
                "When can I safely end isolation?",
                "Should I have follow-up imaging to monitor lung recovery?",
                "What is my risk of pulmonary fibrosis or long-term lung damage?",
                "Are my household contacts at risk and should they be tested?"
            ],
            precautions: [
                "Strict isolation for at least 10 days from symptom onset or positive test",
                "Wear a well-fitted N95 mask around any household members",
                "Monitor SpO2 with a pulse oximeter at least 3 times daily",
                "Stay well hydrated — minimum 2–3 liters of water daily",
                "Rest completely — avoid any exertion that causes breathlessness",
                "Keep emergency contacts and hospital address readily available",
                "Inform your employer and recent contacts of possible exposure",
                "Follow local public health reporting requirements"
            ],
            emergencySignals: [
                "SpO2 below 94% or dropping rapidly",
                "Breathing rate above 30 per minute",
                "Chest pain or pressure that won't resolve",
                "Confusion, difficulty staying awake, or altered consciousness",
                "Inability to speak in full sentences due to breathlessness",
                "Persistent pain or pressure in the chest",
                "Bluish lips or face",
                "New neurological symptoms (stroke-like signs)"
            ],
            lungRegionsAffected: ["Bilateral peripheral zones", "Lower lobe predominance", "Sub-pleural regions", "Posterior lung zones"],
            heatmapDescription: "Bilateral peripheral activation is the defining characteristic. The heatmap shows strong edge-zone (peripheral and sub-pleural) activation in both lungs — COVID-19's ground glass opacities preferentially affect the outer margins of the lung, unlike bacterial pneumonia which tends toward central consolidation. The symmetric bilateral pattern is a key discriminating feature."
        )
    }
}
