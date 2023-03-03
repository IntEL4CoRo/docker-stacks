#!/bin/bash
source /home/workspace/ros/devel/setup.bash
# roslaunch cram_pick_place_tutorial world.launch &
roslaunch cram_projection_demos household_pr2.launch &

# export THIS_IP=$(ifconfig 'docker0' | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')
sleep 2
echo ""
echo ""
xvfb-run jupyter-lab --allow-root --no-browser --port 8888 --ip=0.0.0.0