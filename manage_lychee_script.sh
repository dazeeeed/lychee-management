#!/bin/bash
# Script used for managing Lychee photo management server.
# Created: 25-03-2023

# Path to the datasource without "/" at the end!
DATASOURCE_PATH="/mnt/c/Users/Lenovo/Documents/POLITECHNIKA-MGR/SEM3/Infrastucture/Lab3/lychee-management/test_photos"
# DATASOURCE_PATH="/mnt/datasource"

# Specify logs format and location
LOGFILE=~/lychee_management.log
timestamp() { printf '%(%F-%H%M%S)T'; }

# If log file does not exist, create it
if [[ ! -e $LOGFILE ]]; then
    touch $LOGFILE
fi

# Check if datasource is correctly mounted
if [[ $(ls $DATASOURCE_PATH 2> /dev/null | wc -l) == 0 ]]; then
    echo "$(timestamp) LOG: DATASOURCE does not have any files! Exiting..." >> $LOGFILE
    exit 1
fi

# Get credentials and token from secrets.env file
USERNAME=$(grep "username" ~/secrets.env | cut -d" " -f2)
PASSWORD=$(grep "password" ~/secrets.env | cut -d" " -f2)
TOKEN=$(grep "token" ~/secrets.env | cut -d" " -f2)

session_response=$(curl -X POST https://photoserver.mde.epf.fr/api/Session::login \
    -H 'Content-Type: application/json' -H 'Accept: application/json' \
    -H 'Authorization:'"$TOKEN" \
    -d '{"username": "'$USERNAME'", "password": "'$PASSWORD'"}' -i -s -c lychee_cookie.cookie)

# Session status (204 Content expected), 0 means fail, 1 means success -> continue
session_status=$(echo $session_response | grep "204 No Content" | wc -l)

if [ $session_status == 0 ]; then
    echo "$(timestamp) LOG: Session is not correct, exiting the script!" >> $LOGFILE
    exit 2
fi

# Get album_id of kpalmi_photos
ALBUM_ID=$(curl -X POST https://photoserver.mde.epf.fr/api/Albums::get \
    -H 'Content-Type: application/json' -H 'Accept: application/json' \
    -H 'Authorization:'$TOKEN \
    -b lychee_cookie.cookie -s \
    | jq '.albums[] | select(.title=="kpalmi_photos_test") | .id')

# Uncomment below to log the album_id
# echo "LOG: Album id: $ALBUM_ID"

UPLOADED_PHOTOS=$(curl -X POST https://photoserver.mde.epf.fr/api/Album::get \
    -H 'Content-Type: application/json' -H 'Accept: application/json' \
    -H 'Authorization:'$TOKEN -b lychee_cookie.cookie \
    -d '{"albumID": '$ALBUM_ID'}' -s)

UPLOADED_PHOTOS_IDS=( $(echo $UPLOADED_PHOTOS | jq -r '.photos[] | .id') )
UPLOADED_PHOTOS_TITLES=( $(echo $UPLOADED_PHOTOS | jq -r '.photos[] | .title') )

FILES="$DATASOURCE_PATH/*"

