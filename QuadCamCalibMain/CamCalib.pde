
interface ICamCalib {
	public void loadFile(String filename);
	public void writeFile(String filename);
	public void setTarget(int tw, int th);
	public PImage toTarget(PImage src);
	public void drawCalibLines(PGraphics src);
}


class QuadCamCalib implements ICamCalib {
	final static int maxPoints = 4;

	int[][] points;
	int numValid;
	
	int target_width;
	int target_height;
	PGraphics target = null;
	
	
	public QuadCamCalib() {
		points = new int[maxPoints][2];
		numValid = 0;
		setTarget(0, 0);
	}
	
	public void addPoint(int x, int y) {
		if (numValid < maxPoints) {
			points[numValid][0] = x;
			points[numValid][1] = y;
			numValid++;
		}
	}
	
	public void clearPoints() {
		numValid = 0;
	}
		
	public boolean isComplete() {
		return numValid == maxPoints;
	}
	
		/* loads data from file */
	public void loadFile(String filename) {
		BufferedReader reader = createReader(filename);
		try {
			for (int i = 0; i < maxPoints; i++) {
				points[i][0] = int(reader.readLine());
				points[i][1] = int(reader.readLine());
			}
			numValid = maxPoints;
		} catch (IOException e) {
   		e.printStackTrace();
  	}	
	}

	/* writes data to file */
	public void writeFile(String filename) {
		if (!isComplete()) throw new RuntimeException("calibration not complete"); 
		
		PrintWriter output = createWriter(filename);
		for (int i = 0; i < maxPoints; i++) {
			output.println(points[i][0]);
			output.println(points[i][1]);
		}
		output.flush();
		output.close();
	}
	
	public void setTarget(int tw, int th) { 
		target_width = tw; 
		target_height = th; 
		setupTargetImage();
	}
	
	private void setupTargetImage() {
		target = createGraphics(target_width, target_height, P2D);
	}

	public PImage toTarget(PImage src) {
		if (!isComplete()) throw new RuntimeException("calibration not complete"); 
		
		target.beginDraw();
		target.textureMode(IMAGE);
		target.beginShape();
		target.texture(src);
		target.vertex(0, 0, 
									points[0][0], points[0][1]);
		target.vertex(target_width-1, 0, 
									points[1][0], points[1][1]);
		target.vertex(target_width-1, target_height-1, 
									points[2][0], points[2][1]);
		target.vertex(0, target_height-1, 
									points[3][0], points[3][1]);
		target.endShape();
		target.endDraw();
		return target;
	}

	public void drawCalibLines(PGraphics src) {
		if (!isComplete()) throw new RuntimeException("calibration not complete"); 
		
		src.noFill();
		src.stroke(255);
		for (int i = 0; i < maxPoints; i++) {
		  // System.out.printf("%d: (%d, %d) ---> (%d, %d)\n", i, points[i][0], points[i][1], points[(i+1)%maxPoints][0], points[(i+1)%maxPoints][1]);
			src.line(points[i][0], points[i][1], points[(i+1)%maxPoints][0], points[(i+1)%maxPoints][1]);
		}
	}

	
}


/* represents calibration settings for cropping a camera image to a rectangle */
class RectCamCalib implements ICamCalib {
	int x;
	int y;
	int w;
	int h;
	
	int target_width;
	int target_height;
	PGraphics target = null;

	public RectCamCalib(int x, int y, int w, int h) {
		this.x = x;
		this.y = y;
		this.w = w;
		this.h = h;
		setTarget(w, h);
	}
	
	public RectCamCalib(String filename) {
		loadFile(filename);
	}
	
	/* loads data from file */
	public void loadFile(String filename) {
		BufferedReader reader = createReader(filename);
		try {
			this.x = int(reader.readLine());
			this.y = int(reader.readLine());
			this.w = int(reader.readLine());
			this.h = int(reader.readLine());
		} catch (IOException e) {
   		e.printStackTrace();
  	}	
	}

	/* writes data to file */
	public void writeFile(String filename) {
		PrintWriter output = createWriter(filename);
		output.println(this.x);
		output.println(this.y);
		output.println(this.w);
		output.println(this.h);
		output.flush();
		output.close();
	}
	
	public void setTarget(int tw, int th) { 
		target_width = tw; 
		target_height = th; 
		setupTargetImage();
	}
	
	private void setupTargetImage() {
		target = createGraphics(target_width, target_height, P2D);
	}

	public PImage toTarget(PImage src) {
		target.beginDraw();
		target.textureMode(IMAGE);
		target.beginShape();
		target.texture(src);
		target.vertex(0, 0, 
									x, y);
		target.vertex(target_width-1, 0, 
									x+w, y);
		target.vertex(target_width-1, target_height-1, 
									x+w, y+h);
		target.vertex(0, target_height-1, 
									x, y+h);
		target.endShape();
		target.endDraw();
		return target;
	}
	
	public void drawCalibLines(PGraphics src) {
		src.noFill();
		src.stroke(255);
		src.rect(x, y, w, h);
	}


}