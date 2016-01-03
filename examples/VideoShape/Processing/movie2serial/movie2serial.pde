/*  OctoWS2811 movie2serial.pde - Transmit video data to 1 or more
      Teensy 3.0 boards running OctoWS2811 VideoDisplay.ino
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
*/

// To configure this program, edit the following sections:
//
//  1: change myMovie to open a video file of your choice    ;-)
//
//  2: edit the serialConfigure() lines in setup() for your
//     serial device names (Mac, Linux) or COM ports (Windows)
//
//  3: if your LED strips have unusual color configuration,
//     edit colorWiring().  Nearly all strips have GRB wiring,
//     so normally you can leave this as-is.
//
//  4: if playing 50 or 60 Hz progressive video (or faster),
//     edit framerate in movieEvent().

import processing.video.*;
import processing.serial.*;
import java.awt.Rectangle;
import java.lang.reflect.Array;

//Movie myMovie = new Movie(this, "C:\\pub\\LocalDev\\Sean\\Processing2.0\\OctoWS2811\\examples\\VideoShape\\Processing\\movie2serial\\HorzLineTest01_01.mov");
Movie myMovie = new Movie(this, "C:\\pub\\LocalDev\\Sean\\Processing2.0\\OctoWS2811\\examples\\VideoShape\\Processing\\movie2serial\\LineTest01_01.mov");
//Movie myMovie = new Movie(this, "C:\\pub\\LocalDev\\Sean\\Arduino\\OctoWS2811-master\\OctoWS2811-master\\examples\\VideoDisplay\\Processing\\movie2serial\\2015_11_25_05_53_30_2015_12_02_04_49_42_AIA_304-hq.mp4");
//Movie myMovie = new Movie(this, ".\\20131111_191820.mp4");


// ledPhysLocs array stores the physical location lookup for every LED in use.
// Array indexes are:
//   - Port index
//   - LED strip index (Must have 8 LED strips)
//   - LED index (All strips must have the same number of LED positions)
//   - x,y coordinate. {-1, -1} is used as a placeholder to make all LED strips 
//      have the same length and fill empty strips.
int[][][][] ledPhysLocs = 
  { // Ports
    { // Strips
      {{ 1, 0},{ 3, 0},{ 5, 0},{ 7, 0},{ 9, 0},{11, 0},{13, 0},{-1,-1}},
      {{ 1, 2},{ 3, 2},{ 5, 2},{ 7, 2},{ 9, 2},{11, 2},{13, 2},{-1,-1}},
      {{ 1, 4},{ 3, 4},{ 5, 4},{ 7, 4},{ 9, 4},{11, 4},{13, 4},{-1,-1}},
      {{ 1, 6},{ 3, 6},{ 5, 6},{ 7, 6},{ 9, 6},{11, 6},{13, 6},{-1,-1}},
      {{14, 1},{12, 1},{10, 1},{ 8, 1},{ 6, 1},{ 4, 1},{ 2, 1},{ 0, 1}},
      {{14, 3},{12, 3},{10, 3},{ 8, 3},{ 6, 3},{ 4, 3},{ 2, 3},{ 0, 3}},
      {{14, 5},{12, 5},{10, 5},{ 8, 5},{ 6, 5},{ 4, 5},{ 2, 5},{ 0, 5}},
      {{-1,-1},{-1,-1},{-1,-1},{-1,-1},{-1,-1},{-1,-1},{-1,-1},{-1,-1}}
    }
  };

// Final install has the following number of leds/strip:
// 3: 379
// 7: 378
// others: 382


float ledLocScaler = 30;
int ledLocXOffset = 30;
int ledLocYOffset = 65;
int ledLocAveArea = 0;
color[] drawColors = {color(255,0,0), color(0,255,0)};

