-- [[ Pick Me Up! is a mod designed to enhance combine AI by allowing them to revive each other when they're down. ]]
-- [[ There's a chance a combine will spawn down, if so, other combine around them will help revive them. ]]

Sound("npc/combine_soldier/gear4.wav")

CombineList = CombineList or {
	NPCs = {},
	Other = {},
	Revivers = {},
}

function CombineList:Init()
	return self
end

function CombineList:AddNPC(ent)
	table.insert(self.NPCs, ent)
end

-- Function to calculate the distance between two vectors
local function VectorDistance(v1, v2)
	return v1:DistToSqr(v2)
end

-- Function to get the closest Combine NPCs
function CombineList:GetClosest(npc, depth)
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
		weap = "weapon_pistol"
	else
		weap = weap:GetClass()
	end

	local ct = combine:GetInternalVariable("citizentype") or nil

	Comb:AddReviver(npc, combine, combine:GetClass(), combine:GetModel(), weap, body, combine:GetSkin(), ct)
end

function CombineList:HasAReviver(npc)
	for k, v in pairs(Comb.Revivers) do
		if v.npc == npc then
			return false
		end
	end
	return false
end

Comb = CombineList:Init()
local AllowedNPCs = {
	["npc_combine_s"] = true,
	["npc_citizen"] = true,
}

local FocusCitizenType = {
	["npc_citizen"] = true,
}

hook.Add("OnEntityCreated", "PickMeUp_Add", function(ent)
	if AllowedNPCs[ent:GetClass()] then
		print("[PickMeUp] Added " .. ent:GetClass())
		Comb:AddNPC(ent)
		ent:SetNWBool("AlreadyRevived", false)
	end
end)

hook.Add("CreateEntityRagdoll", "PickMeUp_CreateEntityRagdoll", function(npc, rag)
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

-- hook.Add("OnNPCKilled", 	"PickMeUp_OnNPCKilled", function(npc, attacker, inflictor)
-- 	-- add a separate body, copying the one that just died, so we have a reference to it

-- 	local alreadyRevived = npc:GetNWBool("AlreadyRevived", false)

-- 	if alreadyRevived then return end
-- 	-- hide original ragdoll
-- 	npc:Remove()

-- 	local ragBody = ents.Create("prop_ragdoll")
-- 	ragBody:SetPos(npc:GetPos())
-- 	ragBody:SetAngles(npc:GetAngles())
-- 	ragBody:SetModel(npc:GetModel())
-- 	ragBody:SetCollisionGroup(COLLISION_GROUP_NONE) -- Set collision group to debris
-- 	ragBody:PhysicsInit(SOLID_NONE) -- Remove solid properties

-- 	ragBody:SetSkin(npc:GetSkin())
-- 	for i = 1, #npc:GetBodyGroups() do
-- 		ragBody:SetBodygroup(i, npc:GetBodygroup(i))
-- 	end
-- 	ragBody:SetVelocity(npc:GetVelocity())
-- 	ragBody:Spawn()

-- 	for id = 1,ragBody:GetPhysicsObjectCount() do
-- 		local bone = ragBody:GetPhysicsObjectNum(id - 1)
-- 		if IsValid(bone) then
-- 				local pos,angle = npc:GetBonePosition(ragBody:TranslatePhysBoneToBone(id - 1))
-- 				bone:SetPos(pos)
-- 				bone:SetAngles(angle)
-- 				bone:AddVelocity(npc:GetVelocity())

-- 				ragBody:ManipulateBoneScale(id - 1,npc:GetManipulateBoneScale(id - 1))
-- 		end
-- 	end

-- 	if table.HasValue(Comb.NPCs, npc) then
-- 		local helper = Comb:GetClosest(npc, 5)

-- 		local randomGuy = helper[1]

-- 		if randomGuy then
-- 			Comb:SetNPCToReviveAnother(randomGuy, npc, ragBody)
-- 		end

-- 		if IsValid(npc:GetActiveWeapon()) then
-- 			npc:GetActiveWeapon():Remove()
-- 		end
-- 	end
-- end)

hook.Add("Tick", "MePickUpCheck", function()
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
		local posOfDistress = v.forwho

		if posOfNpc:Distance(posOfDistress) <= 30 then
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
		end
	end
end)

print("[PickMeUp] Loaded")
