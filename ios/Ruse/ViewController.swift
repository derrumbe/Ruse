//
//
//
//  Ruse
//
//  Created by Mike Kiser on 12/26/20.
//
//
//

import MLKit
import UIKit
import GPUImage
import Photos

/// Main view controller class.
@objc(ViewController)
class ViewController: UIViewController, UINavigationControllerDelegate {

  /// A string holding current results from detection.
  var resultsText = ""

  /// An overlay view that displays detection annotations.
  private lazy var annotationOverlayView: UIView = {
    precondition(isViewLoaded)
    let annotationOverlayView = UIView(frame: .zero)
    annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
    annotationOverlayView.clipsToBounds = true
    return annotationOverlayView
  }()

  /// An image picker for accessing the photo library or camera.
  var imagePicker = UIImagePickerController()

  // Image counter.
  var currentImage = 0


  /// The detector row with which detection was most recently run. Useful for inferring when to
  /// reset detector instances which use a conventional lifecyle paradigm.
  private var lastDetectorRow: DetectorPickerRow?

  // MARK: - IBOutlets

  //@IBOutlet fileprivate weak var detectorPicker: UIPickerView!
  //@IBOutlet fileprivate weak var stylePicker: UIPickerView!

  @IBOutlet fileprivate weak var imageView: UIImageView!
  @IBOutlet fileprivate weak var styleImageView: UIImageView!
  @IBOutlet fileprivate weak var photoCameraButton: UIBarButtonItem!
  @IBOutlet fileprivate weak var videoCameraButton: UIBarButtonItem!
  @IBOutlet weak var detectButton: UIBarButtonItem!
  @IBOutlet fileprivate weak var styleSlider: UISlider!
  @IBOutlet weak var segmentedControl: UISegmentedControl!
 // GPU acceleration not available below xcode 10 - and limited to particular iPhones
    // (but we're going to set it to always on)
  @IBOutlet weak var useGPUSwitch: UISwitch!
    
    /// Style transferer instance reponsible for running the TF model. Uses a Int8-based model and
    /// runs inference on the CPU.
    private var cpuStyleTransferer: StyleTransferer?

    /// Style transferer instance reponsible for running the TF model. Uses a Float16-based model and
    /// runs inference on the GPU.
    private var gpuStyleTransferer: StyleTransferer?
    


    /// Target image to transfer a style onto.
    private var targetImage: UIImage?

    /// Style-representative image applied to the input image to create a pastiche.
    private var styleImage: UIImage?
    

    /// Style transfer result.
    private var styleTransferResult: StyleTransferResult?

    
  

  // MARK: - UIViewController

  override func viewDidLoad() {
    super.viewDidLoad()
    
   
//    let transferer = gpuStyleTransferer

    
    // set default target image
    imageView.image = UIImage(named: Constants.images[currentImage])
    targetImage = UIImage(named: Constants.images[currentImage])
    
    
    // Set default style image.
    styleImage = StylePickerDataSource.defaultStyle()
    styleImageView.image = styleImage

    // set default style image
//    styleImageView.image = UIImage(named: Constants.styles[currentImage])
 //   styleImage = UIImage(named: Constants.styles[currentImage])
    
    imageView.addSubview(annotationOverlayView)
    NSLayoutConstraint.activate([
      annotationOverlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
      annotationOverlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
      annotationOverlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
      annotationOverlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
    ])

    imagePicker.delegate = self
    imagePicker.sourceType = .photoLibrary

    //detectorPicker.delegate = self
    //detectorPicker.dataSource = self

    let isCameraAvailable =
      UIImagePickerController.isCameraDeviceAvailable(.front)
      || UIImagePickerController.isCameraDeviceAvailable(.rear)
    if isCameraAvailable {
      // `CameraViewController` uses `AVCaptureDevice.DiscoverySession` which is only supported for
      // iOS 10 or newer.
      if #available(iOS 10.0, *) {
        videoCameraButton.isEnabled = true
      }
    } else {
      photoCameraButton.isEnabled = false
    }
    styleSlider.minimumValue=0
    styleSlider.maximumValue=10
    styleSlider.isContinuous = false
    //styleSlider.addTarget(self, action: self.styleSliderChange(_:)), for: .valueChanged)
    //let defaultRow = (DetectorPickerRow.rowsCount / 2) - 1
    //detectorPicker.selectRow(defaultRow, inComponent: 0, animated: false)
    /*StyleTransferer.newGPUStyleTransferer { result in
      switch result {
      case .success(let transferer):
        self.gpuStyleTransferer = transferer
      case .error(let wrappedError):
        print("Failed to initialize: \(wrappedError)")
      }
    }*/
    
    //going to default this to true (change later for flexibility)
    useGPUSwitch.isOn = true

