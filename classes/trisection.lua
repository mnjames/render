local plain = SILE.require("plain", "classes")
local trisection = plain { id = "trisection" }
-- SILE.languageSupport.loadLanguage("urd")

-- trisection:loadPackage("ruby")
-- trisection:loadPackage("interlinear")
trisection:loadPackage("masters")
trisection:defineMaster({
  id = "right",
  firstContentFrame = "content",
  frames = {
    content = {
      left = "5%pw",
      right = "95%pw",
      top = "10%ph",
      bottom = "top(interlinear)"
    },
    folio = {
      left = "left(content)",
      right = "right(content)",
      top = "bottom(notes)+3%ph",
      bottom = "bottom(notes)+5%ph"
    },
    interlinear = {
      left = "left(content)",
      right = "right(content)",
      height = "0",
      bottom = "top(ssv_lit)",
      -- direction = "RTL"
    },
    ssv_lit = {
      left = "left(content)",
      right = "right(content)",
      height = "0",
      bottom = "top(ssv)",
      direction = "RTL"
    },
    ssv = {
      left = "left(content)",
      right = "right(content)",
      height = "0",
      bottom = "top(notes)",
      direction = "RTL"
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

SILE.scratch.trisection = {
  counter = 0
}

trisection:loadPackage("twoside", { oddPageMaster = "right", evenPageMaster = "left" })

SILE.registerCommand("verse", function (options, content)
  -- SILE.scratch.trisection.verse = options.number
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

SILE.registerCommand("para-start", function (options, content)

end)

SILE.registerCommand("para-end", function (options, content)
  SILE.typesetter:leaveHmode()
end)

SILE.registerCommand("chapter", function (options, content)
  -- SILE.call("eject")
  -- SILE.call("par")
  SILE.typesetter:typeset("Chapter "..options.number)
  SILE.typesetter:leaveHmode()
  SILE.process(content)
end)

-- SILE.registerCommand("note", function (options, content)
--   SILE.call("footnote", options, content)
--   -- SILE.process(content)
-- end)

function trisection:init()
  trisection:mirrorMaster("right", "left")
  trisection.pageTemplate = SILE.scratch.masters["right"]
  trisection:loadPackage("interlinear", {
    insertInto = "interlinear",
    stealFrom = { "content" }
  })
  trisection:loadPackage("ssv-lit", {
    insertInto = "ssv_lit",
    stealFrom = { "content" }
  })
  trisection:loadPackage("ssv", {
    insertInto = "ssv",
    stealFrom = { "content" }
  })
  trisection:loadPackage("notes", {
    insertInto = "notes",
    stealFrom = { "content" }
  })
  return plain.init(self)
end

function trisection:newPage()
  trisection:switchPage()
  -- trisection:newPageInfo()
  return plain.newPage(self)
end

function trisection:finish()
  return plain.finish(trisection)
end

function trisection:endPage()
  -- if (trisection:oddPage() and SILE.scratch.headers.right) then
    -- SILE.typesetNaturally(SILE.getFrame("runningHead"), function ()
    --   SILE.settings.set("current.parindent", SILE.nodefactory.zeroGlue)
    --   SILE.settings.set("document.lskip", SILE.nodefactory.zeroGlue)
    --   SILE.settings.set("document.rskip", SILE.nodefactory.zeroGlue)
    --   -- SILE.settings.set("typesetter.parfillskip", SILE.nodefactory.zeroGlue)
    --   SILE.process(SILE.scratch.headers.right)
    --   SILE.call("par")
    -- end)
  -- elseif (not(trisection:oddPage()) and SILE.scratch.headers.left) then
  --     SILE.typesetNaturally(SILE.getFrame("runningHead"), function ()
  --       SILE.settings.set("current.parindent", SILE.nodefactory.zeroGlue)
  --       SILE.settings.set("document.lskip", SILE.nodefactory.zeroGlue)
  --       SILE.settings.set("document.rskip", SILE.nodefactory.zeroGlue)
  --         -- SILE.settings.set("typesetter.parfillskip", SILE.nodefactory.zeroGlue)
  --       SILE.process(SILE.scratch.headers.left)
  --       SILE.call("par")
  --     end)
  -- end
  return plain.endPage(trisection)
end

-- trisection.newPage = function(self)
--   plain.newPage(self)
--   if SILE.typesetter == trisection.intelinearTypesetter then
--     trisection.textTypesetter:initFrame(SILE.getFrame("text"))
--     trisection.notesTypesetter:initFrame(SILE.getFrame("notes"))
--     return SILE.getFrame("interlinear")
--   elseif SILE.typesetter == trisection.textTypesetter then
--     trisection.interlinearTypesetter:initFrame(SILE.getFrame("interlinear"))
--     trisection.notesTypesetter:initFrame(SILE.getFrame("notes"))
--     return SILE.getFrame("text")
--   else
--     trisection.interlinearTypesetter:initFrame(SILE.getFrame("interlinear"))
--     trisection.textTypesetter:initFrame(SILE.getFrame("text"))
--     return SILE.getFrame("notes")
--   end
-- end

-- trisection.endPage = function(self)
--   print("Page ended")
--   SILE.typesetter.other1:leaveHmode(1)
--   SILE.typesetter.other2:leaveHmode(1)
--   plain.endPage(self)
-- end

-- trisection.finish = function(self)
--   table.insert(SILE.typesetter.other1.state.outputQueue, SILE.nodefactory.vfillGlue)
--   table.insert(SILE.typesetter.other2.state.outputQueue, SILE.nodefactory.vfillGlue)
--   SILE.typesetter.other1:chuck()
--   SILE.typesetter.other2:chuck()
--   plain.finish(self)
-- end

return trisection