-- UI art from the uploaded atlases (art/atlas/*.png, packed by tools/ui/atlas.py, uploaded by
-- tools/ui/upload.py; rectangles in UIAtlasRects, asset ids in UIAtlasIds). Until an atlas has an id, `has`
-- is false and the UI keeps its plain fallback look, so nothing breaks before the art is live.
local Rects = require(script.Parent.UIAtlasRects)

local UIAtlas = {}

UIAtlas.Ids = require(script.Parent.UIAtlasIds)

function UIAtlas.has(name)
	local r = Rects[name]
	return r ~= nil and (UIAtlas.Ids[r[1]] or 0) ~= 0
end

local function apply(image, r)
	image.Image = "rbxassetid://" .. UIAtlas.Ids[r[1]]
	image.ImageRectOffset = Vector2.new(r[2], r[3])
	image.ImageRectSize = Vector2.new(r[4], r[5])
	image.BackgroundTransparency = 1
end

-- An icon (kept to its aspect ratio) on an ImageLabel or ImageButton. Returns false if the art isn't live.
function UIAtlas.icon(image, name)
	if not UIAtlas.has(name) then
		return false
	end
	apply(image, Rects[name])
	image.ScaleType = Enum.ScaleType.Fit
	return true
end

-- A stretchable 9-slice frame. `scale` shrinks or grows the corners (1 = the art's own size).
function UIAtlas.frame(image, name, scale)
	if not UIAtlas.has(name) then
		return false
	end
	local r = Rects[name]
	apply(image, r)
	local s = r[6]
	image.ScaleType = Enum.ScaleType.Slice
	image.SliceCenter = Rect.new(s[1], s[2], s[3], s[4])
	image.SliceScale = scale or 1
	return true
end

-- A new ImageLabel showing `name`, or nil if the art isn't live yet.
function UIAtlas.label(parent, name, props)
	if not UIAtlas.has(name) then
		return nil
	end
	local image = Instance.new("ImageLabel")
	image.Name = name
	UIAtlas.icon(image, name)
	for k, v in props or {} do
		image[k] = v
	end
	image.Parent = parent
	return image
end

return UIAtlas
