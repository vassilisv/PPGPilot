using Toybox.WatchUi;
using Toybox.ActivityRecording;
using Toybox.FitContributor;

class PPGPilotDelegate extends WatchUi.BehaviorDelegate {
	var views;
    var pilot;
    var currentViewIdx = 0;
    var canPopView = false;

    function initialize(views, pilot) {
        BehaviorDelegate.initialize();
        self.views = views;
        self.pilot = pilot;
    }

    function onSelect() {
		pilot.startSession();
		return true;   
    }
    
    function onNextPage() {
    	if (views.size() > 1) {
    		// Pop previous view (if one)
    		if (canPopView) {
    			WatchUi.popView(WatchUi.SLIDE_UP);
    		}
    		// Cycle to next view
    		currentViewIdx = (currentViewIdx+1)%views.size();
    		WatchUi.pushView(views[currentViewIdx], self, WatchUi.SLIDE_UP);
    		canPopView = true;
    	}		
    	return true;
    }
    
    function onPreviousPage() {
		return onNextPage();
    }
    
    function onBack() {
    	WatchUi.popView(WatchUi.SLIDE_UP);
    	canPopView = false;
    	currentViewIdx = currentViewIdx - 1;
	}
    
}