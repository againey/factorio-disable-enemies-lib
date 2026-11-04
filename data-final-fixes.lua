local registration = require("registration")
local disable_enemies = require("disable-enemies")

-- Unit filtering

local function filter_unit(context, unit_name, unit_entry)
	if not unit_entry then return false end
	if not unit_entry.filter then return true end
	return unit_entry.filter(context, unit_name, unit_entry)
end

-- Removing enemies from spawners

local function get_spawn_point_values(spawn_point)
	return spawn_point[1] or spawn_point.evolution_factor, spawn_point[2] or spawn_point.spawn_weight
end

local function add_spawn_weight(spawn_point, additional_spawn_weight)
	if spawn_point[2] then
		spawn_point[2] = spawn_point[2] + additional_spawn_weight
	else
		spawn_point.spawn_weight = spawn_point.spawn_weight + additional_spawn_weight
	end
end

local function lerp(first_x, first_y, second_x, second_y, sample_x)
	if first_y == second_y then
		return first_y
	end

	local range_x = second_x - first_x

	if range_x == 0 then
		return (first_y + second_y) / 2
	end

	local first_weight = (second_x - sample_x) / range_x
	local second_weight = (sample_x - first_x) / range_x
	return first_y * first_weight + second_y * second_weight
end

local function merge_spawn_points(source, target)
	if #source == 0 then
		return
	end

	if #target == 0 then
		for _, spawn_point in ipairs(source) do
			local evolution_factor, spawn_weight = get_spawn_point_values(spawn_point)
			table.insert(target, { evolution_factor, spawn_weight })
		end
		return
	end

	local next_source_index = 1
	local next_target_index = 1
	local next_source_evolution_factor, next_source_spawn_weight = get_spawn_point_values(source[1])
	local prev_source_evolution_factor, prev_source_spawn_weight = next_source_evolution_factor, next_source_spawn_weight
	local next_target_evolution_factor, next_target_spawn_weight = get_spawn_point_values(target[1])
	local prev_target_evolution_factor, prev_target_spawn_weight = next_target_evolution_factor, next_target_spawn_weight

	local function increment_source()
		next_source_index = next_source_index + 1
		prev_source_evolution_factor = next_source_evolution_factor
		prev_source_spawn_weight = next_source_spawn_weight
		if next_source_index <= #source then
			next_source_evolution_factor, next_source_spawn_weight = get_spawn_point_values(source[next_source_index])
		else
			next_source_evolution_factor = 1
		end
	end

	local function increment_target()
		next_target_index = next_target_index + 1
		prev_target_evolution_factor = next_target_evolution_factor
		prev_target_spawn_weight = next_target_spawn_weight
		if next_target_index <= #target then
			next_target_evolution_factor, next_target_spawn_weight = get_spawn_point_values(target[next_target_index])
		else
			next_target_evolution_factor = 1
		end
	end

	--local loop_count = 0

	while next_source_index <= #source or next_target_index <= #target do
		--helpers.write_file("disable-enemies-lib.txt", {"", "\t\tnext_source_index = " .. next_source_index .. ", next_target_index = " .. next_target_index .. "\n"}, true)
		--helpers.write_file("disable-enemies-lib.txt", {"", "\t\t#source = " .. #source .. ", #target = " .. #target .. "\n"}, true)
		--helpers.write_file("disable-enemies-lib.txt", {"", "\t\tnext_source_evolution_factor = " .. next_source_evolution_factor .. ", next_target_evolution_factor = " .. next_target_evolution_factor .. "\n"}, true)
		if next_source_evolution_factor < next_target_evolution_factor or next_target_index > #target then
			local lerp_target_spawn_weight = lerp(
				prev_target_evolution_factor, prev_target_spawn_weight,
				next_target_evolution_factor, next_target_spawn_weight,
				next_source_evolution_factor)
			--helpers.write_file("disable-enemies-lib.txt", {"", "\t\tInserting new target spawn point with target lerp weight = " .. lerp_target_spawn_weight .. " and source weight = " .. next_source_spawn_weight .. "\n"}, true)

			table.insert(target, next_target_index, { next_source_evolution_factor, next_source_spawn_weight + lerp_target_spawn_weight })

			increment_source()
			next_target_index = next_target_index + 1
		elseif next_target_evolution_factor < next_source_evolution_factor or next_source_index > #source then
			local lerp_source_spawn_weight = lerp(
				prev_source_evolution_factor, prev_source_spawn_weight,
				next_source_evolution_factor, next_source_spawn_weight,
				next_target_evolution_factor)
			--helpers.write_file("disable-enemies-lib.txt", {"", "\t\tUpdating target spawn point with target weight = " .. (target[next_target_index][2] or target[next_target_index].spawn_weight) .. " and source lerp weight = " .. lerp_source_spawn_weight .. "\n"}, true)

			add_spawn_weight(target[next_target_index], lerp_source_spawn_weight)

			increment_target()
		else
			--helpers.write_file("disable-enemies-lib.txt", {"", "\t\tUpdating target spawn point with target weight = " .. (target[next_target_index][2] or target[next_target_index].spawn_weight) .. " and source weight = " .. next_source_spawn_weight .. "\n"}, true)

			add_spawn_weight(target[next_target_index], next_source_spawn_weight)

			increment_source()
			increment_target()
		end

		--[[
		loop_count = loop_count + 1
		if loop_count > 10 then
			helpers.write_file("disable-enemies-lib.txt", {"", "\tEmergency break!\n\tnext_source_index = " .. next_source_index .. ", next_target_index = " .. next_target_index .. ", #source = " .. #source .. ", #target = " .. #target .. "\n"}, true)
			return
		end
		]]
	end
end

local function find_target_substitution_spawn_definition(unit_name, unit_entry, units_to_disable, spawner_name, spawner_result_units)
	if unit_entry.substitutions ~= nil then
		-- Consider each substitution target in order, thus prioritizing the front over the back.
		for _, substitute_unit_name in ipairs(unit_entry.substitutions) do
			-- Only consider this substitution target if it is not itself disabled for spawning.
			local substitute_unit_entry = units_to_disable[substitute_unit_name]
			if not filter_unit(spawner_name, substitute_unit_name, substitute_unit_entry) then
				-- Find the spawner's result unit entry for the substitution target, if it exists.
				for _, result_unit in ipairs(spawner_result_units) do
					local result_unit_name = result_unit[1] or result_unit.unit
					if substitute_unit_name == result_unit_name then
						return result_unit
					end
				end

				-- If spawner restrictions are not enforced for this disabled unit,
				-- then return just the substitution target's unit name to indicate a valid substition without an existing result unit entry.
				-- Otherwise, keep looking for a better substitution target.
				if unit_entry.unrestricted_substitutions then
					return substitute_unit_name
				end
			end
		end
	end
	
	return nil
end

local function format_spawn_points(spawn_points)
	local spawn_point_descriptions = {}
	for _, spawn_point in ipairs(spawn_points) do
		table.insert(spawn_point_descriptions, string.format("{%0.2f, %0.2f}", spawn_point[1] or spawn_point.evolution_factor, spawn_point[2] or spawn_point.spawn_weight))
	end
	return table.concat(spawn_point_descriptions, ", ")
end

local function remove_enemies_from_spawner_results(units_to_disable)
	helpers.write_file("disable-enemies-lib.txt", {"", "Removing units from spawner results.\n"}, true)
	local unit_spawners = data.raw["unit-spawner"]
	if unit_spawners ~= nil then
		for spawner_name, unit_spawner in pairs(unit_spawners) do
			--helpers.write_file("disable-enemies-lib.txt", {"", "\tExamining units spawned by " .. spawner_name .. "\n"}, true)
			local original_unit_count = #unit_spawner.result_units
			local removed_unit_count = 0
			local result_unit_index = 1
			while result_unit_index <= #unit_spawner.result_units do
				local result_unit = unit_spawner.result_units[result_unit_index]
				local result_unit_name = result_unit[1] or result_unit.unit
				local unit_entry = units_to_disable[result_unit_name]
				if filter_unit(spawner_name, result_unit_name, unit_entry) then
					local target_substitution_unit = find_target_substitution_spawn_definition(result_unit_name, unit_entry, units_to_disable, spawner_name, unit_spawner.result_units)
					if type(target_substitution_unit) == "string" then
						-- Target substitution unit is not already spawned by this spawner, but isn't restricted from doing so.
						-- Instead of removing this result unit and adding a new one with the same spawn points, just change the unit name of this one.
						if result_unit[1] == result_unit_name then
							result_unit[1] = target_substitution_unit
						else
							result_unit.unit = target_substitution_unit
						end
						result_unit_index = result_unit_index + 1
					else
						-- The result unit is getting removed. But first check to see if its spawn points should be merged into a substited unit.
						if target_substitution_unit ~= nil then
							local target_substitution_unit_name = target_substitution_unit[1] or target_substitution_unit.unit
							helpers.write_file("disable-enemies-lib.txt", {"", "\tMerging spawn weights for " .. result_unit_name .. " into " .. target_substitution_unit_name .. " from " .. spawner_name .. ".\n"}, true)
							merge_spawn_points(result_unit[2] or result_unit.spawn_points, target_substitution_unit[2] or target_substitution_unit.spawn_points)
						end

						table.remove(unit_spawner.result_units, result_unit_index)
						removed_unit_count = removed_unit_count + 1
						helpers.write_file("disable-enemies-lib.txt", {"", "\tRemoving " .. result_unit_name .. " from " .. spawner_name .. ".\n"}, true)
					end
				else
					helpers.write_file("disable-enemies-lib.txt", {"", "\tKeeping " .. result_unit_name .. " from " .. spawner_name .. ".\n"}, true)
					result_unit_index = result_unit_index + 1
				end
			end
			if removed_unit_count > 0 then
				helpers.write_file("disable-enemies-lib.txt", {"", "\tRemoved " .. removed_unit_count .. " of " .. original_unit_count .. " units from " .. spawner_name .. ".\n"}, true)
				for _, result_unit in ipairs(unit_spawner.result_units) do
					local result_unit_name = result_unit[1] or result_unit.unit
					local result_unit_spawn_points = result_unit[2] or result_unit.spawn_points
					helpers.write_file("disable-enemies-lib.txt", {"", "\t\tFinal spawn points for " .. result_unit_name .. ": {" .. format_spawn_points(result_unit_spawn_points) .. "}\n"}, true)
				end
			end
		end
	end
end

-- Removing the creation of units from trigger effects
--   All functions return true if the first argument has been made irrelevant by removing all effects.
--   This is used to decide if the caller should completely remove the object where the effects were defined.
--   The root_source_name argument is the name of whatever item or entity owns the top-level trigger from which this current removal was initiated.
--   The units_to_disable argument is a dictionary where the keys are the names of the units to be disabled.
--     If the value for a given unit is true, then the unit should be disabled regardless of root_source_name.
--     Otherwise, the value is a dictionary of valid root source names for which the unit should be disabled.

local remove_enemies_from_trigger

local function remove_enemies_from_trigger_effect(effect, root_source_name, units_to_disable)
	--helpers.write_file("disable-enemies-lib.txt", {"", "remove_enemies_from_trigger_effect(" .. ((units_to_disable == nil) and "nil" or "units_to_disable") .. ")\n"}, true)
	if effect.type == "create-entity" then
		local unit_entry = units_to_disable[effect.entity_name]
		if filter_unit(root_source_name, effect.entity_name, unit_entry) then
			return true
		else
			if remove_enemies_from_trigger(effect.non_colliding_fail_result, root_source_name, units_to_disable) and effect.non_colliding_fail_result ~= nil then
				helpers.write_file("disable-enemies-lib.txt", {"", "\t\tRemoving non_colliding_fail_result from trigger effect with root source " .. root_source_name .. ".\n"}, true)
				effect.non_colliding_fail_result = nil
			end
			return false
		end
	else
		return false
	end
end

local function remove_enemies_from_trigger_effects_list(effects, root_source_name, units_to_disable)
	--helpers.write_file("disable-enemies-lib.txt", {"", "remove_enemies_from_trigger_effects_list(" .. ((units_to_disable == nil) and "nil" or "units_to_disable") .. ")\n"}, true)
	if effects ~= nil then
		if effects.type ~= nil then
			return remove_enemies_from_trigger_effect(effects, root_source_name, units_to_disable)
		else
			local i = 1
			while i <= #effects do
				if remove_enemies_from_trigger_effect(effects[i], root_source_name, units_to_disable) then
					helpers.write_file("disable-enemies-lib.txt", {"", "\t\tRemoving trigger effect element " .. i .. " from trigger effects list with root source " .. root_source_name .. ".\n"}, true)
					table.remove(effects, i)
				else
					i = i + 1
				end
			end
			return i == 1
		end
	else
		return true
	end
end

local function remove_enemies_from_trigger_delivery_item_effects(action_delivery, root_source_name, units_to_disable)
	--helpers.write_file("disable-enemies-lib.txt", {"", "remove_enemies_from_trigger_delivery_item_effects(" .. ((units_to_disable == nil) and "nil" or "units_to_disable") .. ")\n"}, true)
	if remove_enemies_from_trigger_effects_list(action_delivery.source_effects, root_source_name, units_to_disable) and action_delivery.source_effects ~= nil then
		helpers.write_file("disable-enemies-lib.txt", {"", "\t\tRemoving source_effects from delivery item with root source " .. root_source_name .. ".\n"}, true)
		action_delivery.source_effects = nil
	end
	if remove_enemies_from_trigger_effects_list(action_delivery.target_effects, root_source_name, units_to_disable) and action_delivery.target_effects ~= nil then
		helpers.write_file("disable-enemies-lib.txt", {"", "\t\tRemoving target_effects from delivery item with root source " .. root_source_name .. ".\n"}, true)
		action_delivery.target_effects = nil
	end

	if action_delivery.type == "instant" then
		return action_delivery.source_effects == nil and action_delivery.target_effects == nil
	else
		return false
	end
end

local function remove_enemies_from_trigger_delivery(action_delivery, root_source_name, units_to_disable)
	--helpers.write_file("disable-enemies-lib.txt", {"", "remove_enemies_from_trigger_delivery(" .. ((units_to_disable == nil) and "nil" or "units_to_disable") .. ")\n"}, true)
	if action_delivery ~= nil then
		if action_delivery.type ~= nil then
			return remove_enemies_from_trigger_delivery_item_effects(action_delivery, root_source_name, units_to_disable)
		else
			local i = 1
			while i <= #action_delivery do
				if remove_enemies_from_trigger_delivery_item_effects(action_delivery[i], root_source_name, units_to_disable) then
					helpers.write_file("disable-enemies-lib.txt", {"", "\t\tRemoving action_delivery element " .. i .. " from trigger with root source " .. root_source_name .. ".\n"}, true)
					table.remove(action_delivery, i)
				else
					i = i + 1
				end
			end
			return i == 1
		end
	else
		return true
	end
end

remove_enemies_from_trigger = function(trigger, root_source_name, units_to_disable)
	--helpers.write_file("disable-enemies-lib.txt", {"", "remove_enemies_from_trigger(" .. ((units_to_disable == nil) and "nil" or "units_to_disable") .. ")\n"}, true)
	if trigger ~= nil then
		if trigger.type ~= nil then
			return remove_enemies_from_trigger_delivery(trigger.action_delivery, root_source_name, units_to_disable)
		else
			local i = 1
			while i <= #trigger do
				if remove_enemies_from_trigger_delivery(trigger[i].action_delivery, root_source_name, units_to_disable) then
					helpers.write_file("disable-enemies-lib.txt", {"", "\t\tRemoving trigger element " .. i .. " from trigger with root source " .. root_source_name .. ".\n"}, true)
					table.remove(trigger, i)
				else
					i = i + 1
				end
			end
			return i == 1
		end
	else
		return true
	end
end

-- Removing enemies from particular sources of trigger effects

local function remove_enemies_from_spoilage_effects(units_to_disable)
	helpers.write_file("disable-enemies-lib.txt", {"", "Removing enemies from spoilage effects.\n"}, true)
	for item_prototype_name in pairs(defines.prototypes["item"]) do
		local item_prototypes = data.raw[item_prototype_name]
		if item_prototypes ~= nil then
			for item_name, item in pairs(item_prototypes) do
				if item.spoil_ticks ~= nil and item.spoil_ticks > 0 and item.spoil_to_trigger_result ~= nil then
					if remove_enemies_from_trigger(item.spoil_to_trigger_result.trigger, item_name, units_to_disable) and item.spoil_to_trigger_result ~= nil then
						helpers.write_file("disable-enemies-lib.txt", {"", "\tRemoving spoil_to_trigger_result from " .. item_name .. ".\n"}, true)
						item.spoil_to_trigger_result = nil
					end
				end
			end
		end
	end
end

local function remove_enemies_from_projectile_action_effects(units_to_disable)
	helpers.write_file("disable-enemies-lib.txt", {"", "Removing enemies from projectile action effects.\n"}, true)
	local projectile_prototypes = data.raw["projectile"]
	if projectile_prototypes ~= nil then
		for projectile_name, projectile in pairs(projectile_prototypes) do
			if remove_enemies_from_trigger(projectile.action, projectile_name, units_to_disable) and projectile.action ~= nil then
				helpers.write_file("disable-enemies-lib.txt", {"", "\tRemoving action from " .. projectile_name .. ".\n"}, true)
				projectile.action = nil
			end
		end
	end
end

local function remove_enemies_from_projectile_final_action_effects(units_to_disable)
	helpers.write_file("disable-enemies-lib.txt", {"", "Removing enemies from projectile final action effects.\n"}, true)
	local projectile_prototypes = data.raw["projectile"]
	if projectile_prototypes ~= nil then
		for projectile_name, projectile in pairs(projectile_prototypes) do
			if remove_enemies_from_trigger(projectile.final_action, projectile_name, units_to_disable) and projectile.final_action ~= nil then
				helpers.write_file("disable-enemies-lib.txt", {"", "\tRemoving final_action from " .. projectile_name .. ".\n"}, true)
				projectile.final_action = nil
			end
		end
	end
end

local function collect_source_names(units_to_disable)
	local source_names = {}
	for unit_name, unit_entry in pairs(units_to_disable) do
		if unit_entry.sources then
			for _, source_name in ipairs(unit_entry.sources) do
				source_names[source_name] = true
			end
		end
	end
	return source_names
end

local function remove_enemies_from_entity_damage_effects(units_to_disable, entity_prototype_names)
	helpers.write_file("disable-enemies-lib.txt", {"", "Removing enemies from entity damage effects.\n"}, true)
	local entity_prototype_names = collect_source_names(units_to_disable)
	for entity_prototype_name, _ in pairs(entity_prototype_names) do
		local entity_prototypes = data.raw[entity_prototype_name]
		if entity_prototypes ~= nil then
			for entity_name, entity in pairs(entity_prototypes) do
				if remove_enemies_from_trigger_effects_list(entity.damaged_trigger_effect, entity_name, units_to_disable) and entity.damaged_trigger_effect ~= nil then
					helpers.write_file("disable-enemies-lib.txt", {"", "\tRemoving damaged_trigger_effect from " .. entity_name .. ".\n"}, true)
					entity.damaged_trigger_effect = nil
				end
			end
		end
	end
end

local function remove_enemies_from_entity_death_effects(units_to_disable)
	helpers.write_file("disable-enemies-lib.txt", {"", "Removing enemies from entity death effects.\n"}, true)
	local entity_prototype_names = collect_source_names(units_to_disable)
	for entity_prototype_name, _ in pairs(entity_prototype_names) do
		local entity_prototypes = data.raw[entity_prototype_name]
		if entity_prototypes ~= nil then
			for entity_name, entity in pairs(entity_prototypes) do
				if remove_enemies_from_trigger_effects_list(entity.dying_trigger_effect, entity_name, units_to_disable) and entity.dying_trigger_effect ~= nil then
					helpers.write_file("disable-enemies-lib.txt", {"", "\tRemoving dying_trigger_effect from " .. entity_name .. ".\n"}, true)
					entity.dying_trigger_effect = nil
				end
			end
		end
	end
end

local function remove_attacks_from_entities(entities_to_disable)
	helpers.write_file("disable-enemies-lib.txt", {"", "Removing attacks from entities.\n"}, true)
	for entity_name, entity_entry in pairs(entities_to_disable) do
		if entity_entry.entity_type == "turret" then
			local entity_prototype = data.raw["turret"][entity_name]
			if entity_prototype then
				helpers.write_file("disable-enemies-lib.txt", {"", "\tRemoving attack from " .. entity_name .. ".\n"}, true)
				local attack_parameters = entity_prototype.attack_parameters
				attack_parameters.range = 0
				attack_parameters.range_mode = "center-to-center"
				attack_parameters.damage_modifier = 0
				attack_parameters.ammo_type.action = nil
			end
		end
	end
end

-- Final fixes

if not rawequal(next(registration.units_to_disable_from_spawners), nil) then
	remove_enemies_from_spawner_results(registration.units_to_disable_from_spawners)
end

if not rawequal(next(registration.units_to_disable_from_spoilage), nil) then
	remove_enemies_from_spoilage_effects(registration.units_to_disable_from_spoilage)
end

if not rawequal(next(registration.units_to_disable_from_projectile_action), nil) then
	remove_enemies_from_projectile_action_effects(registration.units_to_disable_from_projectile_action)
end

if not rawequal(next(registration.units_to_disable_from_projectile_final_action), nil) then
	remove_enemies_from_projectile_final_action_effects(registration.units_to_disable_from_projectile_final_action)
end

if not rawequal(next(registration.units_to_disable_from_entity_damage), nil) then
	remove_enemies_from_entity_damage_effects(registration.units_to_disable_from_entity_damage)
end

if not rawequal(next(registration.units_to_disable_from_entity_death), nil) then
	remove_enemies_from_entity_death_effects(registration.units_to_disable_from_entity_death)
end

if not rawequal(next(registration.entities_to_disable_from_attacking), nil) then
	remove_attacks_from_entities(registration.entities_to_disable_from_attacking)
end
