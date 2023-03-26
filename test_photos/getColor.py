#!/usr/bin/python3

import math
import sys
from PIL import Image

# Hue : 0-360
# Saturation : 0-1
# Value : 0-1
def nameOfTheColor(hue,saturation,value):
    # If saturation is low, is probably a shade of grey.
    if saturation < 0.3:
        # Discrimating the shade of grey based on Value
        if value < 0.3:
            return "Black"
        elif value < 0.6:
            return "Grey"
        else:
            return "White"
    else: #If saturation is high enough
        # We will compare the Hue to this table
        hue_to_colorname_dict={15:"Red",45:"Orange",75:"Yellow",165:"Green",195:"Cyan",270:"Blue",300:"Purple",330:"Rose",360:"Red"}
        # For each threshold in the table
        for k in hue_to_colorname_dict:
            # We return the name corresponding to the first fitting interval
            if hue < k:
                return hue_to_colorname_dict[k]
                break

# Returning the first and second index of the maximum values of the list
def indexOfMaxAndsecondMax(l):
    max=sec_max=-math.inf
    idx_max=idx_sec_max=-1
    for i,v in enumerate(l):
        if v > max:
            sec_max = max
            idx_sec_max=idx_max
            max = v
            idx_max=i
        elif v > sec_max and v != max:
            sec_max = v
            idx_sec_max=i
    return idx_max,idx_sec_max

# If we don't receive enough argument, we quit and print an informative message
if len(sys.argv) < 2:
    print("Usage : ",sys.argv[0]," IMAGE_NAME [-d]")
    sys.exit()
    
# Read image, then quantize if (reduce it to a very scarce palette), then convert it to Hue/Saturation/Value           
img = Image.open(sys.argv[1]).quantize(3).convert("HSV")
# If -d => show the resulting image for debug
if len(sys.argv) > 2 and sys.argv[2] == "-d":
    img.show()
# Get the histogram of the channels, then identify the first and second index of this histogram.
# They correspond to the main and second main color of the quantized image
hue_i1,hue_i2 = indexOfMaxAndsecondMax(img.getchannel("H").histogram())
sat_i1,sat_i2 = indexOfMaxAndsecondMax(img.getchannel("S").histogram())
val_i1,val_i2 = indexOfMaxAndsecondMax(img.getchannel("V").histogram())
# Normalize values
hue1=360*hue_i1/256
hue2=360*hue_i2/256
sat1=sat_i1/256
sat2=sat_i2/256
val1 = val_i1/256
val2 = val_i2/256
# Printing the HSV values
#print(hue1, sat1, val1)
#print(hue2, sat2, val2)
# Printing the name of the two corresponding colors
print(nameOfTheColor(hue1, sat1,val1),nameOfTheColor(hue2, sat2,val2),sep=",")