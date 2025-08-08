
import Foundation
import UniformTypeIdentifiers
import UIKit
import WebKit

@MainActor
final class ConverterViewModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var selectedFileURL: URL?
    @Published var selectedFileName: String?
    @Published var selectedFileSize: String?
    @Published var generatedPDFURL: URL?
    @Published var errorMessage: String?
    @Published var isConverting = false

    private var webView: WKWebView?
    private var loadContinuation: CheckedContinuation<Void, Never>?

    func clearSelection() {
        selectedFileURL = nil
        selectedFileName = nil
        selectedFileSize = nil
        generatedPDFURL = nil
        errorMessage = nil
    }

    func handlePicked(url: URL) {
        errorMessage = nil
        generatedPDFURL = nil

        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension)

        do {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                try FileManager.default.copyItem(at: url, to: target)
            } else {
                try FileManager.default.copyItem(at: url, to: target)
            }
            selectedFileURL = target
            selectedFileName = target.lastPathComponent
            selectedFileSize = humanFileSize(for: target)
        } catch {
            errorMessage = "Couldn’t import file (\(error.localizedDescription))."
        }
    }

    func convertToPDF() async {
        guard let fileURL = selectedFileURL else {
            errorMessage = "Please choose a file first."
            return
        }
        errorMessage = nil
        generatedPDFURL = nil
        isConverting = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        self.webView = webView

        let readAccessURL = fileURL.deletingLastPathComponent()
        webView.loadFileURL(fileURL, allowingReadAccessTo: readAccessURL)

        do {
            let pdfData = try await createPDFWhenReady(webView: webView)
            let outURL = try persist(pdfData: pdfData, suggestedName: fileURL.deletingPathExtension().lastPathComponent)
            self.generatedPDFURL = outURL
        } catch {
            self.errorMessage = error.localizedDescription
        }

        self.isConverting = false
        self.webView = nil
    }

    private func createPDFWhenReady(webView: WKWebView) async throws -> Data {
        // Wait for the file to finish loading/rendering
        await waitForLoad()
        // Small extra delay to allow Quick Look to fully lay out complex docs
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        
        // Ensure the webview has a concrete, non-empty frame for PDF rendering
        if webView.bounds.isEmpty || webView.bounds.size.height < 100 {
            webView.frame = CGRect(x: 0, y: 0, width: 1024, height: 1365)
        }
        
        let config = WKPDFConfiguration()
        config.rect = webView.bounds
        return try await withCheckedThrowingContinuation { cont in
            webView.createPDF(configuration: config) { result in
                cont.resume(with: result)
            }
        }
    }

    private func waitForLoad() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            // If the page is already loaded (rare), resume immediately
            if let webView = self.webView, webView.isLoading == false {
                cont.resume()
            } else {
                self.loadContinuation = cont
            }
        }
    }

func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadContinuation?.resume()
        loadContinuation = nil
    }

    private func persist(pdfData: Data, suggestedName: String) throws -> URL {
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(suggestedName).pdf")
        try pdfData.write(to: outURL, options: .atomic)
        return outURL
    }

    func revealInFiles() {
        guard let url = generatedPDFURL else { return }
        let vc = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.rootViewController
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc?.present(activity, animated: true)
    }

    private func humanFileSize(for url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let bytes = attrs[.size] as? UInt64 else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? {
        return self.windows.first { $0.isKeyWindow }
    }
}
