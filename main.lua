function createECSWorld()
  local entities = {}
  local queries = {}
  local systems = {}
  local onNextUpdateStack = {}

  -- filter is an array of components, eg; { Positionable, Collidable }
  -- Return a reference to the filtered list of entities (automatically
  -- updated when new entities match / old entities no longer match)
  function createQuery(filter)
    -- This filter already exists
    local query = util.find(queries, filter, function(a, _, b)
      return util.arraySame(a, b)
    end)

    if (query != nil) then
      return query
    end

    -- Empty to start
    queries[filter] = {}

    -- Then iterate over all known entites to populate the filter
    for _, entity in pairs(entities) do
      if (util.every(filter, function(componentFactory)
        return entity[componentFactory]
      end)) then
        queries[filter][entity._id] = entity
      end
    end

    return queries[filter]
  end

  function updateFiltersForEntity(entity)
    -- Extract out just the components from this entity
    local components = {}
    for _, component in pairs(entity) do
      if (type(component) == "table" and component._componentFactory != nil) then
        add(components, component)
      end
    end

    -- Check and update each filter
    for filter, entities in pairs(queries) do
      if (util.every(filter, function(componentFactory)
        return entity[componentFactory] != nil
      end)) then
        entities[entity._id] = entity
      else
        entities[entity._id] = nil
      end
    end
  end

  function addComponentToEntity(entity, component)
    -- Only components created by createComponent() can be added
    assert(component and component._componentFactory)
    -- And only once
    assert(not entity[component._componentFactory])

    -- Store the component keyed by its factory
    entity[component._componentFactory] = component
  end

  function createEntity(attributes, ...)
    local entity = util.assign({}, attributes or {})

    entity._id = cuid()

    setmetatable(entity,{
      __add=function(self, component)
        addComponentToEntity(self, component)
        -- This entity's set of components has changed, so we need to update the
        -- queries
        updateFiltersForEntity(self)
        return self
      end,

      __sub=function(self, componentFactory)
        self[componentFactory] = nil
        updateFiltersForEntity(self)
        return self
      end
    })

    local newComponents = 0
    for component in all(pack(...)) do
      newComponents += 1
      addComponentToEntity(entity, component)
    end

    entities[entity._id] = entity

    if (newComponents > 0) then updateFiltersForEntity(entity) end
    return entity
  end

  function createComponent(defaults)
    local function componentFactory(attributes)
      local component = util.assign({}, defaults, attributes)
      component._componentFactory = componentFactory
      component._id = cuid()
      return component
    end
    return componentFactory
  end

  function createSystem(componentFilter, callback)
    local entities = createQuery(componentFilter)
    return function(...)
      for _, entity in pairs(entities) do
        callback(entity, ...)
      end
    end
  end

  function removeEntity(entity)
    entities[entity._id] = nil
    for _, filteredEntities in pairs(queries) do
      filteredEntities[entity._id] = nil
    end
  end

  -- Useful for delaying actions until the next turn of the update loop.
  -- Particularly when the action would modify a list that's currently being
  -- iterated on such as removing an item due to collision, or spawning new items.
  function queue(callback)
    add(onNextUpdateStack, callback)
  end

  -- Must be called at the start of each update() before anything else
  function update()
    for callback in all(onNextUpdateStack) do
      callback()
      del(onNextUpdateStack, callback)
    end
  end

  return {
    createEntity=createEntity,
    createComponent=createComponent,
    createSystem=createSystem,
    createQuery=createQuery,
    removeEntity=removeEntity,
    queue=queue,
    update=update,
  }
end