/*
int[][] ledLocations0 = {{ 0, 1},{ 0, 3},{ 0, 5},{ 0, 7},{ 0, 9},{ 0,11}};
int[][] ledLocations1 = {{ 1,12},{ 1,10},{ 1, 8},{ 1, 6},{ 1, 4},{ 1, 2},{ 1, 0}};
int[][] ledLocations2 = {{ 2, 1},{ 2, 3},{ 2, 5},{ 2, 7},{ 2, 9},{ 2,11}};
int[][] ledLocations3 = {{ 3,12},{ 3,10},{ 3, 8},{ 3, 6},{ 3, 4},{ 3, 2},{ 3, 0}};
int[][] ledLocations4 = {{ 4, 1},{ 4, 3},{ 4, 5},{ 4, 7},{ 4, 9},{ 4,11}};
int[][] ledLocations5 = {{ 5,12},{ 5,10},{ 5, 8},{ 5, 6},{ 5, 4},{ 5, 2},{ 5, 0}};
int[][] ledLocations6 = {{ 6, 1},{ 6, 3},{ 6, 5},{ 6, 7},{ 6, 9},{ 6,11}};


class OctoWS2811 {
  public int[][] ledStrips; 
  public OctoWS2811() {
    
  public OctoWS2811(int loc[][]) {
      ledLocations = {0,1;0,3;etc};
    }
}
*/


/*    
int[] ledStrip0 = {;
int[] ledStrip1 = new int[8];
int[] ledStrip2 = new int[7];
int[] ledStrip3 = new int[8];
int[] ledStrip4 = new int[7];
int[] ledStrip5 = new int[8];
int[] ledStrip6 = new int[7];
*/

float gamma = 1.7;

int numPorts=0;  // the number of serial ports in use
int maxPorts=24; // maximum number of serial ports

Serial[] ledSerial = new Serial[maxPorts];     // each port's actual Serial port
Rectangle[] ledArea = new Rectangle[maxPorts]; // the area of the movie each port gets, in % (0-100)
boolean[] ledLayout = new boolean[maxPorts];   // layout of rows, true = even is left->right
PImage ledImage;      // image sent to each port
int[] gammatable = new int[256];
int errorCount=0;
float framerate=0;

void setup() {
  String[] list = Serial.list();
  delay(20);
  println("Serial Ports List:");
  println(list);
  serialConfigure("COM22");
  //serialConfigure("/dev/ttyACM0");  // change these to your port names
  //serialConfigure("/dev/ttyACM1");
  if (errorCount > 0) exit();
  for (int i=0; i < 256; i++) {
    gammatable[i] = (int)(pow((float)i / 255.0, gamma) * 255.0 + 0.5);
  }
  size(480, 400);  // create the window
  myMovie.loop();  // start the movie :-)
}

 
// movieEvent runs for each new frame of movie data
void movieEvent(Movie m) {
  // read the movie's next frame
  m.read();
  
  //if (framerate == 0) framerate = m.getSourceFrameRate();
  framerate = 30.0; // TODO, how to read the frame rate???
  
  
  // ShapeDisplay code
  for (int p=0; p < numPorts; p++) {  
    // Copy the video frame to a PImage
    // ToDo: make ledImage a single PImage rather than array
    //ledImage[p].copy(m);
    //println("m=" + m.width + "," + m.height);
    ledImage = new PImage(m.width, m.height);
    ledImage.copy(m, 0, 0, m.width, m.height, 0, 0, m.width, m.height);
    byte[] ledData = new byte[(ledPhysLocs[p].length * ledPhysLocs[p][0].length * 3) + 3];
    
    //println("image=" + ledImage.width + "," + ledImage.height);
    shape2data(ledImage, ledData, p);
    
    if (p == 0) {
      ledData[0] = '*';  // first Teensy is the frame sync master
      int usec = (int)((1000000.0 / framerate) * 0.75);
      ledData[1] = (byte)(usec);   // request the frame sync pulse
      ledData[2] = (byte)(usec >> 8); // at 75% of the frame time
    } else {
      ledData[0] = '%';  // others sync to the master board
      ledData[1] = 0;
      ledData[2] = 0;
    }
    // send the raw data to the LEDs  :-)
    ledSerial[p].write(ledData); 
  }
  
  
  /*
  // Original VideoDisplay code
  for (int i=0; i < numPorts; i++) {    
    // copy a portion of the movie's image to the LED image
    int xoffset = percentage(m.width, ledArea[i].x);
    int yoffset = percentage(m.height, ledArea[i].y);
    int xwidth =  percentage(m.width, ledArea[i].width);
    int yheight = percentage(m.height, ledArea[i].height);
    ledImage[i].copy(m, xoffset, yoffset, xwidth, yheight,
                     0, 0, ledImage[i].width, ledImage[i].height);
    // convert the LED image to raw data
    byte[] ledData =  new byte[(ledImage[i].width * ledImage[i].height * 3) + 3];
    image2data(ledImage[i], ledData, ledLayout[i]);
    if (i == 0) {
      ledData[0] = '*';  // first Teensy is the frame sync master
      int usec = (int)((1000000.0 / framerate) * 0.75);
      ledData[1] = (byte)(usec);   // request the frame sync pulse
      ledData[2] = (byte)(usec >> 8); // at 75% of the frame time
    } else {
      ledData[0] = '%';  // others sync to the master board
      ledData[1] = 0;
      ledData[2] = 0;
    }
    // send the raw data to the LEDs  :-)
    ledSerial[i].write(ledData); 
  }
  */
}

