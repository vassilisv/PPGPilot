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
using Toybox.Position;
using Toybox.System;
using Toybox.Time;

class PPGPilotView extends WatchUi.View {
	const MPS2MPH = 2.23694;
	const M2F = 3.28084;
	const INFO_FONT_SIZE = Graphics.FONT_LARGE;
	const TITLE_FONT_SIZE = Graphics.FONT_TINY;
	const INFO_RADIUS = 0.5;
	const TITLE_TO_INFO_SPACING = 0.7;
    var dataTimer;
    var width;
    var height;
    var posInfo;
    var sensorInfo;
    var notification;
    var gotGPSFix;
    var infoFontHeight;
    
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
    	// Setup timer
        dataTimer = new Timer.Timer();
        dataTimer.start(method(:timerCallback), 100, true);
        // Setup dims
        width = dc.getWidth(); 
        height = dc.getHeight();
        infoFontHeight = dc.getFontHeight(INFO_FONT_SIZE);
        // Setup position updates
        gotGPSFix = false;
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        // Setup sensor updates
        Sensor.setEnabledSensors([Sensor.SENSOR_TECHNOLOGY_ONBOARD]);
        Sensor.enableSensorEvents(method(:onSensor));
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
        	var groundSpeed = posInfo.speed * MPS2MPH;
        	drawInfoField(dc, 270, "GSPD", groundSpeed.format("%4.1f"));

			// Altitude (baro)
        	var alt = sensorInfo.altitude * M2F;
        	drawInfoField(dc, 0, "ALT", alt.format("%4d"));

			// Wind speed
        	var windSpeed = 10 * MPS2MPH;
        	drawInfoField(dc, 90, "WSPD", windSpeed.format("%4.1f"));

			// Time/dist to home (TBD)
			// TODO: Implement, alternate between distance to home and time to home
        	drawInfoField(dc, 180, "HOME", "10:12");
        	
        	// North heading
        	var northAngle = Math.toDegrees(-sensorInfo.heading);
        	drawDirection(dc, northAngle, Graphics.COLOR_ORANGE, 0);
        	
 			// Wind heading
 			// TODO: Implement
        	var windAngle = 150;
        	drawDirection(dc, windAngle, Graphics.COLOR_BLUE, -1); 
 
 			// Home heading
 			// TODO: Implement
        	var homeAngle = 100;
        	drawDirection(dc, homeAngle, Graphics.COLOR_GREEN, 1); 
        	
             	
        	
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
			dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
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
    	dc.drawText(pos.x,  pos.y-infoFontHeight*TITLE_TO_INFO_SPACING, TITLE_FONT_SIZE, title, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
    	dc.drawText(pos.x,  pos.y, INFO_FONT_SIZE, info, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
    }
    
    function drawDirection(dc, angle, color, arrow) {
    	var startPos = polar2cart(angle, 0.8);
    	var endPos = polar2cart(angle, 1.0);
    	dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    	dc.setPenWidth(3);
    	dc.drawLine(startPos.x, startPos.y, endPos.x, endPos.y);
    	var arrowRadius = 0.05;
    	if (arrow > 0) {
    		var arrowPos = polar2cart(angle, 1.0 - arrowRadius);
    		dc.fillCircle(arrowPos.x, arrowPos.y, Math.ceil(arrowRadius*width/2));
    	} else if (arrow < 0) {
    		var arrowPos = polar2cart(angle, 0.8 + arrowRadius);
    		dc.fillCircle(arrowPos.x, arrowPos.y, Math.ceil(arrowRadius*width/2));   
    	} 	
    }

    function timerCallback() {
        var info = Sensor.getInfo();
        WatchUi.requestUpdate();
    }

    // Called when this View is removed from the screen. Save the
    // state of your app here.
    function onHide() {
    }
    
    // Called on position updates
	function onPosition(info) {
		posInfo = info;
		if (posInfo.accuracy < 2) {
			notification = new Notification("Lost GPS Fix", true, 10);
			gotGPSFix = false;
		} else if (!gotGPSFix) {
			notification = new Notification("Got GPS Fix", false, 10);
			gotGPSFix = true; 
		}
				
	    System.println("Position acc: " + posInfo.accuracy); 
	}
	
	// Called on new sensor updates
	function onSensor(info) {
		sensorInfo = info;
		System.println("Sensor, H: " + info.heading + " A:" + info.altitude);
	}
	
	// Convert polar (angle in degrees, radius as a fraction) to cartesian (x, y in pixels)
	function polar2cart(angle, radius) {
		var angleRad = Math.PI/2 - Math.toRadians(angle);
		var radiusPix = radius*height/2;
		var x = Math.round(width/2 + radiusPix * Math.cos(angleRad));
		var y = Math.round(height/2 - radiusPix * Math.sin(angleRad));
		return new PixelPos(x, y);
	}
}
