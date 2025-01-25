#!/bin/bash

echo "Updating automation..."
cd ~/automation_projects/automation_1
git pull
pip3 install --user -r requirements.txt

echo "Update complete! The automation is now up to date."