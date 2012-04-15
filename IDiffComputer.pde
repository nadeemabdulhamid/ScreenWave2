
public interface IDiffComputer {
	/* returns the diffs given the next frame of input */
	public boolean[] nextFrame(int[] pixels);
	
	public int lastDiffCount();
}



/* diff computer based on frame differencing */
class FDDiffComputer implements IDiffComputer {
	int width;
	int height;
	int numPixels;
	int[] previousFrame;
	boolean[] diffs;
	int lastDiffCount;
	
	float tolerance;   // color distance difference threshold [0...255^3]
	float avgWeight;   // weight to accord the current frame in the average with the previous
										 // [0.0 .. 1.0]
	
	public FDDiffComputer(int w, int h, float tol, float avgwgt) {
		this.width = w;
		this.height = h;
		this.numPixels = width * height;
		this.tolerance = tol;
		this.avgWeight = avgwgt;
		this.previousFrame = null; /* initialized on first frame */
		this.diffs = null;
		this.lastDiffCount = 0;
	}


	public boolean[] nextFrame(int[] pixels) {
		if (previousFrame == null) {   // copy in the first frame
			previousFrame = new int[width * height];
			diffs = new boolean[width * height];  // all false
			for (int i = 0; i < pixels.length; i++) {
				previousFrame[i] = pixels[i];
			}
			return diffs;   // that's it
		} 
		
		// otherwise, do frame differencing...
		lastDiffCount = 0;
    for (int i = 0; i < numPixels; i++) { // For each pixel in the video frame...
      color currColor = pixels[i];
      color prevColor = previousFrame[i];
      
      // Extract the red, green, and blue components from current pixel
      int currR = (currColor >> 16) & 0xFF; // Like red(), but faster
      int currG = (currColor >> 8) & 0xFF;
      int currB = currColor & 0xFF;
      // Extract red, green, and blue components from previous pixel
      int prevR = (prevColor >> 16) & 0xFF;
      int prevG = (prevColor >> 8) & 0xFF;
      int prevB = prevColor & 0xFF;
      
      /*
      // Compute the difference of the red, green, and blue values
      int diffR = abs(currR - prevR);
      int diffG = abs(currG - prevG);
      int diffB = abs(currB - prevB);
      
      // Add these differences to the running tally
      movementSum += diffR + diffG + diffB;
      // Render the difference image to the screen
      //pixels[i] = color(diffR, diffG, diffB);
      // The following line is much faster, but more confusing to read
      //pixels[i] = 0xff000000 | (diffR << 16) | (diffG << 8) | diffB;
      */
      
			diffs[i] = dist(currR, currG, currB, prevR, prevG, prevB) > this.tolerance;
			if (diffs[i]) lastDiffCount++;
      
      // Save the current color into the 'previous' buffer
      int nextR = (int)(prevR * (1-this.avgWeight) + currR * this.avgWeight);
      int nextG = (int)(prevG * (1-this.avgWeight) + currG * this.avgWeight);
      int nextB = (int)(prevB * (1-this.avgWeight) + currB * this.avgWeight);
      previousFrame[i] = color(nextR, nextG, nextB);
    }		
		
		return diffs;
		
	}

	public int lastDiffCount() { return lastDiffCount; }

}