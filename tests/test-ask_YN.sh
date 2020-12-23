#!/usr/bin/env bash

# Make sure we are in the correct directory
DIRNAME=$(dirname "$0")
cd $DIRNAME/..

. functions/define_colors
. functions/ask_YN.function

printf "==> Testing the ${RED}ask_YN.function${NO_COLOR}.\n\n"
printf "First, print the help file...\n"
ask_YN -h
printf "\n"

printf "==> Starting Section 1.\n\n"
printf "==> 'ask_YN -w' with no prompt supplied. Expect 'Hit any key to continue, '^C' to quit.'\n"
ask_YN -w

ask_YN -w "Custom prompt supplied with -w. Hit any key. Next test should clear the screen."

ask_YN -wc "Screen should have cleared from -wc. Hit any key."

printf "==> Done with Section 1.\n\n"

printf "==> Section 2. Test ${RED}[y/n]${NO_COLOR} prompts. Valid responses are Y, y, N, or n.\n"
printf "==> It should not proceed if you hit any other character, including <cr>.\n"
printf "==> It will return as soon as you type one character. It doesn't wait for a <cr>.\n"

printf "\n==> Some tests to check basic functionality using the default prompt.\n"
printf "==> 'ask_YN' with no prompt supplied. Expect 'Does that look correct?'\n"
if ask_YN; then
    printf "Yes\n"
else
    printf "No\n"
fi

printf "==> A simple 'ask_YN' that only accepts 1 character. Type a y.\n"
if ask_YN; then
    printf "Yes\n"
else
    printf "No\n"
fi

printf "==> A second simple 'ask_YN' that only accepts 1 character. Type an n.\n"
if ask_YN; then
    printf "Yes\n"
else
    printf "No\n"
fi

printf "==> A third simple 'ask_YN' that only accepts 1 character. Hit any key.\n"
printf "==> It should loop waiting for y or n.\n"
if ask_YN; then
    printf "Yes\n"
else
    printf "No\n"
fi

if ask_YN "With a custom prompt. Next test sleeps 3 seconds, then clears the screen before prompting."; then
    printf "Yes\n"
else
    printf "No\n"
fi

sleep 3

if ask_YN -c "Did we set a custom prompt and clear the screen first with -c?"; then
    printf "Yes\n"
else
    printf "No\n"
fi

printf "\n==> Show what is displayed if a bad param -x is sent.\n"
if ask_YN -x "Phooey. I have a bad parameter in my source code."; then
    printf "Yes\n"
else
    printf "No\n"
fi

printf "==> Done with Section 2.\n\n"

printf "==> Section 3. Test longer form answers that require a <cr> before proceeding.\n"
printf "==> Only the first character is tested, so 'yes' works as well as 'y'.\n"

printf "\n==> Four tests to check long responses to ${RED}[y/n]${NO_COLOR} prompts.\n"
if ask_YN -l "1. Enter any string starting with y."; then
    printf "Yes\n"
else
    printf "No\n"
fi

if ask_YN -l "2. Enter any string starting with n."; then
    printf "Yes\n"
else
    printf "No\n"
fi

if ask_YN -l "3. Enter <cr>. Should loop waiting for y or n."; then
    printf "Yes\n"
else
    printf "No\n"
fi

if ask_YN -l "4. Enter a different character. Should loop waiting for y or n."; then
    printf "Yes\n"
else
    printf "No\n"
fi

printf "==> Done with Section 3.\n\n"

printf "==> Section 4. Test ${RED}[Y/n]${NO_COLOR} and ${RED}[y/N]${NO_COLOR} prompts. "
printf "Valid responses are Y, y, N, n, or <cr>.\n"
printf "==> A <cr> should be the same as entering the capitalized letter.\n"
printf "==> It should not proceed if you enter any other character than Y, y, N, n, or <cr>.\n"

# Default to Yes [Y/n] if the user presses enter without giving an answer:
printf "\n==> Four tests to check possible responses to ${RED}[Y/n]${NO_COLOR} prompts.\n"
if ask_YN -lY "1. Enter any string starting with y."; then
    printf "Yes\n"
else
    printf "No\n"
fi
if ask_YN -lY "2. Enter any string starting with n."; then
    printf "Yes\n"
else
    printf "No\n"
fi
if ask_YN -lY "3. Enter <cr>."; then
    printf "Yes\n"
else
    printf "No\n"
fi
if ask_YN -lY "4. Enter a different character. Should loop until Y, y, N, n, or <cr>."; then
    printf "Yes\n"
else
    printf "No\n"
fi

# Default to No [y/N] if the user presses enter without giving an answer:
printf "\n==> Four tests to check possible responses to ${RED}[y/N]${NO_COLOR} prompts.\n"
if ask_YN -lN "1. Enter any string starting with y."; then
    printf "Yes\n"
else
    printf "No\n"
fi
if ask_YN -lN "2. Enter any string starting with n."; then
    printf "Yes\n"
else
    printf "No\n"
fi
if ask_YN -lN "3. Enter <cr>."; then
    printf "Yes\n"
else
    printf "No\n"
fi
if ask_YN -lN "4. Enter a different character. Should loop until Y, y, N, n, or <cr>."; then
    printf "Yes\n"
else
    printf "No\n"
fi

printf "==> Done with Section 4. End of test.\n\n"
