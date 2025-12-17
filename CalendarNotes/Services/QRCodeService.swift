//
//  QRCodeService.swift
//  CalendarNotes
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum QRCodeService {
    static func generate(from string: String) -> Data? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        let context = CIContext()
        if let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) {
            #if os(iOS)
            let cg = context.createCGImage(output, from: output.extent)
            let ui = cg.flatMap { UIImage(cgImage: $0) }
            return ui?.pngData()
            #else
            let cg = context.createCGImage(output, from: output.extent)
            if let cg = cg {
                let rep = NSBitmapImageRep(cgImage: cg)
                return rep.representation(using: .png, properties: [:])
            }
            return nil
            #endif
        }
        return nil
    }
}


