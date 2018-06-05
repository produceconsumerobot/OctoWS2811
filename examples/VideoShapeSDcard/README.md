VideoShapeSDcard
==========
Combination of PaulStoffregen's VideoDisplay and VideoSDcard to enable movies to be viewed directly via serial communication with the Teensy or downloaded over serial and stored on the Teensy SD card for viewing when disconnected from the computer. The code also permits an arbitrary pixel arrangement to be used.

## Requires
* Processing 3 (tested with 3.3.7)
* Video library
## Usage
### Change variables to match your system:
* moviePath: Computer file location of movie to display on the LEDs
* outFileNames: Computer file location to save the .BIN files
* serialPorts: Name of serial ports that Octos are attached to
* targetFrameRate: Set to match input video frame rate unless you want to change playback speed
* ledPhysLocs: Physical location of LEDs -- may specify ledPhysLocsFilename to load from file 
* ledPhysLocsFilename: JSON file of ledPhysLocs (arbitrary units specify relative position in space)
### Important key commands:
* "^": Sets SERIAL_DISPLAY mode to send video to Teensy/Octo(s) over serial for live display on LEDs
* "!": toggles SERIAL_SD_WRITE mode to write entire video sequence to Teensy/Octo SD card (overwrites existing VIDEO_01.BIN on SD card)
* "w": toggles LOCAL_FILE_WRITE mode to write entire video sequence to local computer outFileNames
* "&": Set Teensy/Octo to read from VIDEO_01.BIN on its SD card (Teensy defaults to this mode on boot up)
* "+": increases the size of the video sampling area (that's projected on the LED grid)
* "-": decreases the size of the video sampling area (that's projected on the LED grid)
* [Arrow Keys]: moves the video sampling area
* "w": toggle writing to the SD card
* "o": toggle computer's "live display" serial out
* "{": load parameters from saved parameter file
* "}": save parameters to a file
* [Mouse Release]: Pauses/plays video
* Additional key commands at the bottom of movie2shapeSdcard.pde in keyReleased() and keyPressed() functions
### Typical operation:
* Make a backup of VIDEO_01.BIN on your SD card and/or computer (it may be overwritten)
* Hook up the USB to the teensy(ies)
* Open captureLedLocs.pde and follow usage to generate a ledPhysLocs file
  * Alternately manually enter ledPhysLocs array. See examples in movie2shapSdcard/data/ledPhysLocs_examples.txt
* Change the variables to match your system (see Usage section above)
* Run movie2shapeSdcard
* Hit "^" to see live display of the video on the LED grid (sometimes you have to hit it 2x)
* Change the size and position of the sampling area using key commands
* Save your parameters to a file by hitting "}"
* When ready, hit "w" to start writing a new file to your local computer (recommended so you can backup file)
  * Alternately hit "!" to write directly to the Teensy/Octo SD card 
* It will take some time depending on your parameters and video file size
* When the video is finished writing it will be paused at the end of the video and write "Movie writing complete!" to the console (hopefully there won't be a bunch of other warnings all the time that wash that out)
* At that point you can hit "^" to show the computer's live video display again or reboot the teensy to show the SD cards video
* Repeat as necessary to achieve satisfaction
