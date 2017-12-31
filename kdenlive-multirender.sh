#!/bin/bash

# kdenlive-multirender.sh | Multi-threaded video rendering for Kdenlive
# Version 0.0.1
# Created by unfa 2017-12-13

# Getting input

INPUT=$1 # The first passed argument has to be a Kdenlive render script (for example "Project_001.sh")
PARTS=$2 # The second passed parameter is the number of threads to use.

# processing the information

IN=$(grep -o " in=[0-9]* "  "$INPUT" | cut -d= -f2 | xargs) # Get the first frame for the project
OUT=$(grep -o " out=[0-9]* "  "$INPUT" | cut -d= -f2 | xargs) # Get the last frame for the project
PATHRAW=$(grep -o "TARGET_0=.*"  "$INPUT") # Identify the target file path
PATHFILE=$(dirname "${PATHRAW}" | sed -e 's/TARGET_0="file:\/\///g' ) # Get the clean file path
TARGET=$(grep -o "TARGET_0=.*"  "$INPUT" | rev | cut -d/ -f1 | rev | cut -d'"' -f1) # Get the output video file for this project

#ffmpeg can't read urlencoded paths
urldecode() {
    # urldecode <string>

    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

echo "IN=$IN OUT=$OUT" # verify we got it right

rm list.txt # clear the list.txt file

for i in $(seq -w 01 $PARTS); do # for each thread...
    
    PART=$i
    IN2=$(echo "(($OUT - $IN) / $PARTS ) * ($PART - 1)" | bc) # calculate the thread start frame
    if [[ "$PART" == "$PARTS" ]]; then # if this is the last thread
        OUT2=$OUT # use the global last frame for this thread (the last thread usually has to render a few frames more, compensating for division errors)
    else # otherwise
        OUT2=$(echo "(($OUT - $IN) / $PARTS ) * $PART -1" | bc) # calculate the last frame for this thread
    fi
    
    TB=$(echo $TARGET | cut -d. -f1) # slice out the basename of the output file
    TE=$(echo $TARGET | cut -d. -f2) # slice out the filename extension
    
    TARGET2="$TB-$i.$TE" # compose a filename for the thread output
    
    echo "PARTS=$PARTS PART=$PART IN=$IN2 OUT=$OUT2" # print it out for verification
    echo 
    
    sed -e "s/in=$IN/in=$IN2/" "$INPUT" | sed -e "s/out=$OUT/out=$OUT2/" | sed -e "s/$TARGET/$TARGET2/" > "$PART.sh" # replace the IN, OUT and TARGET information in the source Kdenlicve render script and write that to a new shell script
    
    echo "file '$(urldecode $PATHFILE/$TARGET2)'" >> list.txt # add a line to out concatenation list.txt file for ffmpeg to use later
    
    bash "$PART.sh" & # run the newly created script in the background
    echo
done

wait # wait until all rendering threads finish

echo "Concatenating files..."

ffmpeg -f concat -safe 0 -i list.txt -c copy "$TARGET" # merge the individual files into one

echo "All done!"
