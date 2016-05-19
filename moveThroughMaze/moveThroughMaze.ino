// read four analog distance sensors and send the values to serial.
// Also drive two wheels.
// Also read two digital encoders.
// Also send the clock time and encoders to serial.
// Dan Royer (dan@marginallyclever.com)
// 2016-05-18
//--------------------------------------------------------
// includes
//--------------------------------------------------------

#include <Servo.h>


//--------------------------------------------------------
// constants
//--------------------------------------------------------

// serial speed
#define BAUD           57600

// Minimum time between distance sensor reads should be at least (16.5 +/- 3.7)ms.
#define STEPS_PER_SECOND     30
#define DELAY_BETWEEN_STEPS  (1000/STEPS_PER_SECOND)

// servo movement control
#define LEFT_STOP      90
#define RIGHT_STOP     90

// arduino pins
#define L_SERVO        4
#define R_SERVO        2

#define SENSOR_L_SDOUT 5
#define SENSOR_L_CLK   6
#define SENSOR_L_CSEL  7

#define SENSOR_R_SDOUT 8
#define SENSOR_R_CLK   9
#define SENSOR_R_CSEL  10

// helpful encoder numbers
// ANGLE_BITS + STATUS_BITS must = 16
#define ANGLE_BITS      (10)
#define STATUS_BITS     (6)
#define ANGLE_MASK      (0b1111111111000000)
#define STATUS_MASK     (0b0000000000111111)

// physical dimensions
#define WHEEL_DIAMETER        (3.78)  // cm
#define WHEEL_CIRCUMFERENCE   (PI * WHEEL_DIAMETER)  // c = 2 * pi * r


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

  t=millis();
}


void fullStop() {
  left.write(LEFT_STOP);
  right.write(RIGHT_STOP);
}


void loop() {
  // Delay
  while(millis()-t<DELAY_BETWEEN_STEPS);
  t=millis();

  readDistanceSensors();
  if( readEncoders() ) {
    thinkAndAct();
    reportToPC();
  }
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
  ok &= readEncoder(SENSOR_L_SDOUT,SENSOR_L_CSEL,SENSOR_L_CLK,encoderL);
  ok &= readEncoder(SENSOR_R_SDOUT,SENSOR_R_CSEL,SENSOR_R_CLK,encoderR);
  return ok;
}


void readDistanceSensors() {
  distanceA = analogRead(2);
  distanceB = analogRead(3);
  distanceC = analogRead(4);
  distanceD = analogRead(5);
}

/**
 * read an AS5045 sensor
 * sdout - arduino pin that to the sensor SD_OUT pin
 * csel - arduino pin to the sensor CSEL pin
 * clk - arduino pin to the sensor CLK_IN pin
 */
boolean readEncoder(int sdout,int csel,int clk, float &result) {
  int data = readEncoderRaw(sdout,csel,clk);
  
  int statusI = (data & STATUS_MASK);
  
  //Serial.print(angleI,BIN);
  //Serial.print(' ');
  //Serial.println(statusI,BIN);
  
  if( (statusI & 0b100000) != 0b100000 ) {
    return false;
  }
  
  if( (statusI & 0b011110) != 0 ) {
    // error
    // 0B100000 startup complete
    // 0B010000 cordic overflow; data invalid
    // 0B001000 linearity alarm
    // 0B000100 moved towards chip
    // 0B000010 moved away from chip
/*
    for(int i=4;i>=0;--i) {
      char x = (statusI & (1<<i)) !=0?'1':'0';
      Serial.print(x);
    }
    Serial.println();
    */
    if((statusI & 0b111) !=0) {
      return false;
    }
  }
  
  int angleI = (data & ANGLE_MASK) >> STATUS_BITS;
  result = angleI * 360.0 / (float)(1 << ANGLE_BITS);
  
  return true;
}


int readEncoderRaw(int sdout,int csel,int clk) {
  int data=0;
  int c;
  
  digitalWrite(csel,HIGH);
  digitalWrite(clk,HIGH);
  digitalWrite(csel,LOW);
  digitalWrite(clk,LOW);
  
  for(int n=0; n<16; ++n) {  // clock signal, 16 transitions, output to clock pin
    digitalWrite(clk,HIGH);
    c = (digitalRead(sdout));// !=0) ? 1 : 0;
    data = ( ( data << 1 ) | c );
    digitalWrite(clk,LOW);
  }
  
  //Serial.print(data,BIN);
  //Serial.print('\t');
  
  return data;
}
