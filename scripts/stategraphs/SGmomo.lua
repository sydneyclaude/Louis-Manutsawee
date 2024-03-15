require("stategraphs/commonstates")
local SkillUtil = require("utils/skillutil")

local function ToggleOffPhysics(inst)
    inst.sg.statemem.isphysicstoggle = true
    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.GROUND)
end

local function ToggleOnPhysics(inst)
    inst.sg.statemem.isphysicstoggle = nil
    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.WORLD)
    inst.Physics:CollidesWith(COLLISION.OBSTACLES)
    inst.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)
    inst.Physics:CollidesWith(COLLISION.CHARACTERS)
    inst.Physics:CollidesWith(COLLISION.GIANTS)
end

local function DoWortoxPortalTint(inst, val)
    if val > 0 then
        inst.components.colouradder:PushColour("portaltint", 154 / 255 * val, 23 / 255 * val, 19 / 255 * val, 0)
        val = 1 - val
        inst.AnimState:SetMultColour(val, val, val, 1)
    else
        inst.components.colouradder:PopColour("portaltint")
        inst.AnimState:SetMultColour(1, 1, 1, 1)
    end
end

local function DoTalkSound(inst)
    inst.SoundEmitter:PlaySound((inst.talker_path_override or "dontstarve/characters/")..(inst.soundsname or inst.prefab).."/talk_LP", "talk")
end

local function DoHurtSound(inst)
    inst.SoundEmitter:PlaySound((inst.talker_path_override or "dontstarve/characters/")..(inst.soundsname or inst.prefab).."/hurt", nil, inst.hurtsoundvolume)
end

local function DoYawnSound(inst)
    inst.SoundEmitter:PlaySound((inst.talker_path_override or "dontstarve/characters/")..(inst.soundsname or inst.prefab).."/yawn")
end

local function StopTalkSound(inst, instant)
    if inst.SoundEmitter:PlayingSound("talk") then
        if not instant and inst.endtalksound then
            inst.SoundEmitter:PlaySound(inst.endtalksound)
        end
        inst.SoundEmitter:KillSound("talk")
    end
end

local function DoMountSound(inst, mount, sound, ispredicted)
    if mount ~= nil and mount.sounds ~= nil then
        inst.SoundEmitter:PlaySound(mount.sounds[sound], nil, nil, ispredicted)
    end
end

local function SkillCollision(inst, enable)
    inst.Physics:ClearCollisionMask()
    if enable then
        inst.Physics:CollidesWith(COLLISION.WORLD)
        inst.Physics:CollidesWith(COLLISION.GROUND)
    else
        inst.Physics:CollidesWith(COLLISION.WORLD)
        inst.Physics:CollidesWith(COLLISION.OBSTACLES)
        inst.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)
        inst.Physics:CollidesWith(COLLISION.CHARACTERS)
        inst.Physics:CollidesWith(COLLISION.GIANTS)
    end
end

local function GetUnequipState(inst, data)
    return (data.eslot ~= EQUIPSLOTS.HANDS and "item_hat")
        or (not data.slip and "item_in"), data.item
end

local function StartTeleporting(inst)
    inst.sg.statemem.isteleporting = true

    inst.components.health:SetInvincible(true)
    if inst.components.playercontroller ~= nil then
        inst.components.playercontroller:Enable(false)
    end
    inst:Hide()
    inst.DynamicShadow:Enable(false)
end

local function DoneTeleporting(inst)
    inst.sg.statemem.isteleporting = false

    inst.components.health:SetInvincible(false)
    if inst.components.playercontroller ~= nil then
        inst.components.playercontroller:Enable(true)
    end
    inst:Show()
    inst.DynamicShadow:Enable(true)
end

local NOTENTCHECK_CANT_TAGS = { "FX", "INLIMBO" }

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function NoEntCheckFn(pt)
    return NoHoles(pt) and #TheSim:FindEntities(pt.x, pt.y, pt.z, 1, nil, NOTENTCHECK_CANT_TAGS) == 0
end

local function SpawnPortalEntrance(inst)
    local pt = inst:GetPosition()
    local offset = FindWalkableOffset(pt, math.random() * 2 * PI, 3 + math.random(), 16, false, true, NoEntCheckFn, true, true)
                    or FindWalkableOffset(pt, math.random() * 2 * PI, 5 + math.random(), 16, false, true, NoEntCheckFn, true, true)
                    or FindWalkableOffset(pt, math.random() * 2 * PI, 7 + math.random(), 16, false, true, NoEntCheckFn, true, true)
    if offset ~= nil then
        pt = pt + offset
    end

    local portal = SpawnPrefab("pocketwatch_portal_entrance")
    portal.Transform:SetPosition(pt:Get())
    inst.SoundEmitter:PlaySound("wanda1/wanda/portal_entrance_pre")
    return portal
end

local function CalculateLandPoint(pt, radius)
    radius = radius or 8
    if not TheWorld.Map:IsAboveGroundAtPoint(pt:Get()) then
        pt = FindNearbyLand(pt, 1) or pt
    end
    local offset = FindWalkableOffset(pt, math.random() * 2 * PI, radius, 12, true, true, NoHoles)
    if offset ~= nil then
        offset.x = offset.x + pt.x
        offset.z = offset.z + pt.z
        return offset
    end
end

local actionhandlers = {
    ActionHandler(ACTIONS.GIVE, "give"),
    ActionHandler(ACTIONS.SLEEPIN, function(inst, action)
        if action.invobject ~= nil then
            if action.invobject.onuse ~= nil then
                action.invobject:onuse(inst)
            end
            return "bedroll"
        else
            return "tent"
        end
    end),
}

