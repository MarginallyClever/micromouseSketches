// Find the center of a maze, then roam back and forth along the shortest route forever.
// Dan Royer (dan@marginallyclever.com) 2016-05-21

class MazeCell {
  int x, y;
  boolean visited;
  boolean onStack;
}

class MazeWall {
  int cellA, cellB;
  boolean removed;
}


class Turtle {
  int cellX, cellY;
  int dir;
}


int rows = 16, columns = 16;
float xmax, xmin, ymax, ymin;
float cellW,cellH;

MazeCell[] cells;
MazeWall[] walls;

Turtle turtle = new Turtle();
Turtle [] history = new Turtle[256];  // probably enough?
int historyCount;

int state=0;

int walkCount;

/**
 * build a list of walls in the maze, cells in the maze, and how they connect to each other.
 * @param out
 * @throws IOException
 */
void createMazeNow() {
  // build the cells
  cells = new MazeCell[rows * columns];

  int x, y, i = 0;
  for (y = 0; y < rows; ++y) {
    for (x = 0; x < columns; ++x) {
      cells[i] = new MazeCell();
      cells[i].visited = false;
      cells[i].onStack = false;
      cells[i].x = x;
      cells[i].y = y;
      ++i;
    }
  }

  // build the graph
  walls = new MazeWall[((rows - 1) * columns) + ((columns - 1) * rows)];
  i = 0;
  for (y = 0; y < rows; ++y) {
    for (x = 0; x < columns; ++x) {
      if (x < columns - 1) {
        // vertical wall between horizontal cells
        walls[i] = new MazeWall();
        walls[i].removed = false;
        walls[i].cellA = y * columns + x;
        walls[i].cellB = y * columns + x + 1;
        ++i;
      }
      if (y < rows - 1) {
        // horizontal wall between vertical cells
        walls[i] = new MazeWall();
        walls[i].removed = false;
        walls[i].cellA = y * columns + x;
        walls[i].cellB = y * columns + x + columns;
        ++i;
      }
    }
  }

  int unvisitedCells = cells.length; // -1 for initial cell.
  int cellsOnStack = 0;

  // Make the initial cell the current cell and mark it as visited
  int currentCell = 0;
  cells[currentCell].visited = true;
  --unvisitedCells;
  
  int wallIndex;

  // While there are unvisited cells
  while (unvisitedCells > 0) {
    // If the current cell has any neighbours which have not been visited
    // Choose randomly one of the unvisited neighbours
    int nextCell = chooseUnvisitedNeighbor(currentCell);
    if (nextCell != -1) {
      // Push the current cell to the stack
      cells[currentCell].onStack = true;
      ++cellsOnStack;
      // Remove the wall between the current cell and the chosen cell
      wallIndex = findWallBetween(currentCell, nextCell);
      assert (wallIndex != -1);
      walls[wallIndex].removed = true;
      // Make the chosen cell the current cell and mark it as visited
      currentCell = nextCell;
      cells[currentCell].visited = true;
      --unvisitedCells;
    } else if (cellsOnStack > 0) {
      // else if stack is not empty pop a cell from the stack
      for (i = 0; i < cells.length; ++i) {
        if (cells[i].onStack) {
          // Make it the current cell
          currentCell = i;
          cells[i].onStack = false;
          --cellsOnStack;
          break;
        }
      }
    }
  }

  // remove the walls between the four center squares
  x = (columns/2)-1;
  y = (rows/2)-1;
  currentCell = y * columns + x;
  
  wallIndex = findWallBetween(currentCell, currentCell+1);
  walls[wallIndex].removed = true;
  wallIndex = findWallBetween(currentCell, currentCell+columns);
  walls[wallIndex].removed = true;
  wallIndex = findWallBetween(currentCell+columns, currentCell+columns+1);
  walls[wallIndex].removed = true;
  wallIndex = findWallBetween(currentCell+1, currentCell+columns+1);
  walls[wallIndex].removed = true;
}


