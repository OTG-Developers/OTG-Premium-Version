local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

local variousModule = ShopModule:new()
local variousBuyable = "amphora,2023,4,0;armor rack kit,6114,90;bamboo drawer kit,3921,20;bamboo table kit,3914,25;barrel kit,3919,12;"
local equipmentModule = ShopModule:new()
local distanceModule = ShopModule:new()
local wandsModule = ShopModule:new()
local rodsModule = ShopModule:new()
local potionsModule = ShopModule:new()
local runesModule = ShopModule:new()
local suppliesModule = ShopModule:new()
local toolsModule = ShopModule:new()
local postalModule = ShopModule:new()

local hireling = nil
local count = {} -- for banking
local transfer = {} -- for banking

--[[ str = "I sell a {selection} of {various} items, {equipment}, " .. 
			"{distance} weapons, {wands} and {rods}, {potions}, {runes}, " .. 
			"{supplies}, {tools} and {postal} goods. Just ask!" ]]

local function initShopModules()
	local shop_trade_backup = SHOP_TRADEREQUEST
	SHOP_TRADEREQUEST = {'various'}
	variousModule:parseBuyable(variousBuyable)
	npcHandler:addModule(variousModule)
	SHOP_TRADEREQUEST = shop_trade_backup

end

function onCreatureAppear(cid)
	npcHandler:onCreatureAppear(cid)
	local creature = Creature(cid)
	if not creature then return end

	local position = creature:getPosition()

	hireling = getHirelingByPosition(position)
	creature:setOutfit({ lookType=hireling.looktype,lookHead=hireling.lookhead,lookAddons=0,lookLegs=hireling.looklegs,lookBody=hireling.lookbody,lookFeet=hireling.lookfeet})

	local npc = Npc(cid)
	npc:setName(hireling.name)

	initShopModules()
end

function onCreatureDisappear(cid)		npcHandler:onCreatureDisappear(cid)			end
function onCreatureSay(cid, type, msg)		npcHandler:onCreatureSay(cid, type, msg)		end
function onThink()				npcHandler:onThink()					end

local TOPIC = {
	NONE = 1000,
	SERVICES = 1100,
	BANK = 1200,
	FOOD = 1300,
	GOODS = 1400
}

local GREETINGS = {
	BANK = "Alright! What can I do for you and your bank business, |PLAYERNAME|?",
	FOOD = "Hmm, yes! A variety of fine food awaits! However, a small expense of 15000 gold is expected to make these delicious masterpieces happen. Shall I?",
	STASH = "Of course, here is your stash! Well-maintained and neatly sorted for your convenience!",
	GOODS = ""
}

local function setTopic(cid, topic) 
	npcHandler.topic[cid] = topic
end

local function getHirelingSkills()

	if not player then return {} end

	local skillStorage = player:getStorageValue(HIRELING_SKILL_STORAGE)
	local skills = {}
	if hasBitSet(HIRELING_SKILLS.BANKER, skillStorage) then
		table.insert(skills,HIRELING_SKILLS.BANKER)
	end
	if hasBitSet(HIRELING_SKILLS.COOKING, skillStorage) then
		table.insert(skills,HIRELING_SKILLS.COOKING)
	end
	if hasBitSet(HIRELING_SKILLS.STEWARD, skillStorage) then
		table.insert(skills,HIRELING_SKILLS.STEWARD)
	end
	-- ignoring trader skills as it shows the same message about {goods}
	return skills
end

local function getHirelingServiceString()
	local skills = getHirelingSkills()
	local str = "Do you want to see my {goods}"

	for i=1,#skills do
		if i == #skills then
			str = str .. ' or '
		else
			str = str .. ', '
		end

		if skills[i]== HIRELING_SKILLS.BANKER then
			str = str .. 'to access your {bank} account' -- TODO: this setence is not official
		elseif skills[i]== HIRELING_SKILLS.COOKING then
			str = str .. 'to order {food}'
		elseif skills[i]== HIRELING_SKILLS.STEWARD then
			str = str .. 'to open your {stash}'
		end
	end
	str = str .. "?"
	return str
end

local function getTopic(cid) 
	return npcHandler.topic[cid]
end

local function sendSkillNotLearned(cid, SKILL)
	local message = "Sorry, but I do not have mastery in this skill yet."
	local profession
	if SKILL == HIRELING_SKILLS.BANKER then 
		profession = "banker"
	elseif SKILL == HIRELING_SKILLS.COOKING then
		profession = "cooker"

	elseif SKILL == HIRELING_SKILLS.STEWARD then
		profession = "steward"
	elseif SKILL == HIRELING_SKILLS.TRADER then
		profession = "trader"
	end 

	if profession then
		message = string.format("I'm not a %s and would not know how to help you with that, sorry. I can start a %s apprenticeship if you buy it for me in the store!", profession, profession)
	end

	npcHandler:say(message, cid)
