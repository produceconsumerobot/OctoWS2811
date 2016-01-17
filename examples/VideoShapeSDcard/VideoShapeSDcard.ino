/*  OctoWS2811 VideoDisplay.ino - Video on LEDs, from a PC, Mac, Raspberry Pi
    http://www.pjrc.com/teensy/td_libs_OctoWS2811.html
    Copyright (c) 2013 Paul Stoffregen, PJRC.COM, LLC

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.

 
  Required Connections
  --------------------
    pin 2:  LED Strip #1    OctoWS2811 drives 8 LED Strips.
    pin 14: LED strip #2    All 8 are the same length.
    pin 7:  LED strip #3
    pin 8:  LED strip #4    A 100 to 220 ohm resistor should used
    pin 6:  LED strip #5    between each Teensy pin and the
    pin 20: LED strip #6    wire to the LED strip, to minimize
    pin 21: LED strip #7    high frequency ringining & noise.
    pin 5:  LED strip #8
    pin 15 & 16 - Connect together, but do not use
    pin 4:  Do not use
    pin 3:  Do not use as PWM.  Normal use is ok.
    pin 12: Frame Sync

    When using more than 1 Teensy to display a video image, connect
    the Frame Sync signal between every board.  All boards will
    synchronize their WS2811 update using this signal.

    Beware of image distortion from long LED strip lengths.  During
    the WS2811 update, the LEDs update in sequence, not all at the
    same instant!  The first pixel updates after 30 microseconds,
    the second pixel after 60 us, and so on.  A strip of 120 LEDs
    updates in 3.6 ms, which is 10.8% of a 30 Hz video frame time.
    Doubling the strip length to 240 LEDs increases the lag to 21.6%
    of a video frame.  For best results, use shorter length strips.
    Multiple boards linked by the frame sync signal provides superior
    video timing accuracy.

    A Multi-TT USB hub should be used if 2 or more Teensy boards
    are connected.  The Multi-TT feature allows proper USB bandwidth
    allocation.  Single-TT hubs, or direct connection to multiple
    ports on the same motherboard, may give poor performance.
*/

#include <OctoWS2811.h>
#include <SPI.h>
#include <SD.h>
//#include <SerialFlash.h>
//#include <Audio.h>
#include <Wire.h>

// The actual arrangement of the LEDs connected to this Teensy 3.0 board.
// LED_HEIGHT *must* be a multiple of 8.  When 16, 24, 32 are used, each
// strip spans 2, 3, 4 rows.  LED_LAYOUT indicates the direction the strips
// are arranged.  If 0, each strip begins on the left for its first row,
// then goes right to left for its second row, then left to right,
// zig-zagging for each successive row.
#define LED_WIDTH      8   // number of LEDs horizontally
#define LED_HEIGHT     8   // number of LEDs vertically (must be multiple of 8)

#define FILENAME     "VIDEO_01.BIN"

#define SD_CARD_READ_MODE   0
#define SERIAL_MODE         1
#define SD_CARD_WRITE_MODE  2

int playMode = SD_CARD_READ_MODE;

#define LOG_ERROR     3
#define LOG_VERBOSE   5 // Log verbose information to Serial.print

int LOG_LEVEL = LOG_ERROR;

// --------- END USER DEFINED VARIABLES ------------- //

const int ledsPerStrip = LED_WIDTH * LED_HEIGHT / 8;
DMAMEM int displayMemory[ledsPerStrip*6];
int drawingMemory[ledsPerStrip*6];
elapsedMicros elapsedUsecSinceLastFrameSync = 0;
elapsedMicros elapsedSinceLastFrame = 0;
bool playing = false;
bool writing = false;
bool sdBegun = false;

const int config = WS2811_800kHz; // color config is on the PC side
OctoWS2811 leds(ledsPerStrip, displayMemory, drawingMemory, config);

File videofile;

unsigned long vidLoopTime = millis(); // Tracks how long it takes to close and open the video

