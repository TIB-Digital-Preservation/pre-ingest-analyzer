#!/usr/bin/env bash
#author: FS

#script conducts pre-ingest analysis and checks:
  ##1.1 Check file names
  #1.2 Check directory names
  #2) Check for operating system specific files
  #3) Check for invisible files and directories
  #4)check for empty files and directories
  #5)check against SIP-specification Identifier-MASTER/MODIFIED_MASTER/DERIVATIVE_COPY
  #6)check for duplicates
  #7)check for files >2GB

#Dependencies:
  #1) Structure:
  # Script must be saved on the same level as identifier-directories are. Or, otherwise, maxdepth parameter in section 5 must be changed to the corresponding level and mindepth parameter should be
  #added.
  #logfiles are written one level above the script location
  #2) Using Cygwin64Bit, all neccessary packages should be installed by default.



#1) Check against file name policy

#Returns all filenames and directory names containing other characters than specified in the pattern.
# Allowed characters are "a-z", "A-Z", "0-9", "_" , "-" , "+"  and an introducing "./" (from find output).
# Checking file names requires removing the file extension with parameter expansion. Otherwise, all file names will match the pattern due to dot in file extension. This is not neccessary for dir names.

#1.1 Check file names against policy
echo "-------------------------------Check file names against file name  policy--------------------------------"
while read line_file ; do
#trim find-output by removing path name with basename function and file extension with parameter expansion for file names
  name=$(basename "$line_file")
  name_file=$(echo "${name%.*}")
  #Bash String Comparison: find out if variable $name_file contains a substring defined in grep command's regular expression.
  grep -Eq "[^\/0-9A-Za-z_\+\-]" <<< "$name_file" && echo "$line_file" >>../files_special_characters.txt
done < <(find . -type f)
if [ -s ../files_special_characters.txt ]; then
echo "Special characters found."
  else
    echo " No special characters found."
    rm ../files_special_characters.txt
fi

#1.2 Check directory names against policy
echo "-------------------------------Check directory names against file name policy--------------------------------"
while read line_dir ; do
#trim find-output by removing introducing ./ and file extension with parameter expansion for file names
  name_dir=$(echo "$line_dir" | sed 's/^..//')
  #Bash String Comparison: Find Out IF a Variable Contains a Substring.
  grep -Eq "[^\/0-9A-Za-z_\+\-]" <<< "$name_dir" && echo "$line_dir" >>../dir_special_characters.txt
done < <(find . -type d)
if [ -s ../dir_special_characters.txt ]; then
echo "Special characters found."
  else
    echo " No special characters found."
    rm ../dir_special_characters.txt
fi

#2) Check for operating system specific files
echo "-------------------------------Check for operating system specific files--------------------------------"
find . -name Thumbs.db -o -name thumbs.db -o -name THUMBS.DB -o -name .DS_Store >../systemdateien.txt
if [ -s ../systemdateien.txt ]; then
echo "Operating system specific files found."
  else
    echo "No operating system specific files found."
    rm ../systemdateien.txt
fi

#3) Check for hidden  files and directories
echo "-------------------------------Check for hidden  files and directories--------------------------------"
find . -name ".*" -print >../hidden_files.txt
if [ -s ../hidden_files.txt ]; then
echo "Hidden files or directories found."
  else
    echo "No hidden files or directories found."
    rm hidden_files.txt
fi

#4)check for empty files and directories
echo "-------------------------------Check for empty  files and directories--------------------------------"
find . -empty >../empty.txt
if [ -s ../empty.txt ]; then
echo "Empty files or directories found."
  else
    echo "No empty files or directories found."
    rm ../empty.txt
fi
#5)check against SIP-specification for representation directories: MASTER/MODIFIED_MASTER/DERIVATIVE_COPY
#read all directory names into an array. Change -maxdepth parameter to the level where the Identifier-directories are.
echo "-------------------------------Check against SIP-specification for representation directories: MASTER/MODIFIED_MASTER/DERIVATIVE_COPY--------------------------------"
IFS=$'/\n\n' dirs=( $(find . -maxdepth 1 -type d -printf "%P\\n") )
#count items in array
echo "${dirs[*]}"
#print items in array
echo "${#dirs[@]}"
for i in "${dirs[@]}"
  do
   #echo "$i"
    cd "$i" || exit
    #test if directory "MASTER" exists
      if [ -d "MASTER" ]; then
        echo "$i contains a MASTER directory"
        else
        echo "$i doesn't contain a MASTER directory"
        printf "%s doesn't contain a MASTER directory\\n" "$i" >>../../sip_structure_not_ok.txt
      fi
#count number of directories
    dir_count=$(find . -maxdepth 1 -type d | wc -l)
#test if number of directories is not 1
    if [ "$dir_count" -ne 1 ]; then
#read directory names into an array
        IFS=$'/\n\n' check_dir_names=( $(find . -maxdepth 1 -type d -printf "%P\\n") )
        echo "${check_dir_names[@]}"
#print items in array
        for d in "${check_dir_names[@]}"
        do
#check for each item in array if it matches the list of allowed directory names
          if [[ "$d" =~ ^(MASTER|MODIFIED_MASTER|DERIVATIVE_COPY)$ ]]; then
            echo "$i contains allowed directory names: '$d'"
          else
            echo "$i contains forbidden directory names: '$d'"
            printf "%s contains forbidden directory names: %s\\n" "$i" "$d" >>../../sip_structure_not_ok.txt
          fi
        done
    fi
    cd ..
  done

#6)check for files >2GB
echo "-------------------------------Check for files >2GB--------------------------------"
find . -size +2G >>../big_files.txt
if [ -s ../big_files.txt ]; then
echo "Files > 2GB found."
  else
    echo "No files > 2GB found."
    rm ../big_files.txt
fi

#7)check for duplicates
echo "-------------------------------Check for duplicates--------------------------------"
#If shopt -s dotglob is set, Bash includes filenames beginning with a ‘.’ in the results of filename expansion. find
# . -type f shows hidden files anyway.

IFS=$'\n'
file_list=$(find . -type f | sed 's/^..//')
for file in $file_list; do
  md5sum "$file" >>../tmp_md5.txt
done
cut -d' ' -f 1 ../tmp_md5.txt >> ../tmp_md5_trim.txt
sort ../tmp_md5_trim.txt >> ../tmp_md5_sorted.txt
uniq -d ../tmp_md5_sorted.txt > ../tmp_duplicates.txt
if [ -s ../tmp_duplicates.txt ]; then
  echo "Duplicate checksums found."
  while read checksum; do
    grep "$checksum" ../tmp_md5.txt >> ../duplicates_by_md5.txt
  done < ../tmp_duplicates.txt
  #rm ../tmp_duplicates.txt
  else
    echo "No duplicate checksums found."
    rm  ../duplicates_by_md5.txt
fi
rm ../tmp_*.txt
