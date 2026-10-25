local tool = script.Parent
local remote = tool.Remotes:WaitForChild("Shoot")
local remote2 = game.ReplicatedStorage.Remotes.ShakeCamera

local Debris = game:GetService("Debris")

local range = 500
local DAMAGE_PER_SKILL = 5
local WHEEL_DAMAGE = 5

local damageTable = {
	Head = 100,
	Torso = 35,
	["Left Arm"] = 20,
	["Right Arm"] = 20,
	["Left Leg"] = 18,
	["Right Leg"] = 18
}

local SuspensionNames = {
	SuspensionFL = true,
	SuspensionFR = true,
	SuspensionRL = true,
	SuspensionRR = true
}

local function EnableWheelVFX(wheel)
	local states = {}

	for _, obj in ipairs(wheel:GetDescendants()) do
		if obj:IsA("ParticleEmitter")
			or obj:IsA("Trail")
			or obj:IsA("Beam")
			or obj:IsA("Smoke")
			or obj:IsA("Fire")
			or obj:IsA("Sparkles")
			or obj:IsA("PointLight")
			or obj:IsA("SpotLight")
			or obj:IsA("SurfaceLight") then

			states[obj] = obj.Enabled
			obj.Enabled = true

			if obj:IsA("ParticleEmitter") then
				obj:Emit(8)
			end
		end
	end

	task.delay(0.2, function()
		for obj, oldState in pairs(states) do
			if obj and obj.Parent then
				obj.Enabled = oldState
			end
		end
	end)
end

local function DamageWheel(hit)
	local current = hit

	while current and current ~= workspace do
		if SuspensionNames[current.Name] then
			local suspension = current
			local chassis = suspension.Parent

			if not chassis or chassis.Name ~= "Chassis" then
				return false
			end

			local car = chassis.Parent

			if not car or not car:IsA("Model") then
				return false
			end

			local wheel = suspension:FindFirstChild("Wheel", true)

			if not wheel then
				return false
			end

			if hit ~= wheel and not hit:IsDescendantOf(wheel) then
				return false
			end

			local suffix = current.Name:gsub("Suspension", "")

			local body = car:FindFirstChild("Body")

			if not body then
				return false
			end

			local tireModel = body:FindFirstChild(suffix)

			if not tireModel then
				return false
			end

			local tireHealth = tireModel:FindFirstChild("TireHealth")

			if not tireHealth then
				tireHealth = Instance.new("IntValue")
				tireHealth.Name = "TireHealth"
				tireHealth.Value = 25
				tireHealth.Parent = tireModel
			end

			if tireHealth.Value <= 0 then
				return true
			end

			tireHealth.Value = math.max(
				0,
				tireHealth.Value - WHEEL_DAMAGE
			)

			EnableWheelVFX(wheel)

			print(
				"[Wheel Hit]",
				car.Name,
				suffix,
				"Health:",
				tireHealth.Value
			)

			if tireHealth.Value <= 0 then
				print(
					"[Wheel Broken]",
					car.Name,
					suffix
				)
			end

			return true
		end

		current = current.Parent
	end

	return false
end

remote.OnServerEvent:Connect(function(player, origin, direction)
	remote2:FireClient(player, 0.7)

	if typeof(origin) ~= "Vector3" then
		return
	end

	if typeof(direction) ~= "Vector3" then
		return
	end

	if direction.Magnitude <= 0 then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local bulletDamage = player:FindFirstChild("BulletDamage")
	local bonusDamage = bulletDamage and bulletDamage.Value * DAMAGE_PER_SKILL or 0

	local params = RaycastParams.new()

	params.FilterDescendantsInstances = {
		character
	}

	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local result = workspace:Raycast(
		origin,
		direction.Unit * range,
		params
	)

	if not result then
		return
	end

	local hit = result.Instance

	if not hit then
		return
	end

	-- WHEEL HIT
	if DamageWheel(hit) then
		tool.Sounds.Shoot:Play()
		return
	end

	-- NORMAL DAMAGE
	local damage = damageTable[hit.Name] or 15

	local model = hit:FindFirstAncestorOfClass("Model")

	if not model then
		return
	end

	-- PLAYER / HUMANOID
	local humanoid = model:FindFirstChildOfClass("Humanoid")

	if humanoid and humanoid.Health > 0 then
		local finalDamage = damage + bonusDamage

		humanoid:TakeDamage(finalDamage)

		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = result.Position
		attachment.Parent = workspace.Terrain

		local gui = script.BillboardGui:Clone()
		gui.Adornee = attachment
		gui.Parent = attachment
		gui.TextLabel.Text = tostring(finalDamage)

		script["sword hit"]:Play()
		tool.Sounds.Shoot:Play()

		Debris:AddItem(attachment, 0.3)

		return
	end

	-- VEHICLE DAMAGE
	local current = model

	while current do
		local health = current:FindFirstChild("Health")

		if health and health:IsA("IntValue") then
			local finalDamage = damage + bonusDamage

			health.Value -= finalDamage

			local attachment = Instance.new("Attachment")
			attachment.WorldPosition = result.Position
			attachment.Parent = workspace.Terrain

			local gui = script.BillboardGui:Clone()
			gui.Adornee = attachment
			gui.Parent = attachment
			gui.TextLabel.Text = tostring(finalDamage)

			script["sword hit"]:Play()
			tool.Sounds.Shoot:Play()

			Debris:AddItem(attachment, 0.3)

			break
		end

		current = current.Parent
	end
end)
