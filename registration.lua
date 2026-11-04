local function add_entity(mod_name, registration_type, entity, data, additional_data, registration_table)
	if not data then return end
	
	local registration_entry = registration_table[entity]
	if registration_entry then
		helpers.write_file("disable-enemies-lib.txt", {"", string.format("Registration of entity '%s' by mod '%s' for '%s' skipped because it has already been registered by mod '%s'.\n", entity, mod_name, registration_type, registration_entry.mod_name) }, true)
		return
	end

	registration_entry = { mod_name = mod_name }
	if data ~= true then
		for key, value in pairs(data) do
			registration_entry[key] = value
		end
	end
	
	if additional_data ~= nil then
		for key, value in pairs(additional_data) do
			registration_entry[key] = value
		end
	end
	
	registration_table[entity] = registration_entry
end

local units_to_disable_from_spawners = {}
local units_to_disable_from_spoilage = {}
local units_to_disable_from_projectile_action = {}
local units_to_disable_from_projectile_final_action = {}
local units_to_disable_from_entity_damage = {}
local units_to_disable_from_entity_death = {}
local entities_to_disable_from_attacking = {}

return {
	add_entity = add_entity,
	units_to_disable_from_spawners = units_to_disable_from_spawners,
	units_to_disable_from_spoilage = units_to_disable_from_spoilage,
	units_to_disable_from_projectile_action = units_to_disable_from_projectile_action,
	units_to_disable_from_projectile_final_action = units_to_disable_from_projectile_final_action,
	units_to_disable_from_entity_damage = units_to_disable_from_entity_damage,
	units_to_disable_from_entity_death = units_to_disable_from_entity_death,
	entities_to_disable_from_attacking = entities_to_disable_from_attacking,
}
