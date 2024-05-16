local function OnAttackCommonFn(inst, owner, target)
    if owner.components.rider and owner.components.rider:IsRiding() then
        return
    end

    if not inst.weaponstatus and inst:HasTag("iai") then
        inst.UnsheathMode(inst)
        if target.components.combat ~= nil then
            target.components.combat:GetAttacked(owner, inst.components.weapon.damage * .8)
        end
    end

    if owner:HasTag("kenjutsu") and not inst:HasTag("mkatana") then
        inst:AddTag("mkatana")
    end

    if math.random(1,4) == 1 then
        local x = math.random(1, 1.2)
        local y = math.random(1, 1.2)
        local z = math.random(1, 1.2)
        local slash = {"shadowstrike_slash_fx","shadowstrike_slash2_fx"}

        slash = SpawnPrefab(slash[math.random(1,2)])
        slash.Transform:SetPosition(target:GetPosition():Get())
        slash.Transform:SetScale(x, y, z)
    end

    inst.components.weapon.attackwear = (inst.IsShadow(target) or inst.IsLunar(target)) and TUNING.GLASSCUTTER.SHADOW_WEAR or 1
end

local function GroundPoundFx(inst, scale)
    local x, y, z = inst.Transform:GetWorldPosition()
    local fx = SpawnPrefab("groundpoundring_fx")
    fx.Transform:SetScale(scale, scale, scale)
    fx.Transform:SetPosition(x, y, z)
end

local function SlashFx(inst, target, prefab, scale)
    local fx = SpawnPrefab(prefab)
    fx.Transform:SetScale(scale, scale, scale)
    fx.Transform:SetPosition(target:GetPosition():Get())
    inst.SoundEmitter:PlaySound("turnoftides/common/together/moon_glass/mine")
    inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
end

local function AoeAttack(inst, damage, range)
    local CANT_TAGS = { "INLIMBO", "invisible", "NOCLICK",}
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, range, nil, CANT_TAGS)
    local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)

    for _ ,v in pairs(ents) do
        if (v and v:HasTag("bird")) then
            v.sg:GoToState("stunned")
        end

        if v ~= nil and not v:IsInLimbo() and v:IsValid() and v.components.health ~= nil and v.components.combat ~= nil and not v.components.health:IsDead() then
            if not (v:HasTag("player") or v:HasTag("structure") or v:HasTag("companion") or v:HasTag("abigial") or v:HasTag("wall")) then
                if weapon ~= nil then
                    v.components.combat:GetAttacked(inst, weapon.components.weapon.damage*damage)
                end
                if v.components.freezable ~= nil then
                    v.components.freezable:SpawnShatterFX()
                end
            end
        elseif v ~= nil and v:HasTag("tree") or v:HasTag("stump") and not v:HasTag("structure") then
            if v.components.workable ~= nil then
                v.components.workable:WorkedBy(inst, 10)
            end
        end
    end
end

local function AddFollowerFx(inst, prefab, scale)
    local fx = SpawnPrefab(prefab)
    fx.entity:AddFollower()
    fx.Follower:FollowSymbol(inst.GUID, "swap_body", 0, 0, 0)
    if scale ~= nil then
        fx.Transform:SetScale(scale, scale, scale)
    end
end

local function Skill_CommonFn(tag, name, time, mindpower, fn)
    return function(inst)
        if inst.components.skillreleaser:CanUseSkill(inst.components.combat.target) then
            inst.sg:GoToState("idle")
            inst.components.skillreleaser:SkillRemove()
            inst:DoTaskInTime(.3, function()
                inst.components.talker:Say(STRINGS.SKILL.REFUSE_RELEASE)
            end)
            return
        end

        if inst.mafterskillndm ~= nil then
            inst.mafterskillndm:Cancel()
            inst.mafterskillndm = nil
        end

        fn(inst)

        inst.components.kenjutsuka:SetMindpower(inst.components.kenjutsuka:GetMindpower() - mindpower)
        inst.components.timer:StartTimer(name, time)

        inst:RemoveTag(tag)
    end
end

local ARC = 90 * DEGREES
local AOE_RANGE_PADDING = 3
local AOE_TARGET_MUSTHAVE_TAGS = { "_combat" }
local AOE_TARGET_CANT_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack" }
local MAX_SIDE_TOSS_STR = 0.8

local SWIPE_OFFSET = 2
local SWIPE_RADIUS = 3.5

local function DoArcAttack(inst, dist, radius, heavymult, mult, targets)
	inst.components.combat.ignorehitrange = true
	local x, y, z = inst.Transform:GetWorldPosition()
	local rot = inst.Transform:GetRotation() * DEGREES
	local x0, z0
	if dist ~= 0 then
		if dist > 0 and ((mult ~= nil and mult > 1) or (heavymult ~= nil and heavymult > 1)) then
			x0, z0 = x, z
		end
		x = x + dist * math.cos(rot)
		z = z - dist * math.sin(rot)
	end
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RANGE_PADDING, AOE_TARGET_MUSTHAVE_TAGS, AOE_TARGET_CANT_TAGS)) do
		if v ~= inst and
			not (targets ~= nil and targets[v]) and
			v:IsValid() and not v:IsInLimbo()
			and not (v.components.health ~= nil and v.components.health:IsDead())
		then
			local range = radius + v:GetPhysicsRadius(0)
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			local dx = x1 - x
			local dz = z1 - z
			local distsq = dx * dx + dz * dz
			if distsq > 0 and distsq < range * range and
				DiffAngleRad(rot, math.atan2(-dz, dx)) < ARC and
				inst.components.combat:CanTarget(v)
			then
				inst.components.combat:DoAttack(v)
				if mult ~= nil then
					local strengthmult = (v.components.inventory ~= nil and v.components.inventory:ArmorHasTag("heavyarmor") or v:HasTag("heavybody")) and heavymult or mult
					if strengthmult > MAX_SIDE_TOSS_STR and x0 ~= nil then
						dx = x1 - x0
						dz = z1 - z0
						if dx ~= 0 or dz ~= 0 then
							local rot1 = math.atan2(-dz, dx) + PI
							local k = math.max(0, math.cos(math.min(PI, DiffAngleRad(rot1, rot) * 2)))
							strengthmult = MAX_SIDE_TOSS_STR + (strengthmult - MAX_SIDE_TOSS_STR) * k * k
						end
					end
				end
				if targets ~= nil then
					targets[v] = true
				end
			end
		end
	end
	inst.components.combat.ignorehitrange = false
end

return {
    DoArcAttack = DoArcAttack,
    OnAttackCommonFn = OnAttackCommonFn,
    SlashFx = SlashFx,
    GroundPoundFx = GroundPoundFx,
    AoeAttack = AoeAttack,
    AddFollowerFx = AddFollowerFx,
    Skill_CommonFn = Skill_CommonFn,
}
