#!/bin/sh

# HELP: (release strg+b before pressing the other key)
# Switch window: strg+b  Arrow-Keys
# Close Window: strg+b d
#   tmux kill session (to stop everything)

SESSION_NAME=$1

# Check if the session already exists
if tmux has-session -t $SESSION_NAME 2>/dev/null; then
    echo "Session $SESSION_NAME already exists. Attaching to it."
    tmux attach-session -t $SESSION_NAME
else
    # Create a new session and name it
    tmux new-session -d -s $SESSION_NAME

    # Send a command to the first pane
    tmux send -t 0 "julia swarmElementLoop/disasterRelayChain/main.jl $1" ENTER

    # Attach to the created session
    #tmux attach-session -t $SESSION_NAME 


    sleep 10s

    # Create a new session and name it
    tmux new-session -d -s $SESSION_NAME
    # Split the window horizontally
    tmux split-window -h
    tmux split-window -v

    # Send a command to the second pane
    tmux send -t 1 "source singleRobotLoop/bin/activate" ENTER
    tmux send -t 1 "source ./rosWorkspace/install/setup.bash" ENTER
    tmux send -t 1 "python3 singleRobotLoop/main.py $1 configTransportChain.ini" ENTER

    sleep 1s

    tmux send -t 2 "source messagesComponent/bin/activate" ENTER
    tmux send -t 2 "source ./rosWorkspace/install/setup.bash" ENTER
    tmux send -t 2 "python3 messagesComponent/mainRelayChain.py $1" ENTER

    # Attach to the created session
    tmux attach-session -t $SESSION_NAME
fi

# source "runtimemodel/bin/activate"
# source /home/adrian/ros_ws/install/setup.bash

# julia Contexts/examples/mainMAPE.jl $1 &

# sleep 3s

# python3 runtimemodel/main.py $1 &
# python3 messages/main.py $1



