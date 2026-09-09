# Module: Explainability (`matlab/explainability/`)

**Phase Planned:** Phase 7  
**Subsystem:** Retino-AI Visual Explainability & Clinical Evidence Generation

---

## Purpose & Scope
Explainability is a core pillar of SIH26038. Medical practitioners, particularly in rural tele-health clinics, need clear visual rationale behind why an AI system assigned a specific DR stage. This module generates visual evidence and human-interpretable justifications to accompany predictions.

## Planned Capabilities (Future Development)
* **Lesion Overlay Visualizations:** Colored bounding boxes and segmented masks highlighting detected microaneurysms, hemorrhages, and exudates overlaid directly onto the raw fundus photograph.
* **Feature Contribution Maps:** Heatmaps demonstrating regional importance and lesion clusters driving the classification decision.
* **Clinical Summary Generator:** Programmatic generation of textual clinical rationale:
  * Example: *"Classified as Moderate NPDR due to presence of >5 microaneurysms in the inferior quadrant and localized hard exudates near the foveal avascular zone."*
* **Optional Future Methods:** Class Activation Mapping (Grad-CAM) if deep learning backbones are evaluated in future phases.

## Planned Interfaces (Future Placeholder)
* `generate_explanation_overlay.m`: Combines original fundus image with detected lesion locations and model attribution maps.
