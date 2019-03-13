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
  default = "#26BF8B",
  help = "The color of the line separating the Interlinear and SSV Lit sections"
})

SILE.settings.declare({
  name = "sections.notesseparator",
  type = "string",
  default = "#26BF8B",
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

function leaveHmodeMiddleman (self, independent)
  if self.holdContentMode then independent = true end
  return SILE.defaultTypesetter.leaveHmode(self, independent)
end

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

function buildConstraints ()
  local interlinearTypesetter = sections.types.interlinear.typesetter
  local ssvLitTypesetter = sections.types.ssvLit.typesetter
  local ssvTypesetter = sections.types.ssv.typesetter
  local notesTypesetter = sections.types.notes.typesetter
  local interlinearFrame = interlinearTypesetter.frame
  local ssvLitFrame = ssvLitTypesetter.frame
  local ssvFrame = ssvTypesetter.frame
  local notesFrame = notesTypesetter.frame
  allTypesetters(function (typesetter, section, name)
    local height = measureHeight(typesetter.state.outputQueue)
    if height > 0 and name == "interlinear" then
      height = height + SILE.toPoints(SILE.settings.get("interlinear.height"))
    end
    typesetter.frame:constrain("height", height)
  end)
  local bottomFrame = ssvLitFrame:height() > 0 and ssvLitFrame or interlinearFrame
  ssvLitFrame:constrain("top", "bottom("..interlinearFrame.id..") + "..(interlinearFrame:height() > 0 and SILE.settings.get("sections.interlinearskip")) or "0")
  ssvFrame:constrain("top", "bottom("..bottomFrame.id..") + "..(bottomFrame:height() > 0 and SILE.settings.get("sections.ssvlitskip")) or "0")
  notesFrame:constrain("bottom", "top(folio) - "..SILE.settings.get("sections.notesskip"))
  local buffer = SILE.settings.get("sections.borderbuffer")
  local borderWidth = 8
  local halfWidth = math.ceil(borderWidth / 2) + 1
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
    local topY = interlinearFrame:top() - borderWidth
    local bottomY = bottomFrame:bottom() + borderWidth + 5
    local leftX = interlinearFrame:left() - extraWidth
    local rightX = interlinearFrame:right() + extraWidth
    SILE.outputter:pushColor(SILE.colorparser(SILE.settings.get("sections.interlinearseparator")))
    outputFrame(
      leftX,
      topY,
      rightX,
      bottomY,
      borderWidth
    )
    SILE.outputter:popColor()

    extraWidth = buffer + halfWidth
    SILE.outputter:pushColor(SILE.colorparser("white"))
    outputFrame(
      interlinearFrame:left() - extraWidth,
      interlinearFrame:top() - halfWidth,
      interlinearFrame:right() + extraWidth,
      bottomFrame:bottom() + halfWidth + 5,
      2
    )
    SILE.outputter:popColor()

    local src = SILE.resolveFile('./graphics/top_left.png') or SU.error("Couldn't find file")
    local box_width,box_height = SILE.outputter.imageSize(src)
    local long = box_width * borderWidth / box_height
    if 2*long <= bottomY - topY then
      SILE.outputter.drawImage(
        SILE.resolveFile('./graphics/left_top.png'),
        leftX,
        topY,
        borderWidth,
        long
      )
      SILE.outputter.drawImage(
        SILE.resolveFile('./graphics/left_bottom.png'),
        leftX,
        bottomY - long,
        borderWidth,
        long
      )
      SILE.outputter.drawImage(
        SILE.resolveFile('./graphics/right_top.png'),
        rightX - borderWidth,
        topY,
        borderWidth,
        long
      )
      SILE.outputter.drawImage(
        SILE.resolveFile('./graphics/right_bottom.png'),
        rightX - borderWidth,
        bottomY - long,
        borderWidth,
        long
      )
    end
    SILE.outputter.drawImage(
      SILE.resolveFile('./graphics/top_left.png'),
      leftX,
      topY,
      long,
      borderWidth
    )
    SILE.outputter.drawImage(
      SILE.resolveFile('./graphics/bottom_left.png'),
      leftX,
      bottomY - borderWidth,
      long,
      borderWidth
    )
    SILE.outputter.drawImage(
      SILE.resolveFile('./graphics/top_right.png'),
      rightX - long,
      topY,
      long,
      borderWidth
    )
    SILE.outputter.drawImage(
      SILE.resolveFile('./graphics/bottom_right.png'),
      rightX - long,
      bottomY - borderWidth,
      long,
      borderWidth
    )
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
    sections[section.."Chapter"] = nil
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
  SILE.typesetter:leaveHmode()
end)

SILE.registerCommand("optbreak", function ()
  SILE.typesetter:typeset("//")
end)

SILE.registerCommand("chapter", function (options, content)
  if options.number == "1" then
    doSwitch()
  end
  local chapterNumber = tonumber(options.number)
  SILE.scratch.sections.chapterBegun = true
  SILE.scratch.sections.notesNumber = 1
  SILE.scratch.sections.xrefNumber = 0.001
  local chapterMark = toArabic(options.number)..SU.utf8charfromcodepoint("U+200F").." "
  SILE.scratch.sections.ssvChapter = chapterMark
  SILE.scratch.sections.ssvLitChapter = chapterMark
  SILE.process(content)
  allTypesetters(function (typesetter, section, name)
    SILE.settings.temporarily(function ()
      if name == "interlinear" then
        SILE.call("set", {
          parameter = "document.lineskip",
          value = SILE.settings.get("interlinear.height")
        })
      end
      SILE.typesetter:leaveHmode()
      SILE.typesetter.holdContentMode = nil
    end)
    section.queue = typesetter.state.outputQueue
    if name == "interlinear" or name == "ssvLit" or name == "ssv" then
      for _, box in ipairs(section.queue) do
        box.chapterNumber = box.chapterNumber or chapterNumber
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
        box.chapterNumber = box.chapterNumber or chapterNumber
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
  outputPages(chapterNumber)
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

function outputPages (chapterNumber)
  local verse = 0
  local height = 0
  local lastNoteNumber = 0
  allTypesetters(function (typesetter, section)
    while #section.queue > 0 and section.queue[1].chapterNumber < chapterNumber do
      table.insert(typesetter.state.outputQueue, table.remove(section.queue, 1))
    end
    height = height + measureHeight(typesetter.state.outputQueue)
    section.lastBreakpoint = 0
  end)
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
      },
        SILE.scratch.sections.availableHeight - height,
        lastNoteNumber,
        verse - 1
      )
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
      if lastVbox and lastVbox.headerContent then
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
      height = height + minimumContribution
      -- print("Height is now "..height)
    end
    lastNoteNumber = noteNumberToConsider
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
        shouldAdd, availableHeight = shouldAddNextLine(content, availableHeight, function (vbox, availableHeight)
          local isBadLine = #vbox.verses > 0
            and vbox.verses[#vbox.verses] > verse
          SU.debug("sectionbreak", "The next line contains a future verse: "..isBadLine)
          if not isBadLine and vbox.notes and #vbox.notes > 0 then
            -- We need to check if this line contains verses, and break accordingly
            local notesSection = sections.types.notes
            local noteNumberToConsider = vbox.notes[#vbox.notes]
            SU.debug("sectionbreak", "We need to at least start note "..noteNumberToConsider)
            local queue = {}
            local notesContentQueue = notesSection.minimumContent
            while true do
              if #notesContentQueue == 0 then notesContentQueue = notesSection.queue end
              local notesBox = table.remove(notesContentQueue, 1)
              if not notesBox then break end
              table.insert(queue, notesBox)
              SU.debug("sectionbreak", "Adding "..notesBox)
              if
                notesBox.notesNumber == noteNumberToConsider
              then break end
            end
            local newAvailableHeight = availableHeight - measureHeight(queue)
            if newAvailableHeight < 0 then
              SU.debug("sectionbreak", "We can add the line, but not the notes. Undo removal.")
              for index, box in ipairs(queue) do
                table.insert(notesContentQueue, index, box)
              end
              return true
            else
              SU.debug("sectionbreak", "We can add the line and the notes. Commit.")
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
  local height = 0
  for _, vbox in ipairs(content) do
    if (vbox:isVbox()) then
      height = height + vbox.height + vbox.depth
      if type(height) == "table" then height = height.length end
      if height > availableHeight then return false, availableHeight end
      local isBadLine, newAvailableHeight = isBad(vbox, availableHeight - height)
      if newAvailableHeight then availableHeight = newAvailableHeight end
      if isBadLine then return false, availableHeight end
      return true, availableHeight
    elseif vbox:isVglue() then
      height = height + vbox.height
    end
  end
  return false, availableHeight
end

function containsVbox (queue)
  for _, box in ipairs(queue) do
    if box:isVbox() then return true end
  end
  return false
end

SILE.registerCommand("verse-section", function (options, content)
  SILE.scratch.sections.sectionNumber = SILE.scratch.sections.sectionNumber + 1
  SILE.process(content)
end)

function findNextVBox (list, index)
  index = index or 1
  for i=index, #list do
    if list[i]:isVbox() then return list[i], i end
  end
end

SILE.registerCommand("interlinear", function (options, content)
  SILE.typesetter = sections.types.interlinear.typesetter
  SILE.typesetter:pushHbox({
    beginSection = SILE.scratch.sections.sectionNumber,
    outputYourself = emptyFunction
  })
  SILE.process(content)
end)

SILE.registerCommand("ssv-lit", function (options, content)
  SILE.typesetter = sections.types.ssvLit.typesetter
  SILE.settings.temporarily(function ()
    SILE.call("ssvLit:style")
    renderChapter("ssvLit", content)
    SILE.typesetter:pushHbox({
      beginSection = SILE.scratch.sections.sectionNumber,
      outputYourself = emptyFunction
    })
    SILE.process(content)
  end)
end)

SILE.registerCommand("ssv", function (options, content)
  SILE.typesetter = sections.types.ssv.typesetter
  SILE.settings.temporarily(function ()
    SILE.call("ssv:style")
    renderChapter("ssv", content)
    SILE.typesetter:pushHbox({
      beginSection = SILE.scratch.sections.sectionNumber,
      outputYourself = emptyFunction
    })
    SILE.process(content)
  end)
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
    SILE.typesetter:leaveHmode()
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
    typesetter.leaveHmode = leaveHmodeMiddleman
    typesetter.holdContentMode = true
    typesetter:init(SILE.getFrame(name))
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
  buildConstraints()
  finishPage()
  local side = sections.pageTemplate == SILE.scratch.masters.right and "left" or "right"
  local page = SILE.scratch.counters.folio.value + 1
  writeFile("context.lua", "return {side=\""..side.."\",page="..page.."}")
  plain.finish(self)
end

return sections