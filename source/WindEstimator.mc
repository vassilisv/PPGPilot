using Toybox.Math;
using Toybox.System;

class WindEstimator {
	var numPolarBins;
	var filterLength;
	var polarBins;
	var degreesPerPolarBin;

	class PolarBin {
		const INIT_SPEED = 9.4f; // 21 mph
		const MIN_SPEED = 1.56f; // 3.5 mph
		var speeds;
		var speedIndex;
		var centerAngleRad;
		var filterLength;
		var degreesPerPolarBin;
		var x;
		var y;
		
		function initialize(centerAngle, filterLength) {
			centerAngleRad = -Math.toRadians(centerAngle)+Math.PI/2; // convert from compass angle to coordinate angle
			self.filterLength = filterLength;
			speeds = new [filterLength];
			speedIndex = 0;
			for (var i = 0; i < filterLength; ++i) {
				speeds[i] = INIT_SPEED;
			}
			update(INIT_SPEED);
		}
		
		function mean() {
			var sum = 0;
			for (var i = 0; i < filterLength; ++i) {
				sum += speeds[i];
			}
			return sum / filterLength;
		}
		
		function update(speed) {
			// If speed too low then ignore it, estimation not accurate with too small values
			if (speed < MIN_SPEED) {
				return;
			}
			// Add speed to buffer
			speeds[speedIndex] = speed;
			speedIndex = (speedIndex + 1) % filterLength;
			// Update x, y components
			var mag = mean(); 
			x = mag * Math.cos(centerAngleRad);
			y = mag * Math.sin(centerAngleRad);
			// Debug
			//System.println("Bin update, angle: " + Math.toDegrees(centerAngleRad) + ", mag: " + mag);
		}
	}
			
	function initialize(numPolarBins, filterLength) {
		// Setup polar bins
		self.numPolarBins = numPolarBins;
		self.filterLength = filterLength;
		self.degreesPerPolarBin = 360.0f / numPolarBins;
		self.polarBins = new [numPolarBins];
		for (var i = 0; i < numPolarBins; ++i) {
			var binAngleCenter = i * self.degreesPerPolarBin + self.degreesPerPolarBin/2;
			self.polarBins[i] = new PolarBin(binAngleCenter, filterLength);
		}
	}
	
	function update(groundSpeed, heading) {
		// Convert heading to possitive number
		var headingPos = (heading + 360).toNumber() % 360;
		// Figure out which bin this update is for
		var polarBinIndex = Math.floor(headingPos / self.degreesPerPolarBin).toNumber() % self.numPolarBins;
		// Update bin
		self.polarBins[polarBinIndex].update(groundSpeed);
		try {
			// Fit best circle
			var xyR = fitCircle();
			// Calculate wind speed and direction from circle center
			var windSpeed = Math.sqrt(xyR[0]*xyR[0] + xyR[1]*xyR[1]);
			var windDirection = Math.toDegrees(-Math.atan2(xyR[1], xyR[0])+1.5*Math.PI); // from coordinate angle to compass angle, also rotate by 180deg
			var airSpeed = xyR[2];
			return [windSpeed, windDirection, airSpeed];
		} catch (ex) {
			System.print("ERROR: Wind update failed with: " + ex);
			return [null, null, null];
		}			
	}
	
	// Fit best circle given points using the TaubinNewton method
	function fitCircle() {
        var nPoints = numPolarBins;
        if (nPoints < 3) {
        	System.println("ERROR: need a minimum of three points to fit circle!");
            return [0, 0, 0];
        }
        var centroid = getCentroid();
        var Mxx = 0, Myy = 0, Mxy = 0, Mxz = 0, Myz = 0, Mzz = 0;
        for (var i = 0; i < nPoints; i++) {
            var Xi = polarBins[i].x - centroid[0];
            var Yi = polarBins[i].y - centroid[1];
            var Zi = Xi * Xi + Yi * Yi;
            Mxy += Xi * Yi;
            Mxx += Xi * Xi;
            Myy += Yi * Yi;
            Mxz += Xi * Zi;
            Myz += Yi * Zi;
            Mzz += Zi * Zi;

        }
        Mxx /= nPoints;
        Myy /= nPoints;
        Mxy /= nPoints;
        Mxz /= nPoints;
        Myz /= nPoints;
        Mzz /= nPoints;

        var Mz = Mxx + Myy;
        var Cov_xy = Mxx * Myy - Mxy * Mxy;
        var A3 = 4 * Mz;
        var A2 = -3 * Mz * Mz - Mzz;
        var A1 = Mzz * Mz + 4 * Cov_xy * Mz - Mxz * Mxz - Myz * Myz - Mz
                * Mz * Mz;
        var A0 = Mxz * Mxz * Myy + Myz * Myz * Mxx - Mzz * Cov_xy - 2 * Mxz
                * Myz * Mxy + Mz * Mz * Cov_xy;
        var A22 = A2 + A2;
        var A33 = A3 + A3 + A3;

        var xnew = 0;
        var ynew = 1e+20;
        var epsilon = 1e-12;
        var iterMax = 20; // was 20

        for (var iter = 0; iter < iterMax; iter++) {
            var yold = ynew;
            ynew = A0 + xnew * (A1 + xnew * (A2 + xnew * A3));
            if (abs(ynew) > abs(yold)) {
                System.println("WARNING: Newton-Taubin goes wrong direction: |ynew| > |yold|");
                xnew = 0;
                break;
            }
            var Dy = A1 + xnew * (A22 + xnew * A33);
            var xold = xnew;
            xnew = xold - ynew / Dy;
            if (abs((xnew - xold) / xnew) < epsilon) {
                break;
            }
            if (iter >= iterMax) {
                System.println("Newton-Taubin will not converge");
                xnew = 0;
            }
            if (xnew < 0) {
                System.println("Newton-Taubin negative root: x = " + xnew);
                xnew = 0;
            }
        }
        var centreRadius = new [3];
        var det = xnew * xnew - xnew * Mz + Cov_xy;
        var x = (Mxz * (Myy - xnew) - Myz * Mxy) / (det * 2);
        var y = (Myz * (Mxx - xnew) - Mxz * Mxy) / (det * 2);
        centreRadius[0] = x + centroid[0];
        centreRadius[1] = y + centroid[1];
        centreRadius[2] = Math.sqrt(x * x + y * y + Mz);

        return centreRadius;		
	}
	
	function getCentroid() {
        var centroid = new [2];
        var sumX = 0;
        var sumY = 0;
        for (var n = 0; n < numPolarBins; n++) {
            sumX += polarBins[n].x;
            sumY += polarBins[n].y;
        }
        centroid[0] = sumX / numPolarBins;
        centroid[1] = sumY / numPolarBins;
        return centroid;
    }
	
	function abs(value) {
		if (value < 0) {
			return -value;
		} else {
			return value;
		}
	}
	
}
	
	