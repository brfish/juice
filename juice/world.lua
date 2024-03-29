local BASEDIR = (...):match("(.-)[^%.]+$")
local class = require(BASEDIR .. "class")

local ComponentsPool = require(BASEDIR .. "component").Pool

local EntityManager = require(BASEDIR .. "entity_manager")
local EventManager = require(BASEDIR .. "event_manager")

local BuiltinEvents = require(BASEDIR .. "builtin_events")

local Types = require(BASEDIR .. "type_info")

local JuWorld = class("juice_world")

function JuWorld:init()
	self.__isWorld = true

	self.componentsPool = ComponentsPool.new()

	self.entityManager = EntityManager.new()
	self.entityManager:setWorld(self)

	self.eventManager = EventManager.new()
	self.eventManager:setWorld(self)
	
	self.systems = {}
	self.registeredSystems = {}

	self.eventManagerOptions = {
		event_entity_added_enable = false,
		event_entity_removed_enable = false,
		event_component_added_enable = false,
		event_component_removed_enable = false,
		event_system_added_enable = false,
		event_system_removed_enable = false,
		event_system_loaded_enable = false,
		event_system_stopped_enable = false,
		event_system_started_enable = false
	}
end

function JuWorld:setEntityManager(entityManager)
	if not Types.isEntityManager(entityManager) then
		Types.error(entityManager, "entitymanager")
	end
	self.entityManager = entityManager
end

function JuWorld:setEventManager(eventManager)
	if not Types.isEventManager(eventManager) then
		Types.error(eventManager, "eventmanager")
	end
	self.eventManager = eventManager
end

function JuWorld:addEntity(entity)
	if not Types.isEntity(entity) then
		Types.error(entity, "entity")
	end

	self.entityManager:addEntity(entity)

	for _, callback in pairs(self.systems) do
		for __, system in pairs(callback.objects) do
			if system:eligible(entity) then
				system:addEntity(entity)
				if self.eventManagerOptions.event_entity_added_enable then
					self.eventManager:queueEvent(
						BuiltinEvents.EVENT_ENTITY_ADDED.new(system, entity))
				end
			end
		end
	end

	return entity
end

function JuWorld:removeEntity(entity)
	if not Types.isEntity(entity) then
		Types.error(entity, "entity") 
	end

	for _, callback in pairs(self.systems) do
		for __, system in pairs(callback.objects) do
			system:removeEntity(entity)
			if self.eventManagerOptions.event_entity_removed_enable then
				self.eventManager:queueEvent(
					BuiltinEvents.EVENT_ENTITY_REMOVED.new(system, entity))
			end
		end
	end
	
	self.entityManager:removeEntity(entity)
end

function JuWorld:addSystem(system, callback)
	if not Types.isSystem(system) then
		Types.error(system, "system")
	end

	callback = callback or "NULL"

	local name = system.__cname

	if not self.registeredSystems[name] then
		self.registeredSystems[name] = {}
	end

	if self.registeredSystems[name][callback] then
		error("Fail to add system to the world: the system " .. name .. " has existed")
		return
	end

	if callback ~= "NULL" and not system[callback] then
		error("Fail to add system to the world: the system is without the designative callback function")
		return
	end

	system:setWorld(self)

	if not self.systems[callback] then
		self.systems[callback] = {point = 0, objects = {}, size = 0}
	end

	self.systems[callback].point = self.systems[callback].point + 1
	local point = self.systems[callback].point
	self.systems[callback].objects[point] = system
	self.registeredSystems[name][callback] = point

	if self.eventManagerOptions.event_system_added_enable then
		self.eventManager:queueEvent(
			BuiltinEvents.EVENT_SYSTEM_ADDED.new(self, system, callback))
	end

	local entities = self.entityManager:getAllEntities()
	for _, entity in pairs(entities) do
		if system:eligible(entity) then
			system:addEntity(entity)
		end
	end

	if system["load"] and type(system["load"]) == "function" then
		system:load(system)
		if self.eventManagerOptions.event_system_loaded_enable then
			self.eventManager:queueEvent(
				BuiltinEvents.EVENT_SYSTEM_LOADED.new(system))
		end
	end

	return system
end

function JuWorld:removeSystem(system, callback)
	if not Types.isSystem(system) then
		Types.error(system, "system")
	end

	local name = system.__cname		

	if not self.registeredSystems[name][callback] then
		error("Fail to remove the system: the system is not existed")
		return
	end

	index = self.registeredSystems[name][callback]
	self.systems[callback].objects[index] = nil
	self.registeredSystems[name][callback] = nil
	self.systems[callback].size = self.systems[callback].size - 1

	if self.eventManagerOptions.event_system_removed_enable then
		self.eventManager:queueEvent(
			BuiltinEvents.EVENT_SYSTEM_REMOVED.new(self, system, callback))
	end
end

function JuWorld:stopSystem(system, callback)
	if not Types.isSystem(system) then
		Types.error(system, "system")
	end

	local name = system.__cname

	if not self.registeredSystems[name][callback] then
		error("Faile to stop the system: the system is not existed")
		return
	end

	if self.eventManagerOptions.event_system_stopped_enable then
		if system.active then
			self.eventManager:queueEvent(BuiltinEvents.EVENT_SYSTEM_STOPPED.new(system, callback))
		end
	end

	system:deactivate()
end

function JuWorld:startSystem(system, callback)
	if not Types.isSystem(system) then
		Types.error(system, "system")
	end

	local name = system.__cname

	if not self.registeredSystems[name][callback] then
		error("Faile to continue the system: the system is not existed")
		return
	end

	if self.eventManagerOptions.event_system_started_enable then
		if not system.active then
			self.eventManager:queueEvent(BuiltinEvents.EVENT_SYSTEM_STARTED.new(system, callback))
		end
	end

	system:activate()
end

function JuWorld:containsSystem(system, callback)
	if not Types.isSystem(system) then
		Types.error(system, "system")
	end

	if callback then
		return self.registeredSystems[system][callback] ~= nil
	end
	return self.registeredSystems[system] ~= nil
end

function JuWorld:containsEntity(entity)
	if not Types.isEntity(entity) then
		Types.error(entity, "entity")
	end
	
	return self.entityManager:contains(entity)
end

function JuWorld:getAllEntities()
	return self.entityManager:getAllEntities()
end

function JuWorld:run(callback, ...)
	if callback == "NULL" then
		return
	end

	if not self.systems[callback] then
		return
	end

	for _, system in pairs(self.systems[callback].objects) do
		if system.active then
			system[callback](system, ...)
		end
	end
end

return JuWorld