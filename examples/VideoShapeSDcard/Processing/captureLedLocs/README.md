captureLedLocs.pde
==========
## Description
Uses computer vision to detect LED locations controlled by OctoWS2811.
Each LED is turned on one at a time and detected via background segmentation.
Locations of detected LEDs are saved in a json file
## Requires
* Processing 3 (tested with 3.3.7)
* OpenCV library
* Video library
## Usage
* Plug in Teensy/Octos
* Plug in webcam (if not using integrated webcam)
* Aim webcam at LEDs so that nothing is moving in the frame
* Adjust webcam driver settings (exposure/brightness) and lighting conditions so that no frame areas with LEDs are blown out 
* Change user-defined variables if desired
  * Increase cameraDelay if ANY lit LEDs EVER appear on the left camera frame image
  * Increase camera resolution to improve location accuracy
* Run program
* When program is complete output json file has all led locations (recommended to make a backup copy of this file)