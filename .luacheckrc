-- Checks documentation:
-- https://luacheck.readthedocs.io/en/stable/warnings.html

stds.ucm = {
  read_globals = {
    'inspect',
    enapter = {
      fields = {
        'log',
        'send_properties',
        'send_telemetry',
        'register_command_handler',
        'on_connection_status_changed',
        'get_connection_status',
        'err_to_str',
      },
    },
    ucm = {
      fields = { 'new' },
    },
    storage = {
      fields = { 'read', 'write', 'remove', 'err_to_str' },
    },
    scheduler = {
      fields = { 'add', 'remove' },
    },
    led = {
      fields = { 'on', 'off', 'blink' },
    },
    modbus = {
      fields = {
        'read_coils',
        'read_discrete_inputs',
        'read_holdings',
        'read_inputs',
        'write_coil',
        'write_holding',
        'write_multiple_coils',
        'write_multiple_holdings',
        'err_to_str',
      },
    },
    rs232 = {
      fields = { 'init', 'send', 'receive', 'err_to_str' },
    },
    rs485 = {
      fields = { 'init', 'send', 'receive', 'err_to_str' },
    },
    can = {
      fields = { 'init', 'send', 'err_to_str' },
    },
    rl6 = {
      fields = {
        'get',
        'open',
        'close',
        'impulse',
        'open_all',
        'close_all',
        'set_all',
        'err_to_str',
      },
    },
    ai4 = {
      fields = { 'read_volts', 'read_milliamps', 'err_to_str' },
    },
    di7 = {
      fields = {
        'is_closed',
        'is_opened',
        'read_counter',
        'set_counter',
        'set_debounce',
        'err_to_str',
      },
    },
    rl = {
      fields = {
        'is_closed',
        'open',
        'close',
        'impulse',
      },
    },
  },
}

stds.vucm = {
  read_globals = {
    modbustcp = {
      fields = { 'new', 'err_to_str' },
    },
    http = {
      fields = { 'get', 'post', 'post_form', 'client', 'request' },
    },
  },
}

-- assignments to globals in the top level function scope
-- (also known as main chunk) define them and does not trigger
-- "undefined global" warning
allow_defined_top = true

std = 'lua53+ucm+vucm'

ignore = {
  -- allow unused `self` in OOP-style functions
  '212/self',
  -- allow unused variables prefixed with underscore
  '212/_.*',
  -- allow to re-define and shadow common error-checking
  -- and result variables
  '411/ok',
  '411/err',
  '411/result',
  '411/data',
  '421/ok',
  '421/err',
  '421/result',
  '421/data',
}