    // Initialize new style transferer instances.
    StyleTransferer.newCPUStyleTransferer { result in
      switch result {
      case .success(let transferer):
        self.cpuStyleTransferer = transferer
      case .error(let wrappedError):
        print("Failed to initialize: \(wrappedError)")
      }
    }
    StyleTransferer.newGPUStyleTransferer { result in
      switch result {
      case .success(let transferer):
        self.gpuStyleTransferer = transferer
      case .error(let wrappedError):
        print("Failed to initialize: \(wrappedError)")
      }
    }
    
    
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    navigationController?.navigationBar.isHidden = true
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    navigationController?.navigationBar.isHidden = false
  }

  // MARK: - IBActions

    
    @IBAction func detect(_ sender: Any) {
     
        print("*************************")
        if (imageView.image?.imageOrientation == UIImage.Orientation.up) {
            print("up")
        }
        if (imageView.image?.imageOrientation == UIImage.Orientation.left) {
            print("left")
        }
        if (imageView.image?.imageOrientation == UIImage.Orientation.right) {
            print("right")
        }
        print("*************************")

        
        detectFaces(image: imageView.image)
        
        
    }


  @IBAction func openPhotoLibrary(_ sender: Any) {
    imagePicker.sourceType = .photoLibrary
    present(imagePicker, animated: true)
  }

  @IBAction func openCamera(_ sender: Any) {
    guard
      UIImagePickerController.isCameraDeviceAvailable(.front)
        || UIImagePickerController
          .isCameraDeviceAvailable(.rear)
    else {
      return
    }
    imagePicker.sourceType = .camera
    present(imagePicker, animated: true)
  }

  @IBAction func changeImage(_ sender: Any) {
    clearResults()
    currentImage = (currentImage + 1) % Constants.images.count
    imageView.image = UIImage(named: Constants.images[currentImage])
    targetImage =  UIImage(named: Constants.images[currentImage])
  }

    
    @IBAction func styleSliderChange ( sender: UISlider!) {
        print("slider changed!")
        let roundedStepValue = round(sender.value / 0.1) * 0.1
        sender.value = roundedStepValue
        print("slider value changed")
    }

    
    @IBAction func saveModifiedPhotoToRoll(_ sender: Any) {
        print("saving photo!!!!")
        /// Save current view  into Photo Library
        let cloakedPhotos = PhotoManager(albumName: "Cloaked Photos")
        
        if let myImage = getImage(from: imageView) {
            
            let photoToSave = myImage
        
            
            cloakedPhotos.save(photoToSave, completion: { result, error in
                if let e = error {
                    // handle error
                    return
                }
                // save successful, do something (such as inform user)
            })
            
        //UIImageWriteToSavedPhotosAlbum(photoToSave,  self,
         //   #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        
            //UIImageWriteToSavedPhotosAlbum(image, self,
            //#selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }

    
      // Called when image save is complete (with error or not)
      @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
          if let error = error {
              print("ERROR: \(error)")
          }
          else {
              self.showAlert("Image saved", message: "The image is saved into your Photo Library.")
          }
      }
      
      /// Show popup with title and message
      /// - Parameters:
      ///   - title: the title
      ///   - message: the message
      private func showAlert(_ title: String, message: String) {
          let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
          alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
          self.present(alert, animated: true, completion: nil)
      }

    // get image with all sublayers included
    func getImage(from view:UIView) -> UIImage? {

        defer { UIGraphicsEndImageContext() }
        UIGraphicsBeginImageContextWithOptions(view.frame.size, true, UIScreen.main.scale)
        guard let context =  UIGraphicsGetCurrentContext() else { return nil }
        view.layer.render(in: context)
        return UIGraphicsGetImageFromCurrentImageContext()

    }
    

    /// Handle tapping on different display mode: Input, Style, Result
    @IBAction func onSegmentChanged(_ sender: Any) {
      switch segmentedControl.selectedSegmentIndex {
      case 0:
        // Mode 0: Show input image
        imageView.image = targetImage
      case 1:
        // Mode 1: Show style image
        imageView.image = styleImage
      case 2:
        // Mode 2: Show style transfer result.
        //need to change this at the end **********
        imageView.image = styleTransferResult?.resultImage
      default:
        break
      }
    }
    

    @IBAction func onObfuscateButton(_ sender: Any) {
      // Make sure that the cached target image is available.
      guard targetImage != nil else {
       // self.inferenceStatusLabel.text = "Error: Input image is nil."
        return
      }

      runStyleTransfer(targetImage!)
    }
    
    /// Run style transfer on the given image (individual face), and show result on screen.
    ///  - Parameter image: The target image for style transfer.
    func runStyleTransferOnFace(_ image: UIImage) -> UIImage {
      clearResults()
        
        let shouldUseQuantizedFloat16 = useGPUSwitch.isOn
        let transferer = shouldUseQuantizedFloat16 ? gpuStyleTransferer : cpuStyleTransferer

        // Make sure that the style transferer is initialized.
        guard let styleTransferer = transferer else {
          //inference/StatusLabel.text = "ERROR: Interpreter is not ready."
          return image
        }
        
        // Center-crop the target image if the user has enabled the option.
        //let willCenterCrop = cropSwitch.isOn
        let image = image.cropCenter()

   

 
        // Make sure that the image is ready before running style transfer.
        guard image != nil else {
          //inferenceStatusLabel.text = "ERROR: Image could not be cropped."
          return image!
        }

        guard let styleImage = styleImage else {
          //inferenceStatusLabel.text = "ERROR: Select a style image."
          return image!
        }


        var faceResult = image
        // Run style transfer.
        styleTransferer.runStyleTransfer(
          style: styleImage,
          image: image!,
          contentBlendRatio : (1 - styleSlider.value / 10),
          completion: { result in
            // Show the result on screen
            switch result {
            case let .success(styleTransferResult):
              faceResult = styleTransferResult.resultImage
              

              // Change to show style transfer result
              //self.segmentedControl.selectedSegmentIndex = 2
              //self.onSegmentChanged(self)

              // Show result metadata
              //self.showInferenceTime(styleTransferResult)
            case let .error(error):
              print(" transfer didn't work")
            // self.inferenceStatusLabel.text = error.localizedDescription
            }
              print("*****suceeded with style!****")

            // Regardless of the result, re-enable switching between different display modes
            self.segmentedControl.isEnabled = true
            //self.cropSwitch.isEnabled = true
            //self.runButton.isEnabled = true
          })
        
        
        
      return faceResult!
    }
    
    
    /// Run style transfer on the given image, and show result on screen.
    ///  - Parameter image: The target image for style transfer.
    func runStyleTransfer(_ image: UIImage) {
      clearResults()

      let shouldUseQuantizedFloat16 = useGPUSwitch.isOn
      let transferer = shouldUseQuantizedFloat16 ? gpuStyleTransferer : cpuStyleTransferer

      // Make sure that the style transferer is initialized.
      guard let styleTransferer = transferer else {
        //inferenceStatusLabel.text = "ERROR: Interpreter is not ready."
        return
      }

      guard let targetImage = self.targetImage else {
        //inferenceStatusLabel.text = "ERROR: Select a target image."
        return
      }

      // Center-crop the target image if the user has enabled the option.
      //let willCenterCrop = cropSwitch.isOn
      //let image = targetImage.cropCenter()

      // Cache the potentially cropped image.
      //self.targetImage = image

      // Show the potentially cropped image on screen.
      //imageView.image = image
       // imageView.image=targetImage

      // Make sure that the image is ready before running style transfer.
      guard image != nil else {
        //inferenceStatusLabel.text = "ERROR: Image could not be cropped."
        return
      }

      guard let styleImage = styleImage else {
        //inferenceStatusLabel.text = "ERROR: Select a style image."
        return
      }

      // Lock the crop switch and run buttons while style transfer is running.
      //cropSwitch.isEnabled = false
      //runButton.isEnabled = false

      // Run style transfer.
      styleTransferer.runStyleTransfer(
        style: styleImage,
        image: image,
        contentBlendRatio : (1 - styleSlider.value / 10),
        completion: { result in
          // Show the result on screen
          switch result {
          case let .success(styleTransferResult):
            self.styleTransferResult = styleTransferResult
            

            // Change to show style transfer result
            self.segmentedControl.selectedSegmentIndex = 2
            self.onSegmentChanged(self)
            //self.styleTransferResult = UIImage(styleTransferResult.resultImage)

            // Show result metadata
            //self.showInferenceTime(styleTransferResult)
          case let .error(error):
            print(" transfer didn't work")
          // self.inferenceStatusLabel.text = error.localizedDescription
          }
            print("*****suceeded with style!****")

          // Regardless of the result, re-enable switching between different display modes
          self.segmentedControl.isEnabled = true
          //self.cropSwitch.isEnabled = true
          //self.runButton.isEnabled = true
        })
    }

    
    @IBAction func onTapChangeStyleButton(_ sender: Any) {
      let pickerController = StylePickerViewController.fromStoryboard()
      pickerController.delegate = self
      present(pickerController, animated: true, completion: nil)
    }
    
    class PhotoManager {

        private var albumName: String
        private var album: PHAssetCollection?

        init(albumName: String) {
            self.albumName = albumName

            if let album = getAlbum() {
                self.album = album
                return
            }
        }

        private func getAlbum() -> PHAssetCollection? {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "title = %@", albumName)
            let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
            return collection.firstObject ?? nil
        }

        private func createAlbum(completion: @escaping (Bool) -> ()) {
            PHPhotoLibrary.shared().performChanges({
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumName)
            }, completionHandler: { (result, error) in
                if let error = error {
                    print("error: \(error.localizedDescription)")
                } else {
                    self.album = self.getAlbum()
                    completion(result)
                }
            })
        }

        private func add(image: UIImage, completion: @escaping (Bool, Error?) -> ()) {
            PHPhotoLibrary.shared().performChanges({
                let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                if let album = self.album, let placeholder = assetChangeRequest.placeholderForCreatedAsset {
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                    let enumeration = NSArray(object: placeholder)
                    albumChangeRequest?.addAssets(enumeration)
                }
            }, completionHandler: { (result, error) in
                completion(result, error)
            })
        }

        func save(_ image: UIImage, completion: @escaping (Bool, Error?) -> ()) {
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized else {
                    // fail and redirect to app settings
                    return
                }

                if let _ = self.album {
                    self.add(image: image) { (result, error) in
                        completion(result, error)
                    }
                    return
                }

                self.createAlbum(completion: { _ in
                    self.add(image: image) { (result, error) in
                        completion(result, error)
                    }
                })
            }
        }
    }

    
    
    
  @IBAction func downloadOrDeleteModel(_ sender: Any) {
    clearResults()
  }

    @IBAction func clearDetectionResults(_ sender: Any) {
       clearResults()
    }
    
  
  // TK: Classification function to check for actual matching of base photo against target set
  // Basic training should be done on the device itself (but it's still too limited to be refined to real usability.)
    
  // MARK: - Private

  /// Removes the detection annotations from the annotation overlay view.
  private func removeDetectionAnnotations() {
    for annotationView in annotationOverlayView.subviews {
      annotationView.removeFromSuperview()
    }
  }

  /// Clears the results text view and removes any frames that are visible.
  private func clearResults() {
    removeDetectionAnnotations()
    self.resultsText = ""
  }

  private func showResults() {
    let resultsAlertController = UIAlertController(
      title: "Detection Results",
      message: nil,
      preferredStyle: .actionSheet
    )
    resultsAlertController.addAction(
      UIAlertAction(title: "OK", style: .destructive) { _ in
        resultsAlertController.dismiss(animated: true, completion: nil)
      }
    )
    resultsAlertController.message = resultsText
    resultsAlertController.popoverPresentationController?.barButtonItem = detectButton
    resultsAlertController.popoverPresentationController?.sourceView = self.view
    present(resultsAlertController, animated: true, completion: nil)
    print(resultsText)
  }

  /// Updates the image view with a scaled version of the given image.
  private func updateImageView(with image: UIImage) {
    
    //let image = image.cropCenter()!

    
    let orientation = UIApplication.shared.statusBarOrientation

    var scaledImageWidth: CGFloat = 0.0
    var scaledImageHeight: CGFloat = 0.0
    switch orientation {
    case .portrait, .portraitUpsideDown, .unknown:
      scaledImageWidth = imageView.bounds.size.width
      scaledImageHeight = image.size.height * scaledImageWidth / image.size.width
    case .landscapeLeft, .landscapeRight:
      scaledImageWidth = image.size.width * scaledImageHeight / image.size.height
      scaledImageHeight = imageView.bounds.size.height
    @unknown default:
      fatalError()
    }
    

    weak var weakSelf = self
    DispatchQueue.global(qos: .userInitiated).async {
      // Scale image while maintaining aspect ratio so it displays better in the UIImageView.
      var scaledImage = image.scaledImage(
        with: CGSize(width: scaledImageWidth, height: scaledImageHeight)
      )
      scaledImage = scaledImage ?? image
      guard let finalImage = scaledImage else { return }
      DispatchQueue.main.async {
        weakSelf?.imageView.image = finalImage
        self.targetImage = finalImage
      }
    }
  }

  private func transformMatrix() -> CGAffineTransform {
    guard let image = imageView.image else { return CGAffineTransform() }
    let imageViewWidth = imageView.frame.size.width
    let imageViewHeight = imageView.frame.size.height
    let imageWidth = image.size.width
    let imageHeight = image.size.height

    let imageViewAspectRatio = imageViewWidth / imageViewHeight
    let imageAspectRatio = imageWidth / imageHeight
    let scale =
      (imageViewAspectRatio > imageAspectRatio)
      ? imageViewHeight / imageHeight : imageViewWidth / imageWidth

    // Image view's `contentMode` is `scaleAspectFit`, which scales the image to fit the size of the
    // image view by maintaining the aspect ratio. Multiple by `scale` to get image's original size.
    let scaledImageWidth = imageWidth * scale
    let scaledImageHeight = imageHeight * scale
    let xValue = (imageViewWidth - scaledImageWidth) / CGFloat(2.0)
    let yValue = (imageViewHeight - scaledImageHeight) / CGFloat(2.0)

    var transform = CGAffineTransform.identity.translatedBy(x: xValue, y: yValue)
    transform = transform.scaledBy(x: scale, y: scale)
    return transform
  }

  private func pointFrom(_ visionPoint: VisionPoint) -> CGPoint {
    return CGPoint(x: visionPoint.x, y: visionPoint.y)
  }

  private func addContours(forFace face: Face, transform: CGAffineTransform) {
    // Face
    if let faceContour = face.contour(ofType: .face) {
      for point in faceContour.points {
        let transformedPoint = pointFrom(point).applying(transform)
        UIUtilities.addCircle(
          atPoint: transformedPoint,
          to: annotationOverlayView,
          color: UIColor.yellow,
          radius: Constants.smallDotRadius
        )
      }
    }

    // Eyebrows
    if let topLeftEyebrowContour = face.contour(ofType: .leftEyebrowTop) {
      for point in topLeftEyebrowContour.points {
        let transformedPoint = pointFrom(point).applying(transform)
        UIUtilities.addCircle(
          atPoint: transformedPoint,
          to: annotationOverlayView,
          color: UIColor.yellow,
          radius: Constants.smallDotRadius
        )
      }
    }
    if let bottomLeftEyebrowContour = face.contour(ofType: .leftEyebrowBottom) {
      for point in bottomLeftEyebrowContour.points {
        let transformedPoint = pointFrom(point).applying(transform)
        UIUtilities.addCircle(
          atPoint: transformedPoint,
          to: annotationOverlayView,
          color: UIColor.yellow,
          radius: Constants.smallDotRadius
        )
      }
    }
    if let topRightEyebrowContour = face.contour(ofType: .rightEyebrowTop) {
      for point in topRightEyebrowContour.points {
        let transformedPoint = pointFrom(point).applying(transform)
        UIUtilities.addCircle(
          atPoint: transformedPoint,
          to: annotationOverlayView,
          color: UIColor.yellow,
          radius: Constants.smallDotRadius
        )
      }
    }
    if let bottomRightEyebrowContour = face.contour(ofType: .rightEyebrowBottom) {
      for point in bottomRightEyebrowContour.points {
        let transformedPoint = pointFrom(point).applying(transform)
        UIUtilities.addCircle(
          atPoint: transformedPoint,
          to: annotationOverlayView,
          color: UIColor.yellow,
          radius: Constants.smallDotRadius
        )
      }
    }

    // Eyes
    if let leftEyeContour = face.contour(ofType: .leftEye) {
      for point in leftEyeContour.points {
        let transformedPoint = pointFrom(point).applying(transform)
        UIUtilities.addCircle(
          atPoint: transformedPoint,
          to: annotationOverlayView,
          color: UIColor.yellow,
          radius: Constants.smallDotRadius)
      }
    }
    if let rightEyeContour = face.contour(ofType: .rightEye) {
      for point in rightEyeContour.points {
        let transformedPoint = pointFrom(point).applying(transform)
        UIUtilities.addCircle(
          atPoint: transformedPoint,
          to: annotationOverlayView,
          color: UIColor.yellow,
          radius: Constants.smallDotRadius
        )
      }
    }

    // Lips
    if let topUpperLipContour = face.contour(ofType: .upperLipTop) {
      for point in topUpperLipContour.points {
        let transformedPoint = pointFrom(point).applying(transform)
        UIUtilities.addCircle(
          atPoint: transformedPoint,
          to: annotationOverlayView,
          color: UIColor.yellow,
          radius: Constants.smallDotRadius
        )
      }
    }
    if let bottomUpperLipContour = face.contour(ofType: .upperLipBottom) {
      for point in bottomUpperLipContour.points {
        let transformedPoint = pointFrom(point).applying(transform)
        UIUtilities.addCircle(
          atPoint: transformedPoint,
          to: annotationOverlayView,
          color: UIColor.yellow,
          radius: Constants.smallDotRadius
        )
      }
    }
    if let topLowerLipContour = face.contour(ofType: .lowerLipTop) {
      for point in topLowerLipContour.points {
        let transformedPoint = pointFrom(point).applying(transform)
        UIUtilities.addCircle(
          atPoint: transformedPoint,
          to: annotationOverlayView,
          color: UIColor.yellow,
          radius: Constants.smallDotRadius
        )
      }
    }
    if let bottomLowerLipContour = face.contour(ofType: .lowerLipBottom) {
      for point in bottomLowerLipContour.points {
        let transformedPoint = pointFrom(point).applying(transform)
        UIUtilities.addCircle(
          atPoint: transformedPoint,
          to: annotationOverlayView,
          color: UIColor.yellow,
          radius: Constants.smallDotRadius
        )
      }
    }

    // Nose
    if let noseBridgeContour = face.contour(ofType: .noseBridge) {
      for point in noseBridgeContour.points {
        let transformedPoint = pointFrom(point).applying(transform)
        UIUtilities.addCircle(
          atPoint: transformedPoint,
          to: annotationOverlayView,
          color: UIColor.yellow,
          radius: Constants.smallDotRadius
        )
      }
    }
    if let noseBottomContour = face.contour(ofType: .noseBottom) {
      for point in noseBottomContour.points {
        let transformedPoint = pointFrom(point).applying(transform)
        UIUtilities.addCircle(
          atPoint: transformedPoint,
          to: annotationOverlayView,
          color: UIColor.yellow,
          radius: Constants.smallDotRadius
        )
      }
    }
  }

  private func addLandmarks(forFace face: Face, transform: CGAffineTransform) {
    // Mouth
    if let bottomMouthLandmark = face.landmark(ofType: .mouthBottom) {
      let point = pointFrom(bottomMouthLandmark.position)
      let transformedPoint = point.applying(transform)
      UIUtilities.addCircle(
        atPoint: transformedPoint,
        to: annotationOverlayView,
        color: UIColor.red,
        radius: Constants.largeDotRadius
      )
    }
    if let leftMouthLandmark = face.landmark(ofType: .mouthLeft) {
      let point = pointFrom(leftMouthLandmark.position)
      let transformedPoint = point.applying(transform)
      UIUtilities.addCircle(
        atPoint: transformedPoint,
        to: annotationOverlayView,
        color: UIColor.red,
        radius: Constants.largeDotRadius
      )
    }
    if let rightMouthLandmark = face.landmark(ofType: .mouthRight) {
      let point = pointFrom(rightMouthLandmark.position)
      let transformedPoint = point.applying(transform)
      UIUtilities.addCircle(
        atPoint: transformedPoint,
        to: annotationOverlayView,
        color: UIColor.red,
        radius: Constants.largeDotRadius
      )
    }

    // Nose
    if let noseBaseLandmark = face.landmark(ofType: .noseBase) {
      let point = pointFrom(noseBaseLandmark.position)
      let transformedPoint = point.applying(transform)
      UIUtilities.addCircle(
        atPoint: transformedPoint,
        to: annotationOverlayView,
        color: UIColor.yellow,
        radius: Constants.largeDotRadius
      )
    }

    // Eyes
    if let leftEyeLandmark = face.landmark(ofType: .leftEye) {
      let point = pointFrom(leftEyeLandmark.position)
      let transformedPoint = point.applying(transform)
      UIUtilities.addCircle(
        atPoint: transformedPoint,
        to: annotationOverlayView,
        color: UIColor.cyan,
        radius: Constants.largeDotRadius
      )
    }
    if let rightEyeLandmark = face.landmark(ofType: .rightEye) {
      let point = pointFrom(rightEyeLandmark.position)
      let transformedPoint = point.applying(transform)
      UIUtilities.addCircle(
        atPoint: transformedPoint,
        to: annotationOverlayView,
        color: UIColor.cyan,
        radius: Constants.largeDotRadius
      )
    }

    // Ears
    if let leftEarLandmark = face.landmark(ofType: .leftEar) {
      let point = pointFrom(leftEarLandmark.position)
      let transformedPoint = point.applying(transform)
      UIUtilities.addCircle(
        atPoint: transformedPoint,
        to: annotationOverlayView,
        color: UIColor.purple,
        radius: Constants.largeDotRadius
      )
    }
    if let rightEarLandmark = face.landmark(ofType: .rightEar) {
      let point = pointFrom(rightEarLandmark.position)
      let transformedPoint = point.applying(transform)
      UIUtilities.addCircle(
        atPoint: transformedPoint,
        to: annotationOverlayView,
        color: UIColor.purple,
        radius: Constants.largeDotRadius
      )
    }

    // Cheeks
    if let leftCheekLandmark = face.landmark(ofType: .leftCheek) {
      let point = pointFrom(leftCheekLandmark.position)
      let transformedPoint = point.applying(transform)
      UIUtilities.addCircle(
        atPoint: transformedPoint,
        to: annotationOverlayView,
        color: UIColor.orange,
        radius: Constants.largeDotRadius
      )
    }
    if let rightCheekLandmark = face.landmark(ofType: .rightCheek) {
      let point = pointFrom(rightCheekLandmark.position)
      let transformedPoint = point.applying(transform)
      UIUtilities.addCircle(
        atPoint: transformedPoint,
        to: annotationOverlayView,
        color: UIColor.orange,
        radius: Constants.largeDotRadius
      )
    }
  }


}

