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


// Measured in Fusion360 model of robot
static final float WHEEL_CENTER_TO_SENSOR_CENTER = 3.5426002;  // cm
static final float ROBOT_WHEEL_SAFETY_RADIUS = 13.0/2.0;  // cm
static final float SENSOR_CIRCLE_RADIUS = 4.6192007;  // cm
static final float IDEAL_SENSOR_DISTANCE = CELL_INTERIOR_SIZE/2.0 - SENSOR_CIRCLE_RADIUS;
static final float FRONT_SENSORS_TO_IDEAL_FRONT_WALL = IDEAL_SENSOR_DISTANCE / cos(radians(30));
static final float FRONT_SENSORS_TO_IDEAL_SIDE_WALL = IDEAL_SENSOR_DISTANCE / sin(radians(30));



class TurtleHistory {
  int cellX, cellY;
  int dir;
}


class Turtle {
  // actual position 
  float px, py;
  float angle;
  float speed;
  
  // estimate of current location in the maze
  int cellX, cellY;
  int dir;

  // steering sub-goals  
  int goal;
  float goalCounter;
    
  // Turtle memory
  Maze mentalMaze;
  TurtleHistory [] history;
  int historyCount;
  int turtleState;
  int walkCount;

  // sensor readings
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
    println(FRONT_SENSORS_TO_IDEAL_FRONT_WALL);
    
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
    goal=0;
    goalCounter=0;
  }
  
  
  void thinkAndAct() {
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
    if( distance < SENSOR_RANGE ) {
      fill(255,255,0);
      noStroke();
      ellipse(dx,dy,4,4);
    }
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
  
  
  int getCellToTheRight() {
    int c = getCurrentCellNumber();
    switch((dir+1)%4) {
      case NORTH: return c+1;
      case  EAST: return c+COLUMNS;
      case SOUTH: return c-1;
      default   : return c-COLUMNS;
    }
  }
  
  
  void turnRight() {
    dir = (dir+1)%4;
    
    angle+=90+random(2);
    if(angle>360) angle-=360;
    print("Turning right to ");
    print(angle);
    print(".  ");
    //correctTurn();
  }
  
  
  void turnLeft() {
    dir = (dir+4-1)%4;
    
    angle-= 90+random(2);
    if(angle<0) angle+=360;
    print("Turning left to ");
    print(angle);
    print(".  ");
    //correctTurn();
  }
  
  
  void correctTurn() {
    print("Correcting turn.  ");
    if(thereIsAWallAhead()) {
      print("I know there's a wall ahead.  ");
      readSensors();
      int i=0;
      while(abs(distanceB-distanceC)>0.25 && i<100) {
        if(distanceB<distanceC) {
          // left sensor closer than right.
          turnABitLeft();
          print("\n");
        } else {
          // right sensor closer than left.
          turnABitRight();
          print("\n");
        }
        readSensors();
        ++i;
      }
    } else if(thereIsAWallToTheRight()) {
      print("I know there's a wall on the right.  ");
      readSensors();
      int i=0;
      while(abs(IDEAL_SENSOR_DISTANCE - distanceA) > 0.01 && i<100) {
        print(distanceA - IDEAL_SENSOR_DISTANCE);
        print("  ");
        if(distanceA < IDEAL_SENSOR_DISTANCE ) {
          //print("Too close.  ");
          turnABitLeft();
          print("\n");
        } else {
          //print("Too far.  ");
          turnABitRight();
          print("\n");
        }
        readSensors();
        ++i;
      }
    } else {
      print("I know where there's a wall to use.  ");
    }
  }
  
  
  void turnABitLeft() {
    angle-=(2+random(2))/2;
    if(angle<0) angle+=360;
    //print("Turning a bit left to ");
    //print(angle);
    //print(".  ");
  }
  
  void turnABitRight() {
    angle+=(2+random(2))/2;
    if(angle>360) angle-=360;
    //print("Turning a bit right to ");
    //print(angle);
    //print(".  ");
  }

  
  void accelerate(float deltaV) {
    //print("faster.  ");
    speed+=deltaV;
    // cap the speed
    if(speed>1) speed=1;
    if(speed<0) speed=0;
  }
  
  void decelerate(float deltaV) {
    //print("slower.  ");
    speed-=deltaV;
    // cap the speed
    if(speed>1) speed=1;
    if(speed<0) speed=0;
  }
  
  void fullStop() {
    //print("Stop.  ");
    speed=0;
  }
  
  
    // One step in the maze search.
  void searchMaze() {
    accelerate(0.05);
    readSensors();

    boolean proximityAlarm =
      distanceB < FRONT_SENSORS_TO_IDEAL_FRONT_WALL &&
      distanceC < FRONT_SENSORS_TO_IDEAL_FRONT_WALL;

    switch(goal) {
      default: {  // drive forward until a wall it found
        if( proximityAlarm ) {
          if( abs(distanceB - distanceC) > 0.25) {
            if( distanceB < distanceC ) turnABitLeft();
            else                        turnABitRight();
          }
          // decide which way to turn
          if( thereIsAWallToTheRight() ) {
            goal=2;
            goalCounter=angle;
          } else {
            goal=1;
            goalCounter=angle;
          }
        } else {
          if( distanceA < IDEAL_SENSOR_DISTANCE ) turnABitLeft();
          if( distanceD < IDEAL_SENSOR_DISTANCE ) turnABitRight();
        }
      }
      break;
      case 1: {  // turn right
        fullStop();
        turnABitRight();
       
        float a = angle;
        if(goalCounter < 100 && angle>300) a=angle-360;
        if(abs(a-goalCounter)>=90) {
          goal = 0;
          goalCounter=0;
        }
      }
      break;
      case 2: {  // turn left
        fullStop();
        turnABitLeft();
       
        float a = angle;
        if(goalCounter >260 && angle<100) a+=360;
        if(abs(a-goalCounter)>=90) {
          goal = 0;
          goalCounter=0;
        }
      }
      break;
    }

    // Advance
    float dx=cos(radians(angle))*speed;
    float dy=sin(radians(angle))*speed;
    px+=dx;
    py+=dy;

    if(goal==0) {
      goalCounter+=sqrt(dx*dx + dy*dy);
      if( goalCounter > CELL_SIZE ) {
        //paused=true;
        if( !thereIsAWallToTheRight() ) {
          print("No wall on the right.\n");
          goal=1;
          goalCounter=angle;
        } else {
          print("Wall on the right.\n");
          if( !thereIsAWallAhead() ) {
            print("No wall ahead.\n");
            goalCounter=0;
          } else {
            print("wall ahead.\n");
            goal=2;
            goalCounter=angle;
          }
        }
      }
    }

    int x = floor(px / cellW);
    int y = floor(py / cellH);
    if( x!=cellX || y!=cellY ) {
      cellX = x;
      cellY = y;
      dir = floor( (angle+45) / 90 ) % 4;
      addToHistory();
    }
  
    // remove dead ends
    pruneHistory(getCurrentCellNumber());
    
    if( iAmInTheCenter() ) {
      println("** CENTER FOUND.  GOING HOME **");
      turtleState = GOHOME;
      walkCount = historyCount;
      goal = 2;
      goalCounter = 0;
    }
  }
  
  
  void addToHistory() {
    history[historyCount].cellX = cellX;
    history[historyCount].cellY = cellY;
    history[historyCount].dir = dir;
    historyCount++;
      
    int i = mentalMaze.getCellNumberAt(cellX,cellY);
    mentalMaze.cells[i].visited=true;
  }
  
  /**
   * @return the index number of 'findCell' if found in history.  -1 if not found.
   */
  int findCellInHistory(int findCell) {
    int i;
    for(i = historyCount-2; i >= 0; --i) {
      int cell = mentalMaze.getCellNumberAt(history[i].cellX, history[i].cellY);
      if(cell == findCell) {
        return i;
      }
    }
    return -1;
  }
  
  /**
   * Remove dead ends from the calulcated shortest route.
   * Do this by checking if we've been here before.
   * If we have, remove everything in history between the last visit and now.
   */
  void pruneHistory(int findCell) {
    int i = findCellInHistory(findCell);
    if(i==-1) return;
    historyCount = i+1;
  }
  
  
  boolean iAmInTheCenter() {
    return ( cellX == (ROWS   /2)-1 || cellX == (ROWS   /2) ) &&
           ( cellY == (COLUMNS/2)-1 || cellY == (COLUMNS/2) );
  }
  
  
  void turnToFace(int newDir) {
    if(dir == newDir) {
      // facing that way already
      goal = 1;
      goalCounter = 0;
      return;
    }
  
    if(newDir == dir+2 || newDir == dir-2 ) {
      // 180
      turnRight();
      turnRight();
      return;
    }
    if(newDir == (dir+4-1)%4) {
      turnLeft();
    }
    if(newDir == (dir  +1)%4) {
      turnRight();
    }
  }
  
  
  void stepForward() {
    accelerate(0.05);
    readSensors();

    boolean proximityAlarm =
      distanceB < FRONT_SENSORS_TO_IDEAL_FRONT_WALL &&
      distanceC < FRONT_SENSORS_TO_IDEAL_FRONT_WALL;

    if( proximityAlarm ) {
      if( abs(distanceB - distanceC) > 0.25) {
        if( distanceB < distanceC ) turnABitLeft();
        else                        turnABitRight();
      }
      print("Next 1.  ");
      goal = 2;
      return;
    } else {
      if( distanceA < IDEAL_SENSOR_DISTANCE ) turnABitLeft();
      if( distanceD < IDEAL_SENSOR_DISTANCE ) turnABitRight();
    }
        
    // Advance
    float dx=cos(radians(angle))*speed;
    float dy=sin(radians(angle))*speed;
    px+=dx;
    py+=dy;

    goalCounter+=sqrt(dx*dx + dy*dy);
    if( goalCounter > CELL_SIZE ) {
      print("Next 2.  ");
      goal = 2;
    }

    int x = floor(px / cellW);
    int y = floor(py / cellH);
    if( x!=cellX || y!=cellY ) {
      cellX = x;
      cellY = y;
      dir = floor( (angle+45) / 90 ) % 4;
    }
  }
  
  
  // One step towards home along the known shortest route.
  void goHome() {
    switch(goal) {
    default:
      turnToFace((history[walkCount].dir+2)%4);  // face the opposite of the history
      break;
    case 1:   
      stepForward();
      break;
    case 2:
      walkCount--;
      if(walkCount==0) {
        println("** HOME FOUND.  GOING TO CENTER **");
        turtleState = GOCENTER;
        walkCount=1;
        goal = 0;
        goalCounter = 0;
      } else {
        goal = 0;
        goalCounter = angle;
      }
      break;
    }
  }
  
  
  // One step towards center along the known shortest route.
  void goToCenter() {
    switch(goal) {
    default:
      turnToFace((history[walkCount].dir)%4);  // face the opposite of the history
      break;
    case 1:   
      stepForward();
      break;
    case 2:
      walkCount++;
      if(walkCount==historyCount) {
        println("** CENTER FOUND.  GOING HOME **");
        turtleState = GOHOME;
        goal = 2;
        goalCounter = 0;
      } else {
        goal = 0;
        goalCounter = angle;
      }
      break;
    }
  }
}