using Test
using JSON
ARGS = ["9"]
include("../swarmElementLoop/MAPE.jl")

robotSelf = Robot("test", 2000, false, false, Position(0,0), false, false, false)

@testset "Swarm" begin

    @testset "JoinChainTeam Joiner" begin
        
        # joiner detected without being in Chain or having load to transfer
        data = DatafromSRL(1,2, false, false, false)
        message = JSON.parse("[[\""*msg_joinerDetected*"\", 2.0, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test getRoles(robotSelf) === nothing
        # --> nothing should happen

        # robot with load perceived
        data = DatafromSRL(1,1,false,false, false)
        message = JSON.parse("[[\""*msg_robotWithLoadDetected*"\", 2.0, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test hasRole(robotSelf, JoinChainMember, JoinChainTeam)
        @test goal[1] == Position(2,1)
        @test goal[2] == "driving"
        @test goal[3] == "green"

        # percevied robot with load disappears
        data = DatafromSRL(1.5,1,false,false, false)
        message = JSON.parse("[[\"nothing\", 0.0, 0.0]]")
        goal = mapeLoop(data, message, false)
        @test getRoles(robotSelf) === nothing
        @test goal[3] == "black"

        # robot appear again or other roobt in Chainmember mode appears --> do nothing
        data = DatafromSRL(1.5,1, false, false, false)
        message = JSON.parse("[[\""*msg_ChainmemberDetected*"\", 2.0, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test getRoles(robotSelf) === nothing
        @test goal[3] == "black"

        # another robot appears
        data = DatafromSRL(1.5,1, false, false, false)
        message = JSON.parse("[[\""*msg_robotWithLoadDetected*"\", 2.0, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test hasRole(robotSelf, JoinChainMember, JoinChainTeam)
        @test goal[1] == Position(2,1)
        @test goal[2] == "driving"
        @test goal[3] == "green"
        
        # robot reached
        transferpoint = Position(1.8,1)
        data = DatafromSRL(transferpoint.x, transferpoint.y, false, false, true)
        message = JSON.parse("[[\""*msg_ChainmemberDetected*"\", 2.0, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test goal[2] == "load"
        @test goal[3] == "white"
        
        # load received
        data = DatafromSRL(transferpoint.x, transferpoint.y, true, false, true)
        message = JSON.parse("[[\""*msg_ChainmemberDetected*"\", 2.0, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test goal[1] == Position(-3,1.2)
        @test goal[3] == "yellow"
        @test !isempty(getObjectsOfRole(getDynamicTeams(ChainTeam)[1], Load))
        @test hasRole(robotSelf, Tail, ChainTeam)
        @test isempty(getObjectsOfRole(getDynamicTeam(ChainTeam, 3), RobotJoining))
        @test !isempty(getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Predecessor))
		@test getRoleOfTeam(getDynamicTeam(ChainTeam, 3), Predecessor).transferpoint_receive == transferpoint
    end

    @testset "JoinChainTeam --> Tail" begin
        transferpoint = Position(1.8,1)

        #-------------- TAIL ---------------
        # drive to nest: Joiner to near --> do not join
        data = DatafromSRL(1.7,1, true, false, true)
        message = JSON.parse("[[\""*msg_joinerDetected*"\", 1.5, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test goal === nothing
        @test !hasRole(robotSelf, ChainMember, JoinChainTeam)

        
        # unload
        data = DatafromSRL(-3,1.2, true, true, false)
        message = JSON.parse("[[\"nothing\", 2.0, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test goal[2] == "unload"

        # load released, drive back to transferpoint
        data = DatafromSRL(-3,1.2,false,true, false)
        goal = mapeLoop(data,message, false)
        @test goal[1] == transferpoint
        @test goal[3] == "black"
        @test isempty(getObjectsOfRole(getDynamicTeams(ChainTeam)[1], Load))

        data = DatafromSRL(-3,1.2,false,false, false)
        goal = mapeLoop(data,message, false)

        # transferpoint reached --> waiting
        data = DatafromSRL(1.8,1, false, true, false)
        goal = mapeLoop(data,message, false)
        @test !hasRole(robotSelf, JoinChainMember, JoinChainTeam)
        @test goal[2] == "waiting"

        #TODO: split to timeout with Prey known and Prey not known

        # robot with load detected
        data = DatafromSRL(1.8,1, false, true, false)
        message = JSON.parse("[[\""*msg_robotWithLoadDetected*"\", 3.0, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test hasRole(robotSelf, JoinChainMember, JoinChainTeam)
        @test hasRole(robotSelf, Tail, ChainTeam)
        @test goal[1] == Position(3,1)
        @test goal[2] == "driving"
        @test goal[3] == "green"

        # robot position updated
        data = DatafromSRL(2.2,1, false, false, false)
        message = JSON.parse("[[\""*msg_ChainmemberDetected*"\", 2.5, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test goal[1] == Position(2.5,1)
        @test goal[3] == "green"
             
        # robot reached
        transferpoint = Position(2.4,1)
        data = DatafromSRL(transferpoint.x, transferpoint.y, false, false, true)
        message = JSON.parse("[[\""*msg_ChainmemberDetected*"\", 2.5, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test goal[2] == "load"
        @test goal[3] == "white"

        # load received
        data = DatafromSRL(transferpoint.x, transferpoint.y, true, false, true)
        message = JSON.parse("[[\""*msg_ChainmemberDetected*"\", 2.5, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test goal[1] == Position(-3,1.2)
        @test goal[3] == "yellow"
        @test !isempty(getObjectsOfRole(getDynamicTeams(ChainTeam)[1], Load))
        @test hasRole(robotSelf, Tail, ChainTeam)
        @test isempty(getObjectsOfRole(getDynamicTeam(ChainTeam, 3), RobotJoining))
        @test !isempty(getObjectsOfRole(getDynamicTeam(ChainTeam, 3), Predecessor))
		@test getRoleOfTeam(getDynamicTeam(ChainTeam, 3), Predecessor).transferpoint_receive == transferpoint

        # drive to nest and meet wrong joiner (beside the robot) -> do nothing
        data = DatafromSRL(0,1, true,false, false)
        message = JSON.parse("[[\""*msg_joinerDetected*"\", 0, 2.0]]")
        goal = mapeLoop(data,message, false)
        @test goal === nothing

        # drive to nest an real joiner detected --> wait and Join
        data = DatafromSRL(0,1, true,false, false)
        message = JSON.parse("[[\""*msg_joinerDetected*"\", -1, 1.0]]")
        goal = mapeLoop(data,message, false)
        @test hasRole(robotSelf, ChainMember, JoinChainTeam)
        @test !getRoleOfTeam(getDynamicTeam(JoinChainTeam, 77), JoinChainMember).loadActive
        @test goal[2] == "waiting"
        @test goal[3] == "magenta"

        # joiner is very near and has load activated
        data = DatafromSRL(0,1, true,false, true)
        message = JSON.parse("[[\""*msg_joinerLoadingDetected*"\", -0.2, 1.0]]")
        goal = mapeLoop(data,message, false)
        @test hasRole(robotSelf, ChainMember, JoinChainTeam)
        @test getRoleOfTeam(getDynamicTeam(JoinChainTeam, 77), JoinChainMember).loadActive
        @test goal[2] == "unload"
        @test goal[3] == "magenta"
    end

    @testset "Tail --> Intermediate" begin 
        transferpoint = Position(2.4,1)
        # ----------- INTERMEDIATE --------------
        # load released, drive back to transferpoint with Pred
        data = DatafromSRL(0,1,false,false, false)
        message = JSON.parse("[[\""*msg_joinerLoadingDetected*"\", -0.2, 1.0]]")
        goal = mapeLoop(data,message, false)
        @test hasRole(robotSelf, Intermediate, ChainTeam)
        @test goal[1] == transferpoint
        @test goal[3] == "black"
        @test isempty(getObjectsOfRole(getDynamicTeams(ChainTeam)[1], Load))
		@test getRoleOfTeam(getDynamicTeam(ChainTeam, 3), Successor).transferpoint_release == Position(0,1)

        
        # Intermediate reached to transferpoint with its Predecessor --> waiting
        data = DatafromSRL(2.4,1, false, true, false)
        goal = mapeLoop(data,message, false)
        @test hasRole(robotSelf, Intermediate, ChainTeam)
        @test goal[2] == "waiting"

        # Intermediate timeout exceeded while waiting --> exploration because no prey known
        data = DatafromSRL(2.4,1, false, true, false)
        message = JSON.parse("[[\""*msg_joinerLoadingDetected*"\", -0.2, 1.0]]")
        goal = mapeLoop(data,message, true)
        @test getRoles(robotSelf) === nothing
        @test goal[2] == "driving"
    end
end 