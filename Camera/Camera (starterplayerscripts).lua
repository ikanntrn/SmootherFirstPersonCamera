

---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ----

local players = game:GetService("Players")
local runService = game:GetService("RunService")
local input = game:GetService("UserInputService")
local starterPlayer = game:GetService("StarterPlayer")
local replicatedStorage = game:GetService("ReplicatedStorage")

-- Get the local player and their character (wait for it to be added if it hasn't already)
local player = players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local human = character:WaitForChild("Humanoid")
local humanoidpart = character:WaitForChild("HumanoidRootPart")
local head = character:WaitForChild("Head")
local cam = game.Workspace.CurrentCamera

-- ======== EVENT SETUP ========
-- Waits for the events in ReplicatedStorage needed for camera control
local cameraEvents = replicatedStorage:WaitForChild("CameraEvents")
local lockCamEvent = cameraEvents:WaitForChild("LockCam")
local unlockCamEvent = cameraEvents:WaitForChild("UnlockCam")

-- ======== SETTINGS ========
-- You can mess with these settings

-- Lets you move your mouse around in first-person
local CanToggleMouse = {allowed = true; activationkey = Enum.KeyCode.F;}
-- Whether you see your body in first person
local CanViewBody = true
-- Mouse sensitivity. Anything higher makes looking up/down harder. Recommend 0 to 1.
local Sensitivity = 0.4
-- Camera smoothness. Recommend 0 to 1.
local Smoothness = 0.1
-- Default Field of View
local FieldOfView = 80
-- How far your camera is from your head
local HeadOffset = CFrame.new(0, 0.7, 0)

-- Walk speed settings
local walkspeeds = {
	enabled =		  true;
	walkingspeed =		16;
	backwardsspeed =	10;
	sidewaysspeed =		15;
	diagonalspeed =		16;
	runningspeed =		25;
	runningFOV=			85;
}
-- How quickly speed and FOV changes are eased. Recommend 0 to 1.
local easingtime = 0.1

---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ----

-- Local variables for camera logic
local AngleX, TargetAngleX = 0, 0
local AngleY, TargetAngleY = 0, 0
local running = true
local freemouse = false
local isForceLocked = false -- NEW: Tracks if the camera is locked by a forced event
local defFOV = FieldOfView

-- Input state variables
local w, a, s, d, lshift = false, false, false, false, false

-- Replace mouse icon
input.MouseIcon = "http://www.roblox.com/asset/?id=569021388"

---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ----

-- This function makes the player's character parts transparent for first-person view.
function updatechar()
	for _, v in pairs(character:GetChildren()) do
		if v:IsA("BasePart") or v:IsA("UnionOperation") then
			if CanViewBody then
				if v.Name == 'Head' then
					v.LocalTransparencyModifier = 1
					v.CanCollide = false
					-- FIX: Check if the 'face' decal exists before trying to modify it.
					-- This prevents errors on modern characters that don't have it.
					local faceDecal = v:FindFirstChild("face")
					if faceDecal then
						faceDecal.LocalTransparencyModifier = 1
					end
				end
			else
				-- If body isn't viewable, make all parts transparent.
				v.LocalTransparencyModifier = 1
				v.CanCollide = false
			end
		end

		if v:IsA("Accessory") then
			local handle = v:FindFirstChild("Handle")
			if handle then
				handle.LocalTransparencyModifier = 1
				handle.CanCollide = false
			end
		end
	end
end

-- Linear interpolation function for smooth transitions
function lerp(a, b, t)
	return a + (b - a) * t
end

---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ----

-- Listen for camera lock/unlock events
lockCamEvent.OnClientEvent:Connect(function(forced)
	forced = forced or false -- Default to not forced if not specified
	freemouse = false -- Lock the camera
	if forced then
		isForceLocked = true -- Set the forced lock state
	end
end)

unlockCamEvent.OnClientEvent:Connect(function(forced)
	-- Any unlock event will break a forced lock
	isForceLocked = false
	freemouse = true -- Unlock the camera
end)

---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ----

input.InputChanged:Connect(function(inputObject, gameProcessed)
	if gameProcessed then return end

	if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = Vector2.new(inputObject.Delta.x / Sensitivity, inputObject.Delta.y / Sensitivity) * Smoothness

		local X = TargetAngleX - delta.y
		TargetAngleX = math.clamp(X, -80, 80)
		TargetAngleY = (TargetAngleY - delta.x) % 360
	end
end)

input.InputBegan:Connect(function(inputObject, gameProcessed)
	if gameProcessed then return end

	-- Player can only toggle the mouse if it's allowed AND not force-locked
	if inputObject.KeyCode == CanToggleMouse.activationkey then
		if CanToggleMouse.allowed and not isForceLocked then
			freemouse = not freemouse -- Toggle the free mouse state
		end
	end

	-- Update movement key states
	if inputObject.KeyCode == Enum.KeyCode.W then w = true end
	if inputObject.KeyCode == Enum.KeyCode.A then a = true end
	if inputObject.KeyCode == Enum.KeyCode.S then s = true end
	if inputObject.KeyCode == Enum.KeyCode.D then d = true end
	if inputObject.KeyCode == Enum.KeyCode.LeftShift then lshift = true end
end)

input.InputEnded:Connect(function(inputObject, gameProcessed)
	if gameProcessed then return end

	-- Update movement key states
	if inputObject.KeyCode == Enum.KeyCode.W then w = false end
	if inputObject.KeyCode == Enum.KeyCode.A then a = false end
	if inputObject.KeyCode == Enum.KeyCode.S then s = false end
	if inputObject.KeyCode == Enum.KeyCode.D then d = false end
	if inputObject.KeyCode == Enum.KeyCode.LeftShift then lshift = false end
end)

---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ----

runService.RenderStepped:Connect(function(dt)

	-- Check if the camera is inside a part, and if so, "zoom out" by disabling the script
	if (cam.Focus.Position - cam.CFrame.Position).Magnitude < 1 then
		running = false
	else
		running = true
	end

	if running then
		updatechar()

		AngleX = lerp(AngleX, TargetAngleX, 0.35)
		local dist = TargetAngleY - AngleY
		if math.abs(dist) > 180 then
			dist = dist - (dist / math.abs(dist)) * 360
		end
		AngleY = (AngleY + dist * 0.35) % 360

		cam.CameraType = Enum.CameraType.Scriptable

		cam.CFrame = CFrame.new(head.Position)
			* CFrame.Angles(0, math.rad(AngleY), 0)
			* CFrame.Angles(math.rad(AngleX), 0, 0)
			* HeadOffset

		humanoidpart.CFrame = CFrame.new(humanoidpart.Position) * CFrame.Angles(0, math.rad(AngleY), 0)

		-- Handle mouse lock state
		if freemouse then
			input.MouseBehavior = Enum.MouseBehavior.Default
		else
			input.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
	else
		input.MouseBehavior = Enum.MouseBehavior.Default
	end

	if walkspeeds.enabled then
		local targetSpeed = walkspeeds.walkingspeed
		local targetFOV = defFOV

		local isSprinting = lshift and w and not s

		if isSprinting then
			targetSpeed = walkspeeds.runningspeed
			targetFOV = walkspeeds.runningFOV
		elseif w and not s then
			targetSpeed = (a or d) and walkspeeds.diagonalspeed or walkspeeds.walkingspeed
		elseif s and not w then
			targetSpeed = (a or d) and walkspeeds.diagonalspeed or walkspeeds.backwardsspeed
		elseif (a or d) and not (w or s) then
			targetSpeed = walkspeeds.sidewaysspeed
		end

		human.WalkSpeed = lerp(human.WalkSpeed, targetSpeed, easingtime)
		cam.FieldOfView = lerp(cam.FieldOfView, targetFOV, easingtime)
	else
		cam.FieldOfView = lerp(cam.FieldOfView, defFOV, easingtime)
	end
end)
