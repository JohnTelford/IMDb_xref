#!/usr/bin/env bash
# Count the instances of any "word" in downloaded IMDb data files

# INVOCATION:
#    ./countIMDbInstances.sh tt5123128 nm1524628
#    ./countIMDbInstances.sh Catarella

# Make sure we are in the correct directory
DIRNAME=$(dirname "$0")
cd "$DIRNAME"
export LC_COLLATE="C"
source functions/define_colors
source functions/define_files
source functions/load_functions

# Make sure we can execute rg.
checkForExecutable rg

for srchString in "$@"; do
    for file in $(ls *.tsv.gz); do
        count=$(rg -wcz "$srchString" $file)
        if [ "$count" == "" ]; then
            count=0
        fi
        printf "%-10s %5d  %s\n" "$srchString" $count $file
    done
    printf "\n"
done
