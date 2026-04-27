import Foundation

enum PianoGuideFlameQualityTier: Equatable {
    case full
    case mildReduction
    case strongReduction
}

struct PianoGuideFlameQualityService {
    func tier(forVisibleNoteCount count: Int) -> PianoGuideFlameQualityTier {
        switch count {
            case 0 ... 6:
                .full
            case 7 ... 10:
                .mildReduction
            default:
                .strongReduction
        }
    }

    func scale(_ parameters: PianoGuideFlameParameters, for tier: PianoGuideFlameQualityTier) -> PianoGuideFlameParameters {
        let birthRateMultiplier: Float
        let sizeMultiplier: Float
        switch tier {
            case .full:
                birthRateMultiplier = 1.0
                sizeMultiplier = 1.0
            case .mildReduction:
                birthRateMultiplier = 0.75
                sizeMultiplier = 0.92
            case .strongReduction:
                birthRateMultiplier = 0.55
                sizeMultiplier = 0.82
        }
        return PianoGuideFlameParameters(
            intensityBand: parameters.intensityBand,
            birthRate: parameters.birthRate * birthRateMultiplier,
            speed: parameters.speed,
            speedVariation: parameters.speedVariation,
            lifetime: parameters.lifetime,
            particleSize: parameters.particleSize * sizeMultiplier,
            alpha: parameters.alpha,
            footprintScale: parameters.footprintScale,
            colorProfile: parameters.colorProfile
        )
    }
}
