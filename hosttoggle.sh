#!/bin/bash
###############################################################################
# In response to my propensity to impulsively open some websites without      #
# thinking about it, I started using /etc/hosts for blocking them out. But,   #
# sometimes, I'd like to go look at one.  It's not all focus all the time.    #
# And commenting out / uncommenting lines gets tedious when you're looking at #
# even this number of sites to look at. So I wanted to simplify/automate that #
# a little bit.                                                               #
#                                                                             #
# This should probably be owned by root, since non-root accounts are          #
# typically more at risk of being compromised. It would be too easy to modify #
# this to make it do something nefarious. It's not like it's convenient to    #
# check if this has been compromisd every time you run it.                    #
#                                                                             #
# Would it be unethical to to have it sudo chown root.root itself if it's     #
# not owned by root? I am unsure.                                             #
#                                                                             #
###############################################################################

# there's probably a way to do something like a Python dictionary.
# I'll have to figure that out sometime in the future.
# In the meantime:
# To add/remove sites to a specific site group, add to/remove from that
#   specific site group, e.g., remove meta.com from meta

# To add a new site group:
# Add new site group to site_list
# Create specific site list array.
# Add new case in get_group_array

site_list=(bluesky meta news social x yelp)

bluesky=(bsky.app)
meta=(facebook.com instagram.com threads.net meta.com)
news=(npr.org slashdot.org soylentnews.org electoral-vote.com)
social=(bsky.app facebook.com instagram.com threads.net meta.com)
x=(x.com twitter.com)
yelp=(yelp.com)

# to check if script is owned by root to avoid non-privileged shenanigans
check_ownership() {
  if [ "$(uname)" = "Darwin" ]; then
    FILE_OWNER=$(stat -f "%u")
    # I'm under the impression it's -c elsewhere. I'll find out another time.
  fi

  if [ ! -z "$FILE_OWNER" ]; then
    if [ $FILE_OWNER -gt 0 ]; then
      echo "\nCaution: this script should be owned by root.\n"
    fi
  fi
}

get_group_array() {
  case $1 in
  bluesky)
    echo ${bluesky[*]}
    ;;
  meta)
    echo ${meta[*]}
    ;;
  news)
    echo ${news[*]}
    ;;
  social)
    echo ${social[*]}
    ;;
  x)
    echo ${x[*]}
    ;;
  yelp)
    echo ${yelp[*]}
    ;;
  *)
    echo ""
    ;;
  esac
}

# function to get state of hosts in group (commented: 2, uncommented: 1)
get_group_state() {
  if [ -z "$SITES" ]; then
    exit
  fi
  IFS=" "
  for site in $SITES; do
    LINE="$(cat /etc/hosts | grep -e 127.0.0.1[[:space:]][[:alnum:]\.]*$site)"
    LINE_START="$(echo $LINE | head -c 1)"
    if [ "$LINE_START" = "#" ]; then
      echo 2
      return
    fi
  done
  echo 1
}

# output usage information
print_usage() {
  printf "usage: $0 [-w] <site group>\n\t-w:\t use sudo and write changes "
  printf " (default behavior is to show changes to be made)\n"
  printf "\tsite groups are: "
  for site in ${site_list[@]}; do printf "$site, "; done | sed -e 's/,\ $//'
  printf "\n\n"
  exit
}

# check if a group name is actually in $site_list
validate_group() {
  if [ -z "$(get_group_array $1)" ]; then
    echo 1
  else
    echo 0
  fi
}

# generate temporary filename
get_temporary_file_name() {
  DATE=$(date +%Y%m%d_%H%M_%S)
  FILENAME=~/.hosts_${DATE}_${RANDOM}
  echo $FILENAME
}

# output a list of words/sites separated by commas
printf_sites() {
  echo $@ | sed -e 's/\ /,\ /g'
}

# prepare temporary files and make sure permissions are tight
create_temporary_files() {
  cat /etc/hosts >"$TEMPFILENAME_1"
  touch "$TEMPFILENAME_2"
  chmod 600 "$TEMPFILENAME_1" "$TEMPFILENAME_2"
}

# remove temporary files
delete_temporary_files() {
  if [ -f "$TEMPFILENAME_1" ]; then
    rm "$TEMPFILENAME_1" "$TEMPFILENAME_2"
  fi
}

# pipe temporary file into /etc/hosts
temporary_file_to_etc_hosts() {
  if [ -z "$(cat $TEMPFILENAME_1)" ]; then
    echo "\nError: something is wrong with the temporary file, not updating.\n"
    return
  fi
  if [ -z "$(diff -ru $TEMPFILENAME_1 /etc/hosts)" ]; then
    echo "No changes made, not updating /etc/hosts"
    return
  fi
  if [ "$WRITE" = 0 ]; then
    LINES_CHANGED="$(diff -ru $TEMPFILENAME_1 /etc/hosts |
      grep -e '^+[^+]' | wc -l | awk '{print $1}')"
    echo "::: asking for root to change $LINES_CHANGED lines of /etc/hosts"
    sudo sh -c "cat "$TEMPFILENAME_1" > /etc/hosts"
  else
    diff -ru /etc/hosts "$TEMPFILENAME_1"
  fi
}

# prepare the sed regex patttern to comment out lines
prepare_comment_out() {
  PATTERN_BEFORE_SITE="s/^\(127.0.0.1[[:space:]][[:alnum:]\.]*"
  PATTERN_AFTER_SITE="\)/#\1/"
  ACTION_TEXT="commenting out"
}

# prepare the sed regex pattern to uncomment lines
prepare_uncomment() {
  PATTERN_BEFORE_SITE="s/^#\(127.0.0.1[[:space:]][[:alnum:]\.]*"
  PATTERN_AFTER_SITE="\)/\1/"
  ACTION_TEXT="uncommenting"
}

# modify temporary file based on sites in site group
draft_new_hosts_file() {
  echo "::: $ACTION_TEXT $GROUP group ($(printf_sites $SITES))"
  IFS=" "
  for site in $SITES; do
    FULL_PATTERN="${PATTERN_BEFORE_SITE}"${site}"${PATTERN_AFTER_SITE}"
    cat "$TEMPFILENAME_1" | sed -e "$FULL_PATTERN" >"$TEMPFILENAME_2"
    cat "$TEMPFILENAME_2" >"$TEMPFILENAME_1"
    continue
  done
  printf "::: done $ACTION_TEXT $GROUP group\n"
}

WRITE=1 # don't attempt to write to /etc/hosts first (change to 0 if you want to be reckless; I do not.)

# function to iterate comment/uncomment calls for each group specified on command line
iterate_command_line_arguments() {
  for arg in $@; do
    VALID=$(validate_group $arg)
    if [ "$VALID" = 1 ]; then
      echo "::: invalid group: $arg"
      continue
    fi
    GROUP=$arg
    SITES=$(get_group_array $arg)
    STATE=$(get_group_state $arg)
    if [ "$STATE" = 2 ]; then
      prepare_uncomment
    elif [ "$STATE" = 1 ]; then
      prepare_comment_out
    fi
    TEMPFILENAME_1="$(get_temporary_file_name)"
    TEMPFILENAME_2="${TEMPFILENAME_1}_tmp"
    create_temporary_files
    draft_new_hosts_file
    temporary_file_to_etc_hosts
    delete_temporary_files
  done
}

# now we're ready to run.

if [ "$1" = "-w" ]; then
  WRITE=0
  shift
fi

if [ -z "$1" ] || [ "$(validate_group $1)" = 1 ]; then
  print_usage
  exit
fi

check_ownership
iterate_command_line_arguments $@
