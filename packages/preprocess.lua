local lom = require "lomwithpos"
local book = arg[1]

if not book then
  print "The 'book' argument is required"
  os.exit()
end

local inputDir = "../books/"..book
local outputDir = "../output/"..book

function readFile (file)
  local ret = ""
  for line in io.lines(file) do 
    ret = ret .. line
  end
  return ret
end

function writeFile (file, data)
  file = io.open(file, "w")
  file:write(data)
  file:close()
end

function getAttr (attr)
  local str = ""
  if #attr == 0 then
    return str
  end
  for i, at in ipairs(attr) do
    str = str.." "..at.."=\""..attr[at].."\""
  end
  return str
end

function deparse (xml)
  if type(xml) ~= "table" then
    return xml
  end
  local str = "<"..xml.tag..getAttr(xml.attr)
  if (#xml == 0) then
    return str.." />"
  end
  str = str..">"
  for i, child in ipairs(xml) do
    str = str..deparse(child)
  end
  str = str.."</"..xml.tag..">"
  return str
end

function createNested (parent, child, tag, index)
  local nested = {
    attr = child.attr,
    tag = child.tag
  }
  for i = index, #parent do
    if parent[i].tag == tag or parent[i].tag == "chapter" then
      return i - 1, nested
    end
    table.insert(nested, parent[i])
  end
  return #parent, nested
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
        tag = child.tag.."-break"
      })
      for j, paraChild in ipairs(child) do
        table.insert(flattened, paraChild)
      end
    else
      table.insert(flattened, child)
    end
  end
  return flattened
end

function flip (xml) return nest(nest(flatten(xml)), "chapter") end

function getNext (tag, index, xml)
  local child
  print("starting at index", index)
  for i = index, #xml do
    child = xml[i]
    if child.tag == tag then return i, child end
  end
  return nil
end

function combineChapter (ssv, lit)
  print("Chapter", ssv.attr.number, lit.attr.number)
  local combined = {
    attr = lit.attr,
    tag = lit.tag
  }
  local i1 = 1
  local i2 = 1
  local ssvChild
  local litChild
  while true do
    i1, ssvChild = getNext("verse", i1, ssv)
    i2, litChild = getNext("verse", i2, lit)
    if not (ssvChild and litChild) then break end
    ssvChild.tag = "ssv"
    litChild.tag = "ssv-lit"
    table.insert(combined, {
      litChild,
      ssvChild,
      attr = {
        "number",
        number = ssvChild.attr.number
      },
      tag = "verse"
    })
    i1 = i1 + 1
    i2 = i2 + 1
  end
  return combined
end

function combine (ssv, lit)
  local combined = {
    attr = lit.attr,
    tag = lit.tag
  }
  local i1 = 1
  local i2 = 1
  local ssvChild
  local litChild
  while true do
    ssvChild = ssv[i2]
    if ssvChild.tag == "chapter" then break end
    print("tag", ssvChild.tag, "index", i2)
    table.insert(combined, ssvChild)
    i2 = i2 + 1
  end
  i2 = i2 - 1
  while true do
    i1, ssvChild = getNext("chapter", i1, ssv)
    i2, litChild = getNext("chapter", i2, lit)
    if not (ssvChild and litChild) then break end
    table.insert(combined, combineChapter(ssvChild, litChild))
    i1 = i1 + 1
    i2 = i2 + 1
  end
  return combined
end

function getVerses (xml, stack, paths)
  -- if !stack then stack = {} end
  if type(stack) ~= "string" then
    stack = xml.tag
  else
    stack = stack.."."..xml.tag
  end
  if type(paths) ~= "table" then paths = {} end
  if xml.tag == "verse" then
    paths[stack] = true
  end
  for i, child in ipairs(xml) do
    if type(child) == "table" then
      getVerses(child, stack, paths)
    end
  end
  return paths
end

local ssvLit = lom.parse(readFile(inputDir.."/SSV_Lit.xml"))
local ssv = lom.parse(readFile(inputDir.."/SSV.xml"))

ssv = flip(ssv)
ssvLit = flip(ssvLit)

-- writeFile(outputDir.."/prepared.xml", deparse(ssvLit))
writeFile(outputDir.."/prepared.xml", deparse(combine(ssv, ssvLit)))