include("FlockingCROM.jl")
	

# Constants
xDist = 0.4
yDist = 0.5

function magnitude(vector)
    return sqrt(vector[1]^2+vector[2]^2)
end


robotSelf = Robot("test", Position(-0.5,0.5), 0, false, false)
predecessorPosition = Position(0, 0)  
    
    # # pred is front right 
	# if predecessorPosition.x > robotSelf.position.x
	# 	# Position des anderen Roboters in Koordinatensystem von robotSelf mit Richtung Theta bringen 
	# 	robo = [robotSelf.position.x, robotSelf.position.y]
	# 	v = [predecessorPosition.x, predecessorPosition.y]
	# 	theta = robotSelf.theta
	# 	R = [cos(theta) -sin(theta); sin(theta) cos(theta)]

    #     diffVec = v-robo
    #     println(diffVec)
    #     rotDiffVec = R^(-1) * diffVec
    #     # test, if rsulting vector targets to (0,0)
    #     println(magnitude(robo))
    #     println(magnitude(v))
    #     if (magnitude(robo) > magnitude(v))
    #         rotDiffVec = [-rotDiffVec[1], -rotDiffVec[2]] 
    #     end   
    #     println(rotDiffVec) # correct distances!!!
	# 	# Abstand in Bezug auf das Koordinatensystem bestimmen
    # #pred is left front
    # else
	# 	# Position des anderen Roboters in Koordinatensystem von robotSelf mit Richtung Theta bringen 
	# 	robo = [robotSelf.position.x, robotSelf.position.y]
	# 	v = [predecessorPosition.x, predecessorPosition.y]
	# 	theta = robotSelf.theta
	# 	R = [cos(theta) -sin(theta); sin(theta) cos(theta)]
		
    #     diffVec = v-robo
    #     println(diffVec)
    #     rotDiffVec = R^(-1) * diffVec
    #     println(rotDiffVec) # right distances!!!
    # end

println(mod(3.5, pi))

function vecAddition(vec1, vec2)
	return [vec1[1]+vec2[1], vec1[2]+vec2[2]]
	
end

function claculateFollowingPosition(predecessorPosition)
	robotVector = [robotSelf.position.x, robotSelf.position.y]
	predVector = [predecessorPosition.x, predecessorPosition.y]
	
	theta = robotSelf.theta - (pi/2)
    if theta > pi
        theta = mod(theta,pi)
        theta = -theta
    end
	R = [cos(theta) -sin(theta); sin(theta) cos(theta)]
	
	differenceVector = predVector-robotVector           # robotVec + diffVec = predVec
	rotDiffVec = R^(-1) * differenceVector
	println(rotDiffVec) 

	# RIGHT (left-branch)
	# resulting vector points to the rigth --> pred is front right --> robot itself is in the left branch
	if rotDiffVec[1] > 0 
		rotResultingVector = vecAddition(rotDiffVec, [-xDist, -yDist])
		println(rotResultingVector)
	# LEFT (right branch)
    else
		rotResultingVector = vecAddition(rotDiffVec, [xDist, -yDist])
		println(rotResultingVector)
    end
    # Currently the resultingVector relies on the rotatet coordinate system from R
    # check, if the y-value of the vector is below 0 --> robot should wait in this case
    if rotResultingVector[2] <= 0 
        return nothing
    end

    # rotate the rotResultingVector back into the world system
    resultingVector = R * rotResultingVector

    # add resulting vector for the movement to the current position vector of the robot
    return Position(robotSelf.position.x+resultingVector[1], robotSelf.position.y+resultingVector[2])
end

println(claculateFollowingPosition(Position(0,0)))
