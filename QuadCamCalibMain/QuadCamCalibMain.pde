/*
 Allows cropping of input camera image to an arbitrary quadrilateral;
 writes the coordinates of the crop box to a file, camcrop.txt
 */

import codeanticode.gsvideo.*;

GSCapture cam;

QuadCamCalib cc = new QuadCamCalib();

boolean mirror = false;

void setup() {
  size(640, 480, P2D);
  
  cam = new GSCapture(this, 800, 600);
  cam.start();    
}


void draw() {
	noFill();
	stroke(255);
	strokeWeight(3);
  if (cam.available() == true) {
    cam.read();
    
    if (mirror) {
    	pushMatrix();
    	scale(-1, 1);
    	translate(-this.width, 0);
    }
    image(cam, 0, 0);
    if (mirror) {
    	popMatrix();
    }
    
		switch (cc.numValid) {
			case 0:
				ellipse(mouseX, mouseY, 10, 10);
				text("Select top-left", 50, 50);
				break;
			case 1:
				line(cc.points[0][0], cc.points[0][1], mouseX, mouseY);
				ellipse(mouseX, mouseY, 10, 10);
				text("Select top-right", 50, 50);
				break;
			case 2:
				line(cc.points[0][0], cc.points[0][1], cc.points[1][0], cc.points[1][1]);
				line(cc.points[1][0], cc.points[1][1], mouseX, mouseY);
				ellipse(mouseX, mouseY, 10, 10);
				text("Select bottom-right", 50, 50);
				break;
		case 3:
				line(cc.points[0][0], cc.points[0][1], cc.points[1][0], cc.points[1][1]);
				line(cc.points[1][0], cc.points[1][1], cc.points[2][0], cc.points[2][1]);
				line(cc.points[2][0], cc.points[2][1], mouseX, mouseY);
				line(cc.points[0][0], cc.points[0][1], mouseX, mouseY);
				ellipse(mouseX, mouseY, 10, 10);
				text("Select bottom-left", 50, 50);
				break;
			case 4:
				cc.setTarget(640, 480);
				PGraphics off = createGraphics(800, 600, P2D);
				off.beginDraw();
				if (mirror) {
					off.scale(-1, 1);
					off.translate(-800, 0);
				}
				off.image(cam, 0, 0);
				off.endDraw();
				image(cc.toTarget(off), 0, 0);
				break;
		}
  }
}


void keyPressed() {
	switch (keyCode) {
		case 'C':
			cc.clearPoints();
			break;
		case 'M':
			mirror = !mirror;
			break;
		case 'W':
			if (cc.isComplete()) {
				cc.writeFile("camcalib.txt");
			}
			break;
		case 'R':
			cc.loadFile("camcalib.txt");
			break;
	}
}


void mouseClicked() {
	cc.addPoint(mouseX, mouseY);
}