int chooseUnvisitedNeighbor(int currentCell) {
  int x = cells[currentCell].x;
  int y = cells[currentCell].y;

  int[] candidates = new int[4];
  int found = 0;

  // left
  if (x > 0 && cells[currentCell - 1].visited == false) {
    candidates[found++] = currentCell - 1;
  }
  // right
  if (x < columns - 1 && !cells[currentCell + 1].visited) {
    candidates[found++] = currentCell + 1;
  }
  // up
  if (y > 0 && !cells[currentCell - columns].visited) {
    candidates[found++] = currentCell - columns;
  }
  // down
  if (y < rows - 1 && !cells[currentCell + columns].visited) {
    candidates[found++] = currentCell + columns;
  }

  if (found == 0)
    return -1;

  // choose a random candidate
  int choice = (int) (Math.random() * found);
  assert (choice >= 0 && choice < found);

  return candidates[choice];
}


void drawMaze() {
  ymin = 0;
  ymax = height;
  xmin = 0;
  xmax = width;
  
  cellW = (xmax - xmin) / columns;
  cellH = (ymax - ymin) / rows;

  // Draw outside edge
  line(xmin, ymax, xmax, ymax);
  line(xmin, ymin, xmax, ymin);
  line(xmax, ymin, xmax, ymax);
  line(xmin, ymin, xmin, ymax);

  int i;
  for (i = 0; i < walls.length; ++i) {
    if (walls[i].removed)
      continue;
    int a = walls[i].cellA;
    int b = walls[i].cellB;
    int ax = cells[a].x;
    int ay = cells[a].y;
    int bx = cells[b].x;
    int by = cells[b].y;
    if (ay == by) {
      // vertical wall
      float x = xmin + (ax + 1) * cellW;
      float y0 = ymin + (ay + 0) * cellH;
      float y1 = ymin + (ay + 1) * cellH;

      line(x,y0,x,y1);
    } else if (ax == bx) {
      // horizontal wall
      float x0 = xmin + (ax + 0) * cellW;
      float x1 = xmin + (ax + 1) * cellW;
      float y = ymin + (ay + 1) * cellH;
      line(x0,y,x1,y);
    }
  }
}


/**
 * Find the index of the wall between two cells
 * returns -1 if no wall is found (asking the impossible)
 */
int findWallBetween(int currentCell, int nextCell) {
  int i;
  for (i = 0; i < walls.length; ++i) {
    if (walls[i].cellA == currentCell || walls[i].cellA == nextCell) {
      if (walls[i].cellB == currentCell || walls[i].cellB == nextCell)
        return i;
    }
  }
  return -1;
}



void setup () {
  // set the window size:
  size(512, 512);

  stroke(255,255,255);
  createMazeNow();
  
  // prepare the turtle
  turtle.cellX=0;
  turtle.cellY=rows-1;
  turtle.dir=3;
  int i;
  for(i=0;i<history.length;++i) {
    history[i] = new Turtle();
  }
  historyCount=0;
  addToHistory();
}



void draw() {
  // clear everything
  background(0);
  
  color c1=color(0,0,255);
  color c2=color(255,0,0);
  color c3;
  
  // draw history
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
    default: dx = cellW/2; break; 
    case  1: dy = cellH/2; break;
    case  2: dx = -cellW/2; break;
    case  3: dy = -cellH/2; break;
    }
    
    line(px,
         py,
         px+dx,
         py+dy);
  }
  
  // draw turtle
  int cellNumber = getCurrentCellNumber();
  ax = cells[cellNumber].x * cellW;
  ay = cells[cellNumber].y * cellH;
  
  float px = ax+cellW/2;
  float py = ay+cellH/2;
  float dx=0;
  float dy=0;

  stroke(0,255,0);
  ellipse(px,py,cellW/2,cellH/2);
  
  switch(turtle.dir) {
  default: dx = cellW/2; break; 
  case  1: dy = cellH/2; break;
  case  2: dx = -cellW/2; break;
  case  3: dy = -cellH/2; break;
  }
  stroke(0,0,255);
  line(px,
       py,
       px+dx,
       py+dy);

  // draw the maze
  stroke(255,255,255);
  drawMaze();
}

