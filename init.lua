-- Structure definitions.

local TRUNK_MINHEIGHT = 7
local TRUNK_MAXHEIGHT = 25

local LEAVES_MINHEIGHT = 2
local LEAVES_MAXHEIGHT = 6
local LEAVES_MAXRADIUS = 5
local LEAVES_NARROWRADIUS = 3 -- For narrow typed conifers.

local CONIFERS_DISTANCE = 4
local CONIFERS_ALTITUDE = 30

local SAPLING_CHANCE = 100 -- 1/x chances to grow a sapling.

local INTERVAL = 3600

local conifers_seed = 1435

-- End of structure definitions.


local conifers = {}



--------------------------------------------------------------------------------
--
-- Definitions
--
--------------------------------------------------------------------------------

--
-- Node definitions
--
minetest.register_node("conifers:trunk", {
	description = "Conifer trunk",
	tiles = {
		"conifers_trunktop.png",
		"conifers_trunktop.png",
		"conifers_trunk.png",
	},
	paramtype2 = "facedir",
	--material = minetest.digprop_woodlike(1.0),
	groups = {
		tree = 1,
		snappy = 2,
		choppy = 2,
		oddly_breakable_by_hand = 1,
		flammable = 2
	},
	sounds = default.node_sound_wood_defaults(),
	on_place = minetest.rotate_node,
})

minetest.register_node("conifers:leaves", {
	description = "Conifer leaves",
	drawtype = "allfaces_optional",
	visual_scale = 1.3,
	tiles = { "conifers_leaves.png" },
	--inventory_image = "conifers_leaves.png",
	paramtype = "light",
	groups = {
		snappy = 3,
		--leafdecay = 3,
		flammable = 2
	},
	drop = {
		max_items = 1,
		items = {
			{
				-- player will get sapling with 1/20 chance
				items = {"conifers:sapling"},
				rarity = 20,
			},
			{
				-- player will get leaves only if he get no saplings,
				-- this is because max_items is 1
				items = {"conifers:leaves"},
			}
		}
	},
	sounds = default.node_sound_leaves_defaults()
})

minetest.register_node("conifers:leaves_special", {
	description = "Bright conifer leaves",
	drawtype = "allfaces_optional",
	visual_scale = 1.3,
	tiles = { "conifers_leaves_special.png" },
	--inventory_image = "conifers_leaves_special.png",
	paramtype = "light",
	groups = {
		snappy = 3,
		--leafdecay = 3,
		flammable = 2
	},
	drop = {
		max_items = 1,
		items = {
			{
				-- player will get sapling with 1/20 chance
				items = {"conifers:sapling"},
				rarity = 20,
			},
			{
				-- player will get leaves only if he get no saplings,
				-- this is because max_items is 1
				items = {"conifers:leaves"},
			}
		}
	},
	sounds = default.node_sound_leaves_defaults()
})

minetest.register_node("conifers:sapling", {
	description = "Conifer sapling",
	drawtype = "plantlike",
	tiles = {"conifers_sapling.png"},
	inventory_image = "conifers_sapling.png",
	wield_image = "conifers_sapling.png",
	paramtype = "light",
	walkable = false,
	groups = {
		snappy = 2,
		dig_immediate = 3,
		flammable = 2
	},
	sounds = default.node_sound_defaults(),
})


conifers_c_air = minetest.get_content_id("air")
conifers_c_tree = minetest.get_content_id("default:tree")
conifers_c_leaves = minetest.get_content_id("default:leaves")
conifers_c_dirt_with_grass = minetest.get_content_id("default:dirt_with_grass")

conifers_c_con_trunk = minetest.get_content_id("conifers:trunk")
conifers_c_con_leaves = minetest.get_content_id("conifers:leaves")
conifers_c_con_leaves_special = minetest.get_content_id("conifers:leaves_special")
conifers_c_con_sapling = minetest.get_content_id("conifers:sapling")


