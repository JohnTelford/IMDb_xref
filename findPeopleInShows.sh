#!/usr/bin/env bash
#
# Create a filmography for a named person in IMDb

# Make sure we are in the correct directory
DIRNAME=$(dirname "$0")
cd "$DIRNAME" || exit

export LC_COLLATE="C"
source functions/define_colors
source functions/define_files
source functions/load_functions

function help() {
    cat <<EOF
findPeopleInShows.sh -- List people in a show on IMDb.

Search IMDb titles for a match to a tconst or a show name. A tconst should be
unique, but a show name can have several or even many matches. Allow user to
select one match or skip if there are too many.

Then list all the people from that show.

If you don't enter a parameter on the command line, you'll be prompted for input.

USAGE:
    ./findPeopleInShows.sh [TCONST...] [SHOW TITLE...]

OPTIONS:
    -h      Print this message.
    -m      Maximum matches for a show title allowed in menu - defaults to 25

EXAMPLES:
    ./findPeopleInShows.sh
    ./findPeopleInShows.sh tt1606375
    ./findPeopleInShows.sh tt1606375 tt1399664 "Broadchurch"
    ./findPeopleInShows.sh "The Crown"
EOF
}

# Don't leave tempfiles around
trap terminate EXIT
#
function terminate() {
    if [ -n "$DEBUG" ]; then
        printf "\nTerminating: $(basename "$0")\n" >&2
        printf "Not removing:\n" >&2
        cat <<EOT >&2
$ALL_TERMS
$TCONST_TERMS
$SHOWS_TERMS
$POSSIBLE_MATCHES
$MATCH_COUNTS
$ALL_MATCHES

$CACHE_LIST
$SEARCH_LIST
$TCONST_LIST
$SHOW_NAMES
$EPISODES_LIST
$NCONST_LIST

$SHOWS_PL
$EPISODES_PL
$EPISODE_NAMES_PL
$NAMES_PL

$CREDITS_CSV
$EPISODES_CSV
$CAST_CSV

$TEMP_LIST
EOT
    else
        rm -f "$ALL_TERMS" "$TCONST_TERMS" "$SHOWS_TERMS" "$POSSIBLE_MATCHES"
        rm -f "$MATCH_COUNTS" "$ALL_MATCHES" "$CACHE_LIST" "$SEARCH_LIST"
        rm -f "$TCONST_LIST" "$SHOW_NAMES" "$EPISODES_LIST" "$NCONST_LIST"
        rm -f "$SHOWS_PL" "$EPISODES_PL" "$EPISODE_NAMES_PL" "$NAMES_PL"
        rm -f "$CREDITS_CSV" "$EPISODES_CSV" "$CAST_CSV" "$TEMP_LIST"
    fi
}

# trap ctrl-c and call cleanup
trap cleanup INT
#
function cleanup() {
    printf "\nCtrl-C detected. Exiting.\n" >&2
    exit 130
}

function loopOrExitP() {
    if waitUntil "$YN_PREF" -N \
        "\n==> Would you like to search for another show?"; then
        printf "\n"
        terminate
        exec ./findPeopleInShows.sh
    else
        printf "Quitting...\n"
        exit
    fi
}

while getopts ":hm:" opt; do
    case $opt in
    h)
        help
        exit
        ;;
    m)
        maxMenuSize="$OPTARG"
        ;;
    \?)
        printf "==> Ignoring invalid option: -$OPTARG\n\n" >&2
        ;;
    :)
        printf "Option -$OPTARG requires a 'maximum menu size' argument'.\n" >&2
        exit 1
        ;;
    esac
done
shift $((OPTIND - 1))

# Make sure prerequisites are satisfied
ensurePrerequisites

# Need some tempfiles
ALL_TERMS=$(mktemp)
TCONST_TERMS=$(mktemp)
SHOWS_TERMS=$(mktemp)
POSSIBLE_MATCHES=$(mktemp)
MATCH_COUNTS=$(mktemp)
ALL_MATCHES=$(mktemp)
#
CACHE_LIST=$(mktemp)
SEARCH_LIST=$(mktemp)
TCONST_LIST=$(mktemp)
SHOW_NAMES=$(mktemp)
EPISODES_LIST=$(mktemp)
NCONST_LIST=$(mktemp)
#
SHOWS_PL=$(mktemp)
EPISODES_PL=$(mktemp)
EPISODE_NAMES_PL=$(mktemp)
NAMES_PL=$(mktemp)
#
CREDITS_CSV=$(mktemp)
EPISODES_CSV=$(mktemp)
CAST_CSV=$(mktemp)
#
TEMP_LIST=$(mktemp)

