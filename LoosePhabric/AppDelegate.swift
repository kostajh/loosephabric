//
//  AppDelegate.swift
//  LoosePhabric
//
//  Created by David Lynch on 6/7/24.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var timer: Timer!
    let pasteboard: NSPasteboard = .general
    var lastChangeCount: Int = 0

    var lastInputValue: String?
    var lastSetValue: String?

    let nc = NotificationCenter.default
    let publisher = NotificationCenter.default.publisher(for: Notification.Name("NSPasteboardDidChange"))

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { (t) in
            if self.lastChangeCount != self.pasteboard.changeCount {
                self.lastChangeCount = self.pasteboard.changeCount
                self.onPasteboardChanged()
            }
        }
    }

    func onPasteboardChanged() {
        guard let items = pasteboard.pasteboardItems else { return }
        guard let item = items.first else { return }
        guard let plain = item.string(forType: .string) else { return }
        
        if plain == lastInputValue || plain == lastSetValue { return }
        lastSetValue = nil
        lastInputValue = nil
        
        if let match = plain.wholeMatch(of: /T\d+(?:#\d+)?/) {
            // T12345 or T12345#54321
            fetchTitleAndSetLink(text: plain)
        }
    }

    func fetchTitleAndSetLink(text: String) {
        let urlString: String
        urlString = "https://phabricator.wikimedia.org/\(text)"

        guard let url = URL(string: urlString) else { return }

        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data, error == nil else { return }
            if let htmlString = String(data: data, encoding: .utf8),
               let titleRange = htmlString.range(of: "<title>")?.upperBound,
               let titleEndRange = htmlString.range(of: "</title>", range: titleRange..<htmlString.endIndex)?.lowerBound {
                var title = String(htmlString[titleRange..<titleEndRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                title = self.cleanUpTitle(title: title)
                DispatchQueue.main.async {
                    self.setLinkToPasteboard(text: "\(text): \(title)", URL: urlString)
                }
            }
        }

        task.resume()
    }

    func cleanUpTitle(title: String) -> String {
        // Remove the leading "⚓ " and any other unwanted parts from the title
        var cleanedTitle = title
        if cleanedTitle.hasPrefix("⚓ ") {
            cleanedTitle.removeFirst(2)
        }
        // Ensure the task ID is included and formatted correctly
        if let range = cleanedTitle.range(of: "T\\d+", options: .regularExpression) {
            let taskID = cleanedTitle[range]
            cleanedTitle = "\(cleanedTitle[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        return cleanedTitle
    }
    
    func setLinkToPasteboard(text: String, URL: String) {
        lastInputValue = text
        let attributedString = NSAttributedString(string: text, attributes: [.link: URL])
        do {
            let rtf = try attributedString.data(from: NSMakeRange(0, attributedString.length), documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.rtf])
            pasteboard.clearContents()
            pasteboard.setData(rtf, forType: .rtf)
            pasteboard.setString(text, forType: .string)
            lastSetValue = text
        } catch {
            print("Error setting pasteboard data", error)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        nc.removeObserver(self)
        timer.invalidate()
    }
}
