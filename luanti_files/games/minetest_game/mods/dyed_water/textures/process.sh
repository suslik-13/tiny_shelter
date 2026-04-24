#!/bin/bash

# uses imagemagick to recolour the default water sprites. just place a copy of them in this same folder and run it.

convert default_water_source_animated.png -colorspace LinearGray -modulate 500% dyed_water_white_source_animated.png

convert default_water.png -colorspace LinearGray -modulate 500% dyed_water_white.png

convert default_water_flowing_animated.png -colorspace LinearGray -modulate 500% dyed_water_white_flowing_animated.png
