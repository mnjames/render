local insertions = SILE.require("packages/insertions")

SILE.registerCommand("ssv-lit", function(options, content)
  -- SILE.settings.set("typesetter.parseppattern", -1)
  local opts = SILE.scratch.insertions.classes["ssv-lit"]
  local f = SILE.getFrame(opts["insertInto"].frame)
  local oldT = SILE.typesetter
  SILE.typesetter = SILE.typesetter {}
  SILE.typesetter:init(f)
  -- SILE.typesetter.pageTarget = function () return 0xFFFFFF end
  SILE.settings.pushState()
  SILE.settings.reset()
  local material = SILE.Commands["vbox"]({}, function()
    SILE.call("urdu:font")
    SILE.process(content)
    -- SILE.Commands["urdu:font"]({}, function()
    --   -- SILE.call("footnote:atstart", options)
    --   -- SILE.call("footnote:counter", options)
    --   SILE.process(content)
    -- end)
  end)
  SILE.settings.popState()
  SILE.typesetter = oldT
  insertions.exports:insert("ssv-lit", material)
end)

return {
  init = function (class, args)
    insertions.exports:initInsertionClass("ssv-lit", {
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