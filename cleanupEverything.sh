#!/usr/bin/env bash
#
# Remove all files and directories created by running scripts

# Make sure we are in the correct directory
DIRNAME=$(dirname "$0")
cd $DIRNAME
export LC_COLLATE="C"
source functions/define_colors
source functions/define_files
source functions/load_functions

function help() {
    cat <<EOF
cleanupEverything.sh -- Deveoper script: Remove files generated by other scripts.

This script makes it easier for developers to get rid of files generated by
running other scripts.  It will first ask if you want to delete EVERYTHING,
which will reset this directory to the state a completely new user would
encounter. You can't undo this.

If you hit <cr> or answer "no". It will give you the choice of deleting various
types of files. It always defaults to "No", so just hit <cr> to see what your
choices would be. Or look at the source code for this script.

USAGE:
    ./cleanupEverything.sh [OPTIONS]

OPTIONS:
    -h      Print this message.
    -i      Request confirmation before attempting to remove each file
    -v      Be verbose when deleting files, showing them as they are removed.
EOF
}

function deleteFiles() {
    printf "Deleting ...\n"
    # Don't quote $@. Globbing needs to take place here.
    rm -rf $ASK $TELL $@
    printf "\n"
}

# Allow switches -v or -i to be passed to the rm command
while getopts ":hiv" opt; do
    case $opt in
    h)
        help
        exit
        ;;
    i)
        ASK="-i"
        ;;
    v)
        TELL="-v"
        ;;
    \?)
        printf "Ignoring invalid option: -$OPTARG\n\n" >&2
        ;;
    esac
done
shift $((OPTIND - 1))

# Quote filenames so globbing takes place in the "deleteFiles" function,
# i.e. the function is passed the number of parameters seen below, not
# the expanded list which could be quite long.
if waitUntil -N "${RED}Delete EVERYTHING created by scripts and users?${NO_COLOR}"; then
    deleteFiles "Shows-*.csv" "Credits-*.csv" "Persons-KnownFor*.csv" "AssociatedTitles*.csv" \
        "LinksToPersons*.csv" "LinksToTitles*.csv" "uniq*.txt" "secondary" "diffs*.txt" \
        "baseline" "test_results" "*.tsv.gz" "*.tconst" "*.xlate" ".xref_*"
else
    printf "Skipping...\n"
fi

if waitUntil -N "Delete primary spreadsheets that contain information on credits, shows, and episodes?"; then
    deleteFiles "Shows-*.csv" "Credits-*.csv" "Persons-KnownFor*.csv" "AssociatedTitles*.csv"
else
    printf "Skipping...\n"
fi

if waitUntil -N "Delete smaller files that only contain lists of persons and shows?"; then
    deleteFiles "LinksToPersons*.csv" "LinksToTitles*.csv" "uniq*.txt"
else
    printf "Skipping...\n"
fi

if waitUntil -N "Delete all files generated during debugging?"; then
    deleteFiles "secondary" "diffs*.txt" "baseline" "test_results"
else
    printf "Skipping...\n"
fi

if waitUntil -N "Delete all the .gz files downloaded from IMDb?"; then
    deleteFiles "*.tsv.gz"
else
    printf "Skipping...\n"
fi

printf "\n[${RED}Warning${NO_COLOR}] The following files are usually manually created. They are ignored by git.\n"

if waitUntil -N "Delete all manually maintained .tconst and .xlate files?"; then
    deleteFiles "*.tconst" "*.xlate"
else
    printf "Skipping...\n"
fi

if waitUntil -N "Delete all user configuration (.xref_*) files?"; then
    deleteFiles ".xref_*"
else
    printf "Skipping...\n"
fi
