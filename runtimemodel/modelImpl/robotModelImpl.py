import math

import numpy as np
from model.robotModel import *

class RobotImpl(Robot):    
    def __init__(self, xPos=0.0, yPos=0.0, zPos = 0.0, xTarget=0.0, yTarget=0.0, name = "newRobot", id=12, goalReached = True, theta = 0.0, load=False, proximity=False):
        super().__init__(xPos, yPos, zPos, id, name,xTarget,yTarget, goalReached, theta, None, 0.0, 0.0, load, proximity)
    
    def setPos(self, x, y,z, theta):
        self.xPos =x
        self.yPos = y
        self.zPos = z
        self.theta = theta

    def setProximity(self, proximity=False):
        self.proximity = proximity
        
    def setstate(self, state=None):
        self.state = state
    
    def setmessage(self, message=None):
        self.message = message
    
    def setLoad(self, load=False):
        self.load = load

    # calculates and sets the forward and roation speed of the robot
    def calculateSpeeds(self, repulsion):
        ANGLE_TOLERANCE = 0.2 # TODO spielen
        MAX_SPEED = 0.6 #Transport chain
        #MAX_SPEED = 0.3 # Flocking
        MAX_SPEED_ROT = 1.0
        MIN_SPEED_ROT = 0.8
        MIN_SPEED = 0.3  # transport chain
        #MIN_SPEED = 0.1 # Flocking
        GAIN = 0.2
        ANGLE_GAIN = 0.5 #0.05           
        
        distanceToTarget = self.geDistanceToTarge()

        # Potential Field Implementation from: https://github.com/Tim-HW/ROS2-Path-Planning-Turtlebot3-Potential-Field/blob/main/src/potentialF.cpp
        #attraction
        dx= self.xTarget- self.xPos
        dy= self.yTarget- self.yPos
        attraction = np.array([dx/distanceToTarget, dy/distanceToTarget])
        #print("attraction" + str(attraction))
        #print("repulsion" + str(repulsion))

        x_final = attraction[0] + repulsion[0]
        y_final = attraction[1] + repulsion[1]

        targetHeading = math.atan2(y_final, x_final)
        headingError = self.geHeadingError(targetHeading)

        if(abs(headingError) > ANGLE_TOLERANCE):
            self.speed = 0.0
            self.rotationSpeed = ANGLE_GAIN * headingError * self.state.speedFactor
            if abs(self.rotationSpeed) > MAX_SPEED_ROT:
                self.rotationSpeed = (MAX_SPEED_ROT * -1.0) if self.rotationSpeed < 0 else MAX_SPEED_ROT
            if abs(self.rotationSpeed) < MIN_SPEED_ROT:
                self.rotationSpeed = MIN_SPEED_ROT * -1.0 if self.rotationSpeed < 0 else MIN_SPEED_ROT

        else:
            self.rotationSpeed = 0.0 
            self.speed = GAIN * distanceToTarget
            self.speed = self.speed if self.speed<MAX_SPEED else MAX_SPEED 
            self.speed = self.speed * self.state.speedFactor # speed factor has a value between 0 and 1
            self.speed = self.speed if self.speed>MIN_SPEED else MIN_SPEED
            
            

    # ("ge" to prevent that the Model-to-JSON Part calls this function)
    def geDistanceToTarge(self):
        return math.sqrt(pow(self.xTarget - self.xPos,2)+pow(self.yTarget-self.yPos,2))
       
    # ("ge" to prevent that the Model-to-JSON Part calls this function)
    def geHeadingError(self, targetHeading):
        #print(targetHeading)
        headingError1 = targetHeading - self.theta
        headingError2 = self.theta - targetHeading
        if abs(headingError1) > abs(headingError2):
            headingError = headingError2
            print("wrrrwrong")
        else:
            headingError = headingError1

        # avoid rotation more than 180°
        while (headingError >= math.pi):headingError = -2*math.pi + headingError
        while (headingError <= -math.pi): headingError = 2*math.pi + headingError

        return headingError
           
        
class ModelImpl(Model):

    def __init__(self, robot=None, states=None, messages=None):
        # if kwargs:
        #    raise AttributeError('unexpected arguments: {}'.format(kwargs))
        super().__init__(robot, states, messages)

    def addRobot(self, robot):
        self.robots = robot

    def removeRobot(self):
        self.robots= None
    
    # takes data from goal-message and implement them to a specific goal for the runtimemodel
    def implementation(self, xTarget, yTarget, stateName, messageName):
        robot = self.robots
        if(robot != None): 
            robot.xTarget = float(xTarget)
            robot.yTarget = float(yTarget)
            print("Target setted " + str (xTarget) + " " + str(yTarget))
            for state in self.states:
                if(state.getname() == stateName):
                    robot.state = state
                    print("State setted " + state.getname())
            for message in self.messages:
                if (message.getname() == messageName):
                    robot.message = message
                    print("LED setted " + message.getledColor())
        return False

    
class StateImpl(State):
    def __init__(self, id=None, name="default", speedFactor=0.0, grip=False, release=False):
        super().__init__(id, name, speedFactor, grip, release)

class MsgImpl(Message):
    def __init__(self, id=None, name="default",ledColor="blue"):
        super().__init__(id, name, ledColor)
