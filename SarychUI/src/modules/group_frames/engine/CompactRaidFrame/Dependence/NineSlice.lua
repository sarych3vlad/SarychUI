local function GetNineSlicePiece(container, pieceName)
    if container.GetNineSlicePiece then
        local piece = container:GetNineSlicePiece(pieceName);
        if piece then
            return piece, true;
        end
    end
    local piece = container[pieceName];
    if piece then
        return piece, true;
    else
        piece = container:CreateTexture()
        container[pieceName] = piece;
        return piece, false;
    end
end

local function PropagateLayoutSettingsToPieceLayout(userLayout, pieceLayout)
    -- Only apply mirrorLayout if it wasn't explicitly defined
    if pieceLayout.mirrorLayout == nil then
        pieceLayout.mirrorLayout = userLayout.mirrorLayout;
    end
    -- ... and other settings that apply to the whole nine-slice
end

local function SetupTextureCoordinates(piece, setupInfo, pieceLayout)
    local left, right, top, bottom = 0, 1, 0, 1;
    if pieceLayout.mirrorLayout then
        if setupInfo.mirrorVertical then
            top, bottom = bottom, top;
        end
        if setupInfo.mirrorHorizontal then
            left, right = right, left;
        end
    end
    piece:SetHorizTile(setupInfo.tileHorizontal);
    piece:SetVertTile(setupInfo.tileVertical);
    piece:SetTexCoord(left, right, top, bottom);
end

local function SetupPieceVisuals(piece, setupInfo, pieceLayout, textureKit, userLayout)
    --- Change texture coordinates before applying atlas.
    SetupTextureCoordinates(piece, setupInfo, pieceLayout, userLayout);
    -- textureKit is optional, that's fine; but if it's nil the caller should ensure that there are no format specifiers in .atlas
    local atlasName = SarychUI.Compat.GetFinalNameFromTextureKit(pieceLayout.atlas, textureKit);
    local info = SarychUI.Compat.Texture.GetAtlasInfo(atlasName);
    piece:SetHorizTile(info and info.tilesHorizontally or false);
    piece:SetVertTile(info and info.tilesVertically or false);
    SarychUI.Compat.Widgets.SetAtlas(piece, atlasName, true);
end

local function SetupCorner(container, piece, setupInfo, pieceLayout)
    piece:ClearAllPoints();
    piece:SetPoint(pieceLayout.point or setupInfo.point, container, pieceLayout.relativePoint or setupInfo.point, pieceLayout.x, pieceLayout.y);
end

local function SetupEdge(container, piece, setupInfo, pieceLayout)
    piece:ClearAllPoints();
    piece:SetPoint(setupInfo.point, GetNineSlicePiece(container, setupInfo.relativePieces[1]), setupInfo.relativePoint, pieceLayout.x, pieceLayout.y);
    piece:SetPoint(setupInfo.relativePoint, GetNineSlicePiece(container, setupInfo.relativePieces[2]), setupInfo.point, pieceLayout.x1, pieceLayout.y1);
end

local function SetupCenter(container, piece, setupInfo, pieceLayout)
    piece:ClearAllPoints();
    piece:SetPoint("TOPLEFT", GetNineSlicePiece(container, "TopLeftCorner"), "BOTTOMRIGHT", pieceLayout.x, pieceLayout.y);
    piece:SetPoint("BOTTOMRIGHT", GetNineSlicePiece(container, "BottomRightCorner"), "TOPLEFT", pieceLayout.x1, pieceLayout.y1);