void setup() {
  Serial.println("VideoShapeSDcard");
  
  // Blink LED to show Teensy is working properly
  pinMode(13, OUTPUT);
  digitalWrite(13, HIGH);
  delay(3000);
  digitalWrite(13, LOW);
  
  pinMode(12, INPUT_PULLUP); // Frame Sync
  Serial.setTimeout(50);
  leds.begin();
  leds.show();

  // Setup SD card
  //  AudioMemory(40);
  //while (!Serial) ;
  delay(50);

  // Setup the SD card
  SD.begin(3);
  delay(50);
  //setupSDcheck();

  if (playMode == SD_CARD_READ_MODE) {
    openSDread();
  }

  elapsedUsecSinceLastFrameSync = 0;
  elapsedSinceLastFrame = 0;
}

void loop() {
  // Read from serial to determine which mode to 
  int startChar = Serial.read();
  int lpCnt;

  switch (startChar) {
    case '^':
      playing = false;
      videofile.seek(0);
      videofile.close();
      lpCnt = 0;
      while(videofile && lpCnt < 100) {
        delay(10);
        lpCnt++;
      }
      playMode = SERIAL_MODE;
      Serial.println("Entering SERIAL_MODE");
      break;
    case '&':
      // ToDo: Figure out how to make this work
      // Until then: Manually reset the Teensy with the reset button.
      //playMode = SD_CARD_READ_MODE;
      //stopWithErrorMessage("Manually hit reset button to enter SD_CARD_READ_MODE");
      //Serial.println("Manually hit reset button to enter SD_CARD_READ_MODE");
      videofile.close();
      lpCnt = 0;
      while(videofile && lpCnt < 100) {
        delay(10);
        lpCnt++;
      }
      openSDread();
      playMode = SD_CARD_READ_MODE;
      elapsedUsecSinceLastFrameSync = 0;
      elapsedSinceLastFrame = 0;
      break;
    case '!':
      playMode = SD_CARD_WRITE_MODE;
      Serial.println("Entering SD_CARD_WRITE_MODE");
      openSDwrite();
      break;
    default:
      break;
  }
  
  if (playMode == SERIAL_MODE) {
    // Serial Mode receives video data from the serial port and writes
    // it to the OCTOWS8211.
    
    //
    // wait for a Start-Of-Message character:
    //
    //   '*' = Frame of image data, with frame sync pulse to be sent
    //         a specified number of microseconds after reception of
    //         the first byte (typically at 75% of the frame time, to
    //         allow other boards to fully receive their data).
    //         Normally '*' is used when the sender controls the pace
    //         of playback by transmitting each frame as it should
    //         appear.
    //   
    //   '$' = Frame of image data, with frame sync pulse to be sent
    //         a specified number of microseconds after the previous
    //         frame sync.  Normally this is used when the sender
    //         transmits each frame as quickly as possible, and we
    //         control the pacing of video playback by updating the
    //         LEDs based on time elapsed from the previous frame.
    //
    //   '%' = Frame of image data, to be displayed with a frame sync
    //         pulse is received from another board.  In a multi-board
    //         system, the sender would normally transmit one '*' or '$'
    //         message and '%' messages to all other boards, so every
    //         Teensy 3.0 updates at the exact same moment.
    //
    //   '@' = Reset the elapsed time, used for '$' messages.  This
    //         should be sent before the first '$' message, so many
    //         frames are not played quickly if time as elapsed since
    //         startup or prior video playing.
    //   
    //   '?' = Query LED and Video parameters.  Teensy 3.0 responds
    //         with a comma delimited list of information.
    //
    
  
    if (startChar == '*') {
      // receive a "master" frame - we send the frame sync to other boards
      // the sender is controlling the video pace.  The 16 bit number is
      // how far into this frame to send the sync to other boards.
      unsigned int startAt = micros();
      unsigned int usecUntilFrameSync = 0;
      int count = Serial.readBytes((char *)&usecUntilFrameSync, 2);
      if (count != 2) return;
      count = Serial.readBytes((char *)drawingMemory, sizeof(drawingMemory));
      if (count == sizeof(drawingMemory)) {
        unsigned int endAt = micros();
        unsigned int usToWaitBeforeSyncOutput = 100;
        if (endAt - startAt < usecUntilFrameSync) {
          usToWaitBeforeSyncOutput = usecUntilFrameSync - (endAt - startAt);
        }
        digitalWrite(12, HIGH);
        pinMode(12, OUTPUT);
        delayMicroseconds(usToWaitBeforeSyncOutput);
        digitalWrite(12, LOW);
        // WS2811 update begins immediately after falling edge of frame sync
        digitalWrite(13, HIGH);
        leds.show();
        digitalWrite(13, LOW);
      }
  
    } else if (startChar == '$') {
      // receive a "master" frame - we send the frame sync to other boards
      // we are controlling the video pace.  The 16 bit number is how long
      // after the prior frame sync to wait until showing this frame
      unsigned int usecUntilFrameSync = 0;
      int count = Serial.readBytes((char *)&usecUntilFrameSync, 2);
      if (count != 2) return;
      count = Serial.readBytes((char *)drawingMemory, sizeof(drawingMemory));
      if (count == sizeof(drawingMemory)) {
        digitalWrite(12, HIGH);
        pinMode(12, OUTPUT);
        while (elapsedUsecSinceLastFrameSync < usecUntilFrameSync) /* wait */ ;
        elapsedUsecSinceLastFrameSync -= usecUntilFrameSync;
        digitalWrite(12, LOW);
        // WS2811 update begins immediately after falling edge of frame sync
        digitalWrite(13, HIGH);
        leds.show();
        digitalWrite(13, LOW);
      }
  
    } else if (startChar == '%') {
      // receive a "slave" frame - wait to show it until the frame sync arrives
      pinMode(12, INPUT_PULLUP);
      unsigned int unusedField = 0;
      int count = Serial.readBytes((char *)&unusedField, 2);
      if (count != 2) return;
      count = Serial.readBytes((char *)drawingMemory, sizeof(drawingMemory));
      if (count == sizeof(drawingMemory)) {
        elapsedMillis wait = 0;
        while (digitalRead(12) != HIGH && wait < 30) ; // wait for sync high
        while (digitalRead(12) != LOW && wait < 30) ;  // wait for sync high->low
        // WS2811 update begins immediately after falling edge of frame sync
        if (wait < 30) {
          digitalWrite(13, HIGH);
          leds.show();
          digitalWrite(13, LOW);
        }
      }
  
    } else if (startChar == '@') {
      // reset the elapsed frame time, for startup of '$' message playing
      elapsedUsecSinceLastFrameSync = 0;
  
    } else if (startChar == '?') {
      // when the video application asks, give it all our info
      // for easy and automatic configuration
      Serial.print(LED_WIDTH);
      Serial.write(',');
      Serial.print(LED_HEIGHT);
      Serial.write(',');
      Serial.println();

    } else if (startChar >= 0) {
      // discard unknown characters
    }
  } else if (playMode == SD_CARD_READ_MODE) {
    // SD Card Mode reads video data from the SD card and writes
    // it to the OCTOWS8211.
    unsigned char header[5];
    
    if (playing && videofile && videofile.position() < videofile.size()) {
      if (LOG_LEVEL >= LOG_VERBOSE) {
        Serial.printf("Position = %u / %u\n", videofile.position(), videofile.size());
      }
      if (sd_card_read(header, 5, 0)) {
          if (LOG_LEVEL >= LOG_VERBOSE)  {
            //Serial.println((char*)header);
          }
          if (header[0] == '*') {
          // found an image frame
          unsigned int size = (header[1] | (header[2] << 8)) * 3;
          unsigned int usec = header[3] | (header[4] << 8);
          unsigned int readsize = size;
          if (LOG_LEVEL >= LOG_VERBOSE)  {
            Serial.printf("v: %u %u, ", size, usec);
          }
          if (readsize > sizeof(drawingMemory)) {
            // Make sure header size information doesn't exceed allocated memory
            readsize = sizeof(drawingMemory);
          }
          if (sd_card_read(drawingMemory, readsize, 0)) {
            if (LOG_LEVEL >= LOG_VERBOSE)  {
               Serial.printf("us = %u\n", (unsigned int)elapsedSinceLastFrame);
            }
            while (elapsedSinceLastFrame < usec) ; // wait
            elapsedSinceLastFrame -= usec;
            vidLoopTime = millis();
            leds.show();
          } else {
            error("unable to read video frame data");
            return;
          }
          if (LOG_LEVEL >= LOG_VERBOSE) {
            //Serial.printf("Readsize = ");
            //Serial.println(readsize);
          }
          if (readsize < size) {
            sd_card_skip(size - readsize);
            if (LOG_LEVEL >= LOG_VERBOSE) {
              Serial.printf("Skipping = ");
              Serial.println(size - readsize);
            }
          }
        } else if (header[0] == '%') {
          /*
          // found a chunk of audio data
          unsigned int size = (header[1] | (header[2] << 8)) * 2;
          if (LOG_LEVEL >= LOG_VERBOSE)  {
            Serial.printf("a: %u", size);
            Serial.println();
          }
          while (size > 0) {
            unsigned int len = size;
            if (len > 256) len = 256;
              int16_t *p = audio.getBuffer();
            if (!sd_card_read(p, len)) {
              error("unable to read audio frame data");
                    return;
            }
            if (len < 256) {
                    for (int i=len; i < 256; i++) {
                      *((char *)p + i) = 0;  // fill rest of buffer with zero
                    }
            }
                  audio.playBuffer();
            size -= len;
          }
         */
        } else {
          error("unknown header: ");
          Serial.println((char*)header);
          return;
        }
      } else {
        error("unable to read 5-byte header: ");
        Serial.println((char*) header);
        return;
      }
    } else {
      //delay(2000);
      playing = false;
      Serial.printf("Closing file\n");
      videofile.close();
      lpCnt = 0;
      while(videofile && lpCnt < 100) {
        delay(10);
        lpCnt++;
      }
      if (LOG_LEVEL >= LOG_VERBOSE)  {
        Serial.printf("Close lpCnt = %i\n", lpCnt);
      }
      videofile = SD.open(FILENAME, FILE_READ);
      lpCnt = 0;
      while(!videofile && lpCnt < 100) {
        delay(10);
        lpCnt++;
      }
      if (LOG_LEVEL >= LOG_VERBOSE)  {
        Serial.printf("Open lpCnt = %i\n", lpCnt);
      }
      if (videofile) {
        Serial.println("File opened");
        sd_card_read(0, 0, 1);
        playing = true;
        elapsedSinceLastFrame = 0;
      }
      if (LOG_LEVEL >= LOG_VERBOSE)  {
        // Print how long it took to close and open the video
        Serial.print("v: VidLoopDelay: ms = ");
        Serial.println(millis() - vidLoopTime);
      }
    }
  } else if (playMode == SD_CARD_WRITE_MODE) {
    if (startChar == ']') {
      // Video file is finished writing!
      videofile.close();
      lpCnt = 0;
      while(videofile && lpCnt < 100) {
        delay(10);
        lpCnt++;
      }
      Serial.println("Closing SD write");
      playMode = SERIAL_MODE;
    } else if (startChar == '*') {
      // ToDo: Make this work for slave frames too
      // Read the rest of the header
      int headerSize = 4;
      char header[headerSize];
      int count = Serial.readBytes((char *)&header, headerSize);
      if (count != headerSize) {
        Serial.println("Error: Wrong size header");
      } else {
        count = Serial.readBytes((char *)drawingMemory, sizeof(drawingMemory));
        if (count != sizeof(drawingMemory)) {
          Serial.printf("Error: Wrong size write data: %i, %i\n", count, sizeof(drawingMemory));
        } else {
          videofile.write(startChar);
          videofile.write(header, headerSize);
          videofile.write((char *)drawingMemory, sizeof(drawingMemory));
          leds.show();
        }
      }
    }
  }
}

