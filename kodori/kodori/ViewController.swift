import UIKit
import AVFoundation

class ViewController: UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate  {
    
    var detector: CIDetector!
    var maskImage: UIImage!
    var startDate: NSDate!
    
    var mySession: AVCaptureSession!
    var myCamera: AVCaptureDevice!
    var myVideoInput: AVCaptureDeviceInput!
    var myVideoOutput: AVCaptureVideoDataOutput!
    var detectFlag: Bool = false
    
    
    @IBOutlet weak var myImageView: UIImageView!
    @IBAction func tapStart(_ sender: AnyObject) {
        mySession.startRunning()
    }
    @IBAction func tapStop(_ sender: AnyObject) {
        mySession.stopRunning()
    }
    @IBAction func tapDetect(_ sender: AnyObject) {
        detectFlag = !detectFlag
    }
    
//    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        print("captureOutput:didOutputSampleBuffer:fromConnection)")
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = AVCaptureVideoOrientation.portrait
        }
        DispatchQueue.main.sync(execute: {
            let image = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer)
            if self.detectFlag {
                self.myImageView.image = self.detectFace(image: image)
            } else {
                self.myImageView.image = image
            }
        })
    }
    
    func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage {
        let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))   // Lock Base Address
        let baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)  // Get Original Image Information
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()  // RGB ColorSpace
        let bitmapInfo = (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        let imageRef = context!.makeImage() // Create Quarts image
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))    // Unlock Base Address
        
        let resultImage: UIImage = UIImage(cgImage: imageRef!)
        
        return resultImage
    }
    
    func prepareVideo() {
        mySession = AVCaptureSession()
        mySession.sessionPreset = AVCaptureSessionPresetHigh
        //let devices = AVCaptureDevice.devices()
        let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
/*        for device in devices! {
            if ((device as AnyObject).position == AVCaptureDevicePosition.back) {
                myCamera = device as! AVCaptureDevice
            }
        }*/
        do {
            myVideoInput = try AVCaptureDeviceInput(device: device)
            //myVideoInput = try AVCaptureDeviceInput(device: myCamera)
            if (mySession.canAddInput(myVideoInput)) {
                mySession.addInput(myVideoInput)
            } else {
                print("cannot add input to session")
            }
            
            myVideoOutput = AVCaptureVideoDataOutput()
            myVideoOutput.videoSettings =
                [ kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA) ]
                //[kCVPixelBufferPixelFormatTypeKey as AnyHashable : Int(kCVPixelFormatType_32BGRA)]
            let queue: DispatchQueue = DispatchQueue(label: "myqueue",  attributes: [])
            myVideoOutput.setSampleBufferDelegate(self,queue:queue)
            myVideoOutput.alwaysDiscardsLateVideoFrames = true
            if (mySession.canAddOutput(myVideoOutput)) {
                mySession.addOutput(myVideoOutput)
            } else {
                print("cannot add output to session")
            }
            
            /* // preview background
             let myVideoLayer = AVCaptureVideoPreviewLayer(session: mySession)
             myVideoLayer.frame = view.bounds
             myVideoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
             view.layer.insertSublayer(myVideoLayer,atIndex:0)
             */
        } catch let error as NSError {
            print("cannot use camera \(error)")
        }
    }
    
    func detectFace(image: UIImage) -> UIImage {
        let deltaTime:Double = NSDate().timeIntervalSince(startDate as Date)
        let modTime = deltaTime - Double(Int(deltaTime/4) * 4)
        let mask = rotateImage(image: maskImage!, Float(3.1415 * modTime / 2))
        
        let ciImage:CIImage! = CIImage(image: image)
        let options = [CIDetectorSmile:true]
        let features = detector.features(in: ciImage, options:options)
        UIGraphicsBeginImageContext(image.size);
        image.draw(in: CGRectMake(0,0,image.size.width,image.size.height))
        let context: CGContext = UIGraphicsGetCurrentContext()!
        context.setLineWidth(5.0);
        context.setStrokeColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        for feature in features as! [CIFaceFeature] {
            var rect:CGRect = feature.bounds;
            rect.origin.y = image.size.height - rect.origin.y - rect.height;
            if feature.hasSmile {
                context.addRect(rect);
                context.strokePath()
            } else {
                //CGContextDrawImage(context,rect,mask.cgImage)
                context.draw(mask.cgImage!, in: rect)
            }
        }
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return img!;
    }
    
    func rotateImage(image: UIImage, _ radian: Float) -> UIImage {
        let size: CGSize = image.size
        UIGraphicsBeginImageContext(size);
        let context = UIGraphicsGetCurrentContext()
        context!.translateBy(x: size.width/2, y: size.height/2) // rotation center
        context!.scaleBy(x: 1.0, y: -1.0) // flip y-coordinate
        context!.rotate(by: CGFloat(-radian))
//        CGContextDrawImage(UIGraphicsGetCurrentContext(),CGRectMake(-size.width/2,-size.height/2, size.width, size.height), image.cgImage)
        UIGraphicsGetCurrentContext()?.draw(image.cgImage!, in: CGRectMake(-size.width/2,-size.height/2, size.width, size.height))
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        detector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh])
        maskImage = UIImage(named: "LaughingMan.png")
        startDate = NSDate()
        prepareVideo()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func CGRectMake(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }

}
