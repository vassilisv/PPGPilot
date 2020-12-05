using Toybox.Application;

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
        mainView = new PPGPilotView();
        viewDelegate = new PPGPilotDelegate( mainView );
        return [mainView, viewDelegate];
    }

}