function init()
	global.creepers = {}
	global.index = 1
	for each, surface in pairs(game.surfaces) do
		local roboports = surface.find_entities_filtered{type="roboport"}
		for index, port in pairs(roboports) do
			if validate(port) then
				addPort(port)
			end
		end
	end
end

function check_roboports()
	-- Iterate over up to 5 entities
	if #global.creepers == 0 then return end
	for i = 1, 5 do
		if i > #global.creepers then
            return
        end
		local creeper = get_creeper()
		if creeper == nil then
			--game.print("creeper removed")
			return end --This is where I want a 'continue' keyword.
		local roboport = creeper.roboport
		if roboport.logistic_network and
		roboport.logistic_network.valid and
		roboport.prototype.electric_energy_source_prototype.buffer_capacity == roboport.energy then --Check if powered and full energy
			creep(creeper)
		end
    end
end

function get_creeper()
	if global.index > #global.creepers then
		global.index = 1
	end
	local creeper = global.creepers[global.index]
	if not (creeper.roboport and creeper.roboport.valid) or creeper.off then --Roboport removed
		table.remove(global.creepers, global.index)
		return
	end
	global.index = global.index + 1
	return creeper
end

function checkRoboports()
	if global.creepers and #global.creepers > 0 then
		--for index, creeper in pairs(global.creepers) do
		local creeper = global.creepers[global.index]
		if creeper then -- Redundant?
			local roboport = creeper.roboport
			local radius = creeper.radius
			local amount = 0
			-- Place a tile per every 10 robots.
			if roboport and roboport.valid then --Check if still alive
				if roboport.logistic_network and roboport.logistic_network.valid and roboport.prototype.electric_energy_source_prototype.buffer_capacity == roboport.energy then --Check if powered!
					-- if roboport.logistic_cell.construction_radius == 0 then --Not a valid creeper.
						-- table.remove(global.creepers, global.index)
						-- return false
					-- end
					if roboport.logistic_network.available_construction_robots > 0 then
						amount = math.floor(roboport.logistic_network.available_construction_robots / 2)
						roboport.force.max_successful_attemps_per_tick_per_construction_queue = math.max(roboport.force.max_successful_attemps_per_tick_per_construction_queue,  math.floor(amount / 60) )
						-- amount = 10
						--game.print(serpent.line(index))
						if creep(global.index, amount) then
							return true
						end
					end
				else
					return false
				end
			else -- Roboport died
				table.remove(global.creepers, global.index)
			end
		else
			table.remove(global.creepers, global.index)
		end
		-- global.index = global.index + 1
		-- if global.index > #global.creepers then
		-- 	global.index = 1
		-- end
		--end
	end
end

