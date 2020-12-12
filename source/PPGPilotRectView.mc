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
	var titleToInfoSpacing = 0;
	var pilot; // PPGPilot instance
	var refreshTimer;
    var width; // pixels
    var height; // pixels
    var infoFontHeight; // pixels
    var titleFontHeight; // pixels
    var homeFieldLoopSize = 2;
    var homeFieldLoopIdx = 0;
    var homeFieldLoopNextUpdate = 0;

    class PixelPos {
    	var x;
    	var y;
    	function initialize(x, y) {
    		self.x = x;
    		self.y = y;
    	}
    }
    
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
			dc.drawText(pos.x,  pos.y, Graphics.FONT_SYSTEM_LARGE, pilot.notification.msg, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
			
        	// If expired delete it
        	if (pilot.notification.isExpired()) {
        		pilot.notification = null;
        	}
        }
        
    }
    
    function drawDataField(dc, x, y, width, height, title, data) {
    	dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    	drawText(dc, x, y, width, height*FIELD_TITLE_TO_DATA_RATIO, title, TEXT_FONT_SIZES);
    	drawText(dc, x, y+height*FIELD_TITLE_TO_DATA_RATIO, width, height*(1-FIELD_TITLE_TO_DATA_RATIO), data, NUMBER_FONT_SIZES);
    	dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
    	dc.setPenWidth(1);
    	dc.drawRectangle(x, y, width, height);
    }
    
    function drawText(dc, x, y, width, height, text, fonts) {
    	var fontSize = selectFontSize(dc, text, width, height, fonts);		    
    	dc.drawText(x + width/2.0, y + height/2.0, fontSize, text, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
    }
    
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
    
    function drawDirection(dc, angle, color, arrow) {
    	var startPos = polar2cart(angle, 0.7);
    	var endPos = polar2cart(angle, 1.0);
    	dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    	dc.setPenWidth(7);
    	dc.drawLine(startPos.x, startPos.y, endPos.x, endPos.y);
    	var arrowRadius = 0.07;
    	if (arrow > 0) {
    		var arrowPos = polar2cart(angle, 1.0 - arrowRadius);
    		dc.fillCircle(arrowPos.x, arrowPos.y, Math.ceil(arrowRadius*width/2));
    	} else if (arrow < 0) {
    		var arrowPos = polar2cart(angle, 0.8 + arrowRadius);
    		dc.fillCircle(arrowPos.x, arrowPos.y, Math.ceil(arrowRadius*width/2));   
    	} 	
    }

    function timerCallback() {
        WatchUi.requestUpdate();
    }

    // Called when this View is removed from the screen. Save the
    // state of your app here.
    function onHide() {
    }
	
	// Convert polar (angle in degrees, radius as a fraction of visible screen) to cartesian (x, y in pixels)
	function polar2cart(angle, radius) {
		var angleRad = Math.PI/2 - Math.toRadians(angle);
		var radiusPix = radius*height/2;
		var x = Math.round(width/2 + radiusPix * Math.cos(angleRad));
		var y = Math.round(height/2 - radiusPix * Math.sin(angleRad));
		return new PixelPos(x, y);
	}
	
	function onStop() {
		pilot.stopSession();
      	System.println("App stopped");		
	}
}
