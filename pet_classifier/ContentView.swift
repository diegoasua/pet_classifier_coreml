//
//  ContentView.swift
//  pet_classifier
//
//  Created by Diego Asua on 8/4/24.
//

import SwiftUI
import PhotosUI
import CoreML
import Vision

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var classificationResult: String = ""
    @State private var isImagePickerPresented: Bool = false
    
    var body: some View {
        VStack {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
            } else {
                Text("No image selected")
                    .frame(height: 300)
            }
            
            Button("Select Image") {
                isImagePickerPresented = true
            }
            .padding()
            
            Text(classificationResult)
                .padding()
        }
        .sheet(isPresented: $isImagePickerPresented) {
            ImagePicker(image: $selectedImage, completion: classifyImage)
        }
    }
    
    func classifyImage() {
        guard let image = selectedImage,
              let ciImage = CIImage(image: image) else {
            classificationResult = "Failed to prepare the image"
            return
        }
        
        do {
            let config = MLModelConfiguration()
            let model = try model_pet_classifier(configuration: config)
            let prediction = try model.prediction(image: ciImage.pixelBuffer(width: 360, height: 360)!)
            
            classificationResult = "Classification: \(prediction.target)"
        } catch {
            classificationResult = "Classification failed: \(error.localizedDescription)"
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var completion: () -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                        self.parent.completion()
                    }
                }
            }
        }
    }
}

extension CIImage {
    func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                          kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_32BGRA,
                                         attributes,
                                         &pixelBuffer)
        
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: rgbColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            return nil
        }
        
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        UIImage(ciImage: self).draw(in: rect)
        UIGraphicsPopContext()
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}
