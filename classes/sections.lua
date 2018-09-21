local plain = SILE.require("plain", "classes")
local sections = plain { id = "sections" }

SILE.require("packages/raiselower")

SILE.scratch.sections = {}

SILE.settings.set("document.baselineskip", SILE.nodefactory.newVglue("30pt"))
SILE.settings.set("typesetter.parseppattern", -1)

sections:loadPackage("masters")
sections:loadPackage("build-interlinear")
sections:defineMaster({
  id = "right",
  firstContentFrame = "contentA",
  frames = {
    title = {
      right = "right(contentA)",
      left = "left(contentB)",
      top = "10%ph",
      height = "0",
      bottom = "top(contentA)"
    },
    contentA = {
      right = "93.7%pw",
      left = "right(gutter)",
      height = "75%ph",
      top = "bottom(title)",
      next = "contentB",
      direction = "RTL"
    },
    interlinearA = {
      right = "right(contentA)",
      left = "left(contentA)",
      height = "75%ph"
    },
    ssvLitA = {
      right = "right(contentA)",
      left = "left(contentA)",
      height = "75%ph",
      direction = "RTL"
    },
    ssvA = {
      right = "right(contentA)",
      left = "left(contentA)",
      height = "75%ph",
      direction = "RTL"
    },
    notesA = {
      right = "right(contentA)",
      left = "left(contentA)",
      height = "75%ph",
      direction = "RTL"
    },
    contentB = {
      right = "left(gutter)",
      width = "width(contentA)",
      left = "14%pw",
      height = "75%ph",
      top = "bottom(title)",
      direction = "RTL"
    },
    interlinearB = {
      right = "right(contentB)",
      left = "left(contentB)",
      height = "75%ph"
    },
    ssvLitB = {
      right = "right(contentB)",
      left = "left(contentB)",
      height = "75%ph",
      direction = "RTL"
    },
    ssvB = {
      right = "right(contentB)",
      left = "left(contentB)",
      height = "75%ph",
      direction = "RTL"
    },
    notesB = {
      right = "right(contentB)",
      left = "left(contentB)",
      height = "75%ph",
      direction = "RTL"
    },
    folio = {
      left = "left(contentB)",
      right = "right(contentA)",
      top = "86.3%ph",
      bottom = "88.3%ph"
    },
    gutter = {
      left = "right(contentB)",
      right = "left(contentA)",
      width = "3%pw"
    }
  }
})
sections:defineMaster({
  id = "left",
  firstContentFrame = "contentA",
  frames = {
    title = {
      right = "right(contentA)",
      left = "left(contentB)",
      top = "10%ph",
      height = "0",
      bottom = "top(contentA)"
    },
    contentA = {
      right = "86%pw",
      left = "right(gutter)",
      height = "75%ph",
      top = "bottom(title)",
      next = "contentB",
      direction = "RTL"
    },
    interlinearA = {
      right = "right(contentA)",
      left = "left(contentA)",
      height = "75%ph"
    },
    ssvLitA = {
      right = "right(contentA)",
      left = "left(contentA)",
      height = "75%ph",
      direction = "RTL"
    },
    ssvA = {
      right = "right(contentA)",
      left = "left(contentA)",
      height = "75%ph",
      direction = "RTL"
    },
    notesA = {
      right = "right(contentA)",
      left = "left(contentA)",
      height = "75%ph",
      direction = "RTL"
    },
    contentB = {
      right = "left(gutter)",
      width = "width(contentA)",
      left = "6.3%pw",
      height = "75%ph",
      top = "bottom(title)",
      direction = "RTL"
    },
    interlinearB = {
      right = "right(contentB)",
      left = "left(contentB)",
      height = "75%ph"
    },
    ssvLitB = {
      right = "right(contentB)",
      left = "left(contentB)",
      height = "75%ph",
      direction = "RTL"
    },
    ssvB = {
      right = "right(contentB)",
      left = "left(contentB)",
      height = "75%ph",
      direction = "RTL"
    },
    notesB = {
      right = "right(contentB)",
      left = "left(contentB)",
      height = "75%ph",
      direction = "RTL"
    },
    folio = {
      left = "left(contentB)",
      right = "right(contentA)",
      top = "86.3%ph",
      bottom = "88.3%ph"
    },
    gutter = {
      left = "right(contentB)",
      right = "left(contentA)",
      width = "3%pw"
    }
    -- notes = {
    --   left = "left(content)",
    --   right = "right(content)",
    --   height = "50%ph",
    --   -- bottom = "83.3%ph",
    --   direction = "RTL"
    -- }
  }
})

