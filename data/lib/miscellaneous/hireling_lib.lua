-- Created by Leu (jlcvp @github)
-- Date: 16/04/2020 - corona virus

--[[{name = "Banker Dress"{female = 1109, male = 1110}

{name = "Bonelord Dress"{female = 1123, male = 1124}

{name = "Cook Dress"{female = 1113, male = 1114}

{name = "Dragon Dress"{female = 1125, male = 1126}

{name = "Ferumbras Dress"{female = 1131, male = 1132}

{name = "Hydra Dress"{female = 1129, male = 1130}

{name = "Servant Dress"{female = 1117, male = 1118}

{name = "Stewart Dress"{female = 1115, male = 1116}

{name = "Trader Dress"{female = 1111, male = 1112} 
]]

DEBUG = true -- print debug to console


HIRELINGS = {}

function DebugPrint(str)
  if DEBUG == true then
    print(str)
  end
end

-- [[ DEFINING HIRELING CLASS ]]
HIRELING_SKILLS = {
  BANKER = 0,   -- 1<<0
  COOKING = 1,  -- 1<<1
  STEWARD = 2,  -- 1<<2
  TRADER = 3    -- 1<<3
}

HIRELING_SKILL_STORAGE = 28800

HIRELING_SEX = {
  FEMALE = 0,
  MALE = 1
}

Hireling = {
  id = -1,
  player_id = -1,
  name = 'hireling',
  skills = 0,
  active = 0,
  sex = 0,
  house_id = -1,
  posx = 0,
  posy = 0,
  posz = 0,
  lookbody = 34,
  lookfeet = 116,
  lookhead = 97,
  looklegs = 3,
  looktype = 0,
  unlocked_outfits = {}
}

function Hireling:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Hireling:getOwnerId()
  return self.player_id
end

function Hireling:canTalkTo(player)
  if not player then return false end

  local tile = Tile(player:getPosition())
  if not tile then return false end
  local house = tile:getHouse()
  if not house then return false end


  return house:getId() == self.house_id and house:isInvited(player)
end

function Hireling:getPosition()
  return Position(self.posx,self.posy, self.posz)
end

function Hireling:hasSkill(SKILL)
  local player = Player(self.player_id)
  local skills = player:getStorageValue(HIRELING_SKILL_STORAGE)
  return hasBitSet(SKILL, skills)
end
-- [[ END CLASS DEFINITION ]]

-- [[ GLOBAL FUNCTIONS DEFINITION ]]

function getHirelingByPosition(position)
  --TODO
end

function HirelingsInit()
  local rows = db.storeQuery("SELECT * FROM `player_hirelings`")
	
	if rows then
		repeat
			local player_id = result.getNumber(rows, "player_id")
      if not HIRELINGS[player_id] then
        HIRELINGS[player_id] = {}
      end
      
      local hireling = Hireling:new()
      hireling.id = result.getNumber(rows, "id")
      hireling.player_id = player_id
      hireling.name = result.getString(rows, "name")
      hireling.active = result.getNumber(rows, "active")
      hireling.sex = result.getNumber(rows, "sex")
      hireling.house_id = result.getNumber(rows, "house_id")
      hireling.posx = result.getNumber(rows, "posx")
      hireling.posy = result.getNumber(rows, "posy")
      hireling.posz = result.getNumber(rows, "posz")
      hireling.lookbody = result.getNumber(rows, "lookbody")
      hireling.lookfeet = result.getNumber(rows, "lookfeet")
      hireling.lookhead = result.getNumber(rows, "lookhead")
      hireling.looklegs = result.getNumber(rows, "looklegs")
      hireling.looktype = result.getNumber(rows, "looktype")
      local unlocked_outfits = result.getString(rows, "unlocked_outfits")
      if unlocked_outfits and string.len(unlocked_outfits) > 0 then
        hireling.unlocked_outfits = {}
        local outfits = string.split(';')
        for i=1,#outfits do
          local outfit = tonumber(outfits[i])
          table.insert(hireling.unlocked_outfits,outfit)
        end
      end
			table.insert(HIRELINGS[player_id], hireling)
		until not result.next(rows)

		result.free(rows)
	end
end

function SaveHireling(hireling)
  local unlocked_outfits = ""
  if #hireling.unlocked_outfits > 0 then
    for i=1,#hireling.unlocked_outfits do
      local outfit = hireling.unlocked_outfits[i]
      if i > 1 then
        unlocked_outfits = unlocked_outfits .. ';'
      end
      unlocked_outfits = unlocked_outfits .. tostring(outfit)
    end
  end

  db.query(string.format("INSERT INTO `player_hirelings` (`player_id`,`name`,`active`,`sex`,`house_id`,`posx`,`posy`,`posz`,`lookbody`,`lookfeet`,`lookhead`,`looklegs`,`looktype`,`unlocked_outfits`) VALUES (%d, %s, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %s)", 
    hireling.player_id, db.escapeString(hireling.name), hireling.active, hireling.sex, hireling.house_id, hireling.posx, hireling.posy, hireling.posz, hireling.lookbody, hireling.lookfeet, hireling.lookhead, hireling.looklegs, hireling.looktype, unlocked_outfits)
  )

  DebugPrint("hireling created, loading id from db")

  local hirelings = HIRELINGS[hireling.player_id]
  local ids = ""
  for i=1,#hirelings do
    if i > 1 then
      ids = ids .. "',"
    end
      ids = ids .. "'" ..  tostring(hireling[i].id)
  end
  local query = string.format("SELECT `id` FROM `player_hirelings` WHERE `player_id`= %d and `id` NOT IN ('%s')", hireling.player_id, ids)
  local resultId = db.storeQuery(query)

  if resultId then
    local id = result.getNumber(resultId, 'id')
    hireling.id = id
    return true
  else
    return false
  end
end



-- [[ END GLOBAL FUNCTIONS ]]

-- [[ Player extension ]]
function Player:getHirelings()
  return HIRELINGS[self:getGuid()] or {}
end

function Player:getHirelingsCount()
  local hirelings = self:getHirelings()
  return #hirelings
end

function Player:addNewHireling(name, sex)
  local hireling = Hireling:new()
  hireling.name = name
  hireling.player_id = self:getGuid()
  if sex == HIRELING_SEX.FEMALE then
    hireling.looktype=136 -- citizen female
    hireling.sex = HIRELING_SEX.FEMALE
  else
    hireling.looktype=128 -- citizen male
    hireling.sex = HIRELING_SEX.MALE
  end

  local house = self:getHouse()
  if house and house:getId() > 0 then
    hireling.house_id = house:getId()
  end

  local saved = SaveHireling(hireling)
  if not saved then
    DebugPrint('Error saving Hireling:' .. name .. ' - player:' .. self:getName())
    return nil
  else
    return hireling
  end
end
-- [[ END PLAYER EXTENSION ]]