end

local function openPlayerStash(cid)
	local player = Player(cid)
	if not player then return end
	local client = player:getClient()
	if client.os == CLIENTOS_NEW_WINDOWS and client.version >= 1180 then
		SupplyStash.sendOpenWindow(player)
	else
		player:sendCancelMessage("You must use a newer client to open the supply stash")
		player:getPosition():sendMagicEffect(CONST_ME_POFF)
	end
end

-- ----------------------[[ BANKING FUNCTIONS ]] ------------------------------
-------------------------------- guild bank -----------------------------------------------
local receiptFormat = 'Date: %s\nType: %s\nGold Amount: %d\nReceipt Owner: %s\nRecipient: %s\n\n%s'
local function getReceipt(info)
	local receipt = Game.createItem(info.success and 24301 or 24302)
	receipt:setAttribute(ITEM_ATTRIBUTE_TEXT, receiptFormat:format(os.date('%d. %b %Y - %H:%M:%S'), info.type, info.amount, info.owner, info.recipient, info.message))

	return receipt
end

local function getGuildIdByName(name, func)
	db.asyncStoreQuery('SELECT `id` FROM `guilds` WHERE `name` = ' .. db.escapeString(name),
		function(resultId)
			if resultId then
				func(result.getNumber(resultId, 'id'))
				result.free(resultId)
			else
				func(nil)
			end
		end
	)
end

local function getGuildBalance(id)
	local guild = Guild(id)
	if guild then
		return guild:getBankBalance()
	else
		local balance
		local resultId = db.storeQuery('SELECT `balance` FROM `guilds` WHERE `id` = ' .. id)
		if resultId then
			balance = result.getNumber(resultId, 'balance')
			result.free(resultId)
		end

		return balance
	end
end

local function setGuildBalance(id, balance)
	local guild = Guild(id)
	if guild then
		guild:setBankBalance(balance)
	else
		db.query('UPDATE `guilds` SET `balance` = ' .. balance .. ' WHERE `id` = ' .. id)
	end
end

local function transferFactory(playerName, amount, fromGuildId, info)
	return function(toGuildId)
		if not toGuildId then
			local player = Player(playerName)
			if player then
				info.success = false
				info.message = 'We are sorry to inform you that we could not fulfil your request, because we could not find the recipient guild.'
				local inbox = player:getInbox()
				local receipt = getReceipt(info)
				inbox:addItemEx(receipt, INDEX_WHEREEVER, FLAG_NOLIMIT)
			end
		else
			local fromBalance = getGuildBalance(fromGuildId)
			if fromBalance < amount then
				info.success = false
				info.message = 'We are sorry to inform you that we could not fulfill your request, due to a lack of the required sum on your guild account.'
			else
				info.success = true
				info.message = 'We are happy to inform you that your transfer request was successfully carried out.'
				setGuildBalance(fromGuildId, fromBalance - amount)
				setGuildBalance(toGuildId, getGuildBalance(toGuildId) + amount)
			end

			local player = Player(playerName)
			if player then
				local inbox = player:getInbox()
				local receipt = getReceipt(info)
				inbox:addItemEx(receipt, INDEX_WHEREEVER, FLAG_NOLIMIT)
			end
		end
	end
end
--------------------------------end guild bank-----------------------------------------------
local function handleBankActions(cid, msg)
	local player = Player(cid)
---------------------------- help ------------------------
	if msgcontains(msg, 'bank account') then
		npcHandler:say({
			'Every citizen has one. The big advantage is that you can access your money in every branch of the Global Bank! ...',
			'Would you like to know more about the {basic} functions of your bank account, the {advanced} functions, or are you already bored, perhaps?'
		}, cid)
		npcHandler.topic[cid] = 1200
		return true
---------------------------- balance ---------------------
--------------------------------guild bank-----------------------------------------------
	elseif msgcontains(msg, 'guild balance') then
		npcHandler.topic[cid] = 1200
		if not player:getGuild() then
			npcHandler:say('You are not a member of a guild.', cid)
			return false
		end
		npcHandler:say('Your guild account balance is ' .. player:getGuild():getBankBalance() .. ' gold.', cid)
		return true