sections.mainTypesetter = SILE.defaultTypesetter {}
sections.interlinearTypesetter = SILE.defaultTypesetter {}
sections.ssvLitTypesetter = SILE.defaultTypesetter {}
sections.ssvTypesetter = SILE.defaultTypesetter {}
sections.notesTypesetter = SILE.defaultTypesetter {}
local typesetters = {
  content = sections.mainTypesetter,
  interlinear = sections.interlinearTypesetter,
  ssvLit = sections.ssvLitTypesetter,
  ssv = sections.ssvTypesetter,
  notes = sections.notesTypesetter
}

local charStyles = {
  zheb = {
    family = "Times New Roman"
  },
  zgrk = {
    family = "Times New Roman"
  }
}

local state = {
  section = "content"
}

function resetState ()
  state.heights = {
    content = 0,
    interlinear = 0,
    ssv = 0,
    ssvLit = 0,
    notes = 0
  }
end

resetState()

function clone (obj)
  local cl = {}
  for key, value in pairs(obj) do
    cl[key] = value
  end
  return cl
end

function calculateHeight ()
  -- local nodes = clone(SILE.typesetter.state.nodes)
  local vboxes = SILE.typesetter:boxUpNodes()
  local outputQueue = SILE.typesetter.state.outputQueue
  -- SILE.typesetter.state.nodes = nodes

  local height = 0
  for _, vbox in ipairs(vboxes) do
    height = height + vbox.height + vbox.depth
  end
  for _, vbox in ipairs(outputQueue) do
    height = height + vbox.height + vbox.depth
  end
  return height
end

function breakNeeded ()
  local totalHeight = 0
  for _, height in pairs(state.heights) do
    totalHeight = totalHeight + height
  end
  return totalHeight > state.availableHeight
end

function process (content)
  content = content or {}
  local saveNodes = clone(SILE.typesetter.state.nodes)
  local saveOutputQueue = clone(SILE.typesetter.state.outputQueue)
  local saveHeight = state.heights[state.section]
  print("Processing content for frame "..SILE.typesetter.frame.id)
  SILE.process(content)
  state.heights[state.section] = calculateHeight()
  print("Height", state.heights[state.section])
  SILE.typesetter.state.nodes = saveNodes
  SILE.typesetter.state.outputQueue = saveOutputQueue
  local saveTypesetter = SILE.typesetter
  if breakNeeded() then
    state.heights[state.section] = saveHeight
    local pageBreak = isPageBreak()
    buildConstraints()
    doSwitch(pageBreak)
    print("Reprocessing Content")
    SILE.typesetter = saveTypesetter
    SILE.process(content)
    state.heights[state.section] = calculateHeight()
    print("Done")
  else
    SILE.process(content)
  end
  SILE.typesetter = sections.mainTypesetter
end

function setHeight(frame, frameType)
  local height = state.heights[frameType]
  if height > 0 then
    height = height + SILE.toAbsoluteMeasurement(10, "%ph")
  end
  if type(height) ~= "number" then
    height = height.length + height.stretch
  end
  print("Constraining "..frameType.." to "..height)
  frame:constrain("height", height)
end

