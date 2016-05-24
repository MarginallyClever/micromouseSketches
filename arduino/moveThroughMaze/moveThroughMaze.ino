// read four distance sensors and two wheel encoders to move through the maze.
// Also drive two wheels.
// Also send the clock time and encoders to serial.
// Dan Royer (dan@marginallyclever.com)
// 2016-05-19
//--------------------------------------------------------
// includes
//--------------------------------------------------------

#include <Servo.h>


//--------------------------------------------------------
// constants
//--------------------------------------------------------

// serial speed
#define BAUD           57600

// arduino pins - duemilanove supports PWM on pins 3, 5, 6, 9, 10, and 11.
#define L_SERVO        3
#define R_SERVO        11

// where are encoders attached?
#define SENSOR_L_SDOUT 8
#define SENSOR_L_CLK   9
#define SENSOR_L_CSEL  10

#define SENSOR_R_SDOUT 5
#define SENSOR_R_CLK   6
#define SENSOR_R_CSEL  7

// where are distance sensors attached?
#define DISTANCE_A     A2
#define DISTANCE_B     A3
#define DISTANCE_C     A4
#define DISTANCE_D     A5

// helpful encoder numbers
#define ANGLE_BITS      (12)
#define STATUS_BITS     (5)
#define PARITY_BITS     (1)
#define ANGLE_MASK      (0b111111111111000000)
#define STATUS_MASK     (0b000000000000111110)
#define PARITY_MASK     (0b000000000000000001)
#define TOTAL_BITS      (ANGLE_BITS+STATUS_BITS+PARITY_BITS)
#define ANGLE_SCALE     (360.0 / (float)((1 << ANGLE_BITS)))


// Minimum time between distance sensor reads should be at least (16.5 +/- 3.7)ms.
#define STEPS_PER_SECOND     30
#define DELAY_BETWEEN_STEPS  (1000/STEPS_PER_SECOND)

// servo movement control
#define LEFT_STOP      92
#define RIGHT_STOP     92


// To move the robot I need to know the size of the wheels and the distance-per-degree.
#define WHEEL_DIAMETER        (3.78)  // cm
#define WHEEL_CIRCUMFERENCE   (WHEEL_DIAMETER * PI)  // c = 2 * pi * r
#define DISTANCE_PER_DEGREE   (WHEEL_CIRCUMFERENCE/360.0)  // cm

// To make 90 degree turns I need to know the distance between the wheels.
// trust real world measurements > computer model numbers.
#define WHEEL_BASE               (8.5)   // cm


// How far do I have to move to reach the next cell of the maze?
#define DISTANCE_BETWEEN_MAZE_CELLS    (18.0) // cm
#define DEGREES_BETWEEN_MAZE_CELLS     (DISTANCE_BETWEEN_MAZE_CELLS/DISTANCE_PER_DEGREE)


// If one turns forward and one turns reverse at the same speed then the wheels 
// will "draw" a circle.  I know the distance between wheels, so I know the 
// circle's circumference.
#define WHEEL_BASE_CIRCUMFERENCE (WHEEL_BASE * PI)  // c = 2 * pi * r
// 1/4 of the circumference is one 90 degree turn.
#define DEGREES_FOR_ONE_TURN    ((WHEEL_BASE_CIRCUMFERENCE*0.25) / DISTANCE_PER_DEGREE)


//--------------------------------------------------------
// globals
//--------------------------------------------------------

Servo left, right;

// distance readings
int distanceA, distanceB, distanceC, distanceD;

// encoder readings
float encoderL, encoderR;

long t;


//--------------------------------------------------------
// methods
//--------------------------------------------------------

