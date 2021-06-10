#!/usr/bin/env bash

# Initially authored by Franziska Schwab
# Modularization and current development by Peter Eisner

#   Copyright 2021 Technische Informationsbibliothek (TIB)
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# script conducts pre-ingest analysis and checks:
#  1.1 Check file names                                (fileNamePolicy)
#  1.2 Check directory names                           (dirNamePolicy)
#  2) Check for operating system specific files        (hiddenSystemFiles)
#  3) Check for invisible files and directories        (hiddenFilesDirs)
#  4) check for empty files and directories            (emptyFilesDirs)
#  5) check against SIP-specification                  (sipStructure)
#     Identifier-MASTER/MODIFIED_MASTER/DERIVATIVE_COPY
#  6) check for files >2GB                             (bigFiles)
#  7) check for duplicates                             (dubCheck)
#  8) look for (possibly compressed) archive files     (archiveFiles)
#  [ Cleanup ]

# Dependencies:
#  Using Cygwin64Bit in version 3.0.7 or higher, all neccessary packages
#  should be installed by default.
#  Works fine on real computers, too.


# get the location of this script
piaDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

function piaConfig {

################
# Configuration:

# config options are sourced from PIA's config file. At the moment, the
# file pia.config needs to be edited manually.

source "$piaDir"/pia.config

# create output folder safely and recursively
mkdir -p $output

# add time stamped subdirectory to output
configured_output=$output
output=$configured_output/$(date +%Y-%m-%d_%H-%M-%S)
mkdir $output

# define depth limits for identifier directories

if [ -z $id_depth ]
  then
    # determine depth as difference from "input" to "MASTER"
    input_depth=$(echo $input | awk -F '/' '{print NF}')
    master_depth=$(find $input -type d -name "MASTER" | awk -F '/' '{print NF; exit}')
    id_depth=$(expr $master_depth - $input_depth - 1)
fi

SIP_mindepth=$id_depth
SIP_maxdepth=$id_depth

# check if needed commands are available

# currently, this checks a single command: unzip. later we can add more
# packers like rar or 7zip to this array, like this: ("unzip" "unrar" ...)
declare -a mandatory_cmds=("unzip")

peek_in_archives=true
for cmd in "${mandatory_cmds[@]}"
do
  if ! command -v "$cmd" &> /dev/null
    then
      echo "WARNING: Could not find mandatory command $cmd."
      peek_in_archives=false
  fi
done

if [ "$peek_in_archives" = false ]
  then
    echo "Will not analyze contents of archive files due to missing command(s)."
fi

}

