using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Sensor;
using Toybox.Math;
using Toybox.Position;
using Toybox.System;
using Toybox.Time;
using Toybox.ActivityRecording;
using Toybox.FitContributor;

class PPGPilotRoundView extends WatchUi.View {
	const MPS2MPH = 2.23694;
	const M2F = 3.28084;
	const M2MILE = 0.000621371;
	const F2MILE = 0.000189394;
	const INFO_RADIUS = 0.6;
	const HOME_FIELD_LOOP_PERIOD = 3; // sec
	const REC_FLASH_PERIOD = 0; // sec
	const ENABLE_FUEL_GAUGE = false;
	const ALERT_FLASH_PERIOD = 0.5; // sec
	var infoFontSize = null;
	var txtInfoFontSize = null;
	var titleFontSize = null;
	var titleToInfoSpacing = 0;
	var pilot; // PPGPilot instance
    var width; // pixels
    var height; // pixels
    var infoFontHeight; // pixels
    var titleFontHeight; // pixels
    var homeFieldLoopSize = 2;
    var homeFieldLoopIdx = 0;
    var homeFieldLoopNextUpdate = 0;
    var recFlashNextUpdate = 0;
    var recVisible = false;
    var layoutInitDone = false;
    var dark = false;
    var alertFlashNextUpdate = 0;
    var alertVisible = false;

    class PixelPos {
    	var x;
    	var y;
    	function initialize(x, y) {
    		self.x = x;
    		self.y = y;
    	}
    }
    
    function initialize(pilot) {
        View.initialize();
        self.pilot = pilot;
    }

    // Load your resources here
    function onLayout(dc) {
    	if (!layoutInitDone) {
	    	System.println("Setting up new layout");
	    	// Figure out font size
	    	var titleToInfoSpacingScale;
	    	if (dc.getWidth() < 240) {
	    		infoFontSize = Graphics.FONT_NUMBER_HOT;
	    		txtInfoFontSize = Graphics.FONT_SYSTEM_LARGE;
	    		titleFontSize = Graphics.FONT_XTINY;
	    		titleToInfoSpacingScale = 16.0; 
	    	} else {
	     		infoFontSize = Graphics.FONT_NUMBER_MEDIUM;
	     		txtInfoFontSize = Graphics.FONT_SYSTEM_LARGE;
	    		titleFontSize = Graphics.FONT_XTINY;
	    		titleToInfoSpacingScale = 5.0; 
	    	}   		
	        // Setup dims
	        width = dc.getWidth(); 
	        height = dc.getHeight();
	        infoFontHeight = dc.getFontHeight(infoFontSize);
	        titleFontHeight = dc.getFontHeight(titleFontSize);
	        titleToInfoSpacing = titleToInfoSpacingScale*(height/infoFontHeight);
	        layoutInitDone = true;
        } else {
        	System.println("New layout request, skipping since already done");
        }
    }

    // Restore the state of the app and prepare the view to be shown
    function onShow() {
    }

