SILE.registerCommand("interlinear:vernacular-font", function(options, content)
  SILE.call("font", {
    direction = "RTL",
    size = "9pt",
    weight = 400
  })
end)

SILE.registerCommand("interlinear:source-font", function(options, content)
  SILE.call("font", {
    family = "Times New Roman",
    size = "12pt",
    weight = 800
  })
end)

SILE.settings.declare({
  name = "interlinear.height",
  type = "string",
  default = "-6mm",
  help = "Vertical offset between the interlinear and the main text"
})

SILE.settings.declare({
  name = "interlinear.latinspacer",
  type = "Glue",
  default = SILE.nodefactory.newGlue("0.5em"),
  help = "Glue added between consecutive Latin interlinear"
})

local bidi = SILE.require('bidi', 'packages')

if not SU.firstChar then
  SU.firstChar = function (s)
    local chars = SU.splitUtf8(s)
    return chars[1]
  end
end
if not SU.lastChar then
  SU.lastChar = function (s)
    local chars = SU.splitUtf8(s)
    return chars[#chars]
  end
end
if not table.flip then
  table.flip = function(tbl)
    for i=1, math.floor(#tbl / 2) do
      local tmp = tbl[i]
      tbl[i] = tbl[#tbl - i + 1]
      tbl[#tbl - i + 1] = tmp
    end
  end
end

local isLatin = function(c)
  return (c > 0x20 and c <= 0x24F) or (c>=0x300 and c<=0x36F)
    or (c >= 0x1DC0 and c<= 0x1EFF) or (c >= 0x2C60 and c <= 0x2c7F)
end

local checkIfSpacerNeeded = function(reading)
  -- First, did we have an interlinear node at all?
  if not SILE.scratch.lastInterlinearBox then return end
  -- Does the current reading start with a latin?
  -- if not isLatin(SU.codepoint(SU.firstChar(reading))) then return end
  -- Did we have some nodes recently?
  local top = #SILE.typesetter.state.nodes
  if top < 2 then return end
  -- Have we had other stuff since the last interlinear node?
  if SILE.typesetter.state.nodes[top] ~= SILE.scratch.lastInterlinearBox
     and SILE.typesetter.state.nodes[top-1] ~= SILE.scratch.lastInterlinearBox then
    return
  end
  -- Does the previous reading end with a latin?
  -- if not isLatin(SU.codepoint(SU.lastChar(SILE.scratch.lastInterlinearText))) then return end
  -- OK, we need a spacer!
  SILE.typesetter:pushGlue(SILE.settings.get("interlinear.latinspacer"))
end

SILE.registerCommand("item", function (options, content)
  local vernacular = SU.required(options, "vernacular", "\\interlinear")
  local greek = SU.required(options, "greek", "\\interlinear")
  SILE.typesetter:setpar("")

  checkIfSpacerNeeded(vernacular)

  SILE.call("hbox", {}, function ()
    SILE.settings.temporarily(function ()
      SILE.call("noindent")
      SILE.call("interlinear:vernacular-font")
      SILE.typesetter:typeset(vernacular)
    end)
  end)
  local interlinearbox = SILE.typesetter.state.nodes[#SILE.typesetter.state.nodes]
  local hbox = interlinearbox.value[1]
  
  if hbox.nodes then
    hbox = hbox.nodes[1]
    if hbox.value.items then table.flip(hbox.value.items) end
    table.flip(hbox.value.glyphString)
  end
  
  interlinearbox.outputYourself = function (self, typesetter, line)
    local ox = typesetter.frame.state.cursorX
    local oy = typesetter.frame.state.cursorY
    typesetter.frame:advanceWritingDirection(interlinearbox.width)
    typesetter.frame:advancePageDirection(-SILE.toPoints(SILE.settings.get("interlinear.height")))
    SILE.outputter.moveTo(typesetter.frame.state.cursorX, typesetter.frame.state.cursorY)
    for i = 1, #(self.value) do
      local node = self.value[i]
      node:outputYourself(typesetter, line)
    end
    typesetter.frame.state.cursorX = ox
    typesetter.frame.state.cursorY = oy
  end
  -- measure the content
  -- SILE.call("hbox", {}, {greek})
  SILE.call("hbox", {}, function ()
    SILE.settings.temporarily(function ()
      SILE.call("noindent")
      SILE.call("interlinear:source-font")
      SILE.typesetter:typeset(greek)
    end)
  end)
  cbox = SILE.typesetter.state.nodes[#SILE.typesetter.state.nodes]
  SU.debug("interlinear", "base box is " .. cbox)
  SU.debug("interlinear", "vernacular is  " .. interlinearbox)
  if cbox:lineContribution() > interlinearbox:lineContribution() then
    SU.debug("interlinear", "Base is longer, offsetting interlinear to fit")
    -- This is actually the offset against the base
    interlinearbox.width = SILE.length.make(cbox:lineContribution() - interlinearbox:lineContribution()).length/2
  else
    local diff = interlinearbox:lineContribution() - cbox:lineContribution()
    if type(diff) == "table" then diff = diff.length end
    local to_insert = SILE.length.new({ length = diff / 2 })
    SU.debug("interlinear", "Vernacular is longer, inserting " .. to_insert .. " either side of base")
    cbox.width = SILE.length.make(interlinearbox:lineContribution())
    interlinearbox.width = 0
    -- add spaces at beginning and end
    table.insert(cbox.value, 1, SILE.nodefactory.newGlue({ width = to_insert }))
    table.insert(cbox.value, SILE.nodefactory.newGlue({ width = to_insert }))
  end
  SILE.scratch.lastInterlinearBox = interlinearbox
  SILE.scratch.lastInterlinearText = vernacular
end)