--------------------------------guild bank-----------------------------------------------
	elseif msgcontains(msg, 'balance') then
		npcHandler.topic[cid] = 1200
		if player:getBankBalance() >= 100000000 then
			npcHandler:say('I think you must be one of the richest inhabitants in the world! Your account balance is ' .. player:getBankBalance() .. ' gold.', cid)
			return true
		elseif player:getBankBalance() >= 10000000 then
			npcHandler:say('You have made ten millions and it still grows! Your account balance is ' .. player:getBankBalance() .. ' gold.', cid)
			return true
		elseif player:getBankBalance() >= 1000000 then
			npcHandler:say('Wow, you have reached the magic number of a million gp!!! Your account balance is ' .. player:getBankBalance() .. ' gold!', cid)
			return true
		elseif player:getBankBalance() >= 100000 then
			npcHandler:say('You certainly have made a pretty penny. Your account balance is ' .. player:getBankBalance() .. ' gold.', cid)
			return true
		else
			npcHandler:say('Your account balance is ' .. player:getBankBalance() .. ' gold.', cid)
			return true
		end
---------------------------- deposit ---------------------
--------------------------------guild bank-----------------------------------------------
	elseif msgcontains(msg, 'guild deposit') then
		if not player:getGuild() then
			npcHandler:say('You are not a member of a guild.', cid)
			npcHandler.topic[cid] = 1200
			return false
		end
	   -- count[cid] = player:getMoney()
	   -- if count[cid] < 1 then
		   -- npcHandler:say('You do not have enough gold.', cid)
		   -- npcHandler.topic[cid] = 1200
		   -- return false
		--end
		if string.match(msg, '%d+') then
			count[cid] = getMoneyCount(msg)
			if count[cid] < 1 then
				npcHandler:say('You do not have enough gold.', cid)
				npcHandler.topic[cid] = 1200
				return false
			end
			npcHandler:say('Would you really like to deposit ' .. count[cid] .. ' gold to your {guild account}?', cid)
			npcHandler.topic[cid] = 1223
			return true
		else
			npcHandler:say('Please tell me how much gold it is you would like to deposit.', cid)
			npcHandler.topic[cid] = 1222
			return true
		end
	elseif npcHandler.topic[cid] == 1222 then
		count[cid] = getMoneyCount(msg)
		if isValidMoney(count[cid]) then
			npcHandler:say('Would you really like to deposit ' .. count[cid] .. ' gold to your {guild account}?', cid)
			npcHandler.topic[cid] = 1223
			return true
		else
			npcHandler:say('You do not have enough gold.', cid)
			npcHandler.topic[cid] = 1200
			return true
		end
	elseif npcHandler.topic[cid] == 1223 then
		if msgcontains(msg, 'yes') then
			npcHandler:say('Alright, we have placed an order to deposit the amount of ' .. count[cid] .. ' gold to your guild account. Please check your inbox for confirmation.', cid)
			local guild = player:getGuild()
			local info = {
				type = 'Guild Deposit',
				amount = count[cid],
				owner = player:getName() .. ' of ' .. guild:getName(),
				recipient = guild:getName()
			}
			local playerBalance = player:getBankBalance()
			if playerBalance < tonumber(count[cid]) then
				info.message = 'We are sorry to inform you that we could not fulfill your request, due to a lack of the required sum on your bank account.'
				info.success = false
			else
				info.message = 'We are happy to inform you that your transfer request was successfully carried out.'
				info.success = true
				guild:setBankBalance(guild:getBankBalance() + tonumber(count[cid]))
				player:setBankBalance(playerBalance - tonumber(count[cid]))
			end

			local inbox = player:getInbox()
			local receipt = getReceipt(info)
			inbox:addItemEx(receipt, INDEX_WHEREEVER, FLAG_NOLIMIT)
		elseif msgcontains(msg, 'no') then
			npcHandler:say('As you wish. Is there something else I can do for you?', cid)
		end
		npcHandler.topic[cid] = 1200
		return true
