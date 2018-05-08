import gab.opencv.*;
import processing.video.*;
import java.awt.Rectangle;
import org.opencv.core.Point;

//Movie video;
OpenCV opencv;
Capture cam;

PImage background;
PImage foreground;
PImage  diffImage;
PImage drawImage;

boolean getBkgnd = true;

void setup() {
  size(320, 240);
   
  //video = new Movie(this, "C:/priv/gd2/Dropbox/LocalDev/Sean/Processing/Processing3.0/videoExample01/SunSurface02_320x240_SaS_90_2000_01.mov");
  //surface.setSize(video.width, video.height);
  //opencv = new OpenCV(this, 320, 240);
  //opencv.startBackgroundSubtraction(5, 3, 0.5);
  
  //video.loop();
  //video.play();
  
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
    cam = new Capture(this, cameras[0]);
    cam.start();     
  }      
}

void draw() {
  
  if (cam.available() == true) {
    //readCamera();
  }
  
  pushMatrix();
  if (drawImage != null) {
    //image(drawImage, 0, 0);
  
  
    
    scale(0.5);
    image(background, 0, 0);
    image(foreground, background.width, 0);
    image(diffImage, background.width, background.height);
    
  }
  
  
  
  
  if (opencv != null) {
    
    //opencv.loadImage(cam);
    //opencv.updateBackground();
    //opencv.dilate();
    //opencv.erode();
    translate(background.width, 0);
    noFill();
    stroke(255, 0, 0);
    strokeWeight(3);
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
      
      color c;
      contours.get(maxIndex).draw();
      c = color(20, 75, 200);
      stroke(c);
      contours.get(maxIndex).getConvexHull().draw();
      c = color(20, 200, 75);
      stroke(c);
      Rectangle box = contours.get(maxIndex).getBoundingBox();
      //rect(box.x, box.y, box.width, box.height);
      float ledX = box.x + box.width / 2;
      float ledY = box.y + box.height / 2;
      float ledRadius = min(box.width, box.height) / 2;
      ellipseMode(RADIUS);
      ellipse(ledX, ledY, ledRadius, ledRadius);
    }
  }  

  popMatrix();

}

void movieEvent(Movie m) {
  m.read();
}

void readCamera() {
    cam.read();
    
    if (cam.width > width || cam.height > height) {
      surface.setResizable(true);
      println("reset frame size: " + cam.width +","+ cam.height +","+ width +","+ height);
      surface.setSize(cam.width, cam.height);
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
    readCamera();
    if (background != null) {
      if (getBkgnd) {
        
        
        background.copy(cam, 0, 0, cam.width, cam.height, 0, 0, cam.width, cam.height);

        opencv = new OpenCV(this, cam.width, cam.height);
        opencv.startBackgroundSubtraction(2, 3, 0.5);
        opencv.loadImage(background);
        opencv.updateBackground();
        //opencv = new OpenCV(this, background);
        drawImage = background;
        //opencv.updateBackground();
        //background = opencv.getSnapshot(opencv.getB()); 
        println("Updating Background");
      } else {
        if (opencv != null) {
        foreground.copy(cam, 0, 0, cam.width, cam.height, 0, 0, cam.width, cam.height);
        opencv.loadImage(foreground);
        opencv.updateBackground();
        //opencv.diff(foreground);
        //diffImage = opencv.getSnapshot();
        drawImage = foreground;
        
        println("Updating foreground");
        //foreground = opencv.getSnapshot(opencv.getB()); 
        opencv.erode();
        opencv.dilate();
        }
    
      }
      getBkgnd = !getBkgnd;
    }
  }
}
    
    