function buildConstraints ()
  local contentFrame = sections.mainTypesetter.frame
  local interlinearFrame = sections.interlinearTypesetter.frame
  local ssvLitFrame = sections.ssvLitTypesetter.frame
  local ssvFrame = sections.ssvTypesetter.frame
  local notesFrame = sections.notesTypesetter.frame
  contentFrame:relax("bottom")
  interlinearFrame:relax("top")
  setHeight(contentFrame, "content")
  setHeight(interlinearFrame, "interlinear")
  setHeight(ssvLitFrame, "ssvLit")
  setHeight(ssvFrame, "ssv")
  setHeight(notesFrame, "notes")
  contentFrame:constrain("bottom", "top("..interlinearFrame.id..")")
  interlinearFrame:constrain("top", "bottom("..contentFrame.id..")")
  ssvLitFrame:constrain("top", "bottom("..interlinearFrame.id..") + 2%ph")
  ssvFrame:constrain("top", "bottom("..ssvLitFrame.id..") + 2%ph")
  notesFrame:constrain("bottom", "top(folio) - 3%ph")
  fixCursors()
end

function fixCursors ()
  for _, typesetter in pairs(typesetters) do
    local frame = typesetter.frame
    frame.state.cursorY = frame:top()
  end
end

function isPageBreak ()
  local _, subs = string.gsub(SILE.typesetter.frame.id, 'A', 'B')
  return subs == 0
end

function doSwitch(pageBreak)
  resetState()
  for frame, typesetter in pairs(typesetters) do
    SILE.typesetter = typesetter
    -- SILE.typesetter:leaveHmode()
    print('Chucking '..SILE.typesetter.frame.id)
    SILE.typesetter:chuck()
    SILE.typesetter.frame:leave()
    if pageBreak then
      -- SILE.call("eject")
      -- SILE.call("par")
    else
      typesetter:initFrame(SILE.getFrame(frame..'B'))
    end
  end
  SILE.typesetter = sections.mainTypesetter
  if pageBreak then
    SILE.call("eject")
    SILE.call("par")
  end
end

sections:loadPackage("twoside", { oddPageMaster = "right", evenPageMaster = "left" })

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
  
end)

SILE.registerCommand("char", function (options, content)
  SILE.call("font", charStyles[options.style] or {}, function ()
    SILE.process(content)
  end)
end)

SILE.registerCommand("para-start", function (options, content)
  SILE.call("urdu:font")
end)

SILE.registerCommand("para-end", function (options, content)
  SILE.typesetter:leaveHmode()
  -- process()
end)

SILE.registerCommand("chapter", function (options, content)
  buildConstraints()
  doSwitch(isPageBreak())
  SILE.typesetter = sections.mainTypesetter
  state.section = "content"
  SILE.scratch.sections.notesNumber = 1
  process({options.number})
  -- SILE.typesetter:typeset(options.number)
  SILE.typesetter:leaveHmode()
  SILE.process(content)
end)

SILE.registerCommand("interlinear", function (options, content)
  local oldT = SILE.typesetter
  SILE.typesetter = sections.interlinearTypesetter
  state.section = "interlinear"
  process(content)
  SILE.typesetter = oldT
  state.section = "content"
end)

-- SILE.registerCommand("item", function (options, content)
--   -- SILE.call("ruby", {reading = options.vernacular}, options.greek)
--   SILE.call("font", {
--     family = "Times New Roman",
--     size = "12pt",
--     language = "el"
--   }, function ()
--     SILE.typesetter:typeset(options.greek.." ")
--   end)
--   SILE.typesetter:typeset("("..options.vernacular..") ")
-- end)

SILE.registerCommand("ssv-lit", function (options, content)
  local oldT = SILE.typesetter
  SILE.typesetter = sections.ssvLitTypesetter
  state.section = "ssvLit"
  process(content)
  SILE.typesetter = oldT
  state.section = "content"
end)

