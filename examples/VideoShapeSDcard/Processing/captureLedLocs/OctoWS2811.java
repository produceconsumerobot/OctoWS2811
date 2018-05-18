
public class VideoShapeSdCard {
  private OctoWS2811 octo;
  private JSONObject ledLocations;
  
  // Grab data from video frame specified by ledPhysLocs
  void shape2data(PImage image, byte[] data, int port, int offset) {
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
  }
}

public class OctoWS2811 {
  
  private string serialPort;
  private Serial ledSerial;
  
}
  
  
  
  // Write frame to the Teensy on each serial port
  if (serialOutOn) {
    // ShapeDisplay code
    //println("serialOutOn");
    for (int p=0; p < ledPhysLocs.length; p++) {  
      int offset = 3;
      byte[] ledData = new byte[(ledPhysLocs[p].length * ledPhysLocs[p][0].length * 3) + offset];
      
      // Extract LED data from the image
      shape2data(ledImage, ledData, p, offset);
      
      if (p == 0) {
        ledData[0] = '*';  // first Teensy is the frame sync master
        int usec = (int)((1000000.0 / myParams.targetFrameRate) * 0.75);
        ledData[1] = (byte)(usec);   // request the frame sync pulse
        ledData[2] = (byte)(usec >> 8); // at 75% of the frame time
      } else {
        ledData[0] = '%';  // others sync to the master board
        ledData[1] = 0;
        ledData[2] = 0;
      }
      // send the raw data to the LEDs  :-)
      try {  
        ledSerial[p].write(ledData); 
      } catch (Exception e) { 
        println("Error: serial write failed");
        e.printStackTrace();
        exit();
      } 
    }         
  }
  
    if (serialSdWriteOn) {
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

  if (serialSdWriteOn) {
    //if (myMovie.time() >= 10) {
    if (myMovie.time() >= myMovie.duration() - 1 / myParams.targetFrameRate) {
      println("Movie serial SD writing complete!");
      myMovie.stop();
      isPlaying = false;
      serialSdWriteOn = false;
      for (int p=0; p < ledPhysLocs.length; p++) {
        try {  
          ledSerial[p].write(']'); 
          String line = "";
          while (line != null) {
            print(line);
            delay(100);
            line = ledSerial[p].readStringUntil(10);
          }
        } catch (Exception e) { 
          println("Error: serial write failed");
          e.printStackTrace();
          exit();
        }
      }
    }
  }
}

// Close all serial ports
void closeSerialOut() {
  serialOutOn = false;
  for (int i=0; i<serialPorts.length; i++) {
    try {
      println("Closing serial port: " + serialPorts[i]);
      ledSerial[i].stop();
    } catch (Exception e) {
      println("Error: " + serialPorts[i] + ".stop() failed");
      //e.printStackTrace();
      //exit();
    }
  }
  numPorts = 0;
}


// ask a Teensy board for its LED configuration, and set up the info for it.
int serialConfigure(int port) {
  String portName = serialPorts[port];
  
  int errorCount = 0;
  
  numPorts++;
  
  if (numPorts >= maxPorts) {
    println("too many serial ports, please increase maxPorts: ");
    errorCount++;
    return errorCount;
  }
  try {
    ledSerial[port] = new Serial(this, portName);
    if (ledSerial[port] == null) throw new NullPointerException();
    // Clear the serial buffer
    String line = "";
    while (line != null) {
      delay(100);
      line = ledSerial[port].readStringUntil(10);
      print(line);
    }
    // Switch Teensy to SERIAL_MODE
    ledSerial[port].write('^');
    delay(50);
    println(serialPorts[port] + ": " + ledSerial[port].readStringUntil(10));
    ledSerial[port].write('?');
  } catch (Throwable e) {
    println("Serial port " + portName + " does not exist or is non-functional");
    e.printStackTrace();
    errorCount++;
    return errorCount;
  }
  delay(50);
  String line = ledSerial[port].readStringUntil(10);
  if (line == null) {
    println("Serial port " + portName + " is not responding.");
    println("Is it really a Teensy 3.0 running VideoDisplay?");
    errorCount++;
    return errorCount;
  }
  print(line);
  String param[] = line.split(",");
  if (param == null || param.length < 2) {
    println("Error: port " + portName + " did not return array size from LED config query");
    errorCount++;
    return errorCount;
  }

  if (int(param[1]) != ledPhysLocs[port].length) {
    println("Error: nStrips doesn't match for port " + portName);
    errorCount++;
    return errorCount;
  }  
  
  if (int(param[0]) != ledPhysLocs[port][0].length) {
    println("Error: nLedsPerStrip doesn't match for port " + portName);
    errorCount++;
    return errorCount;
  }  
  
  return errorCount;
}

