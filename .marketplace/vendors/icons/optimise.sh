#!/bin/bash

magick mogrify -resize 'x100>' ./*.png
oxipng -i 0 --strip safe ./*.png
