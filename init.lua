duel = {}

local modpath = minetest.get_modpath("duel")

-- TODO: use a setting for this
duel.pos1={x=0,y=0,z=0}
duel.pos2={x=10,y=0,z=10}

local dev_mode = false -- Do not set this to true on real servers!!!!!!!

local duel_data = {
	state = 0, -- 0: Not in progress, 1: challenge sent out 2: duel in progress 
	time = 0, -- game time at which the duel request was sent out
	move_on_respawn = {},
}

local items_to_grant = minetest.setting_get("duel_items") or "default:sword_steel"

local function give_items(inv)
	local items = items_to_grant:split(",")
	for _, item in ipairs(items) do
		inv:add_item("main", ItemStack(item))
	end
end

local function restore_player_inv(inv)
	local lists = inv:get_lists()
	for key,value in pairs(lists) do 
		local restore_to, count = key:gsub("_duel_backup", "")
		if count == 1 then
			print("Restoring:"..key)
			inv:set_size(key, 0)
			inv:set_list(restore_to, value)
		elseif count > 1 then
			inv:set_size(key, 0)
		end
	end
end

local function save_player_inv(inv)
	local oldlists = inv:get_lists()
	-- TODO: Figure out a better way to do this
	for key,value in pairs(oldlists) do 
		inv:set_list(key,{})
	end
	
	local newlists = inv:get_lists()
	for key,value in pairs(oldlists) do 
		newlists[key.."_duel_backup"] = value
	end
	inv:set_lists(newlists)
end

local function start_duel(player1, player2)
	-- TODO: Make this less repetative
	local inv1 = player1:get_inventory()
	local inv2 = player2:get_inventory()
	-- Save the inventory
	save_player_inv(inv1)
	save_player_inv(inv2)
	-- Give items
	give_items(inv1)
	give_items(inv2)
	-- save current pos
	duel_data[player1:get_player_name()]= {pos = player1:getpos()}
	duel_data[player2:get_player_name()]= {pos = player2:getpos()}
	-- Teleport the players
	player1:setpos(duel.pos1)
	player2:setpos(duel.pos2)
end

local function end_duel(winner, loser)
	-- inform players of the result
	for _,player in ipairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		if not (name == winner or name == loser) then
			minetest.chat_send_player(name, winner.." defeats "..loser.." in a duel!")
		end
	end
	minetest.chat_send_player(winner,"You have defeated "..loser.."!")
	minetest.chat_send_player(loser,"You have been defeated by "..winner.."!")
	-- Restore player data
	local player_winner = minetest.get_player_by_name(winner)
	local player_loser = minetest.get_player_by_name(loser)
	local inv1 = player_winner:get_inventory()
	local inv2 = player_loser:get_inventory()
	player_winner:setpos(duel_data[winner].pos)
	player_loser:setpos(duel_data[loser].pos)
	restore_player_inv(inv1)
	restore_player_inv(inv2)
	-- Clean up
	duel_data[loser] = nil
	duel_data[winner] = nil
end

function duel.challenge(challenger,challenged)
	-- Check if a duel is currently in progress
	-- TODO: Improve this
	if challenger == duel_data.challenged_name then
		duel.accept(challenger)
		return true
	end

	if duel_data.state == 1 and (minetest.get_gametime() - duel_data.time) < 60 then
		if minetest.get_player_by_name(duel_data.challenger_name) 	
				and minetest.get_player_by_name(duel_data.challenged_name) then
			return false
		end
	elseif duel_data.state == 2 then
		return false
	end
	
	-- inform other players of the duel
	for _,player in ipairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		if not (name == challenger or name == challenged) then
			minetest.chat_send_player(name,challenger.." challenges "..challenged.." to a duel!")
		end
	end
	
	duel_data.state = 1
	duel_data.time = minetest.get_gametime()
	duel_data.challenger_name = challenger
	duel_data.challenged_name = challenged
	minetest.chat_send_player(challenged,"You have been challenged to a duel by "..challenger..
			". Type /duel_accept to accept the duel")
	return true
end

function duel.accept(name)
	if duel_data.challenged_name == name and duel_data.state == 1 then
		duel_data.state = 2
		local player1 = minetest.get_player_by_name(name)
		local player2 = minetest.get_player_by_name(duel_data.challenger_name)
		start_duel(player1, player2)
		return true
	end
	return false
end

function duel.lose(name)
	if duel_data.state == 2 then
		if duel_data.challenged_name == name then
			end_duel(duel_data.challenger_name, name)
			duel_data.state = 0
			return true
		elseif  duel_data.challenger_name == name then
			end_duel(duel_data.challenged_name, name)
			duel_data.state = 0
			return true
		end
	end
	return false
end

function duel.in_duel(name)
	if duel_data.state == 2 then
		if duel_data.challenged_name == name or duel_data.challenger_name == name then
			return true
		end
	end
	return false
end

minetest.register_on_leaveplayer(function(player)
	duel.lose(player:get_player_name())
end)

-- TODO: add a way to draw, if rewards for winning are implmented
minetest.register_on_shutdown(function()
	duel.lose(duel_data.challenger_name)
end)

minetest.register_on_dieplayer(function(player)
	local name = player:get_player_name()
	if duel.in_duel(name) then
	
		-- clear inventory to prevent bones being placed
		local player_inv = player:get_inventory()
		player_inv:set_list("main", {})
		player_inv:set_list("craft", {})
		
		table.insert(duel_data.move_on_respawn,name)
		
		-- Run on the next server step to prevent items being removed by bones mod
		minetest.after(0, duel.lose, name)
	end
end)

-- Stop minetest from moving the losing player to a spawn point
minetest.register_on_respawnplayer(function(player)
	local name = player:get_player_name()
	for i,v in ipairs(duel_data.move_on_respawn) do
		if v == name then
			duel_data.move_on_respawn[i] = nil
			return true
		end
	end
end)

-- Register chat commands

dofile(modpath.."/chatcommands.lua")
if dev_mode then
	dofile(modpath.."/dev_chatcommands.lua")
end