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

// set to 1 to get more details
#define VERBOSE 0

// serial speed
#define BAUD           57600

// arduino pins - duemilanove supports PWM on pins 3, 5, 6, 9, 10, and 11.
#define L_SERVO        2
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


// high level maze solving
#define NORTH 0
#define EAST  1
#define SOUTH 2
#define WEST  3

#define SEARCHING   0
#define GOHOME      1
#define GOCENTER    2

// maze dimension, in cells.
#define ROWS        16
#define COLUMNS     16
#define TOTAL_CELLS (ROWS*COLUMNS)

//--------------------------------------------------------
// structures
//--------------------------------------------------------

struct MazeCell {
  int x, y;
  boolean visited;
  boolean onStack;
};

struct MazeWall {
  int cellA, cellB;
  boolean removed;
};

struct Turtle {
  int cellX, cellY;
  int dir;
};



//--------------------------------------------------------
// globals
//--------------------------------------------------------

Servo left, right;

// distance readings
int distanceA, distanceB, distanceC, distanceD;

// encoder readings
float encoderL, encoderR;

long t;

// turtle logic
Turtle turtle;
Turtle *history;
int historyCount;
int turtleState;
int walkCount;

// maze memory
MazeCell *cells;
MazeWall *walls;


//--------------------------------------------------------
// methods
//--------------------------------------------------------

void createMaze() {
  // build the cells
  cells = new MazeCell[TOTAL_CELLS];

  int x, y, i = 0;
  for (y = 0; y < ROWS; ++y) {
    for (x = 0; x < COLUMNS; ++x) {
      cells[i].visited = false;
      cells[i].onStack = false;
      cells[i].x = x;
      cells[i].y = y;
      ++i;
    }
  }

  // build the graph
  walls = new MazeWall[((ROWS - 1) * COLUMNS) + ((COLUMNS - 1) * ROWS)];
  i = 0;
  for (y = 0; y < ROWS; ++y) {
    for (x = 0; x < COLUMNS; ++x) {
      if (x < COLUMNS - 1) {
        // vertical wall between horizontal cells
        walls[i].removed = false;
        walls[i].cellA = y * COLUMNS + x;
        walls[i].cellB = y * COLUMNS + x + 1;
        ++i;
      }
      if (y < ROWS - 1) {
        // horizontal wall between vertical cells
        walls[i].removed = false;
        walls[i].cellA = y * COLUMNS + x;
        walls[i].cellB = y * COLUMNS + x + COLUMNS;
        ++i;
      }
    }
  }
}


void setup() {
  // setup communications
  Serial.begin(BAUD);

  setupWheels();
  setupEncoders();

  Serial.println(F("Hello, World!  I am a micromouse."));
  calibrateSensors();
  waitForStartSignal();
  setupTurtle();
}

void setupWheels() {
  left.attach(L_SERVO);
  right.attach(R_SERVO);
  fullStop();
}


void setupEncoders() {
  pinMode(SENSOR_L_SDOUT,  INPUT );
  pinMode(SENSOR_L_CLK  ,  OUTPUT);
  pinMode(SENSOR_L_CSEL ,  OUTPUT);

  pinMode(SENSOR_R_SDOUT,  INPUT );
  pinMode(SENSOR_R_CLK  ,  OUTPUT);
  pinMode(SENSOR_R_CSEL ,  OUTPUT);

  // wait for the encoders to wake up
  do {
    delayBetweenSteps();
    readEncoders();
  } while (encoderL == 0 || encoderR == 0);
}

void setupTurtle() {
  history = new Turtle[TOTAL_CELLS];
  turtleState = SEARCHING;
  // start in bottom left corner
  turtle.cellX=0;
  turtle.cellY=0;
  turtle.dir=NORTH;
  historyCount=0;
  addToHistory();
}


void addToHistory() {
  history[historyCount].cellX = turtle.cellX;
  history[historyCount].cellY = turtle.cellY;
  history[historyCount].dir = turtle.dir;
  historyCount++;
}


// convert grid (x,y) to cell index number.
int getCellNumberAt(int x,int y) {
  return y * COLUMNS + x;
}


/**
 * Remove dead ends from the calulcated shortest route.
 * Do this by checking if we've been here before.
 * If we have, remove everything in history between the last visit and now.
 */
