local BASEDIR = (...):match("(.-)[^%.]+$")

local class = require(BASEDIR .. "class")
local Types = require(BASEDIR .. "type_info")

local JuEntityManager = class("juice_entitymanager")

function JuEntityManager:init()
	self.__isEntityManager = true

	self.world = nil

	self.entities = {}

	self.point = 0

	self.size = 0
end

function JuEntityManager:setWorld(world)
	if not Types.isWorld(world) then
		Types.error(world, "world")
	end
	self.world = world or nil
end

function JuEntityManager:assignNewId()
	self.point = self.point + 1
	return self.point
end

function JuEntityManager:contains(entity)
	if not Types.isEntity(entity) then
		Types.error(entity, "entity")
	end

	if entity.id == -1 then
		return false
	end
	return self.entities[entity.id] ~= nil
end

function JuEntityManager:addEntity(entity)
	if not Types.isEntity(entity) then
		Types.error(entity, "entity")
	end

	if self.entities[entity.id] then
		error("Fail to add entity to entity manager: the entity has existed")
		return
	end
	self.size = self.size + 1
	entity:setManager(self)
	self.entities[entity.id] = entity
end

function JuEntityManager:removeEntity(entity)
	if not Types.isEntity(entity) then
		Types.error(entity, "entity")
	end

	if entity.id == -1 or self.entities[entity.id] == nil then
		error("Fail to remove entity from entity manager: the entity is not existed")
		return
	end
	self.size = self.size - 1
	self.entities[entity.id] = nil
	entity:setManager()

end

function JuEntityManager:clear()
	for _, entity in pairs(self.entities) do
		entity:setManager()
	end
	self.entities = {}
	self.point = 0
	self.size = 0
end

function JuEntityManager:getByEntityId(id)
	if self.entities[id] then
		return self.entities[id]
	end
	return nil
end

function JuEntityManager:getAllEntities()
	return self.entities
end

return JuEntityManager