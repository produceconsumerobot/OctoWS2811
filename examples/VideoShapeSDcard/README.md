VideoShapeSDcard
==========
Combination of PaulStoffregen's VideoDisplay and VideoSDcard to enable movies to be viewed directly via serial communication with the Teensy or downloaded over serial and stored on the Teensy SD card for viewing when disconnected from the computer. The code also permits an arbitrary pixel arrangement to be used.

## Requires
Processing 2

## Usage
### Change variables to match your system:
* moviePath
* outFileNames
* serialPorts
* targetFrameRate  (to match input video frame rate)
* ledPhysLocs physical location of LEDs (arbitrary units specify relative position in space)
### Important key commands:
* "+": increases the size of the video sampling area (that's projected on the LED grid)
* "-": decreases the size of the video sampling area (that's projected on the LED grid)
* [Arrow Keys]: moves the video sampling area
* "w": toggle writing to the SD card
* "o": toggle computer's "live display" serial out
* "{": load parameters from saved parameter file
* "}": save parameters to a file
* Additional key commands at the bottom of movie2shapeSdcard.pde in keyReleased() and keyPressed() functions
### Typical operation:
* Make a backup of VIDEO_01.BIN on your SD card (it will be overwritten)
* Hook up the USB to the teensy
* Open code in processing
* Change the variables to match your system
* Run the program
* You should see live display of the video on the LED grid
* Change the size and position of the sampling area using key commands
* Save your parameters to a file by hitting "{"
* When ready, hit "w" to start writing a new file to the SD card
* It will take some time depending on your parameters and video file size
* When the video is finished writing it will be paused at the end of the video and write "Movie writing complete!" to the console (hopefully there won't be a bunch of other warnings all the time that wash that out)
* At that point you can hit "o" to show the computer's live video display again or reboot the teensy to show the SD cards video
* Repeat as necessary to achieve satisfaction
