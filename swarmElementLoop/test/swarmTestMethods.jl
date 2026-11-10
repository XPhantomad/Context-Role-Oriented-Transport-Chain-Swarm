using Test
using JSON
include("../swarmElementLoop/MAPE.jl")

robotSelf = Robot("test", 2000, false, false, Position(0,0), false, false, false)

@testset "Swarm" begin

    @testset "SingleRobotChain Methods" begin
        
        testPrey = Position(5,5)
        # without load
        assignSingleRobotChainTeams(testPrey)
        @test hasRole(robotSelf, ChainMember, SingleRobotChainTeam)
        @test isempty(getObjectsOfRole(getDynamicTeams(SingleRobotChainTeam)[1], Load))
        @test getObjectsOfRole(getDynamicTeams(SingleRobotChainTeam)[1], Prey)[1] == testPrey
        disassignAllRoles()
        # with load
        testLoad = Object(1,2)
        assignSingleRobotChainTeams(testPrey, testLoad)
        @test hasRole(robotSelf, ChainMember, SingleRobotChainTeam)
        @test !isempty(getObjectsOfRole(getDynamicTeams(SingleRobotChainTeam)[1], Load))
        @test getObjectsOfRole(getDynamicTeams(SingleRobotChainTeam)[1], Prey)[1] == testPrey

    end
    disassignAllRoles()

    @testset "SingleRobotChain without Load, Robot with Load detected" begin
        testNest = Position(1,1)
        @assignRoles SingleRobotChainTeam begin
            name = 4
            nest = testNest
            robotSelf >> ChainMember()
            Position(5,5) >> Prey()
        end
        @assignRoles ChainTeam begin
            name = 2
            testNest >> Nest()
		    getDynamicTeam(SingleRobotChainTeam, 4) >> SingleRobotChain()
        end

        #data = 

    end
       
end 