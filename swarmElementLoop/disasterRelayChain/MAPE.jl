include("ChainCROM.jl")
include("functions.jl")

# Constants
NEST_AND_PREY_LOADING_RANGE = 0.7  # value must be at least the range of the prey light which is around 0.7
MIN_TRANSFERPOINT_DISTANCE = 0.2   # if to low: robot does not move; if to high: robots never join because of the delayed reaction time
ROBOT_PROXIMITY = 0.2	# distance to the detected light blob of the other robot sufficient for load transfer procedure 

EXPLORATION_POS1 = Position(1.0, -1.0) # do not change to values<0 (otherwise tests may crash)
EXPLORATION_POS2 = Position(6.0, 3.0) 

# Message Types
msg_InformedExplorer = "Informed Explorer"
msg_Connector = "Connector"
msg_BaseStation = "BaseStation"
msg_RelayChainIncomplete = "RelayChain incomplete"
msg_RelayChainComplete = "RelayChain complete"
msg_nothing = "nothing"

# Initials
baseStation = Position(-1.0,1.2)
first_time = true
hint = Position(4,1)

function disassignAllRoles()
    if getRoles(robotSelf) !== nothing
        #println(keys(getRoles(robotSelf)[nothing]))
		#disassignRoles(DisasterChainTeam, 3) -> can be left out as far as teams are not nested into each other
		#if getRoles(robotSelf) !== nothing
		teams = keys(getRoles(robotSelf)[nothing])
		for team in teams
			disassignRoles(typeof(team), team.ID )
		end
		#end
    end
end

# function assignSingleRobotChainTeams(prey)
# 	global nest, robotSelf
# 	@assignRoles SingleRobotChainTeam begin
# 		name = 2
# 		nest >> Nest()
# 		robotSelf >> ChainMember()
# 		prey >> Prey()
# 	end 
# 	@assignRoles ChainTeam begin
# 		name = 3
# 		nest >> Nest()
# 		getDynamicTeam(SingleRobotChainTeam, 2) >> SingleRobotChain()
# 	end
# end

# function assignSingleRobotChainTeams(prey, load)
# 	global nest, robotSelf
# 	@assignRoles SingleRobotChainTeam begin
# 		name = 2
# 		nest >> Nest()
# 		robotSelf >> ChainMember()
# 		prey >> Prey()
# 		load >> Load()
# 	end 
# 	@assignRoles ChainTeam begin
# 		name = 3
# 		nest >> Nest()
# 		getDynamicTeam(SingleRobotChainTeam, 2) >> SingleRobotChain()
# 		load >> Load()
# 	end
#end

# function disassignJoinChainTeams()
# 	# disassign JoinChainTeam and if Robot has no other Role the ChainTeam as well 
# 	if length(keys(getRoles(robotSelf)[nothing])) > 1
# 		@changeRoles ChainTeam 3 begin
# 			getDynamicTeam(JoinChainTeam, 37) << RobotJoining
# 		end
# 	else		
# 		disassignRoles(ChainTeam, 3)
# 	end
# 	disassignRoles(JoinChainTeam, 37)
# 	robotSelf.goalGiven = false
# end



