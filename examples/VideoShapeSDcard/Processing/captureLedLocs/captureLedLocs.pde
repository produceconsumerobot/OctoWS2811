/* captureLedLocs
    Uses computer vision to detect LED locations controlled by OctoWS2811.
    Each LED is turned on one at a time and detected via background segmentation.
    Locations of detected LEDs are saved in ledPhysLocs.json
    Usage:
    - Plug in Teensy/Octos
    - Plug in webcam (if not using integrated webcam)
    - Change user-defined variables if desired
    - Run program
    - When program is complete ledPhysLocs.json has all led locations
*/

import gab.opencv.*;
import processing.video.*;
import java.awt.Rectangle;
import org.opencv.core.Point;
import processing.serial.*;
import java.awt.Color;
//import static javax.swing.JOptionPane.*;

// ----------- USER-DEFINED VARIABLES ------------- //

String serialPorts[] = {"COM22"};  // Serial ports of Teensy/Octos
String cameraName = "Microsoft LifeCam Studio,size=640x480,fps=30";
int cameraDelay = 150;      // Delay between LED-ON and camera frame capture. If you ever see any LEDs lit on the left pane, increase this number
int ledDrawRadius = 2;     // -1 uses computer vision detected radius
int maxTriesPerLed = 2;     // Number of times to try detecting an LED before moving on to next LED
int maxMissedLedsInRow = 3; // Number of failed LEDs before moving on to next strip
int minRadius = 1;          // Min size of CV LED detection
int maxRadius = 100;        // Max size of CV LED detection
int maxStrips = 8;          // Number of LED strips
int maxLedsPerStrip = 400;   // Number of LEDs per strip
Color backgroundLedColor = new Color(0, 0, 0);    // Color of LEDs for background subtraction
Color foregroundLedColor = new Color(255, 0, 0);  // Color of LEDs in ON state

// --------- END USER-DEFINED VARIABLES ------------- //

//Movie video;
OpenCV opencv;
Capture cam;
ArrayList<OctoWS2811> octos = new ArrayList<OctoWS2811>();
Color[][] colorData;
int _port = 0;
int _strip = 0;
int _led = 0;
int ledTryCounter = 0;
int missedLeds = 0;
color ledLocationColor = color(20, 200, 75);
color ledContourColor = color(20, 75, 200);
int cameraDelayTimer = millis();

int screenTextHeight = 48;
int padding = 10;
String screenText = "TESTING";

PImage background;
PImage foreground;
PImage  diffImage;
PImage drawImage;
Contour ledContour = null;
JSONObject ledLocation = null;
JSONObject _ledPhysLocsJSON = new JSONObject();

int LOG_ERROR = 3;
int LOG_NOTIFY = 4;
int LOG_VERBOSE = 5;
int LOG_LEVEL = LOG_NOTIFY;

int[][][][] _ledPhysLocs;

boolean getBkgnd = true;
boolean finished = false;

void setup() {
  size(320, 240);
  
  for (int j=0; j<serialPorts.length; j++) {
    octos.add(new OctoWS2811(this, serialPorts[j]));
    octos.get(j).setSerialMode(OctoWS2811.SerialModes.SERIAL_DISPLAY);
  }
  
  initColorData();
  octos.get(_port).writeFrame(colorData);
  
  //final String id = showInputDialog("Please enter new ID");
  //selectOutput("Select a file to write to:", "fileSelected");
  
  String[] cameras = Capture.list();
  
  if (cameras.length == 0) {
    println("There are no cameras available for capture.");
    exit();
  } else {
    println("Available cameras:");
    for (int i = 0; i < cameras.length; i++) {
      println(cameras[i]);
    }
    
    // The camera can be initialized directly using an 
    // element from the array returned by list():
    println("Loading: " + cameraName);
    cam = new Capture(this, cameraName);
    cam.start();     
  }      
  
  initLedPhysLocs();
}

void initLedPhysLocs() {
  _ledPhysLocs = new int[serialPorts.length][maxStrips][maxLedsPerStrip][3];
  for (int p=0; p<_ledPhysLocs.length; p++) {
    for (int s=0; s<_ledPhysLocs[p].length; s++) {
      for (int l=0; l<_ledPhysLocs[p][s].length; l++) {
        for (int x=0; x<3; x++) {
          _ledPhysLocs[p][s][l][x] = -1;
        }
      }
    }
  }  
}