--------------------------------guild bank-----------------------------------------------
	elseif msgcontains(msg, 'deposit') then
		count[cid] = player:getMoney()
		if count[cid] < 1 then
			npcHandler:say('You do not have enough gold.', cid)
			npcHandler.topic[cid] = 1200
			return false
		end
		if msgcontains(msg, 'all') then
			count[cid] = player:getMoney()
			npcHandler:say('Would you really like to deposit ' .. count[cid] .. ' gold?', cid)
			npcHandler.topic[cid] = 1202
			return true
		else
			if string.match(msg,'%d+') then
				count[cid] = getMoneyCount(msg)
				if count[cid] < 1 then
					npcHandler:say('You do not have enough gold.', cid)
					npcHandler.topic[cid] = 1200
					return false
				end
				npcHandler:say('Would you really like to deposit ' .. count[cid] .. ' gold?', cid)
				npcHandler.topic[cid] = 1202
				return true
			else
				npcHandler:say('Please tell me how much gold it is you would like to deposit.', cid)
				npcHandler.topic[cid] = 1201
				return true
			end
		end
		if not isValidMoney(count[cid]) then
			npcHandler:say('Sorry, but you can\'t deposit that much.', cid)
			npcHandler.topic[cid] = 1200
			return false
		end
	elseif npcHandler.topic[cid] == 1201 then
		count[cid] = getMoneyCount(msg)
		if isValidMoney(count[cid]) then
			npcHandler:say('Would you really like to deposit ' .. count[cid] .. ' gold?', cid)
			npcHandler.topic[cid] = 1202
			return true
		else
			npcHandler:say('You do not have enough gold.', cid)
			npcHandler.topic[cid] = 1200
			return true
		end
	elseif npcHandler.topic[cid] == 1202 then
		if msgcontains(msg, 'yes') then
			if player:depositMoney(count[cid]) then
				npcHandler:say('Alright, we have added the amount of ' .. count[cid] .. ' gold to your {balance}. You can {withdraw} your money anytime you want to.', cid)
			else
				npcHandler:say('You do not have enough gold.', cid)
			end
		elseif msgcontains(msg, 'no') then
			npcHandler:say('As you wish. Is there something else I can do for you?', cid)
		end
		npcHandler.topic[cid] = 1200
		return true
---------------------------- withdraw --------------------
--------------------------------guild bank-----------------------------------------------
	elseif msgcontains(msg, 'guild withdraw') then
		if not player:getGuild() then
			npcHandler:say('I am sorry but it seems you are currently not in any guild.', cid)
			npcHandler.topic[cid] = 1200
			return false
		elseif player:getGuildLevel() < 2 then
			npcHandler:say('Only guild leaders or vice leaders can withdraw money from the guild account.', cid)
			npcHandler.topic[cid] = 1200
			return false
		end

		if string.match(msg,'%d+') then
			count[cid] = getMoneyCount(msg)
			if isValidMoney(count[cid]) then
				npcHandler:say('Are you sure you wish to withdraw ' .. count[cid] .. ' gold from your guild account?', cid)
				npcHandler.topic[cid] = 1225
			else
				npcHandler:say('There is not enough gold on your guild account.', cid)
				npcHandler.topic[cid] = 1200
			end
			return true
		else
			npcHandler:say('Please tell me how much gold you would like to withdraw from your guild account.', cid)
			npcHandler.topic[cid] = 1224
			return true
		end
	elseif npcHandler.topic[cid] == 1224 then
		count[cid] = getMoneyCount(msg)
		if isValidMoney(count[cid]) then
			npcHandler:say('Are you sure you wish to withdraw ' .. count[cid] .. ' gold from your guild account?', cid)
			npcHandler.topic[cid] = 1225
		else
			npcHandler:say('There is not enough gold on your guild account.', cid)
			npcHandler.topic[cid] = 1200
		end
		return true
	elseif npcHandler.topic[cid] == 1225 then
		if msgcontains(msg, 'yes') then
			local guild = player:getGuild()
			local balance = guild:getBankBalance()
			npcHandler:say('We placed an order to withdraw ' .. count[cid] .. ' gold from your guild account. Please check your inbox for confirmation.', cid)
			local info = {
				type = 'Guild Withdraw',
				amount = count[cid],
				owner = player:getName() .. ' of ' .. guild:getName(),
				recipient = player:getName()
			}
			if balance < tonumber(count[cid]) then
				info.message = 'We are sorry to inform you that we could not fulfill your request, due to a lack of the required sum on your guild account.'
				info.success = false
			else
				info.message = 'We are happy to inform you that your transfer request was successfully carried out.'
				info.success = true
				guild:setBankBalance(balance - tonumber(count[cid]))
				local playerBalance = player:getBankBalance()
				player:setBankBalance(playerBalance + tonumber(count[cid]))
			end

			local inbox = player:getInbox()
			local receipt = getReceipt(info)
			inbox:addItemEx(receipt, INDEX_WHEREEVER, FLAG_NOLIMIT)
			npcHandler.topic[cid] = 1200
		elseif msgcontains(msg, 'no') then
			npcHandler:say('As you wish. Is there something else I can do for you?', cid)
			npcHandler.topic[cid] = 1200
		end
		return true