function mapeLoop(dataMiddle, message, timeout) #::Tuple{Union{Position, Nothing}, Union{String, Nothing}, Union{String, Nothing}}
	global robotSelf, baseStation, first_time
	
	#1. Monitor state and behavior of the robot and implement it into the runtime model

	# add load state of the robot into swarm runtime model
	# if getRoles(robotSelf) !== nothing
	# 	if dataMiddle.load == true
	# 		#println(keys(getRoles(robotSelf)[nothing]))
	# 		teams = keys(getRoles(robotSelf)[nothing])
	# 		for team in teams
	# 			if isempty(getObjectsOfRole(team, Load))
	# 				@changeRoles typeof(team) team.ID begin
	# 					obj >> Load()
	# 				end
	# 				println("load added")
	# 				robotSelf.goalGiven=false
	# 			end
	# 		end
	# 	else 
	# 		#println(keys(getRoles(robotSelf)[nothing]))
	# 		teams = keys(getRoles(robotSelf)[nothing])
	# 		for team in teams
	# 			if !isempty(getObjectsOfRole(team, Load))
	# 				@changeRoles typeof(team) team.ID begin
	# 					obj << Load
	# 				end
	# 				robotSelf.goalGiven=false
	# 			end
	# 		end
	# 	end
	# end

	# if goalReached in SRL switches from true to false --> it is sure, that the goal has been successfully given to the SRL
	if (robotSelf.goalReached && !dataMiddle.goalReached)
		robotSelf.goalGiven = true
	end
	
	# add Information from Single-Robot-Loop into robotSelf data structure of the swarm runtime model
	robotSelf.goalReached=dataMiddle.goalReached
	robotSelf.position.x=dataMiddle.x
	robotSelf.position.y=dataMiddle.y
	robotSelf.proximity=dataMiddle.proximity

	# ---------------------------------------

	#2. Analyse Messages and Robot Data (State) and change swarm runtime model accordingly 

	## 00 If Relay Robot detects a robot between itself and the base-station --> assign this as its successor (not relevant for any important movements, only for ColorFlip when chain is fully established)
	## 00 If Successor of a Relay has the Color Magenta --> Trigger Chain Flip and switch its color 
	## 00 If Relay Robot lost one of its Pred or Succ --> Flip Chain back
		#--> drive to Pred. Position to close Lack in the Chain (mentioned in Plan step, if no pred is assigned to a relay robot)
	
	## 11 If Informed Explorer has reached the Connector Position and no other is there
	if hasRole(robotSelf, InformedExplorer, InitialTeam) && robotSelf.goalReached # && no connector perceived && disaster perceived
		# TODO: correct the disaster position if necessary
		@assignRoles DisasterChainTeam begin
			name = 3
			baseStation >> BaseStation()
			robotSelf >> Connector()
			getObjectsOfRole(getDynamicTeam(InitialTeam, 2), DisasterGuess)[1] >> Disaster()
		end
		# dissolve initial team, because it is no longer needed
		disassignRoles(InitialTeam, 2)
	end

	## 22 ArrangeRelay: Relay perceived which is closer to the base than the current one --> assign new relay (Action updates the goal pos)
	if hasRole(robotSelf, NewRelay, ArrangeRelayTeam) 
		currentRelay = getObjectsOfRole(getDynamicTeam(ArrangeRelayTeam, 37), CurrentRelay)[1]
		if getDistance(infoInMessage(message, msg_RelayChainIncomplete), baseStation) < getDistance(currentRelay.position, baseStation) # TODO: from second distance directly into RoleAttribute of the currentRelay
			perceivedRobot = PerceivedRobot("Dummy", infoInMessage(message, msg_RelayChainIncomplete)) 
			@changeRoles ArrangeRelayTeam 37 begin
				currentRelay << CurrentRelay
				robotSelf >> CurrentRelay()
			end
		# if nextRelayPos is reached and no other relay closer to the baseStation found --> disassign ArrangeRelayTeam
		elseif robotSelf.goalReached
			@changeRoles DisasterChainTeam 3 begin
				currentRelay >> Predecessor("incomplete")
			end
			disassignRoles(ArrangeRelayTeam, 37)
		end
	end

	# A) Hint received:
		# - asign Initial Team (robot self = informed Explorer, Disaster Guess = rec. Pos, BaseStation = Nest, Recruit = nothing )
		# - Informed explorer has to expose Color for recruitment
		# Action: drive to the Disaster (not to fast to give Recruits the oportunity to follow?)
	if hint != nothing && getRoles(robotSelf) == nothing
		@assignRoles InitialTeam begin
			name = 2
			baseStation >> BaseStation()
			robotSelf >> InformedExplorer()
			hint >> DisasterGuess()
		end 

	# B) Informed Explorer Perceived: become a recruit in that team
	# - assign Initial Team: (robotSelf = Recruit, Base Station, percRobot = Informed Explorer)
	# Action: Follow the Informed Robot - drive to its position
	elseif getRoles(robotSelf) == nothing && infoInMessage(message, msg_InformedExplorer) != false 
		perceivedRobot = PerceivedRobot("Dummy", infoInMessage(message, msg_InformedExplorer)) 
		@assignRoles InitialTeam begin
			name = 2
			baseStation >> BaseStation()
			perceivedRobot >> InformedExplorer()
			robotSelf >> Recruit()
		end 	
	 
		
	# D) Robot Perceives Observer --> assign itself as additional Observer + assign the arrangeTeam for driving to the free position
		# - disassign current role (or initial Team) 
		# - assign Observer Role (or new DisasterChainTeam with Observer Role)
		# Action Observer: drive around the Disaster and stay connected with exactly one Observer/Connector 
			# no concrete position but a task --> 	
			# goal fulfilled, when robot is in the distance of MAX-LightRange from another Observer AND perceives another observer/connector not closer than this range 	

	# C) Disaster perceived: become first Connector
		# - assign DisasterChainTeam (robotSelf = Connector, Disaster-pos, Base Station-pos)
		# Action: drive to the connector Position (has to be calculated and stored directly at assignment - fixed Position)
	
	# E) Perceive part of the Relay Chain (or Connector) without being part of it
		# - assign itself as Connector in the DisasterChainTeam and additionally in the RelayArrange Team
		# Action: drive to free position in direction of the BaseStation
	elseif !hasRole(robotSelf, DisasterChainTeam, Relay) && (infoInMessage(message, msg_Connector) != false || infoInMessage(message, msg_RelayChainIncomplete) != false)
		# case 1: former recruit/informed Explorer --> diassign InitialTeam
		if getDynamicTeam(InitialTeam, 2) !== nothing
			disassignRoles(InitialTeam, 2)
		end
		# case 2: robot is in no team --> assign DisasterChainTeam
		if getRoles(robotSelf) == nothing
			@assignRoles DisasterChainTeam begin
				name = 3
				baseStation >> BaseStation()
				robotSelf >> Relay()
			end
			# assign closest relayChain Segment (MSG-component always returns only the closest perceived Relay)
			perceivedRelayPos = infoInMessage(message, msg_RelayChainIncomplete) != false ? infoInMessage(message, msg_RelayChainIncomplete) : infoInMessage(message, msg_RelayChainIncomplete)
			perceivedRobot = PerceivedRobot("Dummy", perceivedRelayPos) 
			@assignRoles ArrangeRelayTeam begin
				name = 37
				robotSelf >> NewRelay()
				perceivedRobot >> CurrentRelay() # assign the perceived relay, the robot has drive past 
			end
		else
			println("unexpected case - ---------------------------  ---------")
		end
	

	# F) Robot Detects the BaseStation and a part of the Relay Chain:
		# - assign itself as BaseStationRelay and disassign other Relay Role
		# - Trigger: CHAIN FLIP!!!!! -------------------------------------------------- 
	elseif infoInMessage(message, msg_BaseStation) && hasRole(robotSelf, NewRelay, ArrangeRelayTeam)
		@changeRoles DisasterChainTeam 3 begin
			robotSelf << Relay
			robotSelf >> BaseStationRelay()
			currentRelay >> Predecessor("incomplete")
		end
		disassignRoles(ArrangeRelayTeam, 37)

	end


	#3. Plan:

	# 00 Failover
	#if robotSelf = Relay && robotSelf != NewRelay && getRolesOfTeam(DisasterChain).Predecessor.status == lost
	#	return Pred.pos = reobotSelf.pos-baseStation + Distance, "driving", msg_RelayChainIncomplete