void setup() {
  // put your setup code here, to run once:
  Serial.begin(BAUD);
  Serial.println("angle=");
  
  // prepare the wheels
  left.attach(L_SERVO);
  right.attach(R_SERVO);

  pinMode(SENSOR_L_SDOUT,  INPUT );
  pinMode(SENSOR_L_CLK  ,  OUTPUT);
  pinMode(SENSOR_L_CSEL ,  OUTPUT);

  pinMode(SENSOR_R_SDOUT,  INPUT );
  pinMode(SENSOR_R_CLK  ,  OUTPUT);
  pinMode(SENSOR_R_CSEL ,  OUTPUT);

  fullStop();

  // wait for the encoders to wake up
  do {
    delayBetweenSteps();
    readEncoders();
  } while (encoderL == 0 || encoderR == 0);

  Serial.println(F("Hello, World!  I am a micromouse."));
  t = millis();
}


// vel = [-90...90].  90 is full speed forward
void driveLeftWheel(float vel) {
  left.write(LEFT_STOP + vel);
  readEncoders();
}

// vel = [-90...90].  90 is full speed forward
void driveRightWheel(float vel) {
  right.write(RIGHT_STOP - vel);
  readEncoders();
}


void fullStop() {
  Serial.print(F("Stopping.  "));
  driveLeftWheel(0);
  driveRightWheel(0);
}


// Minimum time between distance sensor reads should be at least (16.5 +/- 3.7)ms.
void delayBetweenSteps() {
  while (millis() - t < DELAY_BETWEEN_STEPS);
  t = millis();
}


void turnRight90() {
  Serial.print(F("Turning right.\n"));
  Serial.println(DEGREES_FOR_ONE_TURN);

  readEncoders();
  float destinationL = encoderL + DEGREES_FOR_ONE_TURN;
  float destinationR = encoderR - DEGREES_FOR_ONE_TURN;
  float lastL = encoderL;
  float lastR = encoderR;
  float turnedL = 0;
  float turnedR = 0;

  boolean stillTurning = true;
  int driveTo, driveSum;
  float dL, dR;

  do {
    delayBetweenSteps();
    readEncoders();

    // Find how far the wheels moved.  Watch for encoders
    // jumping from 0 to 359 and vice versa.
    dL = encoderL - lastL;
    dR = encoderR - lastR;
    if (abs(dL) > 180) {
      if ( lastL <  90 && encoderL > 270 ) dL = encoderL - (lastL + 360);
      if ( lastL > 270 && encoderL <  90 ) dL = (encoderL + 360) - lastL;
    }
    if (abs(dR) > 180) {
      if ( lastR <  90 && encoderR > 270 ) dR = encoderR - (lastR + 360);
      if ( lastR > 270 && encoderR <  90 ) dR = (encoderR + 360) - lastR;
    }
    lastL = encoderL;
    lastR = encoderR;
    turnedL += dL;
    turnedR += dR;

    Serial.print(encoderL);
    Serial.print('\t');
    Serial.print(encoderR);
    Serial.print('\t');
    Serial.print(dL);
    Serial.print('\t');
    Serial.print(dR);
    Serial.print('\t');
    Serial.print(turnedL);
    Serial.print('\t');
    Serial.print(turnedR);
    Serial.print('\t');

    
    driveTo = ( turnedL < DEGREES_FOR_ONE_TURN ) ? 90 : 0;
    driveLeftWheel( driveTo );
    driveSum = abs( driveTo );
    Serial.print(driveTo);
    Serial.print('\t');

    driveTo = ( turnedR > -DEGREES_FOR_ONE_TURN ) ? -90 : 0;
    driveRightWheel( driveTo );
    driveSum += abs( driveTo );
    Serial.print(driveTo);
    Serial.print('\n');

    stillTurning = (driveSum != 0);
  } while (stillTurning);
}

void loop() {
  /*
    delayBetweenSteps();

    readDistanceSensors();
    if( readEncoders() ) {
      thinkAndAct();
      reportToPC();
    }*/
  //turnRight90();

  int WAIT = 2000;
  //  goForward();    t=millis();  while(millis()-t<WAIT);
  //  turnLeft90();   t=millis();  while(millis()-t<WAIT);
  turnRight90();  t = millis();  while (millis() - t < WAIT);
  fullStop();     t = millis();  while (millis() - t < WAIT);
}


