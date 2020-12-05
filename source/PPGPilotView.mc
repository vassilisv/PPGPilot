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

class PPGPilotView extends WatchUi.View {
	const MPS2MPH = 2.23694;
	const M2F = 3.28084;
	const M2MILE = 0.000621371;
	const INFO_FONT_SIZE = Graphics.FONT_NUMBER_HOT;
	const TITLE_FONT_SIZE = Graphics.FONT_XTINY;
	const INFO_RADIUS = 0.6;
	const TITLE_TO_INFO_SPACING = 0.4;
	const FLYING_MIN_SPEED = 3.57f; // 8 mph
	const relativeDirection = false;
    var dataTimer; // as per API
    var width; // pixels
    var height; // pixels
    var posInfo; // as per API
    var sensorInfo; // as per API
    var notification; // object
    var gotGPSFix; // bool
    var infoFontHeight; // pixels
    var titleFontHeight; // pixels
    var windEstimator; // object
    var homePosInfo; // as per API
    var homeDistance = 0; // meters
    var homeBearing = 0; // degrees from North
    var windSpeed = 0; // meters / second
    var windDirection = 0; // degrees from North
    var currentHeading = 0; // degrees from North
    var currentAltitude = 0; // meters
    var currentGroundSpeed = 0; // meters / second
    var currentAirSpeed = 0; // meters / second
    var windSpeedField = null;
    var flying = false;
    var session = null;
    
    class PixelPos {
    	var x;
    	var y;
    	function initialize(x, y) {
    		self.x = x;
    		self.y = y;
    	}
    }
    
