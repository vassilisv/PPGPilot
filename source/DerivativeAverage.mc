using Toybox.Time;

class DerivativeAverage {
	var lastValue = null;
	var lastUpdateTime = null;
	var avrgDerivative = null;
	var derivative = 0;
	
	function initialize(filterLength) {
		avrgDerivative = new MovingAverage(filterLength, 0);
	}
	
	function update(value) {
		var timeNow = Time.now().value();
		if (lastValue != null && lastUpdateTime != null && timeNow > lastUpdateTime) {
			derivative = avrgDerivative.update((value - lastValue)/(timeNow - lastUpdateTime));
		} else {
			derivative = 0;
		}
		lastValue = value;
		lastUpdateTime = timeNow;
		return derivative;
	}
}