oid keyReleased() {
  if (key == '^') {
    if (!serialSdWriteOn) {
      // Only start serialOut if not in serialSdWriteOn mode
      if (!serialOutOn) {
        closeSerialOut();
        if (setupSerialOut()) serialOutOn = true;
      } else {
        closeSerialOut();
      }
    } else {
      println("Can't enable serialOutOn when serialSdWriteOn");
    }
    println("serialOutOn=" + serialOutOn);
  } else if (key == '!') {
    if (!serialSdWriteOn) {            
      if (!serialOutOn) {
        // Setup serial if necessary
        // If serial doesn't work don't continue
        if (!setupSerialOut()) return;
      }
      myMovie.stop();
      for (int p=0; p < ledPhysLocs.length; p++) {
        try {  
          print("serialPort[" + p + "]: \n");
          ledSerial[p].write('!'); 
          String line = "";
          int tries = 0;
          while (tries < 500) {
            if (line != null) {
              print(line);
              // Check for an error message
              if (match(line, "error:") != null) {
                println("Error detected");
                serialSdWriteOn = false;
                return;
              } else if (match(line, "File opened:") != null) {
                
                serialOutOn = false;
                serialSdWriteOn = true;
                break;
              }
            }
            delay(20); // Wait for all messages to come through
            line = ledSerial[p].readStringUntil(10);
            tries++;
          }
        } catch (Exception e) { 
          println("Error: serial write failed");
          e.printStackTrace();
          exit();
        }
      }
      if (serialSdWriteOn) {
        elapsed_picoseconds = 0L;
        elapsed_microseconds = 0L;
        myMovie.play();
        println("Estimated write time: " + myMovie.duration() 
          * targetFrameRate/mFrameRate + " seconds");
      } 
    } else {
      // Stop the serial SD write
      println("Stopping movie serial SD writing!");
      myMovie.stop();
      isPlaying = false;
      serialSdWriteOn = false;
      for (int p=0; p < ledPhysLocs.length; p++) {
        try {  
          ledSerial[p].write(']'); 
          String line = "";
          while (line != null) {
            print(line);
            delay(100);
            line = ledSerial[p].readStringUntil(10);
          }
        } catch (Exception e) { 
          println("Error: serial write failed");
          e.printStackTrace();
          exit();
        }
      }
      myMovie.loop();
      isPlaying = true;
    }
    println("serialSdWriteOn=" + serialSdWriteOn);
  } 
  /*else if (key == 'm') {
    // Toggle movie display
    movieOn = !movieOn;
    println("movieOn=" + movieOn);
  } */
  else if (key == 'v') {
    // Toggle sampling display
    sampledValuesOn = !sampledValuesOn;
    println("sampledValuesOn=" + sampledValuesOn);
  } else if (key == 'p') {
    // Toggle sampling grid
    samplingPointsOn = !samplingPointsOn;
    println("samplingPointsOn=" + samplingPointsOn);
  } else if (key == 'w') {
    // Toggle SD card writing
    myMovie.stop();
    sdWriteOn = !sdWriteOn;
    println("sdWriteOn=" + sdWriteOn);
    if (sdWriteOn) {
      // Restart video from beginning and play once
      //myMovie.stop();
      setupSdWrite();
      elapsed_picoseconds = 0L;
      elapsed_microseconds = 0L;
      myMovie.play();
      println("Estimated write time: " + myMovie.duration() 
          * targetFrameRate/mFrameRate + " seconds");
    } else {
      closeSdWrite();
      // Turn on video looping
      myMovie.loop();
    }
    println("myMovie.time()=" + myMovie.time());
  } else if (key == 'L') {
    LOG_LEVEL = (LOG_LEVEL+1) % 6;
    println("LOG_LEVEL=" + LOG_LEVEL);
  }  else if (key == 'l') {
    LOG_LEVEL = (LOG_LEVEL-1) % 6;
    println("LOG_LEVEL=" + LOG_LEVEL);
  } else if (key == '{') {
    println("Loading Parameters: " + myParams.paramFileName);
    myParams.load();
    println(myParams.toString());
    loadLedLocsFromJson();
  } else if (key == '}') {
    println("Saving Parameters: " + myParams.paramFileName);
    println(myParams.toString());
    myParams.save();
    saveLedLocsToJson();
  } else if (key == '&') {
    serialOutOn = false;
    delay(50);
    // Send the Teensies into SD_CARD_MODE
    println("Sending Teensies into SD_CARD_MODE");
    for (int p=0; p<serialPorts.length; p++) {
      if (ledSerial[p] != null) {
        ledSerial[p].write(key);
        print("serialPort[" + p + "]: \n");
        String line = "";
        while (line != null) {
          print(line);
          delay(200);
          line = ledSerial[p].readStringUntil(10);
        }
      }
    }
    //closeSerialOut();
    //exit();
  }
}

