import os
import subprocess
import sys
import threading
import time


print(os.getcwd())
# start webapp 
threading.Thread(target=lambda: subprocess.run(["python3", os.getcwd() + "/webapp/swarmDisplay.py"])).start()

threading.Thread(target=lambda: subprocess.run([os.getcwd() + "/Flocking_initializeStopper.sh"])).start()


for i in range(5):
    robotName = "fb_"+str(i)
    print("start " + robotName)
    time.sleep(2)
    # start Swarm Element Loop
    threading.Thread(target=lambda: subprocess.run(["julia", os.getcwd() + "/Contexts/swarmElementLoopFlocking/main.jl", robotName])).start()
    time.sleep(9) # TODO: wait until ready
    # start Single Robot Loop 
    threading.Thread(target=lambda: subprocess.run(["python3", os.getcwd() + "/runtimemodel/main.py", robotName])).start()
    time.sleep(2)
    # start Messages Component
    threading.Thread(target=lambda: subprocess.run(["python3", os.getcwd() + "/messages/mainFlocking.py", robotName])).start()
    time.sleep(2)

threading.Thread(target=lambda: subprocess.run([os.getcwd() + "/Flocking_removeStopper.sh"])).start()
