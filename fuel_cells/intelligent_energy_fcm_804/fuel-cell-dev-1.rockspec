rockspec_format = '3.0'
package = 'fuel-cell'
version = 'dev-1'
source = {
  url = 'developers.enapter.com'
}
dependencies = {
  'lua ~> 5.3',
  'enapter-ucm ~> 0.3.2-1',
}
test_dependencies = {
  'inspect',
  'enapter-ucm ~> 0.3.2-1',
}
test = {
  type = 'busted',
}
