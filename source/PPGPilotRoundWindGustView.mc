using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Sensor;
using Toybox.Math;
using Toybox.Position;
using Toybox.System;
using Toybox.Time;
using Toybox.ActivityRecording;
using Toybox.FitContributor;

class PPGPilotRoundWindGustView extends PPGPilotRoundView {

	// Initialize
    function initialize(pilot) {
        PPGPilotRoundView.initialize(pilot);
    }

    // Update the view (override)
    function onUpdate(dc) {
    	// Reset screen
    	if (dark) {
        	dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        } else {
        	dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        }
        dc.clear();
        
		// Draw text
        if (pilot.posInfo != null && pilot.gustAlert != null) {
        	var timeNow = Time.now().value();
        	
	        // Recording state
	        var recordingState;
	        if (pilot.session != null && pilot.session.isRecording()) {
	        	recordingState = true;
	        } else {
	        	recordingState = false;
	        }
	        drawRecordingState(dc, 45, recordingState); 
	        
	        // Gust alarm state
	        drawGustAlarmState(dc, -45, pilot.gustAlert);
	        
	        // Gust probability
        	var prob = Math.round(pilot.gustAlert["confidence"] * 100);
        	drawInfoField(dc, 0, "PROB", prob.format("%d"));	        
	        
	        // Num alerting stations
        	var numStations = pilot.gustAlert["num_alerting_stations"];
        	drawInfoField(dc, 270, "STATIONS", numStations.format("%d"));	   
        	
	        // Distance to closest
	        if (numStations > 0) {
        		var distStation = pilot.gustAlert["closest_station_distance"]*F2MILE;
        		drawInfoField(dc, 90, "DIST", distStation.format("%.1f"));
        	} else {
        		drawInfoField(dc, 90, "DIST", "-");	
        	}
        	
        	// Threat level
        	if (pilot.gustAlert["severity_name"].equals("CLEAR")) {
        		drawTextField(dc, 180, "THREAT", "CLEAR");	
        	} else if (pilot.gustAlert["severity_name"].equals("WARNING")) {
        		drawTextField(dc, 180, "THREAT", "WARN");	
        	} else if (pilot.gustAlert["severity_name"].equals("ALERT")) {
        		drawTextField(dc, 180, "THREAT", "ALERT!");	
        	} else {
        		drawTextField(dc, 180, "THREAT", "-");	
        	}
        	
   			// Alerting station headings
   			for (var n = 0; n < pilot.gustAlert["num_alerting_stations"]; ++n) {
   				drawStationDirection(dc, -(pilot.currentHeading-pilot.gustAlert["alerting_stations"][n]["bearing"]), pilot.gustAlert["alerting_stations"][n]["distance"]*F2MILE);
   			}
        	        	     	        	      	             	
        	// North heading
        	var northAngle = pilot.currentHeading;
        	drawDirection(dc, northAngle, Graphics.COLOR_RED, 0);
        	
 			// Wind heading
        	var windAngle = -(pilot.currentHeading-pilot.windDirection);
        	drawDirection(dc, windAngle, Graphics.COLOR_YELLOW, -1); 
 
 			// Home heading
 			var homeHeading = -(pilot.currentHeading-pilot.homeBearing);
        	drawDirection(dc, homeHeading, Graphics.COLOR_DK_GREEN, 1); 
        	
        	// Fuel gauge
        	if (ENABLE_FUEL_GAUGE) {
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
	        
	        // Vario
	        } else {
	        	drawVario(dc, pilot.currentVerticalSpeedAvrg.derivative);
	        }   
	         	            	   
		}	        
        
        // Draw any notifications
        if (pilot.notification != null) {
        	// Draw it
        	dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
			dc.fillRectangle(0, 0, width, 0.35*height);
        	if (pilot.notification.warn) {
        		dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
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
    
    function drawStationDirection(dc, angle, dist) {
    	var maxRad = 1.0;
    	var minRad = 0.8;
    	var p1;
    	var p2;
    	dc.setColor(Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
		p1 = polar2cart(angle, minRad);
		p2 = polar2cart(angle, maxRad);
		dc.setPenWidth(5);
		dc.drawLine(p1.x, p1.y, p2.x, p2.y);			
    }

}
