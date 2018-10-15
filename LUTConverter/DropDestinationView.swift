//
//  DropDestinationView'.swift
//  CameraX-macOS
//
//  Created by Yu Ao on 2018/4/28.
//  Copyright © 2018 Meteor. All rights reserved.
//

import Foundation
import AppKit

class DropDestinationView: NSView {
    
    var draggingAcceptedHandler: (([URL]) -> Void)?
    
    var draggingAcceptanceStateChangedHandler: ((_ accept: Bool) -> Void)?
    
    var allowsDrop: Bool = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setupDropDestinationView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupDropDestinationView()
    }
    
    private func setupDropDestinationView() {
        self.registerForDraggedTypes([.fileURL])
    }
    
    private static func readableFileURLsFromPasteboard(_ pasteboard: NSPasteboard) -> [URL] {
        var readableFileURLs = [URL]()
        for item in pasteboard.pasteboardItems ?? [] {
            if item.types.contains(.fileURL) {
                if let filePath = pasteboard.propertyList(forType: .fileURL) as? String {
                    if let url = URL(string: filePath) {
                        readableFileURLs.append(url)
                    }
                }
            }
        }
        return readableFileURLs
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if !self.allowsDrop {
            return []
        }
        if let types = sender.draggingPasteboard.types {
            if types.contains(.fileURL) {
                let validItemCount = DropDestinationView.readableFileURLsFromPasteboard(sender.draggingPasteboard).count
                if validItemCount > 0 {
                    sender.numberOfValidItemsForDrop = validItemCount
                    self.draggingAcceptanceStateChangedHandler?(true)
                    return .copy
                }
            }
        }
        return []
    }
    
    override func updateDraggingItemsForDrag(_ sender: NSDraggingInfo?) {
        if let sender = sender, let types = sender.draggingPasteboard.types {
            if types.contains(.fileURL) {
                sender.enumerateDraggingItems(options: [.concurrent, .clearNonenumeratedImages], for: self, classes: [NSURL.self], searchOptions: [:], using: { (item, index, stop) in
                    
                })
            }
        }
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        self.draggingAcceptanceStateChangedHandler?(false)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let types = sender.draggingPasteboard.types {
            if types.contains(.fileURL) {
                let URLs = DropDestinationView.readableFileURLsFromPasteboard(sender.draggingPasteboard)
                if URLs.count > 0 {
                    self.draggingAcceptedHandler?(URLs)
                    return true
                }
            }
        }
        return false
    }
    
}
