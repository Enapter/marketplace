local app

describe('app', function()
  before_each(function()
    _G.enapter = {
      register_command_handler = function() end,
    }
    package.loaded['app'] = false
    app = require('app').new()
  end)

  after_each(function()
    _G.enapter = nil
  end)

  it('should have valid config options', function()
    local config = require('enapter.ucm.config')
    assert.has_no_error(function()
      config.init(app.config)
    end)
  end)
end)
