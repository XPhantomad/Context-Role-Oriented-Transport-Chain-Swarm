import os
import subprocess
import sys
import threading
import time
import unittest
import re


from matplotlib import pyplot as plt
import rclpy
from selenium import webdriver
from selenium.webdriver.common.by import By
from parameterized import parameterized

from TestROSNode import TestROSSupervisor


robotName = "fb_2"
robotWithLoadDetectedSET = []


class testGoalAdaption(unittest.TestCase):


    @classmethod
    def setUpClass(self):

        print(os.getcwd())

        threading.Thread(target=lambda: subprocess.run(["python3", os.getcwd() + "/webapp/swarmDisplay.py"])).start()
        time.sleep(1)
        threading.Thread(target=lambda: subprocess.run(["julia", os.getcwd() + "/swarmElementLoop/transportChain/main.jl", robotName])).start()
        time.sleep(10)   
        threading.Thread(target=lambda: subprocess.run(["python3", os.getcwd() + "/singleRobotLoop/main.py", robotName])).start()
        time.sleep(1)
        threading.Thread(target=lambda: subprocess.run(["python3", os.getcwd() + "/messagesComponent/main.py", robotName])).start()
        
        rclpy.init(args=None)
        self.rosNode = TestROSSupervisor(robotName)
        threading.Thread(target=lambda: rclpy.spin(self.rosNode)).start()
        
        # Next 2 lines are needed to specify the path to your geckodriver
        geckodriver_path = "/snap/bin/geckodriver"
        driver_service = webdriver.FirefoxService(executable_path=geckodriver_path)

        self.driver = webdriver.Firefox(service=driver_service)
        time.sleep(2)
        self.driver.get("http://127.0.0.1:5000/")

    def testWebapp(self):
        title = self.driver.title
        self.assertEqual(title,"Flexible Model Display")
    
    # 1: Robot with Load detected --> start approximation
    @parameterized.expand([0,1,2,3,4,5,6,7,8,9])
    def testRobotWithLoadDetectedFullTime(self, run):
        self.rosNode.publishLight(" ", 0.0, 0.0)
        time.sleep(2)
        self.rosNode.publishLight("yellow", 300.0, -1.2)
        start = time.time()
        # wait for cmd_vel value
        while(self.rosNode.getAngle() != -0.8):
            continue
        end = time.time()
        
        print("Whole Time: " + str(end-start))
        with open('time_RobotWithLoadDetected.txt', 'a', encoding="utf-8") as f:
            f.write("time:"+ str(end-start)+"\n")
        robotWithLoadDetectedSET.append(end-start)
        self.assertEqual(self.rosNode.getAngle(), -0.8)         
    
    @classmethod
    def tearDownClass(self):   
        self.rosNode.publishLight(" ", 300.0, 0.0)
        self.rosNode.destroy_node()
        rclpy.shutdown()

        plt.boxplot([robotWithLoadDetectedSET, joinerDetectedSET, preyDetectedSET, robotLoadingDetectedSET], vert=False, labels=["Robot with Load detected", "Joiner detected", "Prey detected", "Robot in Loading-State detected"])
        plt.title("Full System Execution Times of different Actions")
        plt.xlabel("sec")
        plt.show()
        return super().tearDown(self)
       
if __name__ == '__main__':
    unittest.main()
    