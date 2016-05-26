// Find the center of a maze, then roam back and forth along the shortest route forever.
// Dan Royer (dan@marginallyclever.com) 2016-05-21

Maze actualMaze;
Turtle turtle;


void setup () {
  // set the window size
  size(288, 288);  // 288 = 18x16, the number of cells by the cell size.

  actualMaze = new Maze();
  actualMaze.generateRandomMaze();
  turtle = new Turtle();
}



void draw() {
  background(0);  // erase window
  turtle.drawTurtle();
  stroke(255,255,255);
  actualMaze.drawMaze();
  stroke(255,0,0);
  turtle.mentalMaze.drawMaze();
}


/**
 * make one step in the current state each time a key is pressed.
 * hold the key down to go faster.
 */
void keyPressed() {
  turtle.thinkAndAct();
}