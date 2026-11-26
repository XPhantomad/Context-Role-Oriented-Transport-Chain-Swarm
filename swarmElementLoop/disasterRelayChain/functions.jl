using LinearAlgebra

# Check, if the message contains the requested information and if this is the case return the attached position
# function infoInMessage(message, text)
# 	for info in message 
# 		if info[1] == text
# 			return Position(info[2],info[3])
# 		end
# 	end
# 	return false
# end

# Check, if the message contains the requested information and in case return one or all attached position(s)
function infoInMessage(message, text, text2=" ")
	result = nothing
	for info in message 
		if info[1] == text || info[1] == text2
			# check whether a second result is closer and in case take this
			if result == nothing || (getDistance(robotSelf.position, result) > getDistance(robotSelf.position, Position(info[2],info[3])))
				result = Position(info[2],info[3])
			end
		end
	end
	if result == nothing
		return false
	end
	return result
	#length(result) >= 2 ? result : pop!(result)
end

function getDistance(pos1, pos2)
	return abs(hypot((pos1.x - pos2.x),(pos1.y-pos2.y)))
end

# git first Object of the Role in the Team
function getRoleOfTeam(team::DynamicTeam, role::Type)
	if !isempty(getObjectsOfRole(team, role))
		return getRole(getObjectsOfRole(team, role)[1], team) # TODO: eliminate magic number 1 --> getRole s OfTeam
	else
		return nothing
	end
end

# get the first Team of an given object, based on its roles
function getFirstTeam(object)
	if getRoles(object) !== nothing 
        return first(keys(getRoles(object)[nothing]))
    else
        return nothing
    end
end

function getPositionOnBaseLine(disaster::Position, radius)
	global baseStation

	vecDisasterBase = baseStation - disaster
	dist = hypot(vecDisasterBase.x, vecDisasterBase.y)
	#print(dist)

    dist == 0 && error("Disaster and BaseStation are at the same point --> direction not definable")

    # Radius is larger than the distance between disastern and base station -> take base station
    radius >= dist && return baseStation

    resultingPos = disaster + (radius / dist) * vecDisasterBase
    return Position(round(resultingPos.x; digits=2), round(resultingPos.y; digits=2))
end