function fileNamePolicy {

#####################################
# 1.1 Check file names against policy

# There are different sets of characters. Some are explicitly forbidden according
# to our policy; others are known to be harmless, so we allow them. While both sets
# are mutally exclusive, both added together do not cover all possible characters.
# This routine does two checks:
# 1. It looks for explicitly forbidden characters in file names (FORBIDDEN).
# 2. Then it looks for filenames containing characters that are not on the list of
#    explicitly allowed characters (NOT ALLOWED).
# The results from FORBIDDEN are then subtracted from NOT ALLOWED results.
#
# You may think of it like this: the first check finds the really bad ones, the
# second check goes for the strange and weird ones which might still be okay.

echo
echo "-----------------Looking for forbidden characters in file names-----------------"
echo

# generate a file list, format as <path><delimiter><filename>
find "$input" -type f -fprintf "$output"/tmp_files_delimited.txt '%hpr3ttY_un1que_delimiTer%f\n'

# FIND FORBIDDEN CHARACTERS IN FILE NAMES

# boil down the file list, keep lines with forbidden characters
grep -e "[]\[<>„“&*#,;@|$\\ ]" \
  "$output"/tmp_files_delimited.txt \
  > "$output"/tmp_files_forbidden_characters_delimited.txt

# detect spaces in filenames
awk 'BEGIN{ FS="pr3ttY_un1que_delimiTer";OFS="/" } $2 ~ / / { print $1, $2 }' \
  "$output"/tmp_files_forbidden_characters_delimited.txt \
  > "$output"/filenames_with_spaces.txt
piaStatsSpaces=$(cat "$output"/filenames_with_spaces.txt | wc -l)

# detect punctuation characters (except ".")
awk 'BEGIN{ FS="pr3ttY_un1que_delimiTer";OFS="/" } $2 ~ /[„“,;]/ { print $1, $2 }' \
  "$output"/tmp_files_forbidden_characters_delimited.txt \
  > "$output"/filenames_with_punctuation_characters.txt
piaStatsPunctuations=$(cat "$output"/filenames_with_punctuation_characters.txt | wc -l)

# detect symbol characters
awk 'BEGIN{ FS="pr3ttY_un1que_delimiTer";OFS="/" } $2 ~ /[&*#@|$]/ { print $1, $2 }' \
  "$output"/tmp_files_forbidden_characters_delimited.txt \
  > "$output"/filenames_with_symbol_characters.txt
piaStatsSymbols=$(cat "$output"/filenames_with_symbol_characters.txt | wc -l)

# detect bracket characters
awk 'BEGIN{ FS="pr3ttY_un1que_delimiTer";OFS="/" } $2 ~ /[]\[<>]/ { print $1, $2 }' \
  "$output"/tmp_files_forbidden_characters_delimited.txt \
  > "$output"/filenames_with_bracket_characters.txt
piaStatsBrackets=$(cat "$output"/filenames_with_bracket_characters.txt | wc -l)

# detect backslash character
awk 'BEGIN{ FS="pr3ttY_un1que_delimiTer";OFS="/" } $2 ~ /[\\]/ { print $1, $2 }' \
  "$output"/tmp_files_forbidden_characters_delimited.txt \
  > "$output"/filenames_with_backslash_character.txt
piaStatsBackslash=$(cat "$output"/filenames_with_backslash_character.txt | wc -l)

# detect leading, trailing or more than one dot in file name
awk 'BEGIN{ FS="pr3ttY_un1que_delimiTer";OFS="/" } $2 ~ /^\.|\..*\.|\.$/ { print $1, $2 }' \
  "$output"/tmp_files_delimited.txt \
  > "$output"/filenames_with_dot_characters.txt
piaStatsDots=$(cat "$output"/filenames_with_dot_characters.txt | wc -l)


# compile positives in one list
cat "$output"/filenames_with_*.txt > "$output"/tmp_filenames_with_forbidden_characters.txt

# report results
if [ -s "$output"/tmp_filenames_with_forbidden_characters.txt ]
  then
    sort -u "$output"/tmp_filenames_with_forbidden_characters.txt \
      > "$output"/tmp_filenames_with_forbidden_characters_sorted_unique.txt
    piaStatsForbidden=$(cat "$output"/tmp_filenames_with_forbidden_characters_sorted_unique.txt | wc -l)
    echo "Number of file names containing"
    echo "Spaces: $piaStatsSpaces"
    echo "Punctuations: $piaStatsPunctuations"
    echo "Symbols: $piaStatsSymbols"
    echo "Brackets: $piaStatsBrackets"
    echo "Backslashes: $piaStatsBackslash"
    echo "Dots: $piaStatsDots"
    echo "Detected $piaStatsForbidden file names with forbidden characters."
  else
    echo "No file names with forbidden characters detected."
fi


# FIND NOT ALLOWED CHARACTERS

# detect file names containing characters not in the list of allowed characters
# this regex is quite tricky and prone to failure when tempered with
awk 'BEGIN{ FS="pr3ttY_un1que_delimiTer";OFS="/" } $2 ~ /[^a-zA-Z0-9_ÄäÖöÜüß\.\?\+!~–=:'"'"'\)\(%§-]/ { print $1, $2 }' \
  "$output"/tmp_files_delimited.txt \
  > "$output"/tmp_filenames_with_not_allowed_characters.txt

# remove FORBIDDEN results from NOT ALLOWED
if [ -s "$output"/tmp_filenames_with_not_allowed_characters.txt ]
  then
    sort "$output"/tmp_filenames_with_not_allowed_characters.txt \
      > "$output"/tmp_filenames_with_not_allowed_characters_sorted.txt
    comm -13 "$output"/tmp_filenames_with_forbidden_characters_sorted_unique.txt \
      "$output"/tmp_filenames_with_not_allowed_characters_sorted.txt \
      > "$output"/filenames_with_not_allowed_characters.txt
  else
    echo "No file names with not allowed characters found."
    return
fi

# report results
if [ -s "$output"/filenames_with_not_allowed_characters.txt ]
  then
    piaStatsNotAllowed=$(cat "$output"/filenames_with_not_allowed_characters.txt| wc -l)
    echo "Detected $piaStatsNotAllowed file names with not allowed characters."
  else
    echo "No file names with not allowed characters found."
fi

}