extension ViewController: UIPickerViewDataSource, UIPickerViewDelegate {

  // MARK: - UIPickerViewDataSource

  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    return DetectorPickerRow.componentsCount
  }

  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    return DetectorPickerRow.rowsCount
  }

  // MARK: - UIPickerViewDelegate

  func pickerView(
    _ pickerView: UIPickerView,
    titleForRow row: Int,
    forComponent component: Int
  ) -> String? {
    return DetectorPickerRow(rawValue: row)?.description
  }

  func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    clearResults()
  }
}

// MARK: - UIImagePickerControllerDelegate

extension ViewController: UIImagePickerControllerDelegate {

  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    // Local variable inserted by Swift 4.2 migrator.
    let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

    clearResults()
    if let pickedImage =
      info[
        convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)]
      as? UIImage
    {

        targetImage=pickedImage

        targetImage = targetImage!.correctlyOrientedImage()
        targetImage = targetImage!.cropCenter()
        targetImage = UIImage(cgImage: targetImage!.cgImage!, scale: targetImage!.scale, orientation: .up)
        //targetImage?.imageOrientation = UIImage.Orientation.UIImageOrientationUp
        imageView.image = targetImage
        


        
        
        //print(targetImage!.imageOrientation)
        
        
        //imageView.contentMode = .scaleAspectFit
        //updateImageView(with: pickedImage)
    }
    dismiss(animated: true)
  }
}

