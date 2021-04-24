using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Sensor;
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
	const NUMBER_FONT_SIZES = [Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD, Graphics.FONT_SMALL];
	const NUMBER_FONT_SIZES_SMALL = [Graphics.FONT_NUMBER_MILD, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY];
	const TEXT_FONT_SIZES = [Graphics.FONT_SYSTEM_LARGE, Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY];
	const FIELD_TITLE_TO_DATA_RATIO = 0.20;
	const LAYOUT_PROGRESS_CELL_HEIGHT_RATIO = 0.1;
	const NOTIFICATION_HEIGHT_RATIO = 0.35;
	const FIELD_LOOP_PERIOD = 3;
	const VARIO_MAX = 2.5;
	const VARIO_RESOLUTION = 0.15;
	const BOUNDING_BOX = false;
	const REC_FLASH_PERIOD = 0; // sec
	const ALERT_FLASH_PERIOD = 0.5; // sec
	var grids; // The layout grids, array
	var pilot; // PPGPilot instance
	var compass; // CompassView instance
    var fieldLoopSize = 2;
    var fieldLoopIdx = 0;
    var fieldLoopNextUpdate = 0;
    var dark = false;
    var layoutInitDone = false;
    var recFlashNextUpdate = 0;
    var recVisible = false;
    var alertFlashNextUpdate = 0;
    var alertVisible = false;
    
    function initialize(pilot) {
        View.initialize();
        self.pilot = pilot;
    }

    // Load your resources here
    function onLayout(dc) { 
    	if (!layoutInitDone) {
	    	System.println("Setting up new layout");
	    	// Setup grid layout
	    	grids = initGridLayout(dc.getWidth(), dc.getHeight());	
	    	// Setup compass
	    	compass = new CompassView(grids[3][0], grids[3][1], grids[3][2], grids[3][3], dark);	
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
        	dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        }
        dc.clear();
        
		// Draw text
		if (dark) {
        	dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        } else {
        	dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        }
        if (pilot.posInfo != null) {
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
   			
        	// Ground speed
        	var groundSpeed = pilot.currentGroundSpeed * MPS2MPH;
        	drawDataField(dc, grids[0], "GROUND SPD", groundSpeed.format("%02.1f"), null, null, BOUNDING_BOX);   			
   			
			// Wind or air speed
			if (fieldLoopIdx == 0) {
	        	var wSpd = pilot.windSpeed * MPS2MPH;
	        	drawDataField(dc, grids[1], "WIND SPD", wSpd.format("%.1f"), null, null, BOUNDING_BOX);  
	        } else if (fieldLoopIdx == 1) {
	        	var aSpd = pilot.currentAirSpeed * MPS2MPH;
	        	drawDataField(dc, grids[1], "AIR SPD", aSpd.format("%.1f"), null, null, BOUNDING_BOX);  
	        }	        
			
			// Altitude
        	var alt = pilot.currentAltitudeOverHome * M2F;
        	drawDataField(dc, grids[5], "ALT", alt.format("%04d"), null, null, BOUNDING_BOX); 
        	
			// Distance from home
			var homeDist = pilot.homeDistance*M2MILE;
    		drawDataField(dc, grids[6], "HOME DIST", homeDist.format("%.1f"), null, null, BOUNDING_BOX);        	

        	// Flight time and time to home
    		if (pilot.flying) {
        		var minsFlying = Math.round((timeNow - pilot.takeoffTime)/60);
				var minsToHome = Math.round(pilot.timeToHome / 60);
        		drawDataField(dc, grids[7], "TOT/RET", minsFlying.format("%02d") + "/" + minsToHome.format("%02d"), null, null, BOUNDING_BOX);
        	} else {
        		drawDataField(dc, grids[7], "TOT/RET", "--/--", null, null, BOUNDING_BOX);
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
    
    // Draw a datafield
    function drawDataField(dc, screenPos, title, data, titleFonts, dataFonts, boundingBox) {
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
    	if (dark) {
    		dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    	} else {
    		dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
    	}
    	if (title != null) {
    		drawText(dc, x, y, width, height*FIELD_TITLE_TO_DATA_RATIO, title, titleFonts);
    	}
    	if (data != null) {
    		drawText(dc, x, y+height*FIELD_TITLE_TO_DATA_RATIO, width, height*(1-FIELD_TITLE_TO_DATA_RATIO), data, dataFonts);
    	}
    	// Bounding box
    	if (boundingBox) {
	    	dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
	    	dc.setPenWidth(1);
	    	dc.drawRectangle(x, y, width, height);
	    }
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
		drawDataField(dc, screenPos, title, data, null, TEXT_FONT_SIZES, true); 
		// Bounding box
    	dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
    	dc.setPenWidth(1);
    	dc.drawRectangle(x, y, width, height);
	}

    // Called when this View is removed from the screen. Save the
    // state of your app here.
    function onHide() {
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
		var grids = new [10];
		var compassWidthPercent = 0.87;
		var compassFieldPercent = 0.5;
		var compassWidth = width*compassWidthPercent;
		var compassHeight = compassWidth;
		var compassX = (width-compassWidth)/2.0;
		var compassY = (height-compassHeight)/2.0;
		var fieldHeight = (height - compassHeight)/2.0;
		var barWidth = (width - compassWidth)/2.0;
		var barWidthOversize = 7;
		// Grid 0 and 1, top two fields
		grids[0] = [0, 0, Math.ceil(width/2), Math.ceil(fieldHeight)];
		grids[1] = [Math.ceil(width/2), 0, Math.ceil(width/2), Math.ceil(fieldHeight)];
		// Grid 5 and 6, bottom two fields
		grids[5] = [0, Math.ceil(fieldHeight+compassHeight), Math.ceil(width/2), Math.ceil(fieldHeight)];
		grids[6] = [Math.ceil(width/2), Math.ceil(fieldHeight+compassHeight), Math.ceil(width/2), Math.ceil(fieldHeight)];
		// Grid 3, main compass rose
		grids[3] = [Math.ceil(compassX), Math.ceil(compassY), Math.ceil(compassWidth), Math.ceil(compassHeight)];
		// Grid 2 and 4, progress bars
		grids[2] = [0, Math.ceil(fieldHeight), Math.ceil(barWidth+barWidthOversize), Math.ceil(compassHeight)];
		grids[4] = [Math.ceil(barWidth+compassWidth-barWidthOversize), Math.ceil(fieldHeight), Math.ceil(barWidth+barWidthOversize), Math.ceil(compassHeight)];
		// Grid 7, field in middle of compass rose
		grids[7] = [Math.ceil(compassX+compassWidth*compassFieldPercent/2.0), Math.ceil(compassY+compassHeight*compassFieldPercent/2.0), Math.ceil(compassWidth*compassFieldPercent), Math.ceil(compassHeight*compassFieldPercent)];	 
		// Grid 8, gust alert status
		grids[8] = [grids[3][0]+0.14*width, grids[3][1]+7, 0, 0];
		// Grid 9, recording status
		grids[9] = [grids[3][0]+0.75*width, grids[3][1]+7, 0, 0];
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
	function drawProgressBar(dc, screenPos, progress, color, boundingBox) {
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
    	var progressHeight = height*progress;
    	// Progress
    	dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    	dc.fillRectangle(x, y+height-progressHeight, width, progressHeight);    
    	// Bounding box
    	if (boundingBox) {
	    	dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
	    	dc.setPenWidth(1);
	    	dc.drawRectangle(x, y, width, height);
	    }
	}	

	// Draw a progress bar
	function drawVarioBar(dc, screenPos, vario, boundingBox) {
		var x = screenPos[0];
    	var y = screenPos[1];
    	var width = screenPos[2];
    	var height = screenPos[3];
    	var centerX = x + width/2;
    	var centerY = y + height/2;
    	var bottomY = y + height;
    	var topY = y;
    	var arrowSpacing = 7;
    	dc.setPenWidth(3);
    	// Cap vario
    	if (vario > VARIO_MAX) {
    		vario = VARIO_MAX;
    	} else if (vario < -VARIO_MAX) {
    		vario = -VARIO_MAX;
    	}
    	// Draw vario arrows
    	if (vario < VARIO_RESOLUTION && vario > -VARIO_RESOLUTION) {
    		dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
    		dc.drawLine(centerX-width/2, centerY, centerX+width/2, centerY);
    	} else {
    		var numArrows = Math.round(Utils.abs(vario) / VARIO_RESOLUTION); 
    		for (var n = 0; n < numArrows; ++n) {
    			if (vario > 0) {
    				var arrowY = centerY-n*arrowSpacing;
    				if (arrowY > topY) {
    					drawVarioArrow(dc, centerX, arrowY, true);
    				} else {
    					System.println("WARNING: Vario arrow out of bounds");
    				}
    			} else {
    				var arrowY = centerY+n*arrowSpacing;
    				if (arrowY < bottomY) {
    					drawVarioArrow(dc, centerX, arrowY, false);
    				} else {
    					System.println("WARNING: Vario arrow out of bounds");
    				}
    			}
    		}
		}
    	// Bounding box
    	if (boundingBox) {
	    	dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
	    	dc.setPenWidth(1);
	    	dc.drawRectangle(x, y, width, height);
	    }
	}	
	
    function drawVarioArrow(dc, x, y, dirUp) {
    	var dimX = 11; //15;
    	var dimY = 8; //10;
    	if (dirUp) {
    		dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
    		dc.drawLine(x, y, x - dimX, y + dimY);
    		dc.drawLine(x, y, x + dimX, y + dimY);
    	} else {
    		dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
    		dc.drawLine(x, y, x - dimX, y - dimY);
    		dc.drawLine(x, y, x + dimX, y - dimY);    	
    	}
    }
    
    function drawRecordingState(dc, screenPos, recording) {
    	var timeNow = Time.now().value();
    	if (recording) {
    		if (timeNow >= recFlashNextUpdate) {
    			recVisible = !recVisible;
    			recFlashNextUpdate = timeNow + REC_FLASH_PERIOD;
    		}
			if (REC_FLASH_PERIOD == 0 || recVisible) {
    			dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
    			dc.fillCircle(screenPos[0], screenPos[1], 9);
    		}
    	} else {
    		dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
    		dc.fillRectangle(screenPos[0]-7, screenPos[1]-7, 14, 14);
    	}
    }

    function drawGustAlarmState(dc, screenPos, gustAlert) {
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
    		dc.fillPolygon([[screenPos[0], screenPos[1]-size], [screenPos[0]-size, screenPos[1]+size], [screenPos[0]+size, screenPos[1]+size]]);  
    	} else if (gustAlert["severity_name"].equals("WARNING")) {
    		if (ALERT_FLASH_PERIOD == 0 || alertVisible) {
	    		dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
	    		dc.fillPolygon([[screenPos[0], screenPos[1]-size], [screenPos[0]-size, screenPos[1]+size], [screenPos[0]+size, screenPos[1]+size]]);	
	    	}	
    	} else if (gustAlert["severity_name"].equals("ALERT")) {
    		if (ALERT_FLASH_PERIOD == 0 || alertVisible) {
	    		dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
	    		dc.fillPolygon([[screenPos[0], screenPos[1]-sizeAlert], [screenPos[0]-sizeAlert, screenPos[1]+sizeAlert], [screenPos[0]+sizeAlert, screenPos[1]+sizeAlert]]);  
	    	}	
    	} else {
    		System.println("Unknown alert name: " + gustAlert["severity_name"]);
    	}
    }
	
}