function dirNamePolicy {

##########################################
# 1.2 Check directory names against policy
# This differs from the file name check in only one regard: it generates a
# (recursive) list of folder names instead of file names in the beginning.

echo
echo "-----------------Looking for forbidden characters in folder names---------------"
echo

# generate a folder list, format as <path><delimiter><folderame>
find "$input" -type d -fprintf "$output"/tmp_folders_delimited.txt '%hpr3ttY_un1que_delimiTer%f\n'

# FIND FORBIDDEN CHARACTERS IN FOLDER NAMES

# boil down the folder list, keep lines with forbidden characters
grep -e "[]\[<>„“&*#,;@|$\\ ]" \
  "$output"/tmp_folders_delimited.txt \
  > "$output"/tmp_folders_forbidden_characters_delimited.txt

# detect spaces in foldernames
awk 'BEGIN{ FS="pr3ttY_un1que_delimiTer";OFS="/" } $2 ~ / / { print $1, $2 }' \
  "$output"/tmp_folders_forbidden_characters_delimited.txt \
  > "$output"/foldernames_with_spaces.txt
piaStatsSpaces=$(cat "$output"/foldernames_with_spaces.txt | wc -l)

# detect punctuation characters (except ".")
awk 'BEGIN{ FS="pr3ttY_un1que_delimiTer";OFS="/" } $2 ~ /[„“,;]/ { print $1, $2 }' \
  "$output"/tmp_folders_forbidden_characters_delimited.txt \
  > "$output"/foldernames_with_punctuation_characters.txt
piaStatsPunctuations=$(cat "$output"/foldernames_with_punctuation_characters.txt | wc -l)

# detect symbol characters
awk 'BEGIN{ FS="pr3ttY_un1que_delimiTer";OFS="/" } $2 ~ /[&*#@|$]/ { print $1, $2 }' \
  "$output"/tmp_folders_forbidden_characters_delimited.txt \
  > "$output"/foldernames_with_symbol_characters.txt
piaStatsSymbols=$(cat "$output"/foldernames_with_symbol_characters.txt | wc -l)

# detect bracket characters
awk 'BEGIN{ FS="pr3ttY_un1que_delimiTer";OFS="/" } $2 ~ /[]\[<>]/ { print $1, $2 }' \
  "$output"/tmp_folders_forbidden_characters_delimited.txt \
  > "$output"/foldernames_with_bracket_characters.txt
piaStatsBrackets=$(cat "$output"/foldernames_with_bracket_characters.txt | wc -l)

# detect backslash character
awk 'BEGIN{ FS="pr3ttY_un1que_delimiTer";OFS="/" } $2 ~ /[\\]/ { print $1, $2 }' \
  "$output"/tmp_folders_forbidden_characters_delimited.txt \
  > "$output"/foldernames_with_backslash_character.txt
piaStatsBackslash=$(cat "$output"/foldernames_with_backslash_character.txt | wc -l)

# detect leading, trailing or more than one dot in folder name
awk 'BEGIN{ FS="pr3ttY_un1que_delimiTer";OFS="/" } $2 ~ /^\.|\..*\.|\.$/ { print $1, $2 }' \
  "$output"/tmp_folders_delimited.txt \
  > "$output"/foldernames_with_dot_characters.txt
piaStatsDots=$(cat "$output"/foldernames_with_dot_characters.txt | wc -l)


# compile positives in one list
cat "$output"/foldernames_with_*.txt > "$output"/tmp_foldernames_with_forbidden_characters.txt

# report results
if [ -s "$output"/tmp_foldernames_with_forbidden_characters.txt ]
  then
    sort -u "$output"/tmp_foldernames_with_forbidden_characters.txt \
      > "$output"/tmp_foldernames_with_forbidden_characters_sorted_unique.txt
    piaStatsForbidden=$(cat "$output"/tmp_foldernames_with_forbidden_characters_sorted_unique.txt | wc -l)
    echo "Number of folder names containing"
    echo "Spaces: $piaStatsSpaces"
    echo "Punctuations: $piaStatsPunctuations"
    echo "Symbols: $piaStatsSymbols"
    echo "Brackets: $piaStatsBrackets"
    echo "Backslashes: $piaStatsBackslash"
    echo "Dots: $piaStatsDots"
    echo "Detected $piaStatsForbidden folder names with forbidden characters."
  else
    echo "No folder names with forbidden characters detected."
fi


# FIND NOT ALLOWED CHARACTERS

# detect folder names containing characters not in the list of allowed characters
# this regex is quite tricky and prone to failure when tempered with
awk 'BEGIN{ FS="pr3ttY_un1que_delimiTer";OFS="/" } $2 ~ /[^a-zA-Z0-9_ÄäÖöÜüß\.\?\+!~–=:'"'"'\)\(%§-]/ { print $1, $2 }' \
  "$output"/tmp_folders_delimited.txt \
  > "$output"/tmp_foldernames_with_not_allowed_characters.txt

# remove FORBIDDEN results from NOT ALLOWED
if [ -s "$output"/tmp_foldernames_with_not_allowed_characters.txt ]
  then
    sort "$output"/tmp_foldernames_with_not_allowed_characters.txt \
      > "$output"/tmp_foldernames_with_not_allowed_characters_sorted.txt
    comm -13 "$output"/tmp_foldernames_with_forbidden_characters_sorted_unique.txt \
      "$output"/tmp_foldernames_with_not_allowed_characters_sorted.txt \
      > "$output"/foldernames_with_not_allowed_characters.txt
  else
    echo "No folder names with not allowed characters found."
    return
fi

# report results
if [ -s "$output"/foldernames_with_not_allowed_characters.txt ]
  then
    piaStatsNotAllowed=$(cat "$output"/foldernames_with_not_allowed_characters.txt| wc -l)
    echo "Detected $piaStatsNotAllowed folder names with not allowed characters."
  else
    echo "No folder names with not allowed characters found."
fi


}