/// Extension of ViewController for On-Device detection.
extension ViewController {

  // MARK: - Vision On-Device Detection

  /// Detects faces on the specified image and draws a frame around the detected faces using
  /// On-Device face API.
  ///
  /// - Parameter image: The image.
  func detectFaces(image: UIImage?) {
    guard let image = image else { return }

    // Create a face detector with options.
    // [START config_face]
    let options = FaceDetectorOptions()
    options.landmarkMode = .none
  //  options.classificationMode = .all
    options.performanceMode = .accurate
    options.contourMode = .all
    options.isTrackingEnabled = true
    // [END config_face]

    // [START init_face]
    let faceDetector = FaceDetector.faceDetector(options: options)
    // [END init_face]

    // Initialize a VisionImage object with the given UIImage.
    let visionImage = VisionImage(image: image)
    visionImage.orientation = image.imageOrientation

    


    // [START detect_faces]
    weak var weakSelf = self
    faceDetector.process(visionImage) { faces, error in
      guard let strongSelf = weakSelf else {
        print("Self is nil!")
        return
      }
      guard error == nil, let faces = faces, !faces.isEmpty else {
        // [START_EXCLUDE]
        let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
        strongSelf.resultsText = "On-Device face detection failed with error: \(errorString)"
        strongSelf.showResults()
        // [END_EXCLUDE]
        return
      }

      // Faces detected
      // [START_EXCLUDE]
      faces.forEach { face in
        
        // we have a face in "face" at this point.
        // we need to:
        // (1) normalize the face to whatever standard we need to apply
        // (2) compare it to several other faces
        // (3) introduce variance to the face
        //
        
        //this is commented out for a moment - it makes the face match the scale of the photo i think
        let transform = strongSelf.transformMatrix()
        let transformedRect = face.frame.applying(transform)
        
        // adds rectangle around the face
        UIUtilities.addRectangle(
          transformedRect,
            //face.frame,
          to: strongSelf.annotationOverlayView,
          color: UIColor.green
        )
        strongSelf.addLandmarks(forFace: face, transform: transform)
        strongSelf.addContours(forFace: face, transform: transform)
        //do transform on face only?
        
        
        
        print("FACE: face\n")
      }
      strongSelf.resultsText = faces.map { face in
        let headEulerAngleX = face.hasHeadEulerAngleX ? face.headEulerAngleX.description : "NA"
        let headEulerAngleY = face.hasHeadEulerAngleY ? face.headEulerAngleY.description : "NA"
        let headEulerAngleZ = face.hasHeadEulerAngleZ ? face.headEulerAngleZ.description : "NA"
        let leftEyeOpenProbability =
          face.hasLeftEyeOpenProbability
          ? face.leftEyeOpenProbability.description : "NA"
        let rightEyeOpenProbability =
          face.hasRightEyeOpenProbability
          ? face.rightEyeOpenProbability.description : "NA"
        let smilingProbability =
          face.hasSmilingProbability
          ? face.smilingProbability.description : "NA"
        let output = """
          Frame: \(face.frame)
          Head Euler Angle X: \(headEulerAngleX)
          Head Euler Angle Y: \(headEulerAngleY)
          Head Euler Angle Z: \(headEulerAngleZ)
          Left Eye Open Probability: \(leftEyeOpenProbability)
          Right Eye Open Probability: \(rightEyeOpenProbability)
          Smiling Probability: \(smilingProbability)
          """
        return "\(output)"
      }.joined(separator: "\n")
      strongSelf.showResults()
      // [END_EXCLUDE]
    }
    // [END detect_faces]
  }
/*
  /// Detects poses on the specified image and draw pose landmark points and line segments using
  /// the On-Device face API.
  ///
  /// - Parameter image: The image.
  func detectPose(image: UIImage?) {
    guard let image = image else { return }

    // Initialize a VisionImage object with the given UIImage.
    let visionImage = VisionImage(image: image)
    visionImage.orientation = image.imageOrientation

    if let poseDetector = self.poseDetector {
      poseDetector.process(visionImage) { poses, error in
        guard error == nil, let poses = poses, !poses.isEmpty else {
          let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
          self.resultsText = "Pose detection failed with error: \(errorString)"
          self.showResults()
          return
        }
        let transform = self.transformMatrix()

        // Pose detected. Currently, only single person detection is supported.
        poses.forEach { pose in
          for (startLandmarkType, endLandmarkTypesArray) in UIUtilities.poseConnections() {
            let startLandmark = pose.landmark(ofType: startLandmarkType)
            for endLandmarkType in endLandmarkTypesArray {
              let endLandmark = pose.landmark(ofType: endLandmarkType)
              let transformedStartLandmarkPoint = self.pointFrom(startLandmark.position).applying(
                transform)
              let transformedEndLandmarkPoint = self.pointFrom(endLandmark.position).applying(
                transform)
              UIUtilities.addLineSegment(
                fromPoint: transformedStartLandmarkPoint,
                toPoint: transformedEndLandmarkPoint,
                inView: self.annotationOverlayView,
                color: UIColor.green,
                width: Constants.lineWidth
              )
            }
          }
          for landmark in pose.landmarks {
            let transformedPoint = self.pointFrom(landmark.position).applying(transform)
            UIUtilities.addCircle(
              atPoint: transformedPoint,
              to: self.annotationOverlayView,
              color: UIColor.blue,
              radius: Constants.smallDotRadius
            )
          }
          self.resultsText = "Pose Detected"
          self.showResults()
        }
      }
    }
  }


     /// Detects barcodes on the specified image and draws a frame around the detected barcodes using
  /// On-Device barcode API.
  ///
  /// - Parameter image: The image.
  func detectBarcodes(image: UIImage?) {
    guard let image = image else { return }

    // Define the options for a barcode detector.
    // [START config_barcode]
    let format = BarcodeFormat.all
    let barcodeOptions = BarcodeScannerOptions(formats: format)
    // [END config_barcode]

    // Create a barcode scanner.
    // [START init_barcode]
    let barcodeScanner = BarcodeScanner.barcodeScanner(options: barcodeOptions)
    // [END init_barcode]

    // Initialize a VisionImage object with the given UIImage.
    let visionImage = VisionImage(image: image)
    visionImage.orientation = image.imageOrientation

    // [START detect_barcodes]
    weak var weakSelf = self
    barcodeScanner.process(visionImage) { features, error in
      guard let strongSelf = weakSelf else {
        print("Self is nil!")
        return
      }
      guard error == nil, let features = features, !features.isEmpty else {
        // [START_EXCLUDE]
        let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
        strongSelf.resultsText = "On-Device barcode detection failed with error: \(errorString)"
        strongSelf.showResults()
        // [END_EXCLUDE]
        return
      }

      // [START_EXCLUDE]
      features.forEach { feature in
        let transformedRect = feature.frame.applying(strongSelf.transformMatrix())
        UIUtilities.addRectangle(
          transformedRect,
          to: strongSelf.annotationOverlayView,
          color: UIColor.green
        )
      }
      strongSelf.resultsText = features.map { feature in
        return "DisplayValue: \(feature.displayValue ?? ""), RawValue: "
          + "\(feature.rawValue ?? ""), Frame: \(feature.frame)"
      }.joined(separator: "\n")
      strongSelf.showResults()
      // [END_EXCLUDE]
    }
    // [END detect_barcodes]
  }*/

