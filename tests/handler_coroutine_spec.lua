local spy = require "luassert.spy"
local HandlerCoroutine = require("typescript-tools.protocol.utils").HandlerCoroutine

describe("HandlerCoroutine", function()
  local proxy_spy = spy.new(function(x)
    return x
  end)
  local function test_handler()
    local sum = 0

    sum = sum + proxy_spy(coroutine.yield())
    sum = sum + proxy_spy(coroutine.yield())
    sum = sum + proxy_spy(coroutine.yield())

    return sum
  end

  before_each(function()
    proxy_spy:clear()
  end)

  it("should correctly call underlaying function", function()
    local handler = HandlerCoroutine:new(test_handler)

    handler(1)
    assert.spy(proxy_spy).was.called_with(1)

    handler(2)
    assert.spy(proxy_spy).was.called_with(2)

    handler(3)
    assert.spy(proxy_spy).was.called_with(3)
    assert.spy(proxy_spy).was.called(3)
  end)

  it("should correctly return from function", function()
    local handler = HandlerCoroutine:new(test_handler)

    handler(1)
    handler(2)
    local ret = handler(3)

    assert.spy(proxy_spy).was.called(3)
    assert.same(ret, 6)
  end)

  it("should correctly revive after return", function()
    local function mock_handler()
      proxy_spy()
    end

    local handler = HandlerCoroutine:new(mock_handler)

    handler()
    handler()

    assert.spy(proxy_spy).was.called(2)
  end)

  it("should return correct status of underlaying coroutine", function()
    local handler = HandlerCoroutine:new(test_handler)

    handler(1)
    assert.same(handler:status(), "suspended")
    handler(2)
    assert.same(handler:status(), "suspended")
    handler(3)
    assert.same(handler:status(), "dead")

    assert.spy(proxy_spy).was.called(3)
  end)
end)
