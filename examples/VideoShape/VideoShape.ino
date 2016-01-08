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

// ledPhysLocs array stores the physical location lookup for every LED in use.
// Array indexes are:
//   - LED strip index (Must have 8 LED strips)
//   - LED index (All strips must have the same number of LED positions)
//   - x,y coordinate. {0, 0} is used as a placeholder to make all LED strips 
//      have the same length and fill empty strips.
/*int8_t ledPhysLocs[8][8][2]  = 
  { // Strips
    {{ 2, 1},{ 4, 1},{ 6, 1},{ 8, 1},{10, 1},{12, 1},{14, 1},{ 0, 0}},
    {{ 2, 3},{ 4, 3},{ 6, 3},{ 8, 3},{10, 3},{12, 3},{14, 3},{ 0, 0}},
    {{ 2, 5},{ 4, 5},{ 6, 5},{ 8, 5},{10, 5},{12, 5},{14, 5},{ 0, 0}},
    {{ 2, 7},{ 4, 7},{ 6, 7},{ 8, 7},{10, 7},{12, 7},{14, 7},{ 0, 0}},
    {{15, 2},{13, 2},{11, 2},{ 9, 2},{ 7, 2},{ 5, 2},{ 3, 2},{ 1, 2}},
    {{15, 4},{13, 4},{11, 4},{ 9, 4},{ 7, 4},{ 5, 4},{ 3, 4},{ 1, 4}},
    {{15, 6},{13, 6},{11, 6},{ 9, 6},{ 7, 6},{ 5, 6},{ 3, 6},{ 1, 6}},
    {{ 0, 0},{ 0, 0},{ 0, 0},{ 0, 0},{ 0, 0},{ 0, 0},{ 0, 0},{ 0, 0}}
  };
  */
  
//#include "led_sun_phys_locs_01.h"
#include "sean_travel_phys_locs_01.h"

const int ledsPerStrip = sizeof(ledPhysLocs[0])/sizeof(ledPhysLocs[0][0]);

DMAMEM int displayMemory[ledsPerStrip*6];
int drawingMemory[ledsPerStrip*6];
elapsedMicros elapsedUsecSinceLastFrameSync = 0;

const int config = WS2811_800kHz; // color config is on the PC side

OctoWS2811 leds(ledsPerStrip, displayMemory, drawingMemory, config);

void setup() {
  // Blink LED to show Teensy is working properly
  pinMode(13, OUTPUT);
  digitalWrite(13, HIGH);
  delay(3000);
  digitalWrite(13, LOW);
  
  pinMode(12, INPUT_PULLUP); // Frame Sync
  Serial.setTimeout(50);
  leds.begin();
  leds.show();
}

void loop() {
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
  int startChar = Serial.read();

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
    int nStrips = sizeof(ledPhysLocs)/sizeof(ledPhysLocs[0]);
    int nLedsPerStrip = sizeof(ledPhysLocs[0])/sizeof(ledPhysLocs[0][0]);
    int nCoords = sizeof(ledPhysLocs[0][0])/sizeof(int8_t);
     
    Serial.print(nStrips);
    Serial.print(',');
    Serial.print(nLedsPerStrip);
    Serial.print(',');
    Serial.print(nCoords);
    Serial.print(',');
    Serial.println();
    Serial.print('{');
    
    for (int s=0; s<nStrips; s++) {
      Serial.print('{');
      for (int l=0; l<nLedsPerStrip; l++) {
        Serial.print('{');
        Serial.print(ledPhysLocs[s][l][0]);
        Serial.print(',');
        Serial.print(ledPhysLocs[s][l][1]);
        Serial.print(',');
        Serial.print('}');
      }
      Serial.print('}');
    }
    Serial.print('}');
    Serial.println();
    /*
    Serial.print(LED_WIDTH);
    Serial.write(',');
    Serial.print(LED_HEIGHT);
    Serial.write(',');
    Serial.print(LED_LAYOUT);
    Serial.write(',');
    Serial.print(0);
    Serial.write(',');
    Serial.print(0);
    Serial.write(',');
    Serial.print(VIDEO_XOFFSET);
    Serial.write(',');
    Serial.print(VIDEO_YOFFSET);
    Serial.write(',');
    Serial.print(VIDEO_WIDTH);
    Serial.write(',');
    Serial.print(VIDEO_HEIGHT);
    Serial.write(',');
    Serial.print(0);
    Serial.write(',');
    Serial.print(0);
    Serial.write(',');
    Serial.print(0);
    Serial.println();
    */

  } else if (startChar >= 0) {
    // discard unknown characters
  }
}

