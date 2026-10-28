// A macOS-hosted helper that renders the iOS app icon.
//
// iOS icons must be full-bleed squares (the system applies the rounded mask),
// so this draws the artwork edge to edge rather than insetting a squircle the
// way the macOS icon does.
//
// Run via ../build.sh --icon; not part of the iOS app targets.

import AppKit
import SwiftUI

struct IOSAppIcon: View {
    var progress: Double = 0.68
    private let canvas: CGFloat = 1024

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.19, green: 0.21, blue: 0.26),
                    Color(red: 0.06, green: 0.07, blue: 0.10),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [Color.white.opacity(0.12), Color.clear],
                startPoint: .top,
                endPoint: .center
            )

            ring
        }
        .frame(width: canvas, height: canvas)
    }

    private var ring: some View {
        let ringSize = canvas * 0.56
        let lineWidth = canvas * 0.088

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.13), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.36, green: 0.89, blue: 0.58),
                            Color(red: 0.13, green: 0.72, blue: 0.42),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: "briefcase.fill")
                .font(.system(size: ringSize * 0.40, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: ringSize, height: ringSize)
    }
}

@MainActor
func render(to path: String) -> Int32 {
    let renderer = ImageRenderer(content: IOSAppIcon())
    renderer.scale = 1

    guard let cgImage = renderer.cgImage else {
        FileHandle.standardError.write(Data("failed to render icon\n".utf8))
        return 1
    }
    guard let data = NSBitmapImageRep(cgImage: cgImage)
        .representation(using: .png, properties: [:])
    else {
        FileHandle.standardError.write(Data("failed to encode icon\n".utf8))
        return 1
    }
    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("Wrote \(path)")
        return 0
    } catch {
        FileHandle.standardError.write(Data("failed to write icon: \(error)\n".utf8))
        return 1
    }
}

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon-1024.png"

exit(MainActor.assumeIsolated { render(to: outputPath) })
