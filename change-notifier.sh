#! /usr/bin/env bash

# bash strict-mode
set -euo pipefail
IFS=$'\n\t'

# usage:
# change-notifier.sh <check> <email> [ <email> ... ]

# statefile is <check>.state
# run the check script
# if it succeeds, write output to tempfile
# if statefile does not exist, then copy tempfile to it
# if statefile and tempfile are different, then notify and replace statefile

BASE_PATH="$( dirname "$0" )"
BASE_PATH="$( realpath "$BASE_PATH" )"

. "$BASE_PATH/lib.bash"

subject='Status changed'
from='Change Notifier <change-notifier@spike.cx>'
msg='Text on site has changed:'

while getopts ':s:m:' opt; do
  case "$opt" in
    s)
      subject="$OPTARG"
      ;;
    m)
      msg="$OPTARG"
      ;;
  esac
done

shift "$(( OPTIND - 1 ))"

if [[ "$#" -lt 2 ]]; then
  echo "Usage: $0 [ -s <subject> ] [ -m <msg> ] <check> <email> [ <email> ... ]"
  exit 1
fi

MAILGUN_URL="${MAILGUN_URL:-""}"
MAILGUN_KEY="${MAILGUN_KEY:-""}"

# use these vars for mailgun API use
if [[ -z "$MAILGUN_URL" || -z "$MAILGUN_KEY" ]]; then
  echo "no mailgun settings (MAILGUN_URL / MAILGUN_KEY)"
  exit 1
fi

## functions

sanity_check() {
  # make sure that check is executable
  if [[ ! -x "$check_script" ]]; then
    e::error "Check script is not executable."
    return 1
  fi
}

run_check() {
  if ! "$check_script" > "$tempfile"; then
    e::error "Failed to run check. Bailing."
    return 1
  fi
}

# deal with checking the stuff
post_process() {
  # if the statefile exists
  if [[ -s "$statefile" ]]; then
    if was_status_changed; then
      rm "$statefile"
      cp "$tempfile" "$statefile"

      notify_everyone
    else
      e::info "No changes. Doing nothing."
    fi
  else
    e::info "State file doesn't exist. Creating."

    cp "$tempfile" "$statefile"
  fi
}

was_status_changed() {
  ! diff -q "$statefile" "$tempfile" &> /dev/null
}

notify_everyone() {
  local e
  for e in "${emails[@]}"; do
    notify::send "$e" "$msg

$( cat "$statefile" )"
  done
}

notify::send() {
  local email="$1"
  local msg="$2"

  curl -v \
    -XPOST \
    --user "api:${MAILGUN_KEY}" \
    --data-urlencode "to=${email}" \
    --data-urlencode "from=${from}" \
    --data-urlencode "subject=${subject}" \
    --data-urlencode "text=$msg" \
    "${MAILGUN_URL}/messages"
}

## do the things

check_script="$( realpath "$1" )"; shift
emails=( "$@" )

statefile="${check_script}.state"

tempfile="$( mktemp '/tmp/change-notifier.XXXXXX' )"
trap 'rm -rf "$tempfile"' EXIT

e::info "Creating tempfile at $tempfile"

p::2columns \
  "Check" "$check_script" \
  "State" "$statefile"

p::list "${emails[@]}"

run_check
post_process

