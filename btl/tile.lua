local Tile = {}
Tile.__index = Tile

function Tile.new(image)
	return setmetatable({
		image = image,
	}, Tile)
end

function Tile:draw(x, y)
	love.graphics.draw(self.image, x, y)
end

return setmetatable(Tile, {
	__call = function (t, ...) return t.new(...) end,
})
