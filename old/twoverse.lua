local plain = SILE.require("plain", "classes")
local twoverse = plain { id = "twoverse" }
-- SILE.languageSupport.loadLanguage("urd")

-- twoverse:loadPackage("ruby")
-- twoverse:loadPackage("interlinear")
twoverse:loadPackage("masters")
twoverse:defineMaster({
  id = "right",
  firstContentFrame = "content",
  frames = {
    content = {
      left = "5%pw",
      right = "95%pw",
      top = "10%ph",
      bottom = "top(notes)"
    },
    folio = {
      left = "left(content)",
      right = "right(content)",
      top = "bottom(notes)+3%ph",
      bottom = "bottom(notes)+5%ph"
    },
    notes = {
      left = "left(content)",
      right = "right(content)",
      height = "0",
      bottom = "83.3%ph",
      direction = "RTL"
    }
  }
})

SILE.scratch.twoverse = {}

twoverse:loadPackage("twoside", { oddPageMaster = "right", evenPageMaster = "left" })

SILE.registerCommand("verse", function (options, content)
  -- SILE.scratch.twoverse.verse = options.number
  SILE.typesetter:typeset(options.number.." ")
  SILE.process(content)
end)

SILE.registerCommand("urdu:font", function (options, content)
  SILE.call("font", {
    family = "Awami Nastaliq",
    size = "14pt",
    language = "urd",
    script = "Arab"
  })
end)

SILE.registerCommand("book", function (options, content)
  SILE.process(content)
end)

SILE.registerCommand("char", function (options, content)
  SILE.process(content)
end)

SILE.registerCommand("para-start", function (options, content)

end)

SILE.registerCommand("para-end", function (options, content)
  SILE.typesetter:leaveHmode()
end)

function writeChild (childContent)
  local content = {}
  for i, child in ipairs(childContent.interlinear) do
    table.insert(content, child)
  end
  table.insert(content, {
    attr = {},
    tag = "par"
  })
  for i, child in ipairs(childContent["ssv-lit"]) do
    table.insert(content, child)
  end
  table.insert(content, {
    attr = {},
    tag = "par"
  })
  for i, child in ipairs(childContent.ssv) do
    table.insert(content, child)
  end
  SILE.process(content)
end

SILE.registerCommand("chapter", function (options, content)
  -- SILE.call("eject")
  -- SILE.call("par")
  SILE.typesetter:typeset("Chapter "..options.number)
  SILE.typesetter:leaveHmode()
  local index = 0
  local childContent = {
    interlinear = {},
    ["ssv-lit"] = {},
    ssv = {}
  }
  for i, child in ipairs(content) do
    if child.tag then
      index = index + 1
      table.insert(childContent[child.tag], child)
      if index % 9 == 0 then
        -- print(childContent)
        writeChild(childContent)
        SILE.call("eject")
        SILE.call("par")
        childContent = {
          interlinear = {},
          ["ssv-lit"] = {},
          ssv = {}
        }
      end
    end
  end
  writeChild(childContent)
  -- SILE.process(content)
end)

SILE.registerCommand("item", function (options, content)
  -- SILE.call("ruby", {reading = options.vernacular}, options.greek)
  SILE.typesetter:typeset(options.greek.." ")
  SILE.call("font", {
    family = "Awami Nastaliq",
    size = "12pt",
    language = "urd",
    script = "Arab"
  }, function ()
    SILE.typesetter:typeset("("..options.vernacular..")")
  end)
  SILE.typesetter:typeset(" ")
end)

SILE.registerCommand("interlinear", function (options, content)
  SILE.call("font", {
    family = "Times New Roman",
    size = "14pt"
  })
  SILE.process(content)
end)

SILE.registerCommand("ssv-lit", function (options, content)
  SILE.call("font", {
    family = "Awami Nastaliq",
    size = "12pt",
    language = "urd",
    script = "Arab"
  })
  SILE.process(content)
end)

SILE.registerCommand("ssv", function (options, content)
  SILE.process(content)
end)

