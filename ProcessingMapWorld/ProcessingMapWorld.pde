// read four analog values from serial (range 0-1023) and graph those values over time.
// Dan Royer (dan@marginallyclever.com)
// 2016-05-14
// based on https://www.arduino.cc/en/Tutorial/Graph by David A. Mellis and Tom Igoe.

// Graphing sketch


// This program takes ASCII-encoded strings
// from the serial port at 9600 baud and graphs them. It expects values in the
// range 0 to 1023, followed by a newline, or newline and carriage return

// Created 20 Apr 2005
// Updated 24 Nov 2015
// by Tom Igoe
// This example code is in the public domain.

int WINDOW_WIDTH   =800;
int WINDOW_HEIGHT  =600;

import processing.serial.*;

Serial myPort;        // The serial port

// sensor readings
float inByte0 = 0;
float inByte1 = 0;
float inByte2 = 0;
float inByte3 = 0;

float px,py;  // position
float fx,fy;  // facing
float rx,ry;  // orthogonal to facing direction


void setup () {
  // set the window size:
  size(800, 600);
  WINDOW_WIDTH = 800;
  WINDOW_HEIGHT = 600;
  px = WINDOW_WIDTH/2;
  py = WINDOW_HEIGHT/2;
  fx = 0;
  fy = -1;
  rx = 1;
  ry = 0;
  
  // List all the available serial ports
  // if using Processing 2.1 or later, use Serial.printArray()
  String [] ports = Serial.list();
  println(ports);

  // I know that the first port in the serial list on my mac
  // is always my  Arduino, so I open Serial.list()[0].
  // Open whatever port is the one you're using.
  myPort = new Serial(this, ports[ports.length-1], 57600);

  // don't generate a serialEvent() unless you get a newline character:
  myPort.bufferUntil('\n');

  // set inital background:
  background(0);
}


void drawSensor(float angle,float distance) {
  float dx0 = (fx * cos(radians(angle)) + fy*-sin(radians(angle))) * distance;
  float dy0 = (fx * sin(radians(angle)) + fy* cos(radians(angle))) * distance;
  point(px+dx0, py+dy0);
}


long t=0;
void draw () {
  long tnow = (long)(millis()*0.02);
  px+= (tnow-t);
  t=tnow;
  
  stroke(255,   0,   0);  drawSensor(  0,inByte0);
  stroke(255,   0, 255);  drawSensor( 45,inByte1);
  stroke(  0, 255,   0);  drawSensor(135,inByte2);
  stroke(255,   0, 255);  drawSensor(180,inByte3);
}


void serialEvent (Serial myPort) {
  // get the ASCII string:
  String inString = myPort.readStringUntil('\n');

  if (inString != null) {
    // trim off any whitespace
    String[] tok = splitTokens(inString);
    if (tok.length==4) {
      inByte0 = float(tok[0]);
      inByte1 = float(tok[1]);
      inByte2 = float(tok[2]);
      inByte3 = float(tok[3]);
      
      inByte0 = map(inByte0, 0, 1023, 0, 100);
      inByte1 = map(inByte1, 0, 1023, 0, 100);
      inByte2 = map(inByte2, 0, 1023, 0, 100);
      inByte3 = map(inByte3, 0, 1023, 0, 100);
    } else {
      inByte0=0;
      inByte1=0;
      inByte2=0;
      inByte3=0;
    }
  }
}