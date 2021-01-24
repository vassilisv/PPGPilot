using Toybox.WatchUi as Ui;
using Toybox.Position as Position;
using Toybox.Graphics as Gfx;

class PPGMapView extends Ui.MapView {
	var pilot;
	var locationHistory;

    function initialize(pilot) {
        MapView.initialize();
        
        // Save pilot instance
        self.pilot = pilot;
        
        // Init location history
        locationHistory = [];

        // set the current mode 
        setMapMode(Ui.MAP_MODE_PREVIEW);

		// Setup map at default location
		var initLocation = new Position.Location({:latitude => 38.85508, :longitude =>-94.79959, :format => :degrees});
        var topLeft = initLocation.getProjectedLocation(Math.toRadians(315), 1000);
        var bottomRight = initLocation.getProjectedLocation(Math.toRadians(135), 1000);
        setMapVisibleArea(topLeft, bottomRight);
		setScreenVisibleArea(0, 0, System.getDeviceSettings().screenWidth, System.getDeviceSettings().screenHeight);
    }

    // Load your resources here
    function onLayout(dc) {
    	System.println("Setting up new map layout");
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    // Update the view
    function onUpdate(dc) {
    	clear();        
        // Update only we have a fix
        if (pilot.gotGPSFix) {    
	        // Center map and zoom on current position
	        var topLeft = pilot.posInfo.position.getProjectedLocation(Math.toRadians(315), 1000);
	        var bottomRight = pilot.posInfo.position.getProjectedLocation(Math.toRadians(135), 1000);
	        setMapVisibleArea(topLeft, bottomRight);
	        
	        // Update breadcrumb
	        locationHistory.add(pilot.posInfo.position);
	        if (locationHistory.size() > 2) {
		        var polyline = new Ui.MapPolyline();
		        polyline.setColor(Gfx.COLOR_RED);
		        polyline.setWidth(2);
		        for (var i = 0; i < locationHistory.size(); ++i) {
		        	polyline.addLocation(locationHistory[i]);
		        }
		        setPolyline(polyline);
		    }
		    
		    // Set markers for current position
		    var markers = [];
		    var nowMarker = new Ui.MapMarker(pilot.posInfo.position);
		    nowMarker.setIcon(Ui.MAP_MARKER_ICON_PIN, 0, 0);
		    markers.add(nowMarker);
		    setMapMarker(markers);
		    
		    // Set size
		    setScreenVisibleArea(0, 0, System.getDeviceSettings().screenWidth, System.getDeviceSettings().screenHeight);	   
		}
		
		// Call the parent onUpdate function to redraw the layout
		setMapMode(Ui.MAP_MODE_PREVIEW);
        MapView.onUpdate(dc);	                  
    }
}