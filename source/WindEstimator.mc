using Toybox.Math;
using Toybox.System;

class WindEstimator {
	var numPolarBins;
	var filterLength;
	var degreesPerPolarBin;
	var polarBinFilters;
	var polarBinFilterIndex;

	function initialize(numPolarBins, filterLength) {
		// Setup polar bins
		self.numPolarBins = numPolarBins;
		self.filterLength = filterLength;
		self.degreesPerPolarBin = 360.0f / numPolarBins;
		self.polarBinFilters = new [numPolarBins];
		self.polarBinFilterIndex = new [numPolarBins];
		for (var i = 0; i < numPolarBins; ++i) {
			self.polarBinFilters[i] = new [filterLength];
			for (var n = 0; n < filterLength; ++n) {
				self.polarBinFilters[i][n] = 0f;
			}
			self.polarBinFilterIndex[i] = 0;
		}
	}
	
	function update(groundSpeed, heading) {
		// Convert heading to possitive number
		var headingPos = (heading + 360).toNumber() % 360;
		// Figure out which bin this update is for
		var polarBinIndex = Math.floor(headingPos / self.degreesPerPolarBin).toNumber() % self.numPolarBins;
		// Inster update
		System.println("PB: " + polarBinIndex);
		System.println("PFI: " + polarBinFilterIndex[polarBinIndex]);
		self.polarBinFilters[polarBinIndex][polarBinFilterIndex[polarBinIndex]] = groundSpeed;
		polarBinFilterIndex[polarBinIndex] = (polarBinFilterIndex[polarBinIndex] + 1) % self.filterLength;
		// Calculate sum of vectors
		var xSum = 0f;
		var ySum = 0f;
		for (var i = 0; i < self.numPolarBins; ++i) { 
			var polarBinAngleRad = Math.toRadians(i * self.degreesPerPolarBin + self.degreesPerPolarBin/2);
			var polarBinSpeed = mean(self.polarBinFilters[i], self.filterLength);
			System.println("Angle/Speed: " + Math.toDegrees(polarBinAngleRad) + " / " + polarBinSpeed);
			xSum = xSum + polarBinSpeed * Math.sin(polarBinAngleRad);
			ySum = ySum + polarBinSpeed * Math.cos(polarBinAngleRad);
		}
		var xWind = xSum;
		var yWind = ySum;
		var windSpeed = Math.sqrt(xWind*xWind + yWind*yWind) / 2;
		var windDirectionDeg = Math.toDegrees(Math.atan2(xWind, yWind));
		return [windSpeed, windDirectionDeg];			
	}
	
	function mean(data, length) {
		var sum = 0;
		for (var i = 0; i < length; ++i) {
			sum += data[i];
		}
		return sum / length;
	}
	
}
	
	