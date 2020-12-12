using Toybox.Application;
using Toybox.System;

class PPGPilotApp extends Application.AppBase {
	var mainView;
	var viewDelegate;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    	if (mainView != null) {
    		mainView.onStop();
    	}
    }

    // Return the initial view of your application here
    function getInitialView() {
    	// Determine screen shape to decide which view to create
    	var settings = System.getDeviceSettings();
    	if (settings.screenShape == 1) {
    		System.println("Starting round screen view");
        	mainView = new PPGPilotRoundView();
        } else if (settings.screenShape == 3) {
    		System.println("Starting rectangular screen view");
        	mainView = new PPGPilotRectView();        
        } else {
        	System.println("Screen type not known: " + settings.screenShape);
        }
        viewDelegate = new PPGPilotDelegate( mainView );
        return [mainView, viewDelegate];
    }

} 