// read from the SD card, true=ok, false=unable to read
// the SD library is much faster if all reads are 512 bytes
// this function lets us easily read any size, but always
// requests data from the SD library in 512 byte blocks.
//
bool sd_card_read(void *ptr, unsigned int len, bool resetBufPos)
{
  static unsigned char buffer[512];
  static unsigned int bufpos = 0;
  static unsigned int buflen = 0;
  unsigned char *dest = (unsigned char *)ptr;
  unsigned int n;

  if (resetBufPos) {
    buflen = 0;
    bufpos = 0;  
    if (LOG_LEVEL >= LOG_VERBOSE)  {
        Serial.printf("v: sd_card_read resetBufPos\n");
    }
    return false;  
  } else {
    while (len > 0) {
      if (buflen == 0) {
        n = videofile.read(buffer, 512);
        if (n == 0) return false;    
        buflen = n;
        bufpos = 0;
      }
      //unsigned int n = buflen;
      n = buflen;
      if (n > len) n = len;
      if (LOG_LEVEL >= LOG_VERBOSE)  {
        //Serial.printf("v: sd_card_read: %u, %u, %u, %u, %u\n", len, buflen, n, dest, bufpos);
      }
      memcpy(dest, buffer + bufpos, n);
      dest += n;
      bufpos += n;
      buflen -= n;
      len -= n;
    }
    return true;
  }
}

