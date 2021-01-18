# PPGPilot

Garmin Connect IQ app for Powered Paragliding Pilots (PPG). Displays information needed in most flights like speed, altitude and direction to home (launch). In addition it calculates the wind direction and speed by just using GPS ground speed and direction. Since this is an indirect measurement the estimate improves as the pilot changes direction of flight. To get an accurate initial estimate a full circle should be flown.   

The estimated wind speed and direction is also used to improve the time to home calculation. 

At the end of the flight the log is recorded in Garmin Connect as a new activity.

Some features, like wind estimation and flight recording, are only enabled after takeoff has been detected.

There are two app layouts, one for round displays and another for rectangular.

The Fenix 3 layout, explained.

![Fenix 3](doc/fenix3_explained.png)

The Oregon layout.

![Oregon](doc/oregon.PNG)
 
# Installation

The app was originally developed for personal use so it is not yet submitted to the Garmin IQ app store. This app is still being tested and __should not be used as the primary flight instrument__!

To manually install PPGPilot in your device, do the following:
* Connect your device to a computer using a USB cable, the device should appear as a new drive (e.g. D:\ on Windows)
* Download the app binary from your device from the latest [Releases](https://github.com/vassilisv/PPGPilot/releases)
* Select the binary for your device type and rename it to PPGPilot.prg
* Copy the app binary to the _D:\GARMIN\APPS_ directory of your device (adjust drive letter as needed)
* Eject the drive, don't just unplug the device

The app should appear in the list of Connect IQ apps or activities menu. If you can't find your device in the releases, you can either compile it yourself using the Garmin IQ SDK or submit an issue.

# To Do

- Use forecasted wind direction and speed to initialize before takeoff
- Add options menu (desired flight duration etc)
- Use sunset to cap flight duration if flying in evenings
- Display map (for devices that support it)
- Display additional fields in new screen (e.g. time to sundown, air speed, estimated speed to home, wind estimation bins, time of day)