function hiddenSystemFiles {

##############################################
# 2) Check for operating system specific files

echo
echo "-----------------Loooking for hidden system files-------------------------------"
echo

# in case of reworking/widening this check: update readme.

find "$input" -iname Thumbs.db -o -name .DS_Store >"$output"/systemdateien.txt


if [ -s "$output"/systemdateien.txt ]
  then
    echo "Panic! Operating system specific files found."
  else
    echo "No operating system specific files found."
    rm "$output"/systemdateien.txt
fi

}


function hiddenFilesDirs {

############################################
# 3) Check for hidden  files and directories

echo
echo "-----------------Looking for hidden files and directories-----------------------"
echo

find "$input" -name ".*" -print >"$output"/hidden_files.txt


if [ -s "$output"/hidden_files.txt ]
  then
    echo "Panic! Hidden files or directories found."
  else
    echo "No hidden files or directories found."
    rm "$output"/hidden_files.txt
fi

}


function emptyFilesDirs {

##########################################
# 4) check for empty files and directories

echo
echo "-----------------Looking for empty files and directories------------------------"
echo

find "$input" -empty >"$output"/empty.txt


if [ -s "$output"/empty.txt ]
  then
    echo "Panic! Empty files or directories found."
  else
    echo "No empty files or directories found."
    rm "$output"/empty.txt
fi

}


