include("../src/Contexts.jl")
using .Contexts


abstract type AbstractRobot end

mutable struct Position
	x:: Float64
	y:: Float64
end

Base.:(==)(a::Position, b::Position) = a.x == b.x && a.y == b.y

mutable struct Robot <: AbstractRobot
	name::String
	load::Bool
	goalReached::Bool
	position::Position
	waiting::Bool
	goalGiven::Bool
	proximity::Bool
end

mutable struct PerceivedRobot <: AbstractRobot
	name::String
	position::Position
	load::Bool
end

mutable struct Object
	id::Int64
end

mutable struct DatafromSRL
	x::Float64
	y::Float64
	load::Bool
	goalReached::Bool
	proximity::Bool
end

abstract type ChainMemberType <: Role end


@newDynamicTeam JoinChainTeam begin
	@IDAttribute ID::Int64
	@role ChainMember << AbstractRobot [1] begin end
	@role JoinChainMember << AbstractRobot [1] begin
		loadActive::Bool
	end
	@role Load << Object [0..1] begin end
	@role Transferpoint << Position [0..1] begin end
end

@newDynamicTeam SingleRobotChainTeam begin
	@IDAttribute ID::Int64
	@role Nest << Position [1] begin end
	@role ChainMember << Robot [1] begin end
	@role Prey << Position [1] begin end
	@role Load << Object [0..1] begin end
end

@newDynamicTeam ChainTeam begin
	@IDAttribute ID::Int64
	@role Successor << PerceivedRobot [0..1] begin	
		transferpointRelease::Position
	end
	@role Predecessor << PerceivedRobot [0..1] begin 
		transferpointReceive::Position
	end
	@role Head << Robot <: ChainMemberType [0..1] begin end
	@role Tail << Robot <: ChainMemberType [0..1] begin end
	@role Intermediate << Robot <: ChainMemberType [0..1] begin end
	@role RobotJoining << JoinChainTeam [0..1] begin end
	@role SingleRobotChain << SingleRobotChainTeam [0..1] begin end

	@role Prey << Position [0..1] begin	end
	@role Nest << Position [1] begin end
	@role Load << Object [0..1] begin end
end