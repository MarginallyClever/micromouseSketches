// Find the center of a maze, then roam back and forth along the shortest route forever.
// Dan Royer (dan@marginallyclever.com) 2016-05-21
// Turtle logic


static final int NORTH=0;
static final int EAST =1;
static final int SOUTH=2;
static final int WEST =3;

static final int SEARCHING = 0;
static final int GOHOME    = 1;
static final int GOCENTER  = 2;

static final float SENSOR_RANGE = 20;


static final int DONT_INTERSECT = 0;
static final int COLLINEAR = 1;
static final int DO_INTERSECT = 2;

// Measured in Fusion360 model of robot
static final float WHEEL_CENTER_TO_SENSOR_CENTER = 3.5426002;  // cm
static final float ROBOT_WHEEL_SAFETY_RADIUS = 13.0/2.0;  // cm
static final float SENSOR_CIRCLE_RADIUS = 4.6192007;  // cm
static final float IDEAL_SENSOR_DISTANCE = CELL_INTERIOR_SIZE/2.0 - SENSOR_CIRCLE_RADIUS;
static final float FRONT_SENSORS_TO_WALL = IDEAL_SENSOR_DISTANCE / cos(radians(30));

class TurtleHistory {
  int cellX, cellY;
  int dir;
}


class Turtle {
  // 
  float px, py;
  float angle;
  
  int cellX, cellY;
  int dir;
  
  Maze mentalMaze;
  TurtleHistory [] history;
  int historyCount;
  int turtleState;
  int walkCount;

  float intersectX,intersectY;

  float distanceA;
  float distanceB;
  float distanceC;
  float distanceD;

  Turtle() {
    mentalMaze = new Maze();
    mentalMaze.removeAllWalls();
    
    print("ideal distance = ");
    println(IDEAL_SENSOR_DISTANCE);
    print("front sensor distance = ");
    println(FRONT_SENSORS_TO_WALL);
    
    px = cellW / 2;// - WHEEL_CENTER_TO_SENSOR_CENTER/2;
    py = cellH / 2;
    angle=0;
    
    turtleState = SEARCHING;
    // start in south-west corner
    cellX=0;
    cellY=0;
    dir=NORTH;
  
    // longest path cannot be greater than number of cells in the maze.
    history = new TurtleHistory[COLUMNS * ROWS];
    int i;
    for(i=0;i<history.length;++i) {
      history[i] = new TurtleHistory();
    }
    historyCount=0;
  
    addToHistory();
    readSensors();
  }
  
  
  void thinkAndAct() {
    print("\nI think I'm in (");
    print(cellX);
    print(',');
    print(cellY);
    print(") facing ");
    print(dir);
    print(".  ");
    
    switch(turtleState) {
    case SEARCHING:  searchMaze();  break;
    case    GOHOME:  goHome();      break;
    case  GOCENTER:  goToCenter();  break; 
    }
  }
  
  
  void readSensors() {
    distanceA = senseAlongLine(angle, +90);
    distanceB = senseAlongLine(angle, +30);
    distanceC = senseAlongLine(angle, -30);
    distanceD = senseAlongLine(angle, -90);
  }
  
  
  // send a ray into the map and find the nearest wall within the sensor range.
  // @param arg0 the absolute angle into the world
  // @param arg1 the relative angle of the sensor
  // @return distance to nearest thing, or SENSOR_RANGE+1 if nothing found.
  float senseAlongLine(float arg0, float arg1) {
    float fx0 = px + cos(radians(arg0))*WHEEL_CENTER_TO_SENSOR_CENTER;
    float fy0 = py + sin(radians(arg0))*WHEEL_CENTER_TO_SENSOR_CENTER;
    float fx = fx0 + cos(radians(arg0+arg1))*SENSOR_CIRCLE_RADIUS;
    float fy = fy0 + sin(radians(arg0+arg1))*SENSOR_CIRCLE_RADIUS;
    float ex = fx + cos(radians(arg0+arg1))*SENSOR_RANGE;
    float ey = fy + sin(radians(arg0+arg1))*SENSOR_RANGE;
      
    // test line P-E against the maze walls.  find the nearest hit.
    float nearestD=SENSOR_RANGE+1;
    int nearestI = -1;
    
    int i;
    for(i=0;i<actualMaze.walls.length;++i) {
      if(actualMaze.walls[i].removed) continue;
      
      float d = testLine(fx,fy,
                         ex,ey,
                         actualMaze.walls[i].x1,actualMaze.walls[i].y1,
                         actualMaze.walls[i].x2,actualMaze.walls[i].y2);
      if(d>0 && nearestD > d) {
        nearestD = d;
        nearestI = i;
      }
    }
      
    if( nearestD > 0 && nearestD < SENSOR_RANGE ) {
      // we got one!  https://www.youtube.com/watch?v=KzlQWCdAkgo
      if(mentalMaze.walls[nearestI].removed) {
        //print("Found wall ");
        //print(nearestI);
        //print(" at ");
        //print(nearestD);
        //print(".  ");
        mentalMaze.walls[nearestI].removed = false;
      }
    }
    
    // test the outside walls
    for(i=0;i<actualMaze.outsideWalls.length;++i) {
      float d = testLine(fx,fy,
                         ex,ey,
                         actualMaze.outsideWalls[i].x1,actualMaze.outsideWalls[i].y1,
                         actualMaze.outsideWalls[i].x2,actualMaze.outsideWalls[i].y2);
      if(d>0 && nearestD > d) {
        nearestD = d;
        //print("Found outside wall at ");
        //print(nearestD);
        //print(".  ");
      }
    }
    
    return nearestD;
  }


