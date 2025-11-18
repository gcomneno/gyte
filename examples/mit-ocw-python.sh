#!/usr/bin/env bash
set -euo pipefail

PLAYLIST='https://www.youtube.com/playlist?list=PLUl4u3cNGP62A-ynp6v6-LGBCzeH3VAQB'

gyte-transcript-pl "$PLAYLIST" 2
cd yt-playlist-MIT_6.100L_Introduction_to_CS_and_Programming_using_Python,_Fall_2022

# merge + reflow (quando avremo gyte-merge-pl)
# gyte-merge-pl
