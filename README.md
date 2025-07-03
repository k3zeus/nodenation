# Nodenation
Nation of Nodes Project Repository
#
There are two installation methods:

Method 1 - Gitclone:

Download Menu Script for base instalation:

$ sudo cd /root/
#
$ sudo git clone https://github.com/k3zeus/nodenation.git /root/nodenation

$ find /root/nodenation/ -type f -name "*.sh" -print0 | xargs -0 dos2unix
#
Change permition to scripts:

find /root/nodenation/ -name "*.sh" -type f -print0 | xargs -0 chmod +x

#
Execute the Menu:

$ /root/nodenation/./menu.sh

#
#

Method 2 - Online Script:

curl -sS https://raw.githubusercontent.com/k3zeus/nodenation/refs/heads/main/start.sh | bash
