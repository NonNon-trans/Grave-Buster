--!strict

local ActiveZombieRegistry = require("../src/server/ActiveZombieRegistry")

local registry = ActiveZombieRegistry.new()
local zombie = {}
local entry = { Root = "root" }
registry:Add(zombie, entry)
assert(registry:Count() == 1 and registry:Contains(zombie))
assert(registry:Release(zombie) == entry)
assert(registry:Count() == 0 and not registry:Contains(zombie))
assert(registry:Release(zombie) == nil, "A released zombie cannot be defeated twice")
assert(registry:Count() == 0, "Double release must not consume another cap slot")

registry:Add({}, {})
registry:Clear()
assert(registry:Count() == 0)

print("PASS ActiveZombieRegistry: release frees one slot and rejects double defeat")
