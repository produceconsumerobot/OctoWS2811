 //<>//
import processing.serial.*;
//import com.ProduceConsumeRobot.OctoWS2811.*;
import java.awt.Color;

String serialPort = "COM22";
OctoWS2811 octo;
Color[][] colorData;
int strip;
int led;

int r=255;
int g=0;
int b=0;


void setup() {
  size(640, 360);

  octo = new OctoWS2811(this, serialPort);
  octo.setLedMode(OctoWS2811.LedModes.RGB);
  octo.setSerialMode(OctoWS2811.SerialModes.SERIAL_DISPLAY);

  strip = 0;
  led = 0;

  // setup colorData matrix
  colorData = new Color[octo.getNumStrips()][octo.getNumLedsPerStrip()];
  for (int s=0; s < colorData.length; s++) {
    for (int l=0; l < colorData[s].length; l++) {
      colorData[s][l] = new Color(0);
    }
  }
}

void draw() {
  // Turn on LED
  //if (r == 255) {
  //  r = 0;
  //  g = 255; 
  //}
  //else if (g == 255) {
  //  g = 0;
  //  b = 255;
  //}
  //else if (b == 255) {
  //  b = 0;
  //  r = 255;
  //}

  changeAllLedColor(new Color(r, g, b));

  octo.writeFrame(colorData);

  delay(1000);
}

void changeAllLedColor(Color c) {
  for (int s=0; s < colorData.length; s++) {
    for (int l=0; l < colorData[s].length; l++) {
      colorData[s][l] = c;
    }
  }
}
