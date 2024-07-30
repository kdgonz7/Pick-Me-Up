-- [[ Pick Me Up! is a mod designed to enhance combine AI by allowing them to revive each other when they're down. ]]
-- [[ There's a chance a combine will spawn down, if so, other combine around them will help revive them. ]]

Sound("npc/combine_soldier/gear4.wav")

local ReviveDistance = CreateConVar("pickup_revive_distance", 40, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How close do NPCs have to be to revive each other?")
local SystemEnabled  = CreateConVar("pickup_system_enabled", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable the system?")
local ReviveAgainstOdds = CreateConVar("pickup_revive_underfire", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Should NPCs try to revive their team even if they're being shot at?")

CombineList = CombineList or {
	NPCs = {},
	Other = {},
	Revivers = {},
}

function CombineList:Init()
	return self
end

function CombineList:AddNPC(ent)
	if not IsValid(ent) then return end
	table.insert(self.NPCs, ent)
end

-- Function to calculate the distance between two vectors
local function VectorDistance(v1, v2)
	if not v1 or not v2 then return end
	return v1:DistToSqr(v2)
end

-- Function to get the closest Combine NPCs
function CombineList:GetClosest(npc, depth)
	if not npc then return end
	depth = depth or 5

	-- Table to store all Combine NPCs and their distances
	local combines = {}

	-- Iterate through all entities
	for _, ent in ipairs(ents.GetAll()) do
		-- if the near one is the same class, we add it
		-- we don't add ourselves.
		if ent:GetClass() == npc:GetClass() && ent != npc then
				-- Calculate the distance from the entity to the specified position
				local distance = VectorDistance(npc:GetPos(), ent:GetPos())
				table.insert(combines, {npc = ent, dist = distance})
		end
	end

	-- Sort the table based on the distances
	table.sort(combines, function(a, b) return a.dist < b.dist end)

	-- Table to store the closest combines
	local closest = {}

	-- Select the closest combines based on the depth
	for i = 1, math.min(depth, #combines) do
			table.insert(closest, combines[i].npc)
	end

	return closest
end

function CombineList:AddReviver(npc, forwho, entity_class, entity_model, entity_weapon, body, skins, citizentype)
	citizentype = citizentype or nil
	table.insert(self.Revivers, {npc = npc, forwho = forwho:GetPos(), forwho_info = {class = entity_class, model = entity_model, weapon = entity_weapon, body = body, skins = skins, N = forwho, citizentype = citizentype}})
end

function CombineList:SetNPCToReviveAnother(npc, combine, body)
	if not npc then return end
	if not combine then return end
	if not body then return end
	-- force npc to run to combine position
	npc:SetLastPosition(body:GetPos())
	npc:SetSaveValue("m_vecLastPosition", body:GetPos())
	npc:ClearSchedule()
	npc:SetSchedule(SCHED_FORCED_GO)
	npc:SetMovementActivity( ACT_RUN_CROUCH )
	npc:SetTarget(body)

	-- add reviver
	local weap = combine:GetActiveWeapon()
	if not IsValid(weap) then
		weap = "weapon_smg1"
	else
		weap = weap:GetClass()
	end

	local ct = combine:GetInternalVariable("citizentype") or nil

	Comb:AddReviver(npc, combine, combine:GetClass(), combine:GetModel(), weap, body, combine:GetSkin(), ct)
end

function CombineList:HasAReviver(npc)
	if not npc then return false end

	for k, v in pairs(Comb.Revivers) do
		if v.npc == npc then
			return false
		end
	end
	return false
end

Comb = CombineList:Init()

-- NPCs that are allowed to revive each other
local AllowedNPCs = {
	["npc_combine_s"] = true,
	["npc_citizen"] = true,
}

-- add the NPC to the pool
hook.Add("OnEntityCreated", "PickMeUp_Add", function(ent)
	if not IsValid(ent) then return end
	if not SystemEnabled:GetBool() then return end

	if AllowedNPCs[ent:GetClass()] then
		print("[PickMeUp] Added " .. ent:GetClass())
		Comb:AddNPC(ent)
		ent:SetNWBool("AlreadyRevived", false)
	end
end)

-- when a entity dies, get it revived
hook.Add("CreateEntityRagdoll", "PickMeUp_CreateEntityRagdoll", function(npc, rag)
	if not IsValid(npc) then return end
	if not IsValid(rag) then return end
	if not SystemEnabled:GetBool() then return end

	-- i realized after all this time, the system should've just been created in the CreateEntityRagdoll hook.
	-- i'm so stupid.
	local alreadyRevived = npc:GetNWBool("AlreadyRevived", false)
	if alreadyRevived then return end
	-- hide original ragdoll

	if table.HasValue(Comb.NPCs, npc) then
		local helper = Comb:GetClosest(npc, 5)

		local randomGuy = helper[1]

		if randomGuy then
			Comb:SetNPCToReviveAnother(randomGuy, npc, rag)
		end

		if IsValid(npc:GetActiveWeapon()) then
			npc:GetActiveWeapon():Remove()
		end
	end
end)

hook.Add("Tick", "MePickUpCheck", function()
	if not Comb.Revivers then return end
	if #Comb.Revivers == 0 then return end
	if not SystemEnabled:GetBool() then return end

	for k, v in pairs(Comb.Revivers) do
		if not IsValid(v.npc) then
			table.remove(Comb.Revivers, k)
			continue
		end

		if not v.npc then
			table.remove(Comb.Revivers, k)
			continue
		end

		local posOfNpc = v.npc:GetPos()
		local posOfDistress = v.forwho_info.body:GetPos() -- use the position of the body instead

		-- if the npc is near the one we need to help
		-- initiate revive sequence
		if posOfNpc:Distance(posOfDistress) <= ReviveDistance:GetInt() then
			if not ReviveAgainstOdds:GetBool() && v.npc:GetCurrentSchedule() == SCHED_FORCED_GO then
				continue
			end

			v.npc:SetSchedule(SCHED_IDLE_STAND)
			v.npc:SetIdealActivity( ACT_CROUCHIDLE )

			local seq = (v.npc:LookupSequence("pickup") != -1 && "pickup") or "combat_stand_to_crouch"

			v.npc:StopMoving()
			v.npc:ClearSchedule()
			v.npc:AddGestureSequence( v.npc:LookupSequence(seq), true )
			v.npc:SetPlaybackRate(0.01)
			v.npc:EmitSound("npc/combine_soldier/gear4.wav", 100)
			v.npc:SetAngles(Angle(0, v.forwho_info.body:GetAngles().y, 0))

			timer.Simple(0.5, function()
				if not v.npc then
					return
				end

				if v.npc:IsValid() then
					v.npc:SetSchedule(SCHED_IDLE_WALK)
					v.npc:SetIdealActivity( ACT_RUN_AGITATED )
				end
				timer.Simple(0, function()
					if (IsValid(v.npc)) then
						local e = ents.Create(v.forwho_info.class)

						e:SetModel(v.forwho_info.body:GetModel())
						e:SetSkin(v.forwho_info.body:GetSkin())
						e:SetPos(v.forwho_info.body:GetPos())
						if v.forwho_info.citizentype then
							e:SetSaveValue("citizentype", v.forwho_info.citizentype)
						end
						e:Give(v.forwho_info.weapon)

						for i = 1, #v.forwho_info.body:GetBodyGroups() do
							e:SetBodygroup(i, e:GetBodygroup(i))
						end

						-- disable body collision
						v.forwho_info.body:Remove()
						e:Spawn()
						e:SetNWBool("AlreadyRevived", true)
					end
					if not v.npc then return end
				end)
			end)
			table.remove(Comb.Revivers, k)
		else
			if v.npc:GetCurrentSchedule() != SCHED_FORCED_GO then
				local bodyPos = v.forwho_info.body:GetPos()

				v.npc:SetSaveValue("m_vecLastPosition", bodyPos)
				v.npc:SetLastPosition(bodyPos)
				v.npc:ClearSchedule()
				v.npc:SetSchedule(SCHED_FORCED_GO)
				v.npc:SetIdealActivity( ACT_RUN_CROUCH )
			end
		end
	end
end)

print("[PickMeUp] Loaded")