function sipStructure {

####################################################################
# 5) check against SIP-specification for representation directories:
#    MASTER/MODIFIED_MASTER/DERIVATIVE_COPY

echo
echo "-----------------Checking SIP conformity of representation directories----------"
echo
echo "Check against SIP-specification for representation directories:"
echo "MASTER/MODIFIED_MASTER/DERIVATIVE_COPY"
echo

# read all directory names into an array.

IFS=$'\n' dirs=( $(find "$input" -mindepth "$SIP_mindepth" -maxdepth "$SIP_maxdepth" -type d -printf "%P\\n") )

# Following echoes are for testing purpose only.
# count items in array
# echo "${dirs[*]}"
# print items in array
# echo "${#dirs[@]}"

for i in "${dirs[@]}"
  do
    # echo "$i"
    cd "$input/$i" || exit
    # test if directory "MASTER" exists
      if [ -d "MASTER" ]
        then
          # Following echo is for testing purpose only. Should not be shown in
          # shell when script is running to reduce amound of messages.
          # echo "$i contains a MASTER directory."
          :
        else
        echo "Panic! $i doesn't contain a MASTER directory."
        printf "%s doesn't contain a MASTER directory.\\n" "$i" >>"$output"/sip_structure_not_ok.txt
      fi

# count number of directories
    dir_count=$(find "$input" -maxdepth 1 -type d | wc -l)

# test if number of directories is not 1
    if [ "$dir_count" -ne 1 ]
      then
        # read directory names into an array
        IFS=$'\n' check_dir_names=( $(find "$input/$i" -maxdepth 1 -type d -printf "%P\\n") )
        # echo "${check_dir_names[@]}"
        # print items in array
        for d in "${check_dir_names[@]}"
        do
        # check for each item in array if it matches the list of allowed
        # directory names
          if [[ "$d" =~ ^(MASTER|MODIFIED_MASTER|DERIVATIVE_COPY)$ ]]
            then
              # Following echo is for testing purpose only. Should not be shown
              # in shell when script is running to reduce amound of messages.
              # echo "$i contains allowed directory names and is ok."
              :
          else
            echo "Panic! $i contains forbidden directory names: '$d'"
            printf "%s contains forbidden directory names: %s\\n" "$i" "$d" >>"$output"/sip_structure_not_ok.txt
          fi
          # count Files in MASTER, if >1, check if directories DERIVATIVE_COPY
          # and MODIFIED_MASTER exist
          if [ $check_for_MM = yes ]
            then
              MASTERfiles_count=$(find "$input/$i/MASTER" -type f | wc -l)
              # test if number of files in MASTER is >1
              if [ "$MASTERfiles_count" -gt 1 ]; then
                if [ -d "DERIVATIVE_COPY" ]; then
                  if [ -d "MODIFIED_MASTER" ]; then
                    :
                  else
                    echo "Panic! $input/$i is missing MODIFIED_MASTER"
                    printf "%s/%s is missing MODIFIED_MASTER \\n" "$input" "$i"  >>"$output"/sip_structure_not_ok.txt
                  fi
                else
                  :
                fi
              fi
            fi
        done
    fi
    cd "$input" || exit
  done

# reset working directory to PIA's location
cd $piaDir

}


function bigFiles {

#########################
# 6) check for files >2GB

echo
echo "-----------------Looking for files bigger than 2 GB-----------------------------"
echo

find "$input" -size +2G >>"$output"/big_files.txt


if [ -s "$output"/big_files.txt ]
  then
    echo "Panic! Files > 2GB found."
  else
    echo "No files bigger than 2GB found."
    rm "$output"/big_files.txt
fi

}


