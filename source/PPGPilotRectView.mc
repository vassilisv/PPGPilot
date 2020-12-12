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
	const RELATIVE_DIRECTION = true;
	const NUMBER_FONT_SIZES = [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD, Graphics.FONT_SMALL];
	const NUMBER_FONT_SIZES_SMALL = [Graphics.FONT_NUMBER_MILD, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY];
	const TEXT_FONT_SIZES = [Graphics.FONT_SYSTEM_LARGE, Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY];
	const FIELD_TITLE_TO_DATA_RATIO = 0.20;
	const LAYOUT_PROGRESS_CELL_HEIGHT_RATIO = 0.1;
	const LAYOUT_NUM_CELLS = 9;
	const NOTIFICATION_HEIGHT_RATIO = 0.35;
	var grids; // The layout grids, array
	var pilot; // PPGPilot instance
	var refreshTimer;
    var homeFieldLoopSize = 2;
    var homeFieldLoopIdx = 0;
    var homeFieldLoopNextUpdate = 0;
    
    function initialize() {
        View.initialize();
    }

    // Load your resources here
    function onLayout(dc) { 
    	// Setup grid layout
    	grids = initGridLayout(dc.getWidth(), dc.getHeight());		
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
        	        	
        	// Heading
        	var northAngle = pilot.currentHeading;
        	if (RELATIVE_DIRECTION) {
        		northAngle = -northAngle;
        	}
        	drawDirectionField(dc, grids[0], northAngle, Graphics.COLOR_RED, "HEADING", directionToText(pilot.currentHeading));          	 
        	        	
        	// Ground speed
        	var groundSpeed = pilot.currentGroundSpeed * MPS2MPH;
        	drawDataField(dc, grids[1], "GSPD", groundSpeed.format("%02.1f"), null, null);

 			// Wind heading
        	var windAngle = pilot.windDirection;
        	if (RELATIVE_DIRECTION) {
        		windAngle = -windAngle;
        	}
        	drawDirectionField(dc, grids[2], windAngle, Graphics.COLOR_YELLOW, "WDIR", directionToText(pilot.windDirection)); 

			// Wind speed
        	var wSpd = pilot.windSpeed * MPS2MPH;
        	drawDataField(dc, grids[3], "WSPD", wSpd.format("%.1f"), null, null);

 			// Home heading 
 			var homeHeading;
 			if (RELATIVE_DIRECTION) {
 				homeHeading = -(pilot.currentHeading-pilot.homeBearing);
 			} else {
 				homeHeading = pilot.homeBearing;
 			}
        	drawDirectionField(dc, grids[4], homeHeading, Graphics.COLOR_GREEN, "HDIR", directionToText(pilot.homeBearing)); 

			// Distance from home
			var homeDist = pilot.homeDistance*M2MILE;
    		drawDataField(dc, grids[5], "HDIST", homeDist.format("%.1f"), null, null);

			// Altitude (baro)
        	var alt = pilot.currentAltitude * M2F;
        	drawDataField(dc, grids[6], "ALT", alt.format("%04d"), null, null); 
        	
        	// Flight time and time to home
    		if (pilot.flying) {
        		var minsFlying = Math.round((timeNow - pilot.takeoffTime)/60);
				var minsToHome = Math.round(pilot.timeToHome / 60);
        		drawDataField(dc, grids[7], "TTOTAL/THOME", minsFlying.format("%02d") + "/" + minsToHome.format("%02d"), null, null);
        	} else {
        		drawDataField(dc, grids[7], "TTOTAL/THOME", "--/--", null, null);
        	}  	
        	   	
        	// Fuel remaining before having to turn back
        	var fuelRemaining = pilot.timeToPointOfNoReturn/pilot.MAX_FLIGHT_DURATION;
        	var color;
        	if (!pilot.flying) {
        		color = Graphics.COLOR_DK_GRAY;
        		fuelRemaining = 1.0;
        	} else {
	        	if (pilot.timeToPointOfNoReturn < 5*60) {
	        		color = Graphics.COLOR_RED;
	        	} else if (pilot.timeToPointOfNoReturn < 15*60) {
	        		color = Graphics.COLOR_YELLOW;
	        	} else {
	        		color = Graphics.COLOR_GREEN;
	        	}        	
        	}     	
   			drawProgressBar(dc, grids[8], fuelRemaining, color);
		}	        
        
        // Draw any notifications
        if (pilot.notification != null) {
        	// Draw it
        	dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
			dc.fillRectangle(0, 0, dc.getWidth(), NOTIFICATION_HEIGHT_RATIO*dc.getHeight());
        	if (pilot.notification.warn) {
        		dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        	} else {
        		dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        	}
        	drawText(dc, 0, 0, dc.getWidth(), NOTIFICATION_HEIGHT_RATIO*dc.getHeight(), pilot.notification.msg, TEXT_FONT_SIZES);			
        	// If expired delete it
        	if (pilot.notification.isExpired()) {
        		pilot.notification = null;
        	}
        }
        
    }
    
    // Draw a datafield
    function drawDataField(dc, screenPos, title, data, titleFonts, dataFonts) {
    	var x = screenPos[0];
    	var y = screenPos[1];
    	var width = screenPos[2];
    	var height = screenPos[3];
    	// Use default fonts if none given
    	if (titleFonts == null) {
    		titleFonts = TEXT_FONT_SIZES;
    	}
    	if (dataFonts == null) {
    		dataFonts = NUMBER_FONT_SIZES;
    	}    	
    	// Text
    	dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    	if (title != null) {
    		drawText(dc, x, y, width, height*FIELD_TITLE_TO_DATA_RATIO, title, titleFonts);
    	}
    	if (data != null) {
    		drawText(dc, x, y+height*FIELD_TITLE_TO_DATA_RATIO, width, height*(1-FIELD_TITLE_TO_DATA_RATIO), data, dataFonts);
    	}
    	// Bounding box
    	dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
    	dc.setPenWidth(1);
    	dc.drawRectangle(x, y, width, height);
    }
    
    // Drawtext
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
	function drawDirectionField(dc, screenPos, angle, color, title, data) {
    	var x = screenPos[0];
    	var y = screenPos[1];
    	var width = screenPos[2];
    	var height = screenPos[3];
		var radius = min([width, height])/2.0;
		var centerX = x+width/2.0;
		var centerY = y+height/2.0;
		var angleRad = Math.PI/2.0 - Math.toRadians(angle);
		var pointX = Math.floor(centerX + radius * Math.cos(angleRad));
		var pointY = Math.floor(centerY - radius * Math.sin(angleRad));
		var tailCX = Math.floor(centerX + 0.2*radius * Math.cos(angleRad + Math.PI));
		var tailCY = Math.floor(centerY - 0.2*radius * Math.sin(angleRad + Math.PI));
		var tailLX = Math.floor(centerX + radius * Math.cos(angleRad + 0.7*Math.PI));
		var tailLY = Math.floor(centerY - radius * Math.sin(angleRad + 0.7*Math.PI));
		var tailRX = Math.floor(centerX + radius * Math.cos(angleRad - 0.7*Math.PI));
		var tailRY = Math.floor(centerY - radius * Math.sin(angleRad - 0.7*Math.PI));
		// Direction arrow
		dc.setColor(color, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(3);
		dc.fillPolygon([[pointX, pointY], [tailLX, tailLY], [tailCX, tailCY], [tailRX, tailRY]]);
		// Title and data
		drawDataField(dc, screenPos, title, data, null, TEXT_FONT_SIZES); 
		// Bounding box
    	dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
    	dc.setPenWidth(1);
    	dc.drawRectangle(x, y, width, height);
	}
	
	// Draw a compass rose and display different directional elements (TODO)
	function drawCompassRose(dc, x, y, radius) {
		// Draw circle
		dc.setColor(Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(3);
		dc.drawCircle(x, y, radius);
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
	
	// Get min value from array
	function min(values) {
		var minVal = 10e6;
		for (var i = 0; i < values.size(); ++i) {
			if (values[i] < minVal) {
				minVal = values[i];
			}
		}
		return minVal;
	}
	
	// Initialize the layout grid	
	function initGridLayout(width, height) {
		var grids = new [LAYOUT_NUM_CELLS];
		// Calculate last cell (long horizontal)
		grids[LAYOUT_NUM_CELLS-1] = [0, height*(1-LAYOUT_PROGRESS_CELL_HEIGHT_RATIO), width, height*LAYOUT_PROGRESS_CELL_HEIGHT_RATIO];
		// Split remaining equally 
		for (var i = 0; i < LAYOUT_NUM_CELLS - 1; ++i) {
			var x = (i%2) * width/2.0;
			var y = Math.floor(i/2.0) * height * (1-LAYOUT_PROGRESS_CELL_HEIGHT_RATIO)/4.0;
			var w = width/2;
			var h = height * (1-LAYOUT_PROGRESS_CELL_HEIGHT_RATIO)/4.0;
			grids[i] = [x, y, w, h];
		}
		// Done
		return grids;
	}
	
	// Take a compass direction and convert to text (N/S...)
	function directionToText(angle) {
		// Unwarp
		angle = (360 + angle.toNumber()) % 360;
		// Convert
		if ((angle >= 0 && angle < 22.5) || (angle >= 337.5 && angle <= 360)) {
			return "N";
		} else if (angle >= 22.5 && angle < 67.5) {
			return "NE";
		} else if (angle >= 67.5 && angle < 112.5) {
			return "E";
		} else if (angle >= 112.5 && angle < 157.5) {
			return "SE";
		} else if (angle >= 157.5 && angle < 202.5) {
			return "S";
		} else if (angle >= 202.5 && angle < 247.5) {
			return "SW";
		} else if (angle >= 247.5 && angle < 292.5) {
			return "W";
		} else if (angle >= 292.5 && angle < 337.5) {
			return "NW";
		} else {
			return "?";
		}
	}
	
	// Draw a progress bar
	function drawProgressBar(dc, screenPos, progress, color) {
		var x = screenPos[0];
    	var y = screenPos[1];
    	var width = screenPos[2];
    	var height = screenPos[3];
    	// Bound progress
    	if (progress > 1.0) {
    		progress = 1.0;
    	} else if (progress < 0.0) {
    		progress = 0.0;
    	}
    	// Progress
    	dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    	dc.fillRectangle(x, y, width*progress, height);    
    	// Bounding box
    	dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
    	dc.setPenWidth(1);
    	dc.drawRectangle(x, y, width, height);
	}	
		
	
}