#=
	#println(getFirstTeam(robotSelf))
	if timeout
		println("timeout incoming")
		robotSelf.goalGiven = false
	end

	# perceived ChainMember is no longer in proximity --> switch back to driving state
	if hasRole(robotSelf, JoinChainMember, JoinChainTeam) && !robotSelf.proximity && !robotSelf.load
		# switch attribute of the JoinChainMember to LoadingActivated = false
		@changeRoles JoinChainTeam 37 begin
			robotSelf << JoinChainMember
			robotSelf >> JoinChainMember(false)
		end	
	end

	# to close to nest --> skip role changes
	if getDistance(robotSelf.position, nest) < (NEST_AND_PREY_LOADING_RANGE+0.15)
		println("To close to nest")
		open("time.txt", "a") do file
			write(file, "to close to nest")
		end

	# robot is to close to prey AND has load --> skip role changes
	elseif !timeout && getFirstTeam(robotSelf) !== nothing && robotSelf.load && getObjectsOfRole(getFirstTeam(robotSelf), Prey) != [] && getDistance(robotSelf.position, getObjectsOfRole(getFirstTeam(robotSelf), Prey)[1]) < (NEST_AND_PREY_LOADING_RANGE+0.15)
		println("To close to prey")
		open("time.txt", "a") do file
			write(file, "to close to prey")
		end
	
	# JoinChainmember which is ready to receive load perceived --> enable load transfer
	elseif hasRole(robotSelf, ChainMember, JoinChainTeam) && infoInMessage(message,  msg_Joiner_Loading)!=false && robotSelf.load
		# switch attribute of the JoinChainMember to LoadingActivated= true
		if getDistance(infoInMessage(message,  msg_Joiner_Loading), robotSelf.position) <= ROBOT_PROXIMITY
			joiner = getObjectsOfRole(getDynamicTeam(JoinChainTeam, 77), JoinChainMember)[1]
			@changeRoles JoinChainTeam 77 begin
				joiner << JoinChainMember
				joiner >> JoinChainMember(true)
			end	
		end
		open("time.txt", "a") do file
			write(file, "Release Load (JoinChainTeam:ChainMember)")
		end

	# JoinChainMember has approximated to the perceived ChainMember --> switch to load state
	elseif hasRole(robotSelf, JoinChainMember, JoinChainTeam) && robotSelf.proximity && !robotSelf.load && infoInMessage(message,  msg_Chainmember_Join)!=false
		# switch attribute of the JoinChainMember to LoadingActivated = true
		if getDistance(infoInMessage(message,  msg_Chainmember_Join), robotSelf.position) <= ROBOT_PROXIMITY
			@changeRoles JoinChainTeam 37 begin
				robotSelf << JoinChainMember
				robotSelf >> JoinChainMember(true)
			end		
		end
		open("time.txt", "a") do file
			write(file, "Receive Load (JoinChainTeam:JoinChainMember)")
		end

	# robot with load disappeares --> fall back to last meaningful state
	elseif hasRole(robotSelf, JoinChainMember, JoinChainTeam) && !robotSelf.load && ((infoInMessage(message,  msg_robotWithLoad)==false && infoInMessage(message, msg_Chainmember_Join)==false) || timeout) 
		# if robot in ChainTeam or SingleRobotChainTeam --> remember old knowledge and drive to prey/predecessor
		disassignJoinChainTeams()
		println("disassign JoinChain1")
		open("time.txt", "a") do file
			write(file, "deactivateJoinChain() (JoinChainTeam:JoinChainMember)")
		end

	# joiner disappeares --> fall back to last meaningful state
	elseif hasRole(robotSelf, ChainMember, JoinChainTeam) && ((infoInMessage(message, msg_Joiner)==false && infoInMessage(message, msg_Joiner_Loading)==false) || timeout)
		@changeRoles ChainTeam 3 begin
			getDynamicTeam(JoinChainTeam, 77) << RobotJoining
		end
		disassignRoles(JoinChainTeam, 77)
		robotSelf.goalGiven = false
		println("disassign JoinChain2")
		open("time.txt", "a") do file
			write(file, "deactivateJoinChain() (JoinChainTeam:ChainMember)")
		end
	
	# timeout at pred/succ waiting point or prey/nest  --> fall back to the last meaningful state
	elseif timeout 
		# Robot is Intermediate with load --> remove successor, switch to tail
		if robotSelf.load && hasRole(robotSelf, Intermediate, ChainTeam)

			# TODO: Automate --> switch back to Tail automatically, if Successor of Intermediate is removed
			if !isempty(getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Successor))
				@changeRoles ChainTeam 3 begin
					getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Successor)[1] << Successor
				end
			end
			@changeRoles ChainTeam 3 begin
				robotSelf << Intermediate
				robotSelf >> Tail()
			end
			# END TODO: Automate
			println("timeout: succ removed")

		# Robot has no Prey in history and has no load --> switch back to Exploration
		elseif getDynamicTeam(ChainTeam, 3) !== nothing && isempty(getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Prey)) && !robotSelf.load
			disassignAllRoles()
			println("timeout: only chain disassigned")
		
		# Robot is Head or Tail and Prey is known --> switch back to SingleRobotChainTeam
		# TODO: more history knwoledge of previous transfer points --> put it here
		elseif hasRole(robotSelf, Head, ChainTeam) || hasRole(robotSelf, Tail, ChainTeam)
			prey = getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Prey)[1]
			if robotSelf.load # robot is Head
				load = getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Load)[1]
				disassignRoles(ChainTeam, 3)
				assignSingleRobotChainTeams(prey, load)
			else # robot is Tail
				disassignRoles(ChainTeam, 3)
				assignSingleRobotChainTeams(prey)
			end

		# Robot is Intermediate without load and knows the Prey --> remove Predecessor, switch to Head
		elseif !robotSelf.load && hasRole(robotSelf, Intermediate, ChainTeam)
			if !isempty(getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Predecessor))
				@changeRoles ChainTeam 3 begin
					getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Predecessor)[1] << Predecessor
				end
			end
			@changeRoles ChainTeam 3 begin
				robotSelf << Intermediate
				robotSelf >> Head()
			end
			println("timeout: pred removed")
		end
		robotSelf.goalGiven = false
		open("time.txt", "a") do file
			write(file, "timeout")
		end

	# Prey detected initially or later on --> assign SingleRobot chain team, disassign JoinChainTeam
	elseif infoInMessage(message, msg_prey)!=false
		println("prey detected")
		if hasRole(robotSelf, JoinChainMember, JoinChainTeam) 
			disassignJoinChainTeams()
			println("disassign JoinChain1 because of prey")
		end
		if getRoles(robotSelf) === nothing
			prey = infoInMessage(message, msg_prey)
			assignSingleRobotChainTeams(prey)
		end
		open("time.txt", "a") do file
			write(file, "prey detected")
		end

	# Load transferred successfully: Joiner -> Intermediate or Tail
	elseif hasRole(robotSelf, JoinChainMember, JoinChainTeam) && robotSelf.load
		# robot is head and joins with other robot in SingleRobotChain-Mode 
		if hasRole(robotSelf, Head, ChainTeam)
			@changeRoles ChainTeam 3 begin
				robotSelf << Head
				robotSelf >> Intermediate()
			end
		# check that Chain Team has no Tail or Intermediate before assign self as Tail
		# --> first real chain established
		elseif isempty(getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Tail)) && isempty(getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Intermediate))		
			@changeRoles ChainTeam 3 begin
				robotSelf >> Tail()
				# SPECIAL: only necessary if the robot has no Chain Role before
				#getObjectsOfRole(getDynamicTeam(JoinChainTeam, 37), Load)[1] >> Load()
			end
		end
		# robot returns from Nest and finds other Robot with Load -> do nothing -> except of the 3 standard role changes in this case
		
		# 3 standard role changes: 
		transferpoint = Position(robotSelf.position.x, robotSelf.position.y)
		# 1)remove current predecessor if one exists
		if !isempty(getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Predecessor))
			@changeRoles ChainTeam 3 begin
				getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Predecessor)[1] << Predecessor
			end
		end
		# 2)set perceived Chainmember as Predecessor and disassign JoinChainTeam
		@changeRoles ChainTeam 3 begin
			getObjectsOfRole(getDynamicTeam(JoinChainTeam, 37), ChainMember)[1] >> Predecessor(transferpoint)
			getDynamicTeam(JoinChainTeam, 37) << RobotJoining
		end	
		disassignRoles(JoinChainTeam, 37)

		# 3)disassign SingleRobot-Chain-Team if one exists and overtake Prey position to Chain
		if getDynamicTeam(SingleRobotChainTeam, 2) !== nothing
			@changeRoles ChainTeam 3 begin
				getDynamicTeam(SingleRobotChainTeam, 2) << SingleRobotChain
				getObjectsOfRole(getDynamicTeam(SingleRobotChainTeam, 2), Prey)[1] >> Prey()
			end
			disassignRoles(SingleRobotChainTeam, 2)
		end
		open("time.txt", "a") do file
			write(file, "Load received (JoinChainTeam:JoinChainMember)")
		end

	# Load transferred successfully: Chainmember --> Intermediate or Head
	elseif hasRole(robotSelf, ChainMember, JoinChainTeam) && !robotSelf.load
		# robot drives to nest and ohter robot joins who takes the tail role for him
		if hasRole(robotSelf, Tail, ChainTeam)
			@changeRoles ChainTeam 3 begin
				robotSelf << Tail
				robotSelf >> Intermediate()
			end
		# check that Chain Team has no Head before assign self as Head	
		elseif isempty(getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Head)) && isempty(getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Intermediate)) 
			@changeRoles ChainTeam 3 begin
				robotSelf >> Head()
			end	
		end
		
		# robot comes again from prey and other robot will join him --> do nothing --> except of the 3 standard role changes
		
		# 3 Standard role changes: 
		transferpoint = Position(robotSelf.position.x, robotSelf.position.y)
		# 1)remove current successor if one exists
		if !isempty(getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Successor))
			@changeRoles ChainTeam 3 begin
				getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Successor)[1] << Successor
			end
		end

		# 2)set perceived JoinChainMember as Successor and disassign JoinChainTeam
		@changeRoles ChainTeam 3 begin
			getObjectsOfRole(getDynamicTeam(JoinChainTeam, 77), JoinChainMember)[1] >> Successor(transferpoint)
			getDynamicTeam(JoinChainTeam, 77) << RobotJoining
		end
		disassignRoles(JoinChainTeam, 77)
		
		# 3)disassign SingleRobot-Chain-Team if one exists and overtake Prey position to Chain
		if getDynamicTeam(SingleRobotChainTeam, 2) !== nothing
			@changeRoles ChainTeam 3 begin
				getDynamicTeam(SingleRobotChainTeam, 2) << SingleRobotChain
				getObjectsOfRole(getDynamicTeam(SingleRobotChainTeam, 2), Prey)[1] >> Prey()
			end
			disassignRoles(SingleRobotChainTeam, 2)
		end
		open("time.txt", "a") do file
			write(file, "Load released (JoinChainTeam:ChainMember)")
		end
		
	# Robot with load detected --> activate JoinChainTeam (if all constraints are fulfilled)
	elseif !robotSelf.load && infoInMessage(message, msg_robotWithLoad)!=false && !hasRole(robotSelf, JoinChainMember, JoinChainTeam) && infoInMessage(message, msg_prey)==false
		perceivedRobot = PerceivedRobot("Dummy", infoInMessage(message, msg_robotWithLoad), true) 
		# IF Distance Robot to Nest >= Distance RobotwithLoad to Nest --> Robot is in wrong direction for Joining
		if getDistance(robotSelf.position, nest)+MIN_TRANSFERPOINT_DISTANCE < getDistance(perceivedRobot.position, nest)
			@assignRoles JoinChainTeam begin
				name = 37
				robotSelf >> JoinChainMember(false)
				perceivedRobot >> ChainMember()
			end
			println("JoinChain executed")
			
			# case 1: robot is in chain/SingleRobotChain, and drives back to Prey emptily
			if getDynamicTeam(ChainTeam, 3) !== nothing
				@changeRoles ChainTeam 3 begin
					getDynamicTeam(JoinChainTeam, 37) >> RobotJoining()
				end
			# case 2: robot is in exploration state
			else 
				@assignRoles ChainTeam begin
					name = 3
					nest >> Nest()
					getDynamicTeam(JoinChainTeam, 37) >> RobotJoining()
				end
			end

		else
			println("wrong robot with load detected")
		end
		open("time.txt", "a") do file
			write(file, "Robot with Load perceived")
		end
	# refresh RobotWithLoad Position -> renew the ChainMember(Join) role
	elseif !robotSelf.load && infoInMessage(message, msg_Chainmember_Join)!=false && hasRole(robotSelf, JoinChainMember, JoinChainTeam)
		#println("Robot with load Position updated----------------------------------------")
		perceivedRobot = PerceivedRobot("Dummy", infoInMessage(message, msg_Chainmember_Join), true) 
		@changeRoles JoinChainTeam 37 begin
			getObjectsOfRole(getDynamicTeam(JoinChainTeam, 37), ChainMember)[1] << ChainMember
			perceivedRobot >> ChainMember()
		end
		open("time.txt", "a") do file
			write(file, "Drive to Perceived Robot (update)")
		end

	# Joiner detected, --> activate JoinChainTeam (only if no other robot, wich is already part of the JoinChainTeam is perceived)
	elseif getRoles(robotSelf) != nothing && robotSelf.load && infoInMessage(message, msg_Joiner)!=false && !hasRole(robotSelf, ChainMember, JoinChainTeam) && infoInMessage(message, msg_Chainmember_Join)==false
		
		perceivedRobot = PerceivedRobot("Dummy", infoInMessage(message, msg_Joiner), false) 
		
		# check ditance to last transferpoint, to prevent that robot switch to chainmember(join) mode whilst rotating at the last transferpoint
		role = getRoleOfTeam(getDynamicTeam(ChainTeam, 3), Predecessor)
		if role === nothing || getDistance(role.transferpointReceive, robotSelf.position) > MIN_TRANSFERPOINT_DISTANCE
			# filter out joiners, which are further afar from nest, than the robot itself
			if getDistance(robotSelf.position, nest) > getDistance(perceivedRobot.position, nest)
				@assignRoles JoinChainTeam begin
					name = 77
					robotSelf >> ChainMember()
					perceivedRobot >> JoinChainMember(false)
					# get Load from Team where Robot is in (SingleRobotChainTeam or ChainTeam)
					getObjectsOfRole(getFirstTeam(robotSelf), Load)[1] >> Load()
				end		
				@changeRoles ChainTeam 3 begin
					getDynamicTeam(JoinChainTeam, 77) >> RobotJoining()
				end
			else
				println("wrong Joiner detected")
			end
		else
			println("robot on rotate: Don't disturb :)")
		end
		open("time.txt", "a") do file
			write(file, "Joiner perceived")
		end
	else
		open("time.txt", "a") do file
			write(file, "nothing changed")
		end
	end
