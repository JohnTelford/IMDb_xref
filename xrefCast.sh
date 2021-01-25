#!/usr/bin/env bash
#
# Find common cast members between multiple shows
#
# NOTES:
#   Requires cast member files produced by generateXrefData.sh
#   Note: Cast member data from IMDb sometimes has errors or omissions
#
#   To help refine searches, the output is rather wordy (unless the -m option is used).
#   The final section (Multiply occurring names) is the section of highest interest.
#
#   It may help to start with an actor or character, e.g.
#       ./xrefCast.sh 'Olivia Colman'
#       ./xrefCast.sh 'Queen Elizabeth II' 'Princess Diana'
#
#   Then move to more complex queries that expose other common cast members
#       ./xrefCast.sh 'The Crown'
#       ./xrefCast.sh -m 'The Night Manager' 'The Crown' 'The Durrells in Corfu'
#
#   Experiment to find the most useful results.

# Make sure we are in the correct directory
DIRNAME=$(dirname "$0")
cd "$DIRNAME"
source functions/define_colors
source functions/define_files
source functions/load_functions

function help() {
    cat <<EOF
xrefCast.sh -- Cross-reference shows, actors, and the characters they portray using IMDB data.

If you don't enter a search term on the command line, you'll be prompted for input.

USAGE:
    ./xrefCast.sh [OPTIONS] [-f SEARCH_FILE] [SEARCH_TERM ...]

OPTIONS:
    -h      Print this message.
    -a      All -- Only print 'All names' section.
    -f      File -- Query a specific file rather than "Credits-Person*csv".
    -m      Multiples -- Only print names that appear multiple times
    -i      Print info about any files that are searched.
    -n      No loop - don't offer to do another search upon exit

EXAMPLES:
    ./xrefCast.sh "Olivia Colman"
    ./xrefCast.sh "Queen Elizabeth II" "Princess Diana"
    ./xrefCast.sh "The Crown"
    ./xrefCast.sh -m "The Night Manager" "The Crown" "The Durrells in Corfu"
    ./xrefCast.sh -mn "Elizabeth Debicki"
    ./xrefCast.sh -af Clooney.csv "Brad Pitt"
EOF
}

# Don't leave tempfiles around
trap terminate EXIT
#
function terminate() {
    if [ -n "$DEBUG" ]; then
        printf "\nTerminating: $(basename $0)\n" >&2
        printf "Not removing:\n" >&2
        printf "$TMPFILE $SEARCH_TERMS $ALL_NAMES $MULTIPLE_NAMES\n" >&2
    else
        rm -rf $TMPFILE $SEARCH_TERMS $ALL_NAMES $MULTIPLE_NAMES
    fi
}

# trap ctrl-c and call cleanup
trap cleanup INT
#
function cleanup() {
    printf "\nCtrl-C detected. Exiting.\n" >&2
    exit 130
}

# Shoud we loop or not? Loop unless we were called with -n
function loopOrExitP() {
    [ -n "$noLoop" ] && exit
    if waitUntil $ynPref -N "\n==> Would you like to do another search?"; then
        printf "\n"
        terminate
        [ -n "$SEARCH_FILE" ] && exec ./xrefCast.sh -f "$SEARCH_FILE"
        exec ./xrefCast.sh
    else
        printf "Quitting...\n"
        exit
    fi
}

while getopts ":f:hamin" opt; do
    case $opt in
    h)
        help
        exit
        ;;
    a)
        ALL_NAMES_ONLY="yes"
        ;;
    m)
        MULTIPLE_NAMES_ONLY="yes"
        ;;
    i)
        INFO="yes"
        ;;
    n)
        noLoop="yes"
        ;;
    f)
        SEARCH_FILE="$OPTARG"
        ;;
    \?)
        printf "==> Ignoring invalid option: -$OPTARG\n\n" >&2
        ;;
    :)
        printf "==> Option -$OPTARG requires a 'translation file' argument'.\n\n" >&2
        exit 1
        ;;
    esac
done
shift $((OPTIND - 1))

# Make sure prerequisites are satisfied
ensurePrerequisites

# Need some tempfiles
TMPFILE=$(mktemp)
SEARCH_TERMS=$(mktemp)
ALL_NAMES=$(mktemp)
MULTIPLE_NAMES=$(mktemp)

# If a SEARCH_FILE was specified...
if [ -n "$SEARCH_FILE" ]; then
    # Make sure it exists, no way to recover
    if [ ! -e "$SEARCH_FILE" ]; then
        printf "==> [${RED}Error${NO_COLOR}] Missing search file: $SEARCH_FILE\n\n" >&2
        loopOrExitP
    fi
else
    SEARCH_FILE="Credits-Person.csv"
    # If it doesn't exist, generate it
    [ ! -e "$SEARCH_FILE" ] && ensureDataFiles
fi

