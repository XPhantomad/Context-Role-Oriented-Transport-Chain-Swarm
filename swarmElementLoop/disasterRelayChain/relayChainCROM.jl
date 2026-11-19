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
	goalReached::Bool
	position::Position
	waiting::Bool
	goalGiven::Bool
	proximity::Bool
end

mutable struct PerceivedRobot <: AbstractRobot
	name::String
	position::Position

end


mutable struct DatafromSRL
	x::Float64
	y::Float64
	load::Bool
	goalReached::Bool
	proximity::Bool
end

abstract type RelayChainMemberType <: Role end


@newDynamicTeam InitialTeam begin
	@IDAttribute ID::Int64
	@role BaseStation << Position [1] begin end
	@role InformedExplorer << AbstractRobot [1] begin end
	@role DisasterGuess << Position [1] begin end
	@role Recruit << AbstractRobot [0..1]

end

@newDynamicTeam DisasterChainTeam begin
	@IDAttribute ID::Int64
	@role Successor << PerceivedRobot [0..1] begin	
		transferpointRelease::Position
	end
	@role Predecessor << PerceivedRobot [0..1] begin 
		transferpointReceive::Position
	end
	# Tail of the Relay Chain
	@role BaseStationRelay << Robot <: RelayChainMemberType [0..1] begin end
	# Head of the Relay Chain
	@role Connector << Robot <: RelayChainMemberType [0..1] begin end 
	# Intermediate of the Relay Chain
	@role Relay << Robot <: RelayChainMemberType [0..1] begin end

	# Robots standing around the Disaster
	@role Observer << Robot [0..1] begin end

	@role Disaster << Position [0..1] begin	end
	@role BaseStation << Position [1] begin end

end