// Convert 
void shape2data(PImage image, byte[] data, int port) {
  int offset = 3;
  int mask;
  int pixel[] = new int[8];
    
  for (int l=0; l<ledPhysLocs[port][0].length; l++) {
    for (int s=0; s < 8; s++) {
      
      // get position in image.pixels
      // pixel[s] = x + (y * w)
      if (ledPhysLocs[port][s][l][0] < 0 || ledPhysLocs[port][s][l][1] < 0) {
        pixel[s] = 0;
      } else {
        int pixNum = int(ledPhysLocs[port][s][l][0]*ledLocScaler+ledLocXOffset + // x offset
          (ledPhysLocs[port][s][l][1]*ledLocScaler+ledLocYOffset) * image.width);
        //println(pixNum + "," + image.width+ "," + image.height + "," + image.pixels.length);
        pixel[s] = image.pixels[pixNum];
      }
       
      // convert color
      pixel[s] = colorWiring(pixel[s]);
    }
            
    // convert 8 pixels to 24 bytes
    for (mask = 0x800000; mask != 0; mask >>= 1) {
      byte b = 0;
      for (int s=0; s < 8; s++) {
        if ((pixel[s] & mask) != 0) b |= (1 << s);
      }
      data[offset++] = b;
    }
  }
}
    
// image2data converts an image to OctoWS2811's raw data format.
// The number of vertical pixels in the image must be a multiple
// of 8.  The data array must be the proper size for the image.
void image2data(PImage image, byte[] data, boolean layout) {
  int offset = 3;
  int x, y, xbegin, xend, xinc, mask;
  int linesPerPin = image.height / 8;
  int pixel[] = new int[8];
  
  for (y = 0; y < linesPerPin; y++) {
    if ((y & 1) == (layout ? 0 : 1)) {
      // even numbered rows are left to right
      xbegin = 0;
      xend = image.width;
      xinc = 1;
    } else {
      // odd numbered rows are right to left
      xbegin = image.width - 1;
      xend = -1;
      xinc = -1;
    }
    for (x = xbegin; x != xend; x += xinc) {
      for (int i=0; i < 8; i++) {
        // fetch 8 pixels from the image, 1 for each pin
        pixel[i] = image.pixels[x + (y + linesPerPin * i) * image.width];
        pixel[i] = colorWiring(pixel[i]);
      }
      // convert 8 pixels to 24 bytes
      for (mask = 0x800000; mask != 0; mask >>= 1) {
        byte b = 0;
        for (int i=0; i < 8; i++) {
          if ((pixel[i] & mask) != 0) b |= (1 << i);
        }
        data[offset++] = b;
      }
    }
  } 
  
}

// translate the 24 bit color from RGB to the actual
// order used by the LED wiring.  GRB is the most common.
int colorWiring(int c) {
  int red = (c & 0xFF0000) >> 16;
  int green = (c & 0x00FF00) >> 8;
  int blue = (c & 0x0000FF);
  red = gammatable[red];
  green = gammatable[green];
  blue = gammatable[blue];
  return (green << 16) | (red << 8) | (blue); // GRB - most common wiring
}