=#
	#3. Plan ascertain the subsequent behavior based on the current state of the swarm runtime model

	# 0 Exploration
	areaPos1 = EXPLORATION_POS1
	areaPos2 = EXPLORATION_POS2
	if getRoles(robotSelf) === nothing
		position = Position(rand(areaPos1.x:areaPos2.x),rand(areaPos1.y:areaPos2.y))
		while getDistance(position, robotSelf.position) <= MIN_TRANSFERPOINT_DISTANCE
			position = Position(rand(areaPos1.x:areaPos2.x),rand(areaPos1.y:areaPos2.y))
			#println("same Position")
		end
		println("drive randomly "*string(position))
		open("time.txt", "a") do file
			if first_time 
				write(file, "First Exploration")
				first_time = false
			end
		end
		return position, "driving", msg_nothing
	end


	# 1 Robot is Informed Explorer
	if hasRole(robotSelf, InformedExplorer, InitialTeam)
		disasterPos = getObjectsOfRole(getDynamicTeam(InitialTeam, 2), DisasterGuess)[1]
		connectorPos = getPositionOnBaseLine(disasterPos, RADIUS)
		return connectorPos, "driving", msg_InformedExplorer
	
	elseif hasRole(robotSelf, Recruit, InitialTeam)
		leaderPos = getObjectsOfRole(getDynamicTeam(InitialTeam, 2), InformedExplorer)[1].position
		return leaderPos, "driving", msg_nothing

	elseif hasRole(robotSelf, Connector, DisasterChainTeam)
		disasterPos = getObjectsOfRole(getDynamicTeam(InitialTeam, 2), DisasterGuess)[1]
		connectorPos = getConnectorPosition(disasterPos)
		return connectorPos, "driving", msg_Connector

	elseif hasRole(robotSelf, NewRelay, ArrangeRelayTeam)
		currentRelayPos = getObjectsOfRole(getDynamicTeam(ArrangeRelayTeam, 37), CurrentRelay)[1].position
		nextRelayPos = getPositionOnBaseLine(currentRelayPos, RELAY_DISTANCE)
		return nextRelayPos, "driving", msg_nothing
		
	# Robot in relay has to stay close to its predecessor but on its distant position from it
	elseif hasRole(robotSelf, Relay, DisasterChainTeam)
		predecessorPos = getObjectsOfRole(getDynamicTeam(DisasterChainTeam, 3), Predecessor)[1].position
		relayPos = getPositionOnBaseLine(predecessorPos, RELAY_DISTANCE)
		return relayPos, "driving", msg_RelayChainIncomplete
	
	# Robot in BaseStation Relay role works similar to above, but initializes the CHAIN FLIP by exposing the complete Message
	# (Succesors will follow hopefully :) )
	elseif hasRole(robotSelf, BaseStationRelay, DisasterChainTeam)
		predecessorPos = getObjectsOfRole(getDynamicTeam(DisasterChainTeam, 3), Predecessor)[1].position
		relayPos = getMiddlePos(predecessorPos, baseStation)
		return relayPos, "driving", msg_RelayChainComplete

	#=	

	# 2 Roboter ist in ChainMember(Join) (Robot with load is always ChainMember!!!)
	elseif hasRole(robotSelf, ChainMember, JoinChainTeam)
		robotSelf.waiting = true
		if getRoleOfTeam(getDynamicTeam(JoinChainTeam, 77), JoinChainMember).loadActive == true
			return (nothing, "unload", msg_Chainmember_Join)
		end
		return (nothing, "waiting", msg_Chainmember_Join)

	# 3 Robot is in SingleRobotChain Team 
	elseif hasRole(robotSelf, ChainMember, SingleRobotChainTeam) && !robotSelf.load && !robotSelf.goalReached
		robotSelf.goalGiven = true
		pos = getObjectsOfRole(getDynamicTeam(SingleRobotChainTeam, 2), Prey)[1]
		return pos, "driving", msg_nothing
	
	elseif robotSelf.load && !robotSelf.goalGiven
		# robot released/received load before reaching the goal --> set goalGiven to true
		if !robotSelf.goalReached 
			robotSelf.goalGiven = true
		end
		# Robot is in SingleRobotChain Team or in the Tail role --> drive to nest
		if hasRole(robotSelf, ChainMember, SingleRobotChainTeam) || hasRole(robotSelf, Tail, ChainTeam)
			pos = getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Nest)[1]
		# Robot is Head or Intermediate --> drive to transferpoint
		else
			pos = getRoleOfTeam(getDynamicTeam(ChainTeam, 3), Successor).transferpointRelease
		end
		return pos, "driving", msg_robotWithLoad
	
	elseif !robotSelf.load && !robotSelf.goalGiven
		# robot has released/received load before reaching the goal --> set goalGiven to true
		if !robotSelf.goalReached 
			robotSelf.goalGiven = true
		end
		println("Load released")
		# Robot is in SingleRobotChain Team or in the Head role --> drive to Prey
		if hasRole(robotSelf, ChainMember, SingleRobotChainTeam) || hasRole(robotSelf, Head, ChainTeam)
			pos = getObjectsOfRole(getFirstTeam(robotSelf), Prey)[1]
		# Robot is Tail or Intermediate --> drive to transferpoint
		else
			pos = getRoleOfTeam(getDynamicTeam(ChainTeam, 3), Predecessor).transferpointReceive
		end
		return pos, "driving", msg_nothing

	=# 

	# Any goal reached --> waiting
	elseif robotSelf.goalReached
		#println("Roles: " * string(keys(getRoles(robotSelf)[nothing])) * " wait")
		robotSelf.waiting = true
		#load at the prey
		if !robotSelf.load && (hasRole(robotSelf, ChainMember, SingleRobotChainTeam) || hasRole(robotSelf, Head, ChainTeam))
			pos = getObjectsOfRole(getFirstTeam(robotSelf), Prey)[1]
			if getDistance(pos, robotSelf.position) <= NEST_AND_PREY_LOADING_RANGE
				return (nothing, "load", nothing)
			end
		end
		#unload at nest
		if getDistance(nest, robotSelf.position) <= NEST_AND_PREY_LOADING_RANGE
			println("unloaded at nest")
			return (nothing, "unload", nothing)
		end
		return nothing, "waiting", nothing
	end
end

