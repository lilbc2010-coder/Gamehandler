# Occluder Mode Improvements - Implementation Plan

## Required Changes

### 1. Data Structure Change
**Current:** `occludedModels = {}` stores Model instances directly
**New:** `occludedModels = {}` stores tables with `{Model = model, PartData = partData}`

### 2. Property Storage (Lines ~445-454)
When occluding a model, store original properties:
```lua
-- Store original properties before modifying
local partData = {}
for _, part in ipairs(model:GetDescendants()) do
    if part:IsA("BasePart") then
        partData[part] = {
            Transparency = part.Transparency,
            CanCollide = part.CanCollide,
            Color = part.Color,
            Material = part.Material,
            Reflectance = part.Reflectance
        }
        part.Transparency = 1
        part.CanCollide = false
    end
end
table.insert(occludedModels, {Model = model, PartData = partData})
```

### 3. Property Restoration (Lines ~489-501)
When restoring, use stored properties:
```lua
for i, occludedData in ipairs(occludedModels) do
    if occludedData.Model == model then
        for part, properties in pairs(occludedData.PartData) do
            if part and part.Parent then
                part.Transparency = properties.Transparency
                part.CanCollide = properties.CanCollide
                part.Color = properties.Color
                part.Material = properties.Material
                part.Reflectance = properties.Reflectance
            end
        end
        table.remove(occludedModels, i)
```

### 4. Mode Switching Updates (Lines ~3467, 3481, 3495)
Update all three mode switch locations to use new structure:
```lua
-- Show in Delete Mode (restore appearance but keep collisions off)
for _, occludedData in ipairs(occludedModels) do
    for part, properties in pairs(occludedData.PartData) do
        if part and part.Parent then
            part.Transparency = properties.Transparency
            part.Color = properties.Color
            part.Material = properties.Material
            part.Reflectance = properties.Reflectance
            -- CanCollide stays false
        end
    end
end

-- Hide when leaving Delete Mode
for _, occludedData in ipairs(occludedModels) do
    for part, properties in pairs(occludedData.PartData) do
        if part and part.Parent then
            part.Transparency = 1
        end
    end
end
```

### 5. Hover Detection Update (Lines ~6417-6422, 6428-6439)
Update to use new structure:
```lua
for _, occludedData in ipairs(occludedModels) do
    if occludedData.Model == model then
        isOccludableModel = true
        break
    end
end
```

### 6. Multiple Blue Highlights (New - after line ~6490)
Add system to show highlights on ALL occluded models in Delete Mode:
```lua
-- Variable to track multiple highlights
local occluderHighlights = {} -- Change from single to table

-- In RenderStepped, after occluder highlight code:
if occluderMode and propFrame.ModeButton.Button.Mode.Value == "Delete" then
    -- Remove old highlights
    for _, highlight in ipairs(occluderHighlights) do
        highlight:Destroy()
    end
    occluderHighlights = {}

    -- Create highlights for all occluded models
    for _, occludedData in ipairs(occludedModels) do
        local highlight = Instance.new("Highlight")
        highlight.Adornee = occludedData.Model
        highlight.FillTransparency = 1
        highlight.OutlineColor = Color3.fromRGB(0, 0, 255)
        highlight.Parent = cam
        table.insert(occluderHighlights, highlight)
    end
elseif #occluderHighlights > 0 then
    for _, highlight in ipairs(occluderHighlights) do
        highlight:Destroy()
    end
    occluderHighlights = {}
end
```

### 7. Prevent Build Mode Highlighting
In the hover highlight section (~line 6440), check if model is occluded:
```lua
if currentMode == "Build" then
    local occluderValue = model:FindFirstChild("Occluder")
    if occluderValue and occluderValue:IsA("StringValue") and occluderValue.Value == "Occluded" then
        -- Check if already occluded
        local isAlreadyOccluded = false
        for _, occludedData in ipairs(occludedModels) do
            if occludedData.Model == model then
                isAlreadyOccluded = true
                break
            end
        end
        if not isAlreadyOccluded then
            isOccludableModel = true
        end
    end
end
```

### 8. Save/Load Support
Need to find PropSave/PropLoad functions and add:
- Save: Store model names of occluded models
- Load: Re-occlude matching models after load

### 9. Cleanup on Clear/Leave
Find "Clear All Props" handler and player leaving handler:
```lua
-- Restore all occluded models
for _, occludedData in ipairs(occludedModels) do
    for part, properties in pairs(occludedData.PartData) do
        if part and part.Parent then
            part.Transparency = properties.Transparency
            part.CanCollide = properties.CanCollide
            part.Color = properties.Color
            part.Material = properties.Material
            part.Reflectance = properties.Reflectance
        end
    end
end
occludedModels = {}
```

## Line References
- Variables: 54-56
- Occlude handler: 441-477
- Restore handler: 488-523
- Mode switching: 3466-3500
- Hover detection: 6405-6445
- Highlight system: ~6425-6500

## Status
- Property storage: IN PROGRESS
- Multiple highlights: TODO
- Build Mode prevention: TODO
- Save/Load: TODO
- Cleanup: TODO
