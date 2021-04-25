using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Sensor;
using Toybox.Math;
using Toybox.Position;
using Toybox.System;
using Toybox.Time;
using Toybox.ActivityRecording;
using Toybox.FitContributor;

class PPGPilotRectWindGustView extends PPGPilotRectView {

	// Initialize
    function initialize(pilot) {
        PPGPilotRectView.initialize(pilot);
    }
    
    // Load your resources here
    function onLayout(dc) { 
    	if (!layoutInitDone) {
	    	System.println("Setting up new layout");
	    	// Setup grid layout
	    	grids = initGridLayout(dc.getWidth(), dc.getHeight());	
	    	// Setup compass
	    	compass = new CompassView(grids[3][0], grids[3][1], grids[3][2], grids[3][3], dark, false);	
	        layoutInitDone = true;
        } else {
        	System.println("New layout request, skipping since already done");
        }
    }

    // Update the view
    function onUpdate(dc) {
    	// Reset screen
    	if (dark) {
        	dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        } else {
        	dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        }
        dc.clear();
        
		// Draw text
		if (dark) {
        	dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        } else {
        	dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        }
        if (pilot.posInfo != null && pilot.gustAlert != null) {
        	var timeNow = Time.now().value();
        	
	        // Recording state
	        var recordingState;
	        if (pilot.session != null && pilot.session.isRecording()) {
	        	recordingState = true;
	        } else {
	        	recordingState = false;
	        }
	        drawRecordingState(dc, grids[9], recordingState); 
	        
	        // Gust alarm state
	        if (pilot.gustAlert != null) {
	        	drawGustAlarmState(dc, grids[8], pilot.gustAlert);
	        }     
        	        	   			
   			// Draw compass rose
   			compass.update(dc, pilot.currentHeading, pilot.homeBearing, pilot.windDirection, pilot.homeLocked);
   			
   			// Alerting station positions
   			var maxStationDist = 0;
   			for (var n = 0; n < pilot.gustAlert["num_alerting_stations"]; ++n) {
   				var dist = pilot.gustAlert["alerting_stations"][n]["distance"]*F2MILE;
   				if (dist > maxStationDist) {
   					maxStationDist = dist;
   				}
   			}  			
   			for (var n = 0; n < pilot.gustAlert["num_alerting_stations"]; ++n) {
   				drawStation(dc, grids[3], -(pilot.currentHeading-pilot.gustAlert["alerting_stations"][n]["bearing"]), pilot.gustAlert["alerting_stations"][n]["distance"]*F2MILE, pilot.gustAlert["alerting_stations"][n]["confidence"], maxStationDist);
   			} 
	        
	        // Gust probability
        	var prob = Math.round(pilot.gustAlert["confidence"] * 100);
        	drawDataField(dc, grids[1], "PROB", prob.format("%d"), null, null, BOUNDING_BOX, false); 	        
	        
	        // Num alerting stations
        	var numStations = pilot.gustAlert["num_alerting_stations"];
        	drawDataField(dc, grids[5], "STATIONS", numStations.format("%d"), null, null, BOUNDING_BOX, false);    
        	
	        // Distance to closest
	        if (numStations > 0) {
        		var distStation = pilot.gustAlert["closest_station_distance"]*F2MILE;
        		drawDataField(dc, grids[6], "DIST", distStation.format("%.1f"), null, null, BOUNDING_BOX, false); 
        	} else {
        		drawDataField(dc, grids[6], "DIST", "-", null, null, BOUNDING_BOX, false); 
        	}
        	
        	// Threat level
        	if (pilot.gustAlert["severity_name"].equals("CLEAR")) {
        		drawDataField(dc, grids[0], "THREAT", "CLEAR", null, null, BOUNDING_BOX, true);	
        	} else if (pilot.gustAlert["severity_name"].equals("WARNING")) {
        		drawDataField(dc, grids[0], "THREAT", "WARN", null, null, BOUNDING_BOX, true);	
        	} else if (pilot.gustAlert["severity_name"].equals("ALERT")) {
        		drawDataField(dc, grids[0], "THREAT", "ALERT", null, null, BOUNDING_BOX, true);	
        	} else {
        		drawDataField(dc, grids[0], "THREAT", "-", null, null, BOUNDING_BOX, true);	
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
   			drawProgressBar(dc, grids[2], fuelRemaining, color, false);
   			
   			// Draw vario
   			drawVarioBar(dc, grids[4], pilot.currentVerticalSpeedAvrg.derivative, false);
   			
   			// Advance to next field in the loop if time
        	if (timeNow >= fieldLoopNextUpdate) {
        		fieldLoopIdx = (fieldLoopIdx+1)%fieldLoopSize;
        		fieldLoopNextUpdate = timeNow + FIELD_LOOP_PERIOD;
        	}
   			
		}	        
        
        // Draw any notifications
        if (pilot.notification != null) {
        	// Draw it
        	dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
			dc.fillRectangle(0, 0, dc.getWidth(), NOTIFICATION_HEIGHT_RATIO*dc.getHeight());
        	if (pilot.notification.warn) {
        		dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
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

	function drawStation(dc, screenPos, stationBearing, stationDist, stationConf, maxDist) {
		var width = screenPos[2];
		var height = screenPos[3];
    	var x = screenPos[0] + width/2;
    	var y = screenPos[1] + height/2;
		var maxRadius = (width > height ? height-height*0.025 : width-width*0.025)/2.7;
		var stationPos = polar2cart(x, y, stationBearing, maxRadius*stationDist/maxDist);
		if (stationConf < 0.4) {
    		dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
    		dc.fillCircle(stationPos[0], stationPos[1], 6);	
    	} else if (stationConf < 0.7) {
    		dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
    		dc.fillCircle(stationPos[0], stationPos[1], 6);	
    	} else {
    		dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
    		dc.fillCircle(stationPos[0], stationPos[1], 9);	
    	}
	}
	
	// Convert polar (angle in degrees, radius in pixels) to cartesian (x, y in pixels)
	function polar2cart(origX, origY, angle, radiusPix) {
		var angleRad = Math.PI/2 - Math.toRadians(angle);
		var x = Math.round(origX + radiusPix * Math.cos(angleRad));
		var y = Math.round(origY - radiusPix * Math.sin(angleRad));
		return [x,y];
	}
    	
}
