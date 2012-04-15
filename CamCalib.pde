
/* represents calibration settings for cropping a camera image to a rectangle */
public class CamCalib {
	int x;
	int y;
	int w;
	int h;

	public CamCalib(int x, int y, int w, int h) {
		this.x = x;
		this.y = y;
		this.w = w;
		this.h = h;
	}
	
	/* loads data from file */
	public CamCalib(String filename) {
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

}