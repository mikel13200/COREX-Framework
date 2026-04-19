--[[
    COREX Framework - State Management
    Player state tracking and additional utilities
]]

COREX = COREX or {}
COREX.State = {}

---Set player lifecycle state
---@param source number Player source
---@param state string State name
---@return boolean
function COREX.State.SetPlayerState(source, state)
    if not COREX.Functions or not COREX.Functions.GetPlayer then return false end
    local player = COREX.Functions.GetPlayer(source)
    if not player then
        if COREX.Debug then
            COREX.Debug.Warn('[COREX.State] Cannot set state - player not found: ' .. source)
        end
        return false
    end

    if Config and Config.PlayerStates and COREX.Utils and COREX.Utils.TableContains then
        if not COREX.Utils.TableContains(Config.PlayerStates, state) then
            if COREX.Debug then
                COREX.Debug.Warn('[COREX.State] Invalid player state: ' .. state)
            end
            return false
        end
    end

    -- Use metadata for state
    local oldState = COREX.Functions.GetMetaData(source, 'lifecycleState')
    COREX.Functions.SetMetaData(source, 'lifecycleState', state)

    if COREX.Debug then
        COREX.Debug.Verbose('[COREX.State] Player ' .. source .. ' state changed: ' .. tostring(oldState) .. ' -> ' .. state)
    end

    TriggerEvent('corex:playerStateChanged', source, state, oldState)
    return true
end

---Get player lifecycle state
---@param source number Player source
---@return string|nil
function COREX.State.GetPlayerState(source)
    if not COREX.Functions or not COREX.Functions.GetMetaData then return nil end
    return COREX.Functions.GetMetaData(source, 'lifecycleState')
end

---Get players by state
---@param state string State to filter by
---@return table
function COREX.State.GetPlayersByState(state)
    local result = {}
    if COREX.Functions and COREX.Functions.GetPlayers and COREX.Functions.GetMetaData then
        for source, player in pairs(COREX.Functions.GetPlayers()) do
            if COREX.Functions.GetMetaData(source, 'lifecycleState') == state then
                result[source] = player
            end
        end
    end
    return result
end

exports('SetPlayerState', COREX.State.SetPlayerState)
exports('GetPlayerState', COREX.State.GetPlayerState)
exports('GetPlayersByState', COREX.State.GetPlayersByState)

COREX.Functions = COREX.Functions or {}
COREX.Functions.SetPlayerState = COREX.State.SetPlayerState
COREX.Functions.GetPlayerState = COREX.State.GetPlayerState
COREX.Functions.GetPlayersByState = COREX.State.GetPlayersByState