    /*
  /// Detects labels on the specified image using On-Device label API.
  ///
  /// - Parameter image: The image.
  /// - Parameter shouldUseCustomModel: Whether to use the custom image labeling model.
  func detectLabels(image: UIImage?, shouldUseCustomModel: Bool) {
    guard let image = image else { return }

    // [START config_label]
    var options: CommonImageLabelerOptions!
    if shouldUseCustomModel {
      guard
        let localModelFilePath = Bundle.main.path(
          forResource: Constants.localModelFile.name,
          ofType: Constants.localModelFile.type
        )
      else {
        self.resultsText = "On-Device label detection failed because custom model was not found."
        self.showResults()
        return
      }
      let localModel = LocalModel(path: localModelFilePath)
      options = CustomImageLabelerOptions(localModel: localModel)
    } else {
      options = ImageLabelerOptions()
    }
    options.confidenceThreshold = NSNumber(floatLiteral: Constants.labelConfidenceThreshold)
    // [END config_label]

    // [START init_label]
    let onDeviceLabeler = ImageLabeler.imageLabeler(options: options)
    // [END init_label]

    // Initialize a VisionImage object with the given UIImage.
    let visionImage = VisionImage(image: image)
    visionImage.orientation = image.imageOrientation

    // [START detect_label]
    weak var weakSelf = self
    onDeviceLabeler.process(visionImage) { labels, error in
      guard let strongSelf = weakSelf else {
        print("Self is nil!")
        return
      }
      guard error == nil, let labels = labels, !labels.isEmpty else {
        // [START_EXCLUDE]
        let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
        strongSelf.resultsText = "On-Device label detection failed with error: \(errorString)"
        strongSelf.showResults()
        // [END_EXCLUDE]
        return
      }

      // [START_EXCLUDE]
      strongSelf.resultsText = labels.map { label -> String in
        return "Label: \(label.text), Confidence: \(label.confidence), Index: \(label.index)"
      }.joined(separator: "\n")
      strongSelf.showResults()
      // [END_EXCLUDE]
    }
    // [END detect_label]
  }

  /// Detects text on the specified image and draws a frame around the recognized text using the
  /// On-Device text recognizer.
  ///
  /// - Parameter image: The image.
  func detectTextOnDevice(image: UIImage?) {
    guard let image = image else { return }

    // [START init_text]
    let onDeviceTextRecognizer = TextRecognizer.textRecognizer()
    // [END init_text]

    // Initialize a VisionImage object with the given UIImage.
    let visionImage = VisionImage(image: image)
    visionImage.orientation = image.imageOrientation

    self.resultsText += "Running On-Device Text Recognition...\n"
    process(visionImage, with: onDeviceTextRecognizer)
  }

  /// Detects objects on the specified image and draws a frame around them.
  ///
  /// - Parameter image: The image.
  /// - Parameter options: The options for object detector.
  private func detectObjectsOnDevice(in image: UIImage?, options: CommonObjectDetectorOptions) {
    guard let image = image else { return }

    // Initialize a VisionImage object with the given UIImage.
    let visionImage = VisionImage(image: image)
    visionImage.orientation = image.imageOrientation

    // [START init_object_detector]
    // Create an objects detector with options.
    let detector = ObjectDetector.objectDetector(options: options)
    // [END init_object_detector]

    // [START detect_object]
    weak var weakSelf = self
    detector.process(visionImage) { objects, error in
      guard let strongSelf = weakSelf else {
        print("Self is nil!")
        return
      }
      guard error == nil else {
        // [START_EXCLUDE]
        let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
        strongSelf.resultsText = "Object detection failed with error: \(errorString)"
        strongSelf.showResults()
        // [END_EXCLUDE]
        return
      }
      guard let objects = objects, !objects.isEmpty else {
        // [START_EXCLUDE]
        strongSelf.resultsText = "On-Device object detector returned no results."
        strongSelf.showResults()
        // [END_EXCLUDE]
        return
      }

      objects.forEach { object in
        // [START_EXCLUDE]
        let transform = strongSelf.transformMatrix()
        let transformedRect = object.frame.applying(transform)
        UIUtilities.addRectangle(
          transformedRect,
          to: strongSelf.annotationOverlayView,
          color: .green
        )
        // [END_EXCLUDE]
      }

      // [START_EXCLUDE]
      strongSelf.resultsText = objects.map { object in
        var description = "Frame: \(object.frame)\n"
        if let trackingID = object.trackingID {
          description += "Object ID: " + trackingID.stringValue + "\n"
        }
        description += object.labels.enumerated().map { (index, label) in
          "Label \(index): \(label.text), \(label.confidence), \(label.index)"
        }.joined(separator: "\n")
        return description
      }.joined(separator: "\n")

      strongSelf.showResults()
      // [END_EXCLUDE]
    }
    // [END detect_object]
  }
*/
    
