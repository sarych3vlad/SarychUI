local _, private = ...;
local GetAuctionItemClasses = GetAuctionItemClasses;
local Weapon, Armor, Container, Consumable, _, TradeGoods, Projectile, Quiver, Recipe, Gem, Misc, Quest = GetAuctionItemClasses();

private.config = {
	--	technical
	scale 		 = .85, 		 -- change size
	sound 		 = false, 	 -- play sound
	time 		 = .2, 	 -- time (delay) in milliseconds to show next toast (update time)
	numbuttons 	 = 5, 		 -- how many toasts to show at a time (max 8)
	anims		 = true,	 -- play animations
	offset_x 	 = 20,		 -- offset between toasts, if first is displayed then second will be higher/lower from previous
	point_x		 = 0,		 -- position of toast by X
	point_y		 = 0,        -- position of toast by Y
	castbar_offset = 110,	 -- additional Y offset when casting bar is shown
	
	--	activity
	looting		 = true,     -- fire when you yourself are looting something
	creating 	 = false,	 -- fire when you craft items
	rolling		 = true,	 -- fire when you roll items in an instance
	
	--	toasts
	money		 = true,	 -- display money toast
	recipes 	 = true,	 -- display recipe toast
	honor		 = true,	 -- display battleground toast
	
	--	filtering
	ignore_level = true, 	 -- filter for item quality, if true it will show all items quality
	low_level	 = 2,		 -- what item quality will be prioritized at low level (e.g. not less than 2 [uncommon])
	max_level	 = 4,		 -- what item quality will be prioritized at 80 level (e.g. not less than 4 [epic])
	--[[
		req. ignore_level = false
		[0] = poor, [1] = common, [2] = uncommon, [3] = rare, [4] = epic, [5] = legendary, [6] = artifact, [7] = heirloom
	]]
	
	filter 		 = false, 	 -- filtering for certain items by type
	-- 	which type of item we don't want to see (req. filter = true), localized auction slot names
	filter_type  = {
		MONEY,
		Weapon,
		-- Armor,
		-- 	etc..
	},
	
	--[[
		Possible itemType returns:
		Armor, Consumable, Container, Gem, Misc, MONEY, Recipe, Projectile, Quest, Quiver, TradeGoods, Weapon.
		Generally they are the same strings you see in the auction search tab.
	]] -- see more details: https://wowwiki-archive.fandom.com/wiki/ItemType
};