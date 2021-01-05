#!/usr/bin/env bash

# Make sure we are in the correct directory
DIRNAME=$(dirname "$0")
cd $DIRNAME/..

source functions/define_colors
source functions/define_files
source functions/load_functions

# trap ctrl-c and call cleanup
trap cleanup INT
#
function cleanup() {
    exit 130
}

printf "==> Testing ${RED}iQuery.sh${NO_COLOR}.\n\n"
printf "First, print the help file...\n"
./iQuery.sh -h
waitUntil -k
clear

# Then run queries until ^C
while true; do
    ./iQuery.sh
    printf "\n"
done
