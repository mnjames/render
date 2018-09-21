local insertions = SILE.require("packages/insertions")

SILE.registerCommand("interlinear", function(options, content)
  SILE.scratch.trisection.counter = SILE.scratch.trisection.counter + 1
  -- SILE.settings.set("typesetter.parseppattern", -1)
  local opts = SILE.scratch.insertions.classes.interlinear
  local f = SILE.getFrame(opts["insertInto"].frame)
  local oldT = SILE.typesetter
  SILE.typesetter = SILE.typesetter {}
  SILE.typesetter:init(f)
  -- SILE.typesetter.pageTarget = function () return 0xFFFFFF end
  SILE.settings.pushState()
  SILE.settings.reset()
  -- local material
  -- SILE.settings.temporarily(function ()
  --   SILE.call("urdu:font")
  --   SILE.process(content)
  --   material = SILE.nodefactory.newUnshaped{nodes = {}}
  --   material:append(SILE.typesetter.state.outputQueue)
  -- end)
  local material = SILE.Commands["vbox"]({}, function()
    -- SILE.call("urdu:font")
    SILE.call("font", {
      family = "Times New Roman",
      size = "14pt"
    })
    SILE.process(content)
    -- SILE.Commands["urdu:font"]({}, function()
    --   -- SILE.call("footnote:atstart", options)
    --   -- SILE.call("footnote:counter", options)
    --   SILE.process(content)
    -- end)
  end)
  SILE.settings.popState()
  SILE.typesetter = oldT
  insertions.exports:insert("interlinear", material)
end)

SILE.registerCommand("item", function (options, content)
  -- SILE.call("ruby", {reading = options.vernacular}, options.greek)
  SILE.typesetter:typeset(options.greek.." ")
  SILE.call("font", {
    family = "Awami Nastaliq",
    size = "12pt",
    language = "urd",
    script = "Arab"
  }, function ()
    SILE.typesetter:typeset("("..options.vernacular..")")
  end)
  SILE.typesetter:typeset(" ")
end)

return {
  init = function (class, args)
    insertions.exports:initInsertionClass("interlinear", {
    insertInto = args.insertInto,
    stealFrom = args.stealFrom,
    maxHeight = SILE.length.new({length = SILE.toPoints("75", "%ph") }),
    topBox = SILE.nodefactory.newVglue({height = SILE.length.parse("2ex") }),
    interInsertionSkip = SILE.length.parse("1ex"),
  })
  end,
  exports = {
    outputInsertions = insertions.exports.outputInsertions
  }
}