end
-- Defines the order in which each piece should be set up, and how to do the setup.
--
-- Mirror types: As a texture memory and effort savings, many borders are assembled from a single topLeft corner, and top/left edges.
-- That's all that's required if everything is symmetrical (left edge is also superfluous, but allows for more detail variation)
-- The mirror flags specify which texture coords to flip relative to the piece that would use default texture coordinates: left = 0, top = 0, right = 1, bottom = 1
local nineSliceSetup =
{
    { pieceName = "TopLeftCorner", point = "TOPLEFT", fn = SetupCorner, },
    { pieceName = "TopRightCorner", point = "TOPRIGHT", mirrorHorizontal = true, fn = SetupCorner, },
    { pieceName = "BottomLeftCorner", point = "BOTTOMLEFT", mirrorVertical = true, fn = SetupCorner, },
    { pieceName = "BottomRightCorner", point = "BOTTOMRIGHT", mirrorHorizontal = true, mirrorVertical = true, fn = SetupCorner, },
    { pieceName = "TopEdge", point = "TOPLEFT", relativePoint = "TOPRIGHT", relativePieces = { "TopLeftCorner", "TopRightCorner" }, fn = SetupEdge, tileHorizontal = true },
    { pieceName = "BottomEdge", point = "BOTTOMLEFT", relativePoint = "BOTTOMRIGHT", relativePieces = { "BottomLeftCorner", "BottomRightCorner" }, mirrorVertical = true, tileHorizontal = true, fn = SetupEdge, },
    { pieceName = "LeftEdge", point = "TOPLEFT", relativePoint = "BOTTOMLEFT", relativePieces = { "TopLeftCorner", "BottomLeftCorner" }, tileVertical = true, fn = SetupEdge, },
    { pieceName = "RightEdge", point = "TOPRIGHT", relativePoint = "BOTTOMRIGHT", relativePieces = { "TopRightCorner", "BottomRightCorner" }, mirrorHorizontal = true, tileVertical = true, fn = SetupEdge, },
    { pieceName = "Center", fn = SetupCenter, },
};

local layouts =
{
    Dialog =
    {
        TopLeftCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerTopLeft", },
        TopRightCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerTopRight", },
        BottomLeftCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerBottomLeft", },
        BottomRightCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerBottomRight", },
        TopEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeTop", },
        BottomEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeBottom", },
        LeftEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeLeft", },
        RightEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeRight", },
    },

};
--------------------------------------------------
-- NINE SLICE UTILS
SarychUI.Compat.NineSliceUtil = {};
function SarychUI.Compat.NineSliceUtil.ApplyLayout(container, userLayout, textureKit)
    for pieceIndex, setup in ipairs(nineSliceSetup) do
        local pieceName = setup.pieceName;
        local pieceLayout = userLayout[pieceName];
        if pieceLayout then
            PropagateLayoutSettingsToPieceLayout(userLayout, pieceLayout);
            local piece, pieceAlreadyExisted = GetNineSlicePiece(container, pieceName);
            if not pieceAlreadyExisted then
                container[pieceName] = piece;
                piece:SetDrawLayer(pieceLayout.layer or "BORDER", pieceLayout.subLevel);
            end
            -- Piece setup can change arbitrary properties, do it before changing the texture.
            setup.fn(container, piece, setup, pieceLayout);
            if userLayout.setupPieceVisualsFunction then
                userLayout.setupPieceVisualsFunction(container, piece, setup, pieceLayout, textureKit);
            else
                SetupPieceVisuals(piece, setup, pieceLayout, textureKit);
            end
        end
    end
end

function SarychUI.Compat.NineSliceUtil.ApplyLayoutByName(container, userLayoutName, textureKit)
    return SarychUI.Compat.NineSliceUtil.ApplyLayout(container, SarychUI.Compat.NineSliceUtil.GetLayout(userLayoutName), textureKit);
end

function SarychUI.Compat.NineSliceUtil.GetLayout(layoutName)
    return layouts[layoutName];
end

function SarychUI.Compat.NineSliceUtil.AddLayout(layoutName, layout)
    layouts[layoutName] = layout;
end
--------------------------------------------------
-- NINE SLICE PANEL MIXIN
SarychUI.Compat.NineSlicePanelMixin = {};

function SarychUI.Compat.NineSlicePanelMixin:GetFrameLayoutType()
    return self.layoutType or self:GetParent().layoutType;
end

function SarychUI.Compat.NineSlicePanelMixin:OnLoad()
    local layout = SarychUI.Compat.NineSliceUtil.GetLayout(self:GetFrameLayoutType());
    if layout then
        SarychUI.Compat.NineSliceUtil.ApplyLayout(self, layout, self.layoutTextureKit);
    end
end
