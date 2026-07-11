This project is a simple Windows batch script for continuous recording from an RTSP camera using FFmpeg.

Features:

* Automatic reconnection if the camera goes offline
* RTSP port and ping checks
* Recording without video re-encoding
* Automatic splitting into 10-minute video files
* Separate event and FFmpeg logs
* Increasing reconnect delay after repeated failures