# UPLOADING FILES
for file in $FILES 
do
    # Get name of the file without extension by reversing the path, getting first element, 
    # reversing again and getting rid of extension with cut again.
    file=$(echo $file | rev | cut -d/ -f1 | rev)
    file_name=$(echo $file | cut -d. -f1)
    file_extension=$(echo $file | cut -d. -f2)

    # Skip files that are not jpg format
    if [[ $file_extension != "jpg" ]]; then
        # Uncomment below to log unprocessed files because of the extension
        # echo "$(timestamp) LOG: Skipping processing of $file_name" >> $LOGFILE
        continue
    fi

    # Search if photo is in album (if is then is_photo_in_album > 0)
    is_photo_in_album=$(echo ${UPLOADED_PHOTOS_TITLES[@]} | grep $file_name | wc -l)

    # If photo is in the album skip to next iteration
    if [ $is_photo_in_album -gt 0 ]; then
        # Uncomment below for logging of skipping the file in case of existence in the album
        # echo "$(timestamp) LOG: Photo $file_name already in the album! Skipping..." >> $LOGFILE
        continue
    fi
    echo "$(timestamp) LOG: Uploading $file_name." >> $LOGFILE

    # Get color attributes for a file - REPLACE LATER!
    photo_attribs=$(python3 $DATASOURCE_PATH/getColor.py $DATASOURCE_PATH/$file)
    tag1=$(echo $photo_attribs | cut -d, -f1)
    tag2=$(echo $photo_attribs | cut -d, -f2)

    # Upload the photo using form request and get id (id with "" !)
    uploaded_photo_id=$(curl -X POST https://photoserver.mde.epf.fr/api/Photo::add \
        -H 'Content-Type: multipart/form-data' -H 'Accept: application/json' \
        -H 'Authorization:'$TOKEN -b lychee_cookie.cookie \
        -F 'albumID='"$ALBUM_ID"'}' -F "file=@$DATASOURCE_PATH/$file" -s | jq '.id')

    # Set title the same as filename and save result of this request to the $set_title_code (1: OK, 0: Failed)
    status_set_title=$(curl -X POST https://photoserver.mde.epf.fr/api/Photo::setTitle \
        -H 'Content-Type: application/json' -H 'Accept: application/json' \
        -H 'Authorization:'$TOKEN -b lychee_cookie.cookie \
        -d '{"photoIDs": ['$uploaded_photo_id'], "title": "'$file_name'"}' -i -s | grep "204 No Content" | wc -l)

    if [ $status_set_title -eq 0 ]; then
        echo "$(timestamp) WARNING: Failed setting the title for $file!" >> $LOGFILE
    fi

    # Set tags of the photo using $tag1 and $tag2
    status_set_tags=$(curl -X POST https://photoserver.mde.epf.fr/api/Photo::setTags \
        -H 'Content-Type: application/json' -H 'Accept: application/json' \
        -H 'Authorization:'$TOKEN -b lychee_cookie.cookie \
        -d '{"photoIDs": ['$uploaded_photo_id'], "tags": ["'$tag1'", "'$tag2'"], "shall_override": true}' -s -i \
        | grep "204 No Content" | wc -l)

    if [ $status_set_tags -eq 0 ]; then
        echo "$(timestamp) WARNING: Failed setting the tags for $file!" >> $LOGFILE
    fi
done


# Get all photos from the album (AGAIN) to check which are not anymore in datasource directory.
UPLOADED_PHOTOS=$(curl -X POST https://photoserver.mde.epf.fr/api/Album::get \
    -H 'Content-Type: application/json' -H 'Accept: application/json' \
    -H 'Authorization:'$TOKEN -b lychee_cookie.cookie \
    -d '{"albumID": '$ALBUM_ID'}' -s)

UPLOADED_PHOTOS_IDS=( $(echo $UPLOADED_PHOTOS | jq -r '.photos[] | .id') )
UPLOADED_PHOTOS_TITLES=( $(echo $UPLOADED_PHOTOS | jq -r '.photos[] | .title') )

# Get length of the UPLOADED_PHOTOS_IDS array
NUMBER_OF_PHOTOS=${#UPLOADED_PHOTOS_IDS[@]}

# DELETE photos that no longer exist in datasource
for (( i=0; i<$NUMBER_OF_PHOTOS; i++ ));
do
    # Create $file_name by concatenating ".jpg" extension
    file_name="${UPLOADED_PHOTOS_TITLES[i]}.jpg"

    # Check if photo exists locally, if yes continue to next iteration
    if test -f $DATASOURCE_PATH/$file_name ; then
        continue
    fi

    # If file doesn't exist in datasource remove this photo from Lychee server
    echo "$(timestamp) LOG: Removing ${UPLOADED_PHOTOS_TITLES[i]} from the server!" >> $LOGFILE

    status_delete_photo=$(curl -X POST https://photoserver.mde.epf.fr/api/Photo::delete \
        -H 'Content-Type: application/json' -H 'Accept: application/json' \
        -H 'Authorization:'$TOKEN -b lychee_cookie.cookie \
        -d '{"photoIDs": ["'${UPLOADED_PHOTOS_IDS[i]}'"]}' -s -i \
        | grep "204 No Content" | wc -l)

    if [ $status_delete_photo -eq 0 ]; then
        echo "$(timestamp) WARNING: Failed deleting ${UPLOADED_PHOTOS_TITLES[i]} from server!" >> $LOGFILE
    fi
done

exit 0
