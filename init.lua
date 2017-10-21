function reload_bow(itemstack, user)
	local inv = user:get_inventory()
	if not inv:remove_item("main", "bows:arrow"):is_empty() then
		itemstack:set_name("bows:bow_wood_charged")
		return itemstack
	end
end

minetest.register_tool("bows:bow_wood", {
	description = "Wooden Bow (place to reload)",
	inventory_image = "bows_bow_wood.png^bows_overlay_empty.png",

	on_place = reload_bow,
	on_secondary_use = reload_bow,
})

minetest.register_tool("bows:bow_wood_charged", {
	description = "Wooden Bow (use to fire)",
	inventory_image = "bows_bow_wood.png^bows_overlay_charged.png",
	groups = {not_in_creative_inventory=1},

	on_use = function(itemstack, user, pointed_thing)
		if not spawn_arrow(user, 100) then
			return -- something failed
		end
		itemstack:set_name("bows:bow_wood")
		itemstack:set_wear(itemstack:get_wear() + 0x10000 / 200)
		return itemstack
	end,
})

minetest.register_craftitem("bows:arrow", {
	description = "Arrow",
	inventory_image = "bows_arrow.png",
})

function spawn_arrow(user, strength)
	local pos = user:get_pos()
	pos.y = pos.y + 1.5 -- camera offset
	local dir = user:get_look_dir()
	local yaw = user:get_look_horizontal()

	local obj = minetest.add_entity(pos, "bows:e_arrow")
	if not obj then
		return
	end
	obj:get_luaentity().shooter_name = user:get_player_name()
	obj:set_yaw(yaw + 0.5 * math.pi)
	obj:set_acceleration({x = 0, y = -9.81, z = 0})
	obj:set_velocity(vector.multiply(dir, strength))
	return true
end

minetest.register_entity("bows:e_arrow", {
	hp_max = 5,       -- possible to catch the arrow (pro skills)
	physical = false, -- use Raycast
	collisionbox = {-0.1, -0.1, -0.1, 0.1, 0.1, 0.1},
	visual = "wielditem",
	textures = {"bows:arrow"},
	visual_size = {x = 0.4, y = 0.4},
	old_pos = nil,
	shooter_name = "",
	
	on_step = function(self, dtime)
		print("tick tock" .. self.shooter_name)
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
				print("drop")
				minetest.item_drop(ItemStack("bows:arrow"), nil, vector.round(self.old_pos))
				self.object:remove()
				return
			end
			thing = cast:next()
		end
		self.old_pos = pos
	end,
})