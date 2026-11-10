using Test
using JSON
include("../swarmElementLoop/MAPE.jl")

robotSelf = Robot("test", 2000, false, false, Position(0,0), false, false, false)

@testset "Swarm" begin

    @testset "SingleRobotChain --> Head" begin
        
        data = DatafromSRL(1,2,false,false,false)
        message = JSON.parse("[[\""*msg_preyDetected*"\", 4.0, 1.0]]")
        goal = mapeLoop(data, message, false)
        # prey reached, load expected
        data = DatafromSRL(4,1,false, true, false)
        goal = mapeLoop(data, message, false)
        # load collected
        data = DatafromSRL(4,1, true, true, false)
        goal = mapeLoop(data, message, false)
        # Test load not empty
        @test !isempty(getObjectsOfRole(getDynamicTeams(SingleRobotChainTeam)[1], Load))
        @test goal[3] == "yellow"

        
        transferpoint = Position(2,1)
        # joiner detected (# copied from Test:  Tail--> Intermediate)
        data = DatafromSRL(transferpoint.x, transferpoint.y, true, false, false)
        message = JSON.parse("[[\""*msg_joinerDetected*"\", 1.0, 1.0]]")
        goal = mapeLoop(data,message, false)
        @test hasRole(robotSelf, ChainMember, JoinChainTeam)
        @test hasRole(robotSelf, ChainMember, SingleRobotChainTeam)
        @test !getRoleOfTeam(getDynamicTeam(JoinChainTeam, 77), JoinChainMember).loadActive
        @test goal[2] == "waiting"
        @test goal[3] == "magenta"

        # joiner is very near and has load activated
        data = DatafromSRL(transferpoint.x, transferpoint.y, true,false, true)
        message = JSON.parse("[[\""*msg_joinerLoadingDetected*"\", 1.8, 1.0]]")
        goal = mapeLoop(data,message, false)
        @test hasRole(robotSelf, ChainMember, JoinChainTeam)
        @test getRoleOfTeam(getDynamicTeam(JoinChainTeam, 77), JoinChainMember).loadActive
        @test goal[2] == "unload"
        @test goal[3] == "magenta"
        # -------------------- HEAD ---------------
        # load relesed --> drive to prey
        data = DatafromSRL(transferpoint.x, transferpoint.y,false,false, false)
        message = JSON.parse("[[\""*msg_joinerLoadingDetected*"\", 1.8, 1.0]]")
        goal = mapeLoop(data,message, false)
        @test hasRole(robotSelf, Head, ChainTeam)
        @test !hasRole(robotSelf, ChainMember, JoinChainTeam)
        @test !hasRole(robotSelf, ChainMember, SingleRobotChainTeam)
        @test goal[1] == Position(4,1)
        @test goal[3] == "black"
        @test isempty(getObjectsOfRole(getDynamicTeams(ChainTeam)[1], Load))
		@test getRoleOfTeam(getDynamicTeam(ChainTeam, 3), Successor).transferpoint_release == transferpoint

    end
    @testset "Head --> Intermediate" begin
        transferpoint = Position(2,1)

        # wrong robot with load detected (beside robot) --> nothing
        data = DatafromSRL(3,1,false, false, false)
        message = JSON.parse("[[\""*msg_robotWithLoadDetected*"\", 3, 2.0]]")
        goal = mapeLoop(data, message, false)
        @test goal === nothing
        @test !hasRole(robotSelf, JoinChainMember, JoinChainTeam)


        # A) robot with load detected -- join 
        data = DatafromSRL(3,1,false, false, false)
        message = JSON.parse("[[\""*msg_robotWithLoadDetected*"\", 3.6, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test goal[1] == Position(3.6,1)
        @test goal[3] == "green"
        @test hasRole(robotSelf, Head, ChainTeam)
        @test hasRole(robotSelf, JoinChainMember, JoinChainTeam)

        # robot would not join
        data = DatafromSRL(3.2,1,false, false, false)
        message = JSON.parse("[[\""*msg_robotWithLoadDetected*"\", 3.3, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test goal[1] == Position(3.6,1) # robot does not change to Chainmember --> position not updated
        @test goal[3] == "green"
        @test hasRole(robotSelf, Head, ChainTeam)
        @test hasRole(robotSelf, JoinChainMember, JoinChainTeam)

        # robot would not join
        data = DatafromSRL(3.2,1,false, false, false)
        message = JSON.parse("[[\"nothing\", 3.2, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test goal[1] == Position(4,1)
        @test goal[3] == "black"
        @test hasRole(robotSelf, Head, ChainTeam)
        @test !hasRole(robotSelf, JoinChainMember, JoinChainTeam)

        # B) Edge Case: Robot with load and Prey detected
        data = DatafromSRL(3,1,false, false, false)
        message = JSON.parse("[[\""*msg_robotWithLoadDetected*"\", 3.8, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test goal[1] == Position(3.8,1)
        @test goal[3] == "green"
        @test hasRole(robotSelf, Head, ChainTeam)
        @test hasRole(robotSelf, JoinChainMember, JoinChainTeam)

        # additionally Prey detected --> remove JoinChain 
        data = DatafromSRL(3.2,1,false, false, false)
        message = JSON.parse("[[\""*msg_ChainmemberDetected*"\", 3.7, 1.0], [\""*msg_preyDetected*"\", 4.0, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test goal[1] == Position(4,1) 
        @test goal[3] == "black"
        @test hasRole(robotSelf, Head, ChainTeam)
        @test !hasRole(robotSelf, JoinChainMember, JoinChainTeam)

        # C) Robot with load joins --> Intermediate 
        data = DatafromSRL(2,1,false, false, false)
        message = JSON.parse("[[\""*msg_robotWithLoadDetected*"\", 2.8, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test goal[1] == Position(2.8,1)
        @test goal[3] == "green"
        @test hasRole(robotSelf, Head, ChainTeam)
        @test hasRole(robotSelf, JoinChainMember, JoinChainTeam)

        # perceived robot drives to self before switch to waiting -- > update robots position
        data = DatafromSRL(2.2,1,false, false, false)
        message = JSON.parse("[[\""*msg_ChainmemberDetected*"\", 2.5, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test hasRole(robotSelf, JoinChainMember, JoinChainTeam)
        @test hasRole(robotSelf, Head, ChainTeam)
        @test goal[1] == Position(2.5,1) 
        @test goal[3] == "green"

        # robot close enough  --> trigger load
        data = DatafromSRL(2.3,1,false, false, true)
        message = JSON.parse("[[\""*msg_ChainmemberDetected*"\", 2.4, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test hasRole(robotSelf, JoinChainMember, JoinChainTeam)
        @test hasRole(robotSelf, Head, ChainTeam)
        @test goal[2] == "load"
        @test goal[3] == "white"

        # wait until other robot unloads
        data = DatafromSRL(2.3,1,false, false, true)
        message = JSON.parse("[[\""*msg_ChainmemberDetected*"\", 2.4, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test hasRole(robotSelf, JoinChainMember, JoinChainTeam)
        @test hasRole(robotSelf, Head, ChainTeam)
        @test goal[2] == "load"
        @test goal[3] == "white"

        # ----------------- INTERMEDIATE --------------------
        # transfer successfull --> switch to intermediate with load
        data = DatafromSRL(2.3,1,true, false, true)
        message = JSON.parse("[[\""*msg_ChainmemberDetected*"\", 2.4, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test !hasRole(robotSelf, JoinChainMember, JoinChainTeam)
        @test hasRole(robotSelf, Intermediate, ChainTeam)
        @test goal[1] == transferpoint
        @test goal[3] == "yellow"
        @test !isempty(getObjectsOfRole(getDynamicTeams(ChainTeam)[1], Load))
		@test getRoleOfTeam(getDynamicTeam(ChainTeam, 3), Predecessor).transferpoint_receive == Position(2.3, 1)
    end
    @testset "Intermediate --> Tail" begin
        # transferpoint with successor reached --> waiting
        data = DatafromSRL(2.0,1,true, true, false)
        message = JSON.parse("[[\"nothing\", 2.5, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test hasRole(robotSelf, Intermediate, ChainTeam)
        @test goal[2] == "waiting"

        #------------TAIL -----------------
        # wait until timeout exceeded
        data = DatafromSRL(2.0,1,true, true, false)
        message = JSON.parse("[[\"nothing\", 2.5, 1.0]]")
        goal = mapeLoop(data, message, true)
        @test hasRole(robotSelf, Tail, ChainTeam)
        @test goal[1] == Position(-3,1.2)


    end
       
end 