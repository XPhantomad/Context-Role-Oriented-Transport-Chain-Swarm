import json
import threading
import time
from modelUtils.robotSupervisor import *
import rclpy
import socket
from modelImpl.robotModelImpl import *
import re
import sys
import configparser

# cli arguments for robot name
name = sys.argv[1]
number = re.findall(r'\d+', name)   

global addr, udpClientSocket, bufferSize
addr = None
start = False
bufferSize = 1024
HOST = "127.0.0.1"  
PORT = 2000+int(number[0])*2 # Port to listen on (non-privileged ports are > 1023)
addrPort = (HOST,PORT)


config = configparser.ConfigParser()
config.read("config.ini")

# Access values
DIST_TOLERANCE = float(config["SRL"]["goalReachedTolerance"])
DIST_LOADING = float(config["SRL"]["loadingTolerance"])


# receives Messages from the Swarm Element Loop
def receiveMessages():
    global start, addr, udpClientSocket    
    while(True): 
        msg = udpClientSocket.recv(bufferSize) # BLOCKS
        if(msg.decode() == "start"):
            start = True
        else:
            msg = json.loads(msg.decode())
            #print(msg)
            if(len(msg)>=2):
                model.implementation(msg["xTarget"],msg["yTarget"], msg["state"], msg["message"])

# creates a Status message in JSON of the runtime model and sent it via Socket to the Swarm Element Loop
# runs with 10Hz to meet the frequency of the initial checks of the SEL
def publishMessages():
    global start, udpClientSocket, addr
    while True:
        if(udpClientSocket and start):       # The sending of messages only starts when the start message has been received.
            d = {}
            robot = model.robots
            # adds only attributes of robot to dict
            d[model.robots.getname()] = {}
            for a in [a for a in dir(robot) if not a.startswith('__') and callable(getattr(robot, a)) and "get" in a] :
                # must call getters, bacause otherwise Area would not return name but only reference               
                # appends attribute name from getter function name without get and attribute Value
                d[robot.getname()][(a[3:])] = getattr(robot, a)()
            #print(robot.getload())
            udpClientSocket.send(str.encode(json.dumps(d)+ "\n"))
            
        time.sleep(0.1) # depends on the performance of your PC

print("Staaaart")     


waiting = StateImpl(1, "waiting", 0.0)
driving = StateImpl(2, "driving", float(config["SRL"]["drivingSpeed"]))  # 5.0 for Flocking ; 1.0 for Transport Chain
leading = StateImpl(3, "leading", 0.5)  
load = StateImpl(5, "load", 0.0, True, False)
unload = StateImpl(6, "unload", 0.0, False, True)

msg_joiner = MsgImpl(1,"Joiner", "green")
msg_robotWithLoad = MsgImpl(2, "Robot with Load", "yellow")
#msg_prey = MsgImpl(3, "Prey", "red")
msg_Chainmember= MsgImpl(4, "Chainmember(Join)", "magenta")
msg_joinerLoading = MsgImpl(5, "Joiner with Loading State", "white")
msg_nothing = MsgImpl(6, "nothing", "black")

# EXTRA:Flocking
msg_Leader = MsgImpl(7, "Leader", "purple")
msg_Deputy = MsgImpl(8, "Deputy", "cyan")
msg_Follower = MsgImpl(9, "Follower", "orange")

model = ModelImpl(None, [waiting, driving, leading, load, unload], [msg_joiner, msg_robotWithLoad, msg_Chainmember, msg_joinerLoading, msg_nothing, msg_Leader, msg_Deputy, msg_Follower])
robot1=RobotImpl(0.0, 0.0, 0.0,0.0, 0.0, name, 1)
robot1.setstate(waiting)
robot1.setmessage(msg_nothing)
model.addRobot(robot1)


# run robotSupervisor-Node
rclpy.init(args=None)

robotSupervisor = RobotSupervisor(robot1.getname())
threading.Thread(target=lambda: rclpy.spin(robotSupervisor)).start()

# Socket for Connection to SEL
udpClientSocket= socket.socket(socket.AF_INET, socket.SOCK_STREAM) 
udpClientSocket.connect(addrPort)

# Reveice from SEL
threading.Thread(target=lambda: receiveMessages()).start()

#Publish to SEL
threading.Thread(target=lambda: publishMessages()).start()

measure = False
oldTime = round(time.time())
##### MAPE-Loop
while(True): 
    # if(round(time.time()) != oldTime):
    #     start = time.time()
    #     oldTime = round(start)
    #     measure = True
    #Monitor
    robot1.setPos(robotSupervisor.getxPos(), robotSupervisor.getyPos(),robotSupervisor.getzPos(), robotSupervisor.getTheta())
    robot1.setLoad(robotSupervisor.getLoad())
    repulsion = robotSupervisor.getv_repulsion()

    #Analyse - makes the abstraction and checks if goal was Reached
    robot1.setProximity(robotSupervisor.getProximity()) # Abstraction already done in robotSupervisor
    if(robot1.geDistanceToTarge()>DIST_TOLERANCE):
        robot1.goalReached = False
    else:
        robot1.goalReached = True
    
    # disable collission avoidance when goal is near
    if(robot1.geDistanceToTarge() <= DIST_LOADING or robot1.state != driving):
        repulsion = np.array([0,0])
    
    # Plan - calculates and sets speeds for the robot
    if(not robot1.getgoalReached() and (robot1.state == driving or robot1.state == leading)):
        robot1.calculateSpeeds(repulsion)

    # if goal reached or state != driving
    elif(robot1.speed != 0.0 or robot1.rotationSpeed != 0.0):
        robot1.speed = robot1.rotationSpeed = 0.0
        robot1.goalReached = False #required to send last velocity command with 0 and 0 to stop the robot    

    #Execute - send speeds to robotSupervisor to publish them to ROS
    if(not robot1.getgoalReached()):
        robotSupervisor.publishVelocity(robot1.speed,robot1.rotationSpeed)
    
    if (robot1.speed == 0.0):
        robotSupervisor.publishGripper(robot1.state.getgrip(), robot1.state.getrelease())
    
    robotSupervisor.publishLight(robot1.message.getledColor()) # TODO: with condition, publish only when changed
    # if(measure):
    #     end = time.time()
    #     with open("timeSRL.txt", "a", encoding="utf-8") as f:
    #         f.write("time:"+ str(end-start)+"\n")
    #     measure = False

robotSupervisor.destroy_node()
rclpy.shutdown()