void pruneHistory(int findCell) {
  int i;
  for(i = historyCount-2; i >= 0; --i) {
    int cell = getCellNumberAt(history[i].cellX, history[i].cellY);
    if(cell == findCell) {
      historyCount = i+1;
      return;
    }
  }
}


void waitForStartSignal() {
  // TODO finish me
  readDistanceSensors();
  float a=distanceA;
  float b=distanceB;
  float c=distanceC;
  float d=distanceD;

  do {
    delayBetweenSteps();
    readDistanceSensors();
    Serial.print(distanceA);  Serial.print("\t");
    Serial.print(distanceB);  Serial.print("\t");
    Serial.print(distanceC);  Serial.print("\t");
    Serial.print(distanceD);  Serial.print("\n");
  } while(1);
}


void calibrateSensors() {
  waitForStartSignal();
  
  int i;
  for(i=0;i<4;++i) {
    delayBetweenSteps();
    readDistanceSensors();
    turnRight();
  }
}


// vel = [-90...90].  90 is full speed forward
void driveLeftWheel(float vel) {
  left.write(LEFT_STOP - vel);
  readEncoders();
}

// vel = [-90...90].  90 is full speed forward
void driveRightWheel(float vel) {
  right.write(RIGHT_STOP + vel);
  readEncoders();
}


void fullStop() {
  Serial.print(F("Stopping.  "));
  driveLeftWheel(0);
  driveRightWheel(0);
}


// Minimum time between distance sensor reads should be at least (16.5 +/- 3.7)ms.
void delayBetweenSteps() {
  t = millis();
  while (millis() - t < DELAY_BETWEEN_STEPS);
}


void turnRight() {
  Serial.print(F("Turning right.  "));

  while (!readEncoders());
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
    while (!readEncoders());

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
#if VERBOSE == 1
    Serial.print('\n');
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
#endif

    // drive the left wheel
    driveTo = ( turnedL <  DEGREES_FOR_ONE_TURN ) ? max( DEGREES_FOR_ONE_TURN - turnedL, 4 ) : 0;
    driveTo = min( driveTo, 90 );
    driveLeftWheel( driveTo );
    driveSum = abs( driveTo );
#if VERBOSE == 1
    Serial.print(driveTo);
    Serial.print('\t');
#endif
    // drive the right wheel
    driveTo = ( turnedR < DEGREES_FOR_ONE_TURN ) ? max( DEGREES_FOR_ONE_TURN - turnedR, 4 ) : 0;
    driveTo = min( driveTo, 90 );
    driveRightWheel( -driveTo );
    driveSum += abs( driveTo );
#if VERBOSE == 1
    Serial.print(driveTo);
    Serial.print('\t');
#endif
    stillTurning = (driveSum != 0);
  } while (stillTurning);
}


void turnLeft() {
  Serial.print(F("Turning left.  "));

  while (!readEncoders());
  float destinationL = encoderL - DEGREES_FOR_ONE_TURN;
  float destinationR = encoderR + DEGREES_FOR_ONE_TURN;
  float lastL = encoderL;
  float lastR = encoderR;
  float turnedL = 0;
  float turnedR = 0;

  boolean stillTurning = true;
  int driveTo, driveSum;
  float dL, dR;

  do {
    delayBetweenSteps();
    while (!readEncoders());

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
    turnedL -= dL;
    turnedR -= dR;
#if VERBOSE == 1
    Serial.print('\n');
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
#endif

    // drive the left wheel
    driveTo = ( turnedL <  DEGREES_FOR_ONE_TURN ) ? max( DEGREES_FOR_ONE_TURN - turnedL, 4 ) : 0;
    driveTo = min( driveTo, 90 );
    driveLeftWheel( -driveTo );
    driveSum = abs( driveTo );
#if VERBOSE == 1
    Serial.print(driveTo);
    Serial.print('\t');
#endif
    // drive the right wheel
    driveTo = ( turnedR < DEGREES_FOR_ONE_TURN ) ? max( DEGREES_FOR_ONE_TURN - turnedR, 4 ) : 0;
    driveTo = min( driveTo, 90 );
    driveRightWheel( driveTo );
    driveSum += abs( driveTo );
#if VERBOSE == 1
    Serial.print(driveTo);
    Serial.print('\t');
#endif
    stillTurning = (driveSum != 0);
  } while (stillTurning);
}


