# Ruse



![image](https://user-images.githubusercontent.com/12752489/116280198-0fd77c00-a74e-11eb-8093-642d38c6220a.png)
![image](https://img.shields.io/badge/platform-ios-blue)
![image](https://img.shields.io/badge/platform-android-blue)



![Alt text](https://irisar.com/Ruse/Ruse180.png)


Mobile camera-based application that attempts to alter photos to preserve their utility to humans while making them unusable for facial recognition systems.








![](header.png)

## Installation

(1) Easy Method: Wait and download app from appropriate app store. 

(2) Download and run ios app via XCode (see Development setup for more detail)


## Usage example

App is developed as a camera-based app, allowing for the modification of faces on new camera capture or current photos on camera roll with the goal of keeping them useful for social media and human consumption while making it difficult for facial recognition systems to utilize them accurately and effectively.

This is done through a variety of methods based on previous research. Due to the limits of mobile and TensorFlow Lite, learning on the device itself is not possible—so some of the more advanced techniques are not yet possible (but research and development may yield future results.)

Instructions on usage and a full video to come with first release.

The Jupyter notebook illustrates the "arbitrary fast style" adversarial technique that is possible on mobile: 
![image](https://user-images.githubusercontent.com/12752489/116135863-3f777d00-a697-11eb-8265-3e4f1dba64dd.png)

In the long term, this technique will be applied selectively (likey to segments of the photographs), along with perlin/simplex noise generated on a per image basis, a la https://github.com/kieranbrowne/camera-adversaria.

A variety of methods are used to conceal the faces from commerical recognition systems (e.g. arbitrary file transfer, perlin noise introduction). Before saving to the camera roll or being used for online purposes, an onboard facility checks to see if faces can be detected.

<img src="https://user-images.githubusercontent.com/12752489/116176943-98b3d080-a6d8-11eb-954a-b3006ac940ef.png" width=250/>

The effect of these adversarial approaches may then be checked wihtout needing to have network access.

(Future versions plan on including a similar onboard estimation of how a sample recognition system fairs against the modified image (classification as opposed to merely detection.))


## Development setup

Requirements: Xcode 12 

Pods installed as part of the process below: TensorFlow Lite (Swift nightly build) // GoogleMLKit // GPUImage3

- Download ios and model (tflite models) directory
- run "pod install" in the downloaded directory
- Open Ruse.xcworkspace


Installation to device is left as an excercise for the reader.

## Release History
* 0.2 (in Progress):
   * Redesign of interface to make it more consumer friendly
   * Addition of a new research technique (in process)
* 0.1 
   * Android code checking in (finally)
* 0.0.1
    * Work in progress - iOS code working and checked in

## Furture work
 * web assembly offloading
 * adjustment (independently) of simplex noise and style transfer
 * onboard checking of facial classification
 (dependent on advancement of tensorflow lite, etc)
 * Redesign of app from PoC to actual, you know, usability

## Meta 


Distributed under the MIT license. See ``LICENSE`` for more information.

[https://github.com/derrumbe/Ruse](https://github.com/derrumbe/Ruse)

 

<!-- Markdown link & img dfn's -->
[travis-image]: https://travis-ci.com/derrumbe/Ruse.svg?branch=master
[travis-url]: https://travis-ci.com/derrumbe/Ruse/
[wiki]: https://github.com/derrumbe/Ruse/wiki
