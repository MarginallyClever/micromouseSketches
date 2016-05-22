// Generate a random maze in setup()
// Walk the robot through the maze, one step every time the user presses a key.
// 2016-05-22 dan royer (droyer@marginallyclever.com) 

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
Turtle [] history = new Turtle[256*4];  // probably enough?
int historyCount;

/**
 * build a list of walls in the maze, cells in the maze, and how they connect to each other.
 * @param out
 * @throws IOException
 */
private void createMazeNow() {
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
  assert (wallIndex != -1);
  walls[wallIndex].removed = true;
  wallIndex = findWallBetween(currentCell, currentCell+columns);
  println(wallIndex);
  assert (wallIndex != -1);
  walls[wallIndex].removed = true;
  wallIndex = findWallBetween(currentCell+columns, currentCell+columns+1);
  println(wallIndex);
  assert (wallIndex != -1);
  walls[wallIndex].removed = true;
  wallIndex = findWallBetween(currentCell+1, currentCell+columns+1);
  println(wallIndex);
  assert (wallIndex != -1);
  walls[wallIndex].removed = true;
}


private int chooseUnvisitedNeighbor(int currentCell) {
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


private void drawMaze() {
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


private int findWallBetween(int currentCell, int nextCell) {
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
  size(256, 256);

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
}


void draw() {
  // clear everything
  background(0);
  
  stroke(255,255,255);
  drawMaze();
  
  noStroke();
  
  fill(255,0,0);
  int cellNumber = getCurrentCellNumber();
  float ax = cells[cellNumber].x * cellW;
  float ay = cells[cellNumber].y * cellH;
  rect(ax,ay,cellW,cellH);
  
  stroke(255,255,0);
  float px = ax+cellW/2;
  float py = ay+cellH/2;
  float dx=0;
  float dy=0;
  
  switch(turtle.dir) {
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

int getCurrentCellNumber() {
  return turtle.cellY * columns + turtle.cellX;
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
  turtle.dir++;
  if(turtle.dir>3) turtle.dir=0;
}


void turnLeft() {
  print("Turning left.  ");
  turtle.dir--;
  if(turtle.dir<0) turtle.dir=3;
}


void stepForward() {
  print("Advancing from (");
  print(turtle.cellX);
  print(',');
  print(turtle.cellY);
  print(") to (");
  
  switch(turtle.dir) {
  default:  print("north");   turtle.cellX++;  break;
  case  1:  print("east");    turtle.cellY++;  break;
  case  2:  print("south");   turtle.cellX--;  break;
  case  3:  print("west");    turtle.cellY--;  break;
  }
  
  print(turtle.cellX);
  print(',');
  print(turtle.cellY);
  print(") clipped to (");
  
  if(turtle.cellX >= rows) turtle.cellX = rows-1;
  if(turtle.cellX <  0   ) turtle.cellX = 0;
  if(turtle.cellY >= columns) turtle.cellY = columns-1;
  if(turtle.cellY <  0      ) turtle.cellY = 0;
     
  print(turtle.cellX);
  print(',');
  print(turtle.cellY);
  print(')');
}


void walkTheMaze() {
  println("Step start");
  if(!thereIsAWallToTheRight()) {
    println("No wall on the right.  ");
    turnRight();
    stepForward();
  } else {
    print("Wall on the right.  ");
    if(!thereIsAWallAhead()) {
      println("No wall ahead.  ");
      stepForward();
    } else {
      println("Wall ahead.");
      turnLeft();
    }
  }

  println("\nStep end.");
  redraw();
}

void keyPressed() {
  walkTheMaze();  
}