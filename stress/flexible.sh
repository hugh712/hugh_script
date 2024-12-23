# setup runtime script
sudo bash -c "cat >/usr/bin/run_shutdown_stress" <<"EOF"
#!/bin/bash
...

# define a function to handle the error message
handle_error_message() {
    local err_message="$1"
    output_message="$output_message, \n$err_message"
    echo "$err_message" >> "$count_file_log"
    count_error=$((count_error + 1))
    echo $count_error > $count_file_error
    if [ "$err_stop" == 1 ]; then
        do_stop=1
    fi
}

# define an array of error messages
error_messages=(
    "iwlwifi" "failed"
    "Bluetooth" "fail"
)

# loop through the error messages and handle each one
for error_message in "${error_messages[@]}"; do
    err_m=$(sudo dmesg | grep "$error_message" | grep -i "failed")
    if [[ -n "$err_m" ]]; then
        count_error=$((count_error + 1))
        output_message="Err detected! $err_m \n "
        echo "$err_m" >> "$count_file_log"
        echo $count_error > $count_file_error
        if [ "$err_stop" == 1 ]; then
            do_stop=1
        fi
    fi
done


if [ "$do_stop" == 1 ]; then
    exit 0
fi

...

EOF