function dubCheck {

########################
# 7) check for duplicates

echo
echo "-----------------Looking for duplicate files------------------------------------"
echo

# Duplicates are identified by md5-hashes, not by filenames. Since we expect
# lots of merely renamed files in MODIFIED_MASTER subdirectories, an
# indiscriminate check on all files would result in a lot of false positives.
# Therefore we perform two checks, mutually excluding the MASTER and
# MODIFIED_MASTER subdirectories. The results are merged in one report.

# generate file list
find "$input" -type f -fprint "$output"/tmp_files_without_md5sums.txt

# get number of files to process
numberOfFiles=$(cat "$output"/tmp_files_without_md5sums.txt | wc -l)
numberOfFilesProcessed=0

# iterate over file list, generate md5 hashes
while read file
do
  md5sum "$file" >> "$output"/tmp_files_with_md5sums.txt
  numberOfFilesProcessed=$((numberOfFilesProcessed + 1))
  echo -en "\e[0K\r Calculating hash for file $numberOfFilesProcessed of $numberOfFiles..."
done < "$output"/tmp_files_without_md5sums.txt

printf "\n"

# compile a file list excluding MASTER folders
grep -v "/MASTER/" "$output"/tmp_files_with_md5sums.txt \
  > "$output"/tmp_files_without_master.txt

# compile a file list excluding MODIFIED_MASTER folders
grep -v "/MODIFIED_MASTER/" "$output"/tmp_files_with_md5sums.txt \
  > "$output"/tmp_files_without_modified_master.txt

# Sort the file lists and discard all lines starting with a unique hash. This
# keeps only duplicate files in the lists.
sort "$output"/tmp_files_without_master.txt \
  | uniq -D -w 32 \
  > "$output"/tmp_files_without_master_sorted_duplicates.txt

sort "$output"/tmp_files_without_modified_master.txt \
  | uniq -D -w 32 \
  > "$output"/tmp_files_without_modified_master_sorted_duplicates.txt

# Join both lists, sorted, only unique lines (option '-u'). The 'grouped' list
# separates identical files by a newline.
sort -u "$output"/tmp_files_without_master_sorted_duplicates.txt \
  "$output"/tmp_files_without_modified_master_sorted_duplicates.txt \
  | uniq -w 32 --group > "$output"/tmp_duplicates_by_md5_grouped.txt

# If the list is not empty, there are duplicates. Else there are none.
if [ -s "$output"/tmp_duplicates_by_md5_grouped.txt ]
then
  echo
  echo "There are duplicates."
  echo
else
  echo
  echo "No duplicates found. You are lucky, or something went wrong."
  echo
  return
fi

# sort output list by number of occurances
echo "Rearranging duplicate list."
echo
currentDir=$PWD
cd "$output"

csplit tmp_duplicates_by_md5_grouped.txt \
  --prefix="tmp_splitted_duplicates_" \
  --suffix-format="%06d.txt" \
  --suppress-matched \
  --silent '/^$/' {*}

for file in tmp_splitted_duplicates*
do
  len=$(cat $file | wc -l)
  mv "$file" $(printf "%03d_%s\n" $len $file)
done

for file in *tmp_splitted_duplicates*
do
  cat $file >> duplicates_sorted_by_occurance.txt
  echo >> duplicates_sorted_by_occurance.txt
done

rm *tmp_splitted_duplicates*

cd "$currentDir"

}


function archiveFiles {

########################
# 8) look for (possibly compressed) archive files

echo
echo "-----------------Looking for archive files--------------------------------------"
echo

# make a list of identifier folders
find "$input" -maxdepth $id_depth -mindepth $id_depth -type d \
  > "$output"/tmp_id_folders.txt

numberOfFolders=$(cat "$output"/tmp_id_folders.txt | wc -l)
numberOfFoldersProcessed=0

# find archives by MIME type, folder by folder

# this loop takes a while. if one were inclined to optimize this, keep
# in mind the vast majority of the execution time (like 96 percent-ish)
# is spent with the "... -exec file ..." part.
# so unless there is a high performance alternative to determine the
# MIME type of a file, there is no point in fiddling with this.
while read folder
do
  find "$folder" -type f -exec file -F 'pr3ttY_un1que_delimiTer' -i {} \; \
    | grep -F -f "$piaDir"/search-patterns_archive_mime_types.lst \
    >> "$output"/tmp_archive_files.txt
  numberOfFoldersProcessed=$((numberOfFoldersProcessed +1))
  echo -en "\e[0K\r Processing folder $numberOfFoldersProcessed of $numberOfFolders..."
done < "$output"/tmp_id_folders.txt

printf "\n"

# get rid of false positives, output as csv

# files like epub or office documents may be report ed as MIME type
# "application/zip". these get purged here, based on their file
# extension.
# also, beware: the trailing space in the following FS is a hackish way
# to get rid of padding.

awk 'BEGIN{ FS="pr3ttY_un1que_delimiTer ";OFS="," } tolower($1) !~ /epub$|docx$/ { print "\042"$1"\042", $2 }' \
  "$output"/tmp_archive_files.txt \
  > "$output"/archive_files.csv

# identify zip archives containing macOS ressource fork files
if [ "$peek_in_archives" = true ]
  then
    cat "$output"/tmp_archive_files.txt | grep -F "application/zip" \
      > "$output"/tmp_zip_archive_files_delimited.txt

    awk -F 'pr3ttY_un1que_delimiTer' '{ print $1 }' \
      "$output"/tmp_zip_archive_files_delimited.txt \
      > "$output"/tmp_zip_archive_files.txt

    echo "Scanning ZIP archives for macOS ressource fork files."

    while read zip
    do
      ( unzip -l $zip | grep -F -q "._" ) && echo $zip >> "$output"/macos_ressource_fork_files.txt
    done < "$output"/tmp_zip_archive_files.txt
fi

# report stats
if [ -s "$output"/archive_files.csv ]
  then
    piaStatsArchives=$(cat "$output"/archive_files.csv | wc -l)
    echo "Detected $piaStatsArchives archive files according to MIME types."
  else
    echo "No archive files found."
fi

if [ -s "$output"/macos_ressource_fork_files.txt ]
  then
    piaStatsMacosInZip=$(cat "$output"/macos_ressource_fork_files.txt | wc -l)
    echo "Found $piaStatsMacosInZip ZIPs containing macOS ressource fork files."
  elif [ "$peek_in_archives" = false ]
    then
      echo "Could not scan archives for macOS ressurce forks."
  else
    echo "Found no ZIPs containing macOS ressource fork files."
fi

}


