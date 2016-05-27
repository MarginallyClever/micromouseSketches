// Find the center of a maze, then roam back and forth along the shortest route forever.
// Do it in real time, 
// Dan Royer (dan@marginallyclever.com) 2016-05-21

Maze actualMaze;
Turtle turtle;
boolean step;
boolean paused;

void setup () {
  // set the window size
  size(288, 288);  // 288 = 18x16, the number of cells by the cell size.
  frameRate(240);
  paused=false;
  step=false;

  actualMaze = new Maze();
  actualMaze.generateRandomMaze();
  turtle = new Turtle();
}


void draw() {
  if(paused && !step) return;
  step=false;
  
  background(0);  // erase window
  turtle.thinkAndAct();
  turtle.drawTurtle();
  stroke(255,255,255);
  actualMaze.drawMaze();
  stroke(255,0,0);
  turtle.mentalMaze.drawMaze();
}


void keyPressed() {
  if(key==RETURN || key==ENTER) {
    step=true;
  }
  if(key==' ') paused = !paused;
}