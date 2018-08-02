#!/bin/bash

# kdenlive-multirender.sh | Multi-threaded video rendering for Kdenlive
# Version 0.0.2
# Created by unfa, 2017-12-13, 2018-03-06

### File naming: all tempporary files created by Kdenlive-Multirender are prefixed with 'kmr-'. So after the fact you can clean it up wiht 'rm kmr-*' command (unless you've choosen to name other files in this fashion).

# Getting input

INPUT=$1 # The first passed argument has to be a Kdenlive render script (for example "Project_001.sh")
PARTS=$2 # The second passed argument is the number of parts to split the rendering job into.  High values (like 64) will help mnimize data loss in case of a system crash when rendering a big project. Values smaller than THREADS make no sense.
THREADS=$3 # The third passed argument is the amount of rendering threads to be running at any given time in parallell. Advised values are between 2 and 6. It's recommended to start with a smaller value and see how much memory and CPU time is consumed with a tool like htop. Running too many threads may starve the system for memory and as a result - take it down or progress extremely slowly, which defeats the purpose of this script.

## functions

# ffmpeg can't read urlencoded paths
urldecode() {
    # urldecode <string>

    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

# extracting needed information from the input Kdenlive rendering script

IN=$(grep -o " in=[0-9]* "  "$INPUT" | cut -d= -f2 | xargs) # Get the first frame for the project
OUT=$(grep -o " out=[0-9]* "  "$INPUT" | cut -d= -f2 | xargs) # Get the last frame for the project
PATHRAW=$(grep -o "TARGET_0=.*"  "$INPUT") # Identify the target file path
PATHFILE=$(dirname "${PATHRAW}" | sed -e 's/TARGET_0="file:\/\///g' ) # Get the clean file path
TARGET=$(grep -o "TARGET_0=.*"  "$INPUT" | rev | cut -d/ -f1 | rev | cut -d'"' -f1) # Get the output video file for this project

echo "IN=$IN OUT=$OUT" # verify we got it right

rm kmr-list.txt # clear the kmr-list.txt file

### Prepare individual rendering scripts for each part

breakpoints_mode=FALSE
if ! [[ "$PARTS" =~ ^[0-9]+$ ]]; then
	breakpoints_mode=TRUE
	partsnumber=1
	parts_starts[partsnumber]=0
	echo "Parts was not integer so breakpoints mode is used"
	filename="$PARTS"
	while read -r line
	do
		numba="$line"
		echo "Read from file: $numba"
		parts_ends[partsnumber]=$numba
		partsnumber=$((partsnumber + 1))
		parts_starts[partsnumber]=$((numba+1))
	done < "$filename"
	parts_ends[partsnumber]=$OUT
	echo "there will be $partsnumber parts"
	echo ${parts_starts[@]}
	echo ${parts_ends[@]}
	PARTS=$partsnumber
fi


for i in $(seq -w 01 $PARTS); do # for each part...
    
    PART=$i

    if [[ "breakpoints_mode"==TRUE ]]; then
		IN2=${parts_starts[$i]}
		OUT2=${parts_ends[$i]}
	else
		IN2=$(echo "(($OUT - $IN) / $PARTS ) * ($PART - 1)" | bc) # calculate the thread start frame
		if [[ "$PART" == "$PARTS" ]]; then # if this is the last thread
		    OUT2=$OUT # use the global last frame for this thread (the last thread usually has to render a few frames more, compensating for division errors)
		else # otherwise
		    OUT2=$(echo "(($OUT - $IN) / $PARTS ) * $PART -1" | bc) # calculate the last frame for this thread
		fi
	fi
    
    TB=$(echo $TARGET | cut -d. -f1) # slice out the basename of the output file
    TE=$(echo $TARGET | cut -d. -f2) # slice out the filename extension
    
    TARGET2="kmr-$TB-$i.$TE" # compose a filename for the thread output
    
    echo "PARTS=$PARTS PART=$PART IN=$IN2 OUT=$OUT2" # print it out for verification
    echo 
    
    sed -e "s/in=$IN/in=$IN2/" "$INPUT" | sed -e "s/out=$OUT/out=$OUT2/" | sed -e "s/$TARGET/$TARGET2/" > "kmr-$PART.sh" # replace the IN, OUT and TARGET information in the source Kdenlicve render script and write that to a new shell script

    echo "file '$(urldecode $PATHFILE/$TARGET2)'" >> kmr-list.txt # add a line to out concatenation list.txt file for ffmpeg to use later
done

### exeute the script, maintining no more than $THREADS  concurrent processes

for i in $(seq -w 01 $PARTS); do # for each part...
    
    while [[ $(pgrep -f "bash kmr-" -c) > $(( $THREADS - 1 )) ]]; do # sleeping for so long as there's $THREADS or more processes running
        echo "waiting for a thread to finish..."
        sleep 15s
    done
    
    echo "Starting thread $i"
    bash "kmr-$i.sh" & # run another scrpt in the background
    echo
done

wait # wait until all rendering threads finish

echo "Concatenating files..."

ffmpeg -f concat -safe 0 -i kmr-list.txt -c copy "$(urldecode $PATHFILE/$TARGET)" # merge the individual files into one

echo "All done!"