--------------------------------guild bank-----------------------------------------------
	elseif msgcontains(msg, 'withdraw') then
		if string.match(msg,'%d+') then
			count[cid] = getMoneyCount(msg)
			if isValidMoney(count[cid]) then
				npcHandler:say('Are you sure you wish to withdraw ' .. count[cid] .. ' gold from your bank account?', cid)
				npcHandler.topic[cid] = 1207
			else
				npcHandler:say('There is not enough gold on your account.', cid)
				npcHandler.topic[cid] = 1200
			end
			return true
		else
			npcHandler:say('Please tell me how much gold you would like to withdraw.', cid)
			npcHandler.topic[cid] = 1206
			return true
		end
	elseif npcHandler.topic[cid] == 1206 then
		count[cid] = getMoneyCount(msg)
		if isValidMoney(count[cid]) then
			npcHandler:say('Are you sure you wish to withdraw ' .. count[cid] .. ' gold from your bank account?', cid)
			npcHandler.topic[cid] = 1207
		else
			npcHandler:say('There is not enough gold on your account.', cid)
			npcHandler.topic[cid] = 1200
		end
		return true
	elseif npcHandler.topic[cid] == 1207 then
		if msgcontains(msg, 'yes') then
			if player:getFreeCapacity() >= getMoneyWeight(count[cid]) then
				if not player:withdrawMoney(count[cid]) then
					npcHandler:say('There is not enough gold on your account.', cid)
				else
					npcHandler:say('Here you are, ' .. count[cid] .. ' gold. Please let me know if there is something else I can do for you.', cid)
				end
			else
				npcHandler:say('Whoah, hold on, you have no room in your inventory to carry all those coins. I don\'t want you to drop it on the floor, maybe come back with a cart!', cid)
			end
			npcHandler.topic[cid] = 1200
		elseif msgcontains(msg, 'no') then
			npcHandler:say('The customer is king! Come back anytime you want to if you wish to {withdraw} your money.', cid)
			npcHandler.topic[cid] = 1200
		end
		return true
---------------------------- transfer --------------------
--------------------------------guild bank-----------------------------------------------
	elseif msgcontains(msg, 'guild transfer') then
		if not player:getGuild() then
			npcHandler:say('I am sorry but it seems you are currently not in any guild.', cid)
			npcHandler.topic[cid] = 1200
			return false
		elseif player:getGuildLevel() < 2 then
			npcHandler:say('Only guild leaders or vice leaders can transfer money from the guild account.', cid)
			npcHandler.topic[cid] = 1200
			return false
		end

		if string.match(msg, '%d+') then
			count[cid] = getMoneyCount(msg)
			if isValidMoney(count[cid]) then
				transfer[cid] = string.match(msg, 'to%s*(.+)$')
				if transfer[cid] then
					npcHandler:say('So you would like to transfer ' .. count[cid] .. ' gold from your guild account to guild ' .. transfer[cid] .. '?', cid)
					npcHandler.topic[cid] = 1228
				else
					npcHandler:say('Which guild would you like to transfer ' .. count[cid] .. ' gold to?', cid)
					npcHandler.topic[cid] = 1227
				end
			else
				npcHandler:say('There is not enough gold on your guild account.', cid)
				npcHandler.topic[cid] = 1200
			end
		else
			npcHandler:say('Please tell me the amount of gold you would like to transfer.', cid)
			npcHandler.topic[cid] = 1226
		end
		return true
	elseif npcHandler.topic[cid] == 1226 then
		count[cid] = getMoneyCount(msg)
		if player:getGuild():getBankBalance() < count[cid] then
			npcHandler:say('There is not enough gold on your guild account.', cid)
			npcHandler.topic[cid] = 1200
			return true
		end
		if isValidMoney(count[cid]) then
			npcHandler:say('Which guild would you like to transfer ' .. count[cid] .. ' gold to?', cid)
			npcHandler.topic[cid] = 1227
		else
			npcHandler:say('There is not enough gold on your account.', cid)
			npcHandler.topic[cid] = 1200
		end
		return true
	elseif npcHandler.topic[cid] == 1227 then
		transfer[cid] = msg
		if player:getGuild():getName() == transfer[cid] then
			npcHandler:say('Fill in this field with person who receives your gold!', cid)
			npcHandler.topic[cid] = 1200
			return true
		end
		npcHandler:say('So you would like to transfer ' .. count[cid] .. ' gold from your guild account to guild ' .. transfer[cid] .. '?', cid)
		npcHandler.topic[cid] = 1228
		return true
	elseif npcHandler.topic[cid] == 1228 then
		if msgcontains(msg, 'yes') then
			npcHandler:say('We have placed an order to transfer ' .. count[cid] .. ' gold from your guild account to guild ' .. transfer[cid] .. '. Please check your inbox for confirmation.', cid)
			local guild = player:getGuild()
			local balance = guild:getBankBalance()
			local info = {
				type = 'Guild to Guild Transfer',
				amount = count[cid],
				owner = player:getName() .. ' of ' .. guild:getName(),
				recipient = transfer[cid]
			}
			if balance < tonumber(count[cid]) then
				info.message = 'We are sorry to inform you that we could not fulfill your request, due to a lack of the required sum on your guild account.'
				info.success = false
				local inbox = player:getInbox()
				local receipt = getReceipt(info)
				inbox:addItemEx(receipt, INDEX_WHEREEVER, FLAG_NOLIMIT)
			else
				getGuildIdByName(transfer[cid], transferFactory(player:getName(), tonumber(count[cid]), guild:getId(), info))
			end
			npcHandler.topic[cid] = 1200
		elseif msgcontains(msg, 'no') then
			npcHandler:say('Alright, is there something else I can do for you?', cid)
		end
		npcHandler.topic[cid] = 1200
