local plain = SILE.require("plain", "classes")
local sections = plain { id = "sections" }

SILE.require("packages/raiselower")

SILE.scratch.sections = {}

SILE.settings.set("document.parindent", SILE.nodefactory.newGlue("0pt"))
SILE.settings.set("typesetter.parseppattern", -1)

sections:loadPackage("masters")
sections:loadPackage("build-interlinear")
-- sections:loadPackage("linespacing")
sections:loadPackage("rules")
sections:loadPackage("bidi")
sections:defineMaster({
  id = "right",
  firstContentFrame = "content",
  frames = {
    title = {
      right = "right(content)",
      left = "left(content)",
      top = "10%ph",
      height = "0",
      bottom = "top(content)"
    },
    content = {
      right = "93.7%pw",
      left = "14%pw",
      height = "75%ph",
      top = "bottom(title)",
      direction = "RTL"
    },
    interlinear = {
      right = "right(content)",
      left = "left(content)",
      height = "75%ph"
    },
    ssvLit = {
      right = "right(content)",
      left = "left(content)",
      height = "75%ph",
      direction = "RTL"
    },
    ssv = {
      right = "right(content)",
      left = "left(content)",
      height = "75%ph",
      direction = "RTL"
    },
    notes = {
      right = "right(content)",
      left = "left(content)",
      height = "75%ph",
      direction = "RTL"
    },
    folio = {
      left = "left(content)",
      right = "right(content)",
      top = "86.3%ph",
      bottom = "88.3%ph"
    }
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
  local vboxes = SILE.typesetter:boxUpNodes()
  local outputQueue = SILE.typesetter.state.outputQueue

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
  SILE.process(content)
  state.heights[state.section] = calculateHeight()
  SILE.typesetter.state.nodes = saveNodes
  SILE.typesetter.state.outputQueue = saveOutputQueue
  local saveTypesetter = SILE.typesetter
  if breakNeeded() then
    state.heights[state.section] = saveHeight
    buildConstraints()
    doSwitch()
    SILE.typesetter = saveTypesetter
    SILE.process(content)
    state.heights[state.section] = calculateHeight()
  else
    SILE.process(content)
  end
  SILE.typesetter = sections.mainTypesetter
end

function setHeight(frame, frameType)
  local height = state.heights[frameType]
  if type(height) ~= "number" then
    height = height.length + height.stretch
  end
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

function addRule (typesetter)
  if #typesetter.state.nodes > 0 and typesetter ~= sections.mainTypesetter then
    SILE.call("par")
    local width
    if typesetter == sections.interlinearTypesetter then
      width = "100%fw"
    else
      width = "-100%fw"
    end
    SILE.call("hrule", {
      height = "1pt",
      width = width
    })
  end
end

function doSwitch()
  resetState()
  for frame, typesetter in pairs(typesetters) do
    SILE.typesetter = typesetter
    addRule(typesetter)
    SILE.typesetter:chuck()
    SILE.typesetter.frame:leave()
  end
  SILE.typesetter = sections.mainTypesetter
  SILE.call("eject")
  SILE.call("par")
end

sections:loadPackage("twoside", { oddPageMaster = "right", evenPageMaster = "left" })

SILE.registerCommand("verse", function (options, content)
  -- SILE.scratch.twoverse.verse = options.number
  SILE.typesetter:typeset(options.number.." ")
  SILE.process(content)
end)

SILE.registerCommand("book", function (options, content)
  
end)

SILE.registerCommand("char", function (options, content)
  SILE.call("bidi-on")
  SILE.call("font", charStyles[options.style] or {}, function ()
    SILE.process(content)
  end)
end)

SILE.registerCommand("para-start", function (options, content)
  -- SILE.call("urdu:font")
end)

SILE.registerCommand("para-end", function (options, content)
  SILE.typesetter:leaveHmode()
  -- process()
end)

SILE.registerCommand("chapter", function (options, content)
  buildConstraints()
  doSwitch()
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

SILE.registerCommand("ssv-lit", function (options, content)
  local oldT = SILE.typesetter
  SILE.typesetter = sections.ssvLitTypesetter
  state.section = "ssvLit"
  SILE.call("bidi-on")
  process(content)
  SILE.typesetter = oldT
  state.section = "content"
  SILE.call("bidi-off")
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
  SILE.scratch.sections.initialPass = true
  SILE.call("bidi-on")
  SILE.process(content)
  SILE.scratch.sections.initialPass = false
  state.heights.ssv = calculateHeight()
  SILE.typesetter = sections.notesTypesetter
  state.heights.notes = calculateHeight()
  SILE.typesetter = sections.ssvTypesetter
  SILE.typesetter.state.nodes = saveSsvNodes
  SILE.typesetter.state.outputQueue = saveSsvOutputQueue
  sections.notesTypesetter.state.nodes = saveNotesNodes
  sections.notesTypesetter.state.outputQueue = saveNotesOutputQueue
  if breakNeeded() then
    state.heights.ssv = saveSsvHeight
    state.heights.notes = saveNotesHeight
    buildConstraints()
    doSwitch()
    SILE.typesetter = sections.ssvTypesetter
    SILE.process(content)
    state.heights.ssv = calculateHeight()
    SILE.typesetter = sections.notesTypesetter
    state.heights.notes = calculateHeight()
  else
    SILE.process(content)
  end
  SILE.typesetter = sections.mainTypesetter
  state.section = "content"
  SILE.call("bidi-off")
end)

SILE.registerCommand("note", function (options, content)
  SILE.Commands["raise"]({height = "0.7ex"}, function()
    SILE.Commands["font"]({ size = "1.5ex" }, function()
      SILE.typesetter:typeset(tostring(SILE.scratch.sections.notesNumber))
    end)
  end)
  local oldT = SILE.typesetter
  SILE.typesetter = sections.notesTypesetter
  SILE.call("bidi-on")
  SILE.settings.temporarily(function ()
    SILE.call("font", {size = "7pt"})
    -- SILE.settings.set("document.baselineskip", SILE.nodefactory.newVglue("5pt"))
    -- SILE.settings.set("document.lineskip", SILE.nodefactory.newVglue("30pt"))
    SILE.call("set", {
      parameter = "document.lineskip",
      value = "0.7ex"
    })
    -- SILE.call("set", {
    --   parameter = "linespacing.method",
    --   value = "fixed"
    -- })
    -- SILE.call("set", {
    --   parameter = "linespacing.fixed.baselinedistance",
    --   value = "50pt"
    -- })
    -- SILE.typesetter:typeset(SILE.scratch.sections.notesNumber.." ")
    -- print('==================== BEGIN')
    SILE.process(content)
    SILE.call("par")
    -- print('END ====================')
  end)
  if not SILE.scratch.sections.initialPass then
    SILE.scratch.sections.notesNumber = SILE.scratch.sections.notesNumber + 1
  end
  SILE.typesetter = oldT
  -- SILE.call("bidi-off")
end)

function sections:init()
  -- sections.options.papersize("11in x 8.5in")
  sections:mirrorMaster("right", "left")
  sections.pageTemplate = SILE.scratch.masters["right"]
  state.availableHeight = SILE.toAbsoluteMeasurement(SILE.toMeasurement(61.3, '%ph'))

  local ret = plain.init(self)
  sections.mainTypesetter:init(SILE.getFrame("content"))
  sections.interlinearTypesetter:init(SILE.getFrame("interlinear"))
  sections.ssvLitTypesetter:init(SILE.getFrame("ssvLit"))
  sections.ssvTypesetter:init(SILE.getFrame("ssv"))
  sections.notesTypesetter:init(SILE.getFrame("notes"))
  SILE.typesetter = sections.mainTypesetter
  SILE.settings.set("document.lineskip", SILE.nodefactory.newVglue("15pt"))
  SILE.call("font", {
    -- family = "Scheherazade",
    family = "Awami Nastaliq",
    size = "12pt",
    language = "urd",
    script = "Arab"
  })
  return ret
end

function sections:newPage()
  self:switchPage()
  local r = plain.newPage(self)
  local currentTypesetter = SILE.typesetter
  for frame, typesetter in pairs(typesetters) do
    if typesetter ~= currentTypesetter then
      typesetter:initFrame(SILE.getFrame(frame))
    end
  end
  return r
end

function sections:finish ()
  buildConstraints()
  for frame, typesetter in pairs(typesetters) do
    SILE.typesetter = typesetter
    addRule(typesetter)
    SILE.typesetter:chuck()
  end
  plain.finish(self)
end

return sections