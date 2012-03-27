require File.dirname(__FILE__) + '/lib/jinx/version'
require 'date'

Gem::Specification.new do |s|
  s.name          = 'jinx'
  s.summary       = 'Jruby INtrospeXion facade.'
  s.description   = s.summary + '. See github.com/jinx/core for more information.'
  s.version       = Jinx::VERSION
  s.date          = Date.today
  s.author        = 'OHSU'
  s.email         = 'jinx.ruby@gmail.com'
  s.homepage      = 'http://github.com/jinx/core'
  s.require_path  = 'lib'
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files test`.split("\n")
  s.add_runtime_dependency     'bundler'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '~> 2.8.0'
  s.has_rdoc      = 'yard'
  s.license       = 'MIT'
  s.rubyforge_project = 'caruby'
end
