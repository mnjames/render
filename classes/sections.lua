local plain = SILE.require("plain", "classes")
local sections = plain { id = "sections" }
local context = require("context")

SILE.settings.declare({
  name = "sections.borderbuffer",
  type = "number or integer",
  default = 8,
  help = "The buffer between the Interlinear and SSV Lit text and the border which surrounds it"
})

SILE.settings.declare({
  name = "sections.interlinearseparator",
  type = "string",
  default = "green",
  help = "The color of the line separating the Interlinear and SSV Lit sections"
})

SILE.settings.declare({
  name = "sections.notesseparator",
  type = "string",
  default = "green",
  help = "The color of the line separating the SSV and Notes sections"
})

SILE.settings.declare({
  name = "sections.interlinearskip",
  type = "Length",
  default = SILE.length.parse("15pt"),
  help = "Bottom margin of the interlinear section"
})

SILE.settings.declare({
  name = "sections.ssvlitskip",
  type = "Length",
  default = SILE.length.parse("20pt"),
  help = "Bottom margin of the SSV Lit section"
})

SILE.settings.declare({
  name = "sections.ssvskip",
  type = "Length",
  default = SILE.length.parse("15pt"),
  help = "Bottom margin of the SSV section"
})

SILE.settings.declare({
  name = "sections.notesskip",
  type = "string",
  default = "10pt",
  help = "Bottom margin of the Notes section"
})

SILE.require("packages/raiselower")

