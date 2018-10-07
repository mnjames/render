local base = {}

string.trim = function (str)
  return string.gsub(string.gsub(str, '^%s+', ''), '%s+$', '')
end

package.path = package.path..";../?.lua"

base.readFile = function (file)
  local ret = ""
  for line in io.lines(file) do 
    ret = ret .. line
  end
  return ret
end

base.writeFile = function (file, data)
  file = io.open(file, "w")
  file:write(data)
  file:close()
end

base.getChild = function (xml, tag)
  for i, child in ipairs(xml) do
    if child.tag == tag then return child end
  end
  return nil
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

local counter = 0
base.deparse = function (xml, maxChap, maxVerse)
  if type(xml) ~= "table" then
    return xml
  end
  if maxChap and xml.tag == "chapter" and tonumber(xml.attr.number) > maxChap then return ""
  elseif maxVerse and xml.tag == "verse-section" then
    counter = counter + 1
    if counter > maxVerse then
      return ""
    end
  end
  if not xml.tag then
    for a, b in pairs(xml) do
      if type(b) == "table" then print(a, b.tag)
      else print(a, b)
      end
    end
  end
  local str = "<"..xml.tag..getAttr(xml.attr)
  if (#xml == 0) then
    return str.." />"
  end
  str = str..">"
  for i, child in ipairs(xml) do
    str = str..base.deparse(child, maxChap, maxVerse)
  end
  str = str.."</"..xml.tag..">"
  return str
end

return base