  // test line P-E against wall w.
  // return -1 if no intersection
  float testLine(float x1,float y1,float x2,float y2,float x3,float y3,float x4,float y4) {    
    if(intersect(x1,y1,x2,y2,x3,y3,x4,y4)==DO_INTERSECT) {
      float dx = intersectX - x1;
      float dy = intersectY - y1;
      return sqrt(dx*dx + dy*dy);
    }
    return -1;
  }


  boolean sameSign(float a, float b){
    return (( a * b) >= 0);
  }
  
  
  // http://processingjs.org/learning/custom/intersect/
  int intersect(float x1, float y1, float x2, float y2, float x3, float y3, float x4, float y4) {
    float a1, a2, b1, b2, c1, c2;
    float r1, r2 , r3, r4;
    float denom, offset, num;
  
    // Compute a1, b1, c1, where line joining points 1 and 2
    // is "a1 x + b1 y + c1 = 0".
    a1 = y2 - y1;
    b1 = x1 - x2;
    c1 = (x2 * y1) - (x1 * y2);
  
    // Compute r3 and r4.
    r3 = ((a1 * x3) + (b1 * y3) + c1);
    r4 = ((a1 * x4) + (b1 * y4) + c1);
  
    // Check signs of r3 and r4. If both point 3 and point 4 lie on
    // same side of line 1, the line segments do not intersect.
    if ((r3 != 0) && (r4 != 0) && sameSign(r3, r4)){
      return DONT_INTERSECT;
    }
  
    // Compute a2, b2, c2
    a2 = y4 - y3;
    b2 = x3 - x4;
    c2 = (x4 * y3) - (x3 * y4);
  
    // Compute r1 and r2
    r1 = (a2 * x1) + (b2 * y1) + c2;
    r2 = (a2 * x2) + (b2 * y2) + c2;
  
    // Check signs of r1 and r2. If both point 1 and point 2 lie
    // on same side of second line segment, the line segments do
    // not intersect.
    if ((r1 != 0) && (r2 != 0) && (sameSign(r1, r2))){
      return DONT_INTERSECT;
    }
  
    //Line segments intersect: compute intersection point.
    denom = (a1 * b2) - (a2 * b1);
  
    if (denom == 0) {
      return COLLINEAR;
    }
  
    if (denom < 0){ 
      offset = -denom / 2; 
    } else {
      offset = denom / 2 ;
    }
  
    // The denom/2 is to get rounding instead of truncating. It
    // is added or subtracted to the numerator, depending upon the
    // sign of the numerator.
    num = (b1 * c2) - (b2 * c1);
    if (num < 0){
      intersectX = (num - offset) / denom;
    } else {
      intersectX = (num + offset) / denom;
    }
  
    num = (a2 * c1) - (a1 * c2);
    if (num < 0){
      intersectY = (num - offset) / denom;
    } else {
      intersectY = (num + offset) / denom;
    }
  
    // lines_intersect
    return DO_INTERSECT;
  }
  
  
  void drawTurtle() {
    drawHistory();
    drawPerfectTurtle();
    drawActualTurtle();
  }
  
  
  // visualize the robot's memory of the shortest path through the maze.
  void drawHistory() {
    color c1=color(0,0,255);
    color c2=color(255,0,0);
    color c3;
    
    float ax,ay;
    for(int i=1;i<historyCount;++i) {
      noStroke();
      int cellNumber = actualMaze.getCellNumberAt(history[i].cellX,history[i].cellY);
      ax = mentalMaze.cells[cellNumber].x * cellW;
      ay = mentalMaze.cells[cellNumber].y * cellH;
      
      c3 = lerpColor(c1,c2,(float)i/(float)historyCount);
      fill(c3);
      rect(ax,ay,cellW,cellH);  
      stroke(255,255,0,128);
      float px = ax+cellW/2;
      float py = ay+cellH/2;
      float dx=0;
      float dy=0;
    
      switch(history[i].dir) {
      case NORTH: dx = -cellW; break; 
      case  EAST: dy = -cellH; break;
      case SOUTH: dx =  cellW; break;
      case  WEST: dy =  cellH; break;
      }
      
      line(px,
           py,
           px+dx,
           py+dy);
    }
  }
  
  
  void drawPerfectTurtle() {
    // body
    int cellNumber = getCurrentCellNumber();
    float ax = mentalMaze.cells[cellNumber].x * cellW;
    float ay = mentalMaze.cells[cellNumber].y * cellH;
    float px1 = ax+cellW/2;
    float py1 = ay+cellH/2;
  
    fill(0,255,0,128);
    stroke(128,255,128,128);
    ellipse(px1,py1,cellW/2,cellH/2);
    
    // line pointing forward
    float dx=0;
    float dy=0;
    switch(dir) {
    case NORTH: dx =  cellW/2; break; 
    case  EAST: dy =  cellH/2; break;
    case SOUTH: dx = -cellW/2; break;
    case  WEST: dy = -cellH/2; break;
    }
    line(px1,
         py1,
         px1+dx,
         py1+dy);
  }
  
  
  void drawActualTurtle() {
    // body
    fill(128,255,0);
    stroke(255,255,128);
    
    float fx = px + cos(radians(angle))*WHEEL_CENTER_TO_SENSOR_CENTER;
    float fy = py + sin(radians(angle))*WHEEL_CENTER_TO_SENSOR_CENTER;
    
    float d = ROBOT_WHEEL_SAFETY_RADIUS*2;
    ellipse(px,py,d,d);
    d=SENSOR_CIRCLE_RADIUS*2;
    ellipse(fx,fy,d,d);
    
    // sensors
    stroke(255,  0,  0,255);  drawSensorLine(angle,+90,distanceA);
    stroke(  0,255,  0,255);  drawSensorLine(angle,+30,distanceB);
    stroke(  0,  0,255,255);  drawSensorLine(angle,-30,distanceC);
    stroke(255,255,255,255);  drawSensorLine(angle,-90,distanceD);
  }
  
  
  void drawSensorLine(float arg0,float arg1,float distance) {
    float fx0 = px + cos(radians(arg0))*WHEEL_CENTER_TO_SENSOR_CENTER;
    float fy0 = py + sin(radians(arg0))*WHEEL_CENTER_TO_SENSOR_CENTER;
    float fx = fx0 + cos(radians(arg0+arg1))*SENSOR_CIRCLE_RADIUS;
    float fy = fy0 + sin(radians(arg0+arg1))*SENSOR_CIRCLE_RADIUS;
    float dx = fx + cos(radians(arg0+arg1))*distance;
    float dy = fy + sin(radians(arg0+arg1))*distance;
    
    line(fx,fy,dx,dy);
  }
  
  
  int getCurrentCellNumber() {
    return mentalMaze.getCellNumberAt( cellX, cellY );
  }
  
  
  
