local plain = SILE.require("plain", "classes")
local sections = plain { id = "sections" }
local context = require("context")

SILE.settings.declare({
  name = "sections.sectionskip",
  type = "number or integer",
  default = 2,
  help = "A page percentage to ensure exists between sections"
})

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

function toArabic (number)
  return string.gsub(number, '%d', function (str) return numbers[str] end)
end

function writeFile (file, data)
  file = io.open(file, "w")
  file:write(data)
  file:close()
end

SILE.scratch.sections = {}

sections:loadPackage("masters")
sections:loadPackage("build-interlinear")
sections:loadPackage("rules")
sections:loadPackage("bidi")
sections:defineMaster({
  id = "right",
  firstContentFrame = "content",
  frames = {
    title = {
      right = "right(content)",
      left = "left(content)",
      top = "5%ph",
      height = "0",
      bottom = "top(content)"
    },
    content = {
      right = "94%pw",
      left = "12%pw",
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
      top = "93%ph",
      bottom = "95%ph"
    }
  }
})

sections.main = {
  typesetter = SILE.defaultTypesetter {}
}
sections.interlinear = {
  typesetter = SILE.defaultTypesetter {}
}
sections.ssvLit = {
  typesetter = SILE.defaultTypesetter {}
}
sections.ssv = {
  typesetter = SILE.defaultTypesetter {}
}
sections.notes = {
  typesetter = SILE.defaultTypesetter {}
}
local typesetters = {
  content = sections.main.typesetter,
  interlinear = sections.interlinear.typesetter,
  ssvLit = sections.ssvLit.typesetter,
  ssv = sections.ssv.typesetter,
  notes = sections.notes.typesetter
}

sections.state = {
  currentSection = "content"
}

