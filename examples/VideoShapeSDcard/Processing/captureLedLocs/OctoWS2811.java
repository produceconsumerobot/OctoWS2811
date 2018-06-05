// ------------------------------------------------------------------------------
//package com.ProduceConsumeRobot.OctoWS2811;

// serial display writing
//  serialConfigure
//  startSerial
//  stopSerial
//  
// serial sd writing
//  serialConfigure
//  startSerialSd
//  stopSerialSd
//  
// sd writing
//  
// Everybody
//  ledLocsArray
//  shape2data
//  loadLedLocsFromJson
//  saveJsonFromLedLocs
//  colorWiring
//  writeFrame

import processing.serial.*;
import java.awt.Color;
import processing.core.*;

  
public class OctoWS2811 {
  //private color c;
  
  public enum SerialModes {
  OFF,
  SERIAL_DISPLAY,
  SERIAL_SD_WRITE;
  }
  
  public enum LedModes {
    RGB,
    GRB;
  }
 
  private boolean _isMaster;
  private String _serialPort;
  private Serial _ledSerial;
  private int _nStrips;
  private int _nLedsPerStrip;
  private SerialModes _serialMode;
  private LedModes _ledMode;
  private float _targetFrameRate;
  long _elapsed_picoseconds;
  long _elapsed_microseconds;
  long _picoseconds_per_frame;
  private PApplet _pApplet;
  int[] _gammatable;
  private float _gamma;
   //<>//
  public OctoWS2811(PApplet pApplet, String serialPort) {
    if (pApplet != null) {
      init();
      _serialPort = serialPort;
      //_ledSerial = new Serial(pApplet, serialPort);
      _pApplet = pApplet;
    } else {
       throw new NullPointerException();
    }
  }

  private void init() {
    _isMaster = true;
    _serialPort = "";
    _ledSerial = null;
    _pApplet = null;
    _nStrips = 8;
    _nLedsPerStrip = 552;
    _serialMode = SerialModes.OFF;
    _ledMode = LedModes.GRB;
    _targetFrameRate = (float) 60.0;
    _picoseconds_per_frame = (long)(1e12 /_targetFrameRate + 0.5);
    _elapsed_picoseconds=0L;
    _elapsed_microseconds=0L;
    _gammatable = new int[256];
    _gamma = 1.8f;
    setupGammaTable(_gamma);
  }
  
  public int getNumStrips() {
    return _nStrips;
  }
    
  public int getNumLedsPerStrip() {
    return _nLedsPerStrip;
  }
  
