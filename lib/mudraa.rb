# frozen_string_literal: true


Dir.glob(File.join( '**', '*.rb'), base: 'lib').each do |file|
  require file
end

module Mudraa
  class Error < StandardError; end
  
end
