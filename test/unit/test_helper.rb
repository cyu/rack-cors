require 'minitest/autorun'
require 'minitest/reporters'
require 'rack/cors'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
