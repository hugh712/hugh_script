#!/bin/bash
me=$(basename "$0")
echo "checking $me"

# check output audio device
if ! aplay -l | grep -i "card" &>/dev/null; then
    echo "Error: No audio output device found"
    exit 1
fi

# check microphone input device
if ! arecord -l | grep -i "card" &>/dev/null; then
    echo "Error: No audio input device (mic) found"
    exit 1
fi

echo "Audio input/output devices detected"
exit 0