void draw() {
  
  if (cam.available() == true && !finished) {
    captureImage();
  }
  
  int bg = 50;
  fill(bg,bg,bg);
  stroke(bg,bg,bg);
  rect(0,0,width,height);
  
  pushMatrix();
  scale(0.5);
  translate(0, screenTextHeight + padding);
  
  if (foreground != null && background != null) {
    //image(drawImage, 0, 0);
  
    
    image(background, 0, 0);
    image(foreground, background.width, 0);
    
    fill(0,0,0,0);
  
  
    if (!finished) {
      if (background != null) {
        translate(background.width, 0);
      }   
      
      if (ledContour != null) {
        noFill();
        stroke(255, 0, 0);
        strokeWeight(3); 
        ledContour.draw();
        stroke(ledContourColor);
        ledContour.getConvexHull().draw();
      }
      if (ledLocation != null) {
        stroke(ledLocationColor);
        ellipseMode(RADIUS);
        ellipse(ledLocation.getInt("x"), ledLocation.getInt("y"), ledLocation.getInt("radius"), ledLocation.getInt("radius"));
      } 
    } else {
      screenText = "COMPLETE";
    }
    
    drawLedPhysLocs();
    
    translate(0, -(screenTextHeight + padding));
    textSize(screenTextHeight);
    textAlign(CENTER, CENTER);
    fill(ledLocationColor);
    text(screenText, background.width / 2, screenTextHeight / 2); 
  }

  popMatrix();
}

void movieEvent(Movie m) {
  m.read();
}

boolean incrementLed() {
  if (_strip == 0 && _led == 0) {
    initColorData();
  }

  // Increment LED
  _led++;
  if (_led == maxLedsPerStrip || missedLeds == maxMissedLedsInRow) {
    _strip++;
    _led = 0;
    if (LOG_LEVEL >= LOG_VERBOSE)  {
      println("strip == " + _strip);
    }
  }
  if (_strip == maxStrips) {
    _port++;
    _strip = 0;
    if (LOG_LEVEL >= LOG_VERBOSE)  {
      println("port == " + _port);
    }
  }
  if (_port == octos.size()) {
    _led = 0;
    _strip = 0;
    _port = 0;
    return true; // finished!
  }
  return false;
}

void initColorData() {
  // setup colorData matrix
  colorData = new Color[octos.get(_port).getNumStrips()][octos.get(_port).getNumLedsPerStrip()];
  for (int s=0; s < colorData.length; s++) {
    for (int l=0; l < colorData[s].length; l++) {
      colorData[s][l] = backgroundLedColor;
    }
  }
}

void cvFindLed() {
  if (LOG_LEVEL >= LOG_VERBOSE)  {
      println("cvFindLed()");
  }
  boolean ledDetected = false;
  
  if (opencv != null) {
    
    //opencv.loadImage(cam);
    //opencv.updateBackground();
    //opencv.dilate();
    //opencv.erode();
    float maxArea = 0;
    int maxIndex = 0;
    ArrayList<Contour> contours = opencv.findContours();
    if (contours.size() > 0) {
      for (int i=0; i < contours.size(); i++) {
        if (contours.get(i).area() > maxArea) {
          maxArea = contours.get(i).area();
          maxIndex = i;
        }
      }
      ledContour = contours.get(maxIndex);
      Rectangle box = contours.get(maxIndex).getBoundingBox();
      //rect(box.x, box.y, box.width, box.height);
      ledLocation = new JSONObject(); 
      ledLocation.setInt("x", box.x + box.width / 2);
      ledLocation.setInt("y", box.y + box.height / 2);
      ledLocation.setInt("radius", min(box.width, box.height) / 2);
      
      if (ledLocation.getInt("radius") >= minRadius && ledLocation.getInt("radius") <= maxRadius) {
        _ledPhysLocs[_port][_strip][_led][0] = ledLocation.getInt("x");
        _ledPhysLocs[_port][_strip][_led][1] = ledLocation.getInt("y");
        _ledPhysLocs[_port][_strip][_led][2] = ledLocation.getInt("radius");
        ledDetected = true;
        missedLeds = 0;
      } 
    }
  }
  ledTryCounter++;
  if (ledDetected || ledTryCounter == maxTriesPerLed) {
    if (ledTryCounter == maxTriesPerLed) {
      missedLeds++;
    }
    if (_strip < octos.get(_port).getNumStrips() && _led < octos.get(_port).getNumLedsPerStrip()) {
      colorData[_strip][_led] = backgroundLedColor;
      octos.get(_port).writeFrame(colorData);
    }
    cameraDelayTimer = millis();
    finished = incrementLed();
    if (finished) {
      // we're done! save!
      saveLedLocsToJson(_ledPhysLocs);
    }    
    ledTryCounter = 0;
  }
  //if (missedLeds == maxMissedLedsInRow) {
  //  finished = true;
  //  saveLedLocsToJson(_ledPhysLocs);
  //}
  if (!ledDetected) {
    ledContour = null;
    ledLocation = null;
  }
}