  /// Resets any detector instances which use a conventional lifecycle paradigm. This method should
  /// be invoked immediately prior to performing detection. This approach is advantageous to tearing
  /// down old detectors in the `UIPickerViewDelegate` method because that method isn't actually
  /// invoked in-sync with when the selected row changes and can result in tearing down the wrong
  /// detector in the event of a race condition.
  private func resetManagedLifecycleDetectors(activeDetectorRow: DetectorPickerRow) {
    if activeDetectorRow == self.lastDetectorRow {
      // Same row as before, no need to reset any detectors.
      return
    }
    // Clear the old detector, if applicable.
    switch self.lastDetectorRow {
/*    case .detectPose, .detectPoseAccurate:
      self.poseDetector = nil
      break
    default:
      break
    }
    // Initialize the new detector, if applicable.
    switch activeDetectorRow {
    case .detectPose, .detectPoseAccurate:
      let options =
        activeDetectorRow == .detectPose
        ? PoseDetectorOptions()
        : AccuratePoseDetectorOptions()
      options.detectorMode = .singleImage
      self.poseDetector = PoseDetector.poseDetector(options: options)
      break*/
    default:
      break
    }
    self.lastDetectorRow = activeDetectorRow
  }
}

    
// MARK: - Enums

private enum DetectorPickerRow: Int {
  case detectFaceOnDevice = 0

/*  case
    detectTextOnDevice,
    detectBarcodeOnDevice,
    detectImageLabelsOnDevice,
    detectImageLabelsCustomOnDevice,
    detectObjectsProminentNoClassifier,
    detectObjectsProminentWithClassifier,
    detectObjectsMultipleNoClassifier,
    detectObjectsMultipleWithClassifier,
    detectObjectsCustomProminentNoClassifier,
    detectObjectsCustomProminentWithClassifier,
    detectObjectsCustomMultipleNoClassifier,
    detectObjectsCustomMultipleWithClassifier,
    detectPose,
    detectPoseAccurate*/

