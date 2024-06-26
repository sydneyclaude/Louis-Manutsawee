local function CanCastSkill(inst)
    local screen = TheFrontEnd:GetActiveScreen().name
    if screen == "HUD" and ((not inst:HasTag("time_stopped")) and (not inst:HasTag("sleeping"))) then
        return true
    end
    return false
end

local function OnRawKey(self, key, down)
    local player = self.inst
    if player ~= nil then
        if (key and not down) then
            player:PushEvent("keyup", {inst = self.inst, player = player, key = key})
        elseif key and down then
            player:PushEvent("keydown", {inst = self.inst, player = player, key = key})
        end
    end
end

local KeyHandler = Class(function(self, inst)
    self.inst = inst
    self.handler = TheInput:AddKeyHandler(function(key, down) OnRawKey(self, key, down) end)
end)

function KeyHandler:AddActionListener(namespace, key, action, event)
    local _ismastersim = TheWorld.ismastersim

    if event == nil then
        self.inst:ListenForEvent("keyup", function(inst, data)
            if data.inst == self.inst then
                if data.key == key then
                    if CanCastSkill(self.inst) then
                        if _ismastersim then
                            self.inst:PushEvent("keyaction"..namespace..action, { namespace = namespace, action = action, fn = MOD_RPC_HANDLERS[namespace][MOD_RPC[namespace][action].id]})
                        else
                            SendModRPCToServer(MOD_RPC[namespace][action])
                        end
                    end
                end
            end
        end)
    elseif event ~= nil then
        self.inst:ListenForEvent(string.lower(event), function(inst, data)
            if data.inst == self.inst then
                if data.key == key then
                    if CanCastSkill(self.inst) then
                        if _ismastersim then
                            self.inst:PushEvent("keyaction".. namespace .. action, { namespace = namespace, action = action, fn = MOD_RPC_HANDLERS[namespace][MOD_RPC[namespace][action].id]})
                        else
                            SendModRPCToServer(MOD_RPC[namespace][action])
                        end
                    end
                end
            end
        end)
    end

    if _ismastersim then
        self.inst:ListenForEvent("keyaction".. namespace .. action, function(inst, data)
            if not data.action == action and not data.namespace == namespace then
                return
            end
            data.fn(inst)
        end)
    end
end

return KeyHandler
