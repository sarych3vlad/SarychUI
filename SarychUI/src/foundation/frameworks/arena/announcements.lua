-- One classifier for arena timers, door countdown completion and text filtering.
local Announcements = {}
SarychUI.ArenaAnnouncements = Announcements
local lowerRu = {}
local upper = {"А","Б","В","Г","Д","Е","Ё","Ж","З","И","Й","К","Л","М","Н","О","П","Р","С","Т","У","Ф","Х","Ц","Ч","Ш","Щ","Ъ","Ы","Ь","Э","Ю","Я"}
local lower = {"а","б","в","г","д","е","ё","ж","з","и","й","к","л","м","н","о","п","р","с","т","у","ф","х","ц","ч","ш","щ","ъ","ы","ь","э","ю","я"}
for i, letter in ipairs(upper) do lowerRu[letter] = lower[i] end
local function Normalize(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    -- Byte-wise lower()/locale whitespace classes can corrupt UTF-8 on Windows.
    text = text:gsub("[A-Z]", string.lower)
    text = text:gsub("[\208\209][\128-\191]", lowerRu)
    return text:gsub("[ \t\r\n]+", " "):gsub("^ +", ""):gsub("[ !%.]+$", "")
end
local starts = {}
for _, text in ipairs({
    "The Arena battle has begun!", "The battle has begun!", "The Arena battle has started!",
    "Бой начался!", "Бой на арене начался!", "Битва на арене началась!",
    "Сражение на арене началось!", "Битва началась!", "Сражение началось!",
    "¡La batalla en arena ha comenzado!", "Der Arenakampf hat begonnen!",
    "Le combat d'arène commence", "A batalha na Arena começou!",
    "竞技场的战斗开始了", "競技場戰鬥開始了", "투기장 전투가 시작되었습니다",
}) do starts[Normalize(text)] = true end

function Announcements:IsStart(text)
    return type(text) == "string" and starts[Normalize(text)] == true
end
