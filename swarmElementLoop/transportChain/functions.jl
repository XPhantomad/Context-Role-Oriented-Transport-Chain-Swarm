# Check, if the message contains the requested information and if this is the case return the attached position
function infoInMessage(message, text)
	for info in message 
		if info[1] == text
			return Position(info[2],info[3])
		end
	end
	return false
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