  boolean thereIsAWallToTheRight() {
    int c = getCurrentCellNumber();
    switch(dir) {
      case NORTH: return mentalMaze.thereIsAWallToTheEast (c);
      case  EAST: return mentalMaze.thereIsAWallToTheSouth(c);
      case SOUTH: return mentalMaze.thereIsAWallToTheWest (c);
      default   : return mentalMaze.thereIsAWallToTheNorth(c);
    }
  }
  
  
  boolean thereIsAWallAhead() {
    int c = getCurrentCellNumber();
    switch(dir) {
      case NORTH: return mentalMaze.thereIsAWallToTheNorth(c);
      case  EAST: return mentalMaze.thereIsAWallToTheEast (c);
      case SOUTH: return mentalMaze.thereIsAWallToTheSouth(c);
      default   : return mentalMaze.thereIsAWallToTheWest (c);
    }
  }
  
  
  void turnRight() {
    dir = (dir+1)%4;
    
    angle+=90+random(2);
    if(angle>360) angle-=360;
    print("Turning right to ");
    print(angle);
    print(".  ");
    
    print("Correcting turn.  ");
    readSensors();
    while(abs(distanceB-distanceC)>0.25) {
      if(distanceB<distanceC) {
        // left sensor closer than right.
        turnABitLeft();
      } else {
        // right sensor closer than left.
        turnABitRight();
      }
      readSensors();
    }
  }
  
  
  void turnLeft() {
    dir = (dir+4-1)%4;
    
    angle-= 90+random(2);
    if(angle<0) angle+=360;
    print("Turning left to ");
    print(angle);
    print(".  ");

    print("Correcting turn.  ");
    readSensors();
    while(abs(distanceB-distanceC)>0.25) {
      if(distanceB<distanceC) {
        // left sensor closer than right.
        turnABitLeft();
      } else {
        // right sensor closer than left.
        turnABitRight();
      }
      readSensors();
    }
  }
  
