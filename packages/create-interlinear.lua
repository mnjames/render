-- local base = require "base"
-- local lom = require "lomwithpos"

-- local inter = lom.parse(base.readFile("../resources/Lexicon.xml"))

-- local map = {}
-- local entries = base.getChild(lexicon, "Entries")
-- local entry
-- for i, item in ipairs(entries) do
--   if item.tag == "item" then
--     entry = base.getChild(item, "Entry")
--     for j, sense in ipairs(entry) do
--       if sense.tag == "Sense" then
--         map[sense.attr.Id] = base.getChild(sense, "Gloss")[1]
--       end
--     end
--   end
-- end

-- base.writeFile('../resources/lexicon-map.lua', createLua(map))