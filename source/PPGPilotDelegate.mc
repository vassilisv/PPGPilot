//
// Copyright 2016 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

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