// skip past data from the SD card
void sd_card_skip(unsigned int len)
{
  unsigned char buf[256];

  while (len > 0) {
    unsigned int n = len;
    if (n > sizeof(buf)) n = sizeof(buf);
    sd_card_read(buf, n, 0);
    len -= n;
  }
}

void setupSDcheck() {
  if (!sdBegun) {
    // Setup the SD card
    if (SD.begin(3)) {
      sdBegun = true;
    } else {
      error("Could not access SD card");
      //playMode = SERIAL_MODE;
    }
  }
  delay(50);  
}

void openSDread() {
 // ToDo: figure out why we have to call SD.begin again here.
 SD.begin(3);
 delay(50);
 //setupSDcheck();
 
  Serial.println("SD card ok");
  playing = false;
  videofile.close();
  int lpCnt = 0;
  while(videofile && lpCnt < 100) {
    delay(10);
    lpCnt++;
  }
  videofile = SD.open(FILENAME, FILE_READ);
  lpCnt = 0;
  while(!videofile && lpCnt < 100) {
    delay(10);
    lpCnt++;
  }
  if (!videofile) {
    error("Could not read " FILENAME);
    //stopWithErrorMessage("Could not read " FILENAME);
    //playMode = SERIAL_MODE;
  } else {
    Serial.print("File opened: ");
    Serial.println((char *) FILENAME);
    Serial.print("File size: ");
    Serial.println(videofile.size());
    videofile.seek(0);
    sd_card_read(0, 0, 1);
    playing = true;
    elapsedSinceLastFrame = 0;
  }
}

