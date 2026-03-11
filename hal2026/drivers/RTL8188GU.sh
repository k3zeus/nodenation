# RTL8188GU Driver compilation test
# Ghost Nodes v0.1

#!/bin/bash
sudo apt-get update
sudo apt-get install build-essential git dkms linux-headers-$(uname -r)

git clone https://github.com/McMCCRU/rtl8188gu.git

cd rtl8188gu
make
sudo make install

# First, try checking if it's in CDROM mode with lsusb.
# If so, try switching the mode (this may not be necessary in newer versions of Ubuntu).
sudo usb_modeswitch -v 0bda -p b711 -d 

# or 
# sudo eject /dev/cdrom0

echo "Restart to complete the installation"
echo "####################################"
echo "reboot now"

exit 0