void loop() {
  stepForward();
  turnLeft();
  turnLeft();
  stepForward();
  turnRight();
  turnRight();
  fullStop();

  int WAIT = 2000;
  t = millis();
  while (millis() - t < WAIT);
}


void stepForward() {
  // Check that the square we want to move to is inside the maze.
  int x = turtle.cellX;
  int y = turtle.cellY;
  
  switch(turtle.dir) {
  case NORTH:  Serial.print("north");  ++x;  break;
  case  EAST:  Serial.print("east" );  ++y;  break;
  case SOUTH:  Serial.print("south");  --x;  break;
  case  WEST:  Serial.print("west" );  --y;  break;
  }

  if(x >= ROWS   ) x = ROWS-1;
  if(x <  0      ) x = 0;
  if(y >= COLUMNS) y = COLUMNS-1;
  if(y <  0      ) y = 0;

  if(turtle.cellX == x && turtle.cellY == y ) {
    return;
  }
  
  turtle.cellX = x;
  turtle.cellY = y;
  
  Serial.print("Advancing to (");
  Serial.print(turtle.cellX);
  Serial.print(',');
  Serial.print(turtle.cellY);
  Serial.print(").  ");


  while (!readEncoders());
  float destinationL = encoderL + DEGREES_BETWEEN_MAZE_CELLS;
  float destinationR = encoderR + DEGREES_BETWEEN_MAZE_CELLS;
  float lastL = encoderL;
  float lastR = encoderR;
  float turnedL = 0;
  float turnedR = 0;

  boolean stillTurning = true;
  int driveTo, driveSum;
  float dL, dR;

  do {
    delayBetweenSteps();
    while (!readEncoders());

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
    turnedR -= dR;
#if VERBOSE == 1
    Serial.print('\n');
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
#endif

    // drive the left wheel
    driveTo = ( turnedL <  DEGREES_BETWEEN_MAZE_CELLS ) ? max( DEGREES_BETWEEN_MAZE_CELLS - turnedL, 4 ) : 0;
    driveTo = min( driveTo, 90 );
    driveLeftWheel( driveTo );
    driveSum = abs( driveTo );
#if VERBOSE == 1
    Serial.print(driveTo);
    Serial.print('\t');
#endif
    // drive the right wheel
    driveTo = ( turnedR < DEGREES_BETWEEN_MAZE_CELLS ) ? max( DEGREES_BETWEEN_MAZE_CELLS - turnedR, 4 ) : 0;
    driveTo = min( driveTo, 90 );
    driveRightWheel( driveTo );
    driveSum += abs( driveTo );
#if VERBOSE == 1
    Serial.print(driveTo);
    Serial.print('\t');
#endif
    stillTurning = (driveSum != 0);
  } while (stillTurning);
}


