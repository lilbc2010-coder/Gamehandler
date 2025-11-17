-- PROP EDITING SYSTEM - ADDITIONAL UPDATES
-- This file contains updates for improved prop editing functionality

--[[ UPDATE 1: Make prop editing work after loading saves ]]
-- The issue is that loaded props aren't in the placedPropData table
-- We need to rebuild the placedPropData when clicking on a prop to edit

-- Add this helper function to extract prop data from a placed prop:
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

--[[ UPDATE 2: Modified PickUpPropForEditing to work with loaded props ]]
function PickUpPropForEditing(placedProp)
	-- Only allow editing your own props
	if placedProp.Owner.Value ~= plr.Name then
		return
	end

	-- Find or create the prop data
	local propData, propDataIndex = ExtractPropDataFromPlaced(placedProp)

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

	-- Delete the placed prop from the server
	placedProp.Owner.Value = ""
	rep.PropDelete:FireServer(placedProp)
	script.GUISounds.DeleteSound:Play()

	-- Update the prop count
	local countLabel = propFrame.CountLabel
	countLabel.Count.Value = countLabel.Count.Value - 1
	countLabel.Text = tostring(countLabel.Count.Value) .."/".. tostring(rep.PropLimit.Value)
	countLabel.TextColor3 = Color3.new(0, 0, 0)
	propFrame.Label.TextColor3 = Color3.new(0, 0, 0)

	-- Remove from placed prop data tracking if it exists (to prevent duplication)
	if propDataIndex then
		table.remove(placedPropData, propDataIndex)
	end

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

	-- Create CLIENT-SIDE ONLY highlight (only visible to you)
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

--[[ UPDATE 3: Modified ChangePropMode to reset sliders when entering Tuning Mode ]]
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
	else
		if dragProp["RefMode"] then
			if dragProp["RefMode"] == "Local" then
				dragProp["RefMode"] = "Global"
			else
				dragProp["RefMode"] = "Local"
			end
		end
	end
end

--[[ UPDATE 4: PropButton handler - restore edited prop when selecting new one ]]
-- Find this section in the PropButton click handler:
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
		-- Destroy the dragged prop
		dragProp["Prop"]:Destroy()
		dragProp["Mode"] = nil
		dragProp["Prop"] = nil
		-- Update count
		local countLabel = propFrame.CountLabel
		countLabel.Count.Value = countLabel.Count.Value + 1
		countLabel.Text = tostring(countLabel.Count.Value) .."/".. tostring(rep.PropLimit.Value)
		-- Clear editing data
		editingPropData = nil
	end

	-- Then handle regular prop selection (existing code)
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

	-- Create CLIENT-SIDE ONLY highlight
	local highlight = Instance.new("Highlight")
	highlight.Adornee = dragProp["Prop"]
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(126, 193, 255)
	highlight.OutlineTransparency = 0
	highlight.Parent = dragProp["Prop"]
	dragProp["Highlight"] = highlight

--[[ UPDATE 5: Additional ownership check in ClickAction ]]
-- Find the section where props are selected for editing:
elseif mouseState == "OwnedProp" or (mouseTarget and (platform == "Mobile" and mouseTarget.Name == "OwnedProp")) then
	-- Only allow editing/deleting your own props
	if mouseTarget.Parent.Owner.Value == plr.Name and propFrame.Visible then
		if propFrame.ModeButton.Button.Mode.Value == "Delete" and mouseTarget.Anchored then
			mouseTarget.Parent.Owner.Value = ""
			rep.PropDelete:FireServer(mouseTarget.Parent)
			script.GUISounds.DeleteSound:Play()
			local countLabel = propFrame.CountLabel
			countLabel.Count.Value = countLabel.Count.Value - 1
			countLabel.Text = tostring(countLabel.Count.Value) .."/".. tostring(rep.PropLimit.Value)
			countLabel.TextColor3 = Color3.new(0, 0, 0)
			countLabel.Parent.Label.TextColor3 = Color3.new(0, 0, 0)
		elseif dragProp["Mode"] == "Orient" and mouseTarget.Anchored then
			-- Only allow orienting your own props
			local propData
			for _,v in pairs(placedPropData) do
				if v["Prop"] == mouseTarget.Parent then
					propData = v
					break
				end
			end
			if propData then
				local primary = mouseTarget.Parent.PrimaryPart
				dragProp = {Mode = "Orient", RefMode = propData["RefMode"], Prop = dragProp["Prop"],
					Location = dragProp["Location"], rX = propData["rX"], rY = propData["rY"], rZ = propData["rZ"],
					tX = propData["tX"], tY = propData["tY"], tZ = propData["tZ"]}
				for _,v in pairs({"Rot", "Translate"}) do
					for _,n in pairs({"X", "Y", "Z"}) do
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
				dragProp["Prop"].Prop:SetPrimaryPartCFrame(dragProp["Location"] *
					CFrame.new(propSlider["tX"], propSlider["tY"], propSlider["tZ"]) *
					CFrame.Angles(propSlider["rX"], 0, propSlider["rZ"]) * CFrame.Angles(0, propSlider["rY"], 0))
			end
		end
	elseif not propFrame.Visible and mouseTarget.Parent.Owner.Value == plr.Name and mouseTarget:FindFirstChild("SignGui") and
		not (propFrame.Visible or vehicleFrame.Visible) then
		-- Sign editing (unchanged)
		local sign = mouseTarget.SignGui.Label
		txtFrame.CurrentSign.Value = sign
		txtFrame.Visible = true
		txtFrame.TextBox.Text = sign.Text
		txtFrame.ColorBoxR.Text = math.floor(sign.TextColor3.r * 255)
		txtFrame.ColorBoxG.Text = math.floor(sign.TextColor3.g * 255)
		txtFrame.ColorBoxB.Text = math.floor(sign.TextColor3.b * 255)
		txtFrame.TextSizeBox.Text = sign.TextSize
		txtFrame.TextBox.Font = sign.Font
		txtFrame.TextBox.TextColor3 = sign.TextColor3
		if sign.TextStrokeTransparency == 1 then
			txtFrame.ToggleTextStroke.Button.Text = "Text Stroke Off"
			txtFrame.TextBox.TextStrokeTransparency = 1
		else
			txtFrame.ToggleTextStroke.Button.Text = "Text Stroke On"
			txtFrame.TextBox.TextStrokeTransparency = 0
		end
		if sign.TextScaled then
			txtFrame.ToggleTextScale.Button.Text = "Text Scale On"
			txtFrame.TextBox.TextScaled = true
		else
			txtFrame.ToggleTextScale.Button.Text = "Text Scale Off"
			txtFrame.TextBox.TextScaled = false
		end
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