# Make sure a search term is supplied
if [ $# -eq 0 ]; then
    printf "==> I can cross-reference shows, actors, and the characters they portray,\n"
    printf "    such as The Crown, Olivia Colman, and Queen Elizabeth -- as long as\n"
    printf "    the search terms exist in $SEARCH_FILE\n\n"
    printf "Only one search term per line. Enter a blank line to finish.\n"
    while read -r -p "Enter a show, actor, or character: " searchTerm; do
        [ -z "$searchTerm" ] && break
        tr -ds '"' '[[:space:]]' <<<"$searchTerm" >>$SEARCH_TERMS
    done </dev/tty
    if [ ! -s "$SEARCH_TERMS" ]; then
        if waitUntil $ynPref -N "Would you like to see who played Queen Elizabeth II?"; then
            printf "Queen Elizabeth II\n" >>$SEARCH_TERMS
            printf "\n"
        else
            loopOrExitP
        fi
    fi
fi

# Let us know how many records we're searching
numRecords=$(sed -n '$=' $SEARCH_FILE)
[ "$INFO" == "yes" ] && printf "==> Searching $numRecords records in $SEARCH_FILE for cast data.\n\n"

# Setup SEARCH_TERMS with one search term per line, let us know what's in it.
printf "==> Searching for:\n"
for a in "$@"; do
    printf "$a\n" >>$SEARCH_TERMS
done
cat $SEARCH_TERMS

# Escape metacharacters known to appear in titles, persons, characters
sed -I "" 's/[()?]/\\&/g' $SEARCH_TERMS

# Setup awk printf formats with spaces or tabs
# Name|Job|Show|Episode|Role
PSPACE='%-20s  %-10s  %-40s  %-17s  %s\n'
PTAB='%s\t%s\t%s\t%s\t%s\n'

# If we find anything, rearrange it and put it in TMPFILE
if [ $(rg -wNzSI -c -f $SEARCH_TERMS $SEARCH_FILE) ]; then
    rg -wNzSI --color always -f $SEARCH_TERMS $SEARCH_FILE |
        awk -F "\t" -v PF="$PTAB" '{printf (PF, $1,$5,$2,$3,$6)}' |
        sort -f --field-separator=$'\t' --key=1,1 --key=3,3 -fu >$TMPFILE
fi

# Any results? If not, don't continue.
if [ ! -s "$TMPFILE" ]; then
    printf "==> Didn't find ${RED}any${NO_COLOR} matching records.\n"
    printf "    Check the \"Searching for:\" section above.\n"
    loopOrExitP
else
    numAll=$(sed -n '$=' $TMPFILE)
fi

# Get rid of initial single quote used to force show/episode names in spreadsheet to be strings.
perl -pi -e "s+\t'+\t+g;" $TMPFILE

# Save ALL_NAMES
printf "\n==> All names (Name|Job|Show|Episode|Role):\n" >$ALL_NAMES
if checkForExecutable -q xsv; then
    xsv table -d "\t" $TMPFILE >>$ALL_NAMES
else
    awk -F "\t" -v PF="$PSPACE" '{printf (PF,$1,$2,$3,$4,$5)}' $TMPFILE >>$ALL_NAMES
fi

# Save MULTIPLE_NAMES
# Print multiply occurring names, i.e. where field 1 is repeated in successive lines,
# but field 3 is different
if checkForExecutable -q xsv; then
    awk -F "\t" -v PF="$PTAB" '{if($1==f[1]&&$3!=f[3]) {printf(PF,f[1],f[2],f[3],f[4],f[5]);
    printf(PF,$1,$2,$3,$4,$5)} split($0,f)}' $TMPFILE | sort -fu |
        xsv table -d "\t" >>$MULTIPLE_NAMES
else
    awk -F "\t" -v PF="$PSPACE" '{if($1==f[1]&&$3!=f[3]) {printf(PF,f[1],f[2],f[3],f[4],f[5]);
    printf(PF,$1,$2,$3,$4,$5)} split($0,f)}' $TMPFILE | sort -fu >>$MULTIPLE_NAMES
fi

# Multiple results?
if [ ! -s "$MULTIPLE_NAMES" ]; then
    numMultiple="0"
    ALL_NAMES_ONLY="yes"
else
    numMultiple=$(sed -n '$=' $MULTIPLE_NAMES)
fi

# If we're in interactive mode, give user a choice of all or multiples only
if [ -z "$noLoop" ] && [ -z "$MULTIPLE_NAMES_ONLY" ] && [ -z "$ALL_NAMES_ONLY" ]; then
    printf "\n==> I found $numAll results. $numMultiple occur more than once.\n"
    waitUntil $ynPref -N "Should I only print those $numMultiple?" &&
        MULTIPLE_NAMES_ONLY="yes"
fi

# Unless MULTIPLE_NAMES_ONLY, print all search results
[ -z "$MULTIPLE_NAMES_ONLY" ] && cat $ALL_NAMES

# If ALL_NAMES_ONLY, exit here
[ -n "$ALL_NAMES_ONLY" ] && loopOrExitP

# Print all search results
printf "\n==> Multiply occurring names (Name|Job|Show|Episode|Role):\n"
cat $MULTIPLE_NAMES

# Do we really want to quit?
loopOrExitP
