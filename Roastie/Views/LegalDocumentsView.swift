import SwiftUI
import WebKit

struct LegalDocumentView: View {
    let title: String
    let resource: String
    let fileExtension: String

    private var content: String {
        guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension.isEmpty ? nil : fileExtension),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "This document could not be loaded. Please check the project repository."
        }
        return text
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if resource == "PRIVACY" {
                    Link("View public policy", destination: URL(string: "https://github.com/JayMandava/dr-jay/blob/main/PRIVACY.md")!)
                }
                ForEach(Array(content.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, block in
                    if block.hasPrefix("#") {
                        Text(block.drop(while: { $0 == "#" || $0 == " " }))
                            .font(.headline)
                    } else {
                        Text(.init(block))
                            .font(.body)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .textSelection(.enabled)
        }
        .background(DrJayTheme.canvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(DrJayTheme.primary)
    }
}

struct LicensesView: View {
    private var dependencyNotices: [URL] {
        let directory = Bundle.main.bundleURL
            .appending(path: "Frameworks/CLiteRTLM.framework/third_party_licenses.bundle")
        return ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "html" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    var body: some View {
        List {
            Section("Dr Jay, LiteRT-LM and Gemma 4") {
                NavigationLink("Attributions") {
                    LegalDocumentView(title: "Attributions", resource: "NOTICE", fileExtension: "")
                }
                NavigationLink("Apache License 2.0") {
                    LegalDocumentView(title: "Apache License 2.0", resource: "LICENSE", fileExtension: "")
                }
            }
            Section("LiteRT-LM dependencies") {
                ForEach(dependencyNotices, id: \.self) { url in
                    NavigationLink(url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_LICENSE", with: "")) {
                        LicenseHTMLView(url: url)
                            .navigationTitle("Dependency License")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
        }
        .navigationTitle("Licenses and Notices")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LicenseHTMLView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
