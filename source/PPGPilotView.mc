//
// Copyright 2015-2016 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Sensor;
using Toybox.Timer;
using Toybox.Math;

class PPGPilotView extends WatchUi.View {
    var dataTimer;
    var width;
    var height;

    function initialize() {
        View.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
    	// Setup timer
        dataTimer = new Timer.Timer();
        dataTimer.start(method(:timerCallback), 100, true);
        // Setup dims
        width = dc.getWidth();
        height = dc.getHeight();
    }

    // Restore the state of the app and prepare the view to be shown
    function onShow() {
    }

    // Update the view
    function onUpdate(dc) {
    	// Reset screen
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

		// Draw text
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2,  height / 2, Graphics.FONT_MEDIUM, "1234", Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
		
		//dc.drawText(width / 2,  height / 2, Graphics.FONT_TINY, "1234", Graphics.TEXT_JUSTIFY_CENTER);
        
    }

    function timerCallback() {
        var info = Sensor.getInfo();

        WatchUi.requestUpdate();
    }

    function kickBall()
    { 
    	System.println("Kicked!");
    }

    // Called when this View is removed from the screen. Save the
    // state of your app here.
    function onHide() {
    }
}
