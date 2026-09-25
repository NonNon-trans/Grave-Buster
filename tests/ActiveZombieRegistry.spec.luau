--!strict

local ActiveZombieRegistry = require("../src/server/ActiveZombieRegistry")

local registry = ActiveZombieRegistry.new()
local zombie = {}
local entry = { Root = "root", SpawnWave = 3, Lifecycle = "ACTIVE" }
registry:Add(zombie, entry)
registry:Add({}, { SpawnWave = 4, Lifecycle = "ACTIVE" })
assert(registry:Count() == 2 and registry:Contains(zombie))
assert(registry:CountForWave(3) == 1 and registry:CountForWave(4) == 1)
assert(registry:Release(zombie) == entry)
assert(registry:Count() == 1 and registry:CountForWave(3) == 0 and not registry:Contains(zombie))
assert(registry:CountForWave(4) == 1, "Releasing an old-wave Zombie cannot alter the next-wave count")
assert(registry:Release(zombie) == nil, "A released zombie cannot be defeated twice")
assert(registry:Count() == 1, "Double release must not consume another cap slot")

registry:Add({}, {})
registry:Clear()
assert(registry:Count() == 0)
assert(registry:CountForWave(4) == 0)

print("PASS ActiveZombieRegistry: release frees one slot and rejects double defeat")
