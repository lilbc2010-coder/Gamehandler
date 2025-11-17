# Prop Editing System Changes - Implementation Guide

## Overview
This guide details all changes needed to implement the new prop editing system with the following features:
- Remove Edit Mode tab (works in Build Mode only)
- Prevent editing multiple props simultaneously
- Auto-restore current edited prop when selecting a new one
- Restore edited prop when switching to Delete mode
- Use new Highlight system instead of SelectionBox

## Change 1: Update R Key Handler
**Location:** Around line 1540 in the UserInput section

**Find:**
```lua
elseif input.KeyCode == Enum.KeyCode.R then
	-- Check if player is hovering over an owned prop with Prop Placer equipped in Edit Mode
	if equippedTool["Variant"] == "Prop Placer" and propFrame.ModeButton.Button.Mode.Value == "Edit" and
		mouseState == "OwnedProp" and mouseTarget and mouseTarget.Parent.Owner.Value == plr.Name and mouseTarget.Anchored then
		-- Pick up the prop for editing
		PickUpPropForEditing(mouseTarget.Parent)
	else
		-- Normal reload or tuning mode toggle
		ReloadAction()
		ChangePropMode("Tuning")
	end
```

**Replace with:**
```lua
elseif input.KeyCode == Enum.KeyCode.R then
	-- Check if player is hovering over an owned prop with Prop Placer equipped in Build Mode
	if equippedTool["Variant"] == "Prop Placer" and propFrame.ModeButton.Button.Mode.Value == "Build" and
		mouseState == "OwnedProp" and mouseTarget and mouseTarget.Parent.Owner.Value == plr.Name and mouseTarget.Anchored and
		not editingPropData then -- Can only edit if not already editing another prop
		-- Pick up the prop for editing
		PickUpPropForEditing(mouseTarget.Parent)
	else
		-- Normal reload or tuning mode toggle
		ReloadAction()
		ChangePropMode("Tuning")
	end
```

---

## Change 2: Update PickUpPropForEditing Function
**Location:** Around line 1380 (the PickUpPropForEditing function)

**Find the section that creates the highlight (near the end of the function):**
```lua
-- Create blue highlight for the selected prop
local highlight = Instance.new("SelectionBox")
highlight.Adornee = dragProp["Prop"]
highlight.Color3 = Color3.fromRGB(0, 100, 255)
highlight.SurfaceColor3 = Color3.fromRGB(0, 100, 255)
highlight.SurfaceTransparency = 0.7
highlight.LineThickness = 0.05
highlight.Parent = dragProp["Prop"]
dragProp["Highlight"] = highlight
```

**Replace with:**
```lua
-- Create highlight with new system: Highlight instance with custom colors
local highlight = Instance.new("Highlight")
highlight.Adornee = dragProp["Prop"]
highlight.FillTransparency = 1
highlight.OutlineColor = Color3.fromRGB(126, 193, 255)
highlight.OutlineTransparency = 0
highlight.Parent = dragProp["Prop"]
dragProp["Highlight"] = highlight
```

---

## Change 3: Update ModeButton Handler
**Location:** Around line 3770 in the button click handler section