--------------------------------guild bank-----------------------------------------------
	elseif msgcontains(msg, 'transfer') then
		npcHandler:say('Please tell me the amount of gold you would like to transfer.', cid)
		npcHandler.topic[cid] = 1211
	elseif npcHandler.topic[cid] == 1211 then
		count[cid] = getMoneyCount(msg)
		if player:getBankBalance() < count[cid] then
			npcHandler:say('There is not enough gold on your account.', cid)
			npcHandler.topic[cid] = 1200
			return true
		end
		if isValidMoney(count[cid]) then
			npcHandler:say('Who would you like transfer ' .. count[cid] .. ' gold to?', cid)
			npcHandler.topic[cid] = 1212
		else
			npcHandler:say('There is not enough gold on your account.', cid)
			npcHandler.topic[cid] = 1200
		end
	elseif npcHandler.topic[cid] == 1212 then
		transfer[cid] = msg
		if player:getName() == transfer[cid] then
			npcHandler:say('Fill in this field with person who receives your gold!', cid)
			npcHandler.topic[cid] = 1200
			return true
		end
		if playerExists(transfer[cid]) then
		local arrayDenied = {"accountmanager", "rooksample", "druidsample", "sorcerersample", "knightsample", "paladinsample"}
			if isInArray(arrayDenied, string.gsub(transfer[cid]:lower(), " ", "")) then
				npcHandler:say('This player does not exist.', cid)
				npcHandler.topic[cid] = 1200
				return true
			end
			npcHandler:say('So you would like to transfer ' .. count[cid] .. ' gold to ' .. transfer[cid] .. '?', cid)
			npcHandler.topic[cid] = 1213
		else
			npcHandler:say('This player does not exist.', cid)
			npcHandler.topic[cid] = 1200
		end
	elseif npcHandler.topic[cid] == 1213 then
		if msgcontains(msg, 'yes') then
			if not player:transferMoneyTo(transfer[cid], count[cid]) then
				npcHandler:say('You cannot transfer money to this account.', cid)
			else
				npcHandler:say('Very well. You have transferred ' .. count[cid] .. ' gold to ' .. transfer[cid] ..'.', cid)
				transfer[cid] = nil
			end
		elseif msgcontains(msg, 'no') then
			npcHandler:say('Alright, is there something else I can do for you?', cid)
		end
		npcHandler.topic[cid] = 1200
