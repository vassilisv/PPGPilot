using Toybox.WatchUi;

class PPGPilotDelegate extends WatchUi.BehaviorDelegate {
    var parentView;

    function initialize(view) {
        BehaviorDelegate.initialize();
        parentView = view;
    }

    function onSelect() {
    }
}