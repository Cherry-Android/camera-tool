#!/bin/bash

INSTALL_APP="/data/khuongtrinh2/Open_Camera.apk"
PACKAGE="net.sourceforge.opencamera"
ACTIVITY=".MainActivity"
SAVE_PATH="/storage/emulated/0/DCIM/OpenCamera"
PACKAGE_CHECK="package:net.sourceforge.opencamera"
PREF_FILE="/data/data/net.sourceforge.opencamera/shared_prefs/net.sourceforge.opencamera_preferences.xml"

DEVICE_ID="$1"
MODE="$2"  # capture | record
shift 2

resolution=("1920x1080" "1600x896" "1280x720" "1024x576" "960x540" "800x600" \
            "800x448" "640x480" "640x360" "480x270" "424x240" "352x288" \
            "320x240" "320x180" "176x144")

# Validate input
if [ -z "$DEVICE_ID" ]; then
    echo "Usage: $0 <serial>"
    exit 1
fi

# Optional: Check if adb is available
if ! command -v adb &>/dev/null; then
    echo "adb not found. Please ensure you have adb."
    exit 1
fi

#Show camera resolution
show_camera_resolutions() {
        echo "📸 Supported video resolutions:"
        ./adb -s "$DEVICE_ID" shell dumpsys media.camera \
                | grep "video-size-values" \
                | sed -E 's/.*video-size-values: //; s/,/ /g'
}

# Check app was install 
if adb -s "$DEVICE_ID" shell pm list packages | grep -q "$PACKAGE_CHECK"; then
   echo "✅ OpenCamera app already installed. Skipping installation."
else
   echo "Install OpenCamera app"
   ./adb -s $DEVICE_ID install -g $INSTALL_APP
   if [ $? -ne 0 ]; then
      echo "❌ Installation failed!"
      exit 1
   fi
fi

# Set capture resolution
set_capture_resolution() {
	local INPUT="$1"
	./adb -s "$DEVICE_ID" root >/dev/null 2>&1

	local RES
	case "$INPUT" in
		1920x1080) RES="1920 1080" ;;
		1600x896)  RES="1600 896"  ;;
		1280x720)  RES="1280 720"  ;;
		1024x576)  RES="1024 576"  ;;
		960x540)   RES="960 540"   ;;
		800x600)   RES="800 600"   ;;
		848x480)   RES="848 480"   ;;
		800x448)   RES="800 448"   ;;
		640x480)   RES="640 480"   ;;
		640x360)   RES="640 360"   ;;
		480x270)   RES="480 270"   ;;
		424x240)   RES="424 240"   ;;
		352x288)   RES="352 288"   ;;
		320x240)   RES="320 240"   ;;
		320x180)   RES="320 180"   ;;
		176x144)   RES="176 144"   ;;
		*) echo "❌ Unknown resolution: $INPUT"; return 1 ;;
	esac
	
	# Update resolution and force-stop app
	./adb -s "$DEVICE_ID" shell \
		"sed -i 's|<string name=\"camera_resolution_0\">.*</string>|<string name=\"camera_resolution_0\">$RES</string>|' $PREF_FILE"
	./adb -s "$DEVICE_ID" shell am force-stop net.sourceforge.opencamera
	sleep 2

	local RES_RAW
	RES_RAW=$(./adb -s "$DEVICE_ID" shell "grep 'camera_resolution_0' '$PREF_FILE'")

	local CUR_RES
	CUR_RES=$(echo "$RES_RAW" | sed -nE 's/.*>(.*)<.*/\1/p')
	if [ -n "$CUR_RES" ]; then
		echo "current resolution: $CUR_RES"
		return
	fi
	echo "current resolution: $CUR_RES"
}
# Set video resolution
set_video_resolution() {
	local INPUT="$1"
	./adb -s "$DEVICE_ID" root >/dev/null 2>&1
	
	local RES
        case "$INPUT" in
                1920x1080) RES="1" ;;
                1280x720)  RES="5" ;;
		640x480)   RES="4" ;;
		176x144)   RES="2" ;;
                1600x896)  RES="5_r1600x896" ;;
		1024x576)  RES="4_r1024x576" ;;
		960x540)   RES="4_r960x540"  ;;
		800x600)   RES="4_r800x600"  ;;
		848x480)   RES="4_r848x480"  ;;
		800x448)   RES="4_r848x480"  ;;
		640x360)   RES="2_r640x360"  ;;
		480x270)   RES="2_r640x360"  ;;
		424x240)   RES="2_r424x240"  ;;
		352x288)   RES="2_r352x288"  ;;
		320x240)   RES="2_r320x240"  ;;
		320x180)   RES="2_r320x180"  ;;
                *) echo "❌ Unknown resolution: $INPUT"; return 1 ;;
        esac

	# Update resolution and force-stop app
	./adb -s "$DEVICE_ID" shell \
		"sed -i 's|<string name=\"video_quality_0\">.*</string>|<string name=\"video_quality_0\">$RES</string>|' $PREF_FILE"
	./adb -s "$DEVICE_ID" shell am force-stop net.sourceforge.opencamera
	sleep 2
	
	local RES_RAW
	RES_RAW=$(./adb -s "$DEVICE_ID" shell "grep 'video_quality_0' '$PREF_FILE'")

	local CUR_RES
	CUR_RES=$(echo "$RES_RAW" | sed -nE 's/.*_r([0-9]+x[0-9]+).*/\1/p')
	if [ -n "$CUR_RES" ]; then
		echo "current resolution: $CUR_RES"
		return
	fi

	ID=$(echo "$RES_RAW" | sed -nE 's/.*>([0-9]+)<.*/\1/p')
	case "$ID" in
		1) CUR_RES="1920x1080" ;;
		5) CUR_RES="1280x720"  ;;
		4) CUR_RES="640x480"   ;;
		2) CUR_RES="176x144"   ;;
	esac
	echo "current resolution: $CUR_RES"
}

