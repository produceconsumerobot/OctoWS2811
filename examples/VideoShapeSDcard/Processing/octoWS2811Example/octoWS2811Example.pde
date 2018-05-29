
import processing.serial.*;
import com.ProduceConsumeRobot.OctoWS2811.*;
import java.awt.Color;

String serialPort = "COM22";
OctoWS2811 octo;
Color[][] colorData;
int strip;
int led;

void setup() {
  octo = new OctoWS2811(new Serial(this));
  octo.setup(serialPort);
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

void main() {

  // Zero LED
  colorData[strip][led] = new Color(0);
  
  // Increment LED
  led++;
  if (led == colorData[strip].length) {
    strip++;
    led = 0;
  }
  if (strip == colorData.length) {
    strip = 0;
  }
  
  // Turn on LED
  colorData[strip][led] = new Color(0);;
  
  octo.writeFrame(colorData);
  
  delay(500);
}
