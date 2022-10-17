# frozen_string_literal: true

require_relative "lib/mudraa/version"

Gem::Specification.new do |spec|
  spec.name = "mudraa"
  spec.version = Mudraa::VERSION
  spec.authors = ["Abhimanyu-1855"]
  spec.email = ["abhimanyu@cogoport.com"]

  spec.summary = "Collection Party"
  spec.required_ruby_version = ">= 2.6.8"
  spec.files = Dir.glob(File.join('lib', '**', '*.rb'))
  spec.add_dependency "activerecord"
end
