#!/bin/bash

MAX_HEIGHT="1080"
EXCLUDE_VIDEO_FORMAT="hevc"
VIDEO_CODEC="h264"
VIDEO_CODEC_ARGS="-preset medium"
AUDIO_CODEC="mp3"
OTHER_ACCEPTABLE_AUDIO_CODEC="aac"
AUDIO_BIT_RATE="320k"
AUDIO_CODEC_ARGS="-b:a $AUDIO_BIT_RATE"
CONVERTED_DIR_NAME="converted"

if [[ -z "$1" || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "\
Convert large videos down to $VIDEO_CODEC ${MAX_HEIGHT}p, $AUDIO_CODEC $AUDIO_BIT_RATE

Usage: normalize-video.sh [path] [path2] ...

- If a path is a directory, recursively find videos, convert them, and move
  converted to [directory]/$CONVERTED_DIR_NAME
- If a path is a file, convert it and move converted to ./$CONVERTED_DIR_NAME"
    exit
fi

inPaths="$@"

convert() {
    inFile=$1
    convertedFile=$2

    echo "Checking: $inFile ..."
    info="$(avconv -i "$inFile" 2>&1)"
    videoInfo=$(echo "$info" | grep "Stream #.:.([^)]*): Video")
    audioInfo=$(echo "$info" | grep "Stream #.:.([^)]*): Audio")
    echo "  video: $videoInfo"
    echo "  audio: $audioInfo"
    if [[ -z "$videoInfo" || -z "$audioInfo" ]]; then
        echo "  Fail!"
    else
        height=$(echo "$videoInfo" | perl -ne '/, \d+x(\d+)/ && print $1')
        videoArgs=
        audioArgs=
        if [[ "$videoInfo" != *"Video: $EXCLUDE_VIDEO_FORMAT"* && ( "$videoInfo" != *"Video: $VIDEO_CODEC"* || "$height" -gt "$MAX_HEIGHT" ) ]]; then
            videoArgs="-c:v $VIDEO_CODEC $VIDEO_CODEC_ARGS -filter:v scale=-1:$MAX_HEIGHT"
        fi
        if [[ "$audioInfo" != *"Audio: $AUDIO_CODEC"* && "$audioInfo" != *"Audio: $OTHER_ACCEPTABLE_AUDIO_CODEC"* ]]; then
            audioArgs="-c:a $AUDIO_CODEC $AUDIO_CODEC_ARGS"
        fi
        if [[ -z "$videoArgs" && -z "$audioArgs" ]]; then
            echo "  Skipped"
        else
            if [[ -z "$videoArgs" ]]; then videoArgs="-c:v copy"; fi
            if [[ -z "$audioArgs" ]]; then audioArgs="-c:a copy"; fi
            tmpFile=$(echo "$inFile" | perl -pe "s/\.[^.]*$/.tmp.mkv/g")
            outFile=$(echo "$inFile" | perl -pe "s/\.[^.]*$/.mkv/g")
            echo "  converting: $inFile -> $outFile"
            if [[ -f "$tmpFile" ]]; then rm "$tmpFile"; fi
            if ffmpeg -i "$inFile" $videoArgs $audioArgs -n "$tmpFile"; then
                mkdir -p $(dirname "$convertedFile")
                mv "$inFile" "$convertedFile"
                mv "$tmpFile" "$outFile"
                echo "  Success! (Old file moved to $convertedFile)"
            else
                rm "$tmpFile"
                echo "  Fail!"
            fi
        fi
    fi
}

for inPath in "${inPaths[@]}"; do
    if [[ -f "$inPath" ]]; then
        convert "$inPath" "./$CONVERTED_DIR_NAME"
    else
        pushd "$inPath"
            find . -type f \( -iname \*.mp4 -o -iname \*.mpg -o -iname \*.mpeg -o -iname \*.mkv -o -iname \*.mov \) -print0 | while IFS= read -r -d '' inFile; do
                convert "$inFile" "converted/$inFile"
            done
        popd
    fi
done