**Find:**
```lua
elseif v.Parent.Name == "ModeButton" then
	if v.Mode.Value == "Build" then
		v.Mode.Value = "Delete"
		v.Text = "Delete Mode"
		if dragProp["Mode"] then
			-- If we're editing a prop, restore it before switching modes
			if editingPropData then
				rep.PropPlace:InvokeServer(work, editingPropData.OriginalCFrame, editingPropData.RefMode,
					editingPropData.rX, editingPropData.rY, editingPropData.rZ,
					editingPropData.tX, editingPropData.tY, editingPropData.tZ,
					editingPropData.sRX, editingPropData.sRY, editingPropData.sRZ,
					editingPropData.sTX, editingPropData.sTY, editingPropData.sTZ,
					editingPropData.PropName)
				local countLabel = propFrame.CountLabel
				countLabel.Count.Value = countLabel.Count.Value + 1
				countLabel.Text = tostring(countLabel.Count.Value) .."/".. tostring(rep.PropLimit.Value)
				editingPropData = nil
			end
			dragProp["Mode"] = false
			-- Remove highlight before destroying prop
			if dragProp["Highlight"] then
				dragProp["Highlight"]:Destroy()
				dragProp["Highlight"] = nil
			end
			dragProp["Prop"]:Destroy()
			dragProp["Prop"] = nil
		end
	elseif v.Mode.Value == "Delete" then
		v.Mode.Value = "Edit"
		v.Text = "Edit Mode"
	elseif v.Mode.Value == "Edit" then
		v.Mode.Value = "SaveLoad"
		v.Text = "Save/Load Mode"
		propFrame.ScrollFrame.Visible = false
		propFrame.LoadBuildFrame.Visible = true
		propFrame.SaveClearButton.Button.Text = "Save Build"
	elseif v.Mode.Value == "SaveLoad" then
		v.Mode.Value = "Build"
		v.Text = "Build Mode"
		propFrame.ScrollFrame.Visible = true
		propFrame.LoadBuildFrame.Visible = false
		propFrame.SaveClearButton.Button.Text = "Clear All Props"
	end
```

**Replace with:**
```lua
elseif v.Parent.Name == "ModeButton" then
	if v.Mode.Value == "Build" then
		v.Mode.Value = "Delete"
		v.Text = "Delete Mode"
		if dragProp["Mode"] then
			-- If we're editing a prop, restore it before switching modes
			if editingPropData then
				rep.PropPlace:InvokeServer(work, editingPropData.OriginalCFrame, editingPropData.RefMode,
					editingPropData.rX, editingPropData.rY, editingPropData.rZ,
					editingPropData.tX, editingPropData.tY, editingPropData.tZ,
					editingPropData.sRX, editingPropData.sRY, editingPropData.sRZ,
					editingPropData.sTX, editingPropData.sTY, editingPropData.sTZ,
					editingPropData.PropName)
				local countLabel = propFrame.CountLabel
				countLabel.Count.Value = countLabel.Count.Value + 1
				countLabel.Text = tostring(countLabel.Count.Value) .."/".. tostring(rep.PropLimit.Value)
				editingPropData = nil
			end
			dragProp["Mode"] = false
			-- Remove highlight before destroying prop
			if dragProp["Highlight"] then
				dragProp["Highlight"]:Destroy()
				dragProp["Highlight"] = nil
			end
			dragProp["Prop"]:Destroy()
			dragProp["Prop"] = nil
		end
	elseif v.Mode.Value == "Delete" then
		v.Mode.Value = "SaveLoad"
		v.Text = "Save/Load Mode"
		propFrame.ScrollFrame.Visible = false
		propFrame.LoadBuildFrame.Visible = true
		propFrame.SaveClearButton.Button.Text = "Save Build"
	elseif v.Mode.Value == "SaveLoad" then
		v.Mode.Value = "Build"
		v.Text = "Build Mode"
		propFrame.ScrollFrame.Visible = true
		propFrame.LoadBuildFrame.Visible = false
		propFrame.SaveClearButton.Button.Text = "Clear All Props"
	end
```

---

## Change 4: Update PropButton Handler
**Location:** Around line 3850 in the button handler section

**Find:**
```lua
elseif v.Parent.Name == "PropButton" and propFrame.CountLabel.Count.Value ~= rep.PropLimit.Value and
	propFrame.ModeButton.Button.Mode.Value == "Build" then
	if dragProp["Mode"] then
		-- If we're editing a prop, restore it before selecting a new one
		if editingPropData then
			rep.PropPlace:InvokeServer(work, editingPropData.OriginalCFrame, editingPropData.RefMode,
				editingPropData.rX, editingPropData.rY, editingPropData.rZ,
				editingPropData.tX, editingPropData.tY, editingPropData.tZ,
				editingPropData.sRX, editingPropData.sRY, editingPropData.sRZ,
				editingPropData.sTX, editingPropData.sTY, editingPropData.sTZ,
				editingPropData.PropName)
			local countLabel = propFrame.CountLabel
			countLabel.Count.Value = countLabel.Count.Value + 1
			countLabel.Text = tostring(countLabel.Count.Value) .."/".. tostring(rep.PropLimit.Value)
		end
		dragProp["Mode"] = false
		-- Remove highlight before destroying prop
		if dragProp["Highlight"] then
			dragProp["Highlight"]:Destroy()
			dragProp["Highlight"] = nil
		end
		dragProp["Prop"]:Destroy()
		dragProp["Prop"] = nil
	end
```

