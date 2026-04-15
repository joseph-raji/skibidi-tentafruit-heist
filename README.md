# Skibidi Tentafruit Heist

A Roblox game where players collect fruit characters (brainrots), place them in their base to generate income, steal from rivals, and progress through rebirths.

## Project Structure

```
ReplicatedStorage/
  Modules/
    BrainrotData.lua     — 25 fruit character definitions across 5 rarity tiers
    GameConfig.lua       — Global constants (costs, timings, world layout)

ServerScriptService/
  Main.server.lua        — Entry point, RemoteEvent wiring, heartbeat loop
  BaseSystem.lua         — Player base / floor / slot management
  CharacterBuilders.lua  — Builds 3D characters from Roblox primitives (or imported meshes)
  CombatSystem.lua       — Bat swing / knockback logic
  DataStore.lua          — Persistent save/load via DataStoreService
  ItemsSystem.lua        — Purchasable items (bat, shield, etc.)
  ProgressionSystem.lua  — Income tick, rebirth, collection tracking
  ShopSystem.lua         — Buy/gacha server logic
  StealSystem.lua        — Touch-to-steal and base-claim logic

StarterGui/
  HUD.client.lua         — Money display, carry indicator, steal/claim popups
  ShopUI.client.lua      — Shop tabs: items, gacha, fusion, rebirth
  Pokedex.client.lua     — Collection viewer (all 25 characters)
  FloatingIncome.client.lua — Floating +$N effect above placed characters
```

## Characters

25 fruit anthropomorph characters across 5 rarity tiers:

| Rarity    | Drop weight | Income/s   | Cost          |
|-----------|-------------|------------|---------------|
| Common    | 50          | 50–80      | 500–800       |
| Uncommon  | 25          | 150–200    | 1,500–2,000   |
| Rare      | 12          | 400–500    | gacha only    |
| Epic      | 5           | 1,000–1,200 | gacha only   |
| Legendary | 1           | 2,800–3,200 | gacha only   |

Characters are defined in `BrainrotData.lua` and built procedurally in `CharacterBuilders.lua`. Each builder function receives `(pos, model, s)` — position, parent Model, and scale — and returns the `Body` part used as `PrimaryPart`.

## Adding Custom Skins (Imported FBX Meshes)

Characters are built from Roblox primitives by default. To replace one with a custom imported mesh (e.g. from Meshy AI):

**Step 1 — Import in Roblox Studio**

1. Open the place in Studio.
2. Go to **Home → Import 3D** and select your `.fbx` file.
3. In the 3D Importer, confirm the mesh, skin (textures), and animation tracks look correct, then click **Import**.
4. Move the resulting Model into `ReplicatedStorage > SkinTemplates` and rename it (e.g. `FraiseSkin`).
5. If the FBX includes animations, the imported `Animation` objects will be nested inside the Model — keep them there.

**Step 2 — Update `CharacterBuilders.lua`**

At the top of the file, add:

```lua
local skinTemplates = game:GetService("ReplicatedStorage"):WaitForChild("SkinTemplates")

local function buildFromImportedMesh(pos, model, s, templateName)
    local template = skinTemplates:WaitForChild(templateName)
    local clone = template:Clone()
    clone.Parent = model
    if clone.PrimaryPart then
        clone:SetPrimaryPartCFrame(CFrame.new(pos))
    end
    model.PrimaryPart = clone.PrimaryPart
    return clone.PrimaryPart
end
```

Then replace the builder(s) you want to skin. For example, to apply `FraiseSkin` to all three fraise characters:

```lua
builders["fraise_jr"]      = function(pos, model, s) return buildFromImportedMesh(pos, model, s, "FraiseSkin") end
builders["fraise_supreme"] = function(pos, model, s) return buildFromImportedMesh(pos, model, s, "FraiseSkin") end
builders["fraise_omega"]   = function(pos, model, s) return buildFromImportedMesh(pos, model, s, "FraiseSkin") end
```

**Step 3 — Playing the walk animation**

If the FBX includes a walk animation (e.g. "Red Carpet Walk"), play it after the character is placed:

```lua
local animController = clone:FindFirstChildOfClass("AnimationController")
    or clone:FindFirstChildOfClass("Humanoid")
if animController then
    local anim = clone:FindFirstChildOfClass("Animation")
    if anim then
        local track = animController:LoadAnimation(anim)
        track:Play()
    end
end
```

Add this inside `buildFromImportedMesh` after `clone.Parent = model`.

## Game Loop Summary

1. Players spawn and receive a home base plot.
2. Buy or spin (gacha) for characters, then place them in base slots to earn passive income.
3. Steal rival characters by touching them and carrying them back to your base.
4. Use the bat to knock thieves and drop their cargo.
5. Lock shields temporarily protect placed characters.
6. Rebirth resets money and collection for a permanent income multiplier.
