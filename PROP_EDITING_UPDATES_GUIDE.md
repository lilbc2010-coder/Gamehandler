# Prop Editing System - Additional Updates Guide

## Overview
This guide contains additional improvements to the prop editing system:

1. ✅ **Client-side highlights** - Only you can see your prop highlights
2. ✅ **Ownership enforcement** - Only you can edit your own props
3. ✅ **Edit props after loading** - Works with loaded saves
4. ✅ **Reset sliders in Tuning Mode** - Sliders reset when entering Tuning Mode
5. ✅ **Auto-restore on new selection** - Editing prop restored when selecting from list

---

## Update 1: Add Helper Function for Loading Saved Props

**Location:** Add this new function near the PickUpPropForEditing function (~line 1350)

**Add this NEW function:**

```lua
function ExtractPropDataFromPlaced(placedProp)
	-- Get the prop's current transformation data
	local propCFrame = placedProp.PrimaryPart.CFrame

	-- Try to find existing data first
	for i, v in pairs(placedPropData) do
		if v["Prop"] == placedProp then
			return v, i
		end
	end

	-- If not found in placedPropData (like after loading), create default data
	-- The prop was placed with some transformation, we'll start fresh with defaults
	return {
		Prop = placedProp,
		RefMode = "Global",
		rX = 0,
		rY = 0,
		rZ = 0,
		tX = 0,
		tY = 0,
		tZ = 0,
		sRX = 0,
		sRY = 0,
		sRZ = 0,
		sTX = 0,
		sTY = 0,
		sTZ = 0
	}, nil
end
```

---

## Update 2: Modify PickUpPropForEditing Function

**Location:** Replace the entire PickUpPropForEditing function (~line 1380)

**Key Changes:**
1. Add ownership check at the beginning
2. Use `ExtractPropDataFromPlaced` instead of searching placedPropData directly
3. Ensure highlights are client-side only (already are by default)

**Find:**
```lua
function PickUpPropForEditing(placedProp)
	-- Find the prop data in our tracking table
	local propData
	local propDataIndex
	for i, v in pairs(placedPropData) do
		if v["Prop"] == placedProp then
			propData = v
			propDataIndex = i
			break
		end
	end

	if not propData then return end
```

**Replace with:**
```lua
function PickUpPropForEditing(placedProp)
	-- Only allow editing your own props
	if placedProp.Owner.Value ~= plr.Name then
		return
	end

	-- Find or create the prop data (works even after loading saves)
	local propData, propDataIndex = ExtractPropDataFromPlaced(placedProp)

	if not propData then return end
```

---

## Update 3: Modify ChangePropMode to Reset Sliders

**Location:** Find the ChangePropMode function (~line 1300)

**Find:**
```lua
function ChangePropMode(input)
	if input == "Tuning" then
		if dragProp["Mode"] then
			if dragProp["Mode"] == "Drag" then
				dragProp["Mode"] = "Tune"
				propFrame.TuningFrame.Visible = true
				propFrame.MobilePropFrame.MovementButton.Button.Text = "Tuning Mode"
				dragProp["Location"] = dragProp["Prop"].PrimaryPart.CFrame
			else
				dragProp["Mode"] = "Drag"
				propFrame.TuningFrame.Visible = false
				propFrame.MobilePropFrame.MovementButton.Button.Text = "Drag Mode"
			end
		end
```

**Replace with:**
```lua
function ChangePropMode(input)
	if input == "Tuning" then
		if dragProp["Mode"] then
			if dragProp["Mode"] == "Drag" then
				dragProp["Mode"] = "Tune"
				propFrame.TuningFrame.Visible = true
				propFrame.MobilePropFrame.MovementButton.Button.Text = "Tuning Mode"
				dragProp["Location"] = dragProp["Prop"].PrimaryPart.CFrame

				-- RESET SLIDERS TO CENTER POSITION (0 rotation/translation)
				if editingPropData then
					for _, v in pairs({"Rot", "Translate"}) do
						for _, n in pairs({"X", "Y", "Z"}) do
							local slider = propFrame.TuningFrame:FindFirstChild(v.."Frame"..n).Slider
							-- Set slider to center (0.45 = center of 0.9 width track)
							slider.Position = UDim2.new(0.45, 0, -.25, 0)
							-- Reset the propSlider values to 0
							propSlider[string.lower(string.sub(v, 1, 1))..n] = 0
						end
					end
					-- Reset the dragProp rotation and translation to 0
					dragProp["rX"] = 0
					dragProp["rY"] = 0
					dragProp["rZ"] = 0
					dragProp["tX"] = 0
					dragProp["tY"] = 0
					dragProp["tZ"] = 0
					-- Update the prop position to reflect the reset
					dragProp["Prop"].Prop:SetPrimaryPartCFrame(dragProp["Location"])
				end
			else
				dragProp["Mode"] = "Drag"
				propFrame.TuningFrame.Visible = false
				propFrame.MobilePropFrame.MovementButton.Button.Text = "Drag Mode"
			end
		end
```

---

## Update 4: PropButton Handler - Clear editingPropData

**Location:** In the PropButton click handler (~line 3850)

