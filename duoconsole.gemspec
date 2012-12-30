Gem::Specification.new do |s|
  s.name    = 'duoconsole'
  s.version = '0.1.2'
  s.author  = 'Geoff Buesing'
  s.email   = 'gbuesing@gmail.com'
  s.summary = 'Launch Rails development console with test environment as a child process'
  s.license = 'MIT'
  s.homepage = 'https://github.com/gbuesing/duoconsole'

  s.executables << 'duoconsole'

  s.add_dependency 'rails', '>= 3.2.0'
  s.add_dependency 'commands', '>= 0.2.1'

  s.files = Dir['lib/**/*.rb'] + Dir['bin/*']
end