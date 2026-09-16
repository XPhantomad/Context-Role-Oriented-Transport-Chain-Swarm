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
    threading.Thread(target=lambda: subprocess.run(["julia", os.getcwd() + "/Contexts/swarmElementLoop/main.jl", robotName])).start()
    time.sleep(15) # TODO: wait until ready
    # start Single Robot Loop 
    threading.Thread(target=lambda: subprocess.run(["python3", os.getcwd() + "/runtimemodel/main.py", robotName])).start()
    time.sleep(2)
    # start Messages Component
    threading.Thread(target=lambda: subprocess.run(["python3", os.getcwd() + "/messages/main.py", robotName])).start()
    time.sleep(3)
        