local events = {
    CommonHandlers.OnLocomote(true, false),
    CommonHandlers.OnAttacked(),
    EventHandler("ontalk", function(inst, data)
        if inst.sg:HasStateTag("idle") and not inst.sg:HasStateTag("notalking") then
            inst.sg:GoToState("talk", data.noanim)
		end
    end),
    EventHandler("use_portal_jumpin", function(inst, data)
        inst.sg:GoToState("portal_jumpin_pre", data)
    end),
    EventHandler("use_pocketwatch", function(inst, data)
        if data ~= nil then
            local watch = data.watch
            if watch ~= nil then
                inst.sg:GoToState((watch:HasTag("pocketwatch_warp_casting" and "pocketwatch_warpback_pre")
                or "pocketwatch_cast"), watch)
            end
        end
    end),
    EventHandler("use_pocketwatch_portal", function(inst, data)
        inst.sg:GoToState("pocketwatch_openportal", data)
    end),
    EventHandler("releaselight", function(inst, data)
        inst.sg:GoToState("releaselight", data)
    end),
    EventHandler("dance", function(inst)
        if not inst.sg:HasStateTag("busy") and (not inst.sg:HasStateTag("dancing")) then
            inst.sg:GoToState("dance")
        end
    end),

    EventHandler("equip", function(inst, data)
        if inst.sg:HasStateTag("acting") then
            return
        end
        if (inst.sg:HasStateTag("idle") or inst.sg:HasStateTag("channeling")) and not inst:HasTag("wereplayer") then
            inst.sg:GoToState(
                (data.item ~= nil and data.item.projectileowner ~= nil and "catch_equip") or
                (data.eslot == EQUIPSLOTS.HANDS and "item_out") or
                "item_hat"
            )
        end
    end),

    EventHandler("unequip", function(inst, data)
        if inst.sg:HasStateTag("acting") then
            return
        end
        if inst.sg:HasStateTag("idle") or inst.sg:HasStateTag("channeling") then
            inst.sg:GoToState(GetUnequipState(inst, data))
        end
    end),
}