  void turnABitLeft() {
    angle-=(2+random(2))/2;
    if(angle<0) angle+=360;
    print("Turning a bit left to ");
    print(angle);
    print(".  ");
  }
  
  void turnABitRight() {
    angle+=(2+random(2))/2;
    if(angle>360) angle-=360;
    print("Turning a bit right to ");
    print(angle);
    print(".  ");
  }
  
  
  void stepForward() {
    // Check that the square we want to move to is inside the maze.
    int x = cellX;
    int y = cellY;
    
    String direction="";
    switch(dir) {
    case NORTH:  direction="north ";  ++x;  break;
    case  EAST:  direction="east " ;  ++y;  break;
    case SOUTH:  direction="south ";  --x;  break;
    case  WEST:  direction="west " ;  --y;  break;
    }
  
    if(x >= ROWS   ) x = ROWS-1;
    if(x <  0      ) x = 0;
    if(y >= COLUMNS) y = COLUMNS-1;
    if(y <  0      ) y = 0;
  
    if(cellX == x && cellY == y ) {
      return;
    }
    
    cellX = x;
    cellY = y;
    
    print("Advancing ");
    print(direction);
    print("to (");
    print(cellX);
    print(',');
    print(cellY);
    print(").  ");
    
    float travelDistance=0;
    float v=1;
    long t=millis();
    do {
      readSensors();
      
      v+=0.05;
      if(v>1) v=1;
      
      if(distanceB < SENSOR_RANGE && distanceC < SENSOR_RANGE ) {
        print("\nI see a wall ");
        print(distanceB);
        print("~");
        print(distanceC);
        print(" ahead.  ");
        // wall ahead.  Go until we are in the center of the square
        if( distanceB < FRONT_SENSORS_TO_WALL && distanceC < FRONT_SENSORS_TO_WALL ) {
          print("Stopping.  ");
          v=0;  // stop!
          break;
        } else if(abs(distanceB-distanceC)>0.1) {
          print("Straightening out.  ");
          if(distanceB<distanceC) {
            // left sensor closer than right.
            turnABitLeft();
            v-=0.1;
            if(v<0.0)v=0.0;
          } else {
            // right sensor closer than left.
            turnABitRight();
            v-=0.1;
            if(v<0.0)v=0.0;
          }
        }
      } else {
        print("\nI see nothing ahead.  ");
        /*
        if(distanceA < SENSOR_RANGE && distanceD < SENSOR_RANGE ) {
          print("I see walls on both sides.  ");
          // walls on both sides.
          if(abs(distanceA - distanceD) >0.01 ) {
            if(distanceA > distanceD ) {
              print("Closer on the left.  ");
              turnABitRight();
              v-=0.1;
              if(v<0.0)v=0.0;
            } else if(distanceA < distanceD ) {
              print("Closer on the right.  ");
              turnABitLeft();
              v-=0.1;
              if(v<0.0)v=0.0;
            }
          }
        } else*/ if(distanceA < SENSOR_RANGE) {
          print("I see a wall ");
          print(distanceA - IDEAL_SENSOR_DISTANCE);
          print(" on the right.  ");
          // how far are we from the right wall?
          if(abs(IDEAL_SENSOR_DISTANCE - distanceA) > 0.01) {
            if(distanceA < IDEAL_SENSOR_DISTANCE ) {
              //print("Too close.  ");
              turnABitLeft();
              v-=0.1;
              if(v<0.0)v=0.0;
            } else if(distanceA > IDEAL_SENSOR_DISTANCE ) {
              //print("Too far.  ");
              turnABitRight();
              v-=0.1;
              if(v<0.0)v=0.0;
            }
          }
        } else if(distanceD < SENSOR_RANGE) {
          print("I see a wall ");
          print(distanceD - IDEAL_SENSOR_DISTANCE);
          print(" on the left.  ");
          if(abs(IDEAL_SENSOR_DISTANCE - distanceD) > 0.01) {
            if(distanceD < IDEAL_SENSOR_DISTANCE )  {
              //print("Too close.  ");
              turnABitRight();
              v-=0.1;
              if(v<0.0)v=0.0;
            } else if(distanceD > IDEAL_SENSOR_DISTANCE )  {
              //print("Too far.  ");
              turnABitLeft();
              v-=0.1;
              if(v<0.0)v=0.0;
            }
          }
        } else {
          // I see nothing forward, left, or right.  Go straight?
          print("I see nothing left or right.  ");
        }
      }
      
      float dx=cos(radians(angle))*v;
      float dy=sin(radians(angle))*v;
      px+=dx;
      py+=dy;
      
      travelDistance += sqrt(dx*dx + dy*dy);
    } while(travelDistance < CELL_SIZE && millis()-t<150);
    
    if(travelDistance < CELL_SIZE) {
      print("timed out.  ");
    }
    
    cellX = floor(px / cellW);
    cellY = floor(py / cellH);
    
    readSensors();
  }
  
