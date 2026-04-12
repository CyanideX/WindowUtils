local frameContext = {}

local ctx = {
    clock = 0,
    displayWidth = 0,
    displayHeight = 0,
    deltaTime = 0,
}

local prevClock = 0

--- Call once at the top of onDraw, before anything else.
function frameContext.update()
    local now = os.clock()
    ctx.clock = now
    ctx.deltaTime = prevClock > 0 and (now - prevClock) or 0
    prevClock = now
    ctx.displayWidth, ctx.displayHeight = GetDisplayResolution()
end

--- Read-only access to the current frame's context.
---@return table ctx {clock, displayWidth, displayHeight, deltaTime}
function frameContext.get()
    return ctx
end

return frameContext
