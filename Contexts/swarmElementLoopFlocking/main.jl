include("MAPE.jl")
using Sockets
using JSON
using DelimitedFiles

# get robot name and number from cli argument
robot_name = ARGS[1]
robot_number = parse(Int64, filter(x->'0'<=x<='9',robot_name))

# new robot --> Self
robotSelf = Robot(robot_name, Position(0,0), 0.0, true, false)
robotSelf2 = Robot("dummy", Position(0,0), 0.0, true, false)

### Begin Precompilation of Teams to reduce delay
@assignRoles FlockingTeam begin
	name = 1
	robotSelf >> Leader()
	robotSelf2 >> Follower()
end
disassignRoles(FlockingTeam, 1)
### End Precompilation

# start sockets for connection to messages and single robot loop
server = listen(ip"127.0.0.1", 2000+robot_number*2)
sockSRL = accept(server)
server2 = listen(ip"127.0.0.1", 2000+robot_number*2+1)
sockMSG = accept(server2)

streamWebApp = connect(ip"127.0.0.1", 3004)

# send Initial Messages to Single-Robot-Loop
write(sockSRL, "start")

datafromSRL = DatafromSRL(1,2,0.0,false)
datafromSRL_old = DatafromSRL(0,0,0.0,false,)
message_in = JSON.parse("[[\"test1\", 0.0, 0.0]]")
message_in_old = JSON.parse("[[\"test\", 0.0, 0.0]]")

message_out_old = msg_nothing
position_old = Position(0,0)
t1 = 0


function sendMessage(position, state, message_out)
	global message_out_old
	global position_old
	if position === nothing
		position = position_old
	end
	if message_out === nothing
		message_out = message_out_old
	end
	if isopen(sockSRL)
		s = "{\"robot\" : \""*robotSelf.name*"\", \"xTarget\" : "* string(position.x) *", \"yTarget\" : "* string(position.y) *", \"state\" : \""* state *"\", \"message\" : \"" * message_out *"\"}\n"
		j = JSON.parse(s) # only for checking correctness of JSON-Message
		write(sockSRL, JSON.json(j))
		message_out_old = message_out
		position_old = position
	end
end

function sendMessageToWebapp(pos, state, message_out)
	if isopen(streamWebApp)
		# Fallback for pos and led
		if pos === nothing
			pos= position_old
		end
		if message_out === nothing
			message_out = message_out_old
		end

		# Prepare base data
        robot_data = Dict(
            "name" => robotSelf.name,
            "xTarget" => pos.x,
            "yTarget" => pos.y,
            "state" => state,
            "message" => message_out,
        )

		# Insert roles and teams as array
        roles_info = getRoles(robotSelf)
        if roles_info !== nothing
            roles_dict = roles_info[nothing] 
            roles_list = [string(r) for r in values(roles_dict)]
            teams_list = [string(t) for t in keys(roles_dict)]
            robot_data["roles"] = roles_list
            robot_data["teams"] = teams_list
        end

		# final message
		message = Dict(robotSelf.name => robot_data)

		jsonString = JSON.json(message)
		write(streamWebApp, jsonString*"\n")
	end
end


Threads.@spawn while true
	global datafromSRL, t1
    if isopen(sockSRL)
		msg = JSON.parse(readline(sockSRL))
		t1 = time()
		datafromSRL = DatafromSRL(get(get(msg, robotSelf.name, 0),"xPos",0), get(get(msg, robotSelf.name, 0),"yPos",0), get(get(msg, robotSelf.name, 0),"theta",0), get(get(msg, robotSelf.name, 0),"goalReached",0))	
	end
	sleep(0.1)
end

Threads.@spawn while true
    global message_in
	if isopen(sockMSG)
		message_in = JSON.parse(readline(sockMSG))
	end
	sleep(0.1)
end

counter = 0
while true
	global datafromSRL_old, message_in_old, counter, t1, robotSelf, message_in, datafromSRL
	if datafromSRL.goalReached || robotSelf.waiting
		counter+=1
		#println(counter)
	end
	if counter >= 100 || datafromSRL.goalReached != datafromSRL_old.goalReached || message_in[1][2] != message_in_old[1][2] || message_in[1][3] != message_in_old[1][3] || size(message_in) != size(message_in_old)
		robotSelf.waiting = false
		
		#println(message_in[1][2] != message_in_old[1][2])
		goal = mapeLoop(datafromSRL, message_in, counter >= 100)
		if goal !== nothing
			sendMessage(goal[1], goal[2], goal[3])
			sendMessageToWebapp(goal[1], goal[2], goal[3])
		end
		counter = 0

	end
	datafromSRL_old = datafromSRL
	message_in_old = message_in
	sleep(0.1)
end

