core.register_chatcommand("forceduel", {
	params = "<player name>",
	description = "Force a player to duel",
	func = function(caller, param)
		local player = minetest.get_player_by_name(param)
		if not player then
			return false, "Player:"..param.." not found."
		end
			
		if duel.challenge(caller, param) then
			duel.accept(param)
			return true, "You have challenged "..param.." to a duel"
		else
			return false, "Duel already in progres"
		end
	end,
})
	
core.register_chatcommand("setstate", {
	description = "set duel state",
	func = function(caller, param)
		duel_data.state = param
		return true, "done"
	end,
})
	
core.register_chatcommand("restore", {
	description = "restore inventory",
	func = function(caller, param)
		local player = minetest.get_player_by_name(caller)
		restore_player_inv(player)
		return true, "done"
	end,
})

core.register_chatcommand("save", {
	description = "save inventory",
	func = function(caller, param)
		local player = minetest.get_player_by_name(caller)
		save_player_inv(player)
		return true, "done"
	end,
})
core.register_chatcommand("dump", {
	description = "dump data",
	func = function(caller, param)
		print(dump(duel_data))
		return true, "done"
	end,
})