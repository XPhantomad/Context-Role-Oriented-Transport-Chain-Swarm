using Test
using JSON
ARGS = ["9"]
include("../swarmElementLoop/MAPE.jl")

robotSelf = Robot("test", 2000, false, false, Position(0,0), false, false, false)

@testset "Swarm" begin

    @testset "SingleRobotChain" begin
        
        data = DatafromSRL(1,2,false,false,false)
        message = JSON.parse("[[\""*msg_preyDetected*"\", 4.0, 1.0]]")
        goal = mapeLoop(data, message, false)
        @test hasRole(robotSelf, ChainMember, SingleRobotChainTeam)
        @test robotSelf.goalGiven
        @test goal[1] == Position(4.0, 1.0)
 
        # prey reached, load expected
        data = DatafromSRL(4,1,false, true, false)
        goal = mapeLoop(data, message, false)
        println(goal)
        @test goal[2] == "load"
        @test hasRole(robotSelf, ChainMember, SingleRobotChainTeam)

        # load collected
        data = DatafromSRL(4,1, true, true, false)
        goal = mapeLoop(data, message, false)
        # Test load not empty
        @test !isempty(getObjectsOfRole(getDynamicTeams(SingleRobotChainTeam)[1], Load))
        @test goal[3] == "yellow"

        # random events on the way --> should be ignored by the robot
        message = " "
        data = DatafromSRL(3,1, true, false, true)
        @test mapeLoop(data, message, false) === nothing
        message = JSON.parse("[[\""*msg_robotWithLoadDetected*"\", 2.0, 1.0]]")
        data = DatafromSRL(3,1, true, false, false)
        @test mapeLoop(data, message, false) === nothing
        message = JSON.parse("[[\""*msg_ChainmemberDetected*"\", 2.0, 1.0]]")
        data = DatafromSRL(3,1, true, false, false)
        @test mapeLoop(data, message, false) === nothing
        message = JSON.parse("[[\""*msg_joinerLoadingDetected*"\", -3.0, 1.0]]")
        data = DatafromSRL(-1,1, true, false, false)
        @test mapeLoop(data, message, false) === nothing

        # nest reached, unload expected
        data = DatafromSRL(-3,1.2,true, true, false)
        goal = mapeLoop(data,message, false)
        @test goal[2] == "unload"

        # load released
        data = DatafromSRL(-3,1.2,false, true, false)
        goal = mapeLoop(data,message, false)
        @test goal[1] == Position(4.0,1.0)
        @test goal[2] == "driving"
        @test goal[3] == "black"
        @test isempty(getObjectsOfRole(getDynamicTeams(SingleRobotChainTeam)[1], Load))
        @test hasRole(robotSelf, ChainMember, SingleRobotChainTeam)
        
    end
       
end 