---------------------------- money exchange --------------
	elseif msgcontains(msg, 'change gold') then
		npcHandler:say('How many platinum coins would you like to get?', cid)
		npcHandler.topic[cid] = 1214
	elseif npcHandler.topic[cid] == 1214 then
		if getMoneyCount(msg) < 1 then
			npcHandler:say('Sorry, you do not have enough gold coins.', cid)
			npcHandler.topic[cid] = 1200
		else
			count[cid] = getMoneyCount(msg)
			npcHandler:say('So you would like me to change ' .. count[cid] * 100 .. ' of your gold coins into ' .. count[cid] .. ' platinum coins?', cid)
			npcHandler.topic[cid] = 1215
		end
	elseif npcHandler.topic[cid] == 1215 then
		if msgcontains(msg, 'yes') then
			if player:removeItem(2148, count[cid] * 100) then
				player:addItem(2152, count[cid])
				npcHandler:say('Here you are.', cid)
			else
				npcHandler:say('Sorry, you do not have enough gold coins.', cid)
			end
		else
			npcHandler:say('Well, can I help you with something else?', cid)
		end
		npcHandler.topic[cid] = 1200
	elseif msgcontains(msg, 'change platinum') then
		npcHandler:say('Would you like to change your platinum coins into gold or crystal?', cid)
		npcHandler.topic[cid] = 1216
	elseif npcHandler.topic[cid] == 1216 then
		if msgcontains(msg, 'gold') then
			npcHandler:say('How many platinum coins would you like to change into gold?', cid)
			npcHandler.topic[cid] = 1217
		elseif msgcontains(msg, 'crystal') then
			npcHandler:say('How many crystal coins would you like to get?', cid)
			npcHandler.topic[cid] = 1219
		else
			npcHandler:say('Well, can I help you with something else?', cid)
			npcHandler.topic[cid] = 1200
		end
	elseif npcHandler.topic[cid] == 1217 then
		if getMoneyCount(msg) < 1 then
			npcHandler:say('Sorry, you do not have enough platinum coins.', cid)
			npcHandler.topic[cid] = 1200
		else
			count[cid] = getMoneyCount(msg)
			npcHandler:say('So you would like me to change ' .. count[cid] .. ' of your platinum coins into ' .. count[cid] * 100 .. ' gold coins for you?', cid)
			npcHandler.topic[cid] = 1218
		end
	elseif npcHandler.topic[cid] == 1218 then
		if msgcontains(msg, 'yes') then
			if player:removeItem(2152, count[cid]) then
				player:addItem(2148, count[cid] * 100)
				npcHandler:say('Here you are.', cid)
			else
				npcHandler:say('Sorry, you do not have enough platinum coins.', cid)
			end
		else
			npcHandler:say('Well, can I help you with something else?', cid)
		end
		npcHandler.topic[cid] = 1200
	elseif npcHandler.topic[cid] == 1219 then
		if getMoneyCount(msg) < 1 then
			npcHandler:say('Sorry, you do not have enough platinum coins.', cid)
			npcHandler.topic[cid] = 1200
		else
			count[cid] = getMoneyCount(msg)
			npcHandler:say('So you would like me to change ' .. count[cid] * 100 .. ' of your platinum coins into ' .. count[cid] .. ' crystal coins for you?', cid)
			npcHandler.topic[cid] = 1220
		end
	elseif npcHandler.topic[cid] == 1220 then
		if msgcontains(msg, 'yes') then
			if player:removeItem(2152, count[cid] * 100) then
				player:addItem(2160, count[cid])
				npcHandler:say('Here you are.', cid)
			else
				npcHandler:say('Sorry, you do not have enough platinum coins.', cid)
			end
		else
			npcHandler:say('Well, can I help you with something else?', cid)
		end
		npcHandler.topic[cid] = 1200
	elseif msgcontains(msg, 'change crystal') then
		npcHandler:say('How many crystal coins would you like to change into platinum?', cid)
		npcHandler.topic[cid] = 1221
	elseif npcHandler.topic[cid] == 1221 then
		if getMoneyCount(msg) < 1 then
			npcHandler:say('Sorry, you do not have enough crystal coins.', cid)
			npcHandler.topic[cid] = 1200
		else
			count[cid] = getMoneyCount(msg)
			npcHandler:say('So you would like me to change ' .. count[cid] .. ' of your crystal coins into ' .. count[cid] * 100 .. ' platinum coins for you?', cid)
			npcHandler.topic[cid] = 1222
		end
	elseif npcHandler.topic[cid] == 1222 then
		if msgcontains(msg, 'yes') then
			if player:removeItem(2160, count[cid])  then
				player:addItem(2152, count[cid] * 100)
				npcHandler:say('Here you are.', cid)
			else
				npcHandler:say('Sorry, you do not have enough crystal coins.', cid)
			end
		else
			npcHandler:say('Well, can I help you with something else?', cid)
		end
		npcHandler.topic[cid] = 1200
	elseif msgcontains(msg, 'money') then
		npcHandler:say('We can {change} money for you. You can also access your {bank account}.', cid)
	elseif msgcontains(msg, 'change') then
		npcHandler:say('There are three different coin types in Global Bank: 100 gold coins equal 1 platinum coin, 100 platinum coins equal 1 crystal coin. So if you\'d like to change 100 gold into 1 platinum, simply say \'{change gold}\' and then \'1 platinum\'.', cid)
	elseif msgcontains(msg, 'bank') then
		npcHandler:say('We can {change} money for you. You can also access your {bank account}.', cid)
	elseif msgcontains(msg, 'advanced') then
		npcHandler:say('Your bank account will be used automatically when you want to {rent} a house or place an offer on an item on the {market}. Let me know if you want to know about how either one works.', cid)
	elseif msgcontains(msg, 'help') then
		npcHandler:say('You can check the {balance} of your bank account, {deposit} money or {withdraw} it. You can also {transfer} money to other characters, provided that they have a vocation.', cid)
	elseif msgcontains(msg, 'functions') then
		npcHandler:say('You can check the {balance} of your bank account, {deposit} money or {withdraw} it. You can also {transfer} money to other characters, provided that they have a vocation.', cid)
	elseif msgcontains(msg, 'basic') then
		npcHandler:say('You can check the {balance} of your bank account, {deposit} money or {withdraw} it. You can also {transfer} money to other characters, provided that they have a vocation.', cid)
	elseif msgcontains(msg, 'job') then
		npcHandler:say('I work in this house. I can change money for you and help you with your bank account.', cid)
	end
	return true
