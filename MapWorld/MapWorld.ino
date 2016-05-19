// read four analog distance sensors and send the values to serial.
// Also drive two wheels.
// Also send the clock time and servo speeds.
// Dan Royer (dan@marginallyclever.com)
// 2016-05-16


#define LEFT_STOP   90
#define RIGHT_STOP  90


#include <Servo.h>


Servo left, right;


long t;


void setup() {
  // put your setup code here, to run once:
  Serial.begin(57600);
  
  // prepare the wheels
  left.attach(2);
  right.attach(4);

  fullStop();

  t=millis();
}


void fullStop() {
  left.write(LEFT_STOP);
  right.write(RIGHT_STOP);
}


void loop() {
  // delay
  while(millis()-t<30);
  t=millis();

  // read sensors.  Minimum time between reads should be (16.5 +/- 3.7)ms.
  int a = analogRead(2);
  int b = analogRead(3);
  int c = analogRead(4);
  int d = analogRead(5);

  // move wheels
  int bottom = 0;
  int top = 1023/2;
  int e = map(a,bottom,top, LEFT_STOP-30, LEFT_STOP+30);
  int f = map(d,bottom,top,RIGHT_STOP-30,RIGHT_STOP+30);
  left.write(e);
  right.write(f);

  // report
  Serial.print(t);  Serial.print("\t");
  Serial.print(a);  Serial.print("\t");
  Serial.print(b);  Serial.print("\t");
  Serial.print(c);  Serial.print("\t");
  Serial.print(d);  Serial.print("\t");
  Serial.print(e);  Serial.print("\t");
  Serial.print(f);  Serial.print("\n");
}


