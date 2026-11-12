SarychUI.Compat.PartyUtil = {}
function SarychUI.Compat.PartyUtil.GetPhasedReasonString(reason)
    if reason then
        return PARTY_PHASED_MESSAGE or (GetLocale() == "ruRU" and "Игрок находится в другой фазе." or "Player is in a different phase.")
    end
end
