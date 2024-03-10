local Animation = {}
Animation.__index = Animation

local function getFrames(node)
	local frames = {}

    for _, child_node in ipairs(node.children) do
        if child_node.name == 'frame' then
            table.insert(frames, {
                tile_id = tonumber(child_node.attributes['tileid']),
                duration = tonumber(child_node.attributes['duration']) / 1000,
            })
        end
    end

    return frames
end

function Animation:init(node)
	return setmetatable({
		time = 0,
		frames = getFrames(node),
		frame_idx = 1,
		-- TODO: could have a 'dirty' flag, to prevent updating tiles if frame idx was unchanged
	}, Animation)
end

function Animation:update(dt)
    self.time = self.time + dt
    local frame = self.frames[self.frame_idx]
    if self.time > frame.duration then
        self.time = self.time - frame.duration
        self.frame_idx = (self.frame_idx % #self.frames) + 1
    end
end

function Animation:getCurrentFrame()
	return self.frames[self.frame_idx]
end

return setmetatable(Animation, {
	__call = Animation.init,
})
