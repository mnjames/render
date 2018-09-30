local book = arg[1]

if not book then
  print "The 'book' argument is required"
  os.exit()
end

local args = {}
local var
for _, a in ipairs(arg) do
  if string.sub(a, 1, 2) == "--" then
    if var then args[var] = true end
    var = string.sub(a, 3)
  else
    if var then args[var] = a end
    var = nil
  end
end

local base = require "base"
local lom = require "lomwithpos"

local inputDir = "../books/"..book
local outputDir = ".."

local buildOrder = {
  "interlinear",
  "ssv-lit",
  "ssv",
  "notes"
}

function splitSection (obj)
  local split1 = {
    attr = obj.attr,
    tag = obj.tag
  }
  local split2 = {
    attr = {
      "number",
      "type",
      number = tonumber(obj.attr.number) + 0.5,
      type = obj.attr.type
    },
    tag = obj.tag
  }
  local breakPoint = #obj / 2
  for i, child in ipairs(obj) do
    if i < breakPoint then table.insert(split1, child)
    else table.insert(split2, child)
    end
  end
  return {
    split1,
    split2
  }
end

function createNested (parent, child, tag, index)
  local nested = {
    attr = {
      "number",
      "type",
      number = child.attr.number,
      type = tag
    },
    tag = "section"
  }
  if tag == "verse" then
    table.insert(nested, {
      attr = child.attr,
      tag = child.tag
    })
  end
  -- local nested = {
  --   attr = child.attr,
  --   tag = child.tag
  -- }
  for i = index, #parent do
    if parent[i].tag == tag or parent[i].tag == "chapter" then
      return i - 1, nested
    end
    table.insert(nested, parent[i])
  end
  return #parent, nested
  -- return #parent, splitSection(nested)
end

function nest (xml, tag)
  tag = tag or "verse"
  local nested = {
    attr = xml.attr,
    tag = xml.tag
  }
  local child
  local i = 0
  local length = #xml
  while i < length do
  -- for i = 1, 20 do
    i = i + 1
    -- print(i)
    child = xml[i]
    if child.tag == tag then
      i, child = createNested(xml, child, tag, i + 1)
    end
    table.insert(nested, child)
    -- table.insert(nested, child[1])
    -- table.insert(nested, child[2])
  end
  return nested
end

function flatten (xml)
  local flattened = {
    attr = xml.attr,
    tag = xml.tag
  }
  for i, child in ipairs(xml) do
    if child.tag == "para" then
      -- table.insert(flattened, {
      --   attr = child.attr,
      --   tag = "begin-"..child.tag
      -- })
      table.insert(flattened, {
        attr = child.attr,
        tag = child.tag.."-start"
      })
      for j, paraChild in ipairs(child) do
        table.insert(flattened, paraChild)
      end
      table.insert(flattened, {
        attr = {},
        tag = child.tag.."-end"
      })
    else
      table.insert(flattened, child)
    end
  end
  return flattened
end

function flip (xml) return nest(nest(flatten(xml)), "chapter") end

function getNext (tag, index, xml)
  if not xml then
    return {
      index = index,
      value = nil
    }
  end
  local extra = {}
  local child
  for i = index, #xml do
    child = xml[i]
    if child.tag == tag then
      if #extra == 0 then extra = nil end
      return {
        extra = extra,
        index = i,
        value = child
      }
    else
      table.insert(extra, child)
    end
  end
  return {
    index = index,
    value = nil
  }
end

function getNextType (type, index, xml)
  if not xml then
    return {
      index = index,
      value = nil
    }
  end
  local extra = {}
  local child
  for i = index, #xml do
    child = xml[i]
    if child.tag == "section" and child.attr.type == type then
      if #extra == 0 then extra = nil end
      return {
        extra = extra,
        index = i,
        value = child
      }
    else
      table.insert(extra, child)
    end
  end
  return {
    index = index,
    value = nil
  }
end

function normalize (children)
  local keepGoing = false
  local numbers = {}
  for i, child in ipairs(children) do
    if child.value then
      keepGoing = true
      table.insert(numbers, tonumber(child.value.attr.number))
    end
  end
  if not keepGoing then return false end
  local min = math.min(table.unpack(numbers))
  local validChild
  for i, child in ipairs(children) do
    if child.value then
      if extractNumber(child.value.attr.number) > min then
        child.value = nil
        child.index = child.index - 1
      else
        validChild = child.value
      end
    end
  end
  return validChild
end

function extractNumber (str)
  return tonumber(string.gmatch(str, '%d+')())
end

function getFirst (array)
  for i, value in ipairs(array) do
    if value then return value end
  end
  return nil
end

function combineChapter (xmls)
  local valid = getFirst(xmls)
  -- local combined = {
  --   attr = valid.attr,
  --   tag = valid.tag
  -- }
  local combined = {
    attr = {
      "number",
      number = valid.attr.number
    },
    tag = "chapter"
  }
  local children = {}
  for i = 1, #xmls do children[i] = {index = 1} end
  while true do
    for i, xml in ipairs(xmls) do
      children[i] = getNextType("verse", children[i].index, xml)
    end
    valid = normalize(children)
    if not valid then break end
    -- local verse = {
    --   attr = {
    --     "number",
    --     "type",
    --     number = valid.attr.number,
    --     type = "verse"
    --   },
    --   tag = "section"
    -- }
    for i, child in ipairs(children) do
      if child.value then
        child.index = child.index + 1
        child.value.tag = buildOrder[i]
        child.value.attr = {}
        if child.extra then
          for extraIndex, extraInsert in ipairs(child.extra) do
            table.insert(child.value, extraIndex, extraInsert)
          end
        end
        table.insert(combined, child.value)
        -- table.insert(verse, child.value)
      end
    end
    -- table.insert(combined, verse)
  end
  return combined
end

function combine (xmls)
  local ssv = xmls[3]
  local combined = {
    attr = {
      "class",
      "version",
      class = "sections",
      version = "2.5"
    },
    tag = "sile"
  }
  -- local combined = {
  --   attr = ssv.attr,
  --   tag = ssv.tag
  -- }
  local ssvChild
  local i = 1
  while true do
    ssvChild = ssv[i]
    if ssvChild.tag == "section" then break end
    table.insert(combined, ssvChild)
    i = i + 1
  end
  
  local children = {}
  for i = 1, #xmls do children[i] = {index = 1} end
  while true do
    for i, xml in ipairs(xmls) do
      children[i] = getNextType("chapter", children[i].index, xml)
    end
    if not normalize(children) then break end
    local sections = {}
    for i, child in ipairs(children) do
      -- if child.extra then
      --   -- print("Extra", child.extra[1].tag)
      --   -- print("Value", child.value.tag)
      --   for extraIndex, extraInsert in ipairs(child.extra) do
      --     table.insert(child.value, extraIndex, extraValue)
      --   end
      -- end
      table.insert(sections, child.value)
    end
    table.insert(combined, combineChapter(sections))
    for i, child in ipairs(children) do
      child.index = child.index + 1
    end
  end
  return combined
end

local ssvLit = lom.parse(base.readFile(inputDir.."/SSV_Lit.usx"))
local ssv = lom.parse(base.readFile(inputDir.."/SSV.usx"))
local inter = lom.parse(base.readFile(inputDir.."/Interlinear.xml"))

ssvLit = flip(ssvLit)
ssv = flip(ssv)

base.writeFile(outputDir.."/prepared.xml", base.deparse(combine({
  inter,
  ssvLit,
  ssv
}), tonumber(args.chapter), tonumber(args.verse)))