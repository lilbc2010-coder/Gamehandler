-- CHANGES FOR PROP EDITING SYSTEM
-- This file documents the changes needed for the prop editing system

--[[ CHANGE 1: Update R key handler to work in Build mode only ]]
-- Find this section (around line 1540):
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

--[[ CHANGE 2: Update PickUpPropForEditing function with new highlight system ]]
-- Replace the entire PickUpPropForEditing function:
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

	-- If we're already editing a prop, restore it first
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

	-- IMPORTANT: Capture the placed prop's actual world CFrame BEFORE deleting it
	local placedPropCFrame = placedProp.PrimaryPart.CFrame

	-- Store the editing prop data so we can restore it later if needed
	editingPropData = {
		OriginalCFrame = placedPropCFrame,
		RefMode = propData["RefMode"],
		rX = propData["rX"],
		rY = propData["rY"],
		rZ = propData["rZ"],
		tX = propData["tX"],
		tY = propData["tY"],
		tZ = propData["tZ"],
		sRX = propData["sRX"],
		sRY = propData["sRY"],
		sRZ = propData["sRZ"],
		sTX = propData["sTX"],
		sTY = propData["sTY"],
		sTZ = propData["sTZ"],
		PropName = placedProp.Name
	}

	-- Delete the placed prop from the server (but keep it in placedPropData to avoid duplication)
	placedProp.Owner.Value = ""
	rep.PropDelete:FireServer(placedProp)
	script.GUISounds.DeleteSound:Play()

	-- Update the prop count
	local countLabel = propFrame.CountLabel
	countLabel.Count.Value = countLabel.Count.Value - 1
	countLabel.Text = tostring(countLabel.Count.Value) .."/".. tostring(rep.PropLimit.Value)
	countLabel.TextColor3 = Color3.new(0, 0, 0)
	propFrame.Label.TextColor3 = Color3.new(0, 0, 0)

	-- Remove from placed prop data tracking (to prevent duplication)
	table.remove(placedPropData, propDataIndex)

	-- Get the prop template from ReplicatedStorage
	local propTemplate = rep.Props:FindFirstChild(placedProp.Name)
	if not propTemplate then return end

	-- Create a new draggable version - preserve original transformations
	-- Start in Drag mode so player can move it with cursor
	dragProp = {
		Mode = "Drag",
		RefMode = propData["RefMode"],
		Prop = propTemplate:Clone(),
		Location = CFrame.new(),
		rX = propData["rX"],
		rY = propData["rY"],
		rZ = propData["rZ"],
		tX = propData["tX"],
		tY = propData["tY"],
		tZ = propData["tZ"]
	}

	-- Set up the prop container (same as when initially selecting a prop)
	local container = Instance.new("Model")
	container.Name = dragProp["Prop"].Name
	dragProp["Prop"].Name = "Prop"
	dragProp["Prop"].Parent = container
	dragProp["Prop"] = container
	local falsePrimary = dragProp["Prop"].Prop.PrimaryPart:Clone()
	falsePrimary.Parent = container
	container.PrimaryPart = falsePrimary
	ignoreList[#ignoreList + 1] = dragProp["Prop"]
	ScanProp(dragProp["Prop"])
	dragProp["Prop"].Parent = work

	-- Restore slider positions to original values from saved prop data
	for _, v in pairs({"Rot", "Translate"}) do
		for _, n in pairs({"X", "Y", "Z"}) do
			local slider = propFrame.TuningFrame:FindFirstChild(v.."Frame"..n).Slider
			local p = propData["s"..string.sub(v, 1, 1)..n]
			local absSize = (slider.Parent.AbsoluteSize.X - slider.AbsoluteSize.X)
			if v == "Rot" then
				p = ((math.deg(p) / 360) + 0.5) * absSize
			else
				p = ((p / 16) + 0.5) * absSize
			end
			slider.Position = UDim2.new(0, p, -.25, 0)
			propSlider[string.lower(string.sub(v, 1, 1))..n] = propData["s"..string.sub(v, 1, 1)..n]
		end
	end

	-- Set Location to the actual placed position (no need to calculate base)
	-- Prop can be freely edited from this position
	dragProp["Location"] = placedPropCFrame

	-- Position the container (and inner prop) at the placed location with orientation preserved
	-- Use container's PrimaryPart (falsePrimary) so the inner Prop model moves with it
	dragProp["Prop"]:SetPrimaryPartCFrame(placedPropCFrame)

	-- Create highlight with new system: Highlight instance with custom colors
	local highlight = Instance.new("Highlight")
	highlight.Adornee = dragProp["Prop"]
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(126, 193, 255)
	highlight.OutlineTransparency = 0
	highlight.Parent = dragProp["Prop"]
	dragProp["Highlight"] = highlight

	-- Don't show tuning frame initially - player is in Drag mode
	propFrame.TuningFrame.Visible = false
	propFrame.MobilePropFrame.MovementButton.Button.Text = "Drag Mode"
end

--[[ CHANGE 3: Update ModeButton handler to remove Edit mode ]]
-- Find this section and replace:
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

--[[ CHANGE 4: Update PropButton handler to restore current prop when selecting new one ]]
-- Find the PropButton handler and update it:
elseif v.Parent.Name == "PropButton" and propFrame.CountLabel.Count.Value ~= rep.PropLimit.Value and
	propFrame.ModeButton.Button.Mode.Value == "Build" then
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

	if dragProp["Mode"] then
		dragProp["Mode"] = false
		-- Remove highlight before destroying prop
		if dragProp["Highlight"] then
			dragProp["Highlight"]:Destroy()
			dragProp["Highlight"] = nil
		end
		dragProp["Prop"]:Destroy()
		dragProp["Prop"] = nil
	end
	local refMode = dragProp["RefMode"]
	if not refMode then
		refMode = "Global"
	end
	dragProp = {Mode = "Drag", RefMode = refMode, Prop = rep.Props:FindFirstChild(v.ItemName.Text):Clone(),
		Location = CFrame.new(), rX = 0, rY = 0, rZ = 0, tX = 0, tY = 0, tZ = 0}
	for _,v in pairs({"Rot", "Translate"}) do
		for _,n in pairs({"X", "Y", "Z"}) do
			local slider = propFrame.TuningFrame:FindFirstChild(v.."Frame"..n).Slider
			slider.Position = UDim2.new(0.45, 0, -.25, 0)
			propSlider[string.lower(string.sub(v, 1, 1))..n] = 0
		end
	end
	local container = Instance.new("Model")
	container.Name = dragProp["Prop"].Name
	dragProp["Prop"].Name = "Prop"
	dragProp["Prop"].Parent = container
	dragProp["Prop"] = container
	local falsePrimary = dragProp["Prop"].Prop.PrimaryPart:Clone()
	falsePrimary.Parent  = container
	container.PrimaryPart = falsePrimary
	ignoreList[#ignoreList + 1] = dragProp["Prop"]
	ScanProp(dragProp["Prop"])
	dragProp["Prop"].Parent = work

--[[ CHANGE 5: Update the initial prop selection highlight ]]
-- Find where a prop is initially selected from the list and update highlight:
-- Create highlight with new system
local highlight = Instance.new("Highlight")
highlight.Adornee = dragProp["Prop"]
highlight.FillTransparency = 1
highlight.OutlineColor = Color3.fromRGB(126, 193, 255)
highlight.OutlineTransparency = 0
highlight.Parent = dragProp["Prop"]
dragProp["Highlight"] = highlight
