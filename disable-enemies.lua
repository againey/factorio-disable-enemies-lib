-- The main file for dependent mods to require, so that they can register units to be disabled under various conditions.

-- Prototype name lists

local unit_prototype_names = {
	"unit",
	"spider-unit",
	"segmented-unit",
}

-- Unit disablement registration

-- Parameters:
--   mod_name: The name of the mod that is registering disabled units. Used for logging purposes in case of conflict.
--   units: A dictionary where each key is a unit name, and each value is either `true` or a table of details.
--   entities: A dictionary where each key is an entity name, and each value is table of details which much include an "entity_type" entry.
--   filter: An optional function that returns bool if the unit should be disabled, accepting three parameters:
--     context: The name of the root object which is being affected by disabling a unit (example: `"biter-spawner"` for disabling the spawning of biters).
--     unit_name: The name of the unit being disabled.
--     unit_entry: The registration entry for the unit being disabled, which includes (among other things) any details in value tables from the `units` parameter above.
--   sources: A list of entity type names to be examined (example: `{"unit", "spider-unit"}`).

local registration = require("registration")

local function register_units_to_disable_from_spawners(mod_name, units, filter)
	local additional_data = (filter and { filter = filter } or nil)
	for unit, data in pairs(units) do
		--helpers.write_file("disable-enemies-lib.txt", {"", "Registering " .. unit .. " to not spawn from spawners.\n"}, true)
		registration.add_entity(mod_name, "spawners", unit, data, additional_data, registration.units_to_disable_from_spawners)
	end
end

local function register_units_to_disable_from_spoilage(mod_name, units, filter)
	local additional_data = (filter and { filter = filter } or nil)
	for unit, data in pairs(units) do
		--helpers.write_file("disable-enemies-lib.txt", {"", "Registering " .. unit .. " to not spawn from spoilage.\n"}, true)
		registration.add_entity(mod_name, "spoilage", unit, data, additional_data, registration.units_to_disable_from_spoilage)
	end
end

local function register_units_to_disable_from_projectile_action(mod_name, units, filter)
	local additional_data = (filter and { filter = filter } or nil)
	for unit, data in pairs(units) do
		--helpers.write_file("disable-enemies-lib.txt", {"", "Registering " .. unit .. " to not spawn from projectile action.\n"}, true)
		registration.add_entity(mod_name, "projectile action", unit, data, additional_data, registration.units_to_disable_from_projectile_action)
	end
end

local function register_units_to_disable_from_projectile_final_action(mod_name, units, filter)
	local additional_data = (filter and { filter = filter } or nil)
	for unit, data in pairs(units) do
		--helpers.write_file("disable-enemies-lib.txt", {"", "Registering " .. unit .. " to not spawn from projectile final action.\n"}, true)
		registration.add_entity(mod_name, "projectile final action", unit, data, additional_data, registration.units_to_disable_from_projectile_final_action)
	end
end

local function register_units_to_disable_from_entity_damage(mod_name, units, filter, sources)
	local additional_data = ((filter or sources) and { filter = filter, sources = sources } or nil)
	for unit, data in pairs(units) do
		--helpers.write_file("disable-enemies-lib.txt", {"", "Registering " .. unit .. " to not spawn from entity damage.\n"}, true)
		registration.add_entity(mod_name, "entity damage", unit, data, additional_data, registration.units_to_disable_from_entity_damage)
	end
end

local function register_units_to_disable_from_entity_death(mod_name, units, filter, sources)
	local additional_data = ((filter or sources) and { filter = filter, sources = sources } or nil)
	for unit, data in pairs(units) do
		--helpers.write_file("disable-enemies-lib.txt", {"", "Registering " .. unit .. " to not spawn from entity death.\n"}, true)
		registration.add_entity(mod_name, "entity death", unit, data, additional_data, registration.units_to_disable_from_entity_death)
	end
end

local function register_entities_to_disable_from_attacking(mod_name, entities, entity_type)
	local additional_data = { entity_type = entity_type }
	for entity, data in pairs(entities) do
		--helpers.write_file("disable-enemies-lib.txt", {"", "Registering " .. entity .. " to not attack.\n"}, true)
		registration.add_entity(mod_name, "attack", entity, data, additional_data, registration.entities_to_disable_from_attacking)
	end
end

return {
	unit_prototype_names = unit_prototype_names,

	from_spawners = register_units_to_disable_from_spawners,
	from_spoilage = register_units_to_disable_from_spoilage,
	from_projectile_action = register_units_to_disable_from_projectile_action,
	from_projectile_final_action = register_units_to_disable_from_projectile_final_action,
	from_entity_damage = register_units_to_disable_from_entity_damage,
	from_entity_death = register_units_to_disable_from_entity_death,
	from_attacking = register_entities_to_disable_from_attacking,
}
