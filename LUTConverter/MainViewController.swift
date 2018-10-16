//
//  ViewController.swift
//  LUTConverter
//
//  Created by Yu Ao on 2018/10/12.
//  Copyright © 2018 Meteor. All rights reserved.
//

import Cocoa
import MetalPetal

class MainViewController: NSViewController {

    @IBOutlet private weak var dropDestinationView: DropDestinationView!

    @IBOutlet private weak var activityIndicator: NSProgressIndicator!
    
    @IBOutlet private weak var dropIndicatorImageView: NSImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.dropDestinationView.allowsDrop = true
        self.dropDestinationView.draggingAcceptedHandler = { [unowned self] urls in
            self.dropDestinationView.allowsDrop = false
            self.dropIndicatorImageView.isHidden = true
            self.activityIndicator.startAnimation(nil)
            DispatchQueue.global(qos: .userInitiated).async {
                for url in urls {
                    self.processURL(url)
                }
                DispatchQueue.main.async {
                    self.dropIndicatorImageView.isHidden = false
                    self.dropDestinationView.allowsDrop = true
                    self.activityIndicator.stopAnimation(nil)
                }
            }
        }
    }
    
    let fileManager = FileManager()
    let colorLookupFilter = MTIColorLookupFilter()

    private func processURL(_ url: URL) {
        var isDirectory: ObjCBool = ObjCBool(false)
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                self.processURL(url)
            } else {
                guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                    return
                }
                guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                    return
                }
                let image = MTIImage(cgImage: cgImage, options: [.SRGB: false], isOpaque: true)
                colorLookupFilter.inputColorLookupTable = image
                guard let lookupTableInfo = colorLookupFilter.inputColorLookupTableInfo else {
                    return
                }
                
                var text =
                """
                #Created by: LUT Converter - YuAo
                TITLE "\(url.lastPathComponent)"
                
                #LUT size
                LUT_3D_SIZE \(lookupTableInfo.dimension)
                
                #data domain
                DOMAIN_MIN 0.0 0.0 0.0
                DOMAIN_MAX 1.0 1.0 1.0
                
                #LUT data points
                
                """
                
                let colorspace = CGColorSpaceCreateDeviceRGB()
                guard let buffer = malloc(Int(image.dimensions.width * image.dimensions.height * 4)) else {
                    return
                }
                defer {
                    free(buffer)
                }
                let targetURL = url.deletingPathExtension().appendingPathExtension("cube")
                let bytesPerRow = Int(image.dimensions.width * 4)
                guard let context = CGContext(data: buffer, width: Int(image.dimensions.width), height: Int(image.dimensions.height), bitsPerComponent: 8, bytesPerRow: Int(image.dimensions.width * 4), space: colorspace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else {
                    return
                }
                context.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
                let imageBuffer = buffer.assumingMemoryBound(to: UInt8.self)
                
                func appendRow(r: UInt8, g: UInt8, b: UInt8, to text: inout String) {
                    text += String(format: "%.6f %.6f %.6f\n",
                                   Float(r)/255.0,
                                   Float(g)/255.0,
                                   Float(b)/255.0)
                }
                
                switch lookupTableInfo.type {
                case .type2DSquare:
                    for slice in 0..<lookupTableInfo.dimension {
                        let row = Int(round(sqrt(Double(lookupTableInfo.dimension))))
                        let sliceX = slice % row
                        let sliceY = slice / row
                        let start = sliceY * lookupTableInfo.dimension * bytesPerRow + sliceX * lookupTableInfo.dimension * 4
                        for y in 0..<lookupTableInfo.dimension {
                            for x in 0..<lookupTableInfo.dimension {
                                let index = start + x * 4 + y * bytesPerRow
                                let valueB = imageBuffer[index]
                                let valueG = imageBuffer[index + 1]
                                let valueR = imageBuffer[index + 2]
                                appendRow(r: valueR, g: valueG, b: valueB, to: &text)
                            }
                        }
                    }
                    do {
                        try text.write(to: targetURL, atomically: true, encoding: .utf8)
                    } catch {
                        print(error)
                    }
                case .type2DHorizontalStrip:
                    for slice in 0..<lookupTableInfo.dimension {
                        let start = slice * lookupTableInfo.dimension * 4
                        for y in 0..<lookupTableInfo.dimension {
                            for x in 0..<lookupTableInfo.dimension {
                                let index = start + x * 4 + y * bytesPerRow
                                let valueB = imageBuffer[index]
                                let valueG = imageBuffer[index + 1]
                                let valueR = imageBuffer[index + 2]
                                appendRow(r: valueR, g: valueG, b: valueB, to: &text)
                            }
                        }
                    }
                    do {
                        try text.write(to: targetURL, atomically: true, encoding: .utf8)
                    } catch {
                        print(error)
                    }
                case .type2DVerticalStrip:
                    for slice in 0..<lookupTableInfo.dimension {
                        let start = slice * lookupTableInfo.dimension * bytesPerRow
                        for y in 0..<lookupTableInfo.dimension {
                            for x in 0..<lookupTableInfo.dimension {
                                let index = start + x * 4 + y * bytesPerRow
                                let valueB = imageBuffer[index]
                                let valueG = imageBuffer[index + 1]
                                let valueR = imageBuffer[index + 2]
                                appendRow(r: valueR, g: valueG, b: valueB, to: &text)
                            }
                        }
                    }
                    do {
                        try text.write(to: targetURL, atomically: true, encoding: .utf8)
                    } catch {
                        print(error)
                    }
                default: break
                }
            }
        }
    }
}

