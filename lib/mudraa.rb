# frozen_string_literal: true


Dir.glob(File.join( '**', '*.rb'), base: 'lib').each {|file| require file }

module Mudraa
  class Error < StandardError; end
  
end
