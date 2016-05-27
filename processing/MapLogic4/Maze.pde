// Find the center of a maze, then roam back and forth along the shortest route forever.
// Dan Royer (dan@marginallyclever.com) 2016-05-21
// Maze creation and access methods

class MazeCell {
  int x, y;
  boolean visited;
  boolean onStack;
}

class MazeWall {
  int cellA, cellB;
  float x1,y1,x2,y2;
  
  boolean removed;
}


static final int ROWS = 16;
static final int COLUMNS = 16;
static final float CELL_SIZE = 18;  //cm
static final float WALL_THICKNESS = 1.2;  //cm
static final float CELL_INTERIOR_SIZE = CELL_SIZE - WALL_THICKNESS;  // cm
float xmax, xmin, ymax, ymin;
float cellW,cellH;

  
class Maze {
  // map details
  MazeCell[] cells;
  MazeWall[] walls;
  MazeWall[] outsideWalls;
  
  // build a list of walls in the maze, cells in the maze, and how they connect to each other.
  Maze() {
    ymin = 0;
    ymax = height;
    xmin = 0;
    xmax = width;
    
    cellW = (xmax - xmin) / COLUMNS;
    cellH = (ymax - ymin) / ROWS;
    
    // build the cells
    cells = new MazeCell[ROWS * COLUMNS];
  
    int x, y, i = 0;
    for (y = 0; y < ROWS; ++y) {
      for (x = 0; x < COLUMNS; ++x) {
        cells[i] = new MazeCell();
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
          walls[i] = new MazeWall();
          walls[i].removed = false;
          walls[i].cellA = y * COLUMNS + x;
          walls[i].cellB = y * COLUMNS + x + 1;
          calculateWallEnds(i);
          ++i;
        }
        if (y < ROWS - 1) {
          // horizontal wall between vertical cells
          walls[i] = new MazeWall();
          walls[i].removed = false;
          walls[i].cellA = y * COLUMNS + x;
          walls[i].cellB = y * COLUMNS + x + COLUMNS;
          calculateWallEnds(i);
          ++i;
        }
      }
    }
    
    buildOutsideWalls();
  }
  
  void buildOutsideWalls() {
    outsideWalls = new MazeWall[4];
    for(int i=0;i<4;++i) {
      outsideWalls[i] = new MazeWall();
    }
    outsideWalls[0].x1=0;
    outsideWalls[0].y1=0;
    outsideWalls[0].x2=xmax;
    outsideWalls[0].y2=0;

    outsideWalls[1].x1=xmax;
    outsideWalls[1].y1=0;
    outsideWalls[1].x2=xmax;
    outsideWalls[1].y2=ymax;

    outsideWalls[2].x1=xmax;
    outsideWalls[2].y1=ymax;
    outsideWalls[2].x2=0;
    outsideWalls[2].y2=ymax;

    outsideWalls[3].x1=0;
    outsideWalls[3].y1=ymax;
    outsideWalls[3].x2=0;
    outsideWalls[3].y2=0;
    
    print("maze x max=");    println(xmax);
    print("maze y max=");    println(ymax);
  }

  void removeAllWalls() {
    int i;
    for(i=0;i<walls.length;++i) {
      walls[i].removed = true;
    }
  }
  
  
  void calculateWallEnds(int i) {
    int a = walls[i].cellA;
    int b = walls[i].cellB;
    int ax = cells[a].x;
    int ay = cells[a].y;
    int bx = cells[b].x;
    int by = cells[b].y;
    
    if (ay == by) {
      // vertical wall
      float x1 = xmin + (ax + 1) * cellW;
      float y0 = ymin + (ay + 0) * cellH;
      float y1 = ymin + (ay + 1) * cellH;
      walls[i].x1 = x1;
      walls[i].x2 = x1;
      walls[i].y1 = y0;
      walls[i].y2 = y1;
    } else if (ax == bx) {
      // horizontal wall
      float x0 = xmin + (ax + 0) * cellW;
      float x1 = xmin + (ax + 1) * cellW;
      float y1 = ymin + (ay + 1) * cellH;
      walls[i].x1 = x0;
      walls[i].x2 = x1;
      walls[i].y1 = y1;
      walls[i].y2 = y1;
    }
  }
  
  void generateRandomMaze() {
    int unvisitedCells = cells.length; // -1 for initial cell.
    int cellsOnStack = 0;
  
    // Make the initial cell the current cell and mark it as visited
    int currentCell = cells.length-1;
    cells[0].visited = true;
    walls[0].removed = true;
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
        for (int i = 0; i < cells.length; ++i) {
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
  
    int i;
    for(i=0;i<cells.length;++i) {
      cells[i].visited=false;
    }
    
    // remove the walls between the four center squares
    int x = (COLUMNS/2)-1;
    int y = (ROWS/2)-1;
    currentCell = y * COLUMNS + x;
    
    wallIndex = findWallBetween(currentCell        , currentCell+1        );  walls[wallIndex].removed = true;
    wallIndex = findWallBetween(currentCell        , currentCell+COLUMNS  );  walls[wallIndex].removed = true;
    wallIndex = findWallBetween(currentCell+COLUMNS, currentCell+COLUMNS+1);  walls[wallIndex].removed = true;
    wallIndex = findWallBetween(currentCell+1      , currentCell+COLUMNS+1);  walls[wallIndex].removed = true;
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
    if (x < COLUMNS - 1 && !cells[currentCell + 1].visited) {
      candidates[found++] = currentCell + 1;
    }
    // up
    if (y > 0 && !cells[currentCell - COLUMNS].visited) {
      candidates[found++] = currentCell - COLUMNS;
    }
    // down
    if (y < ROWS - 1 && !cells[currentCell + COLUMNS].visited) {
      candidates[found++] = currentCell + COLUMNS;
    }
  
    if (found == 0)
      return -1;
  
    // choose a random candidate
    int choice = (int) (Math.random() * found);
    assert (choice >= 0 && choice < found);
  
    return candidates[choice];
  }
  
  
  void drawMaze() {
    strokeWeight(WALL_THICKNESS);
    
    // Draw outside edge
    line(xmin, ymax, xmax, ymax);
    line(xmin, ymin, xmax, ymin);
    line(xmax, ymin, xmax, ymax);
    line(xmin, ymin, xmin, ymax);
 
    int i;
    for (i = 0; i < walls.length; ++i) {
      if (walls[i].removed)
        continue;
      line(walls[i].x1,
           walls[i].y1,
           walls[i].x2,
           walls[i].y2);
    }
    strokeWeight(1);
    
    noStroke();
    fill(255,255,255,64);
    for(i=0;i<cells.length;++i) {
      if(cells[i].visited) continue;
      
      float ax = cells[i].x * cellW;
      float ay = cells[i].y * cellH;
      rect(ax,ay,cellW,cellH);  
    }
    
    // draw compass
    textAlign(CENTER, CENTER);
    fill(255,255,0);
    text("N", width - cellW/2, height/2        );
    text("E", width/2        , height - cellH/2);
    text("W", width/2        , cellH/2         );
    text("S", cellW/2        , height/2        );
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


  // convert grid (x,y) to cell index number.
  int getCellNumberAt(int x,int y) {
    return y * COLUMNS + x;
  }
  
  int getCellNumberAt(float px,float py) {
    int x = floor(px / cellW);
    int y = floor(py / cellH);
    return getCellNumberAt(x,y);
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
}