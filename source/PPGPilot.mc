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

class PPGPilot { 
	const FLYING_MIN_SPEED = 3.57f; // 8 mph
	const MAX_FLIGHT_DURATION = 60*60; // sec
    var dataTimer; // as per API
    var posInfo = null; // as per API
    var sensorInfo; // as per API
    var notification; // object
    var gotGPSFix; // bool
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
    var groundSpeedHeadingHome = 0; // meters / second
    var timeToHome = 0; // seconds
    var windSpeedField = null;
	var windDirectionField = null; 
	var airSpeedField = null;
	var homeDistanceField = null;
	var homeDirectionField = null;	   
	var timeToHomeField = null;	
	var timeToPointOfNoReturnField = null;
    var flying = false;
    var session = null;
    var takeoffTime = 0; // sec
    var landTime = 0; // sec
    var timeToPointOfNoReturn = 0; // sec
    
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
        notification = new Notification("No GPS", true, 0);
    }


    function timerCallback() {
        sensorInfo = Sensor.getInfo();
        currentHeading = Math.toDegrees(sensorInfo.heading);
        currentAltitude = sensorInfo.altitude;
    }

    
    // Called on position updates
	function onPosition(info) {
		posInfo = info;
		// Check for good accuracy
		if (posInfo.accuracy < 2) {
			notification = new Notification("No GPS", true, 10);
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
					notification = new Notification("Got GPS", false, 10);
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
			// Update fly to home estimates
			updateReturnToHomeStats();
			// Update custom fields
			if (session != null) {
				windSpeedField.setData(windSpeed);
				windDirectionField.setData(windDirection);
				airSpeedField.setData(currentAirSpeed);
				homeDistanceField.setData(homeDistance);
				homeDirectionField.setData(homeBearing);
				timeToHomeField.setData(timeToHome);
				timeToPointOfNoReturnField.setData(timeToPointOfNoReturn);
			}
		} else {
			System.println("WARNING: Waiting for sensor data, can't process position update");
		}
	    System.println("Position acc: " + posInfo.accuracy); 
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
		return bearing;
	}
	
	// Check if we are flying 
	function updateFlyingState() {
		// Nothing to do if already flying
		if (!flying) {
			// Check speed to detect if flying (TODO: average speed)
			if (currentGroundSpeed > FLYING_MIN_SPEED) {
				flying = true;
				takeoffTime = Time.now().value();
				landTime = takeoffTime + MAX_FLIGHT_DURATION;
				startSession();
		        notification = new Notification("Flying", false, 5);  
		    }
		}				
	}
	
	// Update the return to home estimates (time to home and point of no return)
	function updateReturnToHomeStats() {
		var timeNow = Time.now().value();
		// Calculate wind contribution to speed when heading straight for home
		var windSpeedHeadingHome = -windSpeed * Math.cos(Math.toRadians(homeBearing-windDirection));
		// Assuming we maintain airspeed, calculate total speed while heading straight home
		groundSpeedHeadingHome = currentAirSpeed + windSpeedHeadingHome;
		// Calculate time left to go home if flying straight
		timeToHome = homeDistance / groundSpeedHeadingHome;
		// Calculate point of no return times
		var flightTimeLeft = landTime - timeNow;
		timeToPointOfNoReturn = flightTimeLeft - timeToHome;
		// Debug
		System.println("Speed to home: " + groundSpeedHeadingHome + ", time to home: " + timeToHome + ", time to PoNR: " + timeToPointOfNoReturn);
	}
	
	function startSession() {
		// Start session
	    if ((session == null) || (session.isRecording() == false)) {
	    	session = ActivityRecording.createSession({          // set up recording session
	             :name=>"PPG",                              // set session name
	             :sport=>ActivityRecording.SPORT_GENERIC,       // set sport type
	             :subSport=>ActivityRecording.SUB_SPORT_GENERIC // set sub sport type
	      	});
	      	windSpeedField = session.createField("wind_speed", 0, FitContributor.DATA_TYPE_FLOAT, 
	      		{:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"m/s"});
	      	windDirectionField = session.createField("wind_direction", 1, FitContributor.DATA_TYPE_FLOAT, 
	      		{:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"degrees"});	
	      	airSpeedField = session.createField("air_speed", 2, FitContributor.DATA_TYPE_FLOAT, 
	      		{:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"m/s"});
	      	homeDistanceField = session.createField("home_distance", 3, FitContributor.DATA_TYPE_FLOAT, 
	      		{:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"m"});	 
	      	homeDirectionField = session.createField("home_direction", 4, FitContributor.DATA_TYPE_FLOAT, 
	      		{:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"degrees"});	 
	      	timeToHomeField = session.createField("time_to_home", 5, FitContributor.DATA_TYPE_FLOAT, 
	      		{:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"sec"});	  
	      	timeToPointOfNoReturnField = session.createField("time_to_pnr", 6, FitContributor.DATA_TYPE_FLOAT, 
	      		{:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"sec"});	 	      		     			  	      		  
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
}
