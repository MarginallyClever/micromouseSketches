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

// for calculating distances
long timeNow;
long timeLast;
boolean timeReceived=false;
int left, right;  // wheel speeds

void setup () {
  // set the window size:
  size(800, 600);
  WINDOW_WIDTH = 800;
  WINDOW_HEIGHT = 600;
  px = WINDOW_WIDTH/2.0f;
  py = WINDOW_HEIGHT/2.0f;
  
  fx = 1;
  fy = 0;
  
  frameRate(30);
  
  // List all the available serial ports
  // if using Processing 2.1 or later, use Serial.printArray()
  String [] ports = Serial.list();
  for(int i=0;i<ports.length;++i) {
    println("Port "+i+": "+ports[i]);
  }

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


void draw () {
  // draw the sensor values
  stroke(255,   0,   0);  drawSensor( -90,inByte0);
  stroke(  0, 255,   0);  drawSensor( -30,inByte1);
  stroke(  0,   0, 255);  drawSensor(  30,inByte2);
  stroke(127, 127, 127);  drawSensor(  90,inByte3);
  // draw the robot's position
  stroke(255, 255,   0);  point(px,py);  
}


int skipSteps=3;

void serialEvent (Serial myPort) {
  // get the ASCII string:
  String inString = myPort.readStringUntil('\n');

  if (inString != null) {
    // trim off any whitespace
    String[] tok = splitTokens(inString);
    if (tok.length==7) {
      if(skipSteps>0) {
        skipSteps--;
        return;
      }
      timeNow = int(tok[0]);
      inByte0 = float(tok[1]);
      inByte1 = float(tok[2]);
      inByte2 = float(tok[3]);
      inByte3 = float(tok[4]);
      left = int(tok[5]);
      right = int(tok[6]);
      
      inByte0 = map(inByte0, 0, 1023, 0, 100);
      inByte1 = map(inByte1, 0, 1023, 0, 100);
      inByte2 = map(inByte2, 0, 1023, 0, 100);
      inByte3 = map(inByte3, 0, 1023, 0, 100);
    } else {
      println("***");
      return;
    }
  }

  //print(timeReceived?"Y":"N");  print('\t');

  if(timeNow==0) return;

  if(inByte0<20) inByte0=0;
  if(inByte1<20) inByte1=0;
  if(inByte2<20) inByte2=0;
  if(inByte3<20) inByte3=0;
  
  float dt;
  if(!timeReceived) {
    timeLast = timeNow;
    timeReceived = true;
    dt = 0;
  } else {
    dt = (float)(timeNow - timeLast) * 0.001f;
  }
  //print(timeLast);  print('\t');
  //print(timeNow);  print('\t');
  timeLast = timeNow;
  
  // turn left/right
  float angle = (float)(left-right) * 10.0f * dt;
  float tx = (fx * cos(radians(angle)) + fy*-sin(radians(angle)));
  float ty = (fx * sin(radians(angle)) + fy* cos(radians(angle)));
  float len = sqrt( tx*tx + ty*ty );
  fx = tx / len;
  fy = ty / len;
  
  // apply speed
  float speed = (float)(left+right) * ( 0.2f ) * dt;
  px += fx * speed;
  py += fy * speed;
  
  if( px > WINDOW_WIDTH ) px = WINDOW_WIDTH;
  if( px < 0            ) px = 0;
  if( py > WINDOW_HEIGHT) py = WINDOW_HEIGHT;
  if( py < 0            ) py = 0;
/*
  print(dt);  print('\t');
  print(px);  print('\t');
  print(py);  print('\t');
  print(angle);  print('\t');
  print(speed);  print('\n');
*/
}