function creep(creeper)
	local roboport = creeper.roboport
	local surface = roboport.surface
	local force = roboport.force
	local radius = creeper.radius
	local idle_robots = roboport.logistic_network.available_construction_robots / 2
	local count = 0
	
	local area = {{roboport.position.x - radius, roboport.position.y - radius}, {roboport.position.x + radius, roboport.position.y + radius}}
	-- game.print("X: " .. roboport.position.x)
	-- game.print("Y: " .. roboport.position.y)
	-- game.print("Rad: " .. radius)
	local ghosts = surface.count_entities_filtered{area=area, name="tile-ghost", force=force}

	if force.max_successful_attempts_per_tick_per_construction_queue * 60 < idle_robots then
		force.max_successful_attempts_per_tick_per_construction_queue = math.floor(idle_robots / 60)
	end

	local refined_concrete_count = roboport.logistic_network.get_item_count("refined-concrete")
	local concrete_count = roboport.logistic_network.get_item_count("concrete")
	local brick_count = roboport.logistic_network.get_item_count("stone-brick")
	local landfill = roboport.logistic_network.get_item_count("landfill")

	--Seems we need to do this twice for reinforced concrete and regular concrete.
	local function build_tile(type, position)
		if surface.can_place_entity{name="tile-ghost", position=position, inner_name=type, force=force} then
			surface.create_entity{name="tile-ghost", position=position, inner_name=type, force=force, expires=false}
			count = count + 1
		else
			return
		end
		local tree_area = {{position.x - 0.2,  position.y - 0.2}, {position.x + 0.8, position.y + 0.8}}
		for i, tree in pairs(surface.find_entities_filtered{type = "tree", area=tree_area}) do
			tree.order_deconstruction(roboport.force)
			count = count + 1
		end
		for i, rock in pairs(surface.find_entities_filtered{type = "simple-entity", area=tree_area}) do
			rock.order_deconstruction(roboport.force)
			count = count + 1
		end

		for i, cliff in pairs(surface.find_entities_filtered{type = "cliff", limit=1, area=tree_area}) do
			if roboport.logistic_network.get_item_count("cliff-explosives") > 0 then
				cliff.order_deconstruction(roboport.force)
				count = count + 1
				--roboport.logistic_network.remove_item({name="cliff-explosives", 1})
			end
		end
	end

	local virgin_tiles = surface.find_tiles_filtered{has_hidden_tile=false, area=area, limit=idle_robots, collision_mask="ground-tile"}
	if ghosts > #virgin_tiles then return end --Wait for ghosts to finish building first.
	for i = #virgin_tiles, 1, -1 do
		local ghost_type
		if not creeper.pattern[(virgin_tiles[i].position.x-2) % 4][(virgin_tiles[i].position.y-2) % 4] then
			--ghost_type = "refined-concrete"
			--(settings.global["creep brick"].value and "stone-path") or "concrete"

			-- If we have enough refined concrete, use that.
			if count < refined_concrete_count then
				ghost_type = "refined-concrete"
			-- If not, use regular concrete
			elseif count < concrete_count then
				ghost_type = "concrete"
			--If not, use a stone path.
			elseif count < brick_count and settings.global["creep brick"].value then
				ghost_type = "stone-path"
			end
		else
			if roboport.logistic_network.get_item_count(creeper.item[(virgin_tiles[i].position.x-2) % 4][(virgin_tiles[i].position.y-2) % 4]) > 0 then
				ghost_type = creeper.pattern[(virgin_tiles[i].position.x-2) % 4][(virgin_tiles[i].position.y-2) % 4]
			end
		end
		if ghost_type then
			build_tile(ghost_type, virgin_tiles[i].position)
			table.remove(virgin_tiles, i)
		end
	end

	if count >= idle_robots then
		-- game.print("Found some work to do.  Terminating early.")
		return true
	end
	idle_robots = idle_robots - count

	--Still here?  Look for concrete to upgrade
	if creeper.upgrade then
		if settings.global["upgrade brick"].value then
			local squishy_targets = surface.find_tiles_filtered{area=area, name="stone-path", limit=math.min(math.max(concrete_count, refined_concrete_count), idle_robots)}
			for k,v in pairs(squishy_targets) do
				local tile_type = "refined-concrete"
				if count >= refined_concrete_count then
					tile_type = "concrete"
				end
				if surface.can_place_entity{name="tile-ghost", position=v.position, inner_name=tile_type, force=roboport.force} then
					surface.create_entity{name="tile-ghost", position=v.position, inner_name=tile_type, force=roboport.force}
					count = count + 1
				end
			end
		end
		if settings.global["upgrade concrete"].value then
			local targets = surface.find_tiles_filtered{area=area, name="concrete", limit=math.min(refined_concrete_count, idle_robots)}
			for k,v in pairs(targets) do
				if surface.can_place_entity{name="tile-ghost", position=v.position, inner_name="refined-concrete", force=roboport.force} then
					surface.create_entity{name="tile-ghost", position=v.position, inner_name="refined-concrete", force=roboport.force}
					count = count + 1
				end
			end
		end

		if count >= idle_robots then
			--game.print("Found some work to do.  Terminating early.")
			return true
		end
		idle_robots = idle_robots - count

		--refined_concrete_count = roboport.logistic_network.get_item_count("refined-hazard-concrete")
		local targets = surface.find_tiles_filtered{area=area, name="hazard-concrete-left", limit=refined_concrete_count}
		for k,v in pairs(targets) do
			if surface.can_place_entity{name="tile-ghost", position=v.position, inner_name="refined-hazard-concrete-left", force=roboport.force} then
				surface.create_entity{name="tile-ghost", position=v.position, inner_name="refined-hazard-concrete-left", force=roboport.force}
				count = count + 1
				--refined_concrete_count = refined_concrete_count - 1
			end
		end
		local targets = surface.find_tiles_filtered{area=area, name="hazard-concrete-right", limit=refined_concrete_count}
		for k,v in pairs(targets) do
			if surface.can_place_entity{name="tile-ghost", position=v.position, inner_name="refined-hazard-concrete-left", force=roboport.force} then
				surface.create_entity{name="tile-ghost", position=v.position, inner_name="refined-hazard-concrete-left", force=roboport.force}
				count = count + 1
			end
		end

		if count >= idle_robots then return true end
	end



	-- Alright, how about water to fill in?
	local water_tiles = surface.find_tiles_filtered{area=area, collision_mask="water-tile"}
	if ghosts > #water_tiles then 
		return
	end --Wait for ghosts to finish building first.
	for k,v in pairs(water_tiles) do
		-- game.print("Place land!")
		surface.create_entity{name="tile-ghost", position=v.position, inner_name="landfill", force=roboport.force}
	end





	--Still here?  Check to see if the roboport should turn off or increase it's radius.
	-- game.print("Water: " .. surface.count_tiles_filtered{collision_mask="water-tile", area=area})
	-- game.print("Virgins: " .. surface.count_tiles_filtered{area=area, has_hidden_tile=false, collision_mask="ground-tile"})
	if (
		surface.count_tiles_filtered{area=area, has_hidden_tile=false, collision_mask="ground-tile"} == 0 and
		roboport.logistic_network.get_item_count("concrete") > 0)
		or
		surface.count_tiles_filtered{collision_mask="water-tile", area=area} == 0 then
	--surface.count_tiles_filtered{name="hazard-concrete-left", area=area} == 0 and
	--surface.count_tiles_filtered{name="hazard-concrete-right", area=area} == 0 then
		-- game.print("Increase radius!")
		if radius < roboport.logistic_cell.construction_radius * settings.global["concreep range"].value / 100 then
			--creeper.radius = creeper.radius + 2
			-- game.print("Logistic cell construction radius: " .. roboport.logistic_cell.construction_radius)
			creeper.radius = math.min(creeper.radius + 2, roboport.logistic_cell.construction_radius) -- Todo for next version
		else
			local switch = true
			--Make sure no tiles can be upgraded before proceeding.
			if settings.global["upgrade brick"].value and surface.count_tiles_filtered{name="stone-path", area=area, limit=1} > 0 then
				switch = false
			end
			if settings.global["upgrade concrete"].value and
			(surface.count_tiles_filtered{name="concrete", area=area, limit=1} > 0 or
			surface.count_tiles_filtered{name="hazard-concrete-left", area=area, limit=1} > 0 or
			surface.count_tiles_filtered{name="hazard-concrete-right", area=area, limit=1} > 1) then
				switch = false
			end
			if switch then
				creeper.off = true
				--game.print("Removing creeper")
			else
				creeper.radius = 4 --Reset radius and switch to upgrade mode.
				creeper.upgrade = true
			end
			
		end
	end

		return false
	--end
