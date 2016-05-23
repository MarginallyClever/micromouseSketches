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
  boolean removed;
}



// map details
int rows = 16;
int columns = 16;
float xmax, xmin, ymax, ymin;
float cellW,cellH;
MazeCell[] cells;
MazeWall[] walls;



/**
 * build a list of walls in the maze, cells in the maze, and how they connect to each other.
 * @param out
 * @throws IOException
 */
void createMaze() {
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
  
  wallIndex = findWallBetween(currentCell        , currentCell+1        );  walls[wallIndex].removed = true;
  wallIndex = findWallBetween(currentCell        , currentCell+columns  );  walls[wallIndex].removed = true;
  wallIndex = findWallBetween(currentCell+columns, currentCell+columns+1);  walls[wallIndex].removed = true;
  wallIndex = findWallBetween(currentCell+1      , currentCell+columns+1);  walls[wallIndex].removed = true;
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
  stroke(255,255,255);
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