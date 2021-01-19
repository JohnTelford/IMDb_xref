#!/usr/bin/env bash
#
# Create a filmography for a named person in IMDb

# Make sure we are in the correct directory
DIRNAME=$(dirname "$0")
cd "$DIRNAME"
export LC_COLLATE="C"
source functions/define_colors
source functions/define_files
source functions/load_functions

function help() {
    cat <<EOF
listShowsWith.sh -- List a filmography for a named person in IMDb

Search IMDb titles for a match to a nconst or a person name. A nconst should be unique,
but a person name can have several or even many matches. Allow user to select one match
or skip if there are too many.

If you don't enter a parameter on the command line, you'll be prompted for input.

USAGE:
    ./listShowsWith.sh [NCONST...] [PERSON NAME...]

OPTIONS:
    -h      Print this message.
    -m      Maximum matches for a person name allowed in menu - defaults to 10
    -y      Yes -- assume the answer to job category prompts is "Y".

EXAMPLES:
    ./listShowsWith.sh
    ./listShowsWith.sh -y "Tom Hanks"
    ./listShowsWith.sh nm0000123
    ./listShowsWith.sh "George Clooney"
    ./listShowsWith.sh nm0000123 "Quentin Tarantino"
EOF
}

# Don't leave tempfiles around
trap terminate EXIT
#
function terminate() {
    if [ -n "$DEBUG" ]; then
        printf "\nTerminating: $(basename $0)\n" >&2
        printf "Not removing:\n" >&2
        printf "$ALL_TERMS $NCONST_TERMS $PERSON_TERMS $POSSIBLE_MATCHES\n" >&2
        printf "$MATCH_COUNTS $PERSON_RESULTS $JOB_RESULTS\n" >&2
    else
        rm -f $ALL_TERMS $NCONST_TERMS $PERSON_TERMS $POSSIBLE_MATCHES
        rm -f $MATCH_COUNTS $PERSON_RESULTS $JOB_RESULTS
    fi
}

# trap ctrl-c and call cleanup
trap cleanup INT
#
function cleanup() {
    printf "\nCtrl-C detected. Exiting.\n" >&2
    exit 130
}

while getopts ":hm:y" opt; do
    case $opt in
    h)
        help
        exit
        ;;
    m)
        maxMenuSize="$OPTARG"
        ;;
    y)
        skipPrompts="yes"
        ;;
    \?)
        printf "==> Ignoring invalid option: -$OPTARG\n\n" >&2
        ;;
    :)
        printf "Option -$OPTARG requires a 'translation file' argument'.\n" >&2
        exit 1
        ;;
    esac
done
shift $((OPTIND - 1))

# Make sure prerequisites are satisfied
ensurePrerequisites

# Need some tempfiles
ALL_TERMS=$(mktemp)
NCONST_TERMS=$(mktemp)
PERSON_TERMS=$(mktemp)
POSSIBLE_MATCHES=$(mktemp)
MATCH_COUNTS=$(mktemp)
PERSON_RESULTS=$(mktemp)
JOB_RESULTS=$(mktemp)

