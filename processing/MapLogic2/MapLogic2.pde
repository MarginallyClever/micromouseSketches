// Find the center of a maze, then roam back and forth along the shortest route forever.
// Dan Royer (dan@marginallyclever.com) 2016-05-21


void setup () {
  // set the window size
  size(512, 512);

  createMaze();
  setupTurtle();
}



void draw() {
  background(0);  // erase window
  drawTurtle();
  drawMaze();
}


/**
 * make one step in the current state each time a key is pressed.
 * hold the key down to go faster.
 */
void keyPressed() {
  switch(turtleState) {
  case SEARCHING: searchMaze();  break;
  case    GOHOME: goHome();      break;
  case  GOCENTER: goToCenter();  break; 
  }
}