SILE.registerCommand("ssv", function (options, content)
  -- We have to do this one differently, due to its multi-frame nature
  SILE.typesetter = sections.ssvTypesetter

  local saveSsvNodes = clone(SILE.typesetter.state.nodes)
  local saveSsvOutputQueue = clone(SILE.typesetter.state.outputQueue)
  local saveSsvHeight = state.heights.ssv
  local saveNotesNodes = clone(sections.notesTypesetter.state.nodes)
  local saveNotesOutputQueue = clone(sections.notesTypesetter.state.outputQueue)
  local saveNotesHeight = state.heights.notes
  print("Processing content for frame "..SILE.typesetter.frame.id)
  SILE.scratch.sections.initialPass = true
  SILE.process(content)
  SILE.scratch.sections.initialPass = false
  state.heights.ssv = calculateHeight()
  SILE.typesetter = sections.notesTypesetter
  state.heights.notes = calculateHeight()
  print("Height", state.heights.ssv)
  print("Height", state.heights.notes)
  SILE.typesetter = sections.ssvTypesetter
  SILE.typesetter.state.nodes = saveSsvNodes
  SILE.typesetter.state.outputQueue = saveSsvOutputQueue
  sections.notesTypesetter.state.nodes = saveNotesNodes
  sections.notesTypesetter.state.outputQueue = saveNotesOutputQueue
  if breakNeeded() then
    state.heights.ssv = saveSsvHeight
    state.heights.notes = saveNotesHeight
    local pageBreak = isPageBreak()
    buildConstraints()
    doSwitch(pageBreak)
    print("Reprocessing Content")
    SILE.typesetter = sections.ssvTypesetter
    SILE.process(content)
    state.heights.ssv = calculateHeight()
    SILE.typesetter = sections.notesTypesetter
    state.heights.notes = calculateHeight()
    print("Done")
  else
    SILE.process(content)
  end
  SILE.typesetter = sections.mainTypesetter
  state.section = "content"
end)

SILE.registerCommand("note", function (options, content)
  SILE.Commands["raise"]({height = "0.7ex"}, function()
    SILE.Commands["font"]({ size = "1.5ex" }, function()
      SILE.typesetter:typeset(tostring(SILE.scratch.sections.notesNumber))
    end)
  end)
  local oldT = SILE.typesetter
  SILE.typesetter = sections.notesTypesetter
  SILE.call("font", {size = "7pt"}, function()
    SILE.typesetter:typeset(SILE.scratch.sections.notesNumber.." ")
    SILE.process(content)
  end)
  if not SILE.scratch.sections.initialPass then
    SILE.scratch.sections.notesNumber = SILE.scratch.sections.notesNumber + 1
  end
  SILE.typesetter = oldT
end)

function sections:init()
  sections.options.papersize("11in x 8.5in")
  -- sections:mirrorMaster("right", "left")
  sections.pageTemplate = SILE.scratch.masters["right"]
  state.availableHeight = SILE.toAbsoluteMeasurement(SILE.toMeasurement(61.3, '%ph'))

  local ret = plain.init(self)
  sections.mainTypesetter:init(SILE.getFrame("contentA"))
  sections.interlinearTypesetter:init(SILE.getFrame("interlinearA"))
  sections.ssvLitTypesetter:init(SILE.getFrame("ssvLitA"))
  sections.ssvTypesetter:init(SILE.getFrame("ssvA"))
  sections.notesTypesetter:init(SILE.getFrame("notesA"))
  SILE.typesetter = sections.mainTypesetter
  return ret
end

function sections:newPage()
  print("NEW PAGE")
  self:switchPage()
  local r = plain.newPage(self)
  -- for id, _ in pairs(SILE.frames) do print(id) end
  local currentTypesetter = SILE.typesetter
  for frame, typesetter in pairs(typesetters) do
    if typesetter ~= currentTypesetter then
      typesetter:initFrame(SILE.getFrame(frame.."A"))
    end
  end
  return r
end

-- function sections:endPage ()
--   print("END PAGE")
--   -- local currentTypesetter = SILE.typesetter
--   -- for frame, typesetter in pairs(typesetters) do
--   --   if typesetter ~= currentTypesetter then
--   --     -- typesetter:initFrame(SILE.getFrame(frame.."A"))
--   --     typesetter:leaveHmode(1)
--   --   end
--   -- end
--   plain.endPage(self)
-- end

function sections:finish ()
  buildConstraints()
  for frame, typesetter in pairs(typesetters) do
    SILE.typesetter = typesetter
    SILE.typesetter:chuck()
  end
  plain.finish(self)
end

return sections