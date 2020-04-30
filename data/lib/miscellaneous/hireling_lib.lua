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
PLAYER_HIRELINGS = {}

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
HIRELING_LAMP_ID = 34070
HIRELING_SEX = {
  FEMALE = 0,
  MALE = 1
}

HIRELING_FOODS_BOOST = {
  MAGIC = 35174,
  MELEE = 35175,
  SHIELDING = 35172,
  DISTANCE = 35173,
}

HIRELING_FOODS = { -- only the non-skill ones
  { 35176, 35177, 35178, 35179, 35180 }
}

-- TODO: fullfill this table below
HIRELING_GOODS = {
  VARIOUS = {
    {name="amphora", id=2023, buy=4},
    {name="armor rack kit", id=6114, buy=90}
  },
	EQUIPMENT = {},
	DISTANCE = {
    { name="arrow", id=2544, buy=3 },
    { name="bolt", id=2543, buy=4 },
    { name="bow", id=2456, buy=400, sell=100}
  },
	WANDS = {},
	RODS = {},
	POTIONS = {},
	RUNES = {},
	SUPPLIES = {},
	TOOLS = {},
	POSTAL = {}
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
  unlocked_outfits = {},
  cid = -1
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

function Hireling:getId()
  return self.id
end

function Hireling:getName()
  return self.name
end

function Hireling:canTalkTo(player)
  if not player then return false end

  local tile = Tile(player:getPosition())
  if not tile then return false end
  local house = tile:getHouse()
  if not house then return false end


  return house:getId() == self.house_id
end

function Hireling:getPosition()
  return Position(self.posx,self.posy, self.posz)
end

function Hireling:hasSkill(SKILL)
  local player = Player(self.player_id)
  local skills = player:getStorageValue(HIRELING_SKILL_STORAGE)
  return hasBitSet(SKILL, skills)
end

function Hireling:setCreature(cid)
  self.cid = cid
end

function Hireling:spawn()
  self.active = 1
  Game.createNpc('Hireling', self:getPosition())
end

function Hireling:returnToLamp(player_id)
  local creature = Creature(self.cid)
  local player = Player(player_id)
  local lampType = ItemType(HIRELING_LAMP_ID)

  if self:getOwnerId() ~= player_id then
    return player:sendTextMessage(MESSAGE_INFO_DESCR, "You are not the master of this hireling.")
  end

  if player:getFreeCapacity() < lampType:getWeight(1) then
    return player:sendTextMessage(MESSAGE_INFO_DESCR, "You do not have enough capacity.")
  end

  local inbox = player:getSlotItem(CONST_SLOT_STORE_INBOX)
  if not inbox or inbox:getEmptySlots() == 0 then
    player:getPosition():sendMagicEffect(CONST_ME_POFF)
    return player:sendTextMessage(MESSAGE_INFO_DESCR, "You don't have enough room in your inbox.")
  end


  local lamp = inbox:addItem(HIRELING_LAMP_ID, 1)
  creature:remove() --remove hireling
  lamp:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION, "This mysterious lamp summons your very own personal hireling.\nThis item cannot be traded.\nThis magic lamp is the home of" .. self:getName() .. ".")
  lamp:setAttribute(ITEM_ATTRIBUTE_DATE, self:getId()) --hack to keep hirelingId on item
  self.active = 0
end
-- [[ END CLASS DEFINITION ]]

-- [[ LOCAL FUNCTIONS AND UTILS ]]

local function spawnNPCs()
  print('>> Spawning Hirelings')
  local hireling
  for i=1,#HIRELINGS do
    hireling = HIRELINGS[i]
    if hireling.active ~= 0 then
      hireling:spawn()
    end
  end
end

-- [[ GLOBAL FUNCTIONS DEFINITIONS ]]

function getHirelingByPosition(position)
  local hireling
  for i = 1, #HIRELINGS do
      hireling = HIRELINGS[i]
      if hireling.posx == position.x and hireling.posy == position.y and hireling.posz == position.z then
          return hireling
      end
  end
  return nil
end

function HirelingsInit()
  local rows = db.storeQuery("SELECT * FROM `player_hirelings`")
	
	if rows then
		repeat
      local player_id = result.getNumber(rows, "player_id")

      if not PLAYER_HIRELINGS[player_id] then
        PLAYER_HIRELINGS[player_id] = {}
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
      table.insert(PLAYER_HIRELINGS[player_id], hireling)
      table.insert(HIRELINGS, hireling)
      
		until not result.next(rows)
    result.free(rows)
    
    spawnNPCs()

	end
end

function PersistHireling(hireling)
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

  local hirelings = PLAYER_HIRELINGS[hireling.player_id]
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
  return PLAYER_HIRELINGS[self:getGuid()] or {}
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

  local saved = PersistHireling(hireling)
  if not saved then
    DebugPrint('Error saving Hireling:' .. name .. ' - player:' .. self:getName())
    return nil
  else
    table.insert(PLAYER_HIRELINGS[self:getGuid()], hireling)
    table.insert(HIRELINGS, hireling)
    return hireling
  end
end
-- [[ END PLAYER EXTENSION ]]