int getCurrentCellNumber() {
  return getCellNumberAt( turtle.cellX, turtle.cellY );
}

int getCellNumberAt(int x,int y) {
  return y * columns + x;
}


boolean thereIsAWallToTheNorth() {
  int c = getCurrentCellNumber();
  int wi = findWallBetween(c, c+1);
  return (wi==-1 || !walls[wi].removed); 
}


boolean thereIsAWallToTheSouth() {
  int c = getCurrentCellNumber();
  int wi = findWallBetween(c, c-1);
  return (wi==-1 || !walls[wi].removed); 
}


boolean thereIsAWallToTheEast() {
  int c = getCurrentCellNumber();
  int wi = findWallBetween(c, c+columns);
  return (wi==-1 || !walls[wi].removed); 
}


boolean thereIsAWallToTheWest() {
  int c = getCurrentCellNumber();
  int wi = findWallBetween(c, c-columns);
  return (wi==-1 || !walls[wi].removed); 
}


boolean thereIsAWallToTheRight() {
  switch(turtle.dir) {
    default: return thereIsAWallToTheEast();
    case  1: return thereIsAWallToTheSouth();
    case  2: return thereIsAWallToTheWest();
    case  3: return thereIsAWallToTheNorth();
  }
}


boolean thereIsAWallAhead() {
  switch(turtle.dir) {
    default: return thereIsAWallToTheNorth();
    case  1: return thereIsAWallToTheEast();
    case  2: return thereIsAWallToTheSouth();
    case  3: return thereIsAWallToTheWest();
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
  print("Advancing ");
  
  switch(turtle.dir) {
  default:  print("north");   turtle.cellX++;  break;
  case  1:  print("east");    turtle.cellY++;  break;
  case  2:  print("south");   turtle.cellX--;  break;
  case  3:  print("west");    turtle.cellY--;  break;
  }

  if(turtle.cellX >= rows) turtle.cellX = rows-1;
  if(turtle.cellX <  0   ) turtle.cellX = 0;
  if(turtle.cellY >= columns) turtle.cellY = columns-1;
  if(turtle.cellY <  0      ) turtle.cellY = 0;

  print(" to (");
  print(turtle.cellX);
  print(',');
  print(turtle.cellY);
  print(')');
}


void addToHistory() {
  history[historyCount].cellX = turtle.cellX;
  history[historyCount].cellY = turtle.cellY;
  history[historyCount].dir = turtle.dir;
  historyCount++;
}


void pruneHistory(int findCell) {
//  print("Finding ");
//  println(findCell);
  int i;
  for(i = historyCount-2; i >= 0; --i) {
    int cell = getCellNumberAt(history[i].cellX, history[i].cellY);
//    print(cell);
//    print(" ");
    if(cell == findCell) {
//      println(" found.");
      historyCount = i+1;
      return;
    }
  }
  
//  println();
}


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
  
  pruneHistory(getCurrentCellNumber());
  
  if( ( turtle.cellX == (rows/2)-1 || turtle.cellX == (rows/2)+1 ) &&
      ( turtle.cellY == (columns/2)-1 || turtle.cellY == (columns/2)+1 ) )
  {
    println("** CENTER FOUND.  GOING HOME **");
    state=1;
    walkCount = historyCount;
  }
  
  redraw();
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


void goHome() {
  walkCount--;
  turnToFace((history[walkCount].dir+2)%4);  // face the opposite of the history
  stepForward();
  println();
  
  if(walkCount==0) {
    println("** HOME FOUND.  GOING TO CENTER **");
    state=2;
    walkCount=1;
  }
}


void goToCenter() {
  turnToFace(history[walkCount].dir);  // face the opposite of the history
  stepForward();
  println();

  walkCount++;
  
  if(walkCount==historyCount) {
    println("** CENTER FOUND.  GOING HOME **");
    state=1;
  }
}


void keyPressed() {
  switch(state) {
  default: searchMaze();  break;
  case 1: goHome();  break;
  case 2: goToCenter();  break; 
  }
}