end

--Is this a valid roboport?
function validate(entity)
	if entity and entity.valid and (entity.type == "roboport") and entity.logistic_cell and (entity.logistic_cell.construction_radius > 0) then
		-- game.print("Valid")
		return true
	end
	-- game.print("Invalid")
	return false
end

function roboports(event)
	if not global.creepers then
		init()
	end
	if validate(event.created_entity) then
		addPort(event.created_entity)
	end
end

function addPort(roboport)
	local surface = roboport.surface
	-- Now capture the pattern the roboport sits on.
	local patt = {}
	local it = {}
	for xx = -2, 1, 1 do
		patt[xx+2] = {}
		it[xx+2] = {}
		for yy = -2, 1, 1 do
			local tile = surface.get_tile(roboport.position.x + xx, roboport.position.y + yy)
			if (tile.hidden_tile and tile.prototype.items_to_place_this) and not (tile.name == "stone-path" or tile.name == "concrete" or tile.name == "refined-concrete") then
				it[xx+2][yy+2] = tile.prototype.items_to_place_this[1] and game.item_prototypes[tile.prototype.items_to_place_this[1].name] and tile.prototype.items_to_place_this[1].name
				patt[xx+2][yy+2] = tile.name
				-- game.print(serpent.line(items))
			end
		end
	end
	table.insert(global.creepers, {roboport = roboport, radius = 1, pattern = patt, item = it})
end

function validate_tile_names()
	for i = #global.creepers, 1, -1 do
		local creep = global.creepers[i]
		local remove = false
		for x, yy in pairs(creep.item) do
			for y, item_name in pairs(yy) do
				if not(game.item_prototypes[item_name]) then
					remove = true
					break
				end
			end
		end
		if remove then
			table.remove(global.creepers, i)
			addPort(creep.roboport)
		end
	end
end

script.on_event(defines.events.on_built_entity, roboports)
script.on_event(defines.events.on_robot_built_entity, roboports)
script.on_nth_tick(60, check_roboports)
script.on_init(init)
script.on_configuration_changed(validate_tile_names)
