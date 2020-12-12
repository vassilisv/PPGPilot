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
	const INFO_RADIUS = 0.6;
	const HOME_FIELD_LOOP_PERIOD = 3; // sec
	const RELATIVE_DIRECTION = false;
	var infoFontSize = null;
	var titleFontSize = null;
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
    	// Figure out font size
    	var titleToInfoSpacingScale;
    	if (dc.getWidth() < 240) {
    		infoFontSize = Graphics.FONT_NUMBER_HOT;
    		titleFontSize = Graphics.FONT_XTINY;
    		titleToInfoSpacingScale = 16.0; 
    	} else {
     		infoFontSize = Graphics.FONT_NUMBER_MEDIUM;
    		titleFontSize = Graphics.FONT_XTINY;
    		titleToInfoSpacingScale = 5.0; 
    	}   		
        // Setup dims
        width = dc.getWidth(); 
        height = dc.getHeight();
        infoFontHeight = dc.getFontHeight(infoFontSize);
        titleFontHeight = dc.getFontHeight(titleFontSize);
        titleToInfoSpacing = titleToInfoSpacingScale*(height/infoFontHeight);
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
        	drawInfoField(dc, 270, "GSPD", groundSpeed.format("%.1f"));

			// Altitude (baro)
        	var alt = pilot.currentAltitude * M2F;
        	drawInfoField(dc, 0, "ALT", alt.format("%d"));

			// Wind speed
        	var wSpd = pilot.windSpeed * MPS2MPH;
        	drawInfoField(dc, 90, "WSPD", wSpd.format("%.1f"));

			// Time/dist to home (TBD)
			if (homeFieldLoopIdx == 0) {
				var homeDist = pilot.homeDistance*M2MILE;
        		drawInfoField(dc, 180, "HOME", homeDist.format("%.1f"));
        	} else if (homeFieldLoopIdx == 1) {
        		if (pilot.flying) {
	        		var minsFlying = Math.round((timeNow - pilot.takeoffTime)/60);
					var minsToHome = Math.round(pilot.timeToHome / 60);
	        		drawInfoField(dc, 180, "TIME", minsFlying.format("%02d") + "/" + minsToHome.format("%02d"));
	        	} else {
	        		drawInfoField(dc, 180, "TIME", "--/--");
	        	}
        	}
        	// Advance to next field in the loop if time
        	if (timeNow >= homeFieldLoopNextUpdate) {
        		homeFieldLoopIdx = (homeFieldLoopIdx+1)%homeFieldLoopSize;
        		homeFieldLoopNextUpdate = timeNow + HOME_FIELD_LOOP_PERIOD;
        	}
        	
        	// North heading
        	var northAngle = pilot.currentHeading;
        	if (RELATIVE_DIRECTION) {
        		northAngle = -northAngle;
        	}
        	drawDirection(dc, northAngle, Graphics.COLOR_RED, 0);
        	
 			// Wind heading
        	var windAngle = pilot.windDirection;
        	if (RELATIVE_DIRECTION) {
        		windAngle = -windAngle;
        	}
        	drawDirection(dc, windAngle, Graphics.COLOR_YELLOW, 0); 
 
 			// Home heading
 			var homeHeading;
 			if (RELATIVE_DIRECTION) {
 				homeHeading = -(pilot.currentHeading-pilot.homeBearing);
 			} else {
 				homeHeading = pilot.homeBearing;
 			}
        	drawDirection(dc, homeHeading, Graphics.COLOR_GREEN, 0); 
        	
        	// Fuel gauge
        	var fuelLevel = 0.7;
        	var fuelGaugeWidth = 0.30*width/2;
        	var fuelGaugeHeight = 0.4*height/2;
        	var fuelX = width/2-fuelGaugeWidth/2;
        	var fuelY = height/2-fuelGaugeHeight/2;
        	var fuelGaugeHeightRemaining = fuelGaugeHeight * pilot.timeToPointOfNoReturn/pilot.MAX_FLIGHT_DURATION;
        	if (fuelGaugeHeightRemaining > fuelGaugeHeight) {
        		fuelGaugeHeightRemaining = fuelGaugeHeight;
        	} else if (fuelGaugeHeightRemaining < 0) {
        		fuelGaugeHeightRemaining = 0;
        	}
        	if (!pilot.flying) {
        		dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        		dc.fillRectangle(fuelX, fuelY, fuelGaugeWidth, fuelGaugeHeight);	
        	} else {   		      
	        	if (pilot.timeToPointOfNoReturn < 5*60) {
	        		dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
	        	} else if (pilot.timeToPointOfNoReturn < 15*60) {
	        		dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
	        	} else {
	        		dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
	        	}
	        	dc.fillRectangle(fuelX, fuelY, fuelGaugeWidth, fuelGaugeHeight);
	        	dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
	        	dc.fillRectangle(fuelX, fuelY+fuelGaugeHeight-fuelGaugeHeightRemaining, fuelGaugeWidth, fuelGaugeHeightRemaining);    
	        }        	            	   
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
    
    function drawInfoField(dc, angle, title, info) {
    	var pos = polar2cart(angle, INFO_RADIUS);
    	dc.drawText(pos.x, pos.y-titleToInfoSpacing, titleFontSize, title, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
    	dc.drawText(pos.x, pos.y, infoFontSize, info, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
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
