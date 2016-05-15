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

import processing.serial.*;

Serial myPort;        // The serial port
int xPos = 1;         // horizontal position of the graph
float inByte0 = 0;
float inByte1 = 0;
float inByte2 = 0;
float inByte3 = 0;

float inByte0old = 0;
float inByte1old = 0;
float inByte2old = 0;
float inByte3old = 0;

void setup () {
  // set the window size:
  size(800, 600);

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

void draw () {
  // draw the line:
  stroke(127, 34, 255);
  stroke(255,   0,   0);  line(xPos-1, height-inByte0old, xPos, height - inByte0);
  stroke(  0, 255,   0);  line(xPos-1, height-inByte1old, xPos, height - inByte1);
  stroke(  0,   0, 255);  line(xPos-1, height-inByte2old, xPos, height - inByte2);
  stroke(255, 255, 255);  line(xPos-1, height-inByte3old, xPos, height - inByte3);

  // at the edge of the screen, go back to the beginning:
  if (xPos >= width) {
    xPos = 0;
    background(0);
  } else {
    // increment the horizontal position:
    xPos++;
  }
  inByte0old = inByte0;
  inByte1old = inByte1;
  inByte2old = inByte2;
  inByte3old = inByte3;
}


void serialEvent (Serial myPort) {
  // get the ASCII string:
  String inString = myPort.readStringUntil('\n');

  if (inString != null) {
    // trim off any whitespace:
    String[] tok = splitTokens(inString);
    if (tok.length==4) {
      inByte0 = float(tok[0]);
      inByte1 = float(tok[1]);
      inByte2 = float(tok[2]);
      inByte3 = float(tok[3]);
    } else {
      inByte0=0;
      inByte1=0;
      inByte2=0;
      inByte3=0;
    }
    inByte0 = map(inByte0, 0, 1023, 0, height);
    inByte1 = map(inByte1, 0, 1023, 0, height);
    inByte2 = map(inByte2, 0, 1023, 0, height);
    inByte3 = map(inByte3, 0, 1023, 0, height);
  }
}

