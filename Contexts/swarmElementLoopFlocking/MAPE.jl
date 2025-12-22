include("FlockingCROM.jl")
include("functions.jl")

# Constants
xDist = 0.25
yDist = 0.15
# Message Types
msg_Leader = "Leader"
msg_Deputy = "Deputy"
msg_Follower = "Follower"
msg_nothing = "nothing"
msg_GlobalLigth = "GlobalLight"
msg_Stopper = "Stopper"

function mapeLoop(dataMiddle, message, timeout) #::Tuple{Union{Position, Nothing}, Union{String, Nothing}, Union{String, Nothing}}
	global robotSelf
	
	# 1. Monitor State and behavior of the robot and write it into the model
	# add Information from Single-Robot-Loop into robotSelf data structure
	robotSelf.position.x=dataMiddle.x
	robotSelf.position.y=dataMiddle.y
	robotSelf.theta = dataMiddle.theta
	# ---------------------------------------

	# 2. Analyse Messages and Robot Data (State) and change model accordingly 

	# Deputy detects Leader --> update --> Follow
	if hasRole(robotSelf, Deputy, FlockingTeam) && infoInMessage(message, msg_Leader) != false
		#println("update deputy role")
		leader = PerceivedRobot("leader", infoInMessage(message, msg_Leader))
		#println(infoInMessage(message, msg_Leader))
		@changeRoles FlockingTeam 1 begin
			getObjectsOfRole(getDynamicTeam(FlockingTeam, 1), Leader)[1] << Leader
			leader >> Leader()
		end

	# Follower detects Deputy --> update --> Follow
	elseif hasRole(robotSelf, Follower, FlockingTeam) && infoInMessage(message, msg_Deputy) != false
		#println("update follower role")
		deputy = PerceivedRobot("deputy", infoInMessage(message, msg_Deputy))
		#println(infoInMessage(message, msg_Deputy))
		
		# case 1: Robot followed a Follower before (no Deputy in the team)
		if isempty(getObjectsOfRole(getDynamicTeam(FlockingTeam, 1), Deputy))
			robots = getObjectsOfRole(getDynamicTeam(FlockingTeam, 1), Follower)
			for robot in robots 
				if robot != robotSelf
					@changeRoles FlockingTeam 1 begin
						robot << Follower
						deputy >> Deputy()
					end
				end
			end
		# case 2: Robot followed a Deputy before --> update this Deputy
		else
			@changeRoles FlockingTeam 1 begin
				getObjectsOfRole(getDynamicTeam(FlockingTeam, 1), Deputy)[1] << Deputy
				deputy >> Deputy()
			end
		end
	
	# Follower detects Follower --> update --> Follow
	elseif hasRole(robotSelf, Follower, FlockingTeam) && infoInMessage(message, msg_Follower) != false
		follower = PerceivedRobot("follower", infoInMessage(message, msg_Follower))

		# case 1: Robot followed a Follower before (no Deputy in the team)
		if isempty(getObjectsOfRole(getDynamicTeam(FlockingTeam, 1), Deputy))
			robots = getObjectsOfRole(getDynamicTeam(FlockingTeam, 1), Follower)
			for robot in robots 
				if robot != robotSelf
					@changeRoles FlockingTeam 1 begin
						robot << Follower
						follower >> Follower()
					end
				end
			end
		# case 2: Robot followed a Deputy before --> update this Deputy
		else
			@changeRoles FlockingTeam 1 begin
				getObjectsOfRole(getDynamicTeam(FlockingTeam, 1), Deputy)[1] << Deputy
				follower >> Follower()
			end
		end

	# NewRobot detects Leader --> Follow
	elseif !hasRole(robotSelf, Deputy, FlockingTeam) && infoInMessage(message, msg_Leader) != false
		if getRoles(robotSelf) !== nothing
			disassignRoles(FlockingTeam, 1)
		end
		#println("got deputy role")
		leader = PerceivedRobot("leader", infoInMessage(message, msg_Leader))
		@assignRoles FlockingTeam begin
			name = 1
			robotSelf >> Deputy()
			leader >> Leader()
		end
	
	# NewRobot detects Deputy --> Follow
	elseif !hasRole(robotSelf, Follower, FlockingTeam) && infoInMessage(message, msg_Deputy) != false
		if getRoles(robotSelf) !== nothing
			disassignRoles(FlockingTeam, 1)
		end
		#println("got follower role2")
		deputy = PerceivedRobot("deputy", infoInMessage(message, msg_Deputy))
		@assignRoles FlockingTeam begin
			name = 1
			robotSelf >> Follower()
			deputy >> Deputy()
		end

	# NewRobot detects Follower --> Follower: follow
	elseif !hasRole(robotSelf, Follower, FlockingTeam) && infoInMessage(message, msg_Follower) != false
		if getRoles(robotSelf) !== nothing
			disassignRoles(FlockingTeam, 1)
		end
		#println("got follower role1")
		follower = PerceivedRobot("follower", infoInMessage(message, msg_Follower))
		@assignRoles FlockingTeam begin
			name = 1
			robotSelf >> Follower()
			follower >> Follower()
		end

	# nothing detected --> assign itself as the leader --> drive in direction of the Global light
	elseif !hasRole(robotSelf, Leader, FlockingTeam) && (infoInMessage(message, msg_nothing) != false || infoInMessage(message, msg_Stopper) != false) && infoInMessage(message, msg_GlobalLigth) != false
		if getRoles(robotSelf) !== nothing
			disassignRoles(FlockingTeam, 1)
		end
		#println("got leader role")
		goal = infoInMessage(message, msg_GlobalLigth)
		@assignRoles FlockingTeam begin
			name = 1
			robotSelf >> Leader()
			goal >> Goal()
		end
	end

	
	#4+5. Plan 

	# 1 Follower
	if hasRole(robotSelf, Follower, FlockingTeam)
		predecessorPos = nothing
		# Predecessor is also a Follower
		if isempty(getObjectsOfRole(getDynamicTeam(FlockingTeam, 1), Deputy))
			robots = getObjectsOfRole(getDynamicTeam(FlockingTeam, 1), Follower)
			for robot in robots 
				if robot != robotSelf
					predecessorPos = robot.position
				end
			end
		# Predecessor is a Deputy
		else
			predecessorPos = getObjectsOfRole(getDynamicTeam(FlockingTeam, 1), Deputy)[1].position
		end

		# return target position to stay in the Flock
		if predecessorPos != nothing
			println("follower exec")
			# nothing is returned, if the following position is behind the current
			targetPos = claculateFollowingPosition(predecessorPos)

			return targetPos, "driving", msg_Follower
		end
	
	# 2 Deputy
	elseif hasRole(robotSelf, Deputy, FlockingTeam)
		println("Deputy exec")

		leaderPos = getObjectsOfRole(getDynamicTeam(FlockingTeam, 1), Leader)[1].position
		targetPos = claculateFollowingPosition(leaderPos)
		return targetPos, "driving", msg_Deputy

		

	# 3 Leader
	elseif hasRole(robotSelf, Leader, FlockingTeam)
		globalLightPos = getObjectsOfRole(getDynamicTeam(FlockingTeam, 1), Goal)[1]
		
		# SPECIAL: Stopper condition: Wait until all robots are started --> Stopper will be removed by hand
		if infoInMessage(message, msg_Stopper)!= false
			println("stopped")
			return nothing, "waiting", msg_Leader
		end
		println("normal leading behavior")
		# normal leader behavior
		return globalLightPos, "leading", msg_Leader

	end

end

