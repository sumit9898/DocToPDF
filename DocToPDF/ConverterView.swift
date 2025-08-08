import SwiftUI
import UniformTypeIdentifiers

struct ConverterView: View {
    @StateObject private var vm = ConverterViewModel()
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Doc → PDF")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Convert Microsoft Word or Apple Pages to PDF, on‑device.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            VStack(spacing: 16) {
                if let fileName = vm.selectedFileName {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .imageScale(.large)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fileName)
                                .font(.headline)
                                .lineLimit(1)
                            if let fileSize = vm.selectedFileSize {
                                Text(fileSize)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            vm.clearSelection()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("No file selected")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        showPicker = true
                    } label: {
                        Label(vm.selectedFileName == nil ? "Choose File" : "Choose Another", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task { await vm.convertToPDF() }
                    } label: {
                        if vm.isConverting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Convert", systemImage: "arrow.right.doc.on.clipboard")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.selectedFileURL == nil || vm.isConverting)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal)

            Group {
                if let error = vm.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                } else if let pdfURL = vm.generatedPDFURL {
                    VStack(spacing: 12) {
                        Label("PDF ready: \(pdfURL.lastPathComponent)", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        HStack(spacing: 12) {
                            ShareLink(item: pdfURL) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                vm.revealInFiles()
                            } label: {
                                Label("Show in Files", systemImage: "folder.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                    }
                } else {
                    Text("Pick a file, then tap Convert.")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .sheet(isPresented: $showPicker) {
            DocumentPickerView { url in
                vm.handlePicked(url: url)
            }
        }
        .overlay(alignment: .bottom) {
            if vm.isConverting {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Converting to PDF…")
                        .font(.callout)
                        .bold()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 24)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.isConverting)
    }
}
