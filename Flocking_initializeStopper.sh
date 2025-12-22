#!/bin/bash

source ~/ros_ws/install/setup.bash
ros2 topic pub --once /Stopper/cmd_led argos3_ros2_bridge/msg/Led "{color: "brown", mode: "SINGLE", index: 12}"
