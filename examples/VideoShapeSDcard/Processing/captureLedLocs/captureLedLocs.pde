import gab.opencv.*;
import processing.video.*;

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
  
  if (drawImage != null) {
    //image(drawImage, 0, 0);
  
  
    pushMatrix();
    scale(0.5);
    image(background, 0, 0);
    image(foreground, background.width, 0);
    image(diffImage, background.width, background.height);
    popMatrix();
  }
  
  
  
  
  if (opencv != null) {
    
    
    
    //opencv.loadImage(cam);
    //opencv.updateBackground();
    //opencv.dilate();
    //opencv.erode();
    noFill();
    stroke(255, 0, 0);
    strokeWeight(3);
    for (Contour contour : opencv.findContours()) {
      contour.draw();
    }  
  }  



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
    //if (opencv != null) {
      if (getBkgnd) {
        
        
        background.copy(cam, 0, 0, cam.width, cam.height, 0, 0, cam.width, cam.height);
        
        //opencv.loadImage(background);
        opencv = new OpenCV(this, background);
        drawImage = background;
        //opencv.updateBackground();
        //background = opencv.getSnapshot(opencv.getB()); 
        println("Updating Background");
      } else {
        if (opencv != null) {
        foreground.copy(cam, 0, 0, cam.width, cam.height, 0, 0, cam.width, cam.height);
        opencv.diff(foreground);
        
        diffImage = opencv.getSnapshot();
        drawImage = diffImage;
        
        println("Updating foreground");
        //foreground = opencv.getSnapshot(opencv.getB()); 
        //opencv.erode();
        //opencv.dilate();
        }
    
      }
      getBkgnd = !getBkgnd;
    //}
  }
}
    
    
