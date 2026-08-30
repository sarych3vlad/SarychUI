-- Global enabled state (SarychUI wrapper sets true on enable)
SnowfallKeyPressEnabled = false;

-- Function to check if addon is enabled
local function IsEnabled()
	if SnowfallKeyPressEnabled == false then
		return false;
	end
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.SnowfallKeyPress then
		return SarychUI.db.profile.addons.SnowfallKeyPress.enabled == true;
	end
	return SnowfallKeyPressEnabled == true;
end

local s=string.match;local C=string.gsub;local c=pairs;local n=ipairs;local m=_G;local r;local a;local l;local B=false;local u={};local F={{command="^ACTIONBUTTON(%d+)$",attributes={{"type","macro"},{"actionbutton","%1"}}},{command="^MULTIACTIONBAR1BUTTON(%d+)$",attributes={{"type","click"},{"clickbutton","MultiBarBottomLeftButton%1"}}},{command="^MULTIACTIONBAR2BUTTON(%d+)$",attributes={{"type","click"},{"clickbutton","MultiBarBottomRightButton%1"}}},{command="^MULTIACTIONBAR3BUTTON(%d+)$",attributes={{"type","click"},{"clickbutton","MultiBarRightButton%1"}}},{command="^MULTIACTIONBAR4BUTTON(%d+)$",attributes={{"type","click"},{"clickbutton","MultiBarLeftButton%1"}}},{command="^SHAPESHIFTBUTTON(%d+)$",attributes={{"type","click"},{"clickbutton","ShapeshiftButton%1"}}},{command="^BONUSACTIONBUTTON(%d+)$",attributes={{"type","click"},{"clickbutton","PetActionButton%1"}}},{command="^MULTICASTSUMMONBUTTON(%d+)$",attributes={{"type","click"},{"multicastsummon","%1"}}},{command="^MULTICASTRECALLBUTTON1$",attributes={{"type","click"},{"clickbutton","MultiCastRecallSpellButton"}}},{command="^CLICK (.+):([^:]+)$",attributes={{"type","click"},{"clickbutton","%1"}}},{command="^MACRO (.+)$",attributes={{"type","macro"},{"macro","%1"}}},{command="^SPELL (.+)$",attributes={{"type","spell"},{"spell","%1"}}},{command="^ITEM (.+)$",attributes={{"type","item"},{"item","%1"}}},};local d=true;local o=CreateFrame("Frame");local T={["actionbar"]=true,["action"]=true,["pet"]=true,["multispell"]=true,["spell"]=true,["item"]=true,["macro"]=true,["cancelaura"]=true,["stop"]=true,["target"]=true,["focus"]=true,["assist"]=true,["maintank"]=true,["mainassist"]=true};local f={"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z","0","1","2","3","4","5","6","7","8","9","`","-","=","[","]","\\",";","'",".",",","/","F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12","BACKSPACE","DELETE","DOWN","END","ENTER","ESCAPE","HOME","INSERT","LEFT","NUMLOCK","NUMPAD0","NUMPAD1","NUMPAD2","NUMPAD3","NUMPAD4","NUMPAD5","NUMPAD6","NUMPAD7","NUMPAD8","NUMPAD9","NUMPADDECIMAL","NUMPADDIVIDE","NUMPADMINUS","NUMPADMULTIPLY","NUMPADPLUS","PAGEDOWN","PAGEUP","PAUSE","RIGHT","SCROLLLOCK","SPACE","TAB","UP","BUTTON3","BUTTON4","BUTTON5",};local h={"ALT","CTRL","SHIFT",};local S={};local function i(e,o,t,n)local r=t[o];if(not r)then
table.insert(n,e);return;end
local o=o+1;i(e,o,t,n);i(e..r.."-",o,t,n);end
i("",1,h,S);local function i(n,o)local e,t;e=string.gsub(n,"^.*%-(.+)","%1",1);t=string.gsub(o,"^.*%-(.+)","%1",1);if(e<t)then
return true;elseif(e>t)then
return false;end
e=string.match(n,"ALT%-");t=string.match(o,"ALT%-");if(not e and t)then
return true;elseif(e and not t)then
return false;end
e=string.match(n,"CTRL%-");t=string.match(o,"CTRL%-");if(not e and t)then
return true;elseif(e and not t)then
return false;end
e=string.match(n,"SHIFT%-");t=string.match(o,"SHIFT%-");if(not e and t)then
return true;elseif(e and not t)then
return false;end
return nil;end
local function t(o)a[o]=true;local t,e;e=0;for r,n in n(r)do
t=i(o,n);if(t==nil)then
return nil;elseif(t==true)then
break;end
e=r;end
e=e+1;table.insert(r,e,o);return e;end
local function b(e)a[e]=nil;for t,n in n(r)do
if(e==n)then
table.remove(r,t);return t;end
end
return false;end
local i;local function h()wipe(a);wipe(r);for o,e in n(f)do
if(s(e,"-."))then
t(s(e,"^-?(.*)$"));else
for o,n in n(S)do
t(n..e);end
end
end
end
local e=CreateFrame("Frame",nil,UIParent);e:SetWidth(420);e:SetHeight(310);e:SetPoint("TOPLEFT",200,-200);e:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16,insets={left=4,right=4,top=4,bottom=4},});e:Hide();e.name="SnowfallKeyPress";e.title=e:CreateFontString(nil,"ARTWORK","GameFontNormalLarge");e.title:SetPoint("TOPLEFT",16,-16);e.title:SetPoint("RIGHT");e.title:SetText(e.name);e.title:SetJustifyH("LEFT");local A;do
local e=1;local t={"Sound\\Spells\\bloodlust_player_cast_head.wav","Sound\\Creature\\Doomwalker\\GRULLAIR_Doom_Over02.wav",};function A()if(SnowfallKeyPressSV.enable)then
PlaySoundFile(t[e]);e=(e%#t)+1;end
end
end
local function f(o,e)if(e=="UNKNOWN"or e=="LSHIFT"or e=="RSHIFT"or e=="LCTRL"or e=="RCTRL"or e=="LALT"or e=="RALT")then
return;end
if(e=="LeftButton")then
e="BUTTON1"elseif(e=="RightButton")then
e="BUTTON2"elseif(e=="MiddleButton")then
e="BUTTON3"else
e=string.gsub(e,"^Button(%d+)$","BUTTON%1");end
local o;for o,n in n(S)do
t(n..e);end
i();l();end
local function p(n,e)if(e=="UNKNOWN"or e=="LSHIFT"or e=="RSHIFT"or e=="LCTRL"or e=="RCTRL"or e=="LALT"or e=="RALT")then
return;end
if(e=="LeftButton")then
e="BUTTON1"elseif(e=="RightButton")then
e="BUTTON2"elseif(e=="MiddleButton")then
e="BUTTON3"else
e=string.gsub(e,"^Button(%d+)$","BUTTON%1");end
if(IsShiftKeyDown())then
e="SHIFT-"..e;end
if(IsControlKeyDown())then
e="CTRL-"..e;end
if(IsAltKeyDown())then
e="ALT-"..e;end
t(e);i();l();end
local function O(t,e)if(e=="UNKNOWN"or e=="LSHIFT"or e=="RSHIFT"or e=="LCTRL"or e=="RCTRL"or e=="LALT"or e=="RALT")then
return;end
if(e=="LeftButton")then
e="BUTTON1"elseif(e=="RightButton")then
e="BUTTON2"elseif(e=="MiddleButton")then
e="BUTTON3"else
e=string.gsub(e,"^Button(%d+)$","BUTTON%1");end
local t;for n,t in n(S)do
b(t..e);end
i();l();end
local function S(n,t)if(t=="UNKNOWN"or t=="LSHIFT"or t=="RSHIFT"or t=="LCTRL"or t=="RCTRL"or t=="LALT"or t=="RALT")then
return;end
if(t=="LeftButton")then
t="BUTTON1"elseif(t=="RightButton")then
t="BUTTON2"elseif(t=="MiddleButton")then
t="BUTTON3"else
t=string.gsub(t,"^Button(%d+)$","BUTTON%1");end
if(IsShiftKeyDown())then
t="SHIFT-"..t;end
if(IsControlKeyDown())then
t="CTRL-"..t;end
if(IsAltKeyDown())then
t="ALT-"..t;end
b(t);i();l();end
e.addAllButton=CreateFrame("Button",nil,e,"UIPanelButtonTemplate");e.addAllButton:SetWidth(130);e.addAllButton:SetHeight(44);e.addAllButton:SetPoint("TOPLEFT",16,-42);e.addAllButton:SetText("+\n("..MODIFIERS_COLON.." "..ALL..")");e.addAllButton:SetFrameStrata("DIALOG");e.addAllButton:SetScript("OnEnter",function(e)e:EnableKeyboard(true);end);e.addAllButton:SetScript("OnLeave",function(e)e:EnableKeyboard(false);end);e.addAllButton:SetScript("OnKeyDown",f);e.addAllButton:SetScript("OnClick",f);e.addAllButton:RegisterForClicks("AnyUp");e.addButton=CreateFrame("Button",nil,e,"UIPanelButtonTemplate");e.addButton:SetWidth(65);e.addButton:SetHeight(22);e.addButton:SetPoint("TOPLEFT",e.addAllButton,"BOTTOMLEFT",0,0);e.addButton:SetText("+");e.addButton:SetFrameStrata("DIALOG");e.addButton:SetScript("OnEnter",function(e)e:EnableKeyboard(true);end);e.addButton:SetScript("OnLeave",function(e)e:EnableKeyboard(false);end);e.addButton:SetScript("OnKeyDown",p);e.addButton:SetScript("OnClick",p);e.addButton:RegisterForClicks("AnyUp");e.subButton=CreateFrame("Button",nil,e,"UIPanelButtonTemplate");e.subButton:SetWidth(65);e.subButton:SetHeight(22);e.subButton:SetPoint("TOPLEFT",e.addButton,"TOPRIGHT",0,0);e.subButton:SetText("-");e.subButton:SetFrameStrata("DIALOG");e.subButton:SetScript("OnEnter",function(e)e:EnableKeyboard(true);end);e.subButton:SetScript("OnLeave",function(e)e:EnableKeyboard(false);end);e.subButton:SetScript("OnKeyDown",S);e.subButton:SetScript("OnClick",S);e.subButton:RegisterForClicks("AnyUp");e.subAllButton=CreateFrame("Button",nil,e,"UIPanelButtonTemplate");e.subAllButton:SetWidth(130);e.subAllButton:SetHeight(44);e.subAllButton:SetPoint("TOPRIGHT",e.subButton,"BOTTOMRIGHT",0,0);e.subAllButton:SetText("-\n("..MODIFIERS_COLON.." "..ALL..")");e.subAllButton:SetFrameStrata("DIALOG");e.subAllButton:SetScript("OnEnter",function(e)e:EnableKeyboard(true);end);e.subAllButton:SetScript("OnLeave",function(e)e:EnableKeyboard(false);end);e.subAllButton:SetScript("OnKeyDown",O);e.subAllButton:SetScript("OnClick",O);e.subAllButton:RegisterForClicks("AnyUp");e.clearAllButton=CreateFrame("Button",nil,e,"UIPanelButtonTemplate");e.clearAllButton:SetWidth(130);e.clearAllButton:SetHeight(22);e.clearAllButton:SetPoint("TOPLEFT",e.addAllButton,"TOPRIGHT",40,0);e.clearAllButton:SetText(CLEAR_ALL);e.clearAllButton:SetScript("OnClick",function()wipe(a);wipe(r);i();l();end);e.resetDefaultButton=CreateFrame("Button",nil,e,"UIPanelButtonTemplate");e.resetDefaultButton:SetWidth(130);e.resetDefaultButton:SetHeight(22);e.resetDefaultButton:SetPoint("TOPRIGHT",e.clearAllButton,"BOTTOMRIGHT",0,0);e.resetDefaultButton:SetText(RESET_TO_DEFAULT);e.resetDefaultButton:SetScript("OnClick",function()h();i();l();end);e.animationButton=CreateFrame("CheckButton","SnowfallKeyPress_configFrameAnimationButton",e,"UICheckButtonTemplate");e.animationButton:SetWidth(22);e.animationButton:SetHeight(22);e.animationButton:SetPoint("TOPLEFT",e.resetDefaultButton,"BOTTOMLEFT",0,-10);SnowfallKeyPress_configFrameAnimationButtonText:SetText(ANIMATION);e.animationButton:SetScript("OnClick",function(e)if(e:GetChecked())then SnowfallKeyPressSV.animation=true;else SnowfallKeyPressSV.animation=false;end end);e.enableButton=CreateFrame("CheckButton","SnowfallKeyPress_configFrameEnableButton",e,"UICheckButtonTemplate");e.enableButton:SetWidth(22);e.enableButton:SetHeight(22);e.enableButton:SetPoint("TOPLEFT",e.resetDefaultButton,"BOTTOMLEFT",0,-40);SnowfallKeyPress_configFrameEnableButtonText:SetText(ENABLE);e.enableButton:SetScript("OnClick",function(e)if(e:GetChecked())then SnowfallKeyPressSV.enable=true;o:RegisterEvent("UPDATE_BINDINGS");l();A();else SnowfallKeyPressSV.enable=false;l();end end);e.keyFrame=CreateFrame("Frame",nil,e);e.keyFrame:SetWidth(322);e.keyFrame:SetHeight(16*16+12);e.keyFrame:SetPoint("TOPLEFT",16,-155);e.keyFrame:SetBackdrop({bgFile="Interface\\BUTTONS\\WHITE8X8.BLP",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=16,insets={left=4,right=4,top=4,bottom=4},});e.keyFrame:SetBackdropColor(0,0,0,0);local S=16;e.keyRows={};for t=1,16 do
e.keyRows[t]=e:CreateFontString(nil,"ARTWORK","NumberFontNormalSmall");e.keyRows[t]:SetWidth(314);e.keyRows[t]:SetHeight(16);e.keyRows[t]:SetPoint("TOPLEFT",16,-146-16*t);e.keyRows[t]:SetJustifyH("RIGHT");e.keyRows[t]:SetText(t);end
function i()FauxScrollFrame_Update(e.scrollBar,#r,S,16);local n=FauxScrollFrame_GetOffset(e.scrollBar);for t=1,16 do
e.keyRows[t]:SetText(r[n+t]);end
end
e.scrollBar=CreateFrame("ScrollFrame","SnowfallKeyPress_configFrameScrollBar",e,"FauxScrollFrameTemplate");e.scrollBar:SetWidth(316);e.scrollBar:SetHeight(16*16);e.scrollBar:SetPoint("TOPLEFT",16,-162);e.scrollBar:SetScript("OnVerticalScroll",function(t,e)FauxScrollFrame_OnVerticalScroll(t,e,16,i);end);e.scrollBarTextureTop=e.scrollBar:CreateTexture();e.scrollBarTextureTop:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar");e.scrollBarTextureTop:SetWidth(31);e.scrollBarTextureTop:SetHeight(256);e.scrollBarTextureTop:SetPoint("TOPLEFT",e.scrollBar,"TOPRIGHT",-2,5);e.scrollBarTextureTop:SetTexCoord(0,.484375,0,1);e.scrollBarTextureBottom=e.scrollBar:CreateTexture();e.scrollBarTextureBottom:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar");e.scrollBarTextureBottom:SetWidth(31);e.scrollBarTextureBottom:SetHeight(106);e.scrollBarTextureBottom:SetPoint("BOTTOMLEFT",e.scrollBar,"BOTTOMRIGHT",-2,-2);e.scrollBarTextureBottom:SetTexCoord(.515625,1,0,.4140625);hooksecurefunc("ShowUIPanel",function()if(KeyBindingFrame)then KeyBindingFrame.mode=nil;end end);local b;local f;do
local n={};local t=0;function b()local e;if(#n>0)then
e=table.remove(n);else
t=t+1;e=CreateFrame("Button","SnowfallKeyPress_Button_"..tostring(t),nil,"SecureActionButtonTemplate");e:RegisterForClicks("AnyDown");SecureHandlerSetFrameRef(e,"VehicleMenuBar",VehicleMenuBar);SecureHandlerSetFrameRef(e,"BonusActionBarFrame",BonusActionBarFrame);SecureHandlerSetFrameRef(e,"MultiCastSummonSpellButton",MultiCastSummonSpellButton);SecureHandlerExecute(e,[[
          VehicleMenuBar = self:GetFrameRef("VehicleMenuBar");
          BonusActionBarFrame = self:GetFrameRef("BonusActionBarFrame");
          MultiCastSummonSpellButton = self:GetFrameRef("MultiCastSummonSpellButton");
        ]]);end
return e;end
function f(e)if(e)then
table.insert(n,e);end
end
end
local function I(e)return not not(type(e)=="table"and type(e.IsObjectType)=="function"and issecurevariable(e,"IsObjectType")and e:IsObjectType("Button")and select(2,e:IsProtected()));end
if(SnowfallKeyPress.animation.savedDefaultHandler)then
SnowfallKeyPress.animation.defaultHandler=SnowfallKeyPress.animation.savedDefaultHandler;SnowfallKeyPress.animation.savedDefaultHandler=nil;end
local function A(e)if(not SnowfallKeyPressSV.animation)then
return;end
local e=e.clickButtonName;if(not e)then
return;end
local e=m[e];if(not e)then
return;end
local t=false;for o,n in n(SnowfallKeyPress.animation.handlers)do
t=n(e)or t;end
if(not t and SnowfallKeyPress.animation.defaultHandler)then
SnowfallKeyPress.animation.defaultHandler(e);end
end
local function S(L,p,f,d,a)local e;local i,t;local l,h,O;local B,S,u;local c,r;a.override=nil;SetOverrideBinding(o,false,f,nil);for F,o in n(F)do
if(s(d,o.command))then
if(o.attributes)then
c,l=s(d,"^CLICK (.+):([^:]+)$");if(c)then
r=m[c];if(not I(r)or not l or r:GetAttribute("","downbutton",l))then
return;end
-- harmbutton/helpbutton may be nil; this client's SecureButton_GetModifiedAttribute errors on nil button.
h=SecureButton_GetModifiedAttribute(r,"harmbutton",l);O=SecureButton_GetModifiedAttribute(r,"helpbutton",l);B=SecureButton_GetModifiedAttribute(r,"type",l);S=h and SecureButton_GetModifiedAttribute(r,"type",h) or nil;u=O and SecureButton_GetModifiedAttribute(r,"type",O) or nil;if(B and not T[B]or S and not T[S]or u and not T[u])then
return;end
else
l="LeftButton";end
e=a.button;if(not e)then
e=b();a.button=e;end
SecureHandlerUnwrapScript(e,"OnClick");for r,n in n(o.attributes)do
i=n[1];t=C(d,o.command,n[2],1);if(i=="clickbutton")then
e:SetAttribute(i,m[t]);e.clickButtonName=t;e:SetScript("PostClick",A);elseif(i=="actionbutton")then
SecureHandlerWrapScript(e,"OnClick",e,[[
                if (VehicleMenuBar:IsProtected() and VehicleMenuBar:IsShown() and ]]..tostring(tonumber(t)<=VEHICLE_MAX_ACTIONBUTTONS)..[[) then
                  self:SetAttribute("macrotext", "/click VehicleMenuBarActionButton]]..t..[[");
                elseif (BonusActionBarFrame:IsProtected() and BonusActionBarFrame:IsShown()) then
                  self:SetAttribute("macrotext", "/click BonusActionButton]]..t..[[");
                else
                  self:SetAttribute("macrotext", "/click ActionButton]]..t..[[");
                end
              ]]);e:SetScript("PostClick",function(e)e.clickButtonName=string.sub(e:GetAttribute("macrotext"),8);A(e);end);elseif(i=="multicastsummon")then
SecureHandlerWrapScript(e,"OnClick",e,[[
                lastID = MultiCastSummonSpellButton:GetID();
                MultiCastSummonSpellButton:SetID(]]..t..[[);
              ]],[[
                MultiCastSummonSpellButton:SetID(lastID);
              ]]);e:SetAttribute("clickbutton",MultiCastSummonSpellButton);e.clickButtonName="MultiCastSummonSpellButton";else
e:SetAttribute(i,t);end
end
a.override="CLICK "..e:GetName()..":"..l;SetOverrideBinding(L,p,f,a.override);end
return;end
end
end
function l()if(InCombatLockdown())then
return;end
d=false;if(not IsEnabled() or not SnowfallKeyPressSV.enable)then
o:UnregisterEvent("UPDATE_BINDINGS");ClearOverrideBindings(o);for t,o in c(u)do
for n,e in n(o.normals)do
SetOverrideBinding(e.owner,false,t,e.command);end
for n,e in n(o.prioritys)do
SetOverrideBinding(e.owner,true,t,e.command);end
end
d=true;B=true;return;end
boundKeyColor=not boundKeyColor;local r,e;for t in c(a)do
r=GetBindingAction(t);if(r)then
e=u[t];if(not e)then
e={normals={},prioritys={}};u[t]=e;end
e.color=boundKeyColor;e.command=r;S(o,false,t,r,e);if(e.override)then
for n,e in n(e.normals)do
SetOverrideBinding(e.owner,false,t,e.override);end
end
end
end
for t,e in c(u)do
if(e.command and e.color~=boundKeyColor)then
e.command=nil;if(e.override)then
e.override=nil;SetOverrideBinding(o,false,t,nil);end
end
end
if(B)then
B=false;for t,o in c(u)do
for n,e in n(o.normals)do
if(e.override)then
SetOverrideBinding(e.owner,false,t,e.override);else
S(e.owner,false,t,e.command,e);end
end
for n,e in n(o.prioritys)do
if(e.override)then
SetOverrideBinding(e.owner,true,t,e.override);else
S(e.owner,true,t,e.command,e);end
end
end
end
d=true;end
local function T(t,e)local n;for n,o in c(e.normals)do
if(o.owner==t)then
return table.remove(e.normals,n);end
end
for n,o in c(e.prioritys)do
if(o.owner==t)then
return table.remove(e.prioritys,n);end
end
end
local function s(o,l,n,r)if(not d)then
return;end
if(not IsEnabled())then
return;end
local e=u[n];if(not e)then
e={normals={},prioritys={}};u[n]=e;end
if(not r)then
local e=T(o,e);if(e)then
f(e.button);end
return;end
local t=T(o,e)or{owner=o};t.command=r;t.override=nil;if(a[n]and IsEnabled() and SnowfallKeyPressSV.enable)then
if(InCombatLockdown())then
B=true;else
d=false;S(o,l,n,r,t);d=true;end
end
if(l)then
table.insert(e.prioritys,t);else
table.insert(e.normals,t);end
end
local function B(n,r,t,o,e)if(not e)then
e="LeftButton";end
s(n,r,t,"CLICK "..o..":"..e);end
local function S(o,n,e,t)s(o,n,e,"SPELL "..t);end
local function t(o,e,t,n)s(o,e,t,"ITEM "..n);end
local function T(o,n,t,e)s(o,n,t,"MACRO "..e);end
hooksecurefunc("SetOverrideBinding",s);hooksecurefunc("SetOverrideBindingClick",B);hooksecurefunc("SetOverrideBindingSpell",S);hooksecurefunc("SetOverrideBindingItem",t);hooksecurefunc("SetOverrideBindingMacro",T);local function s(o)if(not d)then
return;end
if(not IsEnabled())then
return;end
local e;for n,t in c(u)do
for n=#t.normals,1,-1 do
e=t.normals[n];if(e.owner==o)then
f(e.button);table.remove(t.normals,n);end
end
for n=#t.prioritys,1,-1 do
e=t.prioritys[n];if(e.owner==o)then
f(e.button);table.remove(t.prioritys,n);end
end
end
end
hooksecurefunc("ClearOverrideBindings",s);local function t()if(not SnowfallKeyPressSV)then
SnowfallKeyPressSV={keys={},animation=true,enable=true};end
if(not IsEnabled())then
SnowfallKeyPressSV.enable=false;end
r=SnowfallKeyPressSV.keys;a={};for n,t in n(r)do
a[t]=true;end
e.enableButton:SetChecked(SnowfallKeyPressSV.enable and IsEnabled());e.animationButton:SetChecked(SnowfallKeyPressSV.animation);if(#r==0)then
h();end
i();
if IsEnabled() then
	SnowfallKeyPress_RegisterInterfaceOptions()
end
o:UnregisterAllEvents();o:SetScript("OnEvent",l);if(IsEnabled())then
o:RegisterEvent("UPDATE_BINDINGS");end
end
-- SarychUI: defer Blizzard category until embedded addon is enabled
function SnowfallKeyPress_RegisterInterfaceOptions()
	if e._suiBlizRegistered then return end
	if not SnowfallKeyPressEnabled then return end
	InterfaceOptions_AddCategory(e)
	e._suiBlizRegistered = true
end
function SnowfallKeyPress_ApplyEmbeddedRuntime(enable)
	SnowfallKeyPressEnabled = enable and true or false
	if enable then
		if SnowfallKeyPressSV then
			SnowfallKeyPressSV.enable = true
		end
		SnowfallKeyPress_RegisterInterfaceOptions()
		o:RegisterEvent("UPDATE_BINDINGS")
		if SnowfallKeyPressSV then
			l()
		end
	else
		if SnowfallKeyPressSV then
			SnowfallKeyPressSV.enable = false
		end
		o:UnregisterEvent("UPDATE_BINDINGS")
		if SnowfallKeyPressSV then
			l()
		end
	end
	if e.enableButton and SnowfallKeyPressSV then
		e.enableButton:SetChecked(SnowfallKeyPressSV.enable and IsEnabled())
	end
end
o:SetScript("OnEvent",t);o:RegisterEvent("ADDON_LOADED");