void thinkAndAct() {
  // Move wheels
  int driveTo;
  driveTo = ( encoderL - 180 ) / 2;  left .write( 90 + driveTo );
  driveTo = ( encoderR - 180 ) / 2;  right.write( 90 + driveTo );
}


void reportToPC() {
  Serial.print(t        );  Serial.print("\t");
  Serial.print(distanceA);  Serial.print("\t");
  Serial.print(distanceB);  Serial.print("\t");
  Serial.print(distanceC);  Serial.print("\t");
  Serial.print(distanceD);  Serial.print("\t");
  Serial.print(encoderL );  Serial.print("\t");
  Serial.print(encoderR );  Serial.print("\n");
}


boolean readEncoders() {
  boolean ok = true;
  if (!readEncoder(SENSOR_L_SDOUT, SENSOR_L_CSEL, SENSOR_L_CLK, encoderL)) {
    //Serial.println("fail left");
    ok = false;
  }
  if (!readEncoder(SENSOR_R_SDOUT, SENSOR_R_CSEL, SENSOR_R_CLK, encoderR)) {
    //Serial.println("fail right");
    ok = false;
  }
  return ok;
}


void readDistanceSensors() {
  distanceA = analogRead(DISTANCE_A);
  distanceB = analogRead(DISTANCE_B);
  distanceC = analogRead(DISTANCE_C);
  distanceD = analogRead(DISTANCE_D);
}

/**
   read an AS5045 sensor
   sdout - arduino pin that to the sensor SD_OUT pin
   csel - arduino pin to the sensor CSEL pin
   clk - arduino pin to the sensor CLK_IN pin
*/
boolean readEncoder(int sdout, int csel, int clk, float &result) {
  long data = 0;

  if (!readEncoderRaw(sdout, csel, clk, data)) {
    return false;
  }

  int statusI = (data & STATUS_MASK);
  /*
    // display the five status bits
    for(int i=5;i>=1;--i) {
      char x = (statusI & (1<<i)) !=0?'1':'0';
      Serial.print(x);
    }
    Serial.println();
  */
  //Serial.println(statusI,BIN);

  if ( (statusI & 0b100000) != 0b100000 ) {
    // 0B100000 startup complete
    // not initialized yet
    return false;
  }

  if ( (statusI & 0b011110) != 0 ) {
    // error
    // 0B010000 cordic overflow; data invalid
    // 0B001000 linearity alarm
    // 0B000100 moved towards chip
    // 0B000010 moved away from chip

    if ((statusI & 0b110) != 0) {
      return false;
    }
  }

  // 0B000001 is the even/odd parity bit

  int angleI = (data & ANGLE_MASK) >> (STATUS_BITS + PARITY_BITS);
/*
  //Serial.print(angleI,BIN);
  //Serial.print(' ');
  // display the angle bits
  for(int i=17;i>=0;--i) {
    char x = (data & (1<<i)) !=0?'1':'0';
    Serial.print(x);
  }
  Serial.print('\t');
*/
  result = (float)angleI * ANGLE_SCALE;
  //Serial.print(result);
  //Serial.print("\t");

  return true;
}


boolean readEncoderRaw(int sdout, int csel, int clk, long &data) {
  data = 0;
  int c;

  digitalWrite(csel, HIGH);
  digitalWrite(clk, HIGH);
  digitalWrite(csel, LOW);
  digitalWrite(clk, LOW);

  char parity = 0;
  for (int n = 0; n < TOTAL_BITS; ++n) { // clock signal, 16 transitions, output to clock pin
    digitalWrite(clk, HIGH);
    c = (digitalRead(sdout));// !=0) ? 1 : 0;
    data = ( ( data << 1 ) | c );
    if (n < TOTAL_BITS - 1)
      parity += c;
    digitalWrite(clk, LOW);
  }

  //Serial.print(data,BIN);
  //Serial.print('\t');

  return ((parity%2) == c);
}
