using Toybox.WatchUi;
using Toybox.ActivityRecording;
using Toybox.FitContributor;

class PPGPilotDelegate extends WatchUi.BehaviorDelegate {
    var parentView;

    function initialize(view) {
        BehaviorDelegate.initialize();
        parentView = view;
    }

    function onSelect() {
		parentView.pilot.startSession();
		return true;   
    }
}