class MovingAverage {
	var values;
	var valueIndex;
	var avrg;
	var filterLength;
	
	function initialize(filterLength, initValue) {
		self.filterLength = filterLength;
		values = new [filterLength];
		valueIndex = 0;
		for (var i = 0; i < filterLength; ++i) {
			values[i] = initValue;
		}
		update(initValue);
	}
	
	function mean() {
		var sum = 0;
		for (var i = 0; i < filterLength; ++i) {
			sum += values[i];
		}
		return sum / filterLength;
	}
	
	function update(value) {
		// Add value to buffer
		values[valueIndex] = value;
		valueIndex = (valueIndex + 1) % filterLength;
		// Calculate 
		avrg = mean();
		return avrg;
	}
}