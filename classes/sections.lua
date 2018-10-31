local plain = SILE.require("plain", "classes")
local sections = plain { id = "sections" }
local context = require("context")

SILE.require("packages/raiselower")

local numbers = {}
numbers["0"] = "۰"
numbers["1"] = "۱"
numbers["2"] = "۲"
numbers["3"] = "۳"
numbers["4"] = "۴"
numbers["5"] = "۵"
numbers["6"] = "۶"
numbers["7"] = "۷"
numbers["8"] = "۸"
numbers["9"] = "۹"

local footnoteMark = SU.utf8charfromcodepoint('U+0602')

SILE.languageSupport.languages.urd = {
  counter = function (options)
    print(options)
  end
}

function toArabic (number)
  return string.gsub(number, '%d', function (str) return numbers[str] end)
end

function writeFile (file, data)
  file = io.open(file, "w")
  file:write(data)
  file:close()
end

SILE.scratch.sections = {}

SILE.settings.set("document.parindent", SILE.nodefactory.newGlue("0pt"))
SILE.settings.set("typesetter.parseppattern", -1)

sections:loadPackage("masters")
sections:loadPackage("build-interlinear")
-- sections:loadPackage("linespacing")
sections:loadPackage("rules")
sections:loadPackage("bidi")
-- sections:loadPackage("unichar")
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
  fr = {
    weight = 800
  },
  zheb = {
    family = "Times New Roman"
  },
  zgrk = {
    family = "SBL Greek"
  },
  zarab = {
    family = "Scheherazade",
	size = "14pt"
  },
  fq = {
	size = "0.1pt"
  }
}

local paraStyles = {
  mt = function ()
    SILE.call("skip", {
      height = "8pt"
    })
    SILE.call("centering")
    SILE.call("font", {
      size = "20pt"
    })
  end,
  mt2 = function ()
    SILE.call("skip", {
      height = "4pt"
    })
    SILE.call("centering")
    SILE.call("font", {
      size = "16pt"
    })
  end,
  qc = function ()
    SILE.call("skip", {
      height = "2pt"
    })
    SILE.call("centering")
    SILE.call("font", {
	  family = "Scheherazade",
      size = "16pt"
    })
  end,
  s = function ()
    SILE.call("centering")
    SILE.call("font", {
      weight = 800
    })
  end,
  toc1 = function ()
    SILE.call("centering")
    SILE.call("font", {
      size = "10pt"
    })
  end,
  toc2 = function ()
    SILE.call("centering")
    SILE.call("font", {
      size = "10pt"
    })
  end
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
  local vboxes
  if SILE.typesetter == sections.notesTypesetter then
    SILE.settings.temporarily(function ()
      SILE.call("set", {
        parameter = "document.lineskip",
        value = "0.7ex"
      })
      vboxes = SILE.typesetter:boxUpNodes()
    end)
  else
    vboxes = SILE.typesetter:boxUpNodes()
  end
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

function process (content, reset)
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
    if reset then reset() end
    SILE.process(content)
    saveNodes = clone(SILE.typesetter.state.nodes)
    saveOutputQueue = clone(SILE.typesetter.state.outputQueue)
    state.heights[state.section] = calculateHeight()
    SILE.typesetter.state.nodes = saveNodes
    SILE.typesetter.state.outputQueue = saveOutputQueue
  else
    if reset then reset() end
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
  state.heights.interlinear = state.heights.interlinear + 10
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
  if #typesetter.state.nodes > 0 and typesetter ~= sections.mainTypesetter and typesetter ~= sections.notesTypesetter then
    SILE.call("par")
    local width
    if typesetter == sections.interlinearTypesetter then
      typesetter:pushVglue({height = 10})
      -- state.heights.interlinear = state.heights.interlinear + 10
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

function finishPage()
  for frame, typesetter in pairs(typesetters) do
    SILE.typesetter = typesetter
    SILE.settings.temporarily(function ()
      if typesetter == sections.notesTypesetter then
        SILE.call("set", {
          parameter = "document.lineskip",
          value = "0.7ex"
        })
      end
      addRule(typesetter)
      SILE.typesetter:chuck()
      SILE.typesetter.frame:leave()
    end)
  end
end

function doSwitch()
  resetState()
  finishPage()
  SILE.typesetter = sections.mainTypesetter
  SILE.call("eject")
  SILE.call("par")
  SILE.scratch.lastInterlinearBox = nil
  SILE.scratch.lastInterlinearText = nil
end

sections:loadPackage("twoside", { oddPageMaster = "right", evenPageMaster = "left" })

SILE.registerCommand("foliostyle", function (options, content)
  SILE.call("font", {
    family = "Awami Nastaliq",
    size = "12pt",
    language = "urd",
    script = "Arab"
  })
  content[1] = toArabic(content[1])
  SILE.call("center", {}, content)
end)

SILE.registerCommand("centering", function ()
  SILE.settings.set("document.lskip", SILE.nodefactory.hfillGlue)
  SILE.settings.set("document.rskip", SILE.nodefactory.hfillGlue)
  SILE.settings.set("typesetter.parfillskip", SILE.nodefactory.zeroGlue)
  SILE.settings.set("document.parindent", SILE.nodefactory.zeroGlue)
  local space = SILE.length.parse("1spc")
  space.stretch = 0
  space.shrink = 0
  SILE.settings.set("document.spaceskip", space)
end)

SILE.registerCommand("verse-section", function (options, content)
  SILE.process(content)
end)

SILE.registerCommand("verse", function (options, content)
  -- SILE.scratch.twoverse.verse = options.number
  -- SILE.typesetter:typeset(options.number.." ")
  SILE.typesetter:typeset(SU.utf8charfromcodepoint("U+06DD")..toArabic(options.number).." ")
  SILE.process(content)
end)

SILE.registerCommand("book", function (options, content)
  
end)

SILE.registerCommand("char", function (options, content)
  SILE.call("font", charStyles[options.style] or {}, function ()
    if options.style == "fr" and not options.morphed then
      options.morphed = true
      content[1] = footnoteMark..toArabic(string.gsub(content[1], '.+:', ''))
    end
    SILE.process(content)
  end)
end)

SILE.registerCommand("para", function (options, content)
  SILE.settings.temporarily(function ()
    local fn = paraStyles[options.style]
    if fn then fn() end
    SILE.process(content)
    SILE.typesetter:leaveHmode()
  end)
end)

SILE.registerCommand("para-start", function (options, content)
  
end)

SILE.registerCommand("para-end", function (options, content)
  SILE.typesetter:leaveHmode()
  -- SILE.settings.popState()
  -- process()
end)

SILE.registerCommand("chapter", function (options, content)
  if options.number == "1" then
    buildConstraints()
    doSwitch()
  end
  SILE.typesetter = sections.mainTypesetter
  state.section = "content"
  SILE.scratch.sections.notesNumber = 1
  process({
    toArabic(options.number),
    {
      attr = {
        height = "4pt"
      },
      tag = "skip"
    }
  })
  -- SILE.typesetter:typeset(options.number)
  SILE.typesetter:leaveHmode()
  SILE.process(content)
end)

SILE.registerCommand("interlinear", function (options, content)
  local oldT = SILE.typesetter
  SILE.typesetter = sections.interlinearTypesetter
  state.section = "interlinear"
  local saveBox = SILE.scratch.lastInterlinearBox
  local saveText = SILE.scratch.lastInterlinearText
  process(content, function ()
    SILE.scratch.lastInterlinearBox = saveBox
    SILE.scratch.lastInterlinearText = saveText
  end)
  SILE.typesetter = oldT
  state.section = "content"
end)

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
  SILE.scratch.sections.initialPass = true
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
    saveSsvNodes = clone(SILE.typesetter.state.nodes)
    saveSsvOutputQueue = clone(SILE.typesetter.state.outputQueue)
    saveNotesNodes = clone(sections.notesTypesetter.state.nodes)
    saveNotesOutputQueue = clone(sections.notesTypesetter.state.outputQueue)
    state.heights.ssv = calculateHeight()
    SILE.typesetter = sections.notesTypesetter
    state.heights.notes = calculateHeight()
    SILE.typesetter = sections.ssvTypesetter
    SILE.typesetter.state.nodes = saveSsvNodes
    SILE.typesetter.state.outputQueue = saveSsvOutputQueue
    sections.notesTypesetter.state.nodes = saveNotesNodes
    sections.notesTypesetter.state.outputQueue = saveNotesOutputQueue
  else
    SILE.process(content)
  end
  SILE.typesetter = sections.mainTypesetter
  state.section = "content"
end)

