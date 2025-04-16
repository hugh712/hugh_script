#!/bin/bash

echo "Starting script..."

count_file_error=~/.stress_config/count_error
count_file_log=~/.stress_config/error_log
success_hooks=()
failed_hooks=()

# ensure the errormessages files exist
if [ ! -f "$count_file_error" ]; then
    echo 0 > "$count_file_error"
fi

# clear previous error log
> "$count_file_log"

for script_file in hook/*; do
    echo "Running script: ${script_file}"

    output=$(bash "$script_file" 2>&1)
    exit_code=$?

    echo "$output"

    if [[ "$exit_code" == 0 ]]; then
        success_hooks+=("$script_file")
    else
        error_msg="Error occurred while running ${script_file}"
        echo "$error_msg" | tee -a "$count_file_log"
        echo "--- Output from ${script_file} ---" >> "$count_file_log"
        echo "$output" >> "$count_file_log"
        echo "" >> "$count_file_log"

        # add failed count
        count_error=$(cat "$count_file_error")
        count_error=$((count_error + 1))
        echo $count_error > "$count_file_error"

        failed_hooks+=("$script_file")
    fi
done

echo "----------------------------------"
echo "Hook Execution Summary:"
echo "Successful hooks:"
for hook in "${success_hooks[@]}"; do
    echo "   - $hook"
done

echo "Failed hooks:"
for hook in "${failed_hooks[@]}"; do
    echo "   - $hook"
done

if [ ${#failed_hooks[@]} -gt 0 ]; then
    echo -e "\033[0;31mSome hooks failed. Check ~/.stress_config/error_log for details.\033[0m"
    exit 1
else
    echo "All hooks executed successfully!"
    exit 0
fi