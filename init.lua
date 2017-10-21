bows = {}

function bows.spawn_arrow(user, strength)
	local pos = user:get_pos()
	pos.y = pos.y + 1.5 -- camera offset
	local dir = user:get_look_dir()
	local yaw = user:get_look_horizontal()

	local obj = minetest.add_entity(pos, "bows:e_arrow")
	if not obj then
		return
	end
	obj:get_luaentity().shooter_name = user:get_player_name()
	obj:set_yaw(yaw - 0.5 * math.pi)
	obj:set_velocity(vector.multiply(dir, strength))
	return true
end

function bows.register_bow(bowname, def)
	assert(type(def.description) == "string")
	assert(type(def.image) == "string")
	assert(type(def.strength) == "number")
	assert(def.uses > 0)

	local function reload_bow(itemstack, user)
		local inv = user:get_inventory()
		if not inv:remove_item("main", "bows:arrow"):is_empty() then
			itemstack:set_name(bowname .. "_charged")
			return itemstack
		end
	end

	minetest.register_tool(bowname, {
		description = def.description .. " (place to reload)",
		inventory_image = def.image .. "^bows_overlay_empty.png",

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
		inventory_image = def.image .. "^bows_overlay_charged.png",
		groups = {not_in_creative_inventory=1},

		on_use = function(itemstack, user, pointed_thing)
			if not bows.spawn_arrow(user, def.strength) then
				return -- something failed
			end
			itemstack:set_name(bowname)
			itemstack:set_wear(itemstack:get_wear() + 0x10000 / def.uses)
			return itemstack
		end,
	})
end

bows.register_bow("bows:bow_wood", {
	description = "Wooden Bow",
	image = "bows_bow_wood.png",
	recipe_item = "group:wood",
	strength = 40,
	uses = 200
})

bows.register_bow("bows:bow_mese", {
	description = "Mese Bow",
	image = "bows_bow_mese.png",
	recipe_item = "default:mese_crystal",
	strength = 80,
	uses = 600
})


minetest.register_craftitem("bows:arrow", {
	description = "Arrow",
	inventory_image = "bows_arrow.png",
})

minetest.register_craft({
	output = "bows:arrow 5",
	recipe = {
		{"default:steel_ingot", "default:stick", "default:stick"},
	}
})

minetest.register_entity("bows:e_arrow", {
	hp_max = 4,       -- possible to catch the arrow (pro skills)
	physical = false, -- use Raycast
	collisionbox = {-0.1, -0.1, -0.1, 0.1, 0.1, 0.1},
	visual = "wielditem",
	textures = {"bows:arrow"},
	visual_size = {x = 0.2, y = 0.15},
	old_pos = nil,
	shooter_name = "",

	on_activate = function(self)
		self.object:set_acceleration({x = 0, y = -9.81, z = 0})
	end,

	on_step = function(self, dtime)
		local pos = self.object:get_pos()
		self.old_pos = self.old_pos or pos

		local cast = minetest.raycast(self.old_pos, pos, true, false)
		local thing = cast:next()
		while thing do
			if thing.type == "object" and thing.ref ~= self.object then
				if not thing.ref:is_player()
						or thing.ref:get_player_name() ~= self.shooter_name then
					print("punch")
					thing.ref:punch(self.object, 1.0, {
						full_punch_interval = 0.5,
						damage_groups = {fleshy = 8}
					})
					self.object:remove()
					return
				end
			elseif thing.type == "node" then
				minetest.item_drop(ItemStack("bows:arrow"), nil, vector.round(self.old_pos))
				self.object:remove()
				return
			end
			thing = cast:next()
		end
		self.old_pos = pos
	end,
})