void openSDwrite() {
  // ToDo: figure out why we have to call SD.begin again here.
  SD.begin(3);
  delay(50);
  //setupSDcheck();
  
  Serial.println("SD card ok");
  playing = false;
  videofile.close();
  while(videofile) delay(10); 
  Serial.println("Video file closed");

  // Remove the old video file
  if (SD.remove(FILENAME)) {
    Serial.printf("File removed: %s\n", FILENAME);
  } else {
    Serial.printf("File not removed: %s\n", FILENAME);
  }
  
  videofile = SD.open(FILENAME, FILE_WRITE);
  int lpCnt = 0;
  while(!videofile && lpCnt < 200) {
    delay(10);
    lpCnt++;
    Serial.printf("lpCnt = %i\n", lpCnt);
  }
  if (!videofile) {
    error("Could not write " FILENAME);
    //stopWithErrorMessage("Could not read " FILENAME);
    //playMode = SERIAL_MODE;
  } else {
    Serial.print("File opened: ");
    Serial.println((char *) FILENAME);
    Serial.print("File size: ");
    Serial.println(videofile.size());
  }
  delay(50); 
}



// when any error happens during playback, close the file and restart
void error(const char *str)
{
  Serial.print("error: ");
  Serial.println(str);
  if (videofile) {
    videofile.close();
    int lpCnt = 0;
    while(videofile && lpCnt < 100) {
      delay(10);
      lpCnt++;
    }
  }
  playing = false;
}

// when an error happens during setup, give up and print a message
// to the serial monitor.
void stopWithErrorMessage(const char *str)
{
  while (1) {
    Serial.println(str);
    delay(1000);
  }
}
