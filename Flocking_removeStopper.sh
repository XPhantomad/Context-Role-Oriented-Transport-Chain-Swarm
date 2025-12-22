#!/bin/bash

source ~/ros_ws/install/setup.bash

for i in 1 2 3 4 5 6 7 8 9 10
do
    printf "line number $i"
    printf "\n"
    ros2 topic pub --once /Stopper/cmd_vel geometry_msgs/msg/Twist "{linear: {x: 1.0}}"
    sleep 1s
done
ros2 topic pub --once /Stopper/cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.0}}"
