
import codeanticode.gsvideo.*;

String[] IMAGES = { "vikinghead.jpg", "vikinglogo.jpg", "firsthand.jpg",
                    "fordgarden.jpg" /*, "shapes.png" */ };
int currentImage = 0;  // index
PImage backpic;


int IMAGE_SCALE = 100;  // percent of display size to scale image


GSCapture video;        // camera
final int VID_WIDTH = 800;
final int VID_HEIGHT = 600;
final int VID_FPS = 30;   // frames/second

PImage cameraImage;            // current image from camera

CamCalib cc;

PGraphics offscreen;    // double-buffering
final int SCR_WIDTH = 1600; //1024;
final int SCR_HEIGHT = 1000; //768;

final color BACKGROUND_COLOR = color(255);
final color TRANSPARENT_COLOR = color(255, 0);
final color DIFF_COLOR = color(51);

IDiffComputer dc;    // frame difference computer
boolean[] diffs;

final int MIN_DIFF_COUNT = 100;
final float DIFF_TOLERANCE = 55;
final float DIFF_FRAME_WEIGHT = 0.1;
final int MIN_NBRS = 5;  // min neighboring diffs to be true to generate a pusher



/* options */
boolean generatePushers = true;
boolean mirrorVideo = true;
boolean showBack = false;
boolean showBouncies = true;
boolean showCameraImage = false;
boolean showDiff = false;
boolean showFrames = true;
boolean showPushers = false;
boolean smoothDraw = false;


/* pushers and bouncies */
int[] pushers;  /* array of indices of pushers - max # is VID_WIDTH * VID_HEIGHT */
int numPushers;    /* note: corresponds to screen area */

final int PUSHER_SIZE_HI = SCR_HEIGHT / 7;  // bigger pushers when high amount of diffs
final int PUSHER_SIZE_LO = SCR_HEIGHT / 10;
      int PUSHER_SIZE = PUSHER_SIZE_LO;
      float PUSHER_SEP = PUSHER_SIZE * .4;
final int MAX_PUSHER_IN_ROW = (int)(SCR_HEIGHT / PUSHER_SEP) + 3;

Bouncy[] bouncies;

final int BOUNCY_GRANULARITY = 3;  // determines how much to slice up a picture to create initial bouncies
final float BOUNCY_SIZE_FACTOR = 1.5;



void setup() {
	size(SCR_WIDTH, SCR_HEIGHT, P2D);
	frameRate(45);
	
	video = new GSCapture(this, VID_WIDTH, VID_HEIGHT, VID_FPS);
	video.start();
	cameraImage = createImage(VID_WIDTH, VID_HEIGHT, RGB);
	
	if (fileExists("camcalib.txt")) {
		cc = new CamCalib("camcalib.txt");
	}
	else {
		cc = new CamCalib(0, 0, VID_WIDTH, VID_HEIGHT);
	}
	
	offscreen = createGraphics(SCR_WIDTH, SCR_HEIGHT, P2D);
	offscreen.loadPixels();
	
	dc = new FDDiffComputer(VID_WIDTH, VID_HEIGHT, DIFF_TOLERANCE, DIFF_FRAME_WEIGHT);

	pushers = new int[VID_WIDTH * VID_HEIGHT];
	numPushers = 0;
	
  backpic = fadeImage(loadAndScaleImage(IMAGES[currentImage], SCR_WIDTH, SCR_HEIGHT, BACKGROUND_COLOR), 3);
  bouncies = loadBouncyImage(IMAGES[currentImage], SCR_WIDTH, SCR_HEIGHT, 
                              BOUNCY_GRANULARITY, BACKGROUND_COLOR, 10);
	
	loadPixels();
}


