// Find the center of a maze, then roam back and forth along the shortest route forever.
// Dan Royer (dan@marginallyclever.com) 2016-05-21
// Turtle logic

class Turtle {
  int cellX, cellY;
  int dir;
}


static final int NORTH=0;
static final int EAST =1;
static final int SOUTH=2;
static final int WEST =3;

static final int SEARCHING = 0;
static final int GOHOME    = 1;
static final int GOCENTER  = 2;

Turtle turtle;
Turtle [] history;
int historyCount;
int turtleState;
int walkCount;


void setupTurtle() {
  turtle = new Turtle();
  turtleState = SEARCHING;
  // start in bottom left corner
  turtle.cellX=0;
  turtle.cellY=0;
  turtle.dir=NORTH;

  // longest path cannot be greater than number of cells in the maze.
  history = new Turtle[columns * rows];
  int i;
  for(i=0;i<history.length;++i) {
    history[i] = new Turtle();
  }
  historyCount=0;

  addToHistory();
}


// visualize the robot's memory of the shortest path through the maze.
void drawHistory() {
  color c1=color(0,0,255);
  color c2=color(255,0,0);
  color c3;
  
  float ax,ay;
  for(int i=0;i<historyCount;++i) {
    noStroke();
    int cellNumber = getCellNumberAt(history[i].cellX,history[i].cellY);
    ax = cells[cellNumber].x * cellW;
    ay = cells[cellNumber].y * cellH;
    
    c3 = lerpColor(c1,c2,(float)i/(float)historyCount);
    fill(c3);
    rect(ax,ay,cellW,cellH);  
    stroke(255,255,0);
    float px = ax+cellW/2;
    float py = ay+cellH/2;
    float dx=0;
    float dy=0;
  
    switch(history[i].dir) {
    case NORTH: dx =  cellW/2; break; 
    case  EAST: dy =  cellH/2; break;
    case SOUTH: dx = -cellW/2; break;
    case  WEST: dy = -cellH/2; break;
    }
    
    line(px,
         py,
         px+dx,
         py+dy);
  }
}


void drawTurtle() {
  drawHistory();
  
  // body
  int cellNumber = getCurrentCellNumber();
  float ax = cells[cellNumber].x * cellW;
  float ay = cells[cellNumber].y * cellH;
  float px = ax+cellW/2;
  float py = ay+cellH/2;

  fill(0,255,0);
  stroke(128,255,128);
  ellipse(px,py,cellW/2,cellH/2);
  
  // line pointing forward
  float dx=0;
  float dy=0;
  switch(turtle.dir) {
  case NORTH: dx =  cellW/2; break; 
  case  EAST: dy =  cellH/2; break;
  case SOUTH: dx = -cellW/2; break;
  case  WEST: dy = -cellH/2; break;
  }
  line(px,
       py,
       px+dx,
       py+dy);
}


int getCurrentCellNumber() {
  return getCellNumberAt( turtle.cellX, turtle.cellY );
}


// convert grid (x,y) to cell index number.
int getCellNumberAt(int x,int y) {
  return y * columns + x;
}


// returns true if there is a wall between cells A and B.
boolean thereIsAWallBetween(int a,int b) {
  int wi = findWallBetween(a,b);
  return (wi==-1 || !walls[wi].removed);
}


boolean thereIsAWallToTheNorth(int c) {  return thereIsAWallBetween(c, c+1      );  }
boolean thereIsAWallToTheSouth(int c) {  return thereIsAWallBetween(c, c-1      );  }
boolean thereIsAWallToTheEast (int c) {  return thereIsAWallBetween(c, c+columns);  }
boolean thereIsAWallToTheWest (int c) {  return thereIsAWallBetween(c, c-columns);  }


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


void turnRight() {
  print("Turning right.  ");
  turtle.dir = (turtle.dir+1)%4;
}


void turnLeft() {
  print("Turning left.  ");
  turtle.dir = (turtle.dir+4-1)%4;
}


void stepForward() {
  // Check that the square we want to move to is inside the maze.
  int x = turtle.cellX;
  int y = turtle.cellY;
  
  switch(turtle.dir) {
  case NORTH:  print("north");  ++x;  break;
  case  EAST:  print("east" );  ++y;  break;
  case SOUTH:  print("south");  --x;  break;
  case  WEST:  print("west" );  --y;  break;
  }

  if(x >= rows   ) x = rows-1;
  if(x <  0      ) x = 0;
  if(y >= columns) y = columns-1;
  if(y <  0      ) y = 0;

  if(turtle.cellX == x && turtle.cellY == y ) {
    return;
  }
  
  turtle.cellX = x;
  turtle.cellY = y;
  
  print("Advancing to (");
  print(turtle.cellX);
  print(',');
  print(turtle.cellY);
  print(").  ");
}


void addToHistory() {
  history[historyCount].cellX = turtle.cellX;
  history[historyCount].cellY = turtle.cellY;
  history[historyCount].dir = turtle.dir;
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
    int cell = getCellNumberAt(history[i].cellX, history[i].cellY);
    if(cell == findCell) {
      historyCount = i+1;
      return;
    }
  }
}


// One step in the maze search.
void searchMaze() {
  if(!thereIsAWallToTheRight()) {
    print("No wall on the right.  ");
    turnRight();
  }
    
  if(!thereIsAWallAhead()) {
    print("No wall ahead.  ");
    stepForward();
    addToHistory();
  } else {
    print("Wall ahead.  ");
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
  return ( turtle.cellX == (rows   /2)-1 || turtle.cellX == (rows   /2) ) &&
         ( turtle.cellY == (columns/2)-1 || turtle.cellY == (columns/2) );
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