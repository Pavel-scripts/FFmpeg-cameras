This project contains two Windows batch scripts for camera recording and storage cleanup.

Files:

* `cameras.bat` - continuously records RTSP camera streams using FFmpeg, automatically reconnects after connection failures, creates segmented `.ts` video files, and writes logs.
* `delete.bat` - automatically deletes old `.ts` recordings, clears a recycle folder, removes empty folders, and runs cleanup at a configurable interval.

Features:

* Continuous RTSP camera recording
* Automatic FFmpeg reconnection
* Segmented video files
* Recording and FFmpeg logs
* Configurable recording folders
* Configurable file retention period
* Configurable cleanup interval
* Support for multiple camera folders
