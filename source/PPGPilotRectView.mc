using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Sensor;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Position;
using Toybox.System;
using Toybox.Time;
using Toybox.ActivityRecording;
using Toybox.FitContributor;

class PPGPilotRectView extends WatchUi.View {
	const MPS2MPH = 2.23694;
	const M2F = 3.28084;
	const M2MILE = 0.000621371;
	const HOME_FIELD_LOOP_PERIOD = 3; // sec
	const RELATIVE_DIRECTION = false;
	const NUMBER_FONT_SIZES = [Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD];
	const TEXT_FONT_SIZES = [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY];
	const FIELD_TITLE_TO_DATA_RATIO = 0.20;
	var pilot; // PPGPilot instance
	var refreshTimer;
    var width; // pixels
    var height; // pixels
    var homeFieldLoopSize = 2;
    var homeFieldLoopIdx = 0;
    var homeFieldLoopNextUpdate = 0;
    
    function initialize() {
        View.initialize();
    }

    // Load your resources here
    function onLayout(dc) { 		
        // Setup dims
        width = dc.getWidth(); 
        height = dc.getHeight();
        // Setup PPGPilot
        pilot = new PPGPilot();
    	// Setup timer
        refreshTimer = new Timer.Timer();
        refreshTimer.start(method(:timerCallback), 200, true);
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
        if (pilot.posInfo != null) {
        	var timeNow = Time.now().value();
        	        	
        	// Ground speed
        	var groundSpeed = pilot.currentGroundSpeed * MPS2MPH;
        	drawDataField(dc, 0, height-100, width/2, 90, "GSPD", groundSpeed.format("%02.1f"));

			// Altitude (baro)
        	var alt = pilot.currentAltitude * M2F;
        	drawDataField(dc, width/2, height-100, width/2, 90, "ALT", alt.format("%04d"));   
        	
        	// North heading
        	var northAngle = pilot.currentHeading;
        	if (RELATIVE_DIRECTION) {
        		northAngle = -northAngle;
        	}
        	drawDirectionField(dc, 0, height-200, width/2, 90, northAngle, Graphics.COLOR_RED);   
		}	        
        
        // Draw any notifications
        if (pilot.notification != null) {
        	// Draw it
        	dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
			dc.fillRectangle(0, 0, width, 0.35*height);
        	if (pilot.notification.warn) {
        		dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        	} else {
        		dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        	}
			var pos = polar2cart(0, 0.65);
			dc.drawText(pos[0],  pos[1], Graphics.FONT_SYSTEM_LARGE, pilot.notification.msg, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
			
        	// If expired delete it
        	if (pilot.notification.isExpired()) {
        		pilot.notification = null;
        	}
        }
        
    }
    
    // Draw a datafield
    function drawDataField(dc, x, y, width, height, title, data) {
    	dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    	drawText(dc, x, y, width, height*FIELD_TITLE_TO_DATA_RATIO, title, TEXT_FONT_SIZES);
    	drawText(dc, x, y+height*FIELD_TITLE_TO_DATA_RATIO, width, height*(1-FIELD_TITLE_TO_DATA_RATIO), data, NUMBER_FONT_SIZES);
    	dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
    	dc.setPenWidth(1);
    	dc.drawRectangle(x, y, width, height);
    }
    
    // Draw a text
    function drawText(dc, x, y, width, height, text, fonts) {
    	var fontSize = selectFontSize(dc, text, width, height, fonts);		    
    	dc.drawText(x + width/2.0, y + height/2.0, fontSize, text, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
    }
    
    // Select max font size to fit area
    function selectFontSize(dc, text, width, height, fonts) {
    	var fontSize = null;
    	for (var i = 0; i < fonts.size(); ++i) {
    		fontSize = fonts[i];
			var textDims = dc.getTextDimensions(text, fontSize);
			if (textDims[0] < width && textDims[1] < height) {
				return fontSize;
			}
		} 
		return null;
	}
	
	// Draw a field with a direction arrow
	function drawDirectionField(dc, x, y, width, height, angle, color) {
		var radius = min([width, height])/2.0;
		var centerX = x+width/2.0;
		var centerY = y+height/2.0;
		var angleRad = Math.PI/2.0 - Math.toRadians(angle);
		var pointX = Math.round(centerX + radius * Math.cos(angleRad));
		var pointY = Math.round(centerY - radius * Math.sin(angleRad));
		var tailCX = Math.round(centerX + 0.2*radius * Math.cos(angleRad + Math.PI));
		var tailCY = Math.round(centerY - 0.2*radius * Math.sin(angleRad + Math.PI));
		var tailLX = Math.round(centerX + radius * Math.cos(angleRad + 0.7*Math.PI));
		var tailLY = Math.round(centerY - radius * Math.sin(angleRad + 0.7*Math.PI));
		var tailRX = Math.round(centerX + radius * Math.cos(angleRad - 0.7*Math.PI));
		var tailRY = Math.round(centerY - radius * Math.sin(angleRad - 0.7*Math.PI));
		// Direction arrow
		dc.setColor(color, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(3);
		dc.fillPolygon([[pointX, pointY], [tailLX, tailLY], [tailCX, tailCY], [tailRX, tailRY]]);
		// Bounding box
    	dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
    	dc.setPenWidth(1);
    	dc.drawRectangle(x, y, width, height);
	}

	// Refresh screen
    function timerCallback() {
        WatchUi.requestUpdate();
    }

    // Called when this View is removed from the screen. Save the
    // state of your app here.
    function onHide() {
    }
		
	function onStop() {
		pilot.stopSession();
      	System.println("App stopped");		
	}
	
	// Get max value from array
	function min(values) {
		var minVal = 10e6;
		for (var i = 0; i < values.size(); ++i) {
			if (values[i] < minVal) {
				minVal = values[i];
			}
		}
		return minVal;
	}
	
	// Convert polar (angle in degrees, radius as a fraction of visible screen) to cartesian (x, y in pixels)
	function polar2cart(angle, radius) {
		var angleRad = Math.PI/2 - Math.toRadians(angle);
		var radiusPix = radius*height/2;
		var x = Math.round(width/2 + radiusPix * Math.cos(angleRad));
		var y = Math.round(height/2 - radiusPix * Math.sin(angleRad));
		return [x, y];
	}
	
}
