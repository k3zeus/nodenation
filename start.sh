#!bin/bash
# Start Ghost Nation Script v.01
#
echo "##################################"
echo "## Welcome to Ghost Node Nation ##"
echo "##################################"

echo ""
echo "Download Github Project"
sudo git clone https://github.com/k3zeus/nodenation.git /root/nodenation
find /root/nodenation/ -type f -name "*.sh" -print0 | xargs -0 dos2unix

echo ""
echo "#################################"
echo "# Change permition to scripts: #"
echo "#################################"
find /root/nodenation/ -name "*.sh" -type f -print0 | xargs -0 chmod +x

# Execute the Menu:
echo "###########################################"
echo "### Execute this command ###"
echo "###########################################"
echo "sudo /root/nodenation/./menu.sh"