SILE.scratch.headers = {}

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
    runningHead = {
      right = "right(content)",
      left = "left(content)",
      bottom = "top(interlinear) - 8px",
      height = "14px",
      direction = "RTL"
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

-- local emptyFunction = function (self, typesetter, line)
--   SILE.outputter:pushColor(SILE.colorparser("orange"))
--   SILE.outputter.rule(typesetter.frame.state.cursorX, typesetter.frame.state.cursorY-12, 1, 12)
--   SILE.outputter:popColor()
-- end
local emptyFunction = function () end

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

function allTypesetters (fun)
  local currentTypesetter = SILE.typesetter
  for name, section in pairs(sections.types) do
    SILE.typesetter = section.typesetter
    fun(section.typesetter, section, name)
  end
  SILE.typesetter = currentTypesetter
end

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

-- function setHeight(frame, section)
--   -- local height = sections.types[section].height
--   -- local measuredHeight = 0
--   -- local tState = sections.types[section].typesetter.state
--   -- for _, vbox in ipairs(tState.outputQueue) do
--   --   measuredHeight = measuredHeight + vbox.height + vbox.depth
--   -- end
--   -- print("Difference is "..(measuredHeight - height).." px")

--   -- if type(height) ~= "number" then
--   --   height = height.length + height.stretch
--   -- end
--   frame:constrain("height", measureHeight(section.typesetter.state.outputQueue))
-- end

function buildConstraints ()
  local interlinearTypesetter = sections.types.interlinear.typesetter
  local ssvLitTypesetter = sections.types.ssvLit.typesetter
  local ssvTypesetter = sections.types.ssv.typesetter
  local notesTypesetter = sections.types.notes.typesetter
  local interlinearFrame = interlinearTypesetter.frame
  local ssvLitFrame = ssvLitTypesetter.frame
  local ssvFrame = ssvTypesetter.frame
  local notesFrame = notesTypesetter.frame
  -- local skip = SILE.settings.get("sections.sectionskip")
  -- sections.types.interlinear.state.height = sections.types.interlinear.state.height + 10
  -- setHeight(interlinearFrame, "interlinear")
  -- setHeight(ssvLitFrame, "ssvLit")
  -- setHeight(ssvFrame, "ssv")
  -- setHeight(notesFrame, "notes")
  allTypesetters(function (typesetter, section, name)
    local height = measureHeight(typesetter.state.outputQueue)
    if height > 0 and name == "interlinear" then
      height = height + SILE.toPoints(SILE.settings.get("interlinear.height"))
    end
    typesetter.frame:constrain("height", height)
  end)
  ssvLitFrame:constrain("top", "bottom("..interlinearFrame.id..") + "..(interlinearFrame:height() > 0 and SILE.settings.get("sections.interlinearskip")) or "0")
  ssvFrame:constrain("top", "bottom("..ssvLitFrame.id..") + "..(ssvLitFrame:height() > 0 and SILE.settings.get("sections.ssvlitskip")) or "0")
  notesFrame:constrain("bottom", "top(folio) - "..SILE.settings.get("sections.notesskip"))
  local buffer = SILE.settings.get("sections.borderbuffer")
  local borderWidth = 5
  local halfWidth = math.ceil(borderWidth / 2)
  if
    #interlinearTypesetter.state.outputQueue > 0
    and #ssvLitTypesetter.state.outputQueue > 0
  then
    SILE.outputter:pushColor(SILE.colorparser(SILE.settings.get("sections.interlinearseparator")))
    SILE.outputter.rule(interlinearFrame:left() - buffer, (ssvLitFrame:top() + interlinearFrame:bottom()) / 2, interlinearFrame:width() + 2*buffer, 1)
    SILE.outputter:popColor()
  end
  if
    #interlinearTypesetter.state.outputQueue > 0
    or #ssvLitTypesetter.state.outputQueue > 0
  then
    local extraWidth = buffer + borderWidth
    SILE.outputter:pushColor(SILE.colorparser(SILE.settings.get("sections.interlinearseparator")))
    outputFrame(
      interlinearFrame:left() - extraWidth,
      interlinearFrame:top() - borderWidth,
      interlinearFrame:right() + extraWidth,
      ssvLitFrame:bottom() + borderWidth + 5,
      borderWidth
    )
    SILE.outputter:popColor()

    extraWidth = buffer + halfWidth
    SILE.outputter:pushColor(SILE.colorparser("white"))
    outputFrame(
      interlinearFrame:left() - extraWidth,
      interlinearFrame:top() - halfWidth,
      interlinearFrame:right() + extraWidth,
      ssvLitFrame:bottom() + halfWidth + 5,
      1
    )
    SILE.outputter:popColor()
  end
  if #notesTypesetter.state.outputQueue > 0 then
    SILE.outputter:pushColor(SILE.colorparser(SILE.settings.get("sections.notesseparator")))
    local location = notesFrame:top() - SILE.settings.get("sections.ssvskip").length / 2
    SILE.outputter.rule(ssvFrame:left(), location, ssvFrame:width(), 1)
    SILE.outputter:popColor()
  end
  fixCursors()
end

function outputFrame (left, top, right, bottom, width)
  SILE.outputter.rule(left, top, right - left, width)
  SILE.outputter.rule(left, bottom - width, right - left, width)
  SILE.outputter.rule(left, top, width, bottom - top)
  SILE.outputter.rule(right - width, top, width, bottom - top)
end

function fixCursors ()
  for sectionName, section in pairs(sections.types) do
    local typesetter = section.typesetter
    local frame = typesetter.frame
    frame.state.cursorY = frame:top()
  end
end

-- function addRule (typesetter)
--   if (#typesetter.state.nodes > 0 or #typesetter.state.outputQueue > 0) and typesetter ~= sections.types.notes.typesetter then
--     SILE.call("par")
--     local width
--     if typesetter == sections.types.interlinear.typesetter then
--       typesetter:pushVglue({height = 10})
--       width = "100%fw"
--     else
--       width = "-100%fw"
--     end
--     SILE.call("hrule", {
--       height = "1pt",
--       width = width
--     })
--   end
-- end

function finishPage()
  if SILE.scratch.sections.chapterBegun then
    SILE.typesetter = sections.mainTypesetter
    SILE.typesetNaturally(SILE.getFrame("runningHead"), function ()
      local side = sections.pageTemplate == SILE.scratch.masters.right and "right" or "left"
      SILE.call("bidi-on")
      SILE.call("noindent")
      SILE.settings.set("current.parindent", SILE.nodefactory.zeroGlue)
      SILE.settings.set("document.lskip", SILE.nodefactory.zeroGlue)
      SILE.settings.set("document.rskip", SILE.nodefactory.zeroGlue)
      SILE.call("font", { size = 7 })
      local options = {}
      options[side == "right" and "left" or "right"] = true
      SILE.call("ragged", options, SILE.scratch.headers[side])
    end)
  end
  for _, section in pairs(sections.types) do
    SILE.typesetter = section.typesetter
    SILE.settings.temporarily(function ()
      if SILE.typesetter == sections.types.notes.typesetter then
        SILE.call("set", {
          parameter = "document.lineskip",
          value = "0.7ex"
        })
      elseif SILE.typesetter == sections.types.interlinear.typesetter then
        SILE.call("set", {
          parameter = "document.lineskip",
          value = SILE.settings.get("interlinear.height")
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
      -- addRule(section.typesetter)
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
  -- SILE.scratch.lastInterlinearBox = nil
  -- SILE.scratch.lastInterlinearText = nil
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
    -- if not sections.initialPass then
    sections[section.."Chapter"] = nil
    -- end
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
    -- SILE.typesetter:pushPenalty({
    --   penalty = 3000
    -- })
    SILE.call(
      "font",
      {size = "14pt"},
      function ()
        if string.match(options.number, "-") then
          local gen = string.gmatch(options.number, "(%d+)")
          SILE.typesetter:typeset(
            SU.utf8charfromcodepoint("U+06DD")..toArabic(gen())..SU.utf8charfromcodepoint("U+200F").."-"..
            SU.utf8charfromcodepoint("U+06DD")..toArabic(gen())..SU.utf8charfromcodepoint("U+200F").." "
          )
        else
          SILE.typesetter:typeset(SU.utf8charfromcodepoint("U+06DD")..toArabic(options.number)..SU.utf8charfromcodepoint("U+200F").." ")
        end
      end
    )
    SILE.process(content)
  end
)

-- function addBidifiedNodesToList ()
--   local nodes = SILE.typesetter.state.masterNodes
--   if not nodes or #SILE.typesetter.state.nodes == 0 then return end
--   local vboxes = bidiBoxUpNodes(SILE.typesetter)
--   for _, vbox in ipairs(vboxes) do
--     if vbox.nodes then
--       for _, node in ipairs(vbox.nodes) do table.insert(nodes, node) end
--     end
--   end
--   table.remove(nodes)
--   table.remove(nodes)
--   return nodes
-- end

-- function bidiBreak ()
--   if SILE.typesetter.state.masterNodes then
--     addBidifiedNodesToList()
--     SILE.typesetter.state.nodes = SILE.typesetter.state.masterNodes
--     SILE.typesetter:leaveHmode(1)
--     SILE.typesetter.state.masterNodes = {}
--   else
--     SILE.typesetter:leaveHmode(1)
--   end
-- end

-- function processWithBidi (content)
--   local nodes = SILE.typesetter.state.nodes
--   if #nodes > 0 then
--     SILE.typesetter:pushGlue"1spc"
--   end
--   SILE.typesetter:pushState()
--   SILE.typesetter.state.masterNodes = nodes
--   SILE.process(content)
--   local queue = SILE.typesetter.state.outputQueue
--   local previousVbox = SILE.typesetter.state.previousVbox
--   addBidifiedNodesToList()
--   nodes = SILE.typesetter.state.masterNodes
--   SILE.typesetter:popState()
--   if #queue > 0 then
--     for _, box in ipairs(queue) do
--       table.insert(SILE.typesetter.state.outputQueue, box)
--     end
--     SILE.typesetter.state.previousVbox = previousVbox
--   end
--   SILE.typesetter.state.nodes = nodes
-- end

SILE.registerCommand("char", function (options, content)
  SILE.call("char-"..options.style, options, content)
end)

SILE.registerCommand("para", function (options, content)
  -- SILE.call("bidi-on")
  SILE.settings.temporarily(function ()
    SILE.call("para-"..options.style, options, content)
  end)
  if options.style == "s" then
    local queue = SILE.typesetter.state.outputQueue
    local strippedContent = {}
    for _, item in ipairs(content) do
      if item.tag ~= "note" then table.insert(strippedContent, item) end
    end
    for i=#queue, 1, -1 do
      local box = queue[i]
      if box:isVbox() then
        box.headerContent = strippedContent
        break
      end
    end
  elseif options.style == "mt" then
    SILE.scratch.headers.right = content
  end
  -- SILE.call("bidi-off")
end)

SILE.registerCommand("para-end", function ()
  -- bidiBreak()
  SILE.typesetter:leaveHmode(true)
end)

SILE.registerCommand("chapter", function (options, content)
  if options.number == "1" then
    doSwitch()
  end
  SILE.scratch.sections.chapterBegun = true
  SILE.scratch.sections.notesNumber = 1
  SILE.scratch.sections.xrefNumber = 0.001
  local chapterNumber = toArabic(options.number)..SU.utf8charfromcodepoint("U+200F").." "
  SILE.scratch.sections.ssvChapter = chapterNumber
  SILE.scratch.sections.ssvLitChapter = chapterNumber
  SILE.process(content)
  allTypesetters(function (typesetter, section, name)
    SILE.settings.temporarily(function ()
      if name == "interlinear" then
        SILE.call("set", {
          parameter = "document.lineskip",
          value = SILE.settings.get("interlinear.height")
        })
      end
      SILE.typesetter:leaveHmode(true)
    end)
    section.queue = typesetter.state.outputQueue
    if name == "interlinear" or name == "ssvLit" or name == "ssv" then
      for _, box in ipairs(section.queue) do
        if box:isVbox() then
          box.verses = {}
          for _, node in ipairs(box.nodes) do
            if node.beginSection then table.insert(box.verses, node.beginSection) end
          end
        end
      end
    end
    if name == "ssv" then
      for _, box in ipairs(section.queue) do
        if box:isVbox() then
          box.notes = {}
          for _, node in ipairs(box.nodes) do
            if node.notesNumber then table.insert(box.notes, node.notesNumber) end
          end
        end
      end
    end
    if name == "notes" then
      for _, box in ipairs(section.queue) do
        if box:isVbox() then
          for _, node in ipairs(box.nodes) do
            if node.notesNumber then
              box.notesNumber = node.notesNumber
              break
            end
          end
        end
      end
    end
    typesetter.state.outputQueue = {}
  end)
  outputPages()
end)

function measureHeight (vboxes)
  if not vboxes or #vboxes == 0 then
    return 0
  end
  -- local height = SILE.pagebuilder.collateVboxes(vboxes).height
  local height = 0
  for _, vbox in ipairs(vboxes) do
    if (vbox:isVbox()) then
      height = height + vbox.height + vbox.depth
    elseif vbox:isVglue() then
      height = height + vbox.height
    end
  end
  if type(height) == "table" then height = height.length end
  return height
end

function outputPages ()
  allTypesetters(function (typesetter, section)
    section.lastHeight = 0
    section.lastBreakpoint = 0
  end)
  local verse = 0
  local height = 0
  local lastNoteNumber = 0
  while
    #sections.types.interlinear.queue > 0
    or #sections.types.ssvLit.queue > 0
    or #sections.types.ssv.queue > 0
    -- or #sections.types.notes.queue > 0
  do
    verse = verse + 1
    local noteNumberToConsider = lastNoteNumber
    local minimumContribution = 0
    -- local extraContribution = 0
    allTypesetters(function (typesetter, section, name)
      if name == "notes" then return end
      section.minimumContent = {}
      if name == "ssv" then sections.types.notes.minimumContent = {} end
      if section.lastBreakpoint >= verse then
        return
      end
      while true do
        local box = table.remove(section.queue, 1)
        if not box then break end
        table.insert(section.minimumContent, box)
        if box:isVbox() then
          if box.notes and #box.notes > 0 then
            local notesSection = sections.types.notes
            noteNumberToConsider = box.notes[#box.notes]
            -- We need to add content
            while true do
              local notesBox = table.remove(notesSection.queue, 1)
              if not notesBox then break end
              table.insert(notesSection.minimumContent, notesBox)
              if
                notesBox:isVbox()
                and notesBox.notesNumber == noteNumberToConsider
              then break end
            end
          end
          if #box.verses > 0 then
            section.breakpointToConsider = box.verses[#box.verses]
            break
          end
        end
      end
      minimumContribution = minimumContribution + measureHeight(section.minimumContent)
      if name == "ssv" then
        minimumContribution = minimumContribution + measureHeight(sections.types.notes.minimumContent)
      end
    end)
    -- print("Minimum contribution for verse "..verse, minimumContribution)
    local notEnoughSpace = height + minimumContribution > SILE.scratch.sections.availableHeight
    if notEnoughSpace then
      addAsMuchAsPossible({
        "ssv",
        "interlinear",
        "ssvLit"
      }, SILE.scratch.sections.availableHeight - height, lastNoteNumber, verse - 1)
      -- print("Too high, breaking!")
      local ssvQueue = sections.types.ssv.typesetter.state.outputQueue
      local firstVbox = findNextVBox(ssvQueue)
      SILE.scratch.headers.left = (firstVbox and firstVbox.headerContent) or SILE.scratch.sections.lastHeader
      local lastVbox
      for i=#ssvQueue, 1, -1 do
        local box = ssvQueue[i]
        if not lastVbox and box:isVbox() then lastVbox = box end
        if box.headerContent then
          SILE.scratch.sections.lastHeader = box.headerContent
          break
        end
      end
      if lastVbox.headerContent then
        local removeNotesTo = lastVbox.notes[1]
        local box
        repeat
          box = table.remove(ssvQueue)
          table.insert(sections.types.ssv.minimumContent, 1, box)
        until box == lastVbox
        if removeNotesTo then
          repeat
            box = table.remove(sections.types.notes.typesetter.state.outputQueue)
            table.insert(sections.types.notes.minimumContent, 1, box)
          until box.notesNumber == removeNotesTo
        end
      end
      buildConstraints()
      doSwitch()
      height = 0
    else
      lastNoteNumber = noteNumberToConsider
      height = height + minimumContribution
      -- print("Height is now "..height)
    end
    allTypesetters(function (typesetter, section)
      section.lastBreakpoint = section.breakpointToConsider or verse
      section.breakpointToConsider = nil
      local content = section.minimumContent
      if content then
        if notEnoughSpace then
          while #content > 0 and not content[1]:isVbox() do
            table.remove(content, 1)
          end
          height = height + measureHeight(content)
        end
        for _, box in ipairs(content) do
          table.insert(typesetter.state.outputQueue, box)
        end
      end
    end)
  end
  if #sections.types.notes.queue > 0 then
    addNotesAsPossible(
      SILE.scratch.sections.availableHeight - height,
      nil,
      sections.types.notes.queue
    )
  end
  if #sections.types.notes.queue > 0 then
    -- Still haven't finished the notes, get them out
    buildConstraints()
    doSwitch()
    sections.types.notes.typesetter.state.outputQueue = sections.types.notes.queue
  end
  buildConstraints()
  finishPage()
end

function addNotesAsPossible (availableHeight, notesNumber, content)
  local isBad
  if notesNumber then
    isBad = function (vbox)
      return vbox.notesNumber and vbox.notesNumber > notesNumber
    end
  else
    isBad = function () return false end
  end
  local section = sections.types.notes
  content = content or section.minimumContent
  if #content == 0 then content = section.queue end
  if #content > 0 then
    while
      shouldAddNextLine(content, availableHeight, isBad)
    do
      local box
      repeat
        box = table.remove(content, 1)
        if box:isVbox() then
          availableHeight = availableHeight - box.height - box.depth
        elseif box:isVglue() then
          availableHeight = availableHeight - box.height
        end
        table.insert(section.typesetter.state.outputQueue, box)
      until box:isVbox()
    end
  end
  return availableHeight
end

function addAsMuchAsPossible (toCheck, availableHeight, notesNumber, verse)
  availableHeight = addNotesAsPossible(availableHeight, notesNumber)
  if availableHeight > 0 then
    SU.debug("sectionbreak", "Considering adding lines for verse "..verse)
    addOneAtATime (toCheck, availableHeight, verse)
  end
end

function addOneAtATime (toCheck, availableHeight, verse)
  local stillGoing = {}
  for _, sectionName in ipairs(toCheck) do
    local section = sections.types[sectionName]
    if section.lastBreakpoint <= verse then
      SU.debug("sectionbreak", "Should we add a line for "..sectionName.."?")
      local content = section.minimumContent
      local shouldAdd = #content > 0
      if shouldAdd then
        SU.debug("sectionbreak", "It has content...")
        shouldAdd, availableHeight = shouldAddNextLine(content, availableHeight, function (vbox, height, availableHeight)
          local isBadLine = #vbox.verses > 0
            and vbox.verses[#vbox.verses] > verse
          SU.debug("sectionbreak", "The next line contains a future verse: "..isBadLine)
          if not isBadLine and vbox.notes and #vbox.notes > 0 then
            -- We need to check if this line contains verses, and break accordingly
            local notesSection = sections.types.notes
            local noteNumberToConsider = vbox.notes[#vbox.notes]
            SU.debug("sectionbreak", "We need to at least start note "..noteNumberToConsider)
            local queue = {}
            while true do
              local notesBox = table.remove(notesSection.minimumContent, 1)
              if not notesBox then notesBox = table.remove(notesSection.queue, 1) end
              if not notesBox then break end
              table.insert(queue, notesBox)
              SU.debug("sectionbreak", "Adding "..notesBox)
              if
                notesBox.notesNumber == noteNumberToConsider
              then break end
            end
            local newAvailableHeight = availableHeight - measureHeight(queue)
            if height > newAvailableHeight then
              -- We can add the line, but not the notes. Undo removal.
              for index, box in ipairs(queue) do
                table.insert(notesSection.queue, index, box)
              end
              return true
            else
              -- We can add the line and the notes. Commit.
              for _, box in ipairs(queue) do
                table.insert(notesSection.typesetter.state.outputQueue, box)
              end
              newAvailableHeight = addNotesAsPossible(newAvailableHeight, noteNumberToConsider)
              SU.debug("sectionbreak", "Adding line with notes!")
              return false, newAvailableHeight
            end
          end
          return isBadLine
        end)
      end
      if shouldAdd then
        SU.debug("sectionbreak", "Yes!")
        local box
        repeat
          box = table.remove(content, 1)
          if box:isVbox() then
            availableHeight = availableHeight - box.height - box.depth
          elseif box:isVglue() then
            availableHeight = availableHeight - box.height
          end
          table.insert(section.typesetter.state.outputQueue, box)
        until box:isVbox()
        if #content > 0 then
          table.insert(stillGoing, sectionName)
        end
      end
    end
  end
  if #stillGoing > 0 then addOneAtATime(stillGoing, availableHeight, verse) end
end

function shouldAddNextLine (content, availableHeight, isBad)
  local foundVbox = false
  local height = 0
  for _, vbox in ipairs(content) do
    if (vbox:isVbox()) then
      foundVbox = true
      height = height + vbox.height + vbox.depth
      local isBadLine, newAvailableHeight = isBad(vbox, height, availableHeight)
      if isBadLine then return false, availableHeight end
      if newAvailableHeight then availableHeight = newAvailableHeight end
      break
    elseif vbox:isVglue() then
      height = height + vbox.height
    end
  end
  if not foundVbox then return false, availableHeight end
  if type(height) == "table" then height = height.length end
  return height <= availableHeight, availableHeight
end

function containsVbox (queue)
  for _, box in ipairs(queue) do
    if box:isVbox() then return true end
  end
  return false
end

-- function createCarryOver (overFill)
--   print("Overfull by "..overFill)
--   local maxVerse = 1000000
--   local carryOver = {
--     {
--       name = "ssv",
--       toNextPage = {},
--       numLinesToRemove = 0
--     },
--     {
--       name = "ssvLit",
--       toNextPage = {},
--       numLinesToRemove = 0
--     },
--     {
--       name = "interlinear",
--       toNextPage = {},
--       numLinesToRemove = 0
--     }
--   }

--   print("Carrying over unfinished lines")
--   for _, item in ipairs(carryOver) do
--     local tState = sections.types[item.name].typesetter.state
--     local state = sections.types[item.name].state
--     local chunks = state.chunks
--     if #tState.nodes > 0 then
--       local chunk = chunks[#chunks]
--       print("Automatically removing unfinished line")
--       item.numLinesToRemove = item.numLinesToRemove + 1
--       print("Subtracting", chunk.height)
--       overFill = overFill - chunk.height
--       state.height = state.height - chunk.height
--       if #chunk.verseContribution > 0 then
--         maxVerse = math.min(chunk.verseContribution[1] - 1, maxVerse)
--       end
--     end
--   end

--   local stillOverful = overFill > 0
--   while stillOverful do
--     local stillRemovingContent = false
--     for _, item in ipairs(carryOver) do
--       local state = sections.types[item.name].state
--       local chunks = state.chunks
--       local chunkIndex = #chunks - item.numLinesToRemove
--       -- if (chunks.firstChunkIsRemovable and chunkIndex > 0) or chunkIndex > 1 then
--       if chunkIndex > 0 then
--         local chunk = chunks[chunkIndex]
--         stillRemovingContent = true
--         item.numLinesToRemove = item.numLinesToRemove + 1
--         print("Subtracting", chunk.height)
--         overFill = overFill - chunk.height
--         state.height = state.height - chunk.height
--         if #chunk.verseContribution > 0 then
--           maxVerse = math.min(chunk.verseContribution[1] - 1, maxVerse)
--         end
--         if overFill <= 0 then
--           stillOverful = false
--           break
--         end
--         print("Still "..overFill.." to go")
--       end
--     end
--     if not stillRemovingContent then
--       print("No more content to remove, aborting!")
--       break
--     end
--   end
  
--   for _, item in ipairs(carryOver) do
--     local tState = sections.types[item.name].typesetter.state
--     for lineIndex=1, item.numLinesToRemove do
--       if lineIndex == 1 and #tState.nodes > 0 then
--         item.nodeCarryOver = tState.nodes
--         tState.nodes = {}
--       else
--         local queue = tState.outputQueue
--         repeat
--           table.insert(item.toNextPage, 1, table.remove(queue))
--         until queue[#queue]:isVbox()
--       end
--     end
--     local sectionMaxVerse
--     for i=#tState.outputQueue, 1, -1 do
--       local vbox = tState.outputQueue[i]
--       if vbox.verseContribution and #vbox.verseContribution > 0 then
--         sectionMaxVerse = vbox.verseContribution[#vbox.verseContribution]
--         break
--       end
--     end
--     if sectionMaxVerse > maxVerse then
--       print(item.name.." begins verse "..sectionMaxVerse.." but is only allowed to begin "..maxVerse)
--     end
--   end

--   return carryOver
-- end

SILE.registerCommand("verse-section", function (options, content)
  SILE.scratch.sections.sectionNumber = SILE.scratch.sections.sectionNumber + 1
  SILE.process(content)
  -- for _, section in pairs(sections.types) do
  --   local tState = section.typesetter.state
  --   section.firstNewBoxIndex = #tState.outputQueue + 1
  --   section.lastNodeLength = #tState.nodes
  -- end


  -- SILE.process(content)

  -- local minimum = 0
  -- local total = 0
  -- for _, section in pairs(sections.types) do
  --   total = total + section.state.height
  --   minimum = minimum + section.state.minimum
  -- end

  -- local overFill = total - SILE.scratch.sections.availableHeight
  -- if overFill > 0 then
  --   if minimum > SILE.scratch.sections.availableHeight then
  --     print("Can't even fit minimum!")
  --   end
  --   local carryOver = createCarryOver(overFill)

  --   -- for sectionName, section in pairs(sections.types) do
  --   --   print("Verse beginnings for "..sectionName)
  --   --   for _, line in ipairs(section.typesetter.state.outputQueue) do
  --   --     if line:isVbox() then
  --   --       print(line.verseContribution)
  --   --     end
  --   --   end
  --   -- end
    
  --   buildConstraints()
  --   doSwitch()

  --   for _, item in ipairs(carryOver) do
  --     if item.nodeCarryOver then
  --       local section = sections.types[item.name]
  --       local tState = section.typesetter.state
  --       local sState = section.state
  --       tState.nodes = item.nodeCarryOver
  --       for _, box in ipairs(item.toNextPage) do
  --         table.insert(tState.outputQueue, box)
  --         sState.height = sState.height + box.height + box.depth
  --       end
  --     end
  --   end
  -- end
end)

function findNextVBox (list, index)
  index = index or 1
  for i=index, #list do
    if list[i]:isVbox() then return list[i], i end
  end
end

-- function measureContribution (sectionName)
--   local section = sections.types[sectionName]
--   local firstNewBoxIndex = section.firstNewBoxIndex
--   local lastNodeLength = section.lastNodeLength
--   local isHardBreak = #SILE.typesetter.state.nodes == 0
--   SILE.typesetter:leaveHmode(1)
--   local tState = SILE.typesetter.state
--   if #tState.outputQueue == 0 then
--     section.lastState = section.state
--     section.state = {
--       height = section.lastState.height,
--       difference = 0,
--       minimum = section.lastState.height,
--       chunks = {}
--     }
--     return
--   end

--   local firstVbox, intermediaryIndex = findNextVBox(tState.outputQueue, firstNewBoxIndex)
--   local verseStartedOnNewLine = lastNodeLength == 0 or lastNodeLength >= #firstVbox.nodes - 3
  
--   local minimum = section.state.height
--   if verseStartedOnNewLine then
--     local box
--     repeat
--       box = tState.outputQueue[firstNewBoxIndex]
--       firstNewBoxIndex = firstNewBoxIndex + 1
--       minimum = minimum + box.height + box.depth
--     until box:isVbox()
--   end

--   -- local height = SILE.pagebuilder.collateVboxes(tState.outputQueue).height

--   local height = 0
--   local chunkHeight = 0
--   local chunks = {
--     -- firstChunkIsRemovable = not verseStartedOnNewLine
--   }
--   -- local firstContributionIndex = intermediaryIndex
--   -- if not verseStartedOnNewLine then
--   --   firstContributionIndex = firstContributionIndex + 1
--   -- end
--   for index, vbox in ipairs(tState.outputQueue) do
--     chunkHeight = chunkHeight + vbox.height + vbox.depth
--     if vbox:isVbox() then
--       if not vbox.verseContribution then
--         local verseContribution = {}
--         for _, node in ipairs(vbox.nodes) do
--           if node.beginSection then
--             table.insert(verseContribution, node.beginSection)
--           end
--         end
--         vbox.verseContribution = verseContribution
--       end

--       height = height + chunkHeight
--       -- if index >= firstContributionIndex then
--       table.insert(chunks, {
--         height = chunkHeight,
--         verseContribution = vbox.verseContribution
--       })
--       -- end
--       chunkHeight = 0
--     end
--   end
--   -- print(sectionName, chunks)

--   if not isHardBreak then
--     local nodes = tState.outputQueue[#tState.outputQueue].nodes
--     table.remove(nodes)
--     table.remove(nodes)

--     tState.nodes = nodes

--     table.remove(tState.outputQueue)
--     while #tState.outputQueue > 0 and not tState.outputQueue[#tState.outputQueue]:isVbox() do
--       table.remove(tState.outputQueue)
--     end
--   end

--   local difference = height - section.state.height
--   section.lastState = section.state
--   section.state = {
--     height = height,
--     difference = difference,
--     minimum = minimum,
--     chunks = chunks
--   }
--   -- if sectionName == "ssvLit" then
--   --   print("Adding "..difference.." for a total of "..height)
--   --   if minimum > 0 then print(section.state) end
--   -- end
--   -- tState.previousVbox = tState.outputQueue[#tState.outputQueue]
-- end

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
    outputYourself = emptyFunction
  })
  SILE.process(content)
--   SILE.settings.temporarily(function ()
--     SILE.call("set", {
--       parameter = "document.lineskip",
--       value = SILE.settings.get("interlinear.height")
--     })
--     SILE.process(content)
--     measureContribution("interlinear")
--   end)
end)

SILE.registerCommand("ssv-lit", function (options, content)
  SILE.typesetter = sections.types.ssvLit.typesetter
  renderChapter("ssvLit", content)
  SILE.typesetter:pushHbox({
    beginSection = SILE.scratch.sections.sectionNumber,
    outputYourself = emptyFunction
  })
  SILE.process(content)
  -- processWithBidi(content)
  -- measureContribution("ssvLit")
end)

SILE.registerCommand("ssv", function (options, content)
  SILE.typesetter = sections.types.ssv.typesetter
  SILE.settings.temporarily(function ()
    SILE.settings.set("document.parindent", SILE.nodefactory.newGlue("1cm"))
    renderChapter("ssv", content)
    SILE.typesetter:pushHbox({
      beginSection = SILE.scratch.sections.sectionNumber,
      outputYourself = emptyFunction
    })
    SILE.process(content)
  end)
  -- processWithBidi(content)
  -- measureContribution("ssv")
end)

SILE.registerCommand("note", function (options, content)
  local notesNumber = SILE.scratch.sections.notesNumber
  local mark
  if options.style == "f" then
    SILE.scratch.sections.notesNumber = SILE.scratch.sections.notesNumber + 1
    mark = SU.utf8charfromcodepoint("U+200F")
      ..footnoteMark
      ..toArabic(tostring(notesNumber))
      ..SU.utf8charfromcodepoint("U+200F")
      .." "
  else
    notesNumber = notesNumber - 1 + SILE.scratch.sections.xrefNumber
    SILE.scratch.sections.xrefNumber = SILE.scratch.sections.xrefNumber + 0.001
    mark = SU.utf8charfromcodepoint("U+2021").." "
  end

  SILE.typesetter:pushHbox({
    notesNumber = notesNumber,
    outputYourself = emptyFunction
  })
  SILE.call("raise", {height = "5pt"}, function ()
    SILE.Commands["font"]({ size = "1.5ex" }, function()
      SILE.typesetter:typeset(mark)
    end)
  end)
  local oldTypesetter = SILE.typesetter
  SILE.typesetter = sections.types.notes.typesetter
  SILE.settings.temporarily(function ()
    -- SILE.call("font", {size = "12pt"})
    SILE.call("font", {size = "9pt"})
    SILE.call("set", {
      parameter = "document.lineskip",
      value = "0.7ex"
    })
    SILE.call("set", {
      parameter = "document.rskip",
      value = "1cm"
    })
    SILE.call("set", {
      parameter = "current.parindent",
      value = "-1cm"
    })
    SILE.typesetter:pushHbox({
      notesNumber = notesNumber,
      outputYourself = emptyFunction
    })
    SILE.typesetter:typeset(mark)
    SILE.process(content)
    SILE.typesetter:leaveHmode(true)
  end)
  SILE.typesetter = oldTypesetter
end)

function sections:init()
  sections:mirrorMaster("right", "left")
  sections.pageTemplate = SILE.scratch.masters[context.side]
  SILE.scratch.counters.folio.value = context.page
  local deadspace = SILE.settings.get("sections.interlinearskip")
    + SILE.toPoints(SILE.settings.get("interlinear.height"))
    + SILE.settings.get("sections.ssvlitskip")
    + SILE.settings.get("sections.ssvskip")
    + SILE.toPoints(SILE.settings.get("sections.notesskip"))
  print("Page is "..SILE.toAbsoluteMeasurement(SILE.toMeasurement(100, '%ph')))
  SILE.scratch.sections.availableHeight = SILE.toAbsoluteMeasurement(SILE.toMeasurement(100 - 12, '%ph')) - deadspace
  print("We have "..SILE.scratch.sections.availableHeight.." available")
  
  local ret = plain.init(self)

  SILE.registerCommand("center", function (options, content)
    SILE.settings.temporarily(function ()
      SILE.settings.set("document.lskip", SILE.nodefactory.hfillGlue)
      SILE.settings.set("document.rskip", SILE.nodefactory.hfillGlue)
      SILE.settings.set("typesetter.parfillskip", SILE.nodefactory.zeroGlue)
      SILE.settings.set("document.parindent", SILE.nodefactory.zeroGlue)
      local space = SILE.length.parse("1spc")
      space.stretch = 0
      space.shrink = 0
      SILE.settings.set("document.spaceskip", space)
      SILE.process(content)
      SILE.typesetter:leaveHmode(true)
      SILE.documentState.documentClass.endPar(SILE.typesetter)
    end)
  end)

  -- SILE.typesetter:registerPageEndHook(function ()
  --   SILE.outputter:debugFrame(SILE.getFrame("interlinear"))
  --   SILE.outputter:debugFrame(SILE.getFrame("ssvLit"))
  --   SILE.outputter:debugFrame(SILE.getFrame("ssv"))
  --   SILE.outputter:debugFrame(SILE.getFrame("notes"))
  -- end)

  sections.mainTypesetter = SILE.typesetter
  sections.mainTypesetter:init(SILE.getFrame("content"))
  SILE.call("bidi-on")
  allTypesetters(function (typesetter, section, name)
    SILE.typesetter:init(SILE.getFrame(name))
    if name ~= "interlinear" then SILE.call("bidi-on") end
  end)
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
  -- buildConstraints()
  -- finishPage()
  local side = sections.pageTemplate == SILE.scratch.masters.right and "left" or "right"
  local page = SILE.scratch.counters.folio.value + 1
  writeFile("context.lua", "return {side=\""..side.."\",page="..page.."}")
  plain.finish(self)
end

return sections