SILE.registerCommand("note", function (options, content)
  SILE.Commands["raise"]({height = "0.8ex"}, function()
    SILE.Commands["font"]({ size = "1.5ex" }, function()
      SILE.typesetter:typeset(
        footnoteMark
        ..toArabic(tostring(SILE.scratch.sections.notesNumber))
      )
    end)
  end)
  local oldT = SILE.typesetter
  SILE.typesetter = sections.notesTypesetter
  SILE.settings.temporarily(function ()
    SILE.call("font", {size = "9pt"})
    SILE.call("set", {
      parameter = "document.lineskip",
      value = "0.7ex"
    })
    SILE.process(content)
  end)
  if not SILE.scratch.sections.initialPass then
    SILE.scratch.sections.notesNumber = SILE.scratch.sections.notesNumber + 1
  end
  SILE.typesetter = oldT
end)

function sections:init()
  SILE.settings.set("document.language", "urd")
  sections:mirrorMaster("right", "left")
  sections.pageTemplate = SILE.scratch.masters[context.side]
  SILE.scratch.counters.folio.value = context.page
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
    size = "11pt",
    language = "urd",
    script = "Arab",
    features = "+shrt=3"
    -- direction = "RTL"
  })
  for _, typesetter in pairs(typesetters) do
    SILE.typesetter = typesetter
    SILE.call("bidi-on")
  end
  SILE.typesetter = sections.mainTypesetter
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
  finishPage()
  local side = sections.pageTemplate == SILE.scratch.masters.right and "left" or "right"
  local page = SILE.scratch.counters.folio.value + 1
  writeFile("context.lua", "return {side=\""..side.."\",page="..page.."}")
  plain.finish(self)
end

return sections