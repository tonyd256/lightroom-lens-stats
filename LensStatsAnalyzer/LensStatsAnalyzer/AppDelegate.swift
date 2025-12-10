import SwiftUI
import UniformTypeIdentifiers

@main
struct LensStatsAnalyzerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var progressWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        selectCatalogAndAnalyze()
    }
    
    func selectCatalogAndAnalyze() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select your Lightroom Catalog"
        openPanel.message = "Choose your .lrcat file"
        openPanel.allowedContentTypes = [UTType(filenameExtension: "lrcat")!]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        
        openPanel.begin { response in
            guard response == .OK, let catalogURL = openPanel.url else {
                NSApp.terminate(nil)
                return
            }
            
            self.selectOutputLocation(catalogURL: catalogURL)
        }
    }
    
    func selectOutputLocation(catalogURL: URL) {
        let savePanel = NSSavePanel()
        savePanel.title = "Save Statistics As"
        savePanel.nameFieldStringValue = "lens_stats.csv"
        savePanel.allowedContentTypes = [UTType.commaSeparatedText]
        
        savePanel.begin { response in
            guard response == .OK, var outputURL = savePanel.url else {
                NSApp.terminate(nil)
                return
            }
            
            // Ensure .csv extension
            if outputURL.pathExtension != "csv" {
                outputURL = outputURL.appendingPathExtension("csv")
            }
            
            self.askForTimeRange(catalogURL: catalogURL, outputURL: outputURL)
        }
    }
    
    func askForTimeRange(catalogURL: URL, outputURL: URL) {
        let alert = NSAlert()
        alert.messageText = "Time Range"
        alert.informativeText = "How many days back to analyze?"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = "365"
        alert.accessoryView = input
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let days = input.stringValue
            self.runAnalysis(catalogURL: catalogURL, outputURL: outputURL, days: days)
        } else {
            NSApp.terminate(nil)
        }
    }
    
    func runAnalysis(catalogURL: URL, outputURL: URL, days: String) {
        guard let scriptPath = Bundle.main.path(forResource: "analyze_lenses", ofType: "py") else {
            showError("Python script not found in app bundle")
            return
        }
        
        // Show progress window
        showProgressWindow()
        
        // Run in background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [
                scriptPath,
                catalogURL.path,
                outputURL.path,
                days
            ]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                DispatchQueue.main.async {
                    self.hideProgressWindow()
                    
                    if process.terminationStatus == 0 {
                        self.showSuccess(outputURL: outputURL, output: output)
                    } else {
                        self.showError("Analysis failed:\n\n\(output)")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.hideProgressWindow()
                    self.showError("Failed to run analysis: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func showProgressWindow() {
        DispatchQueue.main.async {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            window.title = "Analyzing..."
            window.center()
            window.isReleasedWhenClosed = false
            
            let contentView = NSView(frame: window.contentView!.bounds)
            
            let progressIndicator = NSProgressIndicator(frame: NSRect(x: 50, y: 40, width: 200, height: 20))
            progressIndicator.style = .bar
            progressIndicator.isIndeterminate = true
            progressIndicator.startAnimation(nil)
            
            let label = NSTextField(labelWithString: "Analyzing lens statistics...")
            label.frame = NSRect(x: 50, y: 65, width: 200, height: 20)
            label.alignment = .center
            
            contentView.addSubview(progressIndicator)
            contentView.addSubview(label)
            window.contentView = contentView
            
            window.makeKeyAndOrderFront(nil)
            self.progressWindow = window
        }
    }
    
    func hideProgressWindow() {
        DispatchQueue.main.async {
            self.progressWindow?.close()
            self.progressWindow = nil
        }
    }
    
    func showSuccess(outputURL: URL, output: String) {
        let alert = NSAlert()
        alert.messageText = "Analysis Complete!"
        alert.informativeText = "Statistics saved to:\n\(outputURL.path)"
        alert.addButton(withTitle: "Open CSV")
        alert.addButton(withTitle: "Reveal in Finder")
        alert.addButton(withTitle: "Done")
        
        // Show some stats from the output
        if let topLensesRange = output.range(of: "Top 5 most-used lenses:") {
            let statsText = String(output[topLensesRange.lowerBound...])
            if let endRange = statsText.range(of: "\n\n") {
                let stats = String(statsText[..<endRange.lowerBound])
                alert.informativeText += "\n\n" + stats
            }
        }
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(outputURL)
        case .alertSecondButtonReturn:
            NSWorkspace.shared.activateFileViewerSelecting([outputURL])
        default:
            break
        }
        
        NSApp.terminate(nil)
    }
    
    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
        NSApp.terminate(nil)
    }
}
