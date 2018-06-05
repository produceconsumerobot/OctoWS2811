import processing.serial.*;
import java.awt.Color;
import processing.core.*;

public class ShapeToOcto {
  
  private ArrayList<OctoWS2811> _octos;
  private ArrayList<Color[][]> _colorData;
  private int[][][][] _ledPhysLocs;
  
  
  ShapeToOcto(PApplet pApplet, String[] serialPorts) {
    _octos = new ArrayList<OctoWS2811>();
    for (int p=0; p<serialPorts.length; p++) {
      _octos.add(new OctoWS2811(pApplet, serialPorts[p]));
      _colorData.add(new Color[_octos.get(p).getNumStrips()][_octos.get(p).getNumLedsPerStrip()]);
    }
    initColorData(new Color(0,0,0));
  }
  
  private void initColorData(Color c) {
    for (int p=0; p<_colorData.size(); p++) {
      for (int s=0; s<_colorData.get(p).length; s++) {
        for (int l=0; l<_colorData.get(p)[s].length; l++) {
          _colorData.get(p)[s][l] = c;
        }
      }
    }
  }
  
  public void setLedPhysLocs(int[][][][] ledPhysLocs) {
    _ledPhysLocs = ledPhysLocs;
  }
  
  public void writeFrame(PImage image) {
    for (int p=0; p<_ledPhysLocs.length; p++) {
      for (int s=0; s<_ledPhysLocs[p].length; s++) {
        for (int l=0; l<_ledPhysLocs[p][s].length; l++) {
           
          if (p < _colorData.size() && s < _colorData.get(p).length && l < _colorData.get(p)[s].length) {
            if (_ledPhysLocs[p][s][l][0] < 1 || _ledPhysLocs[p][s][l][1] < 1) {
              // Out of bounds 
              _colorData.get(p)[s][l] = new Color(0);
            } else {
              int pixNum = int((_ledPhysLocs[p][s][l][0]-1) + int((_ledPhysLocs[p][s][l][1]-1)) * image.width);
              if (pixNum >= 0 && pixNum < image.pixels.length) {
                _colorData.get(p)[s][l] = new Color(image.pixels[pixNum]);
              } else {
                _colorData.get(p)[s][l] = new Color(0);
              }
            }
          }
        }
      }
      _octos.get(p).writeFrame(_colorData.get(p));
    }
  }
}
 
