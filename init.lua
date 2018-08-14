
if not minetest.raycast then
	error("[farbows] This mod requires at least Minetest 5.0.0-dev")
end


farbows = {}

function farbows.spawn_arrow(user, strength)
	local pos = user:get_pos()
	pos.y = pos.y + 1.5 -- camera offset
	local dir = user:get_look_dir()
	local yaw = user:get_look_horizontal()

	local obj = minetest.add_entity(pos, "farbows:e_arrow")
	if not obj then
		return
	end
	obj:get_luaentity().shooter_name = user:get_player_name()
	obj:set_yaw(yaw - 0.5 * math.pi)
	obj:set_velocity(vector.multiply(dir, strength))
	return true
end

function farbows.register_bow(bowname, def)
	assert(type(def.description) == "string")
	assert(type(def.image) == "string")
	assert(type(def.strength) == "number")
	assert(def.uses > 0)

	local function reload_bow(itemstack, user)
		local inv = user:get_inventory()
		if not inv:remove_item("main", "farbows:arrow"):is_empty() then
			itemstack:set_name(bowname .. "_charged")
			return itemstack
		end
	end

	minetest.register_tool(bowname, {
		description = def.description .. " (place to reload)",
		inventory_image = def.image .. "^farbows_overlay_empty.png",

		on_use = function() end,
		on_place = reload_bow,
		on_secondary_use = reload_bow,
	})

	if def.recipe_item then
		minetest.register_craft({
			output = bowname,
			recipe = {
				{"", def.recipe_item, "farming:string"},
				{def.recipe_item, "", "farming:string"},
				{"", def.recipe_item, "farming:string"},
			}
		})
	end

	minetest.register_tool(bowname .. "_charged", {
		description = def.description .. " (use to fire)",
		inventory_image = def.image .. "^farbows_overlay_charged.png",
		groups = {not_in_creative_inventory=1},

		on_use = function(itemstack, user, pointed_thing)
			if not farbows.spawn_arrow(user, def.strength) then
				return -- something failed
			end
			itemstack:set_name(bowname)
			itemstack:set_wear(itemstack:get_wear() + 0x10000 / def.uses)
			return itemstack
		end,
	})
end

farbows.register_bow("farbows:bow_wood", {
	description = "Wooden Bow",
	image = "farbows_bow_wood.png",
	recipe_item = "group:wood",
	strength = 30,
	uses = 150
})

farbows.register_bow("farbows:bow_mese", {
	description = "Mese Bow",
	image = "farbows_bow_mese.png",
	recipe_item = "default:mese_crystal",
	strength = 60,
	uses = 800
})

minetest.register_craftitem("farbows:arrow", {
	description = "Arrow",
	inventory_image = "farbows_arrow.png",
})

minetest.register_craft({
	output = "farbows:arrow 5",
	recipe = {
		{"default:steel_ingot", "default:stick", "default:stick"},
	}
})

minetest.register_entity("farbows:e_arrow", {
	hp_max = 4,       -- possible to catch the arrow (pro skills)
	physical = false, -- use Raycast
	collisionbox = {-0.1, -0.1, -0.1, 0.1, 0.1, 0.1},
	visual = "wielditem",
	textures = {"farbows:arrow"},
	visual_size = {x = 0.2, y = 0.15},
	old_pos = nil,
	shooter_name = "",
	waiting_for_removal = false,

	on_activate = function(self)
		self.object:set_acceleration({x = 0, y = -9.81, z = 0})
	end,

	on_step = function(self, dtime)
		if self.waiting_for_removal then
			self.object:remove()
			return
		end
		local pos = self.object:get_pos()
		self.old_pos = self.old_pos or pos

		local cast = minetest.raycast(self.old_pos, pos, true, false)
		local thing = cast:next()
		while thing do
			if thing.type == "object" and thing.ref ~= self.object then
				if not thing.ref:is_player()
						or thing.ref:get_player_name() ~= self.shooter_name then

					thing.ref:punch(self.object, 1.0, {
						full_punch_interval = 0.5,
						damage_groups = {fleshy = 8}
					})
					self.waiting_for_removal = true
					self.object:remove()
					return
				end
			elseif thing.type == "node" then
				local name = minetest.get_node(thing.under).name
				if minetest.registered_items[name].walkable then
					minetest.item_drop(ItemStack("farbows:arrow"),
						nil, vector.round(self.old_pos))
					self.waiting_for_removal = true
					self.object:remove()
					return
				end
			end
			thing = cast:next()
		end
		self.old_pos = pos
	end,
})
