#!/bin/bash
docker run -it --net=host --ipc=host --privileged \
    --env="DISPLAY" \
    --env="QT_X11_NO_MITSHM=1" \
    --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
    --volume="${XAUTHORITY}:/root/.Xauthority" \
    argos3-ros2-fchain3 \
    bash -c "cd ros_ws && source install/setup.bash && argos3 -c bridge_example.argos & cd .. && export PATH=/julia-1.10.10/bin:$PATH && cd Context-Role-Oriented-Transport-Chain-Swarm && source /ros_ws/install/setup.bash && source startup/bin/activate && python3 startup/automatedStartup.py"