// ask a Teensy board for its LED configuration, and set up the info for it.
void serialConfigure(String portName) {
  if (numPorts >= maxPorts) {
    println("too many serial ports, please increase maxPorts");
    errorCount++;
    return;
  }
  try {
    ledSerial[numPorts] = new Serial(this, portName);
    if (ledSerial[numPorts] == null) throw new NullPointerException();
    ledSerial[numPorts].write('?');
  } catch (Throwable e) {
    println("Serial port " + portName + " does not exist or is non-functional");
    errorCount++;
    return;
  }
  delay(50);
  String line = ledSerial[numPorts].readStringUntil(10);
  if (line == null) {
    println("Serial port " + portName + " is not responding.");
    println("Is it really a Teensy 3.0 running VideoDisplay?");
    errorCount++;
    return;
  }
  String param[] = line.split(",");
  if (param.length != 12) {
    println("Error: port " + portName + " did not respond to LED config query");
    errorCount++;
    return;
  }
  // only store the info and increase numPorts if Teensy responds properly
  //ledImage[numPorts] = new PImage(Integer.parseInt(param[0]), Integer.parseInt(param[1]), RGB);
  ledArea[numPorts] = new Rectangle(Integer.parseInt(param[5]), Integer.parseInt(param[6]),
                     Integer.parseInt(param[7]), Integer.parseInt(param[8]));
  ledLayout[numPorts] = (Integer.parseInt(param[5]) == 0);
  numPorts++;
}

// draw runs every time the screen is redrawn - show the movie...
void draw() {
  int[] movieOffset = {0, 80};
  // show the original video
  image(myMovie, movieOffset[0], movieOffset[1]);
  
  // Draw locations of LED sampling from video
  for (int p=0; p<ledPhysLocs.length; p++) {
    for (int s=0; s<ledPhysLocs[p].length; s++) {
      for (int l=0; l<ledPhysLocs[p][s].length; l++) {
        pushMatrix();
          
          translate(movieOffset[0], movieOffset[1]);
          noFill();
          rectMode(CENTER);
          
          stroke(255,255,255);     
          if (ledPhysLocs[p][s][l][0] != -1 && ledPhysLocs[p][s][l][1] != -1) {
            rect(ledPhysLocs[p][s][l][0]*ledLocScaler+ledLocXOffset, 
                 ledPhysLocs[p][s][l][1]*ledLocScaler+ledLocYOffset, 
                 ledLocAveArea+2, ledLocAveArea+2);
          }
          /*
          stroke(0,0,0);
          rect(ledPhysLocs[p][s][l][0]*ledLocScaler+ledLocOffset, 
               ledPhysLocs[p][s][l][1]*ledLocScaler+ledLocOffset, 
               ledLocAveArea+4, ledLocAveArea+4);
          
          stroke(255,255,255);
          rect(ledPhysLocs[p][s][l][0]*ledLocScaler+ledLocOffset, 
               ledPhysLocs[p][s][l][1]*ledLocScaler+ledLocOffset, 
               ledLocAveArea+6, ledLocAveArea+6);
          */
        popMatrix();
      }
    }
  }
  
  
  // then try to show what was most recently sent to the LEDs
  // by displaying all the images for each port.
  /*
  for (int i=0; i < numPorts; i++) {
    // compute the intended size of the entire LED array
    int xsize = percentageInverse(ledImage[i].width, ledArea[i].width);
    int ysize = percentageInverse(ledImage[i].height, ledArea[i].height);
    // computer this image's position within it
    int xloc =  percentage(xsize, ledArea[i].x);
    int yloc =  percentage(ysize, ledArea[i].y);
    // show what should appear on the LEDs
    image(ledImage[i], 240 - xsize / 2 + xloc, 10 + yloc);
  } 
  */
}

// respond to mouse clicks as pause/play
boolean isPlaying = true;
void mousePressed() {
  if (isPlaying) {
    myMovie.pause();
    isPlaying = false;
  } else {
    myMovie.play();
    isPlaying = true;
  }
}

// scale a number by a percentage, from 0 to 100
int percentage(int num, int percent) {
  double mult = percentageFloat(percent);
  double output = num * mult;
  return (int)output;
}

// scale a number by the inverse of a percentage, from 0 to 100
int percentageInverse(int num, int percent) {
  double div = percentageFloat(percent);
  double output = num / div;
  return (int)output;
}

// convert an integer from 0 to 100 to a float percentage
// from 0.0 to 1.0.  Special cases for 1/3, 1/6, 1/7, etc
// are handled automatically to fix integer rounding.
double percentageFloat(int percent) {
  if (percent == 33) return 1.0 / 3.0;
  if (percent == 17) return 1.0 / 6.0;
  if (percent == 14) return 1.0 / 7.0;
  if (percent == 13) return 1.0 / 8.0;
  if (percent == 11) return 1.0 / 9.0;
  if (percent ==  9) return 1.0 / 11.0;
  if (percent ==  8) return 1.0 / 12.0;
  return (double)percent / 100.0;
}
