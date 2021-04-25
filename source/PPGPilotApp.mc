using Toybox.Application;
using Toybox.System;
using Toybox.Timer;

class PPGPilotApp extends Application.AppBase {
	var views;
	var viewDelegate;
	var pilot;
	var refreshTimer;

    function initialize() {
        AppBase.initialize();
    } 

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    	if (pilot != null) {
    		pilot.stopSession();
    	}
    }

    // Return the initial view of your application here
    function getInitialView() {
    	// Setup PPGPilot
        pilot = new PPGPilot();
        // Setup refresh timer
        refreshTimer = new Timer.Timer();
        refreshTimer.start(method(:timerCallback), 500, true);
        // Setup views
        views = [];
    	// Determine screen shape to decide which main view to create
    	var settings = System.getDeviceSettings();
    	if (settings.screenShape == 1) {
    		System.println("Starting round screen view (" + settings.screenWidth + "x" + settings.screenHeight + ")");
    		views.add( new PPGPilotRoundView(pilot) );
        	views.add( new PPGPilotRoundWindGustView(pilot) );
        } else if (settings.screenShape == 3) {
    		System.println("Starting rectangular screen view (" + settings.screenWidth + "x" + settings.screenHeight + ")");
        	views.add( new PPGPilotRectView(pilot) );  
        	views.add( new PPGPilotRectWindGustView(pilot) );      
        } else {
        	System.println("Screen type not known: " + settings.screenShape + " (" + settings.screenWidth + "x" + settings.screenHeight + ")");
        }
        // Create map view (TODO: not fully implemented yet, requires SDK >v3)
        //views.add( new PPGMapView(pilot) );            
        // Done
        viewDelegate = new PPGPilotDelegate( views, pilot );
        return [views[0], viewDelegate];
    }
    
	// Refresh screen
    function timerCallback() {
        WatchUi.requestUpdate();
    }

} 