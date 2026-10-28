import SwiftUI

enum Theme {
    static let accent = Color(red: 0.20, green: 0.80, blue: 0.47)
    static let rest = Color(red: 0.64, green: 0.57, blue: 0.99)
    static let overtime = Color(red: 1.00, green: 0.58, blue: 0.20)

    static let ringOverall = Color(red: 0.20, green: 0.80, blue: 0.47)
    static let ringMorning = Color(red: 1.00, green: 0.69, blue: 0.26)
    static let ringAfternoon = Color(red: 0.35, green: 0.62, blue: 1.00)

    static func statusColor(_ phase: DayPhase) -> Color {
        switch phase {
        case .working: return accent
        case .lunchBreak, .dinnerBreak: return .orange
        case .beforeWork: return .blue
        case .afterWork: return .secondary
        case .overtime: return overtime
        case .weekend: return rest
        }
    }

    static func overallTint(_ phase: DayPhase) -> Color {
        phase == .overtime ? overtime : ringOverall
    }
}

// MARK: - Rings

/// Large circular completion ring.
struct ProgressRing: View {
    var progress: Double
    var tint: Color
    var lineWidth: CGFloat = 10
    var trackColor: Color = Color.primary.opacity(0.10)

    var body: some View {
        let value = progress.clamped(to: 0...1)
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.68), tint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .animation(.easeOut(duration: 0.5), value: value)
    }
}

/// Small circular completion ring for the morning / afternoon segments.
struct MiniRing: View {
    var progress: Double
    var tint: Color
    var size: CGFloat = 30
    var lineWidth: CGFloat = 4
    var trackColor: Color = Color.primary.opacity(0.12)

    var body: some View {
        let value = progress.clamped(to: 0...1)
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: value)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.5), value: value)
    }
}

// MARK: - Shared rows

/// One "上午 / 下午" row: ring, label, time range, percentage.
struct SegmentRow: View {
    var icon: String
    var title: String
    var range: String
    var progress: Double
    var percent: Int
    var tint: Color
    var compact: Bool = false
    var onDark: Bool = false
    /// The Dynamic Island's trailing region is too narrow to fit the range
    /// without truncating it, and the range is already shown elsewhere there.
    var showsRange: Bool = true

    private var primary: Color { onDark ? .white.opacity(0.9) : .primary }
    private var secondary: Color { onDark ? .white.opacity(0.45) : .secondary }
    private var tertiary: Color { onDark ? .white.opacity(0.32) : .secondary.opacity(0.7) }

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            MiniRing(
                progress: progress,
                tint: tint,
                size: compact ? 26 : 32,
                lineWidth: compact ? 4 : 5,
                trackColor: onDark ? .white.opacity(0.14) : .primary.opacity(0.10)
            )

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: compact ? 8 : 9, weight: .semibold))
                        .foregroundStyle(secondary)
                    Text(title)
                        .font(.system(size: compact ? 10 : 11, weight: .semibold))
                        .foregroundStyle(primary)
                        .fixedSize()
                }
                if showsRange {
                    Text(range)
                        .font(.system(size: compact ? 8 : 9, weight: .medium))
                        .foregroundStyle(tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(percent)%")
                .font(.system(size: compact ? 11 : 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(secondary)
                .frame(width: compact ? 34 : 38, alignment: .trailing)
        }
    }
}

/// The big ring with the percentage in the middle.
struct OverallRing: View {
    var progress: Double
    var percent: Int
    var tint: Color
    var diameter: CGFloat
    var onDark: Bool = false

    var body: some View {
        ZStack {
            ProgressRing(
                progress: progress,
                tint: tint,
                lineWidth: diameter * 0.095,
                trackColor: onDark ? .white.opacity(0.13) : .primary.opacity(0.10)
            )

            VStack(spacing: 0) {
                Text("\(percent)%")
                    .font(.system(size: diameter * 0.25, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(onDark ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("已完成")
                    .font(.system(size: diameter * 0.095, weight: .medium))
                    .foregroundStyle(onDark ? .white.opacity(0.45) : .secondary)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}