void thinkAndAct() {
  switch(turtleState) {
  case SEARCHING: searchMaze();  break;
  case    GOHOME: goHome();      break;
  case  GOCENTER: goToCenter();  break; 
  }
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


// https://www.pololu.com/file/0J845/GP2Y0A41SK0F.pdf.pdf, page 4
// volts  dist    analog read
// 2.45v =  1cm = 501
// 2.10v =  2cm = 430
// 1.08v =  5cm = 221
// 0.60v = 10cm = 122
// 0.40v = 15cm = 81
// 0.30v = 20cm = 61
// https://www.arduino.cc/en/Reference/Map shows that map()
// is only long to long, no floats allowed.
int analogToDistance(int rawSensorReading,float &result) {
  if( rawSensorReadings > 500 ) {
    // out of range
    return -1;
  } else if( rawSensorReading > 430 ) {
    result = (float)map(rawSensorReading,430,501, 2*100, 1*100)/100.0;
  } else if( rawSensorReading > 221 ) {
    result = (float)map(rawSensorReading,221,430, 5*100, 2*100)/100.0;
  } else if( rawSensorReading > 122 ) {
    result = (float)map(rawSensorReading,122,221,10*100, 5*100)/100.0;
  } else if( rawSensorReading > 81 ) {
    result = (float)map(rawSensorReading, 81,122,15*100,10*100)/100.0;
  } else if( rawSensorReading > 61 ) {
    result = (float)map(rawSensorReading, 61, 81,20*100,15*100)/100.0;
  } else {
    // out of range
    return 1;
  }
  return 0;
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

  return ((parity % 2) == c);
}


/**
 * Find the index of the wall between two cells
 * returns -1 if no wall is found (asking the impossible)
 */
int findWallBetween(int currentCell, int nextCell) {
  int i;
  for (i = 0; i < TOTAL_CELLS; ++i) {
    if (walls[i].cellA == currentCell || walls[i].cellA == nextCell) {
      if (walls[i].cellB == currentCell || walls[i].cellB == nextCell)
        return i;
    }
  }
  return -1;
}



// returns true if there is a wall between cells A and B.
boolean thereIsAWallBetween(int a,int b) {
  int wi = findWallBetween(a,b);
  return (wi==-1 || !walls[wi].removed);
}


boolean thereIsAWallToTheNorth(int c) {  return thereIsAWallBetween(c, c+1      );  }
boolean thereIsAWallToTheSouth(int c) {  return thereIsAWallBetween(c, c-1      );  }
boolean thereIsAWallToTheEast (int c) {  return thereIsAWallBetween(c, c+COLUMNS);  }
boolean thereIsAWallToTheWest (int c) {  return thereIsAWallBetween(c, c-COLUMNS);  }


boolean thereIsAWallToTheRight() {
  int c = getCurrentCellNumber();
  switch(turtle.dir) {
    case NORTH: return thereIsAWallToTheEast (c);
    case  EAST: return thereIsAWallToTheSouth(c);
    case SOUTH: return thereIsAWallToTheWest (c);
    default   : return thereIsAWallToTheNorth(c);
  }
}


boolean thereIsAWallAhead() {
  int c = getCurrentCellNumber();
  switch(turtle.dir) {
    case NORTH: return thereIsAWallToTheNorth(c);
    case  EAST: return thereIsAWallToTheEast (c);
    case SOUTH: return thereIsAWallToTheSouth(c);
    default   : return thereIsAWallToTheWest (c);
  }
}


// One step in the maze search.
void searchMaze() {
  if(!thereIsAWallToTheRight()) {
    Serial.print("No wall on the right.  ");
    turnRight();
  }
    
  if(!thereIsAWallAhead()) {
    Serial.print("No wall ahead.  ");
    stepForward();
    addToHistory();
  } else {
    Serial.print("Wall ahead.  ");
    turnLeft();
  }
  Serial.println();

  // remove dead ends
  pruneHistory(getCurrentCellNumber());
  
  if( iAmInTheCenter() ) {
    Serial.println("** CENTER FOUND.  GOING HOME **");
    turtleState = GOHOME;
    walkCount = historyCount;
  }
}


// One step towards home along the known shortest route.
void goHome() {
  walkCount--;
  turnToFace((history[walkCount].dir+2)%4);  // face the opposite of the history
  stepForward();
  Serial.println();
  
  if(walkCount==0) {
    Serial.println("** HOME FOUND.  GOING TO CENTER **");
    turtleState = GOCENTER;
    walkCount=1;
  }
}


void turnToFace(int dir) {
  if(dir == turtle.dir) {
    // facing that way already
    return;
  }

  if(dir == turtle.dir+2 || dir == turtle.dir-2 ) {
    // 180
    turnRight();
    turnRight();
    return;
  }
  if(dir == (turtle.dir+4-1)%4) turnLeft();
  if(dir == (turtle.dir  +1)%4) turnRight();
}


// One step towards center along the known shortest route.
void goToCenter() {
  turnToFace(history[walkCount].dir);  // face the opposite of the history
  stepForward();
  Serial.println();

  walkCount++;
  
  if(walkCount==historyCount) {
    Serial.println("** CENTER FOUND.  GOING HOME **");
    turtleState = GOHOME;
  }
}


boolean iAmInTheCenter() {
  return ( turtle.cellX == (ROWS   /2)-1 || turtle.cellX == (ROWS   /2) ) &&
         ( turtle.cellY == (COLUMNS/2)-1 || turtle.cellY == (COLUMNS/2) );
}


int getCurrentCellNumber() {
  return getCellNumberAt( turtle.cellX, turtle.cellY );
}