  static let rowsCount = 1
  static let componentsCount = 1

  public var description: String {
    switch self {
    case .detectFaceOnDevice:
      return "Face Detection"
    /*case .detectTextOnDevice:
      return "Text Recognition"
    case .detectBarcodeOnDevice:
      return "Barcode Scanning"
    case .detectImageLabelsOnDevice:
      return "Image Labeling"
    case .detectImageLabelsCustomOnDevice:
      return "Image Labeling Custom"
    case .detectObjectsProminentNoClassifier:
      return "ODT, single, no labeling"
    case .detectObjectsProminentWithClassifier:
      return "ODT, single, labeling"
    case .detectObjectsMultipleNoClassifier:
      return "ODT, multiple, no labeling"
    case .detectObjectsMultipleWithClassifier:
      return "ODT, multiple, labeling"
    case .detectObjectsCustomProminentNoClassifier:
      return "ODT, custom, single, no labeling"
    case .detectObjectsCustomProminentWithClassifier:
      return "ODT, custom, single, labeling"
    case .detectObjectsCustomMultipleNoClassifier:
      return "ODT, custom, multiple, no labeling"
    case .detectObjectsCustomMultipleWithClassifier:
      return "ODT, custom, multiple, labeling"
    case .detectPose:
      return "Pose Detection"
    case .detectPoseAccurate:
      return "Pose Detection, accurate"*/
    }
  }
}