**Find (this is after the restoration code):**
```lua
	if editingPropData and dragProp["Mode"] then
		-- Remove highlight from current editing prop
		if dragProp["Highlight"] then
			dragProp["Highlight"]:Destroy()
			dragProp["Highlight"] = nil
		end
		-- Restore the previously edited prop to its original position
		rep.PropPlace:InvokeServer(work, editingPropData.OriginalCFrame, editingPropData.RefMode,
			editingPropData.rX, editingPropData.rY, editingPropData.rZ,
			editingPropData.tX, editingPropData.tY, editingPropData.tZ,
			editingPropData.sRX, editingPropData.sRY, editingPropData.sRZ,
			editingPropData.sTX, editingPropData.sTY, editingPropData.sTZ,
			editingPropData.PropName)
		-- Destroy the dragged prop
		dragProp["Prop"]:Destroy()
		dragProp["Mode"] = nil
		dragProp["Prop"] = nil
		-- Update count
		local countLabel = propFrame.CountLabel
		countLabel.Count.Value = countLabel.Count.Value + 1
		countLabel.Text = tostring(countLabel.Count.Value) .."/".. tostring(rep.PropLimit.Value)
	end
```

**Add this line at the end:**
```lua
		-- Clear editing data
		editingPropData = nil
	end
```

**Also add highlight creation after the prop container setup:**
```lua
	dragProp["Prop"].Parent = work

	-- Create CLIENT-SIDE ONLY highlight
	local highlight = Instance.new("Highlight")
	highlight.Adornee = dragProp["Prop"]
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(126, 193, 255)
	highlight.OutlineTransparency = 0
	highlight.Parent = dragProp["Prop"]
	dragProp["Highlight"] = highlight
```

---

## Update 5: Additional Ownership Checks in ClickAction

**Location:** In the ClickAction function, around the prop interaction section (~line 1200)

**Find:**
```lua
elseif mouseState == "OwnedProp" or (mouseTarget and (platform == "Mobile" and mouseTarget.Name == "OwnedProp")) then
	if mouseTarget.Parent.Owner.Value == plr.Name and propFrame.Visible then
```

**This section is already checking ownership, but make sure it's consistent**

**Add this check to prevent showing the owner notification if it's your own prop:**

**Find:**
```lua
	else
		notifierCount = notifierCount + 1
		local timeStamp, currentTime = mouseTarget.Parent.TimeStamp.Value, os.time()
		notifier.Text = "This object belongs to ".. mouseTarget.Parent.Owner.Value ..". Placed "..
			tostring(math.floor((currentTime - timeStamp) / 60)).."m "..
			tostring(math.floor((currentTime - timeStamp) % 60)).."s ago"
		notifier.Visible = true
		CoroutineLauncher("NotifierDelay")
	end
```

**Replace with:**
```lua
	else
		-- Show owner info (only if it's not your prop)
		if mouseTarget.Parent.Owner.Value ~= plr.Name then
			notifierCount = notifierCount + 1
			local timeStamp, currentTime = mouseTarget.Parent.TimeStamp.Value, os.time()
			notifier.Text = "This object belongs to ".. mouseTarget.Parent.Owner.Value ..". Placed "..
				tostring(math.floor((currentTime - timeStamp) / 60)).."m "..
				tostring(math.floor((currentTime - timeStamp) % 60)).."s ago"
			notifier.Visible = true
			CoroutineLauncher("NotifierDelay")
		end
	end
```

---

## Summary of Changes

### 1. **Client-Side Highlights Only**
- Highlights are created using `Instance.new("Highlight")` which are **client-side only by default**
- They're parented to the local dragProp model, not replicated to other players
- ✅ **Already working** - No changes needed, but verified in code

### 2. **Ownership Enforcement**
- Added ownership check at the start of `PickUpPropForEditing`: `if placedProp.Owner.Value ~= plr.Name then return end`
- Only shows owner notification if prop doesn't belong to you
- ✅ **Prevents editing other players' props**

### 3. **Edit Props After Loading**
- New `ExtractPropDataFromPlaced` function handles props not in `placedPropData`
- When you load a save, props aren't in the tracking table
- This function creates default data for loaded props so they can be edited
- ✅ **Fixes the loading issue**

### 4. **Reset Sliders in Tuning Mode**
- When entering Tuning Mode (Drag → Tune), sliders reset to center (0.45 position)
- All rotation and translation values reset to 0
- Prop position updates to reflect the reset
- ✅ **Only happens when editing an existing prop** (checks `if editingPropData`)

### 5. **Auto-Restore on New Selection**
- Added `editingPropData = nil` to clear the editing state
- When selecting a new prop from the list, the current edited prop is restored first
- ✅ **Prevents losing edited props when switching**

---

## Testing Checklist

After implementing these updates, verify:

- [ ] Highlights only visible to you (have another player join and check)
- [ ] Cannot edit other players' props (try pressing R on their props)
- [ ] Can edit your own props immediately after loading a save
- [ ] Sliders reset to center when opening Tuning Mode while editing
- [ ] Editing prop is restored when selecting a new prop from the list
- [ ] Prop is restored to original position and rotation
- [ ] Highlight is properly removed when switching props
- [ ] Owner notification doesn't show for your own props
- [ ] Can still delete your own props in Delete mode
- [ ] Orient mode still works correctly

---

## Code Flow for Editing Props After Load

1. **Player presses R on a placed prop**
2. `PickUpPropForEditing(placedProp)` is called
3. Checks ownership: `if placedProp.Owner.Value ~= plr.Name then return end`
4. Calls `ExtractPropDataFromPlaced(placedProp)`
5. Function searches `placedPropData` table
6. **If not found** (loaded prop): Creates default data with 0 transformations
7. Prop can now be edited normally
8. When placed, it gets added back to `placedPropData`

---

## Important Notes

- **Highlights are client-side** by nature in Roblox when created locally
- **Ownership is enforced** at multiple points to prevent griefing
- **Loaded props start with default transformations** - players can re-adjust them
- **Slider reset only applies to edited props** - new props from list already start at 0
- **editingPropData must be cleared** when done editing to allow new edits