# Scroll up main GUI
./adb -s $DEVICE_ID shell input swipe 1243 980 1145 111
sleep 1

capture_camera() {

	local NUM_CAPTURE=$1

        echo "Open Opencamera app ..."
        ./adb -s $DEVICE_ID shell am start -n $PACKAGE/$ACTIVITY
        sleep 2
    
        # Get number of files before capturing
        local before_count
        before_count=$(adb -s "$DEVICE_ID" shell ls "$SAVE_PATH" 2>/dev/null | wc -l)
        echo "📂 Number of image before capture: $before_count"
   
	# capture image
	for element in "${resolution[@]}"
	do
		current=$(set_capture_resolution "$element")
		# Switch capture mode
		./adb -s $DEVICE_ID shell am start -a android.media.action.STILL_IMAGE_CAMERA
		sleep 1
		echo "Capture with $current"
        	for i in $(seq 1 $NUM_CAPTURE); do
            		echo "Capturing picture $i ..."
			sleep 1
            		./adb -s $DEVICE_ID shell input tap 1855 511
            		sleep 2 # save image
        	done
    	done
        # Get the number of files after capturing
        local after_count
        after_count=$(adb -s "$DEVICE_ID" shell ls "$SAVE_PATH" 2>/dev/null | wc -l)
        echo "📂 Files after capture: $after_count"
    
        # Check the difference
        local diff=$((after_count - before_count))
        if [ "$diff" -ne "$NUM_CAPTURE" ]; then
    	   echo "❌ FAIL: Expected $NUM_CAPTURE new files, but got $diff"
    	   exit 1
        else
    	   echo "✅ PASS: Captured $NUM_CAPTURE pictures correctly"
        fi
    
	# Close Opencamera app
        echo "Close Opencamera app ..."
        ./adb -s "$DEVICE_ID" shell am force-stop $PACKAGE
        sleep 1
}

record_camera() {

	local total_time=0
#	local resolution=$1
	local duration=$1 # 1s, 1m, 1h
	# Get total time before recording video
        for INPUT in "$duration"; do
            if [[ $INPUT =~ ^([0-9]+)s$ ]]; then
                total_time=$((total_time + ${BASH_REMATCH[1]}))
            elif [[ $INPUT =~ ^([0-9]+)m$ ]]; then
                total_time=$((total_time + ${BASH_REMATCH[1]} * 60))
            elif [[ $INPUT =~ ^([0-9]+)h$ ]]; then
                total_time=$((total_time + ${BASH_REMATCH[1]} * 3600))
            else
                echo "❌ Invalid time format: $INPUT (use Ns / Nm / Nh)"
                exit 1
            fi
        done
        echo "Total record time = $total_time seconds"
 	
	echo "======================================="

	# Open camera app ver 1.53.1
	echo "Open OpenCamera app..."
	./adb -s $DEVICE_ID shell am start -n $PACKAGE/$ACTIVITY
	sleep 2

	for element in "${resolution[@]}"
	do
		current=$(set_video_resolution "$element")
		echo "Start recording with $current"
		./adb -s $DEVICE_ID shell am start -a android.media.action.VIDEO_CAMERA
		sleep 2
		./adb -s $DEVICE_ID shell input tap 1855 511
		sleep $total_time
		sleep 2

		echo "Stop record video ..."
		./adb -s $DEVICE_ID shell input tap 1855 511
		sleep 2
		./adb -s "$DEVICE_ID" shell input keyevent KEYCODE_BACK
		echo "======================================="
	done
}

case $MODE in 
	capture)
		capture_camera "$1"
		;;
	record)
		record_camera "$1"
		;;

	*)
		echo "❌ Invalid mode: $MODE (use capture|record)"
		exit 1
		;;
esac

echo "✅ Finished"
