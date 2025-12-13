import SwiftUI

struct EqualizerView: View {
    @ObservedObject private var eqManager = EqualizerManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Enable Toggle
                    enableToggle
                    
                    // EQ Visualization Curve
                    eqCurveView
                        .padding(.horizontal)
                    
                    // Frequency Band Sliders
                    bandSlidersView
                        .padding(.horizontal, 8)
                    
                    // Presets
                    presetsSection
                }
                .padding(.vertical)
            }
            .navigationTitle("Equalizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Enable Toggle
    
    private var enableToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Equalizer")
                    .font(.headline)
                Text(eqManager.isEnabled ? "On" : "Off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $eqManager.isEnabled)
                .labelsHidden()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    // MARK: - EQ Curve Visualization
    
    private var eqCurveView: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                gridBackground(in: geometry.size)
                
                // EQ Curve
                if eqManager.isEnabled {
                    eqCurvePath(in: geometry.size)
                        .stroke(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                    
                    // Filled area under curve
                    eqCurveFilledPath(in: geometry.size)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                // Center line (0 dB)
                Path { path in
                    let y = geometry.size.height / 2
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .frame(height: 120)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func gridBackground(in size: CGSize) -> some View {
        Canvas { context, size in
            let horizontalLines = 5
            let verticalLines = eqManager.bands.count
            
            // Horizontal lines
            for i in 0...horizontalLines {
                let y = size.height * CGFloat(i) / CGFloat(horizontalLines)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.secondary.opacity(0.1)), lineWidth: 0.5)
            }
            
            // Vertical lines
            for i in 0..<verticalLines {
                let x = size.width * CGFloat(i) / CGFloat(verticalLines - 1)
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.secondary.opacity(0.1)), lineWidth: 0.5)
            }
        }
    }
    
    private func eqCurvePath(in size: CGSize) -> Path {
        Path { path in
            let points = curvePoints(in: size)
            guard let first = points.first else { return }
            
            path.move(to: first)
            
            // Use catmull-rom spline for smooth curve
            for i in 0..<points.count {
                let p0 = points[max(0, i - 1)]
                let p1 = points[i]
                let p2 = points[min(points.count - 1, i + 1)]
                let p3 = points[min(points.count - 1, i + 2)]
                
                if i > 0 {
                    let cp1 = CGPoint(
                        x: p1.x + (p2.x - p0.x) / 6,
                        y: p1.y + (p2.y - p0.y) / 6
                    )
                    let cp2 = CGPoint(
                        x: p2.x - (p3.x - p1.x) / 6,
                        y: p2.y - (p3.y - p1.y) / 6
                    )
                    path.addCurve(to: p2, control1: cp1, control2: cp2)
                }
            }
        }
    }
    
    private func eqCurveFilledPath(in size: CGSize) -> Path {
        Path { path in
            let points = curvePoints(in: size)
            guard let first = points.first, let last = points.last else { return }
            
            path.move(to: CGPoint(x: first.x, y: size.height / 2))
            path.addLine(to: first)
            
            for i in 0..<points.count {
                let p0 = points[max(0, i - 1)]
                let p1 = points[i]
                let p2 = points[min(points.count - 1, i + 1)]
                let p3 = points[min(points.count - 1, i + 2)]
                
                if i > 0 {
                    let cp1 = CGPoint(
                        x: p1.x + (p2.x - p0.x) / 6,
                        y: p1.y + (p2.y - p0.y) / 6
                    )
                    let cp2 = CGPoint(
                        x: p2.x - (p3.x - p1.x) / 6,
                        y: p2.y - (p3.y - p1.y) / 6
                    )
                    path.addCurve(to: p2, control1: cp1, control2: cp2)
                }
            }
            
            path.addLine(to: CGPoint(x: last.x, y: size.height / 2))
            path.closeSubpath()
        }
    }
    
    private func curvePoints(in size: CGSize) -> [CGPoint] {
        let count = eqManager.bands.count
        return eqManager.bands.enumerated().map { index, band in
            let x = size.width * CGFloat(index) / CGFloat(count - 1)
            // Map gain (-12 to +12 dB) to y position
            let normalizedGain = CGFloat(band.gain) / 12.0
            let y = size.height / 2 - (normalizedGain * size.height / 2)
            return CGPoint(x: x, y: y)
        }
    }
    
    // MARK: - Band Sliders
    
    private var bandSlidersView: some View {
        VStack(spacing: 8) {
            // dB labels on the side
            HStack(alignment: .center) {
                VStack {
                    Text("+12")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("0")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("-12")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 30, height: 180)
                
                // Sliders
                HStack(spacing: 4) {
                    ForEach(eqManager.bands) { band in
                        VStack(spacing: 8) {
                            // Gain value
                            Text(String(format: "%.0f", band.gain))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 30)
                            
                            // Vertical slider
                            VerticalSlider(
                                value: Binding(
                                    get: { band.gain },
                                    set: { eqManager.setBandGain(at: band.id, gain: $0) }
                                ),
                                range: -12...12,
                                isEnabled: eqManager.isEnabled
                            )
                            .frame(height: 150)
                            
                            // Frequency label
                            Text(band.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 8)
    }
    
    // MARK: - Presets Section
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presets")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(EQPreset.allCases) { preset in
                        PresetButton(
                            preset: preset,
                            isSelected: eqManager.currentPreset == preset,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    eqManager.currentPreset = preset
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Vertical Slider

struct VerticalSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    var isEnabled: Bool = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Track background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 6)
                
                // Filled track
                VStack {
                    Spacer()
                    
                    let normalizedValue = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                    let fillHeight = geometry.size.height * normalizedValue
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isEnabled ? Color.accentColor : Color.gray)
                        .frame(width: 6, height: max(0, fillHeight))
                }
                
                // Thumb
                let normalizedValue = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                let yPosition = geometry.size.height * (1 - normalizedValue)
                
                Circle()
                    .fill(isEnabled ? Color.accentColor : Color.gray)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .position(x: geometry.size.width / 2, y: yPosition)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                guard isEnabled else { return }
                                let newValue = 1 - (gesture.location.y / geometry.size.height)
                                let clampedValue = min(max(newValue, 0), 1)
                                value = Float(clampedValue) * (range.upperBound - range.lowerBound) + range.lowerBound
                            }
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .opacity(isEnabled ? 1 : 0.5)
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let preset: EQPreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(preset.rawValue)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    EqualizerView()
}