function resetState ()
  sections.state.heights = {
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
  if SILE.typesetter == sections.notes.typesetter then
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
  for _, height in pairs(sections.state.heights) do
    totalHeight = totalHeight + height
  end
  return totalHeight > SILE.scratch.sections.availableHeight
end

function process (content, reset)
  content = content or {}
  local saveNodes = clone(SILE.typesetter.state.nodes)
  local saveOutputQueue = clone(SILE.typesetter.state.outputQueue)
  local saveHeight = sections.state.heights[sections.currentSection]
  SILE.process(content)
  sections.state.heights[sections.currentSection] = calculateHeight()
  SILE.typesetter.state.nodes = saveNodes
  SILE.typesetter.state.outputQueue = saveOutputQueue
  local saveTypesetter = SILE.typesetter
  if breakNeeded() then
    sections.state.heights[sections.currentSection] = saveHeight
    buildConstraints()
    doSwitch()
    SILE.typesetter = saveTypesetter
    if reset then reset() end
    SILE.process(content)
    saveNodes = clone(SILE.typesetter.state.nodes)
    saveOutputQueue = clone(SILE.typesetter.state.outputQueue)
    sections.state.heights[sections.currentSection] = calculateHeight()
    SILE.typesetter.state.nodes = saveNodes
    SILE.typesetter.state.outputQueue = saveOutputQueue
  else
    if reset then reset() end
    SILE.process(content)
  end
  SILE.typesetter = sections.main.typesetter
end

function setHeight(frame, frameType)
  local height = sections.state.heights[frameType]
  if type(height) ~= "number" then
    height = height.length + height.stretch
  end
  frame:constrain("height", height)
end

function buildConstraints ()
  local contentFrame = sections.main.typesetter.frame
  local interlinearFrame = sections.interlinear.typesetter.frame
  local ssvLitFrame = sections.ssvLit.typesetter.frame
  local ssvFrame = sections.ssv.typesetter.frame
  local notesFrame = sections.notes.typesetter.frame
  local skip = SILE.settings.get("sections.sectionskip")
  sections.state.heights.interlinear = sections.state.heights.interlinear + 10
  contentFrame:relax("bottom")
  interlinearFrame:relax("top")
  setHeight(contentFrame, "content")
  setHeight(interlinearFrame, "interlinear")
  setHeight(ssvLitFrame, "ssvLit")
  setHeight(ssvFrame, "ssv")
  setHeight(notesFrame, "notes")
  contentFrame:constrain("bottom", "top("..interlinearFrame.id..")")
  interlinearFrame:constrain("top", "bottom("..contentFrame.id..")")
  ssvLitFrame:constrain("top", "bottom("..interlinearFrame.id..") + "..skip.."%ph")
  ssvFrame:constrain("top", "bottom("..ssvLitFrame.id..") + "..skip.."%ph")
  notesFrame:constrain("bottom", "top(folio) - "..skip.."%ph")
  fixCursors()
end

function fixCursors ()
  for _, typesetter in pairs(typesetters) do
    local frame = typesetter.frame
    frame.state.cursorY = frame:top()
  end
end

function addRule (typesetter)
  if #typesetter.state.nodes > 0 and typesetter ~= sections.main.typesetter and typesetter ~= sections.notes.typesetter then
    SILE.call("par")
    local width
    if typesetter == sections.interlinear.typesetter then
      typesetter:pushVglue({height = 10})
      -- sections.state.heights.interlinear = sections.state.heights.interlinear + 10
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
      if typesetter == sections.notes.typesetter then
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
  SILE.typesetter = sections.main.typesetter
  SILE.call("eject")
  SILE.call("par")
  SILE.scratch.lastInterlinearBox = nil
  SILE.scratch.lastInterlinearText = nil
end

function renderChapter (section)
  local sections = SILE.scratch.sections
  local chapter = sections[section]
  if chapter then
    SILE.call("chapter:mark", nil, { chapter })
    if not sections.initialPass then
      sections[section] = nil
    end
  end
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

-- Format a verse number
SILE.registerCommand(
  "verse",
  function (options, content)
    SILE.call(
      "font",
      {size = "14pt"},
      function ()
        local n1,n2
        if string.match(options.number, "-") then
          n1, n2 = string.match(options.number, "(%d+)-(%d+)")
          SILE.typesetter:typeset(SU.utf8charfromcodepoint("U+06DD")..toArabic(n1)..SU.utf8charfromcodepoint("U+200F").."-"..
                                  SU.utf8charfromcodepoint("U+06DD")..toArabic(n2)..SU.utf8charfromcodepoint("U+200F").." ")

        else
          SILE.typesetter:typeset(SU.utf8charfromcodepoint("U+06DD")..toArabic(options.number)..SU.utf8charfromcodepoint("U+200F").." ")
        end
      end
    )
    SILE.process(content)
  end
)

SILE.registerCommand("char", function (options, content)
  SILE.call("char-"..options.style, options, content)
end)

SILE.registerCommand("para", function (options, content)
  SILE.settings.temporarily(function ()
    SILE.call("para-"..options.style, options, content)
    SILE.typesetter:boxUpNodes()
  end)
end)

SILE.registerCommand("para-end", function ()
  SILE.call("break")
end)

SILE.registerCommand("chapter", function (options, content)
  if options.number == "1" then
    buildConstraints()
    doSwitch()
  end
  SILE.scratch.sections.notesNumber = 1
  local chapterNumber = toArabic(options.number)..SU.utf8charfromcodepoint("U+200F")
  SILE.scratch.sections.ssvChapter = chapterNumber
  SILE.scratch.sections.ssvLitChapter = chapterNumber
  SILE.process(content)
end)

SILE.registerCommand("verse-section", function (options, content)
  
  SILE.process(content)
end)

function saveState (section)
  local typesetter = sections[section].typesetter
  sections[section].lastState = {
    nodes = #typesetter.state.nodes,
    outputQueue = #typesetter.state.outputQueue
  }
end

function handleProcessedContent (section)
  section = sections[section]
  local lastState = section.lastState
  local typesetter = section.typesetter

  local vboxes = typesetter:boxUpNodes()

  local outputQueue = typesetter.state.outputQueue
  local height = 0
  for _, vbox in ipairs(vboxes) do
    height = height + vbox.height + vbox.depth
  end
  for _, vbox in ipairs(outputQueue) do
    height = height + vbox.height + vbox.depth
  end
  lastState.addedSomethingToLine = lastState.nodes > 0 and #typesetter.state.outputQueue[lastState.outputQueue + 1] > lastState.nodes
  lastState.addedHeight = #typesetter.state.outputQueue
end

SILE.registerCommand("interlinear", function (options, content)
  -- saveState("interlinear")
  -- SILE.typesetter = sections.interlinear.typesetter
  -- SILE.process(content)
  -- handleProcessedContent("interlinear")
end)

function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

SILE.registerCommand("ssv-lit", function (options, content)
  -- SILE.typesetter = sections.ssvLit.typesetter

  -- local nodes = SILE.typesetter.state.nodes
  -- SILE.typesetter:pushState()
  -- SILE.process(content)
  -- local vboxes = SILE.typesetter:boxUpNodes()
  -- for _, vbox in ipairs(vboxes) do
  --   if vbox.nodes then
  --     for _, node in ipairs(vbox.nodes) do table.insert(nodes, node) end
  --   end
  -- end
  -- table.remove(nodes, #nodes)
  -- table.remove(nodes, #nodes)
  -- SILE.typesetter:popState()
  -- vboxes = SILE.defaultTypesetter.boxUpNodes(SILE.typesetter)
  -- nodes = vboxes[#vboxes].nodes
  -- table.remove(nodes, #nodes)
  -- table.remove(nodes, #nodes)

  -- local state = SILE.typesetter.state
  -- state.nodes = nodes
  -- for i=1, #vboxes do
  --   table.insert(state.outputQueue, vboxes[i])
  -- end

  -- if #state.outputQueue > 10 then
  --   print("Switching...")
  --   local toNextPage = {}
  --   for i=#state.outputQueue, 10, -1 do
  --     table.insert(toNextPage, 1, table.remove(state.outputQueue[i]))
  --   end
  --   SILE.typesetter:leaveHmode()
  --   buildConstraints()
  --   doSwitch()
  --   SILE.typesetter = sections.ssvLit.typesetter
  --   state = SILE.typesetter.state
  --   state.outputQueue = toNextPage
  -- end

  -- local height = SILE.pagebuilder.collateVboxes(state.outputQueue).height
  -- table.remove(state.outputQueue, #state.outputQueue)
  -- table.remove(state.outputQueue, #state.outputQueue)
  -- local difference = height - sections.state.heights.ssvLit
  -- sections.state.heights.ssvLit = height
  -- print("Adding "..difference.. " for a total of "..height)
  -- state.previousVbox = state.outputQueue[#state.outputQueue]

  -- SILE.process(content)
  -- local vboxes = SILE.typesetter:boxUpNodes()
  -- local nodes = vboxes[#vboxes].nodes
  -- table.remove(nodes, #nodes)
  -- table.remove(nodes, #nodes)
  -- local state = SILE.typesetter.state
  -- state.nodes = nodes
  -- for i=1, #vboxes do
  --   table.insert(state.outputQueue, vboxes[i])
  -- end
  -- local height = SILE.pagebuilder.collateVboxes(state.outputQueue).height
  -- table.remove(state.outputQueue, #state.outputQueue)
  -- table.remove(state.outputQueue, #state.outputQueue)
  -- local difference = height - sections.state.heights.ssvLit
  -- sections.state.heights.ssvLit = height
  -- print("Adding "..difference.. " for a total of "..height)
  -- state.previousVbox = state.outputQueue[#state.outputQueue]

  -- local nodes = SILE.typesetter.state.nodes
  -- SILE.typesetter:pushState()
  -- SILE.typesetter.state.nodes = nodes
  -- SILE.process(content)
  -- nodes = SILE.typesetter.state.nodes
  -- SILE.typesetter:leaveHmode(1)
  -- local subsidiary = SILE.pagebuilder.collateVboxes(SILE.typesetter.state.outputQueue)
  -- SILE.typesetter:popState()
  -- local difference = subsidiary.height - sections.state.heights.ssvLit
  -- sections.state.heights.ssvLit = subsidiary.height
  -- print("Adding "..difference.. " for a total of "..sections.state.heights.ssvLit)
  -- SILE.typesetter.state.nodes = nodes

  -- ** This can measure the height of the new verse
  -- local unprocessedNodes = std.tree.clone(SILE.typesetter.state.nodes)
  -- SILE.typesetter:pushState()
  -- SILE.typesetter.state.nodes = unprocessedNodes
  -- SILE.process(content)
  -- SILE.typesetter:leaveHmode(1)
  -- local subsidiary = SILE.pagebuilder.collateVboxes(SILE.typesetter.state.outputQueue)
  -- SILE.typesetter:popState()
  -- local difference = subsidiary.height - sections.state.heights.ssvLit
  -- sections.state.heights.ssvLit = subsidiary.height
  -- print("Adding "..difference.. " for a total of "..sections.state.heights.ssvLit)
  -- SILE.process(content)



  -- SILE.process(content)
  -- SILE.typesetter:leaveHmode(1)
  -- local state = SILE.typesetter.state
  -- local outputQueue = state.outputQueue
  -- local nodes = state.nodes
  -- local lastLine = outputQueue[#outputQueue]
  -- state.nodes = lastLine.nodes
  -- table.remove(outputQueue, #outputQueue)
  -- table.remove(state.nodes, #state.nodes)
  -- table.remove(state.nodes, #state.nodes)
  -- print(SILE.typesetter.state)
  -- saveState("ssvLit")
  -- SILE.typesetter = sections.ssvLit.typesetter
  -- SILE.process(content)
  -- handleProcessedContent("ssvLit")
end)

SILE.registerCommand("ssv", function (options, content)

end)

-- SILE.registerCommand("interlinear", function (options, content)
--   local oldT = SILE.typesetter
--   SILE.typesetter = sections.interlinear.typesetter
--   sections.currentSection = "interlinear"
--   local saveBox = SILE.scratch.lastInterlinearBox
--   local saveText = SILE.scratch.lastInterlinearText
--   process(content, function ()
--     SILE.scratch.lastInterlinearBox = saveBox
--     SILE.scratch.lastInterlinearText = saveText
--   end)
--   SILE.typesetter = oldT
--   sections.currentSection = "content"
-- end)

-- SILE.registerCommand("ssv-lit", function (options, content)
--   local oldT = SILE.typesetter
--   SILE.typesetter = sections.ssvLit.typesetter
--   sections.currentSection = "ssvLit"
--   renderChapter("ssvLitChapter")
--   process(content)
--   SILE.typesetter = oldT
--   sections.currentSection = "content"
-- end)

-- SILE.registerCommand("ssv", function (options, content)
--   -- We have to do this one differently, due to its multi-frame nature
--   SILE.typesetter = sections.ssv.typesetter
--   if SILE.scratch.sections.ssvChapter then
--     local firstItem = content[1]
--     if firstItem.tag == "para" and firstItem.attr.style == "s" then
--       SILE.process({ firstItem })
--       table.remove(content, 1)
--     end
--     renderChapter("ssvChapter")
--   end

--   local saveSsvNodes = clone(SILE.typesetter.state.nodes)
--   local saveSsvOutputQueue = clone(SILE.typesetter.state.outputQueue)
--   local saveSsvHeight = sections.state.heights.ssv
--   local saveNotesNodes = clone(sections.notes.typesetter.state.nodes)
--   local saveNotesOutputQueue = clone(sections.notes.typesetter.state.outputQueue)
--   local saveNotesHeight = sections.state.heights.notes
--   SILE.scratch.sections.initialPass = true
--   SILE.process(content)
--   SILE.scratch.sections.initialPass = false
--   sections.state.heights.ssv = calculateHeight()
--   SILE.typesetter = sections.notes.typesetter
--   sections.state.heights.notes = calculateHeight()
--   SILE.typesetter = sections.ssv.typesetter
--   SILE.typesetter.state.nodes = saveSsvNodes
--   SILE.typesetter.state.outputQueue = saveSsvOutputQueue
--   sections.notes.typesetter.state.nodes = saveNotesNodes
--   sections.notes.typesetter.state.outputQueue = saveNotesOutputQueue
--   if breakNeeded() then
--     sections.state.heights.ssv = saveSsvHeight
--     sections.state.heights.notes = saveNotesHeight
--     buildConstraints()
--     doSwitch()
--     SILE.typesetter = sections.ssv.typesetter
--     SILE.process(content)
--     saveSsvNodes = clone(SILE.typesetter.state.nodes)
--     saveSsvOutputQueue = clone(SILE.typesetter.state.outputQueue)
--     saveNotesNodes = clone(sections.notes.typesetter.state.nodes)
--     saveNotesOutputQueue = clone(sections.notes.typesetter.state.outputQueue)
--     sections.state.heights.ssv = calculateHeight()
--     SILE.typesetter = sections.notes.typesetter
--     sections.state.heights.notes = calculateHeight()
--     SILE.typesetter = sections.ssv.typesetter
--     SILE.typesetter.state.nodes = saveSsvNodes
--     SILE.typesetter.state.outputQueue = saveSsvOutputQueue
--     sections.notes.typesetter.state.nodes = saveNotesNodes
--     sections.notes.typesetter.state.outputQueue = saveNotesOutputQueue
--   else
--     SILE.process(content)
--   end
--   SILE.typesetter = sections.main.typesetter
--   sections.currentSection = "content"
-- end)

-- SILE.registerCommand("note", function (options, content)
--   SILE.call("raise", {height = "5pt"}, function ()
--     SILE.Commands["font"]({ size = "1.5ex" }, function()
--       SILE.typesetter:typeset(
--         footnoteMark
--         ..toArabic(tostring(SILE.scratch.sections.notesNumber).." ")
--       )
--     end)
--   end)
--   local oldT = SILE.typesetter
--   SILE.typesetter = sections.notes.typesetter
--   SILE.settings.temporarily(function ()
--     SILE.call("font", {size = "12pt"})
--     SILE.typesetter:typeset(
--       footnoteMark
--       ..toArabic(tostring(SILE.scratch.sections.notesNumber))
--     )
--     SILE.call("font", {size = "9pt"})
--     SILE.call("set", {
--       parameter = "document.lineskip",
--       value = "0.7ex"
--     })
--     SILE.process(content)
--   end)
--   if not SILE.scratch.sections.initialPass then
--     SILE.scratch.sections.notesNumber = SILE.scratch.sections.notesNumber + 1
--   end
--   SILE.typesetter = oldT
-- end)

function sections:init()
  sections:mirrorMaster("right", "left")
  sections.pageTemplate = SILE.scratch.masters[context.side]
  SILE.scratch.counters.folio.value = context.page
  local deadspace = 4 * SILE.settings.get("sections.sectionskip") + 12
  SILE.scratch.sections.availableHeight = SILE.toAbsoluteMeasurement(SILE.toMeasurement(100 - deadspace, '%ph'))
  
  local ret = plain.init(self)
  sections.main.typesetter:init(SILE.getFrame("content"))
  sections.interlinear.typesetter:init(SILE.getFrame("interlinear"))
  sections.ssvLit.typesetter:init(SILE.getFrame("ssvLit"))
  sections.ssv.typesetter:init(SILE.getFrame("ssv"))
  sections.notes.typesetter:init(SILE.getFrame("notes"))
  SILE.typesetter = sections.main.typesetter
  for _, typesetter in pairs(typesetters) do
    SILE.typesetter = typesetter
    SILE.call("bidi-on")
  end
  SILE.typesetter = sections.main.typesetter
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