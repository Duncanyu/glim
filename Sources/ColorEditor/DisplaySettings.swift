import CoreGraphics

struct DisplaySettings: Codable, Equatable {
    var brightness = 1.0
    var contrast = 1.0
    var gamma = 1.0
    var warmth = 0.0
    var tint = 0.0

    var redGain = 1.0
    var greenGain = 1.0
    var blueGain = 1.0
    var redGamma = 1.0
    var greenGamma = 1.0
    var blueGamma = 1.0
    var redLift = 0.0
    var greenLift = 0.0
    var blueLift = 0.0

    var tintRed = 1.0
    var tintGreen = 1.0
    var tintBlue = 1.0
    var tintStrength = 0.0
}

enum InterfaceMode: String, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case professional = "Professional"
    var id: Self { self }
}

enum AppPlacement: String, CaseIterable, Identifiable {
    case dock = "Dock"
    case menuBar = "Menu Bar"
    var id: Self { self }
}

struct DisplayInfo: Identifiable {
    let id: CGDirectDisplayID
    let name: String
    let isMain: Bool
    let key: String
}

struct GammaTable {
    var red: [CGGammaValue]
    var green: [CGGammaValue]
    var blue: [CGGammaValue]

    var count: Int { red.count }

    func approximatelyEquals(_ other: GammaTable) -> Bool {
        guard count == other.count else { return false }
        return zip(red, other.red).allSatisfy { abs($0 - $1) < 0.003 }
            && zip(green, other.green).allSatisfy { abs($0 - $1) < 0.003 }
            && zip(blue, other.blue).allSatisfy { abs($0 - $1) < 0.003 }
    }

    func adjusted(with settings: DisplaySettings) -> GammaTable {
        GammaTable(
            red: TransferCurve.adjust(red, settings: settings, channel: .red),
            green: TransferCurve.adjust(green, settings: settings, channel: .green),
            blue: TransferCurve.adjust(blue, settings: settings, channel: .blue)
        )
    }
}

enum TransferCurve {
    enum Channel { case red, green, blue }

    static func adjust(_ baseline: [CGGammaValue], settings: DisplaySettings, channel: Channel) -> [CGGammaValue] {
        guard baseline.count > 1 else { return baseline }

        let gain: Double
        let channelGamma: Double
        let lift: Double
        let tintComponent: Double
        let temperatureFactor: Double
        let tintFactor: Double

        switch channel {
        case .red:
            gain = settings.redGain
            channelGamma = settings.redGamma
            lift = settings.redLift
            tintComponent = settings.tintRed
            temperatureFactor = 1 - max(0, -settings.warmth) * 0.35
            tintFactor = 1 - max(0, -settings.tint) * 0.2
        case .green:
            gain = settings.greenGain
            channelGamma = settings.greenGamma
            lift = settings.greenLift
            tintComponent = settings.tintGreen
            temperatureFactor = 1 - abs(settings.warmth) * 0.12
            tintFactor = 1 - max(0, settings.tint) * 0.3
        case .blue:
            gain = settings.blueGain
            channelGamma = settings.blueGamma
            lift = settings.blueLift
            tintComponent = settings.tintBlue
            temperatureFactor = 1 - max(0, settings.warmth) * 0.35
            tintFactor = 1 - max(0, -settings.tint) * 0.2
        }

        let colorFactor = 1 - settings.tintStrength * (1 - tintComponent)
        // Preserve enough output to keep the reset controls visible.
        let factor = max(0.08, gain * temperatureFactor * tintFactor * colorFactor * settings.brightness)
        let last = Double(baseline.count - 1)
        let gammaExponent = 1 / max(0.01, settings.gamma * channelGamma)

        return baseline.indices.map { index in
            let input = Double(index) / last
            let gammaInput = pow(input, gammaExponent)
            let curvedInput = contrastAdjusted(gammaInput, amount: settings.contrast)
            let position = curvedInput * last
            let lower = Int(position)
            let upper = min(lower + 1, baseline.count - 1)
            let fraction = position - Double(lower)
            let base = Double(baseline[lower]) * (1 - fraction) + Double(baseline[upper]) * fraction
            let value = max(0, base + lift) * factor
            return CGGammaValue(min(1, max(0, value)))
        }
    }

    private static func contrastAdjusted(_ input: Double, amount: Double) -> Double {
        if input < 0.5 {
            return 0.5 * pow(input * 2, amount)
        }
        return 1 - 0.5 * pow((1 - input) * 2, amount)
    }
}