########################
# MAIN PROGRAM STRUCTURE

# clear the screen
clear

echo
echo "                    ____   ___      _      "
echo "                   |  _ \ |_ _|    / \     "
echo "  Pre              | |_) | | |    / _ \    "
echo "  Ingest           |  __/  | |   / ___ \   "
echo "  Analyzer         |_|    |___| /_/   \_\  "
echo


# get and display PIA's config parameters
piaConfig

echo
echo "Input directory is:"
# echo
echo "$input"
echo
echo "Output will be written to:"
# echo
echo "$output"
echo
echo "Depth of identifier directories: $id_depth"
echo
echo "SIP structure contains MODIFIED_MASTER: $check_for_MM"
echo
echo "--------------------------------------------------------------------------------"
echo "    OPTIONS"
echo

# set prompt for select
PS3='Please type in the number of your choice: '

# define an array with menu options
option=(
"Perform all checks and exit"
"Check everything but duplicates"
"Check everything but duplicates and archives"
"Find forbidden characters in filenames"
"Find the usual hidden system files"
"Find hidden files and directories"
"Find empty files and directories"
"Check SIP conformity of directories"
"Look for files bigger than 2 GB"
"Find duplicates"
"Find archive files by MIME type"
"Quit"
)

# interactive menu utilizing select
select choice in "${option[@]}"
do
  case $choice in
    "Perform all checks and exit")
      fileNamePolicy
      dirNamePolicy
      hiddenSystemFiles
      hiddenFilesDirs
      emptyFilesDirs
      sipStructure
      bigFiles
      archiveFiles
      dubCheck
      break
      ;;
    "Check everything but duplicates")
      fileNamePolicy
      dirNamePolicy
      hiddenSystemFiles
      hiddenFilesDirs
      emptyFilesDirs
      sipStructure
      bigFiles
      archiveFiles
      ;;
    "Check everything but duplicates and archives")
      fileNamePolicy
      dirNamePolicy
      hiddenSystemFiles
      hiddenFilesDirs
      emptyFilesDirs
      sipStructure
      bigFiles
      ;;
    "Find forbidden characters in filenames")
      fileNamePolicy
      dirNamePolicy
      ;;
    "Find the usual hidden system files")
      hiddenSystemFiles
      ;;
    "Find hidden files and directories")
      hiddenFilesDirs
      ;;
    "Find empty files and directories")
      emptyFilesDirs
      ;;
    "Check SIP conformity of directories")
      sipStructure
      ;;
    "Look for files bigger than 2 GB")
      bigFiles
      ;;
    "Find duplicates")
      dubCheck
      ;;
    "Find archive files by MIME type")
      archiveFiles
      ;;
    "Quit")
      break
      ;;
  esac
done

#########
# Cleanup

# remove temporary files if any
if [[ $( ls "$output"/tmp_*.txt 2>/dev/null ) ]]
  then
    echo
    echo "Removing temporary files."
    rm "$output"/tmp_*.txt
fi

# remove empty reports
for file in "$output"/*.txt "$output"/*.csv
do
  if [ ! -s $file ]
    then
      rm $file 2>/dev/null
  fi
done

# remove output subdir if empty
rmdir $output 2>/dev/null && { printf "\nNothing to report. Exiting PIA.\n"; exit 0; }

echo
echo "Exiting PIA. Please check reports in"
echo "$output"
echo

exit 0
