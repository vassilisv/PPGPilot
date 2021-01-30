using Toybox.Attention;

class Utils {
	static function attention() {
		// Play tone and vibrate
		if (Attention has :playTone) {
			Attention.playTone(Attention.TONE_LOUD_BEEP);
		}
		if (Attention has :vibrate) {
			var vibeProf = [
				new Attention.VibeProfile(100, 400),
				new Attention.VibeProfile(0, 200),
				new Attention.VibeProfile(100, 400),
			]; 
			Attention.vibrate(vibeProf);
		}
	}
}