rockspec_format = '3.0'
package = 'generic-can'
version = 'dev-1'
source = {
  url = 'developers.enapter.com'
}
dependencies = {
  'lua ~> 5.3',
  'enapter-ucm ~> 0.2.3-1',
}
test_dependencies = {
  'enapter-ucm ~> 0.2.3-1',
}
test = {
  type = 'busted',
}