private enum Constants {
  static let images = [
    "face1.jpg",
    "face2.jpg",
    "face3.jpg",
    "face4.jpg",
    "face5.jpg"
  ]
    
/*  static let styles = [
      "filter_vangogh.jpg",
      "filter_kandinsky.jpg",
      "filter_fractal.jpg",
      "filter_picasso_violin.jpg",
      "filter_Trees.jpg",
      "filter_flight_of_conchords.jpg"
    ]*/
    
    
  static let detectionNoResultsMessage = "No results returned."
  static let failedToDetectObjectsMessage = "Failed to detect objects in image."
  static let localModelFile = (name: "bird", type: "tflite")
  static let labelConfidenceThreshold = 0.75
  static let smallDotRadius: CGFloat = 5.0
  static let largeDotRadius: CGFloat = 10.0
  static let lineColor = UIColor.yellow.cgColor
  static let lineWidth: CGFloat = 3.0
  static let fillColor = UIColor.clear.cgColor
}

// Helper function inserted by Swift 4.2 migrator.
private func convertFromUIImagePickerControllerInfoKeyDictionary(
  _ input: [UIImagePickerController.InfoKey: Any]
) -> [String: Any] {
  return Dictionary(uniqueKeysWithValues: input.map { key, value in (key.rawValue, value) })
}

// Helper function inserted by Swift 4.2 migrator.
private func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey)
  -> String
{
  return input.rawValue
}

// MARK: StylePickerViewControllerDelegate

extension ViewController: StylePickerViewControllerDelegate {

  func picker(_: StylePickerViewController, didSelectStyle image: UIImage) {
    styleImage = image
    styleImageView.image = image

    //if let targetImage = targetImage {
    //  runStyleTransfer(targetImage)
   // }
  }

}
