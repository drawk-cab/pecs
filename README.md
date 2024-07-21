<div align="center">
  <br>
  <h1>PECS</h1>
  <p>
    <b><a href="https://en.wikipedia.org/wiki/Entity_component_system">Entity Component System (ECS)</a> for <a href="https://www.lexaloffle.com/pico-8.php">PICO-8</a> & <a href="https://www.lexaloffle.com/picotron.php">Picotron</a> in 567 tokens.</b><br />
  <sup>(Based on <a href="https://www.lexaloffle.com/bbs/?uid=45947">KatrinaKitten</a>'s excellent <a href="https://www.lexaloffle.com/bbs/?tid=39021">Tiny ECS Framework v1.1</a>)</sup>
  </p>
  <br>
  <br>
</div>

## Usage

Everything is part of a _World_. Create one with `pecs()`:

```lua
local world = pecs()
```

_Components_ describe data containers that can be instantiated:

```lua
local Position = world.component()
local Velocity = world.component()
```

An _Entity_ is a collection of instantiated _Components_.

```lua
local player = world.entity()
player += Position({ x=10, y=0 })
player += Velocity({ x=0, y=1 })
```

_Resources_ are global objects available to all Entities in the world.

```lua
local Timing = world.resource() -- defaults to an empty table

```

All data within an _Entity_ can be accessed as long as you know the _Component_
it belongs to:

```lua
print(player[Position].x, 10, 10, 7)
```

_Systems_ allow specifying game logic (as a function) which applies to
_Entities_ that have a certain set of _Components_ (ie; a _filter_).

The game logic function of a _System_ is executed once per matched _Entity_,
ensuring performance is maintained when there are many entities.
_Resources_ are available to all Entities as if they were a _Component_ of each one.
The system is passed a reference to the _Entity_ plus the values of all the _Components_ and _Resources_ it has asked for.

```lua
local move = world.system({ Position, Velocity, Timing }, function(entity, p, v, t)
  p.x += v.x * t.ticks
  p.y += v.y * t.ticks
end)

function _update()
  -- Outside a system, access resources like this
  Timing().ticks = 1 
  -- Run the system against all matched entities
  move()
end
```

## Example

```lua
local world = pecs()

local Position = world.component()
local Velocity = world.component()
local Timing = world.resource()

local player = world.entity({ name="Jess" })

player += Position({ x=10, y=0 })
player += Velocity({ x=0, y=1 })

local move = world.system({ Position, Velocity, Timing }, function(p, v, t)
  p.x += v.x * t.ticks
  p.y += v.y * t.ticks
end)

local lastTime = time()
function _update()
  Timing().ticks = time() - lastTime
  move(time())
  lastTime = time()
end

function _draw()
  cls()
  print(player[Position].x.." "..player[Position].y, 10, 10, 7)
end
```

For more complete & practical examples, see the `example/` folder:

- **[`example/particles.p8`](./example/particles.p8)**: A Particle Emitter
  showing how to spawn entities and adding/removing components (the type of
  Emitter) on a button press.
- **[`example/camera-follow.p8`](./example/camera-follow.p8)**: A camera
  follow/window technique built using Components & Systems. This example has a
  visual representation of the "camera" to see the effect.

## API

### `pecs() => World`

Everything in PECS happens within a world.

Can be called multiple times to create multiple worlds:

```lua
local world1 = pecs()
local world2 = pecs()
```

Each world has its own _Components_, _Entities_ and _Resources_.

#### `World#update()`

Must be called at the start of each `_update()` before anything else.

#### `World#entity([attr[, Component, ...]]) => Entity`

```lua
local player = world.entity()

local trap = world.entity({ type="spikes" })

local enemy = world.entity({}, Position({ x=10, y=10 }), Rotation({ angle=45 })
```

##### Adding a Component to an Entity

```lua
player += Position({ x=100, y=20 })
```

##### Removing a Component from an Entity

```lua
player -= Position
```

#### `World#component([defaults]) => Component`

```lua
local Position = world.component()

local Drawable = world.component({ color: 8 })
```

#### `World#resource([initial value]) => Resource`

```lua
local Timing = world.resource()

local Timing = world.resource({ ticks: 1 })
```

#### `World#system(filter, callback) => Function`

Where `filter` is a table of Components and Resources, and `callback` is a function that's
passed the entity to operate on.

Returns a function that when called will execute the `callback` once per Entity
that contains all the specified Components.

When executing the function, any parameters are passed through to the
`callback`.

```lua
local move = world.system({ Position, Velocity, Timing }, function(entity, p, v, t)
  p.x += v.x * t.ticks
  p.y += v.y * t.ticks
end)

-- Outside a system, access resources like this
Timing().ticks = 1 
-- Run the system against all matched entities
move()
```

Systems efficiently maintain a list of filtered entities that is only updated
when needed. It is safe to create many systems that operate over large lists of
Entities (within PICO-8's limits).

#### `World#query(filter) => Table<Entity>`

⚠️ _It is recommended to use `World#system` (which calls `query` internally)._

Where `filter` is a table of Components, eg; `{ Position, Velocity }`.

Return a reference to a filtered table of `Entity`s. The table is automatically
updated when new entities match or old entities no longer match. Modifying this
table can cause Systems to misbehave; treat it as read-only.

```lua
local entities = world.query({ Position })
for _, ent in pairs(entities) do
  printh(ent[Position].x .. "," ..ent[Position].y)
end
```

Queries efficiently maintain a list of filtered entities that is only updated
when needed. It is safe to create many queries that operate over large lists of
Entities (within PICO-8's limits).

#### `World#remove(Entity)`

Remove the given entity from the world.

Any Systems or Queries which previously matched this entity will no longer
operate on it.

#### `World#queue(Function)`

Useful for delaying actions until the next turn of the update loop.
Particularly when the action would modify a list that's currently being iterated
on such as removing an item due to collision, or spawning new items.
