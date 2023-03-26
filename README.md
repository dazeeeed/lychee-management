# Lychee Photo Management Server Script
This is a bash script used for managing the Lychee photo management server. It uploads new photos to a specified album 
and skips duplicates. The script also checks if the datasource path is correctly mounted and generates logs in the 
specified format and location.

## Prerequisites
- access to a Lychee photo management server
- `curl` command line tool
- `jq` command line tool
- `python3` installed
- `getColor.py` file for getting color attributes of an image (this can be replaced later)
- `secrets.env` file containing credentials and token information for authentication.

## Usage
1. Update the DATASOURCE_PATH variable in the script to point to the directory containing the images to upload.
2. Update the ALBUM_ID variable in the script to match the ID of the album where the images will be uploaded.
3. Replace YOUR_ALBUM_NAME with correct name of your album.
4. Fill in the necessary credentials and token information in the secrets.env file.
5. Run the script using 

`bash lychee_management.sh`

or

`./lychee_management.sh`


## Functionality
- Checks if the datasource is correctly mounted and logs an error message if it isn't.
- Authenticates the user using the credentials and token specified in the secrets.env file.
- Retrieves the ID of the specified album.
- Retrieves the list of photos already uploaded to the specified album and skips duplicates.
- Uploads all new images found in the DATASOURCE_PATH directory to the specified album.
- Logs each step and the results of each request made to the server in the specified log file.

## Logfile
The log file is created automatically if it does not exist and is stored in the user's home directory with the name lychee_management.log. The log file is formatted with timestamps and indicates the success or failure of each step of the script.