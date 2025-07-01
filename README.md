# SmootherFirstPersonCamera
A feature-rich, client-sided first-person camera and character movement script for Roblox, designed for smooth gameplay and easy customization. This controller offers a more immersive and responsive alternative to the default Roblox camera and movement systems.

Of course! This is a great script with excellent comments. Here is a conversion of that information into a comprehensive `README.md` file for GitHub.

---

# Enhanced First-Person Camera & Zone System

> **tl;dr:** Don't ungroup anything, just put the scripts and events in the correct services and it will work!

## Overview

This repository contains a complete, client-side first-person camera system and a powerful server-side example script for creating trigger zones. The system is designed to be highly customizable, immersive, and easy to integrate into any Roblox experience.

*   **The Client Script (The Camera):** An enhanced `LocalScript` that takes full control of the player's camera to provide a smooth, modern first-person experience with features like head bob, sprinting, dynamic FOV, and remote-controlled locking.
*   **The Server Script (The Zone Manager):** An example `Script` that demonstrates how to use the camera's API. It allows developers to create trigger zones that can lock/unlock a player's camera and movement simply by tagging parts in the workspace.

## ✨ Features

*   **Centralized Configuration:** All settings are in a single `Config` table for easy edits.
*   **Frame-Rate Independent Smoothing:** Camera movement, FOV changes, and head bob are smooth and consistent on all devices.
*   **Immersive Head Bob:** Customizable camera sway when walking and running to enhance immersion.
*   **Remote Control API:** The camera can be locked and unlocked via `RemoteEvent`s, perfect for cutscenes, tutorials, or UI interactions.
*   **Powerful Zone System:** Use the provided server script to create trigger zones with custom behaviors using Studio's built-in Tag Editor and Attributes.
*   **Clean & Readable Code:** All scripts are heavily commented and refactored for readability and maintainability.

## 🛠️ Setup and Installation

Follow these steps to get the system running in your game.

### Step 1: Place the Scripts

1.  **Client Script:** Place the main camera `LocalScript` (the one with the camera logic) into **`StarterPlayer` -> `StarterPlayerScripts`**.
2.  **Server Script:** Place the `Camera & Movement Lock Zone Manager` script (the code provided in this README) into **`ServerScriptService`**.

### Step 2: Create Remote Events

The client and server scripts communicate using `RemoteEvent`s. You must create these for the system to work.

1.  Create a **`Folder`** inside **`ReplicatedStorage`** and name it `CameraEvents`.
2.  Inside the `CameraEvents` folder, create two **`RemoteEvent`s** and name them:
    *   `LockCam`
    *   `UnlockCam`

The final structure should look like this:
```lua
ReplicatedStorage
└── CameraEvents (Folder)
    ├── LockCam (RemoteEvent)
    └── UnlockCam (RemoteEvent)
```

### Step 3: Tag Your Zone Parts

The server script uses the **Tag Editor** to identify which parts are trigger zones.

1.  In Studio, go to the **VIEW** tab and open the **Tag Editor** window.
2.  In the Tag Editor, click the "Add Tag" button and create a new tag named exactly `CameraLockZone`.
3.  Select any part(s) in the workspace that you want to function as a trigger zone.
4.  With the part(s) selected, check the box next to `CameraLockZone` in the Tag Editor to assign the tag.



## ⚙️ How to Use: The Zone Manager

Any part tagged with `CameraLockZone` will now automatically lock the player's camera when they enter it and unlock it when they leave. You can further customize the behavior of each zone by adding **Attributes** to the tagged part.

### Customizing Zones with Attributes

Select a tagged part. In the Properties window, scroll to the very bottom and click **"Add Attribute"**.

| Attribute Name | Type    | Description                                                                                              |
| :------------- | :------ | :------------------------------------------------------------------------------------------------------- |
| `ForcedLock`   | Boolean | If `true`, the player **cannot** use their manual keybind to unlock the camera while inside this zone.   |
| `LockMovement` | Boolean | If `true`, the player's character will be frozen (WalkSpeed and JumpPower set to 0) while inside the zone. |

If an attribute is not added to a part, it will default to `false`.

---

## Example Server Script: `Camera & Movement Lock Zone Manager`

This is the full code for the server-side script. Place it in `ServerScriptService`.