--
-- Craft definitions
--

minetest.register_craft({
	output = "default:wood 4",
	recipe = {
		{"conifers:trunk"}
	}
})


--
-- ABM definitions
--
-- Spawn random conifers.

local function get_conifers_random(pos)
	return PseudoRandom(math.abs(pos.x+pos.y*3+pos.z*5)+conifers_seed)
end

local function conifer_abm_rand(pos)
	local pr = get_conifers_random(pos)
	local p = {x=pos.x, y=pos.y+1, z=pos.z}
	if pr:next(1,23) == 1
	and minetest.get_node(p).name == "air"
	and pos.y >= CONIFERS_ALTITUDE
	and (not conifers:is_node_in_cube({"conifers:trunk"}, pos, CONIFERS_DISTANCE)) then
		conifers:make_conifer(p, math.random(0, 1))
	end
end

local function conifer_abm_rand_delay(pos)
	local node = minetest.get_node(pos)
	if node.name == "default:dirt_with_grass" then
		conifer_abm_rand(pos, node)
	end
end

local can_grass_abm = true
minetest.register_abm({
	nodenames = "default:dirt_with_grass",
	interval = INTERVAL,
	chance = 9.1,
	catch_up = false,
	action = function(pos)
		if not can_grass_abm then
			return
		end
		can_grass_abm = false
		minetest.after(INTERVAL, function()
			can_grass_abm = true
		end)
		minetest.delay_function(INTERVAL-1, conifer_abm_rand_delay, pos)
	end
})


-- Saplings.

local function conifer_abm_sapling(pos)
	if minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name == "air" then
		conifers:make_conifer(pos, math.random(0, 1))
	end
end

local function conifer_abm_sapling_delay(pos)
	local node = minetest.get_node(pos)
	if node.name == "conifers:sapling" then
		conifer_abm_sapling(pos, node)
	end
end

minetest.register_abm({
	nodenames = "conifers:sapling",
	interval = INTERVAL,
	chance = SAPLING_CHANCE,

	action = function(pos)
		minetest.delay_function(INTERVAL-1, conifer_abm_sapling_delay, pos)
	end
})



--------------------------------------------------------------------------------
--
-- Functions
--
--------------------------------------------------------------------------------

--
-- table_contains(t, v)
--
-- Taken from the Flowers mod by erlehmann.
--
function conifers:table_contains(t, v)
	for _,i in ipairs(t) do
		if i == v then
			return true
		end
	end
	return false
end

--
-- is_node_in_cube(nodenames, node_pos, radius)
--
-- Taken from the Flowers mod by erlehmann.
--
function conifers:is_node_in_cube(nodenames, pos, size)
	local hs = math.floor(size / 2)
	for x = pos.x-size, pos.x+size do
		for y = pos.y-hs, pos.y+hs do
			for z = pos.z-size, pos.z+size do
				local n = minetest.get_node_or_nil({x=x, y=y, z=z})
				if n == nil
				or n.name == "ignore"
				or conifers:table_contains(nodenames, n.name) then
					return true
				end
			end
		end
	end
	return false
end

local area, nodes

--
-- are_leaves_surrounded(position)
--
-- Return a boolean value set to "true" if a leaves block is surrounded
-- by something else than
--  - air
--  - leaves
--  - special leaves
--
-- If a leaves block is surrounded by the blocks above,
-- it can be placed.
-- Otherwise, it will replace blocks we want to keep.
--
function conifers:are_leaves_surrounded(pos)
	--
	-- Check if a leaves block does not interfer with something else than the air or another leaves block.
	--
	local replacable_nodes = {conifers_c_air, conifers_c_con_leaves, conifers_c_con_leaves_special}

	-- Let's check if the neighboring node is a replacable node.
	for i = -1,1,2 do
		if (not conifers:table_contains(replacable_nodes, nodes[area:index(pos.x+i, pos.y, pos.z)]))
		or (not conifers:table_contains(replacable_nodes, nodes[area:index(pos.x, pos.y, pos.z+i)])) then
			return true
		end
	end
	return false
