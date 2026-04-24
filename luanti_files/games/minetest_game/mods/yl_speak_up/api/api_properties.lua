-- handle properties

-- Properties for NPC --
-- This is used when an NPC doesn't have a specific dialog but still wants to
-- make use of a (or some) generic dialog(es)

-- helper function:
-- get one property value of the NPC
yl_speak_up.get_one_npc_property = function(pname, property_name)
	if(not(pname)) then
		return nil
	end
	-- get just the property data
	return yl_speak_up.get_npc_properties(pname, false)[property_name]
end


-- helper function;
-- adds "normal" properties of the npc with a self.<property_name> prefix as well
-- if long_version is not set, a table containing all properties is returned;
-- if long_version *is* set, a table containing the table above plus additional entries is returned
yl_speak_up.get_npc_properties_long_version = function(pname, long_version)
	if(not(pname) or not(yl_speak_up.speak_to[pname])) then
		return {}
	end
	local obj = yl_speak_up.speak_to[pname].obj
	if(not(obj)) then
		return {}
	end
	local entity = obj:get_luaentity()
	if(not(entity)) then
		return {}
	end
	if(not(entity.yl_speak_up)) then
		return {}
	end
	local properties = entity.yl_speak_up.properties
	if(not(properties)) then
		properties = {}
		entity.yl_speak_up.properties = properties
	end
	-- copy other property data that is stored under self.* over as well (like i.e. self.order for mobs_redo)
	for k, v in pairs(entity) do
		local t = type(v)
		if(t == "string" or t == "number" or t == "boolean") then
			properties["self."..tostring(k)] = tostring(v)
		end
	end
	properties["self.name"] = tostring(entity.name)
	if(not(long_version)) then
		return properties
	end
	-- the long version contains additional information
	local prop_names = {}
	for k, v in pairs(properties) do
		table.insert(prop_names, k)
	end
	table.sort(prop_names)
	return {obj = obj, entity = entity, properties = properties, prop_names = prop_names}
end


-- most of the time we don't need object, entity or a list of the names of properties;
-- this returns just the properties themshelves
yl_speak_up.get_npc_properties = function(pname)
	return yl_speak_up.get_npc_properties_long_version(pname, false)
end


yl_speak_up.set_npc_property = function(pname, property_name, property_value, reason)
	if(not(pname) or not(property_name) or property_name == "") then
		return "No player name or property name given. Cannot load property data."
	end
	-- here we want a table with additional information
	local property_data = yl_speak_up.get_npc_properties_long_version(pname, true)
	if(not(property_data)) then
		return "Failed to load property data of NPC."
	end
	-- it is possible to react to property changes with special custom handlers
	if(yl_speak_up.custom_property_handler[property_name]) then
		-- the table contains the pointer to a fucntion
		local fun = yl_speak_up.custom_property_handler[property_name]
		-- call that function with the current values
		return fun(pname, property_name, property_value, property_data)
	end
	-- properties of type self. are not set directly
	if(string.sub(property_name, 1, 5) == "self.") then
		return "Properties of the type \"self.\" cannot be modified."
	end
	-- properites starting with "server" can only be changed or added manually by
	-- players with the npc_talk_admin priv
	if(string.sub(property_name, 1, 6) == "server") then
		if(not(reason) or reason ~= "manually" or not(pname)
		  or not(minetest.check_player_privs(pname, {npc_talk_admin=true}))) then
			return "Properties starting with \"server\" can only be changed by players "..
				"who have the \"npc_talk_admin\" priv."
		end
	end
	-- store it
	if(property_data.entity) then
		property_data.entity.yl_speak_up.properties[property_name] = property_value
		local n_id = yl_speak_up.speak_to[pname].n_id
		yl_speak_up.log_change(pname, n_id, "Property \""..tostring(property_name)..
					"\" set to \""..tostring(property_value).."\".")
	end
	-- TODO: handle non-npc (blocks etc)
	return "OK"
end

