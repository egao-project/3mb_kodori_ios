import UIKit
import AVFoundation

class ViewController: UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate  {
    
    var detector: CIDetector!
    var maskImage: UIImage!
    var mouthImage: UIImage!
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
        self.saveImage()
    }
    @IBAction func tapDetect(_ sender: AnyObject) {
        detectFlag = !detectFlag
    }
    
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
        let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        do {
            myVideoInput = try AVCaptureDeviceInput(device: device)
            if (mySession.canAddInput(myVideoInput)) {
                mySession.addInput(myVideoInput)
            } else {
                print("cannot add input to session")
            }
            
            myVideoOutput = AVCaptureVideoDataOutput()
            myVideoOutput.videoSettings =
                [ kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA) ]
            let queue: DispatchQueue = DispatchQueue(label: "myqueue",  attributes: [])
            myVideoOutput.setSampleBufferDelegate(self,queue:queue)
            myVideoOutput.alwaysDiscardsLateVideoFrames = true
            if (mySession.canAddOutput(myVideoOutput)) {
                mySession.addOutput(myVideoOutput)
            } else {
                print("cannot add output to session")
            }
            
        } catch let error as NSError {
            print("cannot use camera \(error)")
        }
    }
    
    func detectFace(image: UIImage) -> UIImage {
        let ciImage:CIImage! = CIImage(image: image)
        //画像を180度回転
        let mask = rotateImage(image: mouthImage!, Float(180 * M_PI / 180))
        
        let options = [CIDetectorSmile:true]
        let features = detector.features(in: ciImage, options:options)
        UIGraphicsBeginImageContext(image.size);
        image.draw(in: CGRectMake(0,0,image.size.width,image.size.height))
        let context: CGContext = UIGraphicsGetCurrentContext()!
        for feature in features as! [CIFaceFeature] {
            let mrect:CGRect  = feature.bounds;
            context.draw(mask.cgImage!, in: mrect)
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
    
    // セーブを行う
    func saveImage() {
        
        // クリックした UIImageView を取得
        let targetImageView = myImageView! // sender.view! as! UIImageView
        
        // その中の UIImage を取得
        let targetImage = targetImageView.image!
        
        // UIImage の画像をカメラロールに画像を保存
        UIImageWriteToSavedPhotosAlbum(targetImage, self, #selector(self.showResultOfSaveImage(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    // 保存を試みた結果をダイアログで表示
    func showResultOfSaveImage(_ image: UIImage, didFinishSavingWithError error: NSError!, contextInfo: UnsafeMutableRawPointer) {
        
        var title = "保存完了"
        var message = "カメラロールに保存しました"
        
        if error != nil {
            title = "エラー"
            message = "保存に失敗しました"
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        // OKボタンを追加
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        // UIAlertController を表示
        self.present(alert, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        detector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh])
        maskImage = UIImage(named: "LaughingMan")
        mouthImage = UIImage(named: "rabbit")
        
        startDate = NSDate()
        prepareVideo()
        mySession.startRunning()

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func CGRectMake(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }

}
