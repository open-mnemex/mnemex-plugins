#!/usr/bin/env swift
import Cocoa
import Vision

// Usage: swift ocr_locate.swift <image_path> [search_text]
// If search_text is provided, only show matches containing that text
// Output: text | x,y,w,h (in image pixel coordinates)

guard CommandLine.arguments.count >= 2 else {
    print("Usage: ocr_locate.swift <image_path> [search_text]")
    exit(1)
}

let imagePath = CommandLine.arguments[1]
let searchText = CommandLine.arguments.count >= 3
    ? CommandLine.arguments[2...].joined(separator: " ")
    : nil

guard let image = NSImage(contentsOfFile: imagePath) else {
    print("ERROR: Cannot load image: \(imagePath)")
    exit(1)
}

guard let cgImage = image.cgImage(
    forProposedRect: nil, context: nil, hints: nil
) else {
    print("ERROR: Cannot convert to CGImage")
    exit(1)
}

let imgW = CGFloat(cgImage.width)
let imgH = CGFloat(cgImage.height)

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]
request.usesLanguageCorrection = true

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
try! handler.perform([request])

guard let results = request.results else {
    print("No text found")
    exit(0)
}

for observation in results {
    guard let candidate = observation.topCandidates(1).first else {
        continue
    }
    let text = candidate.string

    if let search = searchText,
       !text.localizedCaseInsensitiveContains(search) {
        continue
    }

    // Convert normalized bbox to pixel coordinates
    let bbox = observation.boundingBox
    let x = Int(bbox.origin.x * imgW)
    let y = Int((1 - bbox.origin.y - bbox.height) * imgH)
    let w = Int(bbox.width * imgW)
    let h = Int(bbox.height * imgH)
    // Center point
    let cx = x + w / 2
    let cy = y + h / 2

    print("\(text) | bbox:\(x),\(y),\(w),\(h) | center:\(cx),\(cy)")
}
