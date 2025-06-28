#!/bin/bash

echo "Choose an option:"
echo "1 - Execute script_s.sh"
echo "2 - Executer script_b.sh"
echo "3 or any other key - Exit"

read -p "Enter your choice: " choose

case $chose in
    1)
        if [ -f "/satoshi/script_s.sh" ]; then
            echo "Running script_s.sh..."
	    cp /satoshi/script_s.sh /root/nodenation/
            /bin/bash /root/nodenation/script_s.sh
        else
            echo "Error: /satoshi/script_s.sh not found!"
            exit 1
        fi
        ;;
    2)
        if [ -f "/pleb/script_b.sh" ]; then
            echo "Running script_b.sh..."
            /bin/bash /pleb/script_b.sh
        else
            echo "Error: /pleb/script_b.sh not found!"
            exit 1
        fi
        ;;
    *)
        echo "exitting without execute."
        exit 0
        ;;
esac