void draw() {
	//if (video.available()) { handleVideo(video); }
	//else { diffs = null; }

	offscreen.beginDraw();
	offscreen.noStroke();
	if (smoothDraw) offscreen.smooth();  
  else offscreen.noSmooth();
  
	offscreen.background(BACKGROUND_COLOR);
	
  if (showBack && backpic != null) offscreen.image(backpic, 0, 0);
	
	if (diffs != null) {
		if (generatePushers) {
			createPushers();
			if (showPushers) {
				drawPushers();
			}
		} else {
			numPushers = 0;
		}
		if (showDiff) {
			drawDiffImage();
		}
	}	
	
	
	//long start = millis();
	int cnt = 0;
	int px, py, bi;
	float dx, dy;
	PVector v = new PVector(0,0,0);
	Bouncy b;
	for (int p = 0; p < numPushers; p++) { 
		//    pushers[p].push(bouncies);
		px = pushers[p] % SCR_WIDTH;
		py = pushers[p] / SCR_WIDTH;
		for (bi = 0; bi < bouncies.length; bi++) {
			b = bouncies[bi];
			if (abs(dx = (b.curx - px)) > PUSHER_SIZE  // a crude test to see if bouncy is even near pusher
			    || abs(dy = (b.cury - py)) > PUSHER_SIZE) continue;  // because vector ops are *slow*
			cnt++;
			v.set(b.curx - px, b.cury - py, 0);
			float mag = v.mag();
			float d = (PUSHER_SIZE + b.size)/2;
			if (mag < d) {
				v.mult( d / mag );
				b.curx = px + v.x;
				b.cury = py + v.y;
				//b.pushed = true;
			}
		}
  }
  //println("loop: " + (millis() - start) + " / cnt: " + cnt);
	
	
	for (bi = 0; bi < bouncies.length; bi++) {
	  b = bouncies[bi];
	//for (Bouncy b : bouncies) { 
    b.update(); 
    if (showBouncies) {
      offscreen.fill(b.col);
      offscreen.ellipse(b.curx, b.cury, b.size, b.size);
      //b.display(offscreen);
    }
  }

  noStroke();
  noSmooth();

	if (showCameraImage) {
		offscreen.image(cameraImage, 0, 0);
		offscreen.text("hi", 10, 10);
	}

	offscreen.endDraw();
	image(offscreen, 0, 0);

	if (showFrames) {
		fill(0);
		text("Frame rate: " + frameRate, 50, 50);
	}
}



final int[] OFFSETS = { -VID_WIDTH, +VID_WIDTH, -1, +1, 
										-VID_WIDTH-1, -VID_WIDTH+1, VID_WIDTH-1, VID_WIDTH+1 };
										
void createPushers() {
	float hscale = SCR_WIDTH / (float)cc.w;
	float vscale = SCR_HEIGHT / (float)cc.h;
	int i, x, y, o, nbrs;
	int px, py, j, qx, qy;
	boolean makeNew;
	
	numPushers = 0;
	
	//long start = millis();
	
	int xlim = cc.x+cc.w-1;
	int ylim = cc.y+cc.h-1;
	for (x = cc.x+1; x < xlim; x++) {
		for (y = cc.y+1; y < ylim; y++) {
			i = y * cc.w + x;   // source (diffs) pixel index
			if (!diffs[i]) continue; // not a diff
			
			nbrs = 0;
			for (o = 0; o < OFFSETS.length /*&& nbrs < MIN_NBRS*/; o++) {
				if (diffs[i + OFFSETS[o]]) nbrs++;
			} // end: count number of nbrs of diffs[x, y]
			
			if (nbrs >= MIN_NBRS) {
				for (o = 0; o < OFFSETS.length; o++) {
					diffs[i+OFFSETS[o]] = false; // clear out nbrs!!!
				}
				
				px = (int)((x - cc.x) * hscale);
				py = (int)((y - cc.y) * vscale);
				makeNew = true;
				for (j = 0; j < numPushers && j < MAX_PUSHER_IN_ROW; j++) {  // see if any (qx,qy) near (px,py)
					qx = pushers[numPushers-1-j] % SCR_WIDTH;
					qy = pushers[numPushers-1-j] / SCR_WIDTH;
					if (abs(qx - px) <= PUSHER_SEP && abs(qy - py) <= PUSHER_SEP) {
						makeNew = false;
						break;
					}
				}
				
				if (makeNew) {  // no pushers near (px, py)
					pushers[numPushers++] = py * SCR_WIDTH + px;
					y += PUSHER_SEP;  // skip anything in range of (px, py)   *** TODO - pusher-sep is in terms of screen, 
					//x += PUSHER_SEP/3; if (x >= cc.x + cc.w) break;  // out of the y loop
				}
			}
		}
	}
	
	if (numPushers < 10)   // avoid blips
		numPushers = 0;
	
	//println("loop: " + (millis() - start));
}


