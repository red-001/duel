minetest.register_chatcommand("duel", {
	params = "<player name>",
	description = "Challenge a player to a duel",
	func = function(caller, param)
		if caller == param then
			return false, "You can't have a duel with yourself"
		end
		
		local player = minetest.get_player_by_name(param)
		if not player then
			return false, "Player:"..param.." not found."
		end
		
		if duel.challenge(caller, param) then
			return true, "You have challenged "..param.." to a duel"
		else
			return false, "Duel already in progres"
		end
	end,
})

minetest.register_chatcommand("duel_accept", {
	description = "Accept a duel",
	func = function(caller, param)
		if duel.accept(caller) then
			return true, "You have accepted the challenge"
		else
			return false, "No-one has challenged you to a duel"
		end
	end,
})

minetest.register_chatcommand("duel_abandon", {
	description = "Abandon a duel before one of the players dies (causes you to lose)",
	func = function(caller, param)
		if duel.lose(caller) then
			return true, "You have abandon a duel"
		else
			return false, "You are not in a duel"
		end
	end,
})
