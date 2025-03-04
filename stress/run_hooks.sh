#!/bin/bash

set -e

echo "Starting script..."

count_file_error=~/.stress_config/count_error
count_file_log=~/.stress_config/error_log

# ensure the errormessages files exist
if [ ! -f "$count_file_error" ]; then
    echo 0 > "$count_file_error"
fi

for script_file in hook/*; do
    echo "Running script: ${script_file}"
    bash "$script_file"

    if [[ "$?" != 0 ]]; then
        error_msg="Error occurred while running ${script_file}"
        echo "$error_msg" | tee -a "$count_file_log"

        # error counts
        count_error=$(cat "$count_file_error")
        count_error=$((count_error + 1))
        echo $count_error > "$count_file_error"

        # execute next hook
        continue
    fi
done

echo "All hooks executed!"