    // Update the view
    function onUpdate(dc) {
    	// Reset screen
    	if (dark) {
        	dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        } else {
        	dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        }
        dc.clear();
        
		// Draw text
        if (pilot.posInfo != null) {
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
	        if (pilot.gustAlert != null) {
	        	drawGustAlarmState(dc, -45, pilot.gustAlert);
	        }
        	        	
        	// Ground speed
        	var groundSpeed = pilot.currentGroundSpeed * MPS2MPH;
        	drawInfoField(dc, 270, "GSPD", groundSpeed.format("%.1f"));

			// Altitude (baro)
        	var alt = pilot.currentAltitudeOverHome * M2F;
        	drawInfoField(dc, 0, "ALT", alt.format("%d"));

			// Wind speed
        	var wSpd = pilot.windSpeed * MPS2MPH;
        	drawInfoField(dc, 90, "WSPD", wSpd.format("%.1f"));

			// Time/dist to home
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
    
    function drawInfoField(dc, angle, title, info) {
    	var pos = polar2cart(angle, INFO_RADIUS);
		if (dark) {
        	dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        } else {
        	dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        }
    	dc.drawText(pos.x, pos.y-titleToInfoSpacing, titleFontSize, title, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
    	dc.drawText(pos.x, pos.y, infoFontSize, info, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
    }
    
    function drawTextField(dc, angle, title, txt) {
    	var pos = polar2cart(angle, INFO_RADIUS);
		if (dark) {
        	dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        } else {
        	dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        }
    	dc.drawText(pos.x, pos.y-titleToInfoSpacing, titleFontSize, title, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
    	dc.drawText(pos.x, pos.y, txtInfoFontSize, txt, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
    }
    
    function drawDirection(dc, angle, color, arrow) {
    	var arrowAngle = 5;
    	var maxRad = 1.0;
    	var minRad = 0.7;
    	var p1;
    	var p2;
    	var p3;
    	dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    	if (arrow > 0) {
    		p1 = polar2cart(angle, maxRad);
    		p2 = polar2cart(angle+7, minRad);
    		p3 = polar2cart(angle-7, minRad);
    		dc.fillPolygon([[p1.x, p1.y], [p2.x, p2.y], [p3.x, p3.y]]); 
    	} else if (arrow < 0) {
    		p1 = polar2cart(angle, minRad);
    		p2 = polar2cart(angle+5, maxRad);
    		p3 = polar2cart(angle-5, maxRad); 
    		dc.fillPolygon([[p1.x, p1.y], [p2.x, p2.y], [p3.x, p3.y]]);   
    	} else {
    		p1 = polar2cart(angle, minRad);
    		p2 = polar2cart(angle, maxRad);
    		dc.setPenWidth(5);
    		dc.drawLine(p1.x, p1.y, p2.x, p2.y);
    	}
    			
    }
    
    function drawVario(dc, rate) {
    	var varioWidth = 25;
    	var varioHeight = 30;
    	var varioCenterX = width / 2;
    	var varioCenterY = height / 2;
    	var varioBottomY = varioCenterY + varioHeight/2;
    	var varioTopY = varioCenterY - varioHeight/2;
    	dc.setPenWidth(3);
    	if (rate < 0.1 && rate > -0.1) {
    		dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
    		dc.drawLine(varioCenterX-varioWidth/2, varioCenterY, varioCenterX+varioWidth/2, varioCenterY);
    	} else {
    		var numArrows = Math.round(abs(rate) / 0.5);
    		if (numArrows == 0) {
    			numArrows = 1;
    		} else if (numArrows > 6) {
    			numArrows = 6;
    		}
    		for (var n = 0; n < numArrows; ++n) {
    			if (rate > 0) {
    				drawVarioArrow(dc, varioCenterX, varioBottomY-n*7, true);
    			} else {
    				drawVarioArrow(dc, varioCenterX, varioTopY+n*7, false);
    			}
    		}
		}
    }
    
    function drawVarioArrow(dc, x, y, dirUp) {
    	if (dirUp) {
    		dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
    		dc.drawLine(x, y, x - 15, y + 10);
    		dc.drawLine(x, y, x + 15, y + 10);
    	} else {
    		dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
    		dc.drawLine(x, y, x - 15, y - 10);
    		dc.drawLine(x, y, x + 15, y - 10);    	
    	}
    }
    
    function drawRecordingState(dc, angle, recording) {
    	var pos = polar2cart(angle, 0.8);
    	var timeNow = Time.now().value();
    	if (recording) {
    		if (timeNow >= recFlashNextUpdate) {
    			recVisible = !recVisible;
    			recFlashNextUpdate = timeNow + REC_FLASH_PERIOD;
    		}
			if (REC_FLASH_PERIOD == 0 || recVisible) {
    			dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
    			dc.fillCircle(pos.x, pos.y, 9);
    		}
    	} else {
    		dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
    		dc.fillRectangle(pos.x-7, pos.y-7, 14, 14);
    	}
    }
    
    function drawGustAlarmState(dc, angle, gustAlert) {
    	var pos = polar2cart(angle, 0.8);
    	var timeNow = Time.now().value();
    	var size = 10;
    	var sizeAlert = 15;
    	// Update flashing state
		if (timeNow >= alertFlashNextUpdate) {
			alertVisible = !alertVisible;
			alertFlashNextUpdate = timeNow + ALERT_FLASH_PERIOD;
		}    	
    	// Draw 
    	if (gustAlert["severity_name"].equals("CLEAR")) {
    		dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
    		dc.fillPolygon([[pos.x, pos.y-size], [pos.x-size, pos.y+size], [pos.x+size, pos.y+size]]);  
    	} else if (gustAlert["severity_name"].equals("WARNING")) {
    		if (ALERT_FLASH_PERIOD == 0 || alertVisible) {
	    		dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
	    		dc.fillPolygon([[pos.x, pos.y-size], [pos.x-size, pos.y+size], [pos.x+size, pos.y+size]]);	
	    	}	
    	} else if (gustAlert["severity_name"].equals("ALERT")) {
    		if (ALERT_FLASH_PERIOD == 0 || alertVisible) {
	    		dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
	    		dc.fillPolygon([[pos.x, pos.y-sizeAlert], [pos.x-sizeAlert, pos.y+sizeAlert], [pos.x+sizeAlert, pos.y+sizeAlert]]);  
	    	}	
    	} else {
    		System.println("Unknown alert name: " + gustAlert["severity_name"]);
    	}
    }
    
    function abs(n) {
    	if (n < 0) {
    		return -n;
    	} else {
    		return n;
    	}
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
	
}
