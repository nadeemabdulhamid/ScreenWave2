
import codeanticode.gsvideo.*;
import java.io.*;

String IMAGE_PATH_PREFIX = "images";
String[] IMAGES; /* = { "vikinghead.jpg", "vikinglogo.jpg", "firsthand.jpg",
                    "fordgarden.jpg" , "shapes.png"  }; */
Frame[] FRAMES;                    
int currentImage;  // index
PImage backpic;


int IMAGE_SCALE = 100;  // percent of display size to scale image


GSCapture video;        // camera
final int VIDEO_WIDTH = 800;
final int VIDEO_HEIGHT = 600;
final int VIDEO_FPS = 30;   // frames/second

PImage cameraImage;            // current image from camera

ICamCalib cc;

PGraphics offscreen;    // double-buffering
final int SCR_WIDTH = 1024; //1600; //1024;
final int SCR_HEIGHT = 768; //1000; //768;

final color BACKGROUND_COLOR = color(255);
final color TRANSPARENT_COLOR = color(255, 0);
final color DIFF_COLOR = color(51);

PImage diffImage;       // image from calibration of camera image, to be used for frame difference computing
IDiffComputer dc;    // frame difference computer
boolean[] diffs;

final int DIFF_WIDTH = 640;   // width of the image to which video should be scaled to compute diffs
final int DIFF_HEIGHT = 480;  // height ...    (see VID_WIDTH/HEIGHT above)

final int MIN_DIFF_COUNT = 100;
final float DIFF_TOLERANCE = 55;
final float DIFF_FRAME_WEIGHT = 0.9;  // weight value to use averaging current frame with previous for differencing
final int MIN_NBRS = 4;  // min neighboring diffs to be true to generate a pusher


long ADVANCE_DELAY = 5000;  // msec
long lastAdvance = 0;



/* options */
boolean autoAdvance = true;    // 'A'
boolean generatePushers = true;
boolean mirrorVideo = true;
boolean showBack = false;
boolean showBouncies = true;
boolean showCameraImage = false;
boolean showDiff = false;       // 'D'
boolean showFrames = false;
boolean showPushers = false;
boolean smoothDraw = false;


/* pushers and bouncies */
int[] pushers;  /* array of indices of pushers - max # is DIFF_WIDTH * DIFF_HEIGHT */
int numPushers;    /* note: corresponds to screen area */

//final int PUSHER_SIZE_HI = SCR_HEIGHT / 7;  // bigger pushers when high amount of diffs
//final int PUSHER_SIZE_LO = SCR_HEIGHT / 10;
final int PUSHER_SIZE = SCR_HEIGHT / 9;
final float PUSHER_SEP = PUSHER_SIZE * .3;
final int MAX_PUSHER_IN_ROW = (int)(SCR_HEIGHT / PUSHER_SEP) + 3;

Bouncy[] bouncies;

final int BOUNCY_GRANULARITY = 3;  // determines how much to slice up a picture to create initial bouncies
final float BOUNCY_SIZE_FACTOR = 1.5;

import processing.video.*;

void setup() {
        IMAGES = getImageNames(dataPath(IMAGE_PATH_PREFIX));
        for (String n : IMAGES) {
          println("found image file: " + n);
        }
  
	size(SCR_WIDTH, SCR_HEIGHT, P2D);
	frameRate(45);
	
	println(Capture.list());
	video = new GSCapture(this, VIDEO_WIDTH, VIDEO_HEIGHT, /*"Sony HD Eye for PS3 (SLEH 00201):0",*/ VIDEO_FPS);
	video.start();
	cameraImage = createImage(VIDEO_WIDTH, VIDEO_HEIGHT, RGB);
	
	if (fileExists("camcalib.txt")) {
		cc = new QuadCamCalib();
		cc.loadFile("camcalib.txt");
	}
	else {
		cc = new RectCamCalib(0, 0, VIDEO_WIDTH, VIDEO_HEIGHT);
	}
	cc.setTarget(DIFF_WIDTH, DIFF_HEIGHT);
	
	offscreen = createGraphics(SCR_WIDTH, SCR_HEIGHT, P2D);
	offscreen.loadPixels();
	
	dc = new FDDiffComputer(DIFF_WIDTH, DIFF_HEIGHT, DIFF_TOLERANCE, DIFF_FRAME_WEIGHT);

	pushers = new int[DIFF_WIDTH * DIFF_HEIGHT];
	numPushers = 0;
	
        FRAMES = new Frame[IMAGES.length];
        backpic = fadeImage(loadAndScaleImage(IMAGES[currentImage], SCR_WIDTH, SCR_HEIGHT, BACKGROUND_COLOR), 3);
        bouncies = loadBouncyImage(IMAGES[currentImage], SCR_WIDTH, SCR_HEIGHT, 
                              BOUNCY_GRANULARITY, BACKGROUND_COLOR, 10);
	
	loadPixels();
        lastAdvance = millis();
}