# Make sure a search term is supplied
if [ $# -eq 0 ]; then
    cat <<EOF
==> I can create data files based on show names or tconst IDs,
    such as tt1606375 -- which is the tconst for Downton Abbey.

Only one search term per line. Enter a blank line to finish.
EOF
    while read -r -p "Enter a show name or tconst ID: " searchTerm; do
        [ -z "$searchTerm" ] && break
        tr -ds '"' '[:space:]' <<<"$searchTerm" >>"$ALL_TERMS"
    done </dev/tty
    if [ ! -s "$ALL_TERMS" ]; then
        if waitUntil "$YN_PREF" -N \
            "Would you like to see the cast of Downton Abbey?"; then
            printf "tt1606375\n" >>"$ALL_TERMS"
        else
            loopOrExitP
        fi
    fi
    printf "\n"
fi

# Get title.basics.tsv.gz file size - should already exist but make sure...
num_TB="$(rg -N title.basics.tsv.gz "$numRecordsFile" 2>/dev/null | cut -f 2)"
[ -z "$num_TB" ] && num_TB="$(rg -cz "^t" title.basics.tsv.gz)"

# Setup ALL_TERMS with one search term per line
for param in "$@"; do
    printf "$param\n" >>"$ALL_TERMS"
done
# Split into two groups so we can process them differently
rg -wN "^tt[0-9]{7,8}" "$ALL_TERMS" | sort -fu >"$TCONST_TERMS"
rg -wNv "^tt[0-9]{7,8}" "$ALL_TERMS" | sort -fu >"$SHOWS_TERMS"
printf "==> Searching $num_TB records for:\n"
cat "$TCONST_TERMS" "$SHOWS_TERMS"

# Reconstitute ALL_TERMS with column guards
perl -p -e 's/^/^/; s/$/\\t/;' "$TCONST_TERMS" >"$ALL_TERMS"
perl -p -e 's/^/\\t/; s/$/\\t/;' "$SHOWS_TERMS" >>"$ALL_TERMS"

# Get all possible matches at once
rg -NzSI -f "$ALL_TERMS" title.basics.tsv.gz | rg -v "tvEpisode" | cut -f 1-4 |
    sort -f -t$'\t' --key=3 >"$POSSIBLE_MATCHES"

# Figure how many matches for each possible match
cut -f 3 "$POSSIBLE_MATCHES" | frequency -t >"$MATCH_COUNTS"

# Add possible matches one at a time
while read -r line; do
    count=$(cut -f 1 <<<"$line")
    match=$(cut -f 2 <<<"$line")
    if [ "$count" -eq 1 ]; then
        rg "\t$match\t" "$POSSIBLE_MATCHES" >>"$ALL_MATCHES"
        continue
    fi
    cat <<EOF

Some titles on IMDb occur more than once, e.g. as both a movie and TV show.
You can track down the correct one by searching for it's tconst ID on IMDb.com.

EOF

    printf "I found $count shows titled \"$match\"\n"
    if [ "$count" -ge "${maxMenuSize:-25}" ]; then
        waitUntil "$YN_PREF" -Y "Should I skip trying to select one?" && continue
    fi
    # rg --color always "\t$match\t" $POSSIBLE_MATCHES | xsv table -d "\t"
    pickOptions=()
    # rg --color always -N "\t$match\t" "$POSSIBLE_MATCHES" | xsv table -d "\t"
    while IFS=$'\n' read -r line; do
        pickOptions+=("$line")
    done < <(rg -N "\t$match\t" "$POSSIBLE_MATCHES")
    pickOptions+=("Skip \"$match\"" "Quit")

    PS3="Select a number from 1-${#pickOptions[@]}: "
    COLUMNS=40
    select pickMenu in "${pickOptions[@]}"; do
        if [ "$REPLY" -ge 1 ] 2>/dev/null &&
            [ "$REPLY" -le "${#pickOptions[@]}" ]; then
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
                printf "$pickMenu\n" >>"$ALL_MATCHES"
                break
                ;;
            esac
            break
        else
            printf "Your selection must be a number from 1-${#pickOptions[@]}\n"
        fi
    done </dev/tty
done <"$MATCH_COUNTS"
printf "\n"

# Didn't find any results
if [ ! -s "$ALL_MATCHES" ]; then
    printf "==> Didn't find ${RED}any${NO_COLOR} matching shows.\n"
    printf "    Check the \"Searching $num_TB records for:\" section above.\n\n"
    loopOrExitP
fi

# Found results, check with user before adding to local data
printf "These are the matches I found:\n"
if checkForExecutable -q xsv; then
    sort -f -t$'\t' --key=3 "$ALL_MATCHES" | xsv table -d "\t"
else
    sort -f -t$'\t' --key=3 "$ALL_MATCHES"
fi
! waitUntil "$YN_PREF" -Y && loopOrExitP
printf "\n"

# Figure out which tconst IDs are cached and which aren't
ls -1 "$cacheDirectory" | rg "^tt" >"$CACHE_LIST"
cut -f 1 "$ALL_MATCHES" | sort >"$SEARCH_LIST"

# Build the lists we need, sort SHOW_NAMES alphabetically
comm -13 "$CACHE_LIST" "$SEARCH_LIST" >"$TCONST_LIST"
cut -f 1,3 "$ALL_MATCHES" | sort -f -t$'\t' --key=2 >"$SHOW_NAMES"

# If everthing is cached, skip searching entirely
if [ "$(rg -c "^tt" "$TCONST_LIST")" ]; then

    # Create a perl script to GLOBALLY convert a show tconst to a show title
    printf "==> Searching $num_TB records for show titles.\n"
    rg -wNz -f "$TCONST_LIST" title.basics.tsv.gz |
        perl -F"\t" -lane 'print "s{\\b@F[0]\\b}\{@F[2]}g;";' >"$SHOWS_PL"

    # Use tconst list to lookup episode IDs and generate an EPISODE TCONST file
    rg -wNz -f "$TCONST_LIST" title.episode.tsv.gz |
        tee "$EPISODES_CSV" | cut -f 1 >"$EPISODES_LIST"
    # Create a perl script to convert an episode tconst to its parent show title
    perl -F"\t" -lane 'print "s{\\b@F[0]\\b}\{@F[1]};";' "$EPISODES_CSV" |
        perl -p -f "$SHOWS_PL" >"$EPISODES_PL"

    # Create a perl script to convert an episode tconst to its episode title
    rg -wNz -f "$EPISODES_LIST" title.basics.tsv.gz |
        perl -F"\t" -lane 'print "s{\\b@F[0]\\b}\{@F[3]};";' \
            >"$EPISODE_NAMES_PL"

    # Get title.principals.tsv.gz file size - should already exist but make sure...
    num_TP="$(rg -N title.principals.tsv.gz "$numRecordsFile" 2>/dev/null | cut -f 2)"
    [ -z "$num_TP" ] && num_TP="$(rg -cz "^t" title.principals.tsv.gz)"

    # Use tconst list to lookup principal titles and generate credits csv
    # Fix bogus nconst nm0745728, it should be nm0745694. Rearrange fields
    # Leave the episode title field blank!
    printf "==> Searching $num_TP records for principal cast members.\n\n"
    rg -wNz -f "$TCONST_LIST" title.principals.tsv.gz |
        perl -p -e 's+nm0745728+nm0745694+' |
        perl -F"\t" -lane 'printf "%s\t%s\t\t%02d\t%s\t%s\n", @F[2,0,1,3,5]' |
        tee "$CREDITS_CSV" | cut -f 1 | sort -u | tee "$TEMP_LIST" >"$NCONST_LIST"

    # Use episodes list to lookup principal titles and add to credits csv
    # Copy field 1 to the episode title field!
    rg -wNz -f "$EPISODES_LIST" title.principals.tsv.gz |
        perl -F"\t" -lane 'printf "%s\t%s\t%s\t%02d\t%s\t%s\n", @F[2,0,0,1,3,5]' |
        tee -a "$CREDITS_CSV" | cut -f 1 | sort -u |
        rg -v -f "$TEMP_LIST" >>"$NCONST_LIST"

    # Create a perl script to convert an nconst to a name
    rg -wNz -f "$NCONST_LIST" name.basics.tsv.gz |
        perl -F"\t" -lane 'print "s{^@F[0]\\b}\{@F[1]};";' >"$NAMES_PL"

    # Get rid of ugly \N fields, and unneeded characters. Make sure commas are
    # followed by spaces. Separate multiple characters portrayed with semicolons,
    # remove quotes
    perl -pi -e 's+\\N++g; tr+[]++d; s+,+, +g; s+,  +, +g; s+", "+; +g; tr+"++d;' \
        "$CREDITS_CSV"

    # Translate tconst and nconst into titles and names
    perl -pi -f "$SHOWS_PL" "$CREDITS_CSV"
    perl -pi -f "$EPISODES_PL" "$CREDITS_CSV"
    perl -pi -f "$EPISODE_NAMES_PL" "$CREDITS_CSV"
    perl -pi -f "$NAMES_PL" "$CREDITS_CSV"

    # Create the sorted RESULTS
    printf "Person\tShow Title\tEpisode Title\tRank\tJob\tCharacter Name\n" \
        >"$CAST_CSV"
    # Sort by Person (1), Show Title (2), Rank (4), Episode Title (3)
    sort -f -t$'\t' --key=1,2 --key=4,4 --key=3,3 "$CREDITS_CSV" \
        >>"$CAST_CSV"
fi

[ -n "$DEBUG" ] && set -v
while read -r line; do
    cacheName=$(cut -f 1 <<<"$line")
    cacheFile="$cacheDirectory/$cacheName"
    showName=$(cut -f 2 <<<"$line")
    if [ ! "$(rg -c "^$cacheName$" "$CACHE_LIST")" ]; then
        rg "\t$showName\t" "$CAST_CSV" >"$cacheFile"
    fi
    ./xrefCast.sh -f "$cacheFile" -an "$showName"
    waitUntil -k
done <"$SHOW_NAMES"

# Do we really want to quit?
loopOrExitP