void drawPushers() {
	offscreen.stroke(1);
	for (int p = 0; p < numPushers; p++) {
		offscreen.ellipse(pushers[p]%SCR_WIDTH, pushers[p]/SCR_WIDTH, PUSHER_SIZE, PUSHER_SIZE);
	}
	offscreen.noStroke();
}


/* draws diffs onto offscreen */
void drawDiffImage() {
	float hscale = SCR_WIDTH / (float)cc.w;
	float vscale = SCR_HEIGHT / (float)cc.h;
	int i, dx, dy, j;
		
        cameraImage.loadPixels();
	for (int x = cc.x; x < cc.x+cc.w; x++) {
		for (int y = cc.y; y < cc.y+cc.h; y++) {
			i = y * VID_WIDTH + x;  // source (diffs) pixel index
			if (diffs[i]) {
				//dx = (int)((x - cc.x) * hscale);
				//dy = (int)((y - cc.y) * vscale);
				//j = dy * SCR_WIDTH + dx;
				j = ((int)((y - cc.y) * vscale)) * SCR_WIDTH + (int)((x - cc.x) * hscale);
				offscreen.pixels[j] = cameraImage.pixels[i]; //DIFF_COLOR;
			} else {
				//j = ((int)((y - cc.y) * vscale)) * SCR_WIDTH + (int)((x - cc.x) * hscale);
				//image.pixels[j] = BACKGROUND_COLOR;
			}
		}
	}
	
	offscreen.updatePixels();
}



void keyPressed() {
	switch (keyCode) {
		case 'B': showBack = !showBack; break;
		case 'C': showCameraImage = !showCameraImage; break;
		case 'D': showDiff = !showDiff; break;
		case 'F': showFrames = !showFrames; break;
		case 'M': mirrorVideo = !mirrorVideo; break;
		case 'P': showPushers = !showPushers; break;
		case 'R': dc = new FDDiffComputer(VID_WIDTH, VID_HEIGHT, DIFF_TOLERANCE, DIFF_FRAME_WEIGHT);
						  numPushers = 0;
						  break;
		case 'S': smoothDraw = !smoothDraw; break;
		case 'T': generatePushers = !generatePushers; 
							break;
		case 'X': showBouncies = !showBouncies; break;


		case 'N':
			currentImage = (currentImage + 1) % IMAGES.length;
			backpic = fadeImage(loadAndScaleImage(IMAGES[currentImage], SCR_WIDTH, SCR_HEIGHT, BACKGROUND_COLOR), 3);
			bouncies = loadBouncyImage(IMAGES[currentImage], SCR_WIDTH, SCR_HEIGHT, 
																	BOUNCY_GRANULARITY, BACKGROUND_COLOR, 10);
			//lastImageChange = millis();    
			break;
			
		// +/-  = change spring constant
		case '=':
		case '+': SPRING_CONSTANT = constrain(SPRING_CONSTANT + .01, 0.05, .3);
							println("Spring Constant: " + SPRING_CONSTANT + " / " + 
											"Damping: " + DAMPING);
							break;
		case '-': SPRING_CONSTANT = constrain(SPRING_CONSTANT - .01, 0.05, .3);
							println("Spring Constant: " + SPRING_CONSTANT + " / " + 
											"Damping: " + DAMPING);
							break;
		// change damping factor
		case '>': case '.':
							DAMPING = constrain(DAMPING + .05, .5, .98); 
							println("Spring Constant: " + SPRING_CONSTANT + " / " + 
											"Damping: " + DAMPING);
							break;
		case '<': case ',':
							DAMPING = constrain(DAMPING - .05, .5, .98); 
							println("Spring Constant: " + SPRING_CONSTANT + " / " + 
											"Damping: " + DAMPING);
							break;
	}
	
	//if (generatePushers || showDiff) video.start();
	//else video.stop();

}





