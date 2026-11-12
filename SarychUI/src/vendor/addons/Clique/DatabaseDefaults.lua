local _, private = ...
private.Clique.defaults = {
    settings = {
        downclick = false,
        blizzframes = {
            PlayerFrame = true, PetFrame = true, TargetFrame = true, TargetFrameToT = true,
            FocusFrame = true, FocusFrameToT = true, party = true,
            compactraid = true, compactparty = true, arena = false, boss = false,
        },
    },
    bindings = {
        {key="BUTTON1", type="target", unit="mouseover", sets={default=true}},
        {key="BUTTON2", type="menu", sets={default=true}},
    },
}
