local M = {}

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

function M.new(node)
    return {
		time = 0,
		frames = getFrames(node),
		frame_idx = 1
    }
end

function M.update(animation, dt)
    animation.time = animation.time + dt
    local frame = animation.frames[animation.frame_idx]
    if animation.time > frame.duration then
        animation.time = animation.time - frame.duration
        animation.frame_idx = (animation.frame_idx % #animation.frames) + 1
    end
end

function M.getCurrentFrame(animation)
	return animation.frames[animation.frame_idx]
end

return M
