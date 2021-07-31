//
//  ViewController.swift
//  VisionPersonSegmentation
//
//  Created by LamND14.APL on 29/07/2021.
//

import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

class ViewController: UIViewController {

    @IBOutlet private weak var imageHeight: NSLayoutConstraint!
    @IBOutlet private weak var imageDisplay: UIImageView!
    @IBOutlet private weak var maskImage: UIImageView!
    @IBOutlet private weak var loadingView: UIActivityIndicatorView!
    
    private var canTap: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let onTapView = UITapGestureRecognizer(target: self, action: #selector(onTapView(_:)))
        self.view.addGestureRecognizer(onTapView)
        guard let image: UIImage = UIImage(named: "humanFace"), canTap else {
            loadingView.stopAnimating()
            return
        }
        imageHeight.constant = scaleHeightImage(image: image)
        imageDisplay.image = image
        maskImage.image = image
    }
    
    @objc
    func onTapView(_ sender: UITapGestureRecognizer) {
        loadingView.startAnimating()
        guard canTap else {
            loadingView.stopAnimating()
            return
        }
        canTap = false
        updateImage()
    }

    private func scaleHeightImage(image: UIImage) -> CGFloat {
        return self.view.frame.width / image.size.width * image.size.height
    }
    
    private func updateImage() {
        guard let cgImage = imageDisplay.image?.cgImage else {
            loadingView.stopAnimating()
            return
        }
        
        let requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        // 1.Request
        let faceRectRequest = VNGeneratePersonSegmentationRequest { (request, error) in
            self.personSegmentation(request: request, error: error)
        }
        
        faceRectRequest.qualityLevel = .accurate
        faceRectRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
        
        // 2.Request Handler
        let imageRequestHandle = VNImageRequestHandler(cgImage: cgImage,
                                                       options: requestHandlerOptions)
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try imageRequestHandle.perform([faceRectRequest])
            } catch let error {
                self.loadingView.stopAnimating()
                print(error)
            }
        }
    }
    
    private func personSegmentation(request: VNRequest, error: Error?) {
        // VNPixelBufferObservation
        guard let result = request.results?.first as? VNPixelBufferObservation else {
            loadingView.stopAnimating()
            return
        }
        // 1. Processing
        let buffer: CVPixelBuffer = result.pixelBuffer
        let maskImage: CIImage = CIImage(cvImageBuffer: buffer)
        let bgImage = UIImage(named: "background")!
        let background = CIImage(cgImage: bgImage.cgImage!)
        let input = UIImage(named: "humanFace")!
        let inputImage = CIImage(cgImage: input.cgImage!)
        
        // 2. Scale mask, and background to size of original image
        let maskScaleX = inputImage.extent.width / maskImage.extent.width
        let maskScaleY = inputImage.extent.height / maskImage.extent.height
        let maskScaled =  maskImage.transformed(by: __CGAffineTransformMake(maskScaleX, 0, 0, maskScaleY, 0, 0))
        
        let backgroundScaleX = inputImage.extent.width / background.extent.width
        let backgroundScaleY = inputImage.extent.height / background.extent.height
        let backgroundScaled =  background.transformed(by: __CGAffineTransformMake(backgroundScaleX, 0, 0, backgroundScaleY, 0, 0))
        
        // 3. Blending Image
        let blendFilter = CIFilter.blendWithRedMask()
        blendFilter.inputImage = inputImage
        blendFilter.maskImage = maskScaled
        blendFilter.backgroundImage = backgroundScaled

        // 4. Handle Result
        if let blendedImage = blendFilter.outputImage {
            let context = CIContext(options: nil)
            let maskDisplayRef = context.createCGImage(maskScaled, from: maskScaled.extent)
            let filteredImageRef = context.createCGImage(blendedImage, from: blendedImage.extent)
            DispatchQueue.main.async {
                self.imageDisplay.image = UIImage(cgImage: filteredImageRef!)
                self.maskImage.image = UIImage(cgImage: maskDisplayRef!)
                self.loadingView.stopAnimating()
            }
        }
    }
}
