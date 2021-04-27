# Ruse



[![Build Status][travis-image]][travis-url]<space><space>


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

The Jupyter notebook illustrates the "arbitrary fast style" technique that is possible on mobile: 
![image](https://user-images.githubusercontent.com/12752489/116135863-3f777d00-a697-11eb-8265-3e4f1dba64dd.png)

A variety of methods are used to conceal the faces from commerical recognition systems (e.g. arbitrary file transfer, perlin noise introduction). Before saving to the camera roll or being used for online purposes, an onboard facility checks to see if faces can be detected.

![image](https://user-images.githubusercontent.com/12752489/116176660-217e3c80-a6d8-11eb-8244-3d3998e3c56f.png)
(images are of the pre-release version, showing one particular method adversarial approach)

(Future versions plan on including a similar onboard estimation of how a sample recognition system fairs against the modified image (classification as opposed to merely detection.)


## Development setup

Requirements: Xcode 12 

Pods installed as part of the process below: TensorFlow Lite (Swift nightly build) // GoogleMLKit // GPUImage3

- Download ios and model (tflite models) directory
- run "pod install" in the downloaded directory
- Open Ruse.xcworspace


Installation to device is left as an excercise for the reader.

## Release History
* 0.0.1
    * Work in progress

## Meta 


Distributed under the MIT license. See ``LICENSE`` for more information.

[https://github.com/derrumbe/Ruse](https://github.com/derrumbe/Ruse)

 

<!-- Markdown link & img dfn's -->
[travis-image]: https://travis-ci.com/derrumbe/Ruse.svg?branch=master
[travis-url]: https://travis-ci.com/derrumbe/Ruse/
[wiki]: https://github.com/derrumbe/Ruse/wiki
