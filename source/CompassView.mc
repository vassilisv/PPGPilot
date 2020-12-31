// Based on https://gitlab.com/ravenfeld/Connect-IQ-App-Compass
// Updated to display additional wind specific fields by vassilis@vrhome.net

using Toybox.Application as App;
using Toybox.Graphics as Gfx;

class CompassView {

    hidden var RAY_EARTH = 6378137; 
    hidden var heading_rad = null;

    hidden var northStr="N";
    hidden var eastStr="E";
    hidden var southStr="S";
    hidden var westStr="W";
    hidden var center_x;
	hidden var center_y;
	hidden var size_max;
	
	function initialize(x, y, width, height) {
		size_max = width > height ? height-height*0.025 : width-width*0.025;
    	center_x = x + width / 2;
		center_y = y + height / 2;
	}
          
	function update(dc, heading, homeDirection, windDirection) {  
	    dc.setColor(Gfx.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();  
               
		heading_rad = Math.toRadians(heading);
		if( heading_rad != null) {
			var map_declination = 0;
			if (map_declination != null ) {
				if(map_declination instanceof Toybox.Lang.String) {
					map_declination = map_declination.toFloat();
				}	
				heading_rad= heading_rad+map_declination*Math.PI/180;
			}
			
			if( heading_rad < 0 ) {
				heading_rad = 2*Math.PI+heading_rad;
			}
            							
			var display_logo_orientation = true;
            if( display_logo_orientation ){
            	var logo_orientation=Math.toRadians(homeDirection);
            	drawLogoOrientation(dc, center_x, center_y, size_max, logo_orientation);
			}
			
			var display_text_orientation = false;
			if( display_text_orientation ){
				var y = center_y ;
				var size = size_max;
				drawTextOrientation(dc, center_x, y, size, heading_rad);
			}
						
			var display_compass = true;
			if( display_compass ){
				drawCompass(dc, center_x, center_y, size_max);
			}
			
			drawWindDirection(dc, center_x, center_y, size_max, windDirection);
		}
	}
	
	function drawWindDirection(dc, center_x, center_y, size, direction) {
		var radius = size / 2 - 10;
		var direction_rad = Math.toRadians(direction);
		dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
		var xy1 = pol2Cart(center_x, center_y, direction_rad, radius-radius/2.5);
		var xy2 = pol2Cart(center_x, center_y, direction_rad-Math.PI/25, radius-radius/10);
		var xy3 = pol2Cart(center_x, center_y, direction_rad+Math.PI/25, radius-radius/10);
		dc.fillPolygon([xy1, xy2, xy3]);
	}
	
	function drawTextSpeed(dc, center_x, center_y, size, speed){
		var color = Graphics.COLOR_LT_GRAY;
		var fontMetric = Graphics.FONT_TINY;
		var speedStr=Lang.format("$1$", [speed.format("%.1f")]);
		var font = Graphics.FONT_NUMBER_HOT ;
		
		dc.setColor(color, Graphics.COLOR_TRANSPARENT);
		dc.drawText(center_x, center_y, font, speedStr, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		
		var text_width = dc.getTextWidthInPixels(speedStr, font);
		var text_height =dc.getFontHeight(font);
		dc.drawText(center_x+text_width/2+2, center_y-text_height/4+2, fontMetric, "mph", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		
	}
    
	function drawTextOrientation(dc, center_x, center_y, size, orientation){
		var color = Graphics.COLOR_LT_GRAY;
		var fontOrientaion;
		var fontMetric = Graphics.FONT_TINY;

       	if( orientation < 0 ) {
				orientation = 2*Math.PI+orientation;
		}
		var orientationStr=Lang.format("$1$", [(orientation*180/Math.PI).format("%d")]);
		
		fontOrientaion = Graphics.FONT_NUMBER_THAI_HOT ;
		
		dc.setColor(color, Graphics.COLOR_TRANSPARENT);
		dc.drawText(center_x, center_y, fontOrientaion, orientationStr, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		
		var text_width = dc.getTextWidthInPixels(orientationStr, fontOrientaion);
		var text_height =dc.getFontHeight(fontOrientaion);
		dc.drawText(center_x+text_width/2+2, center_y-text_height/4+2, fontMetric, "o", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		
	}
	   
	function drawCompass(dc, center_x, center_y, size) {
		var colorText = Graphics.COLOR_WHITE;
		var colorTextNorth = Graphics.COLOR_WHITE;
		var colorCompass = Graphics.COLOR_RED;
		
		var size_text = 1;
		var radius;
		var font;
		var step;
		if(size_text==0){
			radius= size/2-10;
			font=Graphics.FONT_SMALL;
			step = 8;
		}else if(size_text==1){
			radius= size/2-12;
			font=Graphics.FONT_MEDIUM;
			step = 10;
		}else{
			radius= size/2-16;
			font=Graphics.FONT_LARGE;
			step = 14;
		}
		 
		var penWidth = 8;

		dc.setColor(colorTextNorth, Graphics.COLOR_TRANSPARENT);
		drawTextPolar(dc, center_x, center_y, heading_rad, radius, font, northStr);
             
		dc.setColor(colorText, Graphics.COLOR_TRANSPARENT);
		drawTextPolar(dc, center_x, center_y, heading_rad + 3*Math.PI/2, radius, font, eastStr);
        
		dc.setColor(colorText, Graphics.COLOR_TRANSPARENT);
		drawTextPolar(dc, center_x, center_y, heading_rad+ Math.PI, radius, font, southStr);

		dc.setColor(colorText, Graphics.COLOR_TRANSPARENT);
		drawTextPolar(dc, center_x, center_y, heading_rad+ Math.PI / 2, radius, font, westStr);
        
		var startAngle = heading_rad*180/Math.PI - step;
		var endAngle = heading_rad*180/Math.PI + 90+ step;
       	dc.setColor(colorCompass, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(penWidth);
		for( var i = 0; i < 4; i++ ) {
			dc.drawArc(center_x, center_y, radius, Gfx.ARC_CLOCKWISE, 90+startAngle-i*90, (360-90+endAngle.toLong()-i*90)%360 );
		}
		
		dc.setPenWidth(penWidth/4);
		for( var i = 0; i < 12; i++) {
			if( i % 3 != 0 ) {
				var xy1 = pol2Cart(center_x, center_y, heading_rad+i*Math.PI/6, radius);
				var xy2 = pol2Cart(center_x, center_y, heading_rad+i*Math.PI/6, radius-radius/10);
				dc.drawLine(xy1[0],xy1[1],xy2[0],xy2[1]);
			}
		}  		    
	}
    
	function drawLogoOrientation(dc, center_x, center_y, size, orientation){
		var color = Graphics.COLOR_RED;
		var radius=size/3.10;
		
		dc.setColor(color, Graphics.COLOR_TRANSPARENT);
	
		var xy1 = pol2Cart(center_x, center_y, orientation, radius);
		var xy2 = pol2Cart(center_x, center_y, orientation+135*Math.PI/180, radius);
		var xy3 = pol2Cart(center_x, center_y, orientation+171*Math.PI/180, radius/2.5);
		var xy4 = pol2Cart(center_x, center_y, orientation, radius/3);
		var xy5 = pol2Cart(center_x, center_y, orientation+189*Math.PI/180, radius/2.5);
		var xy6 = pol2Cart(center_x, center_y, orientation+225*Math.PI/180, radius);
		dc.fillPolygon([xy1, xy2, xy3, xy4, xy5, xy6]);
	}
    
	function drawTextPolar(dc, center_x, center_y, radian, radius, font, text) {
		var xy = pol2Cart(center_x, center_y, radian, radius);
		dc.drawText(xy[0], xy[1], font, text, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
	}
    
	function pol2Cart(center_x, center_y, radian, radius) {
		var x = center_x - radius * Math.sin(radian);
		var y = center_y - radius * Math.cos(radian);
		 
		return [Math.ceil(x), Math.ceil(y)];
	}
     
}