    class Notification {
    	var msg;
    	var timeToExpire;
    	var warn;
    	function initialize(msg, warn, timeout) {
    		self.msg = msg;
    		self.warn = warn;
    		if (timeout > 0) {
    			self.timeToExpire = Time.now().add(new Time.Duration(10));
    		} else {
    			self.timeToExpire = null;
    		}
    	}
    	function isExpired() {
    		if (self.timeToExpire == null) {
    			return false;
    		} else {
    			return Time.now().greaterThan(self.timeToExpire);
    		}
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
        infoFontHeight = dc.getFontHeight(INFO_FONT_SIZE);
        titleFontHeight = dc.getFontHeight(TITLE_FONT_SIZE);
        // Setup wind estimator
        windEstimator = new WindEstimator(10, 3);
    	// Setup timer
        dataTimer = new Timer.Timer();
        dataTimer.start(method(:timerCallback), 200, true);
        // Setup position updates
        gotGPSFix = false;
        homePosInfo = null;
        homeDistance = 0;
        homeBearing = 0;
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        // Display wellcome notification
        notification = new Notification("Waiting for GPS", true, 0);
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
        if (posInfo != null) {        	
        	// Ground speed
        	var groundSpeed = currentGroundSpeed * MPS2MPH;
        	drawInfoField(dc, 270, "GSPD", groundSpeed.format("%4.1f"));

			// Altitude (baro)
        	var alt = currentAltitude * M2F;
        	drawInfoField(dc, 0, "ALT", alt.format("%4d"));

			// Wind speed
        	var wSpd = windSpeed * MPS2MPH;
        	drawInfoField(dc, 90, "WSPD", wSpd.format("%4.1f"));

			// Time/dist to home (TBD)
			// TODO: Implement, alternate between distance to home and time to home
			var homeDist = homeDistance*M2MILE;
        	drawInfoField(dc, 180, "HOME", homeDist.format("%4.1f"));
        	
        	// North heading
        	var northAngle = currentHeading;
        	if (relativeDirection) {
        		northAngle = -northAngle;
        	}
        	drawDirection(dc, northAngle, Graphics.COLOR_RED, 0);
        	
 			// Wind heading
        	var windAngle = windDirection;
        	if (relativeDirection) {
        		windAngle = -windAngle;
        	}
        	drawDirection(dc, windAngle, Graphics.COLOR_YELLOW, 0); 
 
 			// Home heading
 			var homeHeading;
 			if (relativeDirection) {
 				homeHeading = -(currentHeading-homeBearing);
 			} else {
 				homeHeading = homeBearing;
 			}
        	drawDirection(dc, homeHeading, Graphics.COLOR_GREEN, 0); 
        	
        	// Fuel gauge
        	var fuelLevel = 0.7;
        	var fuelGaugeWidth = 0.25*width/2;
        	var fuelGaugeHeight = 0.4*height/2;
        	var fuelX = width/2-fuelGaugeWidth/2;
        	var fuelY = height/2-fuelGaugeHeight/2;
        	dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        	dc.setPenWidth(1);
        	dc.drawRectangle(fuelX, fuelY, fuelGaugeWidth, fuelGaugeHeight);
        	if (flying) {
        		dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
        	} else {
        		dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        	}
        	dc.fillRectangle(fuelX, fuelY, fuelGaugeWidth, fuelGaugeHeight);            	            	   
		}	        
        
        // Draw any notifications
        if (notification != null) {
        	// Draw it
        	if (notification.warn) {
        		dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        	} else {
        		dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        	}
			dc.fillRectangle(0, 0, width, 0.25*height);
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			var pos = polar2cart(0, 0.75);
			dc.drawText(pos.x,  pos.y, Graphics.FONT_SYSTEM_MEDIUM, notification.msg, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
			
        	// If expired delete it
        	if (notification.isExpired()) {
        		notification = null;
        	}
        }
        
    }
    
    function drawInfoField(dc, angle, title, info) {
    	var pos = polar2cart(angle, INFO_RADIUS);
    	dc.drawText(pos.x, pos.y-(infoFontHeight*TITLE_TO_INFO_SPACING), TITLE_FONT_SIZE, title, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
    	dc.drawText(pos.x, pos.y, INFO_FONT_SIZE, info, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
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
        sensorInfo = Sensor.getInfo();
        currentHeading = Math.toDegrees(sensorInfo.heading);
        currentAltitude = sensorInfo.altitude;
        WatchUi.requestUpdate();
    }

    // Called when this View is removed from the screen. Save the
    // state of your app here.
    function onHide() {
    }
    
    // Called on position updates
	function onPosition(info) {
		posInfo = info;
		// Check for good accuracy
		if (posInfo.accuracy < 2) {
			notification = new Notification("Lost GPS Fix", true, 10);
			gotGPSFix = false;
		} else if (sensorInfo != null) {
			// Set home and notify
			if (!gotGPSFix) {
				gotGPSFix = true;
				// Set home if not done already
				if (homePosInfo == null) {
					homePosInfo = info;
					notification = new Notification("Home Set", false, 10);
				} else {
					notification = new Notification("Got GPS Fix", false, 10);
				}
			}
			// Update speed
			currentGroundSpeed = posInfo.speed;
			// Calculate home distance and bearing
		    homeDistance = posDistance(posInfo.position, homePosInfo.position);
		    homeBearing = posBearing(posInfo.position, homePosInfo.position);
		    System.println("Bearing/Disr: " + homeBearing + ", " + homeDistance);
		    System.println("Heading: " + currentHeading);
		    // Calculate wind speed
		    var windEstimate = windEstimator.update(currentGroundSpeed, currentHeading);
		    if (windEstimate[0] != null && windEstimate[1] != null) {
			    windSpeed = windEstimate[0];
			    windDirection = windEstimate[1];
			    currentAirSpeed = windEstimate[2];
			    System.println("Wind speed/direction/airspeed: " + windSpeed + " / " + windDirection + " / " + currentAirSpeed);
			}
			// Update flying state
			updateFlyingState();
			// Update custom fields
			if (session != null) {
				windSpeedField.setData(windSpeed);
			}
		} else {
			System.println("WARNING: Waiting for sensor data, can't process position update");
		}
	    System.println("Position acc: " + posInfo.accuracy); 
	}
	
	// Convert polar (angle in degrees, radius as a fraction of visible screen) to cartesian (x, y in pixels)
	function polar2cart(angle, radius) {
		var angleRad = Math.PI/2 - Math.toRadians(angle);
		var radiusPix = radius*height/2;
		var x = Math.round(width/2 + radiusPix * Math.cos(angleRad));
		var y = Math.round(height/2 - radiusPix * Math.sin(angleRad));
		return new PixelPos(x, y);
	}
	
	// Calculate distance between two positions
	// Ref: https://www.movable-type.co.uk/scripts/latlong.html
	function posDistance(pos1, pos2) {
		// Distance
		var R = 6371e3; 
		var pos1deg = pos1.toDegrees(); // lat, lon
		var pos2deg = pos2.toDegrees();
		var phi1 = pos1deg[0] * Math.PI/180;
		var phi2 = pos2deg[0] * Math.PI/180;
		var dphi = (pos2deg[0]-pos1deg[0]) * Math.PI/180;
		var dlam = (pos2deg[1]-pos1deg[1]) * Math.PI/180;
		var a = Math.sin(dphi/2) * Math.sin(dphi/2) + Math.cos(phi1) * Math.cos(phi2) * Math.sin(dlam/2) * Math.sin(dlam/2);
		var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
		var dist = R * c;
		return dist;
	}
	
	// Calculate bearing between two positions
	// Ref: https://www.movable-type.co.uk/scripts/latlong.html
	function posBearing(pos1, pos2) {
		var pos1rad = pos1.toRadians(); // lat, lon
		var pos2rad = pos2.toRadians();
		var theta = Math.atan2(Math.cos(pos1rad[0]) * Math.sin(pos2rad[0]) - Math.sin(pos1rad[0]) * Math.cos(pos2rad[0]) * Math.cos(pos2rad[1]-pos1rad[1]), Math.sin(pos2rad[1]-pos1rad[1]) * Math.cos(pos2rad[0]));
		var bearing = (90 - (theta*180/Math.PI)).toLong() % 360;
		//var bearing = Math.toDegrees(theta);
		return bearing;
	}
	
	// Check if we are flying 
	function updateFlyingState() {
		// Nothing to do if already flying
		if (!flying) {
			// Check speed to detect if flying (TODO: average speed)
			if (currentGroundSpeed > FLYING_MIN_SPEED) {
				flying = true;
				startSession();
		        notification = new Notification("Flying", false, 5);
		    
		    }
		}				
	}
	
	function startSession() {
		// Start session
	    if ((session == null) || (session.isRecording() == false)) {
	    	session = ActivityRecording.createSession({          // set up recording session
	             :name=>"PPG",                              // set session name
	             :sport=>ActivityRecording.SPORT_GENERIC,       // set sport type
	             :subSport=>ActivityRecording.SUB_SPORT_GENERIC // set sub sport type
	      	});
	      	windSpeedField = session.createField("Windspeed", 0, FitContributor.DATA_TYPE_FLOAT, 
	      		{:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"mph"});
	  		session.start();                                     // call start session
	    	System.println("Activity recording started");
	    }
	}
	
	function stopSession() {
		// Stop recording session if already running
    	if ((session != null) && session.isRecording()) {
         	session.stop();                                      // stop the session
          	session.save();                                      // save the session
          	session = null;                                      // set session control variable to null
          	System.println("Activity recording stopped");
      	}	
	}
	
	function onStop() {
		stopSession();
      	System.println("App stopped");		
	}
}
