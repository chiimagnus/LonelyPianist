import Foundation

enum FlameIntensityBand: Equatable, CaseIterable {
    case soft
    case mediumSoft
    case medium
    case strong
    case veryStrong
}

struct FlameRGBA: Equatable {
    let red: Float
    let green: Float
    let blue: Float
    let alpha: Float
}

struct FlameColorProfile: Equatable {
    let start: FlameRGBA
    let end: FlameRGBA
}

struct PianoGuideFlameParameters: Equatable {
    let intensityBand: FlameIntensityBand
    let birthRate: Float
    let speed: Float
    let speedVariation: Float
    let lifetime: Float
    let particleSize: Float
    let alpha: Float
    let footprintScale: Float
    let colorProfile: FlameColorProfile
}

struct PianoGuideFlameParameterService {
    func parameters(for velocity: UInt8) -> PianoGuideFlameParameters {
        let band = intensityBand(for: velocity)
        let range = velocityRange(for: band)
        let normalized = normalizedValue(velocity, in: range)

        let base = baseParameters(for: band)
        let next = upperParameters(for: band)
        let micro = normalized * 0.18

        return PianoGuideFlameParameters(
            intensityBand: band,
            birthRate: interpolate(base.birthRate, next.birthRate, micro),
            speed: interpolate(base.speed, next.speed, micro),
            speedVariation: interpolate(base.speedVariation, next.speedVariation, micro),
            lifetime: interpolate(base.lifetime, next.lifetime, micro),
            particleSize: interpolate(base.particleSize, next.particleSize, micro),
            alpha: interpolate(base.alpha, next.alpha, micro),
            footprintScale: interpolate(base.footprintScale, next.footprintScale, micro),
            colorProfile: interpolate(base.colorProfile, next.colorProfile, micro)
        )
    }

    func boostedParameters(_ parameters: PianoGuideFlameParameters) -> PianoGuideFlameParameters {
        PianoGuideFlameParameters(
            intensityBand: parameters.intensityBand,
            birthRate: parameters.birthRate * 1.8,
            speed: parameters.speed * 1.25,
            speedVariation: parameters.speedVariation * 1.2,
            lifetime: parameters.lifetime,
            particleSize: parameters.particleSize * 1.15,
            alpha: min(1, parameters.alpha * 1.2),
            footprintScale: parameters.footprintScale,
            colorProfile: parameters.colorProfile
        )
    }

    func intensityBand(for velocity: UInt8) -> FlameIntensityBand {
        switch velocity {
            case 0 ... 40:
                .soft
            case 41 ... 70:
                .mediumSoft
            case 71 ... 95:
                .medium
            case 96 ... 112:
                .strong
            default:
                .veryStrong
        }
    }

    private func velocityRange(for band: FlameIntensityBand) -> ClosedRange<UInt8> {
        switch band {
            case .soft:
                0 ... 40
            case .mediumSoft:
                41 ... 70
            case .medium:
                71 ... 95
            case .strong:
                96 ... 112
            case .veryStrong:
                113 ... 127
        }
    }

    private func normalizedValue(_ velocity: UInt8, in range: ClosedRange<UInt8>) -> Float {
        let lower = Float(range.lowerBound)
        let upper = Float(range.upperBound)
        guard upper > lower else { return 0 }
        return min(1, max(0, (Float(velocity) - lower) / (upper - lower)))
    }

    private func baseParameters(for band: FlameIntensityBand) -> PianoGuideFlameParameters {
        switch band {
            case .soft:
                makeParameters(band: band, birthRate: 45, speed: 0.12, variation: 0.025, lifetime: 0.42, size: 0.010, alpha: 0.55, footprintScale: 0.84, start: .init(red: 1.00, green: 0.78, blue: 0.34, alpha: 0.75), end: .init(red: 1.00, green: 0.38, blue: 0.08, alpha: 0.05))
            case .mediumSoft:
                makeParameters(band: band, birthRate: 70, speed: 0.15, variation: 0.035, lifetime: 0.48, size: 0.012, alpha: 0.64, footprintScale: 0.90, start: .init(red: 1.00, green: 0.72, blue: 0.28, alpha: 0.82), end: .init(red: 1.00, green: 0.32, blue: 0.07, alpha: 0.06))
            case .medium:
                makeParameters(band: band, birthRate: 105, speed: 0.18, variation: 0.050, lifetime: 0.55, size: 0.014, alpha: 0.72, footprintScale: 0.96, start: .init(red: 1.00, green: 0.66, blue: 0.20, alpha: 0.90), end: .init(red: 1.00, green: 0.25, blue: 0.04, alpha: 0.07))
            case .strong:
                makeParameters(band: band, birthRate: 145, speed: 0.23, variation: 0.070, lifetime: 0.62, size: 0.016, alpha: 0.82, footprintScale: 1.0, start: .init(red: 1.00, green: 0.76, blue: 0.34, alpha: 0.95), end: .init(red: 1.00, green: 0.28, blue: 0.04, alpha: 0.08))
            case .veryStrong:
                makeParameters(band: band, birthRate: 185, speed: 0.28, variation: 0.095, lifetime: 0.70, size: 0.018, alpha: 0.90, footprintScale: 1.0, start: .init(red: 1.00, green: 0.86, blue: 0.50, alpha: 1.0), end: .init(red: 1.00, green: 0.30, blue: 0.03, alpha: 0.09))
        }
    }

    private func upperParameters(for band: FlameIntensityBand) -> PianoGuideFlameParameters {
        switch band {
            case .soft:
                baseParameters(for: .mediumSoft)
            case .mediumSoft:
                baseParameters(for: .medium)
            case .medium:
                baseParameters(for: .strong)
            case .strong, .veryStrong:
                baseParameters(for: .veryStrong)
        }
    }

    private func makeParameters(
        band: FlameIntensityBand,
        birthRate: Float,
        speed: Float,
        variation: Float,
        lifetime: Float,
        size: Float,
        alpha: Float,
        footprintScale: Float,
        start: FlameRGBA,
        end: FlameRGBA
    ) -> PianoGuideFlameParameters {
        PianoGuideFlameParameters(
            intensityBand: band,
            birthRate: birthRate,
            speed: speed,
            speedVariation: variation,
            lifetime: lifetime,
            particleSize: size,
            alpha: alpha,
            footprintScale: footprintScale,
            colorProfile: FlameColorProfile(start: start, end: end)
        )
    }

    private func interpolate(_ lhs: Float, _ rhs: Float, _ t: Float) -> Float {
        lhs + (rhs - lhs) * t
    }

    private func interpolate(_ lhs: FlameColorProfile, _ rhs: FlameColorProfile, _ t: Float) -> FlameColorProfile {
        FlameColorProfile(
            start: interpolate(lhs.start, rhs.start, t),
            end: interpolate(lhs.end, rhs.end, t)
        )
    }

    private func interpolate(_ lhs: FlameRGBA, _ rhs: FlameRGBA, _ t: Float) -> FlameRGBA {
        FlameRGBA(
            red: interpolate(lhs.red, rhs.red, t),
            green: interpolate(lhs.green, rhs.green, t),
            blue: interpolate(lhs.blue, rhs.blue, t),
            alpha: interpolate(lhs.alpha, rhs.alpha, t)
        )
    }
}