-- SILE.registerCommand("note", function (options, content)
--   SILE.call("footnote", options, content)
--   -- SILE.process(content)
-- end)

function twoverse:init()
  twoverse:mirrorMaster("right", "left")
  twoverse.pageTemplate = SILE.scratch.masters["right"]
  -- twoverse:loadPackage("interlinear", {
  --   insertInto = "interlinear",
  --   stealFrom = { "content" }
  -- })
  -- twoverse:loadPackage("ssv-lit", {
  --   insertInto = "ssv_lit",
  --   stealFrom = { "content" }
  -- })
  -- twoverse:loadPackage("ssv", {
  --   insertInto = "ssv",
  --   stealFrom = { "content" }
  -- })
  twoverse:loadPackage("notes", {
    insertInto = "notes",
    stealFrom = { "content" }
  })
  return plain.init(self)
end

function twoverse:newPage()
  twoverse:switchPage()
  -- twoverse:newPageInfo()
  return plain.newPage(self)
end

function twoverse:finish()
  return plain.finish(twoverse)
end

function twoverse:endPage()
  -- if (twoverse:oddPage() and SILE.scratch.headers.right) then
    -- SILE.typesetNaturally(SILE.getFrame("runningHead"), function ()
    --   SILE.settings.set("current.parindent", SILE.nodefactory.zeroGlue)
    --   SILE.settings.set("document.lskip", SILE.nodefactory.zeroGlue)
    --   SILE.settings.set("document.rskip", SILE.nodefactory.zeroGlue)
    --   -- SILE.settings.set("typesetter.parfillskip", SILE.nodefactory.zeroGlue)
    --   SILE.process(SILE.scratch.headers.right)
    --   SILE.call("par")
    -- end)
  -- elseif (not(twoverse:oddPage()) and SILE.scratch.headers.left) then
  --     SILE.typesetNaturally(SILE.getFrame("runningHead"), function ()
  --       SILE.settings.set("current.parindent", SILE.nodefactory.zeroGlue)
  --       SILE.settings.set("document.lskip", SILE.nodefactory.zeroGlue)
  --       SILE.settings.set("document.rskip", SILE.nodefactory.zeroGlue)
  --         -- SILE.settings.set("typesetter.parfillskip", SILE.nodefactory.zeroGlue)
  --       SILE.process(SILE.scratch.headers.left)
  --       SILE.call("par")
  --     end)
  -- end
  return plain.endPage(twoverse)
end

-- twoverse.newPage = function(self)
--   plain.newPage(self)
--   if SILE.typesetter == twoverse.intelinearTypesetter then
--     twoverse.textTypesetter:initFrame(SILE.getFrame("text"))
--     twoverse.notesTypesetter:initFrame(SILE.getFrame("notes"))
--     return SILE.getFrame("interlinear")
--   elseif SILE.typesetter == twoverse.textTypesetter then
--     twoverse.interlinearTypesetter:initFrame(SILE.getFrame("interlinear"))
--     twoverse.notesTypesetter:initFrame(SILE.getFrame("notes"))
--     return SILE.getFrame("text")
--   else
--     twoverse.interlinearTypesetter:initFrame(SILE.getFrame("interlinear"))
--     twoverse.textTypesetter:initFrame(SILE.getFrame("text"))
--     return SILE.getFrame("notes")
--   end
-- end

-- twoverse.endPage = function(self)
--   print("Page ended")
--   SILE.typesetter.other1:leaveHmode(1)
--   SILE.typesetter.other2:leaveHmode(1)
--   plain.endPage(self)
-- end

-- twoverse.finish = function(self)
--   table.insert(SILE.typesetter.other1.state.outputQueue, SILE.nodefactory.vfillGlue)
--   table.insert(SILE.typesetter.other2.state.outputQueue, SILE.nodefactory.vfillGlue)
--   SILE.typesetter.other1:chuck()
--   SILE.typesetter.other2:chuck()
--   plain.finish(self)
-- end

return twoverse