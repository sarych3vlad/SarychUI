--------------------------------------------------------------------------------
-- In order to create your own custom animation addon, copy the entire folder
-- containing this file and paste it into your Interface\Addons folder. Then
-- edit to taste.
--
-- You may also want to rename your animation addon. To do this, simply rename
-- the folder and the .toc file. Then edit the .toc file and change the "Title:"
-- field to match.



--------------------------------------------------------------------------------
-- Display a maximum of 5 simultaneous animations

local animationsCount = 5;
local animations = {};



--------------------------------------------------------------------------------
-- Create the animations
--
-- If you simply want to change the default animation texture, size, alpha,
-- scaling, and so forth, then this is the only section you need to edit.

local frame, texture, animationGroup, alpha1, scale1, scale2, rotation2;
for i = 1, animationsCount do
  frame = CreateFrame("Frame");

  -- Create an animation texture
  texture = frame:CreateTexture();
  texture:SetTexture([[Interface\Cooldown\star4]]);
  texture:SetAlpha(0);
  texture:SetAllPoints();
  texture:SetBlendMode("ADD");

  -- Create an animation group for that texture
  animationGroup = texture:CreateAnimationGroup();

  -- Start by making the animation texture visible
  alpha1 = animationGroup:CreateAnimation("Alpha");
  alpha1:SetChange(1);
  alpha1:SetDuration(0);
  alpha1:SetOrder(1);

  -- Start by making the animation texture 1.5x the size of the button
  scale1 = animationGroup:CreateAnimation("Scale");
  scale1:SetScale(1.5, 1.5);
  scale1:SetDuration(0);
  scale1:SetOrder(1);

  -- Over 0.2 seconds, scale the animation texture down to zero size
  scale2 = animationGroup:CreateAnimation("Scale");
  scale2:SetScale(0, 0);
  scale2:SetDuration(0.2);
  scale2:SetOrder(2);

  -- Over 0.2 seconds, rotate the animation texture counter-clockwise by 90 degrees
  rotation2 = animationGroup:CreateAnimation("Rotation");
  rotation2:SetDegrees(90);
  rotation2:SetDuration(0.2);
  rotation2:SetOrder(2);

  animations[i] = {frame = frame, animationGroup = animationGroup};
end



--------------------------------------------------------------------------------
-- Play an animation on the specified button

local animationNum = 1;
local function animate(button)
  -- Don't animate invisible buttons
  if (not button:IsVisible()) then
    return true;
  end

  local animation = animations[animationNum];
  local frame = animation.frame;
  local animationGroup = animation.animationGroup;

  -- Place the animation on top of the button
  frame:SetFrameStrata(button:GetFrameStrata());
  frame:SetFrameLevel(button:GetFrameLevel() + 10);
  frame:SetAllPoints(button);

  -- Play the animation from the beginning
  animationGroup:Stop();
  animationGroup:Play();

  -- Cycle to the next animation on the next call
  animationNum = (animationNum % animationsCount) + 1;

  return true;
end



--------------------------------------------------------------------------------
-- Register our animation handler with SnowfallKeyPress
--
-- When SnowfallKeyPress clicks a button, it will call every animation handler,
-- SnowfallKeyPress.animation.handlers[i], in increasing order of i (1, 2, 3,
-- ...), with the button being clicked as the sole parameter. An animation
-- handler should return true if it is handling the animation for the button,
-- or false otherwise. If no animation handler returns true, then the default
-- animation handler, SnowfallKeyPress.animation.defaultHandler, is called.

SnowfallKeyPress = SnowfallKeyPress or {};
SnowfallKeyPress.animation = SnowfallKeyPress.animation or {};
SnowfallKeyPress.animation.handlers = SnowfallKeyPress.animation.handlers or {};

-- Set an animation handler for a specific button or set of buttons
--table.insert(SnowfallKeyPress.animation.handlers, animate);

-- Set the default animation handler
SnowfallKeyPress.animation.defaultHandler = animate;