  void addToHistory() {
    history[historyCount].cellX = cellX;
    history[historyCount].cellY = cellY;
    history[historyCount].dir = dir;
    historyCount++;
  }
  
  
  /**
   * Remove dead ends from the calulcated shortest route.
   * Do this by checking if we've been here before.
   * If we have, remove everything in history between the last visit and now.
   */
  void pruneHistory(int findCell) {
    int i;
    for(i = historyCount-2; i >= 0; --i) {
      int cell = mentalMaze.getCellNumberAt(history[i].cellX, history[i].cellY);
      if(cell == findCell) {
        historyCount = i+1;
        return;
      }
    }
  }
  
  
  // One step in the maze search.
  void searchMaze() {
    if(!thereIsAWallToTheRight()) {
      print("I think there's no wall on the right.  ");
      turnRight();
    }
      
    if(!thereIsAWallAhead()) {
      print("I think there's no wall ahead.  ");
      stepForward();
      addToHistory();
    } else {
      print("I think there's a wall ahead.  ");
      turnLeft();
    }
    println();
  
    // remove dead ends
    pruneHistory(getCurrentCellNumber());
    
    if( iAmInTheCenter() ) {
      println("** CENTER FOUND.  GOING HOME **");
      turtleState = GOHOME;
      walkCount = historyCount;
    }
  }
  
  
  boolean iAmInTheCenter() {
    return ( cellX == (ROWS   /2)-1 || cellX == (ROWS   /2) ) &&
           ( cellY == (COLUMNS/2)-1 || cellY == (COLUMNS/2) );
  }
  
  
  void turnToFace(int newDir) {
    if(dir == newDir) {
      // facing that way already
      return;
    }
  
    if(newDir == dir+2 || newDir == dir-2 ) {
      // 180
      turnRight();
      turnRight();
      return;
    }
    if(newDir == (dir+4-1)%4) turnLeft();
    if(newDir == (dir  +1)%4) turnRight();
  }
  
  
  // One step towards home along the known shortest route.
  void goHome() {
    walkCount--;
    turnToFace((history[walkCount].dir+2)%4);  // face the opposite of the history
    stepForward();
    println();
    
    if(walkCount==0) {
      println("** HOME FOUND.  GOING TO CENTER **");
      turtleState = GOCENTER;
      walkCount=1;
    }
  }
  
  
  // One step towards center along the known shortest route.
  void goToCenter() {
    turnToFace(history[walkCount].dir);  // face the opposite of the history
    stepForward();
    println();
  
    walkCount++;
    
    if(walkCount==historyCount) {
      println("** CENTER FOUND.  GOING HOME **");
      turtleState = GOHOME;
    }
  }
}