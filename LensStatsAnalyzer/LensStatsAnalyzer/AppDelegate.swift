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
        if #available(macOS 11.0, *) {
            openPanel.allowedContentTypes = [UTType(filenameExtension: "lrcat")!]
        } else {
            openPanel.allowedFileTypes = ["lrcat"]
        }
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
        if #available(macOS 11.0, *) {
            savePanel.allowedContentTypes = [.commaSeparatedText]
        } else {
            savePanel.allowedFileTypes = ["csv"]
        }
        
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
            if let days = Int(input.stringValue), days > 0 {
                self.runAnalysis(catalogURL: catalogURL, outputURL: outputURL, days: days)
            } else {
                showError("Please enter a valid number of days")
            }
        } else {
            NSApp.terminate(nil)
        }
    }
    
    func runAnalysis(catalogURL: URL, outputURL: URL, days: Int) {
        showProgressWindow()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let analyzer = LensAnalyzer()
            
            do {
                let stats = try analyzer.analyze(catalogPath: catalogURL.path, daysBack: days)
                
                if stats.isEmpty {
                    DispatchQueue.main.async {
                        self.hideProgressWindow()
                        self.showError("No lens data found in catalog.\n\nThis could mean:\n• No photos in the specified time range\n• Photos don't have lens EXIF data\n• Catalog metadata hasn't been harvested yet")
                    }
                    return
                }
                
                try analyzer.writeCSV(stats: stats, to: outputURL)
                
                DispatchQueue.main.async {
                    self.hideProgressWindow()
                    self.showSuccess(outputURL: outputURL, stats: stats)
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.hideProgressWindow()
                    self.showError("Analysis failed: \(error.localizedDescription)")
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
    
    func showSuccess(outputURL: URL, stats: [LensStats]) {
        let alert = NSAlert()
        alert.messageText = "Analysis Complete!"
        
        var message = "Statistics saved to:\n\(outputURL.path)\n\nFound \(stats.count) lenses"
        
        if stats.count > 0 {
            message += "\n\nTop 5 most-used lenses:"
            for (index, stat) in stats.prefix(5).enumerated() {
                message += "\n\(index + 1). \(stat.lensName): \(stat.totalPhotos) photos (\(String(format: "%.1f", stat.keeperPercentage))% keepers)"
            }
        }
        
        alert.informativeText = message
        alert.addButton(withTitle: "Open CSV")
        alert.addButton(withTitle: "Reveal in Finder")
        alert.addButton(withTitle: "Done")
        
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