**Add at the beginning (before the existing dragProp["Mode"] check):**
```lua
-- If we're currently editing a prop, restore it first
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
	-- Update count
	local countLabel = propFrame.CountLabel
	countLabel.Count.Value = countLabel.Count.Value + 1
	countLabel.Text = tostring(countLabel.Count.Value) .."/".. tostring(rep.PropLimit.Value)
	-- Destroy the dragged prop
	dragProp["Prop"]:Destroy()
	dragProp["Mode"] = nil
	dragProp["Prop"] = nil
	editingPropData = nil
end
```

---

## Change 5: Update OrientationButton Handler
**Location:** Around line 3900

**Find:**
```lua
elseif v.Parent.Name == "OrientationButton" and dragProp["Prop"] then
	if propFrame.ModeButton.Button.Mode.Value == "Build" then
		propFrame.ModeButton.Button.Mode.Value = "Orient"
		dragProp["Mode"] = "Orient"
		v.Text = "Select a placed prop..."
		v.BackgroundColor3 = Color3.new(1, 1, 1)
		v.Parent.BackgroundColor3 = Color3.fromRGB(175, 175, 175)
	else
		propFrame.ModeButton.Button.Mode.Value = "Build"
		dragProp["Mode"] = "Build"
		v.Text = "Select Orientation"
		v.BackgroundColor3 = Color3.fromRGB(56, 92, 255)
		v.Parent.BackgroundColor3 = Color3.fromRGB(33, 55, 153)
	end
```

**Replace with:**
```lua
elseif v.Parent.Name == "OrientationButton" and dragProp["Prop"] then
	if dragProp["Mode"] == "Drag" or dragProp["Mode"] == "Tune" then
		dragProp["Mode"] = "Orient"
		v.Text = "Select a placed prop..."
		v.BackgroundColor3 = Color3.new(1, 1, 1)
		v.Parent.BackgroundColor3 = Color3.fromRGB(175, 175, 175)
	elseif dragProp["Mode"] == "Orient" then
		dragProp["Mode"] = "Drag"
		v.Text = "Select Orientation"
		v.BackgroundColor3 = Color3.fromRGB(56, 92, 255)
		v.Parent.BackgroundColor3 = Color3.fromRGB(33, 55, 153)
	end
```

---

## Summary of Key Changes

1. **Edit Mode Removed**: The mode button now cycles through Build → Delete → SaveLoad → Build (skipping Edit)

2. **Editing in Build Mode**: Props can be picked up for editing by pressing R while hovering over them in Build mode

3. **Single Prop Editing**: Only one prop can be edited at a time. Attempting to edit another prop will restore the first one

4. **Mode Switching Protection**: Switching to Delete mode or SaveLoad mode will restore any currently edited prop

5. **New Highlight System**: Uses the Highlight instance instead of SelectionBox with:
   - FillTransparency = 1 (invisible fill)
   - OutlineColor = RGB(126, 193, 255) (light blue outline)
   - OutlineTransparency = 0 (fully visible outline)

## Testing Checklist

After implementing these changes, test the following:

- [ ] R key picks up props for editing in Build mode only
- [ ] R key does nothing when already editing a prop
- [ ] Selecting a new prop from the list restores the currently edited prop
- [ ] Switching to Delete mode restores any edited prop
- [ ] Switching to SaveLoad mode restores any edited prop
- [ ] Highlight appears as a light blue outline with no fill
- [ ] Orient mode still works correctly
- [ ] Placing the edited prop works correctly
- [ ] Prop count updates correctly during all operations