local states = {
    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst, pushanim)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end

            local anims = {}
            local dofunny = true

            table.insert(anims, "idle_loop")

            if pushanim then
                for k, v in pairs(anims) do
                    inst.AnimState:PushAnimation(v, k == #anims)
                end
            else
                inst.AnimState:PlayAnimation(anims[1], #anims == 1)
                for k, v in pairs(anims) do
                    if k > 1 then
                        inst.AnimState:PushAnimation(v, k == #anims)
                    end
                end
            end

            if dofunny then
                inst.sg:SetTimeout(math.random() * 4 + 2)
            end
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("funnyidle")
        end,
    },

    State{
        name = "funnyidle",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            local anim = inst.customidleanim ~= nil and (type(inst.customidleanim) == "string" and inst.customidleanim or inst:customidleanim()) or nil
            local state = anim == nil and (inst.customidlestate ~= nil and (type(inst.customidlestate) == "string" and inst.customidlestate or inst:customidlestate())) or nil
            if anim ~= nil or state ~= nil then
                if inst.sg.mem.idlerepeats == nil then
                    inst.sg.mem.usecustomidle = math.random() < .5
                    inst.sg.mem.idlerepeats = 0
                end
                if inst.sg.mem.idlerepeats > 1 then
                    inst.sg.mem.idlerepeats = inst.sg.mem.idlerepeats - 1
                else
                    inst.sg.mem.usecustomidle = not inst.sg.mem.usecustomidle
                    inst.sg.mem.idlerepeats = inst.sg.mem.usecustomidle and 1 or math.ceil(math.random(2, 5) * .5)
                end
                if inst.sg.mem.usecustomidle then
                    if anim ~= nil then
                        inst.AnimState:PlayAnimation(anim)
                    else
                        inst.sg:GoToState(state)
                    end
                else
                    inst.AnimState:PlayAnimation("idle_inaction")
                end
            else
                inst.AnimState:PlayAnimation("idle_inaction")
            end
        end,

        events = {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "talk",
        tags = { "idle", "talking" },

        onenter = function(inst, noanim)
            if not noanim then
                inst.AnimState:PlayAnimation("dial_loop", true)
            end
            DoTalkSound(inst)
            inst.sg:SetTimeout(1.5 + math.random() * .5)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("idle")
        end,

        events =
        {
            EventHandler("donetalking", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

        onexit = StopTalkSound,
    },

    State{
        name = "give",
        tags = { "giving" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("give")
            inst.AnimState:PushAnimation("give_pst", false)
        end,

        timeline =
        {
            TimeEvent(13 * FRAMES, function(inst)
                inst:PerformBufferedAction()
            end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "pocketwatch_openportal",
        tags = { "doing", "busy", "canrotate" },

        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("useitem_pre")
            inst.AnimState:PushAnimation("pocketwatch_portal", false)
			inst.AnimState:PushAnimation("useitem_pst", false)

            if data.target_pos ~= nil then
                inst.sg.statemem.target_pos = data.target_pos
            end

            inst.components.locomotor:Stop()
            inst.AnimState:OverrideSymbol("watchprop", "pocketwatch_portal", "watchprop")
        end,

        timeline =
        {
            TimeEvent(18 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("turnoftides/common/together/moon_glass/mine")
                local portal = SpawnPortalEntrance(inst)
                inst.sg.statemem.portal = portal
            end),
			TimeEvent(37 * FRAMES, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst:ForceFacePoint(inst.sg.statemem.portal:GetPosition():Get())
                    if inst.sg.statemem.portal ~= nil then
                        inst.sg:GoToState("jumpin_pre", {teleporter = inst.sg.statemem.portal, target_pos = inst.sg.statemem.target_pos})
                    end
                end
            end),
        },

        onexit = function(inst)
			inst.AnimState:ClearOverrideSymbol("watchprop")
        end,
    },

    State{
        name = "pocketwatch_cast",
        tags = { "busy", "doing" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("useitem_pre") -- 8 frames
            inst.AnimState:PushAnimation("pocketwatch_cast", false)
            inst.AnimState:PushAnimation("useitem_pst", false)

			local buffaction = inst:GetBufferedAction()
			if buffaction ~= nil then
		        inst.AnimState:OverrideSymbol("watchprop", buffaction.invobject.AnimState:GetBuild(), "watchprop")
				inst.sg.statemem.castfxcolour = buffaction.invobject.castfxcolour
				inst.sg.statemem.pocketwatch = buffaction.invobject
				inst.sg.statemem.target = buffaction.target
			end
        end,

		timeline =
		{
            TimeEvent(8 * FRAMES, function(inst)
				local pocketwatch = inst.sg.statemem.pocketwatch
				if pocketwatch ~= nil and pocketwatch:IsValid() and pocketwatch.components.pocketwatch:CanCast(inst, inst.sg.statemem.target) then
					inst.sg.statemem.stafffx = SpawnPrefab("pocketwatch_cast_fx")
					inst.sg.statemem.stafffx.entity:SetParent(inst.entity)
					inst.sg.statemem.stafffx:SetUp(inst.sg.statemem.castfxcolour or { 1, 1, 1 })

                    inst.SoundEmitter:PlaySound("wanda2/characters/wanda/watch/heal")
				end
            end),
            TimeEvent(16 * FRAMES, function(inst)
				if inst.sg.statemem.stafffx ~= nil then
					inst.sg.statemem.stafflight = SpawnPrefab("staff_castinglight_small")
					inst.sg.statemem.stafflight.Transform:SetPosition(inst.Transform:GetWorldPosition())
					inst.sg.statemem.stafflight:SetUp(inst.sg.statemem.castfxcolour or { 1, 1, 1 }, 0.75, 0)
				end
            end),
            TimeEvent(25 * FRAMES, function(inst)
				if not inst:PerformBufferedAction() then
					inst.sg.statemem.action_failed = true
				end
            end),

			--success timeline
            TimeEvent(40 * FRAMES, function(inst)
				if not inst.sg.statemem.action_failed then
					inst.sg:RemoveStateTag("busy")
				end
            end),

			--failed timeline
			TimeEvent(28 * FRAMES, function(inst)
				if inst.sg.statemem.action_failed then
					inst.AnimState:SetFrame(34)
					if inst.sg.statemem.stafffx ~= nil then
						inst.sg.statemem.stafffx:Remove()
						inst.sg.statemem.stafffx = nil
					end
					if inst.sg.statemem.stafflight ~= nil then
						inst.sg.statemem.stafflight:Remove()
						inst.sg.statemem.stafflight = nil
					end
				end
			end),
			TimeEvent(41 * FRAMES, function(inst)
				if inst.sg.statemem.action_failed then
					inst.sg:RemoveStateTag("busy")
				end
			end),
		},

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
	                inst.sg:GoToState("idle")
                end
            end),
        },

		onexit = function(inst)
			inst.AnimState:ClearOverrideSymbol("watchprop")
			if inst.sg.statemem.stafffx ~= nil and inst.sg.statemem.stafffx:IsValid() then
				inst.sg.statemem.stafffx:Remove()
			end
			if inst.sg.statemem.stafflight ~= nil and inst.sg.statemem.stafflight:IsValid() then
				inst.sg.statemem.stafflight:Remove()
			end
		end,
    },

    State{
        name = "pocketwatch_warpback_pre",
        tags = { "busy" },

        onenter = function(inst, data)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("pocketwatch_warp_pre")

            inst.sg.statemem.dest_pos = data.dest_pos
            inst.AnimState:OverrideSymbol("watchprop", "pocketwatch_recall", "watchprop")
        end,

        timeline=
        {
            TimeEvent(1*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("wanda2/characters/wanda/watch/warp")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    local dest_pos = inst.sg.statemem.dest_pos
                    inst.sg.statemem.portaljumping = true
                    inst.sg:GoToState("pocketwatch_warpback", {dest_pos = dest_pos})
                end
            end),
        },

		onexit = function(inst)
			if not inst.sg.statemem.portaljumping then
				inst.AnimState:ClearOverrideSymbol("watchprop")
			end
		end,
    },

    State{
        name = "pocketwatch_warpback",
        tags = { "busy", "pausepredict", "nodangle", "nomorph", "jumping" },

        onenter = function(inst, data)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("pocketwatch_warp")

            inst.sg.statemem.dest_pos = data.dest_pos

			inst.sg.statemem.stafffx = SpawnPrefab("pocketwatch_warpback_fx")
			inst.sg.statemem.stafffx.entity:SetParent(inst.entity)
			inst.sg.statemem.stafffx:SetUp({ 1, 1, 1 })
        end,

        timeline =
        {
            TimeEvent(4 * FRAMES, function(inst)
                inst.sg:AddStateTag("noattack")
                inst.components.health:SetInvincible(true)
                inst.DynamicShadow:Enable(false)
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
					if inst.sg.statemem.stafffx ~= nil then
						-- detach fx
						inst.sg.statemem.stafffx.entity:SetParent(nil)
						inst.sg.statemem.stafffx.Transform:SetPosition(inst.Transform:GetWorldPosition())
						inst.sg.statemem.stafffx = nil
					end

					local dest_pos = inst.sg.statemem.dest_pos
					inst.sg.statemem.portaljumping = true
                    inst.sg:GoToState("pocketwatch_warpback_pst", {dest_pos = dest_pos})
                end
            end),
        },

        onexit = function(inst)
			if inst.sg.statemem.stafffx ~= nil and inst.sg.statemem.stafffx:IsValid() then
				inst.sg.statemem.stafffx:Remove()
			end
            if not inst.sg.statemem.portaljumping then
				inst.AnimState:ClearOverrideSymbol("watchprop")
                inst.components.health:SetInvincible(false)
                inst.DynamicShadow:Enable(true)
            end
        end,
    },

    State{
        name = "pocketwatch_warpback_pst",
        tags = { "busy", "nopredict", "nomorph", "noattack", "nointerrupt", "jumping" },

        onenter = function(inst, data)
            ToggleOffPhysics(inst)
            inst.components.locomotor:Stop()
            inst.DynamicShadow:Enable(false)
            inst.components.health:SetInvincible(true)

            inst.AnimState:PlayAnimation("pocketwatch_warp_pst")

            local dest_x, dest_y, dest_z
            local dest_pos = data.dest_pos

            if dest_pos == nil then
                dest_x, dest_y, dest_z = inst.Transform:GetWorldPosition()
            else
                dest_pos = CalculateLandPoint(dest_pos)
                dest_x, dest_y, dest_z = dest_pos.x, dest_pos.y, dest_pos.z
            end

            inst.Physics:Teleport(dest_x, dest_y, dest_z)

			local fx = SpawnPrefab("pocketwatch_warpbackout_fx")
			fx.Transform:SetPosition(dest_x, dest_y, dest_z)
			fx:SetUp({ 1, 1, 1 })
        end,

        timeline =
        {
            TimeEvent(1*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("wanda2/characters/wanda/watch/recall")
            end),

            TimeEvent(3 * FRAMES, function(inst)
                inst.DynamicShadow:Enable(true)
                ToggleOnPhysics(inst)
            end),
            TimeEvent(4 * FRAMES, function(inst)
                inst.components.health:SetInvincible(false)
				inst.sg:RemoveStateTag("jumping")
				inst.sg:RemoveStateTag("nomorph")
				inst.sg:RemoveStateTag("nointerrupt")
                inst.sg:RemoveStateTag("noattack")
                inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
            end),
			TimeEvent(9 * FRAMES, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.sg:RemoveStateTag("nopredict")
				inst.sg:AddStateTag("idle")
			end),
        },

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},

        onexit = function(inst)
			inst.AnimState:ClearOverrideSymbol("watchprop")
            inst.components.health:SetInvincible(false)
            inst.DynamicShadow:Enable(true)
            if inst.sg.statemem.isphysicstoggle then
                ToggleOnPhysics(inst)
            end
        end,
    },

    State{
        name = "pocketwatch_portal_land",
        tags = { "busy", "nopredict", "nomorph", "nodangle", "jumping", "noattack" },

        onenter = function(inst, data)
            inst.components.locomotor:Stop()
			StartTeleporting(inst)

			inst.AnimState:PlayAnimation("jumpportal_out")

			local x, y, z = inst.Transform:GetWorldPosition()
			local fx = SpawnPrefab("pocketwatch_portal_exit_fx")
			fx.Transform:SetPosition(x, 4, z)
        end,

        timeline =
        {
            TimeEvent(16 * FRAMES, function(inst)
				inst:Show() -- hidden by StartTeleporting
            end),

            TimeEvent(17 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("wanda1/wanda/jump_whoosh")
            end),

            TimeEvent(20 * FRAMES, function(inst)
                inst.DynamicShadow:Enable(true)
            end),

            TimeEvent(22 * FRAMES, function(inst)
                PlayFootstep(inst)
            end),

            TimeEvent(28 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("jumping")
                inst.sg:RemoveStateTag("busy")
                inst.sg:RemoveStateTag("nomorph")
				inst.sg:RemoveStateTag("noattack")

				DoneTeleporting(inst)
            end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

		onexit = function(inst)
			if inst.sg.statemem.isteleporting then
				DoneTeleporting(inst)
			end
		end,
    },

    State{
        name = "portal_jumpin_pre",
        tags = { "busy" },

        onenter = function(inst, data)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("wortox_portal_jumpin_pre")

            local buffaction = inst:GetBufferedAction()
            if buffaction ~= nil and buffaction.pos ~= nil then
                inst:ForceFacePoint(buffaction:GetActionPoint():Get())
            end
            if data ~= nil and data.pos ~= nil then
                inst.sg.statemem.dest_pos = data.pos
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() and not inst:PerformBufferedAction() then
                    inst.sg:GoToState("portal_jumpin", {dest = inst.sg.statemem.dest_pos})
                end
            end),
        },
    },

    State{
        name = "portal_jumpin",
        tags = { "busy", "pausepredict", "nodangle", "nomorph" },

        onenter = function(inst, data)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("wortox_portal_jumpin")
            local x, y, z = inst.Transform:GetWorldPosition()
            SpawnPrefab("wortox_portal_jumpin_fx").Transform:SetPosition(x, y, z)
            inst.sg:SetTimeout(11 * FRAMES)
            local dest = data and data.dest or nil
            if dest ~= nil then
                inst.sg.statemem.dest = dest
                inst:ForceFacePoint(dest:Get())
            else
                inst.sg.statemem.dest = Vector3(x, y, z)
            end
        end,

        onupdate = function(inst)
            if inst.sg.statemem.tints ~= nil then
                DoWortoxPortalTint(inst, table.remove(inst.sg.statemem.tints))
                if #inst.sg.statemem.tints <= 0 then
                    inst.sg.statemem.tints = nil
                end
            end
        end,

        timeline =
        {
            TimeEvent(FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/toad_stool/infection_post", nil, .7)
                inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, .5)
            end),
            TimeEvent(2 * FRAMES, function(inst)
                inst.sg.statemem.tints = { 1, .6, .3, .1 }
                PlayFootstep(inst)
            end),
            TimeEvent(4 * FRAMES, function(inst)
                inst.sg:AddStateTag("noattack")
                inst.components.health:SetInvincible(true)
                inst.DynamicShadow:Enable(false)
            end),
        },

        ontimeout = function(inst)
            inst.sg.statemem.portaljumping = true
            inst.sg:GoToState("portal_jumpout", {dest = inst.sg.statemem.dest})
        end,

        onexit = function(inst)
            if not inst.sg.statemem.portaljumping then
                inst.components.health:SetInvincible(false)
                inst.DynamicShadow:Enable(true)
                DoWortoxPortalTint(inst, 0)
            end
        end,
    },

    State{
        name = "portal_jumpout",
        tags = { "busy", "nopredict", "nomorph", "noattack", "nointerrupt" },

        onenter = function(inst, data)
            ToggleOffPhysics(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("wortox_portal_jumpout")
            local dest = data and data.dest or nil
            if dest ~= nil then
                inst.Physics:Teleport(dest:Get())
            else
                dest = inst:GetPosition()
            end
            SpawnPrefab("wortox_portal_jumpout_fx").Transform:SetPosition(dest:Get())
            inst.DynamicShadow:Enable(false)
            inst.sg:SetTimeout(14 * FRAMES)
            DoWortoxPortalTint(inst, 1)
            inst.components.health:SetInvincible(true)
            inst:PushEvent("soulhop")
        end,

        onupdate = function(inst)
            if inst.sg.statemem.tints ~= nil then
                DoWortoxPortalTint(inst, table.remove(inst.sg.statemem.tints))
                if #inst.sg.statemem.tints <= 0 then
                    inst.sg.statemem.tints = nil
                end
            end
        end,

        timeline =
        {
            TimeEvent(FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/hop_out")
            end),
            TimeEvent(5 * FRAMES, function(inst)
                inst.sg.statemem.tints = { 0, .4, .7, .9 }
            end),
            TimeEvent(7 * FRAMES, function(inst)
                inst.components.health:SetInvincible(false)
                inst.sg:RemoveStateTag("noattack")
                inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
            end),
            TimeEvent(8 * FRAMES, function(inst)
                inst.DynamicShadow:Enable(true)
                ToggleOnPhysics(inst)
            end),
        },

        ontimeout = function(inst)
            inst.sg:GoToState("idle", true)
        end,

        onexit = function(inst)
            inst.components.health:SetInvincible(false)
            inst.DynamicShadow:Enable(true)
            DoWortoxPortalTint(inst, 0)
            if inst.sg.statemem.isphysicstoggle then
                ToggleOnPhysics(inst)
            end
        end,
    },

    State{
        name = "mkatana",
        tags = { "attack", "notalking", "abouttoattack", "autopredict" },

        onenter = function(inst)
			if inst.components.combat:InCooldown() then
                inst.sg:RemoveStateTag("abouttoattack")
                inst:ClearBufferedAction()
                inst.sg:GoToState("idle", true)
                return
            end

            local buffaction = inst:GetBufferedAction()
            local target = buffaction ~= nil and buffaction.target or nil
            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local cooldown = inst.components.combat.min_attack_period + .5 * FRAMES

            inst.AnimState:OverrideSymbol("fx_lunge_streak", "player_lunge_blue", "fx_lunge_streak")
            inst.components.combat:SetTarget(target)
            inst.components.combat:StartAttack()
            inst.components.locomotor:Stop()

            if inst.components.rider ~= nil and inst.components.rider:IsRiding() then
                inst.AnimState:PlayAnimation("atk_pre")
                inst.AnimState:PushAnimation("atk", false)
                DoMountSound(inst, inst.components.rider:GetMount(), "angry", true)
                cooldown = math.max(cooldown, 16 * FRAMES)
            elseif equip ~= nil and equip:HasTag("mkatana") then
                inst.sg.statemem.iskatana = true
				inst.AnimState:SetDeltaTimeMultiplier(1.2)

                local katanarnd = 1

                if katanarnd == 1 then
                    inst.AnimState:PlayAnimation("atk_prop_pre")
					inst.AnimState:PushAnimation("atk", false)
					katanarnd = math.random(2, 3)
                elseif katanarnd == 2 then
					inst.AnimState:SetDeltaTimeMultiplier(1.3)
					inst.sg:AddStateTag("mkatanaatk")
					inst.AnimState:PlayAnimation("chop_pre")
					katanarnd = 4
				elseif katanarnd == 3 then
					inst.AnimState:SetDeltaTimeMultiplier(1.4)
					inst.sg:AddStateTag("mkatanaatk")
					inst.AnimState:PlayAnimation("pickaxe_pre")
					katanarnd = 1
				elseif katanarnd == 4 then
					inst.AnimState:SetDeltaTimeMultiplier(1.4)
					inst.AnimState:PlayAnimation("spearjab_pre")
					inst.AnimState:PushAnimation("spearjab", false)
					katanarnd = 5
                elseif katanarnd == 5 then
                    inst.AnimState:SetDeltaTimeMultiplier(4)
                    inst.sg.statemem.scythe_anim = true
                    inst.AnimState:PlayAnimation("scythe_pre")
                    inst.AnimState:PushAnimation("scythe_loop", false)
                    katanarnd = 6
                else
                	inst.AnimState:PlayAnimation("atk_pre")
                	inst.AnimState:PushAnimation("atk", false)
                	katanarnd = 1
                end

                inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
                cooldown = math.max(cooldown, 13 * FRAMES)
            end

            inst.sg:SetTimeout(cooldown)
            if target ~= nil then
                inst.components.combat:BattleCry()
                if target:IsValid() then
                    inst:FacePoint(target:GetPosition())
                    inst.sg.statemem.attacktarget = target
                    inst.sg.statemem.retarget = target
                end
            end
        end,

        timeline = {
			TimeEvent(5 * FRAMES, function(inst)
				inst.AnimState:SetDeltaTimeMultiplier(1)
                if inst.sg.statemem.iskatana and inst.sg:HasStateTag("mkatanaatk") then
                    inst.AnimState:PlayAnimation("lunge_pst")
					inst.sg:RemoveStateTag("mkatanaatk")
                end
            end),

			TimeEvent(8 * FRAMES, function(inst)
                if inst.sg.statemem.iskatana then
    				inst:PerformBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
				end
                if inst.sg.statemem.scythe_anim then
                    local sharkboi_swipe_fx = SpawnPrefab("sharkboi_swipe_fx")
                    if sharkboi_swipe_fx ~= nil then
                        sharkboi_swipe_fx.AnimState:SetScale(0.88, 0.88, 0.88)
                        sharkboi_swipe_fx.entity:SetParent(inst.entity)
                        sharkboi_swipe_fx.Transform:SetPosition(1, 0, 0)
                        sharkboi_swipe_fx:Reverse()
                    end
                    inst.sg.statemem.bearger_swipe_fx = sharkboi_swipe_fx
                end
            end),

			TimeEvent(10 * FRAMES, function(inst)
                if not inst.sg.statemem.iskatana then
                    inst:PerformBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end)
        },

        ontimeout = function(inst)
            inst.sg:RemoveStateTag("attack")
            inst.sg:AddStateTag("idle")
        end,

        events = {
            EventHandler("equip", function(inst)
                inst.sg:GoToState("idle")
            end),
            EventHandler("unequip", function(inst)
                inst.sg:GoToState("idle")
            end),
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
					inst.AnimState:SetDeltaTimeMultiplier(1)
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            inst.sg.statemem.scythe_anim = false
            inst.components.combat:SetTarget(nil)
            if inst.sg:HasStateTag("abouttoattack") then
                inst.components.combat:CancelAttack()
				inst.AnimState:SetDeltaTimeMultiplier(1)
				if inst.sg:HasStateTag("mkatanaatk") then
                    inst.sg:RemoveStateTag("mkatanaatk")
                end
            end
            local bearger_swipe_fx = inst.sg.statemem.bearger_swipe_fx
            if bearger_swipe_fx ~= nil and bearger_swipe_fx:IsValid() then
				bearger_swipe_fx:Remove()
			end
        end,
    },

    State{
        name = "iai",
        tags = { "attack", "notalking", "abouttoattack", "autopredict" }, --

        onenter = function(inst)
            if inst.components.combat:InCooldown() then
                inst.sg:RemoveStateTag("abouttoattack")
                inst:ClearBufferedAction()
                inst.sg:GoToState("idle", true)
                return
            end

            local buffaction = inst:GetBufferedAction()
            local target = buffaction ~= nil and buffaction.target or nil
            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local cooldown = inst.components.combat.min_attack_period + .5 * FRAMES

            inst.AnimState:OverrideSymbol("fx_lunge_streak", "player_lunge_blue", "fx_lunge_streak")
            inst.components.combat:SetTarget(target)
            inst.components.combat:StartAttack()
            inst.components.locomotor:Stop()

            if inst.components.rider ~= nil and inst.components.rider:IsRiding() then
                inst.AnimState:PlayAnimation("atk_pre")
                inst.AnimState:PushAnimation("atk", false)
                DoMountSound(inst, inst.components.rider:GetMount(), "angry", true)
                cooldown = math.max(cooldown, 16 * FRAMES)
            elseif equip ~= nil and equip:HasTag("iai") then
                inst.sg.statemem.iskatana = true
                inst.AnimState:PlayAnimation("spearjab_pre")
                inst.AnimState:PushAnimation("lunge_pst", false)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
                cooldown = math.max(cooldown, 9 * FRAMES)
            end

            inst.sg:SetTimeout(cooldown)
            if target ~= nil then
                inst.components.combat:BattleCry()
                if target:IsValid() then
                    inst:FacePoint(target:GetPosition())
                    inst.sg.statemem.attacktarget = target
                    inst.sg.statemem.retarget = target
                end
            end
        end,

        timeline = {
            TimeEvent(7.5 * FRAMES, function(inst)
                if inst.sg.statemem.iskatana then
                    inst:PerformBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            TimeEvent(10 * FRAMES, function(inst)
                if not inst.sg.statemem.iskatana then
                    inst:PerformBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
        },

        ontimeout = function(inst)
            inst.sg:RemoveStateTag("attack")
            inst.sg:AddStateTag("idle")
        end,

        events = {
            EventHandler("equip", function(inst)
                inst.sg:GoToState("idle")
            end),
            EventHandler("unequip", function(inst)
                inst.sg:GoToState("idle")
            end),
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            inst.components.combat:SetTarget(nil)
            if inst.sg:HasStateTag("abouttoattack") then
                inst.components.combat:CancelAttack()
            end
        end,
    },

    State{
        name = "yari",
        tags = { "attack", "notalking", "abouttoattack", "autopredict" }, --

        onenter = function(inst)
            if inst.components.combat:InCooldown() then
                inst.sg:RemoveStateTag("abouttoattack")
                inst:ClearBufferedAction()
                inst.sg:GoToState("idle", true)
                return
            end

            local buffaction = inst:GetBufferedAction()
            local target = buffaction ~= nil and buffaction.target or nil
            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local cooldown = inst.components.combat.min_attack_period + .5 * FRAMES

            inst.components.combat:SetTarget(target)
            inst.components.combat:StartAttack()
            inst.AnimState:OverrideSymbol("fx_lunge_streak", "player_lunge_blue", "fx_lunge_streak")
            inst.components.locomotor:Stop()

            if inst.components.rider ~= nil and inst.components.rider:IsRiding() then
                inst.AnimState:PlayAnimation("atk_pre")
                inst.AnimState:PushAnimation("atk", false)
                DoMountSound(inst, inst.components.rider:GetMount(), "angry", true)
                cooldown = math.max(cooldown, 16 * FRAMES)
            elseif equip ~= nil and equip:HasTag("yari") then
                inst.sg.statemem.isyari = true
                if math.random(1, 3) == 1 then
                    inst.AnimState:PlayAnimation("spearjab_pre")
                    inst.AnimState:PushAnimation("lunge_pst", false)
                elseif math.random(2, 3) == 2 then
                    inst.AnimState:PlayAnimation("atk_pre")
                    inst.AnimState:PushAnimation("atk", false)
                else
                    inst.AnimState:PlayAnimation("spearjab_pre")
                    inst.AnimState:PushAnimation("spearjab", false)
                end
                inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe")
                cooldown = math.max(cooldown, 13 * FRAMES)
            end

            inst.sg:SetTimeout(cooldown)

            if target ~= nil then
                inst.components.combat:BattleCry()
                if target:IsValid() then
                    inst:FacePoint(target:GetPosition())
                    inst.sg.statemem.attacktarget = target
                    inst.sg.statemem.retarget = target
                end
            end
        end,

        timeline = {
            TimeEvent(8 * FRAMES, function(inst)
                if inst.sg.statemem.isyari then
                    inst:PerformBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            TimeEvent(10 * FRAMES, function(inst)
                if not inst.sg.statemem.isyari then
                    inst:PerformBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
        },

        ontimeout = function(inst)
            inst.sg:RemoveStateTag("attack")
            inst.sg:AddStateTag("idle")
        end,

        events = {
            EventHandler("equip", function(inst)
                inst.sg:GoToState("idle")
            end),
            EventHandler("unequip", function(inst)
                inst.sg:GoToState("idle")
            end),
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            inst.components.combat:SetTarget(nil)
            if inst.sg:HasStateTag("abouttoattack") then
                inst.components.combat:CancelAttack()
            end
        end,
    },

    State{
        name = "mdash",
        tags = {"busy", "nopredict", "nointerrupt", "nomorph" },

        onenter = function(inst, data)
			if data ~= nil then
				local pos
                if data.pos ~= nil then
                    pos = data.pos:GetPosition()
                else
                    pos = inst:GetPosition()
                end

                inst:ForceFacePoint(pos.x, 0, pos.z)
			end

			local x, y, z = inst.Transform:GetWorldPosition()
			local pufffx = SpawnPrefab("dirt_puff")
			pufffx.Transform:SetScale(.3, .3, .3)
			pufffx.Transform:SetPosition(x, y, z)

			SkillCollision(inst, true)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_leap_pre")
			inst.Physics:SetMotorVelOverride(30,0,0)
			inst.components.locomotor:EnableGroundSpeedMultiplier(false)
        end,

        timeline = {
			TimeEvent(0 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
            end),

			TimeEvent(6 * FRAMES, function(inst)
                inst.Physics:ClearMotorVelOverride()
            end),
        },

		events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
			SkillCollision(inst, false)
			inst.components.locomotor:EnableGroundSpeedMultiplier(true)
        end,
    },

    State{
        name = "mdash2",
        tags = {"busy", "nopredict", "nointerrupt", "nomorph" },

        onenter = function(inst, data)
			if data ~= nil then
				local pos
                if data.pos ~= nil then
                    pos = data.pos:GetPosition()
                else
                    pos = inst:GetPosition()
                end

                inst:ForceFacePoint(pos.x, 0, pos.z)
			end

			local x, y, z = inst.Transform:GetWorldPosition()
			local pufffx = SpawnPrefab("dirt_puff")
			pufffx.Transform:SetScale(.3, .3, .3)
			pufffx.Transform:SetPosition(x, y, z)

			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("slide_pre")
            inst.AnimState:PushAnimation("slide_loop", false)
			SkillCollision(inst, true)
			inst.Physics:SetMotorVelOverride(20,0,0)
			inst.components.locomotor:EnableGroundSpeedMultiplier(false)
        end,

        timeline = {
			TimeEvent(0 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
            end),

			TimeEvent(7 * FRAMES, function(inst)
                inst.Physics:ClearMotorVelOverride()
            end),
        },

		events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
			SkillCollision(inst, false)
			inst.components.locomotor:EnableGroundSpeedMultiplier(true)
        end,
    },

    State{
        name = "releaselight",
        tags = { "doing", "busy", "nodangle" },

        onenter = function(inst, data)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("wendy_recall")
            inst.AnimState:PushAnimation("wendy_recall_pst", false)

            if data.phase == "night" then
                if data ~= nil and data.sametime then
                    inst.sg.statemem.sametime = data.sametime
                    inst.components.talker:Say(STRINGS.MOMO.ONNIGHT.SAMETIME)
                else
                    inst.components.talker:Say(STRINGS.MOMO.ONNIGHT.FORHONEY)
                end
            end
        end,

        timeline =
        {
            TimeEvent(6*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/summon_pre")
            end),
			TimeEvent(30 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/recall")
                inst.sg:RemoveStateTag("busy")
			end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            if TheWorld.state.isnight then
                inst.components.talker:Say(STRINGS.MOMO.ONNIGHT.FORSELF)
            end
        end
    },

    State{
        name = "dance",
        tags = {"idle", "dancing"},

        onenter = function(inst)
            inst.components.locomotor:Stop()

            local ignoreplay = inst.AnimState:IsCurrentAnimation("run_pst")
            -- NOTES(JBK): No dance data do default dance.
            if ignoreplay then
                inst.AnimState:PushAnimation("emoteXL_pre_dance0")
            else
                inst.AnimState:PlayAnimation("emoteXL_pre_dance0")
            end
            inst.AnimState:PushAnimation("emoteXL_loop_dance0", true)
        end,
    },

    State{
        name = "hit",
		tags = { "busy", "pausepredict"},

        onenter = function(inst)
            inst.components.locomotor:Stop()

			inst.AnimState:PlayAnimation("hit")

            DoHurtSound(inst)

            --V2C: some of the woodie's were-transforms have shorter hit anims
			local stun_frames = math.min(inst.AnimState:GetCurrentAnimationNumFrames(), 6)
            inst.sg:SetTimeout(stun_frames * FRAMES)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("idle", true)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "give",
        tags = { "giving" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("give")
            inst.AnimState:PushAnimation("give_pst", false)
        end,

        timeline =
        {
            TimeEvent(13 * FRAMES, function(inst)
                inst:PerformBufferedAction()
            end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "item_out",
		tags = { "idle", "nodangle", "keepchannelcasting" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("item_out")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "item_in",
		tags = { "idle", "nodangle", "keepchannelcasting" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("item_in")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "item_hat",
		tags = { "idle", "keepchannelcasting" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("item_hat")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "catch_equip",
        tags = { "idle" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("catch_pre")
            inst.AnimState:PushAnimation("catch", false)
        end,

        timeline =
        {
            TimeEvent(9 * FRAMES, function(inst)
                inst.sg.statemem.playedfx = true
                SpawnPrefab("lucy_transform_fx").entity:AddFollower():FollowSymbol(inst.GUID, "swap_object", 50, -25, 0)
            end),
            TimeEvent(13 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/wilson/boomerang_catch")
            end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.playedfx then
                SpawnPrefab("lucy_transform_fx").entity:AddFollower():FollowSymbol(inst.GUID, "swap_object", 50, -25, 0)
            end
        end,
    },

    State{
        name = "jumpin_pre",
        tags = { "doing", "busy", "canrotate" },

        onenter = function(inst, data)
            inst.sg.statemem.portal = data.teleporter

            if data.target_pos ~= nil then
                inst.sg.statemem.target_pos = data.target_pos
            end

            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("jump_pre", false)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("jumpin", {teleporter = inst.sg.statemem.portal, target_pos = inst.sg.statemem.target_pos})
                end
            end),
        },
    },

    State{
        name = "jumpin",
        tags = { "doing", "busy", "canrotate", "nopredict", "nomorph" },

        onenter = function(inst, data)
            ToggleOffPhysics(inst)
            inst.components.locomotor:Stop()

            inst.sg.statemem.portal = data.teleporter

            if data ~= nil then
                inst.sg.statemem.target_pos = data.target_pos
            end

            inst.AnimState:PlayAnimation("jump")

            local pos = data ~= nil and data.teleporter and data.teleporter:GetPosition() or nil

            local MAX_JUMPIN_DIST = 3
            local MAX_JUMPIN_DIST_SQ = MAX_JUMPIN_DIST * MAX_JUMPIN_DIST
            local MAX_JUMPIN_SPEED = 6

            local dist
            if pos ~= nil then
                local distsq = inst:GetDistanceSqToPoint(pos:Get())
                if distsq <= .25 * .25 then
                    dist = 0
                    inst.sg.statemem.speed = 0
                elseif distsq >= MAX_JUMPIN_DIST_SQ then
                    dist = MAX_JUMPIN_DIST
                    inst.sg.statemem.speed = MAX_JUMPIN_SPEED
                else
                    dist = math.sqrt(distsq)
                    inst.sg.statemem.speed = MAX_JUMPIN_SPEED * dist / MAX_JUMPIN_DIST
                end
            else
                inst.sg.statemem.speed = 0
                dist = 0
            end

            inst.Physics:SetMotorVel(inst.sg.statemem.speed * .5, 0, 0)
        end,

        timeline =
        {
            TimeEvent(.5 * FRAMES, function(inst)
                inst.Physics:SetMotorVel(inst.sg.statemem.speed * .75, 0, 0)
            end),
            TimeEvent(1 * FRAMES, function(inst)
                inst.Physics:SetMotorVel(inst.sg.statemem.speed, 0, 0)
            end),
            TimeEvent(15 * FRAMES, function(inst)
                inst.Physics:Stop()
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    local target_pos = inst.sg.statemem.target_pos
                    local x, y, z
                    if target_pos ~= nil then
                        target_pos = CalculateLandPoint(target_pos)
                        x, y, z = target_pos.x, target_pos.y, target_pos.z
                    else
                        local honey = inst:TheHoney()
                        if honey ~= nil then
                            local honey_pos = CalculateLandPoint(honey:GetPosition(), 4)
                            x, y, z = honey_pos.x, honey_pos.y, honey_pos.z
                        end
                    end
                    if x ~= nil and y ~= nil and z ~= nil then
                        inst.Physics:Teleport(x, y, z)
                    end
                    inst.sg:GoToState("pocketwatch_portal_land")
                end
            end),
        },

        onexit = function(inst)
            if inst.sg.statemem.isphysicstoggle then
                ToggleOnPhysics(inst)
            end
            inst.Physics:Stop()

            if inst.sg.statemem.isteleporting then
                inst.components.health:SetInvincible(false)
                inst:Show()
                inst.DynamicShadow:Enable(true)
            end
        end,
    },

    State{
        name = "bedroll",
        tags = { "bedroll", "busy", "nomorph" },

        onenter = function(inst)
            inst.components.locomotor:Stop()

            inst.AnimState:OverrideSymbol("swap_bedroll", "swap_bedroll_furry", "bedroll_furry")

            inst.AnimState:PlayAnimation("action_uniqueitem_pre")
            inst.AnimState:PushAnimation("bedroll", false)
            SetSleeperSleepState(inst)

            --Hack since we've already temp unequipped hand items at this point
            --but we want to show the correct arms for action_uniqueitem_pre
            if inst._sleepinghandsitem ~= nil then
                inst.AnimState:Show("ARM_carry")
                inst.AnimState:Hide("ARM_normal")
            end
        end,

        timeline =
        {
            TimeEvent(20 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/wilson/use_bedroll")
            end),
        },

        events =
        {
            EventHandler("firedamage", function(inst)
                if inst.sg:HasStateTag("sleeping") then
                    inst.sg.statemem.iswaking = true
                    inst.sg:GoToState("wakeup")
                end
            end),
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    if TheWorld.state.isday or
                        (inst.components.health ~= nil and inst.components.health.takingfiredamage) or
                        (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) then
                        inst:PushEvent("performaction", { action = inst.bufferedaction })
                        inst:ClearBufferedAction()
                        inst.sg.statemem.iswaking = true
                        inst.sg:GoToState("wakeup")
                    elseif inst:GetBufferedAction() then
                        inst:PerformBufferedAction()
                        if inst.components.playercontroller ~= nil then
                            inst.components.playercontroller:Enable(true)
                        end
                        inst.sg:AddStateTag("sleeping")
                        inst.sg:AddStateTag("silentmorph")
                        inst.sg:RemoveStateTag("nomorph")
                        inst.sg:RemoveStateTag("busy")
                        inst.AnimState:PlayAnimation("bedroll_sleep_loop", true)
                    else
                        inst.sg.statemem.iswaking = true
                        inst.sg:GoToState("wakeup")
                    end
                end
            end),
        },

        onexit = function(inst)
            if not inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) then
                inst.AnimState:Hide("ARM_carry")
                inst.AnimState:Show("ARM_normal")
            end
            if inst.sleepingbag ~= nil then
                --Interrupted while we are "sleeping"
                inst.sleepingbag.components.sleepingbag:DoWakeUp(true)
                inst.sleepingbag = nil
                SetSleeperAwakeState(inst)
            elseif not inst.sg.statemem.iswaking then
                --Interrupted before we are "sleeping"
                SetSleeperAwakeState(inst)
            end
        end,
    },
}

CommonStates.AddWalkStates(states, {
    walktimeline =
    {
        TimeEvent(0, PlayFootstep),
        TimeEvent(12 * FRAMES, PlayFootstep),
    },
})

CommonStates.AddRunStates(states, {
    runtimeline =
    {
        TimeEvent(0, PlayFootstep),
        TimeEvent(10 * FRAMES, PlayFootstep),
    },
})

return StateGraph("momo", states, events, "idle", actionhandlers)