end

--
-- add_leaves_block(position, type of leaves, near trunk?)
--
-- Put a simple leaves block.
-- Leaves must be positioned near a trunk or surrounded by air.
-- Types of leaves are:
-- 	0: dark leaves
--	1: bright leaves (special)
--
function conifers:add_leaves_block(pos, special, near_trunk)
	if conifers:are_leaves_surrounded(pos)
	and not near_trunk then
		return
	end
	local p_pos = area:index(pos.x, pos.y, pos.z)
	if nodes[p_pos] ~= conifers_c_air then
		return
	end
	if special == 0 then
		nodes[p_pos] = conifers_c_con_leaves
	else
		nodes[p_pos] = conifers_c_con_leaves_special
	end
end

-- Put a small circle of leaves around the trunk.
--    [ ]
-- [ ][#][ ]
--    [ ]
function conifers:add_small_leaves_circle(c, special)
	for i = -1,1,2 do
		conifers:add_leaves_block({x=c.x+i, y=c.y, z=c.z}, special, true)
		conifers:add_leaves_block({x=c.x, y=c.y, z=c.z+i}, special, true)
	end
end

--
-- make_leaves(middle point, min radius, max radius, type of leaves)
--
-- Make a circle of leaves with a center given by "middle point".
-- Types of leaves are:
-- 	0: dark leaves
--	1: bright leaves (special)
--
function conifers:make_leaves(c, radius_min, radius_max, special)
	if radius_max <= 1 then
		conifers:add_small_leaves_circle(c, special)
		return
	end
	--
	-- Using the midpoint circle algorithm from Bresenham we can trace a circle of leaves.
	--
	for r = radius_min, radius_max do
		local m_x = 0
		local m_z = r
		local m_m = 5 - 4 * r
		while m_x <= m_z do
			if r == 1 then
				-- Add a square of leaves (fixing holes near the trunk).
				-- [ ]   [ ]
				--    [#]
				-- [ ]   [ ]
				for i = 1,-1,-2 do
					for j = -1,1,2 do
						conifers:add_leaves_block({x=c.x+j, y=c.y, z=c.z+i}, special)
					end
				end

				conifers:add_small_leaves_circle(c, special)
			else
				for i = -1,1,2 do
					for j = -1,1,2 do
						for _,a in ipairs({{m_x, m_z}, {m_z, m_x}}) do
							conifers:add_leaves_block({x=j*a[1]+c.x, y=c.y, z=i*a[2]+c.z}, special)
						end
					end
				end
			end
			-- Stuff...
			if m_m > 0 then
				m_z = m_z - 1
				m_m = m_m - 8 * m_z
			end
			m_x = m_x + 1
			m_m = m_m + 8 * m_x + 4
		end
	end
end

local function log(txt)
	minetest.log("action", "[conifers] "..txt)
end

local function delayed_map_update(manip)
	local t1 = os.clock()
	manip:update_map()
	log(string.format("map updated after ca. %.2fs", os.clock() - t1))
end

--
-- make_conifer(position, type)
--
-- Make a conifer at a given position.
-- Types are:
-- 	0: regular pine
--	1: narrow pine
--
function conifers:make_conifer(pos, conifer_type)
	local height = math.random(TRUNK_MINHEIGHT, TRUNK_MAXHEIGHT) -- Random height of the conifer.

	local t1 = os.clock()
	local manip = minetest.get_voxel_manip()
	local vwidth = LEAVES_MAXRADIUS+1
	local emerged_pos1, emerged_pos2 = manip:read_from_map({x=pos.x-vwidth, y=pos.y, z=pos.z-vwidth},
		{x=pos.x+vwidth, y=pos.y+height+1, z=pos.z+vwidth})

	area = VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
	nodes = manip:get_data()

	-- Check if we can gros a conifer at this place.
	local p_pos = area:index(pos.x, pos.y, pos.z)
	local d_p_pos = nodes[p_pos]

	if nodes[area:index(pos.x, pos.y-1, pos.z)] ~= conifers_c_dirt_with_grass
	and (d_p_pos ~= conifers_c_air
		or d_p_pos ~= conifers_c_con_sapling
	) then
		return false
	--else
		--if minetest.get_node({x = pos.x, y = pos.y, z = pos.z}).name == "conifers:sapling" then
			--minetest.add_node(pos , {name = "air"})
		--end
	end

	-- Let's check if we can grow a tree here.
	-- That means, we must have a column of "height" high which contains
	-- only air.
	for j = 1, height - 1 do -- Start from 1 so we can grow a sapling.
		if nodes[area:index(pos.x, pos.y+j, pos.z)] ~= conifers_c_air then
			-- Abort
			return false
		end
	end

	local leaves_height = math.random(LEAVES_MINHEIGHT, LEAVES_MAXHEIGHT) -- Level from where the leaves grow.
	local current_block = {} -- Duh...
	local leaves_radius = 1
	local leaves_max_radius = 2
	local special = math.random(0, 1)

	-- Create the trunk and add the leaves.
	for i = 0, height - 1 do
		current_block = {x=pos.x, y=pos.y+i, z=pos.z}
		-- Put a trunk block.
		nodes[area:index(pos.x, pos.y+i, pos.z)] = conifers_c_con_trunk
		-- Put some leaves.
		if i >= leaves_height then
			-- Put some leaves.
			conifers:make_leaves({x=pos.x, y=pos.y+leaves_height+height-1-i, z=pos.z}, 1, leaves_radius, special)
			--
			-- TYPE OF CONIFER
			--
			if conifer_type == 1 then -- Regular type
				-- Prepare the next circle of leaves.
				leaves_radius = leaves_radius+1
				-- Check if the current radius is the maximum radius at this level.
				if leaves_radius > leaves_max_radius then
					leaves_radius = 1
					-- Does it exceeds the maximum radius?
					if leaves_max_radius < LEAVES_MAXRADIUS then
						leaves_max_radius = leaves_max_radius+1
					end
				end
			else -- Narrow type
				if i % 2 == 0 then
					leaves_radius = LEAVES_NARROWRADIUS-math.random(0,1)
				else
					leaves_radius = math.floor(LEAVES_NARROWRADIUS/2)
				end
			end
		end
	end

	-- Put a top leaves block.
	current_block.y = current_block.y+1
	conifers:add_leaves_block(current_block, special)

	manip:set_data(nodes)
	manip:write_to_map()
	log(string.format("A conifer has grown at "..
		"("..pos.x..","..pos.y..","..pos.z..")"..
		" with a height of "..height..
		" after ca. %.2fs", os.clock() - t1)
	)	-- Blahblahblah
	minetest.delay_function(16384, delayed_map_update, manip)
	return true
end


-- legacy

minetest.register_node("conifers:trunk_reversed", {
	description = "Conifer reversed trunk",
	tiles = {"conifers_trunk.png"},
	drop = "conifers:trunk",
	groups = {not_in_creative_inventory = 1},
	sounds = default.node_sound_wood_defaults(),
	on_place = function(stack)
		local backup = ItemStack(stack)
		if stack:set_name("conifers:trunk") then
			return stack
		end
		return backup
	end
})

minetest.register_craft({
	output = "conifers:trunk",
	recipe = {{"conifers:trunk_reversed"}}
})

minetest.register_abm({
	nodenames = {"conifers:trunk_reversed"},
	interval = 1,
	chance = 1,
	action = function(pos, node)
		minetest.set_node(pos, {name="conifers:trunk", param2=12})
		log("legacy: a horizontal tree node became changed at "..minetest.pos_to_string(pos))
	end
})
