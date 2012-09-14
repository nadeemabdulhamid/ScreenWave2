	// constants
static float SPRING_CONSTANT = 0.17; // 0.2; // 0.1;
static float DAMPING = 0.9; // .75; // 0.98;



class Bouncy {

  // unchanging attributes
  float restx, resty;    // the natural resting position of this body
  int size = 20;
  float mass;
  color col;

  // changing attributes during execution
  float curx, cury;
  float velx, vely;
  
  // has this bouncy been pushed most recently by a pusher?
  //boolean pushed;

  Bouncy(float x, float y, int size, float mass, color col) {
    this.size = size;
    this.restx = this.curx = x;
    this.resty = this.cury = y;
    this.mass = mass;
    this.velx = 0;
    this.vely = 0;
    this.col = col;
  }

  void reset() {
     curx = restx;
     cury = resty;
     velx = vely = 0; 
  }


  void update() 
  { 
      float force = -SPRING_CONSTANT * (cury - resty);  // f=-ky 
      float accel = force / mass;                 // Set the acceleration, f=ma == a=f/m 
      vely = DAMPING * (vely + accel);         // Set the velocity 
      cury += vely;                            // Updated position 

      force = -SPRING_CONSTANT * (curx - restx);  // f=-ky 
      accel = force / mass;                 // Set the acceleration, f=ma == a=f/m 
      velx = DAMPING * (velx + accel);       // Set the velocity 
      curx += velx;                          // Updated position
      
      //pushed = false;
  }



  void display(PGraphics offscreen) 
  { 
    //println("drawing " + size);
    offscreen.fill(this.col);
    if (size < 2) 
      offscreen.point(curx, cury);
    else 
      offscreen.ellipse(curx, cury, size, size); 
  }
}