```lua
-- // 1. SETUP //
-- We get all the necessary services and define our variables here.

-- Services are like toolboxes that Roblox gives us to work with different parts of the game.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- This is the tag we will look for on parts. It must match the tag you create in the Tag Editor.
local CAMERA_ZONE_TAG = "CameraLockZone"

-- We need to find the RemoteEvents that the main camera script is listening for.
local cameraEventsFolder = ReplicatedStorage:WaitForChild("CameraEvents")
local lockCamEvent = cameraEventsFolder:WaitForChild("LockCam")
local unlockCamEvent = cameraEventsFolder:WaitForChild("UnlockCam")

-- This table will keep track of which player is in which zone.
-- This is important to prevent bugs and ensure events fire correctly. It's our "memory".
local playersInZones = {}
local originalPlayerSpeeds = {} -- Remembers a player's speed so we can restore it later.

----------------------------------------------------------------------------------------------------

-- // 2. THE LOGIC //
-- This single function contains all the logic for making one zone part work.

local function setupZone(zonePart)

	print("Found a part named '"..zonePart.Name.."' and setting it up as a CameraLockZone.")
	local originalColor = zonePart.Color -- Remember the part's starting color.

	-- This function runs when a player's character FIRST touches the zone.
	local function onPlayerEnterZone(otherPart)
		-- The 'otherPart' is whatever hit the zone (e.g., a "LeftFoot" or "Arm").
		-- Its Parent is the character model.
		local character = otherPart.Parent

		-- We can get the actual Player object from their character model.
		local playerWhoTouched = Players:GetPlayerFromCharacter(character)

		-- --- Safety Checks ---
		-- 1. Was it actually a player? (not an NPC or random falling part)
		-- 2. Is this player already inside a zone? (If so, we do nothing to avoid bugs).
		if not playerWhoTouched or playersInZones[playerWhoTouched] then
			return
		end

		-- If the checks pass, we remember that this player is now inside this specific zone.
		playersInZones[playerWhoTouched] = zonePart

		-- --- Read Custom Settings from Attributes ---
		-- We'll get the custom settings from the part's Attributes.
		-- If an attribute doesn't exist, we use a default value (false).
		local isForced = zonePart:GetAttribute("ForcedLock") or false
		local shouldLockMovement = zonePart:GetAttribute("LockMovement") or false

		print(`Player '{playerWhoTouched.Name}' entered zone '{zonePart.Name}'. Firing LockCam event.`)

		-- Fire the "LockCam" event TO THE CLIENT, telling the main camera script to lock.
		-- We pass 'isForced' so the camera script knows if the player can unlock it themselves.
		lockCamEvent:FireClient(playerWhoTouched, isForced)

		-- If the "LockMovement" attribute was true, we freeze the player.
		if shouldLockMovement then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				-- We must save their original speed first!
				originalPlayerSpeeds[playerWhoTouched] = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower }
				humanoid.WalkSpeed = 0
				humanoid.JumpPower = 0
			end
		end
	end

	-- This function runs when a player's character STOPS touching the zone.
	local function onPlayerLeaveZone(otherPart)
		local character = otherPart.Parent
		local playerWhoTouched = Players:GetPlayerFromCharacter(character)

		-- --- Safety Checks ---
		-- 1. Was it a player?
		-- 2. Is this the same player we remembered entering this zone? (Prevents a player leaving a zone they weren't in).
		if not playerWhoTouched or playersInZones[playerWhoTouched] ~= zonePart then
			return
		end

		-- The player has left the zone, so we can remove them from our memory.
		playersInZones[playerWhoTouched] = nil

		print(`Player '{playerWhoTouched.Name}' left zone '{zonePart.Name}'. Firing UnlockCam event.`)

		-- Fire the "UnlockCam" event TO THE CLIENT, telling the camera script to unlock.
		unlockCamEvent:FireClient(playerWhoTouched)

		-- If we froze the player's movement, we now restore it.
		if originalPlayerSpeeds[playerWhoTouched] then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = originalPlayerSpeeds[playerWhoTouched].WalkSpeed
				humanoid.JumpPower = originalPlayerSpeeds[playerWhoTouched].JumpPower
				originalPlayerSpeeds[playerWhoTouched] = nil -- Clean up the saved data.
			end
		end
	end

	-- We connect our functions to the part's Touched and TouchEnded events.
	zonePart.Touched:Connect(onPlayerEnterZone)
	zonePart.TouchEnded:Connect(onPlayerLeaveZone)
end

----------------------------------------------------------------------------------------------------

-- // 3. ACTIVATION //
-- This code runs when the script starts. It finds all parts with the special tag and sets them up.

-- First, find all parts that are ALREADY tagged when the game starts.
for _, part in ipairs(CollectionService:GetTagged(CAMERA_ZONE_TAG)) do
	setupZone(part)
end

-- Then, listen for any NEW parts that get tagged while the game is running.
CollectionService:GetInstanceAddedSignal(CAMERA_ZONE_TAG):Connect(setupZone)

print("Camera Zone Manager [Example Script] is running and waiting for players...")

```

## Credits

*   **Original Script Concept:** WhoBloxxedWho
*   **Panner Script Elements:** DoogleFox
*   **Original Compilation & Updates:** DuruTeru
*   **Modernization, Refactoring & Zone System:** KanniiCom