void drawLedPhysLocs() {
  if (LOG_LEVEL >= LOG_VERBOSE)  {
      //println("drawLedPhysLocs()");
  }
  for (int p=0; p<_ledPhysLocs.length; p++) {
    for (int s=0; s<_ledPhysLocs[p].length; s++) {
      for (int l=0; l<_ledPhysLocs[p][s].length; l++) {
        if (_ledPhysLocs[p][s][l][0] >= 0) {
          stroke(ledLocationColor);
          ellipseMode(RADIUS);
          if (ledDrawRadius < 0) {
            ellipse(_ledPhysLocs[p][s][l][0], _ledPhysLocs[p][s][l][1], _ledPhysLocs[p][s][l][2], _ledPhysLocs[p][s][l][2]);
          } 
          else {
            ellipse(_ledPhysLocs[p][s][l][0], _ledPhysLocs[p][s][l][1], ledDrawRadius, ledDrawRadius);
          }
        }
      }
    }
  } 
}

void fileSelected(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel.");
  } else {
    println("User selected " + selection.getAbsolutePath());
  }
}

void captureImage() {
  if (LOG_LEVEL >= LOG_VERBOSE)  {
      //println("captureImage()");
  }
  readCamera();
  if (millis() - cameraDelayTimer > cameraDelay){
    if (getBkgnd) {
      background.copy(cam, 0, 0, cam.width, cam.height, 0, 0, cam.width, cam.height);
      
      // Turn on the next led
      if (_strip < octos.get(_port).getNumStrips() && _led < octos.get(_port).getNumLedsPerStrip()) {
        colorData[_strip][_led] = foregroundLedColor;
        octos.get(_port).writeFrame(colorData);
      }
      cameraDelayTimer = millis();

      opencv = new OpenCV(this, cam.width, cam.height);
      opencv.startBackgroundSubtraction(2, 3, 0.5);
      opencv.loadImage(background);
      opencv.updateBackground();
      //opencv = new OpenCV(this, background);
      drawImage = background;
      //opencv.updateBackground();
      //background = opencv.getSnapshot(opencv.getB()); 
      if (LOG_LEVEL >= LOG_VERBOSE)  {
        println("Updating Background");
      }
      
    } else {
      if (opencv != null) {
        foreground.copy(cam, 0, 0, cam.width, cam.height, 0, 0, cam.width, cam.height);
        opencv.loadImage(foreground);
        opencv.updateBackground();
        //opencv.diff(foreground);
        //diffImage = opencv.getSnapshot();
        drawImage = foreground;
        if (LOG_LEVEL >= LOG_VERBOSE)  {
          println("Updating foreground");
        }
        opencv.erode();
        opencv.dilate();
        cvFindLed();
      }
    }
    getBkgnd = !getBkgnd;
  }
}

void readCamera() {
    cam.read();
    
    if (cam.width > width || cam.height / 2 > height) {
      surface.setResizable(true);
      println("reset frame size: " + cam.width +","+ cam.height +","+ width +","+ height);
      surface.setSize(cam.width, cam.height / 2 + screenTextHeight + padding);
      surface.setResizable(false);
      
      background = new PImage(cam.width, cam.height);
      foreground = new PImage(cam.width, cam.height);
      drawImage = new PImage(cam.width, cam.height);
      diffImage = new PImage(cam.width, cam.height);
      
      //opencv = new OpenCV(this, cam.width, cam.height);
      //opencv.startBackgroundSubtraction(5, 3, 0.5);
    }
}

void keyReleased() {
  if (key == ' ') {
    captureImage();
  }
}

void saveLedLocsToJson(int[][][][] ledPhysLocs) {
  println("Saving LED locations to file...");

  // JSON structure  
  //{'ports': [ 
  //    {'strips': [ 
  //        {'leds': [
  //            {'x': , 'y': , 'radius': },
  //            {'x': , 'y': , 'radius': },
  //            {'x': , 'y': , 'radius': }
  //        ] },
  //        {'leds': [
  //            {'x': , 'y': , 'radius': },
  //            {'x': , 'y': , 'radius': }
  //        ] }
  //    ] }
  //] }
  
  JSONObject ledPhysLocsJSON = new JSONObject();
  JSONArray ports = new JSONArray();
  for (int p=0; p<ledPhysLocs.length; p++) {
    JSONObject port = new JSONObject();
    JSONArray strips = new JSONArray();
    for (int s=0; s<ledPhysLocs[p].length; s++) {
      JSONObject strip = new JSONObject();
      JSONArray leds = new JSONArray();
      for (int l=0; l<ledPhysLocs[p][s].length; l++) {
        JSONObject led = new JSONObject();
        led.setInt("x", ledPhysLocs[p][s][l][0]);
        led.setInt("y", ledPhysLocs[p][s][l][1]);
        led.setInt("radius", ledPhysLocs[p][s][l][2]);
        leds.setJSONObject(l, led);
      }
      strip.setJSONArray("leds", leds);
      strips.setJSONObject(s, strip);
    }
    port.setJSONArray("strips", strips);
    ports.setJSONObject(p, port);
  }
  ledPhysLocsJSON.setJSONArray("ports", ports);
  
  saveJSONObject(ledPhysLocsJSON, "ledPhysLocs.json");
}
