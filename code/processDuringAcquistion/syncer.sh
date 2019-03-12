#!/bin/bash



function myHelp () {
cat <<-END
syncer.sh

Purpose:
 This bash script repeatedly calls rsync to pull data from a mounted directory
 of an acquisition machine onto a local RAID array. It is called by syncAndCrunch.m
 and runs in the background. syncer.sh will cease calling rsync once it finds a 
 file called "FINISHED" in source directory. In practice this should usually happen
 and will occur before syncAndCrunch finishes. If the user aborts syncAndCrunch
 (e.g. with ctrl-C) then a cleanup function will run and kill syncer and any
 associated rsync processes. 
 In general, the user will not directly call this bash script. It will be called by 
 syncAndCrunch only.

Usage:
------
   -h | --help
     Display this help

    -l | --landingDir
     The directory on the local machine where the remote will be copied.
     e.g. /mnt/data/CutterData

    -s | --serverDir
    The server directory containing the sample being acquired
    e.g. /mnt/cutterMount/Sample_XYZ_01

    -r | --rsyncFlag
    The flag used for rsync. By default this is "-a" and it is unlikely this will
    need to be changed.

END
}



# Wipes past input args
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

# Process input args
case $key in
    -h|--help)
    LANDING_DIR="$2"
    myHelp
    exit
    ;;
    -l|--landingDir)
    LANDING_DIR="$2"
    shift # past argument
    shift # past value
    ;;
    -s|--serverDir)
    SERVER_DIR="$2"
    shift # past argument
    shift # past value
    ;;
    -r|--rsyncFlag)
    RSYNC_FLAG="$2"
    
    shift # past argument
    shift # past value
    ;;
    --default)
    DEFAULT=YES
    echo $DEFAULT
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters


# Define a default rsync flag -av
if [ -z "${RSYNC_FLAG/ /}" ]
then
  RSYNC_FLAG=-a
fi


#Clean up directory strings: set any multiple slashes to one and remove trailing slash
LANDING_DIR=$(echo $LANDING_DIR | tr -s /); LANDING_DIR=${LANDING_DIR%/}
SERVER_DIR=$(echo $SERVER_DIR | tr -s /); SERVER_DIR=${SERVER_DIR%/}

#Bail out if the server directory does not exist
if [ ! -d $SERVER_DIR ]
then
  echo "The server directory $SERVER_DIR does not exist"
  exit 1
fi



echo "Running syncer.sh with parameters:"
echo "Landing Directory = $LANDING_DIR"
echo "Server Directory = $SERVER_DIR"
echo "rsync flag       = $RSYNC_FLAG"


#The name of the file which will indicate the acquisition is finished and the rsync loop should stop
COMPLETED_FNAME=FINISHED

#The sample directory name is extracted from the server path
SAMPLE_DIR=$(echo $SERVER_DIR | awk -F "/" '{print $NF}')
echo "Sample directory = $SAMPLE_DIR"

FULL_PATH_TO_COMPLETED_FILE="$LANDING_DIR/$SAMPLE_DIR/$COMPLETED_FNAME"



echo "Running rsync until I see $FULL_PATH_TO_COMPLETED_FILE"
echo "RUNNING --> rsync $RSYNC_FLAG $SERVER_DIR $LANDING_DIR <--"

while [ ! -f $FULL_PATH_TO_COMPLETED_FILE ] 
do 
  # Run the rsync
  rsync $RSYNC_FLAG $SERVER_DIR $LANDING_DIR
  sleep 5
done


# The completed file has appeared and we have stopped the rsync
echo "RSYNC FINISHED"
