import SwiftUI
import LinkPresentation
import UIKit

struct ContentView: View {
    // Kept on a benign page while the interface is being reviewed.
    private let runTarget = URL(string: "https://example.com/")!

    @State private var isFetching = false
    @State private var previewIcon: UIImage?
    @State private var logs: [LogEntry] = []
    @State private var provider: LPMetadataProvider?

    private let accentBlue = Color(red: 0.22, green: 0.49, blue: 0.79)
    private let panelColor = Color(uiColor: UIColor(white: 0.115, alpha: 1.0))
    private let disabledButtonColor = Color(uiColor: UIColor(white: 0.22, alpha: 1.0))
    private let disabledTextColor = Color(uiColor: UIColor(white: 0.72, alpha: 1.0))

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("CVE-2026-112621")
                    .font(.system(size: 31, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 10)

                // A single preview surface: the darker inset, title and URL are omitted.
                HStack {
                    Spacer(minLength: 0)
                    ZStack {
                        Circle()
                            .fill(Color(uiColor: UIColor(white: 0.66, alpha: 1.0)))
                            .frame(width: 54, height: 54)

                        if let previewIcon {
                            Image(uiImage: previewIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 31, height: 31)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        } else {
                            Image(systemName: "safari.fill")
                                .font(.system(size: 27, weight: .regular))
                                .foregroundStyle(Color(uiColor: UIColor(white: 0.18, alpha: 1.0)))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .frame(height: 166)
                .background(panelColor)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityLabel("Link preview")

                Button(action: fetchPreview) {
                    Text(isFetching ? "Running" : "Run PoC")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isFetching ? disabledTextColor : Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isFetching ? disabledButtonColor : accentBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isFetching)

                HStack(alignment: .center) {
                    Text("Run log")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Clear") {
                        logs.removeAll()
                    }
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .buttonStyle(.plain)
                }
                .padding(.top, 1)

                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 5) {
                            ForEach(logs) { entry in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(entry.time)
                                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.52))
                                        .frame(width: 60, alignment: .leading)
                                        .fixedSize(horizontal: true, vertical: false)

                                    Text(entry.message)
                                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.91))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                                .id(entry.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: logs.count) { _ in
                        guard let last = logs.last else { return }
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                .frame(height: 112)
                .padding(12)
                .background(panelColor)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onDisappear { provider?.cancel() }
    }

    private func fetchPreview() {
        provider?.cancel()
        previewIcon = nil
        isFetching = true
        addLog("START metadata fetch: \(runTarget.absoluteString)")

        let newProvider = LPMetadataProvider()
        provider = newProvider
        newProvider.startFetchingMetadata(for: runTarget) { result, error in
            DispatchQueue.main.async {
                self.isFetching = false
                self.provider = nil

                if let error {
                    self.addLog("ERROR metadata fetch: \(error.localizedDescription)")
                }

                if let result {
                    self.addLog("SUCCESS metadata fetch")
                    self.loadIcon(from: result.iconProvider)
                }

                if result == nil && error == nil {
                    self.addLog("EMPTY metadata result")
                }
            }
        }
    }

    private func loadIcon(from itemProvider: NSItemProvider?) {
        guard let itemProvider,
              itemProvider.canLoadObject(ofClass: UIImage.self) else {
            return
        }

        itemProvider.loadObject(ofClass: UIImage.self) { object, error in
            DispatchQueue.main.async {
                if let image = object as? UIImage {
                    self.previewIcon = image
                    self.addLog("Preview icon loaded")
                } else if let error {
                    self.addLog("Preview icon unavailable: \(error.localizedDescription)")
                }
            }
        }
    }

    private func addLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        logs.append(LogEntry(time: formatter.string(from: Date()), message: message))
    }
}

private struct LogEntry: Identifiable {
    let id = UUID()
    let time: String
    let message: String
}