void captureEvent(GSCapture video) {
	video.read();
	video.loadPixels();
	if (mirrorVideo) {
		for (int w = 0; w < VID_WIDTH; w++) {
			for (int h = 0; h < VID_HEIGHT; h++) {
				cameraImage.pixels[h*VID_WIDTH + w] = video.pixels[h*VID_WIDTH + (VID_WIDTH - w - 1)];		
			}
		}
	} else {
		arraycopy(video.pixels, cameraImage.pixels);
	}
	cameraImage.updatePixels();
	
	diffs = dc.nextFrame(cameraImage.pixels);
	int count = dc.lastDiffCount();
//	if (count < MIN_DIFF_COUNT) diffs = null;
//	else {
		if (count > 90000) PUSHER_SIZE = PUSHER_SIZE_HI;
		else PUSHER_SIZE = PUSHER_SIZE_LO;
		PUSHER_SEP = PUSHER_SIZE * .4;
		//println(count);
//	}
}






//========================================================================================//

PImage loadAndScaleImage(String name, int width, int height, color backcolor) {
  PImage img = loadImage(dataPath(name));
  // figure out the best scaling factor to fit image to
  float toscale = min( (IMAGE_SCALE/100.0)*width / (float)img.width, (IMAGE_SCALE/100.0)*height / (float)img.height );

  // create offscreen buffer the same size as window, load the image into it, scaled
  PGraphics scr = createGraphics(SCR_WIDTH, SCR_HEIGHT, P2D);
  scr.beginDraw();
  scr.background(backcolor);
  scr.pushMatrix();
  scr.scale(toscale);
  //println(toscale + ": " + img.width + ": " + (DWIDTH - toscale*img.width)/2 + " -- " + (DHEIGHT - toscale*img.height)/2);
  scr.image(img, (SCR_WIDTH - toscale*img.width)/(2*toscale), (SCR_HEIGHT - toscale*img.height)/(2*toscale));
  scr.popMatrix();
  scr.endDraw();

  return scr;
}


//========================================================================================//

Bouncy[] loadBouncyImage(String name, int width, int height, 
int granularity, color backcolor, int tolerance) {
  ArrayList<Bouncy> bs = new ArrayList<Bouncy>();

  PImage img = loadAndScaleImage(name, width, height, backcolor);

  // now go through in slices of size granularity,
  //  and create bouncies if not "close" (within tolerance) to background color
  img.loadPixels();
  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      int i = x + y*img.width;
      if ( x%granularity==0  &&  y%granularity==0 ) {
        if (colordist(img.pixels[i], backcolor) < tolerance) {
          img.pixels[i] = backcolor;
        } 
        else {
          bs.add(new Bouncy(x, y, (int)(granularity * BOUNCY_SIZE_FACTOR), 8.0, 
                             img.pixels[i])); //color(225))); //
        }
      } 
      else { 
        img.pixels[i] = color(255);
      }
    }
  }
  img.updatePixels();

  return bs.toArray(new Bouncy[0]);
}


//========================================================================================//
boolean fileExists(String filename) {
 File file = new File(dataPath(filename));
 //println(file);
 return file.exists();
}


//========================================================================================//

PImage fadeImage(PImage img, int amount) {
  img.filter(BLUR, 3);
  for (int i = 0; i < amount; i++)
    img.blend(0, 0, img.width, img.height, 0, 0, img.width, img.height, SCREEN); 
  return img;
}


//========================================================================================//

float colordist(color c1, color c2) {
  int a1 = (c1 >> 24) & 0xFF;
  int r1 = (c1 >> 16) & 0xFF;  // Faster way of getting red(argb)
  int g1 = (c1 >> 8) & 0xFF;   // Faster way of getting green(argb)
  int b1 = c1 & 0xFF;          // Faster way of getting blue(argb)  

  int a2 = (c2 >> 24) & 0xFF;
  int r2 = (c2 >> 16) & 0xFF;  // Faster way of getting red(argb)
  int g2 = (c2 >> 8) & 0xFF;   // Faster way of getting green(argb)
  int b2 = c2 & 0xFF;          // Faster way of getting blue(argb)    

  return dist(r1, g1, b1, r2, g2, b2);
}