end
-- ======================[[ END BANKING FUNCTIONS ]] ======================== --

-- ========================[[ TRADER FUNCTIONS ]] ========================== --
local function getGoodsMessage()
	local str
	if not hireling:hasSkill(HIRELING_SKILLS.TRADER) then
		str = "While I'm not a trader, I still have a collection of {various} items to sell if you like!"
	else
		str = "I sell a {selection} of {various} items, {equipment}, " .. 
			"{distance} weapons, {wands} and {rods}, {potions}, {runes}, " .. 
			"{supplies}, {tools} and {postal} goods. Just ask!"
	end
	return str
end

local function handleGoodsActions(cid, msg)
	local player = Player(cid)

	if msgcontains(msg, "various") then
		local shopModule = ShopModule:new()

	end
end
-- ======================[[ END TRADER FUNCTIONS ]] ======================== --


local function creatureSayCallback(cid, type, msg)
	if (not npcHandler:isFocused(cid)) then
		return false
	end

	--TODO validate if user is inside the same house as the hireling

	if(msgcontains(msg, "service")) then
		setTopic(cid,TOPIC.SERVICES)
		local servicesMsg = getHirelingServiceString()
		npcHandler:say(servicesMsg, cid)
	elseif(getTopic(cid) == TOPIC.SERVICES) then
		if msgcontains(msg, "bank") then
			if hireling:hasSkill(HIRELING_SKILLS.BANKER) then
				setTopic(cid, TOPIC.BANK)
				count[cid], transfer[cid] = nil, nil
				npcHandler:say(GREETING.BANK, cid)
			else
				sendSkillNotLearned(cid, HIRELING_SKILLS.BANKER)
			end
		elseif msgcontains(msg, "food") then
			if hireling:hasSkill(HIRELING_SKILLS.COOKING) then
				setTopic(cid, TOPIC.FOOD)
				npcHandler:say(GREETING.FOOD, cid)
			else
				sendSkillNotLearned(cid, HIRELING_SKILLS.COOKING)
			end
		elseif msgcontains(msg, "stash") then
			if hireling:hasSkill(HIRELING_SKILLS.STEWARD) then
				setTopic(cid, TOPIC.NONE)
				npcHandler:say(GREETINGS.STASH, cid)
				openPlayerStash(cid)
			else
				sendSkillNotLearned(cid, HIRELING_SKILLS.STEWARD)
			end
		elseif msgcontains(msg, "goods") then
			setTopic(cid, TOPIC.GOODS)
			local goodsMsg = getGoodsMessage()
			npcHandler:say(goodsMsg, cid)
		end
	elseif(getTopic(cid) == TOPIC.BANK) then
		handleBankActions(cid, msg)
	elseif(getTopic(cid) == TOPIC.GOODS) then
		handleGoodsActions(cid, msg)
	end
	return true
end

npcHandler:setMessage(MESSAGE_GREET, "It is good to see you. I'm always at your {service}")
npcHandler:setMessage(MESSAGE_FAREWELL, "Farewell, |PLAYERNAME|, may the winds guide your way.")
npcHandler:setMessage(MESSAGE_WALKAWAY, "Come back soon!")
npcHandler:setMessage(MESSAGE_SENDTRADE, "Take all the time you need to decide what you want!")

local function onTradeRequest(cid)
	if Player(cid):getStorageValue(Storage.TravellingTrader.Mission07) ~= 1 then
		npcHandler:say('Sorry, but you do not belong to my exclusive customers. I have to make sure that I can trust in the quality of your wares.', cid)
		return false
	end

	return true
end

-- npcHandler:setCallback(CALLBACK_ONTRADEREQUEST, onTradeRequest)
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
