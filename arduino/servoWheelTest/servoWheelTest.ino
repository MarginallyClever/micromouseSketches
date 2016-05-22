// read four analog distance sensors and send the values to serial.
// Also drive two wheels.
// Dan Royer (dan@marginallyclever.com)
// 2016-05-16


#define LEFT_STOP   90
#define RIGHT_STOP  90


#include <Servo.h>


Servo left, right;


void setup() {
  // put your setup code here, to run once:
  Serial.begin(57600);
  
  // prepare the wheels
  left.attach(7);
  right.attach(6);

  fullStop();
}


void fullStop() {
  left.write(LEFT_STOP);
  right.write(RIGHT_STOP);
}


void loop() {
  int a = analogRead(2);
  int b = analogRead(3);
  int c = analogRead(4);
  int d = analogRead(5);

  // put your main code here, to run repeatedly:
  Serial.print(a);  Serial.print("\t");
  Serial.print(b);  Serial.print("\t");
  Serial.print(c);  Serial.print("\t");
  Serial.print(d);  Serial.print("\n");

  int bottom = 0;
  int top = 1023/2;
  left.write(map(a,bottom,top,LEFT_STOP-30,LEFT_STOP+30));
  right.write(map(d,bottom,top,RIGHT_STOP-30,RIGHT_STOP+30));
  
  delay(5);
}


