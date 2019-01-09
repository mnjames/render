local plain = SILE.require("plain", "classes")
local sections = plain { id = "sections" }
local context = require("context")

SILE.settings.declare({
  name = "sections.sectionskip",
  type = "number or integer",
  default = 2,
  help = "A page percentage to ensure exists between sections"
})

SILE.settings.declare({
  name = "sections.interlinearskip",
  type = "Length",
  default = SILE.length.parse("10pt"),
  help = "Bottom margin of the interlinear section"
})

SILE.settings.declare({
  name = "sections.ssvlitskip",
  type = "Length",
  default = SILE.length.parse("10pt"),
  help = "Bottom margin of the SSV Lit section"
})

SILE.settings.declare({
  name = "sections.ssvskip",
  type = "Length",
  default = SILE.length.parse("10pt"),
  help = "Bottom margin of the SSV section"
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

local bidiBoxUpNodes

function toArabic (number)
  return string.gsub(number, '%d', function (str) return numbers[str] end)
end

function writeFile (file, data)
  file = io.open(file, "w")
  file:write(data)
  file:close()
end

SILE.scratch.sections = {
  sectionNumber = 0
}

sections:loadPackage("masters")
sections:loadPackage("build-interlinear")
sections:loadPackage("rules")
sections:loadPackage("bidi")
sections:loadPackage("color")
sections:defineMaster({
  id = "right",
  firstContentFrame = "content",
  frames = {
    title = {
      right = "right(content)",
      left = "left(content)",
      top = "5%ph",
      height = "0",
      bottom = "top(interlinear)"
    },
    content = {
      right = "94%pw",
      left = "12%pw",
      -- height = "20%ph",
      bottom = "100%ph",
      top = "20%ph",
      direction = "RTL"
    },
    interlinear = {
      right = "right(content)",
      left = "left(content)",
      top = "bottom(title)",
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

function createSection ()
  return {
    typesetter = SILE.defaultTypesetter {},
    state = {
      height = 0,
      minimum = 0
    }
  }
end

sections.types = {
  interlinear = createSection(),
  ssvLit = createSection(),
  ssv = createSection(),
  notes = createSection()
}

sections.state = {
  currentSection = "content"
}

function resetState ()
  for _, section in pairs(sections.types) do
    section.lastState = nil
    section.state = {
      height = 0,
      minimum = 0
    }
  end
end

function setHeight(frame, section)
  local height = sections.types[section].state.height

  -- local measuredHeight = 0
  -- local tState = sections.types[section].typesetter.state
  -- for _, vbox in ipairs(tState.outputQueue) do
  --   measuredHeight = measuredHeight + vbox.height + vbox.depth
  -- end
  -- print("Difference is "..(measuredHeight - height).." px")

  if type(height) ~= "number" then
    height = height.length + height.stretch
  end
  frame:constrain("height", height)
end

function buildConstraints ()
  local interlinearFrame = sections.types.interlinear.typesetter.frame
  local ssvLitFrame = sections.types.ssvLit.typesetter.frame
  local ssvFrame = sections.types.ssv.typesetter.frame
  local notesFrame = sections.types.notes.typesetter.frame
  -- local skip = SILE.settings.get("sections.sectionskip")
  sections.types.interlinear.state.height = sections.types.interlinear.state.height + 10
  setHeight(interlinearFrame, "interlinear")
  setHeight(ssvLitFrame, "ssvLit")
  setHeight(ssvFrame, "ssv")
  setHeight(notesFrame, "notes")
  ssvLitFrame:constrain("top", "bottom("..interlinearFrame.id..") + "..SILE.settings.get("sections.interlinearskip"))
  ssvFrame:constrain("top", "bottom("..ssvLitFrame.id..") + "..SILE.settings.get("sections.ssvlitskip"))
  notesFrame:constrain("bottom", "top(folio) - 10px")
  fixCursors()
end

function fixCursors ()
  for _, section in pairs(sections.types) do
    local frame = section.typesetter.frame
    frame.state.cursorY = frame:top()
  end
end

function addRule (typesetter)
  if (#typesetter.state.nodes > 0 or #typesetter.state.outputQueue > 0) and typesetter ~= sections.types.notes.typesetter then
    SILE.call("par")
    local width
    if typesetter == sections.types.interlinear.typesetter then
      typesetter:pushVglue({height = 10})
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
  for _, section in pairs(sections.types) do
    SILE.typesetter = section.typesetter
    SILE.settings.temporarily(function ()
      if SILE.typesetter == sections.types.notes.typesetter then
        SILE.call("set", {
          parameter = "document.lineskip",
          value = "0.7ex"
        })
      end
      -- if SILE.typesetter == sections.types.ssv.typesetter then
      --   local str = "SSV Line: "
      --   for _, box in ipairs(SILE.typesetter.state.outputQueue) do
      --     local type = box:isVglue() and "G" or box:isVbox() and "B" or box:isPenalty() and "P" or "?"
      --     str = str..type
      --   end
      --   print(str)
      -- end
      addRule(section.typesetter)
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

function renderChapter (section, content)
  local sections = SILE.scratch.sections
  local chapter = sections[section.."Chapter"]
  if chapter then
    for index, item in ipairs(content) do
      if type(item) == "string" then
        table.insert(content, index, {
          chapter,
          attr = {},
          tag = "chapter:mark"
        })
        break
      end
    end
    -- SILE.call("chapter:mark", nil, { chapter })
    if not sections.initialPass then
      sections[section.."Chapter"] = nil
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
          SILE.typesetter:typeset(
            SU.utf8charfromcodepoint("U+06DD")..toArabic(n1)..SU.utf8charfromcodepoint("U+200F").."-"..
            SU.utf8charfromcodepoint("U+06DD")..toArabic(n2)..SU.utf8charfromcodepoint("U+200F").." "
          )
        else
          SILE.typesetter:typeset(SU.utf8charfromcodepoint("U+06DD")..toArabic(options.number)..SU.utf8charfromcodepoint("U+200F").." ")
        end
      end
    )
    SILE.process(content)
  end
)

function addBidifiedNodesToList ()
  local nodes = SILE.typesetter.state.masterNodes
  if not nodes then return end
  local vboxes = bidiBoxUpNodes(SILE.typesetter)
  for _, vbox in ipairs(vboxes) do
    if vbox.nodes then
      for _, node in ipairs(vbox.nodes) do table.insert(nodes, node) end
    end
  end
  table.remove(nodes)
  table.remove(nodes)
  return nodes
end

function bidiBreak ()
  if SILE.typesetter.state.masterNodes then
    addBidifiedNodesToList()
    SILE.typesetter.state.nodes = SILE.typesetter.state.masterNodes
    SILE.typesetter:leaveHmode(1)
    SILE.typesetter.state.masterNodes = {}
  else
    SILE.typesetter:leaveHmode(1)
  end
end

function processWithBidi (content)
  local nodes = SILE.typesetter.state.nodes
  if #nodes > 0 then
    SILE.typesetter:pushGlue"1spc"
  end
  SILE.typesetter:pushState()
  SILE.typesetter.state.masterNodes = nodes
  SILE.process(content)
  local queue = SILE.typesetter.state.outputQueue
  local previousVbox = SILE.typesetter.state.previousVbox
  addBidifiedNodesToList()
  nodes = SILE.typesetter.state.masterNodes
  SILE.typesetter:popState()
  if #queue > 0 then
    for _, box in ipairs(queue) do
      table.insert(SILE.typesetter.state.outputQueue, box)
    end
    SILE.typesetter.state.previousVbox = previousVbox
  end
  SILE.typesetter.state.nodes = nodes
end

SILE.registerCommand("char", function (options, content)
  SILE.call("char-"..options.style, options, content)
end)

SILE.registerCommand("para", function (options, content)
  SILE.call("bidi-on")
  SILE.settings.temporarily(function ()
    SILE.call("para-"..options.style, options, content)
    bidiBreak()
  end)
  SILE.call("bidi-off")
end)

SILE.registerCommand("para-end", function ()
  bidiBreak()
end)

SILE.registerCommand("chapter", function (options, content)
  if options.number == "1" then
    doSwitch()
  end
  SILE.scratch.sections.notesNumber = 1
  local chapterNumber = toArabic(options.number)..SU.utf8charfromcodepoint("U+200F").." "
  SILE.scratch.sections.ssvChapter = chapterNumber
  SILE.scratch.sections.ssvLitChapter = chapterNumber
  SILE.process(content)
end)

function createCarryOver (overFill)
  print("Overfull by "..overFill)
  local maxVerse = 1000000
  local carryOver = {
    {
      name = "ssv",
      toNextPage = {},
      numLinesToRemove = 0
    },
    {
      name = "ssvLit",
      toNextPage = {},
      numLinesToRemove = 0
    },
    {
      name = "interlinear",
      toNextPage = {},
      numLinesToRemove = 0
    }
  }

  print("Carrying over unfinished lines")
  for _, item in ipairs(carryOver) do
    local tState = sections.types[item.name].typesetter.state
    local state = sections.types[item.name].state
    local chunks = state.chunks
    if #tState.nodes > 0 then
      local chunk = chunks[#chunks]
      print("Automatically removing unfinished line")
      item.numLinesToRemove = item.numLinesToRemove + 1
      print("Subtracting", chunk.height)
      overFill = overFill - chunk.height
      state.height = state.height - chunk.height
      if #chunk.verseContribution > 0 then
        maxVerse = math.min(chunk.verseContribution[1] - 1, maxVerse)
      end
    end
  end

  local stillOverful = overFill > 0
  while stillOverful do
    local stillRemovingContent = false
    for _, item in ipairs(carryOver) do
      local state = sections.types[item.name].state
      local chunks = state.chunks
      local chunkIndex = #chunks - item.numLinesToRemove
      -- if (chunks.firstChunkIsRemovable and chunkIndex > 0) or chunkIndex > 1 then
      if chunkIndex > 0 then
        local chunk = chunks[chunkIndex]
        stillRemovingContent = true
        item.numLinesToRemove = item.numLinesToRemove + 1
        print("Subtracting", chunk.height)
        overFill = overFill - chunk.height
        state.height = state.height - chunk.height
        if #chunk.verseContribution > 0 then
          maxVerse = math.min(chunk.verseContribution[1] - 1, maxVerse)
        end
        if overFill <= 0 then
          stillOverful = false
          break
        end
        print("Still "..overFill.." to go")
      end
    end
    if not stillRemovingContent then
      print("No more content to remove, aborting!")
      break
    end
  end
  
  for _, item in ipairs(carryOver) do
    local tState = sections.types[item.name].typesetter.state
    for lineIndex=1, item.numLinesToRemove do
      if lineIndex == 1 and #tState.nodes > 0 then
        item.nodeCarryOver = tState.nodes
        tState.nodes = {}
      else
        local queue = tState.outputQueue
        repeat
          table.insert(item.toNextPage, 1, table.remove(queue))
        until queue[#queue]:isVbox()
      end
    end
    local sectionMaxVerse
    for i=#tState.outputQueue, 1, -1 do
      local vbox = tState.outputQueue[i]
      if vbox.verseContribution and #vbox.verseContribution > 0 then
        sectionMaxVerse = vbox.verseContribution[#vbox.verseContribution]
        break
      end
    end
    if sectionMaxVerse > maxVerse then
      print(item.name.." begins verse "..sectionMaxVerse.." but is only allowed to begin "..maxVerse)
    end
  end

  return carryOver
end

SILE.registerCommand("verse-section", function (options, content)
  for _, section in pairs(sections.types) do
    local tState = section.typesetter.state
    section.firstNewBoxIndex = #tState.outputQueue + 1
    section.lastNodeLength = #tState.nodes
  end

  SILE.scratch.sections.sectionNumber = SILE.scratch.sections.sectionNumber + 1

  SILE.process(content)

  local minimum = 0
  local total = 0
  for _, section in pairs(sections.types) do
    total = total + section.state.height
    minimum = minimum + section.state.minimum
  end

  local overFill = total - SILE.scratch.sections.availableHeight
  if overFill > 0 then
    if minimum > SILE.scratch.sections.availableHeight then
      print("Can't even fit minimum!")
    end
    local carryOver = createCarryOver(overFill)

    -- for sectionName, section in pairs(sections.types) do
    --   print("Verse beginnings for "..sectionName)
    --   for _, line in ipairs(section.typesetter.state.outputQueue) do
    --     if line:isVbox() then
    --       print(line.verseContribution)
    --     end
    --   end
    -- end
    
    buildConstraints()
    doSwitch()

    for _, item in ipairs(carryOver) do
      if item.nodeCarryOver then
        local section = sections.types[item.name]
        local tState = section.typesetter.state
        local sState = section.state
        tState.nodes = item.nodeCarryOver
        for _, box in ipairs(item.toNextPage) do
          table.insert(tState.outputQueue, box)
          sState.height = sState.height + box.height + box.depth
        end
      end
    end
  end
end)

function findNextVBox (list, index)
  for i=index, #list do
    if list[i]:isVbox() then return list[i], i end
  end
end

function measureContribution (sectionName)
  local section = sections.types[sectionName]
  local firstNewBoxIndex = section.firstNewBoxIndex
  local lastNodeLength = section.lastNodeLength
  local isHardBreak = #SILE.typesetter.state.nodes == 0
  SILE.typesetter:leaveHmode(1)
  local tState = SILE.typesetter.state
  if #tState.outputQueue == 0 then
    section.lastState = section.state
    section.state = {
      height = section.lastState.height,
      difference = 0,
      minimum = section.lastState.height,
      chunks = {}
    }
    return
  end

  local firstVbox, intermediaryIndex = findNextVBox(tState.outputQueue, firstNewBoxIndex)
  local verseStartedOnNewLine = lastNodeLength == 0 or lastNodeLength >= #firstVbox.nodes - 3
  
  local minimum = section.state.height
  if verseStartedOnNewLine then
    local box
    repeat
      box = tState.outputQueue[firstNewBoxIndex]
      firstNewBoxIndex = firstNewBoxIndex + 1
      minimum = minimum + box.height + box.depth
    until box:isVbox()
  end

  -- local height = SILE.pagebuilder.collateVboxes(tState.outputQueue).height

  local height = 0
  local chunkHeight = 0
  local chunks = {
    -- firstChunkIsRemovable = not verseStartedOnNewLine
  }
  -- local firstContributionIndex = intermediaryIndex
  -- if not verseStartedOnNewLine then
  --   firstContributionIndex = firstContributionIndex + 1
  -- end
  for index, vbox in ipairs(tState.outputQueue) do
    chunkHeight = chunkHeight + vbox.height + vbox.depth
    if vbox:isVbox() then
      if not vbox.verseContribution then
        local verseContribution = {}
        for _, node in ipairs(vbox.nodes) do
          if node.beginSection then
            table.insert(verseContribution, node.beginSection)
          end
        end
        vbox.verseContribution = verseContribution
      end

      height = height + chunkHeight
      -- if index >= firstContributionIndex then
      table.insert(chunks, {
        height = chunkHeight,
        verseContribution = vbox.verseContribution
      })
      -- end
      chunkHeight = 0
    end
  end
  -- print(sectionName, chunks)

  if not isHardBreak then
    local nodes = tState.outputQueue[#tState.outputQueue].nodes
    table.remove(nodes)
    table.remove(nodes)

    tState.nodes = nodes

    table.remove(tState.outputQueue)
    while #tState.outputQueue > 0 and not tState.outputQueue[#tState.outputQueue]:isVbox() do
      table.remove(tState.outputQueue)
    end
  end

  local difference = height - section.state.height
  section.lastState = section.state
  section.state = {
    height = height,
    difference = difference,
    minimum = minimum,
    chunks = chunks
  }
  -- if sectionName == "ssvLit" then
  --   print("Adding "..difference.." for a total of "..height)
  --   if minimum > 0 then print(section.state) end
  -- end
  -- tState.previousVbox = tState.outputQueue[#tState.outputQueue]
end

function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

SILE.registerCommand("interlinear", function (options, content)
  SILE.typesetter = sections.types.interlinear.typesetter
  SILE.typesetter:pushHbox({
    beginSection = SILE.scratch.sections.sectionNumber,
    outputYourself = function () end
  })
  SILE.process(content)
  measureContribution("interlinear")
end)

SILE.registerCommand("ssv-lit", function (options, content)
  SILE.typesetter = sections.types.ssvLit.typesetter
  renderChapter("ssvLit", content)
  SILE.typesetter:pushHbox({
    beginSection = SILE.scratch.sections.sectionNumber,
    outputYourself = function () end
  })
  processWithBidi(content)  
  measureContribution("ssvLit")
end)

SILE.registerCommand("ssv", function (options, content)
  SILE.typesetter = sections.types.ssv.typesetter
  renderChapter("ssv", content)
  SILE.typesetter:pushHbox({
    beginSection = SILE.scratch.sections.sectionNumber,
    outputYourself = function () end
  })
  processWithBidi(content)
  measureContribution("ssv")
end)

SILE.registerCommand("note", function (options, content)

end)

function sections:init()
  sections:mirrorMaster("right", "left")
  sections.pageTemplate = SILE.scratch.masters[context.side]
  SILE.scratch.counters.folio.value = context.page
  local deadspace = 4 * SILE.settings.get("sections.sectionskip") + 12
  local deadspace = 10
    + SILE.settings.get("sections.interlinearskip")
    + SILE.settings.get("sections.ssvlitskip")
    + SILE.settings.get("sections.ssvskip")
  print("Page is "..SILE.toAbsoluteMeasurement(SILE.toMeasurement(100, '%ph')))
  SILE.scratch.sections.availableHeight = SILE.toAbsoluteMeasurement(SILE.toMeasurement(100 - 12, '%ph')) - deadspace - 30
  print("We have "..SILE.scratch.sections.availableHeight.." available")
  
  local ret = plain.init(self)

  SILE.typesetter:registerPageEndHook(function ()
    SILE.outputter:debugFrame(SILE.getFrame("interlinear"))
    SILE.outputter:debugFrame(SILE.getFrame("ssvLit"))
    SILE.outputter:debugFrame(SILE.getFrame("ssv"))
    SILE.outputter:debugFrame(SILE.getFrame("notes"))
  end)

  sections.mainTypesetter = SILE.typesetter
  sections.mainTypesetter:init(SILE.getFrame("content"))
  sections.types.interlinear.typesetter:init(SILE.getFrame("interlinear"))
  sections.types.ssvLit.typesetter:init(SILE.getFrame("ssvLit"))
  sections.types.ssv.typesetter:init(SILE.getFrame("ssv"))
  sections.types.notes.typesetter:init(SILE.getFrame("notes"))
  SILE.call("bidi-on")
  bidiBoxUpNodes = SILE.typesetter.boxUpNodes
  return ret
end

function sections:newPage()
  self:switchPage()
  local r = plain.newPage(self)
  local currentTypesetter = SILE.typesetter
  for frame, section in pairs(sections.types) do
    if section.typesetter ~= currentTypesetter then
      section.typesetter:initFrame(SILE.getFrame(frame))
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