void draw() {
	//if (video.available()) { handleVideo(video); }
	//else { diffs = null; }
        if (autoAdvance  &&  millis() - lastAdvance > ADVANCE_DELAY) {
           loadNext(); 
        }

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
		cc.drawCalibLines(offscreen);
		//offscreen.text("hi", 10, 10);
	}

	offscreen.endDraw();
	image(offscreen, 0, 0);

	if (showFrames) {
		fill(0);
		text("Frame rate: " + frameRate, 50, 50);
	}
}



final int[] OFFSETS = { -DIFF_WIDTH, +DIFF_WIDTH, -1, +1, 
										-DIFF_WIDTH-1, -DIFF_WIDTH+1, DIFF_WIDTH-1, DIFF_WIDTH+1 };
										
void createPushers() {
	float hscale = SCR_WIDTH / (float)DIFF_WIDTH;
	float vscale = SCR_HEIGHT / (float)DIFF_HEIGHT;
	int i, x, y, o, nbrs;
	int px, py, j, qx, qy;
	boolean makeNew;
	
	numPushers = 0;
	
	//long start = millis();
	
	int xlim = DIFF_WIDTH-1;
	int ylim = DIFF_HEIGHT-1;
	for (x = 1; x < xlim; x++) {
		for (y = 1; y < ylim; y++) {
			i = y * DIFF_WIDTH + x;   // source (diffs) pixel index
			if (!diffs[i]) continue; // not a diff
			
			nbrs = 0;
			for (o = 0; o < OFFSETS.length /*&& nbrs < MIN_NBRS*/; o++) {
				if (diffs[i + OFFSETS[o]]) nbrs++;
			} // end: count number of nbrs of diffs[x, y]
			
			if (nbrs >= MIN_NBRS) {
				for (o = 0; o < OFFSETS.length; o++) {
					diffs[i+OFFSETS[o]] = false; // clear out nbrs!!!
				}
				
				px = (int)(x * hscale);
				py = (int)(y * vscale);
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
	float hscale = SCR_WIDTH / (float) DIFF_WIDTH;
	float vscale = SCR_HEIGHT / (float) DIFF_HEIGHT;
	int i, dx, dy, j;

	// global now... PImage diffImage = cc.toTarget(cameraImage);
  //   diffImage.loadPixels();
	
	for (int x = 0; x < DIFF_WIDTH; x++) {
		for (int y = 0; y < DIFF_HEIGHT; y++) {
			i = y * DIFF_WIDTH + x;  // source (diffs) pixel index
			if (diffs[i]) {
				offscreen.fill(diffImage.pixels[i]);
				offscreen.ellipse(x*hscale, y*vscale, ceil(hscale*2), ceil(vscale*2));
				//j = ((int)(y * vscale)) * SCR_WIDTH + (int)(x * hscale);
				//offscreen.pixels[j] = diffImage.pixels[i]; //DIFF_COLOR;
			} 
		}
	}
	
	offscreen.updatePixels();
}


/* 
   stores the background picture and bouncy positions for a given frame of the interaction
   this is for caching the loaded images
*/ 
class Frame {
  PImage backpic;
  Bouncy[] bouncies;
  
  public Frame(String imageFileName) {
    backpic = fadeImage(loadAndScaleImage(IMAGES[currentImage], SCR_WIDTH, SCR_HEIGHT, BACKGROUND_COLOR), 3);
    bouncies = loadBouncyImage(IMAGES[currentImage], SCR_WIDTH, SCR_HEIGHT, 
						BOUNCY_GRANULARITY, BACKGROUND_COLOR, 10);
  }
  
}



// for 'N' key or autoAdvance
void loadNext() {
  currentImage = (currentImage + 1) % IMAGES.length;
  
  if (FRAMES[currentImage] == null) {
     FRAMES[currentImage] = new Frame(IMAGES[currentImage]);
  }
  Frame fcur = FRAMES[currentImage];  // should be valid at this point
  
  backpic = fcur.backpic; 
  bouncies = fcur.bouncies;
  for (int i = 0; i < bouncies.length; i++) {
     bouncies[i].reset(); 
  }
  /* fadeImage(loadAndScaleImage(IMAGES[currentImage], SCR_WIDTH, SCR_HEIGHT, BACKGROUND_COLOR), 3);
  bouncies = loadBouncyImage(IMAGES[currentImage], SCR_WIDTH, SCR_HEIGHT, 
						BOUNCY_GRANULARITY, BACKGROUND_COLOR, 10);
  */
  
  lastAdvance = millis();
}


void keyPressed() {
	switch (keyCode) {
                case 'A': autoAdvance = !autoAdvance; break;
		case 'B': showBack = !showBack; break;
		case 'C': showCameraImage = !showCameraImage; break;
		case 'D': showDiff = !showDiff; break;
		case 'F': showFrames = !showFrames; break;
		case 'M': mirrorVideo = !mirrorVideo; break;
		case 'P': showPushers = !showPushers; break;
		case 'R': dc = new FDDiffComputer(DIFF_WIDTH, DIFF_HEIGHT, DIFF_TOLERANCE, DIFF_FRAME_WEIGHT);
						  numPushers = 0;
						  break;
		case 'S': smoothDraw = !smoothDraw; break;
		case 'T': generatePushers = !generatePushers; 
							break;
		case 'X': showBouncies = !showBouncies; break;


		case 'N':
			loadNext();
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

	PImage tempCameraImage = createImage(VIDEO_WIDTH, VIDEO_HEIGHT, RGB);
	if (mirrorVideo) {
		for (int w = 0; w < VIDEO_WIDTH; w++) {
			for (int h = 0; h < VIDEO_HEIGHT; h++) {
				tempCameraImage.pixels[h*VIDEO_WIDTH + w] = video.pixels[h*VIDEO_WIDTH + (VIDEO_WIDTH - w - 1)];		
			}
		}
	} else {
		arraycopy(video.pixels, tempCameraImage.pixels);
	}
	tempCameraImage.updatePixels();
	cameraImage = tempCameraImage;   // this is so that update to cameraImage is atomic
	
	diffImage = cc.toTarget(cameraImage);
	diffImage.loadPixels();
	diffs = dc.nextFrame(diffImage.pixels);
	int count = dc.lastDiffCount();

	/*if (count > 90000) PUSHER_SIZE = PUSHER_SIZE_HI;
	else PUSHER_SIZE = PUSHER_SIZE_LO;
	PUSHER_SEP = PUSHER_SIZE * .4;*/
}



//========================================================================================//

String[] getImageNames(String path) {
    File folder = new File(path);
    FilenameFilter imgFilter = new FilenameFilter() {
      public boolean accept(File dir, String name) {
        String n = name.toLowerCase();
         return n.endsWith(".jpg") || n.endsWith(".png") || n.endsWith(".jpeg") || n.endsWith(".bmp");
      } 
    };
    
    String[] filenames = folder.list(imgFilter);
    return filenames;
}


//========================================================================================//

PImage loadAndScaleImage(String name, int width, int height, color backcolor) {
  PImage img = loadImage(dataPath(IMAGE_PATH_PREFIX + "/" + name));
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
 File file = new File(dataPath(IMAGE_PATH_PREFIX + "/" + filename));
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