  /**
  * Write a 2D array of colorData to the Teensy over serial.
  * 
  * @param image - A color[][] to be written
  */
  public boolean writeFrame(Color[][] colorData) {
    int mask;
    int pixel[] = new int[8];
    int offset = 0;
    if (_serialMode == SerialModes.SERIAL_DISPLAY) {
      offset = 3;
    }
    if (_serialMode == SerialModes.SERIAL_SD_WRITE) {
      offset = 5;
    }
    
    byte[] ledData = new byte[(_nStrips * _nLedsPerStrip * 3) + offset];
    
    // Setup frame header
    if (_serialMode == SerialModes.SERIAL_DISPLAY) {
      if (_isMaster) {
        ledData[0] = '*';  // first Teensy is the frame sync master
        int usec = (int)((1000000.0 / _targetFrameRate) * 0.75);
        ledData[1] = (byte)(usec);   // request the frame sync pulse
        ledData[2] = (byte)(usec >> 8); // at 75% of the frame time
      } else {
        ledData[0] = '%';  // others sync to the master board
        ledData[1] = 0;
        ledData[2] = 0;
      }
    }
    if (_serialMode == SerialModes.SERIAL_SD_WRITE) {
      _elapsed_picoseconds += _picoseconds_per_frame;
      int usec = (int)((_elapsed_picoseconds / 1000000L) - _elapsed_microseconds);
      _elapsed_microseconds += (long)usec;
      //if (LOG_LEVEL >= LOG_VERBOSE)  {
      //  println("usec = " + usec);
      //}
      if (_isMaster) {
        ledData[0] = '*';  // first Teensy is the frame sync master
        ledData[1] = (byte)(_nStrips * _nLedsPerStrip);
        ledData[2] = (byte)((_nStrips * _nLedsPerStrip) >> 8);
        ledData[3] = (byte)(usec);   // request the frame sync pulse
        ledData[4] = (byte)(usec >> 8); // at 75% of the frame time
      } else {
        // ToDo: Add slave SERIAL_SD_WRITE
        System.out.println("WARNING: OCTOWS2811 SLAVE SERIAL_SD_WRITE NOT YET IMPLEMENTED");
      }
    }
    
    // Unpack colorData into ledData
    for (int l = 0; l < _nLedsPerStrip; l++) {
      for (int s = 0; s < 8; s++) {
        if (s < _nStrips && s < colorData.length && l < colorData[s].length) {
          pixel[s] = colorData[s][l].getRGB();
        }
        else {
          pixel[s] = 0;
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
        ledData[offset++] = b;
      }
    }
    
    // send the raw data to the LEDs  :-)
    try {  
      _ledSerial.write(ledData); 
    } catch (Exception e) { 
      System.out.println("Error: serial write failed");
      e.printStackTrace();
      return false;
    } 
    return true;
  }
  
  // translate the 24 bit color from RGB to the actual
  // order used by the LED wiring.  GRB is the most common.
  private int colorWiring(int c) {
    int red = (c & 0xFF0000) >> 16;
    int green = (c & 0x00FF00) >> 8;
    int blue = (c & 0x0000FF);
    red = _gammatable[red];
    green = _gammatable[green];
    blue = _gammatable[blue];
    if (_ledMode == LedModes.GRB) {
      return (green << 16) | (red << 8) | (blue); // GRB - most common wiring
    } 
    else if (_ledMode == LedModes.RGB) {
      return (red << 16) | (green << 8) | (blue); // RGB - most common wiring
    }
    else {
      return (green << 16) | (red << 8) | (blue); // default to GRB 
    }
  }
  
  void setLedMode(LedModes ledMode) {
    _ledMode = ledMode;
  }

  // Close all serial ports
  private boolean closeSerialOut() {
    _serialMode = SerialModes.OFF;
    if (_ledSerial != null) {
      try {
        System.out.println("Closing serial port: " + _serialPort);
        _ledSerial.stop();
      } catch (Exception e) {
        System.out.println("Error: " + _serialPort + ".stop() failed"); //<>//
        //e.printStackTrace();
        //exit();
        return false;
      }
    }
    return true;
  }
  
  // Send serial signal to close SD file
  private boolean closeSerialSdWrite() {
    _serialMode = SerialModes.OFF;
    try {  
      _ledSerial.write(']'); 
      String line = "";
      while (line != null) {
        System.out.print(line);
        Thread.sleep(100);
        line = _ledSerial.readStringUntil(10);
      }
    } catch (Exception e) { 
      System.out.println("Error: OctoWs2811 closeSerialSdFile failed");
      e.printStackTrace();
      return false;
    }
    return true;
  }
  
  private boolean openSerialSdWrite() {
    boolean success = false;
    int nErrors = serialConfigure(_serialPort);
    if (nErrors == 0) {
      try {  
        System.out.print("serialPort[" + _serialPort + "]: \n");
        _ledSerial.write('!'); 
        String line = "";
        int tries = 0;
        while (tries < 500) {
          if (line != null) {
            System.out.print(line);
            // Check for an error message
            //if (match(line.matches(, "error:") != null) { //<>//
            if (line.equals("error:")) {
              System.out.println("Error detected"); //<>//
            //} else if (match(line, "File opened:") != null) {
            } else if (line.equals("File opened:")) {
              success = true;
              break;
            }
          }
          Thread.sleep(20); // Wait for all messages to come through
          line = _ledSerial.readStringUntil(10);
          tries++;
        }
      } catch (Exception e) { 
        System.out.println("Error: serial write failed");
        e.printStackTrace(); //<>//
        //exit();
      } 
    }      
    if (success) {
      _serialMode = SerialModes.SERIAL_SD_WRITE;
      _elapsed_picoseconds = 0L;
      _elapsed_microseconds = 0L;
      return true;
    } else {
      System.out.println("OctoWs2811: openSerialSdWrite failed");
      closeSerialOut();
      return false;
    }
  }
  
  private boolean openSerialWrite() {
    int nErrors = serialConfigure(_serialPort);
    if (nErrors == 0) {
      _serialMode = SerialModes.SERIAL_DISPLAY;
      return true;
    } else {
      System.out.println("OctoWs2811: openSerialWrite failed");
      closeSerialOut();
      return false;
    }
  }
  
  // ask a Teensy board for its LED configuration, and set up the info for it.
  private int serialConfigure(String portName) {
    
    int errorCount = 0;
    //Serial ledSerial = _ledSerial;
    try {
      _ledSerial = new Serial(_pApplet, portName);
      if (_ledSerial == null) {
        Serial.list();
        throw new NullPointerException();
      }
      // Clear the serial buffer
      String line = "";
      while (line != null) {
        Thread.sleep(100);
        line = _ledSerial.readStringUntil(10);
        System.out.println("Serial read data: " + line);
      }
      // Switch Teensy to SERIAL_serialMode
      _ledSerial.write('^');
      Thread.sleep(50);
      System.out.println(portName + ": " + _ledSerial.readStringUntil(10));
      _ledSerial.write('?');
    } catch (Throwable e) {
      System.out.println("Serial port " + portName + " does not exist or is non-functional");
      e.printStackTrace();
      errorCount++;
      return errorCount;
    }
    try {
      Thread.sleep(50);
    } catch (Throwable e) {e.printStackTrace();}
    String line = _ledSerial.readStringUntil(10);
    if (line == null) {
      System.out.println("Serial port " + portName + " is not responding.");
      System.out.println("Is it really a Teensy 3.0 running VideoDisplay?");
      errorCount++;
      return errorCount;
    }
    System.out.print(line);
    String param[] = line.split(",");
    if (param == null || param.length < 2) {
      System.out.println("Error: port " + portName + " did not return array size from LED config query");
      errorCount++;
      return errorCount;
    } 
    else {
      _nStrips = Integer.parseInt(param[1]);
      System.out.println("OctoWS2811: " + _nStrips + " strips");
      _nLedsPerStrip = Integer.parseInt(param[0]);
      System.out.println("OctoWS2811: " + _nLedsPerStrip + " Leds Per Strip");      
    }
    
    if (errorCount == 0) {
      //_ledSerial = ledSerial;
    }
    
    return errorCount;
  }
  
  public SerialModes getSerialMode() {
    return _serialMode;
  }
  
  public boolean setSerialMode(SerialModes s) {
    if (s == SerialModes.OFF) {
      if (_serialMode == SerialModes.SERIAL_SD_WRITE) {
        closeSerialSdWrite();
      }
      closeSerialOut();
      System.out.println("OctoWs2811: Serial mode OFF");
      return true;
    }
    if (s == SerialModes.SERIAL_DISPLAY) {
      if (_serialMode == SerialModes.SERIAL_SD_WRITE) {
        closeSerialSdWrite();
      }
      closeSerialOut();
      if (openSerialWrite()) {
        System.out.println("OctoWs2811: SERIAL_DISPLAY mode");
        return true;
      }
    }
    if (s == SerialModes.SERIAL_SD_WRITE) {
      closeSerialOut();
      if (openSerialWrite()) {
        System.out.println("OctoWs2811: SERIAL_SD_WRITE mode");
        return true;
      }
    }
    return false;
  }
  
  void setupGammaTable(float gamma) {
    // Set up the Gamma table
    for (int i=0; i < 256; i++) {
      _gammatable[i] = (int)(Math.pow((float)(i / 255.0), gamma) * 255.0 + 0.5);
    }
  }
}

  
/*   public serialSdWriteFrame(PImage image) {
    elapsed_picoseconds += picoseconds_per_frame;
    int usec = (int)((elapsed_picoseconds / 1000000L) - elapsed_microseconds);
    elapsed_microseconds += (long)usec;
    if (LOG_LEVEL >= LOG_VERBOSE)  {
      println("usec = " + usec);
    }
    
    // convert the LED image to raw data
    for (int p=0; p < ledPhysLocs.length; p++) {  
      int offset = 5;
      byte[] ledData = new byte[(ledPhysLocs[p].length * ledPhysLocs[p][0].length * 3) + offset];
      shape2data(ledImage, ledData, p, offset);
      ledData[0] = '*';  // first Teensy is the frame sync master
      
      ledData[1] = (byte)(ledPhysLocs[p].length * ledPhysLocs[p][0].length);
      ledData[2] = (byte)((ledPhysLocs[p].length * ledPhysLocs[p][0].length) >> 8);
      ledData[3] = (byte)(usec);   // request the frame sync pulse
      ledData[4] = (byte)(usec >> 8); // at 75% of the frame time

      // send the raw data to the LEDs  :-)
      try {  
        ledSerial[p].write(ledData); 
      } catch (Exception e) { 
        println("Error: serial write failed");
        e.printStackTrace();
        exit();
      } 
    }
  } */
  
/*   // Grab data from video frame specified by ledPhysLocs
  private void shape2data(PImage image, byte[] data, int port, int offset) {
    int mask;
    int pixel[] = new int[8];
    
    //println(port +","+ ledPhysLocs[port][0][0][0] +","+ image.width);
      
    for (int l=0; l<ledPhysLocs[port][0].length; l++) {
      for (int s=0; s < 8; s++) {
        
        // get position in image.pixels
        // pixel[s] = x + (y * w)
        if (ledPhysLocs[port][s][l][0] < 1 || ledPhysLocs[port][s][l][1] < 1) {
          pixel[s] = 0;
        } else {
          int pixNum = int((ledPhysLocs[port][s][l][0]-1)*myParams.ledLocScaler+myParams.ledLocXOffset) + // x offset
            int((ledPhysLocs[port][s][l][1]-1)*myParams.ledLocScaler+myParams.ledLocYOffset) * image.width;
          //println(pixNum + "," + image.width+ "," + image.height + "," + image.pixels.length);
          if (pixNum < image.pixels.length) {
            pixel[s] = image.pixels[pixNum];
          } else {
            pixel[s] = 0;
          }
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
  } */
  
  //------------------------------------------------------------------------------