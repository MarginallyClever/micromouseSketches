// adjust two continuous servos to find their 
// stop position (where they don't move)
// Dan Royer (dan@marginallyclever.com)
// 2016-05-16

// change this number +/-1 at a time until you find center.
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


void loop() {}
