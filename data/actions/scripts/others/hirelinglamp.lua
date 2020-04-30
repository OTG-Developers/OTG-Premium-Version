function onUse(player, item, fromPosition, target, toPosition, isHotkey)
	local spawnPosition = player:getPosition()
	local hireling_id = item:getSpecialAttribute(HIRELING_ATTRIBUTE)

	local hireling = getHirelingById(hireling_id)
	hireling:setPosition(spawnPosition)
	item:remove(1)
	hireling:spawn()
	spawnPosition:sendMagicEffect(CONST_ME_TELEPORT)
	return true
end