# Make sure a search term is supplied
if [ $# -eq 0 ]; then
    printf "==> I can generate a filmography based on person names or nconst IDs,\n"
    printf "    such as nm0000123 -- which is the nconst for George Clooney.\n\n"
    printf "Only one search term per line. Enter a blank line to finish.\n"
    while read -r -p "Enter a person name or nconst ID: " searchTerm; do
        [ -z "$searchTerm" ] && break
        tr -ds '"' '[[:space:]]' <<<"$searchTerm" >>$ALL_TERMS
    done </dev/tty
    if [ ! -s "$ALL_TERMS" ]; then
        if waitUntil -N "Would you like me to add the George Clooney nconst for you?"; then
            printf "nm0000123\n" >>$ALL_TERMS
        else
            exit 1
        fi
    fi
    printf "\n"
fi

# Setup ALL_TERMS with one search term per line
numRecords="$(rg -N name.basics.tsv.gz $numRecordsFile 2>/dev/null | cut -f 2)"
[ -z "$numRecords" ] && numRecords="$(rg -cz "^n" name.basics.tsv.gz)"
for param in "$@"; do
    printf "$param\n" >>$ALL_TERMS
done
# Split into two groups so we can process them differently
rg -wN "^nm[0-9]{7,8}" $ALL_TERMS | sort -fu >$NCONST_TERMS
rg -wNv "nm[0-9]{7,8}" $ALL_TERMS | sort -fu >$PERSON_TERMS
printf "==> Searching $numRecords records for:\n"
cat $NCONST_TERMS $PERSON_TERMS

# Reconstitute ALL_TERMS with column guards
perl -p -e 's/^/^/; s/$/\\t/;' $NCONST_TERMS >$ALL_TERMS
perl -p -e 's/^/\\t/; s/$/\\t/;' $PERSON_TERMS >>$ALL_TERMS

# Get all possible matches at once
rg -NzSI -f $ALL_TERMS name.basics.tsv.gz | rg -wN "tt[0-9]{7,8}" | cut -f 1-5 |
    sort -f --field-separator=$'\t' --key=2 >$POSSIBLE_MATCHES
# perl -pi -e 's+\\N++g;' $POSSIBLE_MATCHES
# perl -pi -e 's+\\N++g; tr+[]++d; s+,+, +g; s+,  +, +g; s+", "+; +g; tr+"++d;' $POSSIBLE_MATCHES
perl -pi -e 's+\\N++g; s+,+, +g; s+,  +, +g;' $POSSIBLE_MATCHES

# Figure how many matches for each possible match
cut -f 2 $POSSIBLE_MATCHES | frequency -t >$MATCH_COUNTS

# Add possible matches one at a time
while read -r line; do
    count=$(cut -f 1 <<<"$line")
    match=$(cut -f 2 <<<"$line")
    if [ "$count" -eq 1 ]; then
        rg "\t$match\t" $POSSIBLE_MATCHES >>$PERSON_RESULTS
        continue
    fi
    printf "\n"
    printf "Some person names on IMDb occur more than once, e.g. John Wayne or John Lennon.\n"
    printf "You can track down the correct one by searching for it's nconst ID on IMDb.com.\n"
    printf "\n"

    printf "I found $count persons named \"$match\"\n"
    if [ "$count" -ge "${maxMenuSize:-10}" ]; then
        if waitUntil -Y "Should I skip trying to select one?"; then
            continue
        fi
    fi
    pickOptions=()
    IFS=$'\n' pickOptions=($(rg -N "\t$match\t" $POSSIBLE_MATCHES |
        sort -f --field-separator=$'\t' --key=3,3r --key=5))
    pickOptions+=("Skip \"$match\"" "Quit")

    PS3="Select a number from 1-${#pickOptions[@]}: "
    COLUMNS=40
    select pickMenu in "${pickOptions[@]}"; do
        if [ "$REPLY" -ge 1 ] 2>/dev/null && [ "$REPLY" -le "${#pickOptions[@]}" ]; then
            case "$pickMenu" in
            Skip*)
                printf "Skipping...\n"
                break
                ;;
            Quit)
                printf "Quitting...\n"
                exit
                ;;
            *)
                printf "Adding: $pickMenu\n"
                printf "$pickMenu\n" >>$PERSON_RESULTS
                break
                ;;
            esac
            break
        else
            printf "Your selection must be a number from 1-${#pickOptions[@]}\n"
        fi
    done </dev/tty
done <$MATCH_COUNTS
printf "\n"

# Didn't find any results
if [ ! -s "$PERSON_RESULTS" ]; then
    printf "==> Didn't find ${RED}any${NO_COLOR} matching persons.\n"
    printf "    Check the \"Searching $numRecords records for:\" section above.\n\n"
    exit
fi

# Found results, check with user before adding
printf "These are the persons I found:\n"
if checkForExecutable -q xsv; then
    xsv table -d "\t" $PERSON_RESULTS
else
    cat $PERSON_RESULTS
fi

if ! waitUntil -Y; then
    printf "Quitting...\n"
    exit
fi

cut -f 1 $PERSON_RESULTS >$NCONST_TERMS
rg -Nz -f $NCONST_TERMS title.principals.tsv.gz |
    rg -w -e actor -e actress -e writer -e director -e producer | cut -f 1,3,4 >$POSSIBLE_MATCHES
perl -pi -e 's+\\N++g; tr+[]++d; s+,+, +g; s+,  +, +g; s+", "+; +g; tr+"++d;' $POSSIBLE_MATCHES

while read -r line; do
    nconstID="$line"
    nconstName="$(rg -N $line $PERSON_RESULTS | cut -f 2)"
    rg -Nw "$nconstID" $POSSIBLE_MATCHES | cut -f 3 | frequency -t >$MATCH_COUNTS
    while read -r job; do
        count=$(cut -f 1 <<<"$job")
        match=$(cut -f 2 <<<"$job")
        printf "\n"
        rg -Nw -e "$nconstID\t$match" $POSSIBLE_MATCHES >$JOB_RESULTS
        ./augment_tconstFiles.sh -y $JOB_RESULTS
        numResults=$(sed -n '$=' $JOB_RESULTS)
        if [[ $numResults -gt 0 ]]; then
            printf "==> I found $numResults titles listing $nconstName as: $match\n"
            if [ -n "$skipPrompts" ] || waitUntil -Y "==> Shall I list them?"; then
                if checkForExecutable -q xsv; then
                    cut -f 2,3 $JOB_RESULTS | sort -fu | xsv table -d "\t"
                else
                    cut -f 2,3 $JOB_RESULTS | sort -fu
                fi
            fi
        fi
    done <$MATCH_COUNTS
done <$NCONST_TERMS