# Qbittorrent-unrar
Script to unpack rar files after qbitorrent is ready with the download

In Qbitttorent UI use: Run External program on torrent completion

add in the line under the text:
/home/unpack_rar.sh "%F" 
* /home/ is the folder you put this script, or you use any other folder where Qbitorrent can excecute it.

Make sure 7z is available on your device (Linux)

chmod 755 for unpack_rar.sh to have it executable


