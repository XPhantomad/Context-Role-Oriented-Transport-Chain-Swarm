import os
import subprocess
import sys
import threading
import time


print(os.getcwd())
# start webapp 
threading.Thread(target=lambda: subprocess.run(["python3", os.getcwd() + "/webapp/swarmDisplay.py"])).start()


for i in range(4):
    robotName = "fb_"+str(i)
    print("start " + robotName)
    time.sleep(2)
    # start Swarm Element Loop
    threading.Thread(target=lambda: subprocess.run(["julia", os.getcwd() + "/swarmElementLoop/transportChain/main.jl", robotName])).start()
    time.sleep(15) # TODO: wait until ready
    # start Single Robot Loop 
    threading.Thread(target=lambda: subprocess.run(["python3", os.getcwd() + "/singleRobotLoop/main.py", robotName, "configTransportChain.ini"])).start()
    time.sleep(2)
    # start Messages Component
    threading.Thread(target=lambda: subprocess.run(["python3", os.getcwd() + "/messagesComponent/main.py", robotName])).start()
    time.sleep(3)
        
