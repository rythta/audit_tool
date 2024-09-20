#!/bin/bash
cd "$(dirname "$0")"
./run_tests.sh &
PID=$!
sleep 2
echo -e "\e[48;5;15m\e[2J" > /dev/tty2
chvt 2
echo -e "\e[H\e[30m" > /dev/tty2
echo -e "1/3 Initiating hardware/network discovery..." > /dev/tty2
echo -e "- Consider pressing the network toggle key" > /dev/tty2
./networking.sh
wait $PID


echo -e "2/3 Attempting to pull updates." > /dev/tty2
TIMEOUT_DURATION=60
output=$(timeout $TIMEOUT_DURATION git pull)
pull_exit_code=$?
if [ $pull_exit_code -eq 124 ]; then
    echo -e "Git pull timed out after $TIMEOUT_DURATION seconds." > /dev/tty2
elif [ $pull_exit_code -ne 0 ]; then
    echo -e "Git pull failed with exit code $pull_exit_code." > /dev/tty2
elif [[ ! $output == *"Already up-to-date"* ]] && [[ ! $output == *"Already up to date"* ]]; then
    echo -e "Pulled updates." > /dev/tty2
    lbu_commit
else
    echo -e "No updates." > /dev/tty2
fi
echo -e "3/3 Hardware discovery finished. Powering off..." > /dev/tty2
poweroff
