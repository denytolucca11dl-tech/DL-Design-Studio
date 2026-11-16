# frozen_string_literal: true
# DL Design Studio - loader
require 'sketchup.rb'
require 'extensions.rb'

module DLDesignStudio
  unless file_loaded?(__FILE__)
    extension = SketchupExtension.new('DL Design Studio', 'dl_design_studio/main')
    extension.description = 'Ferramentas de modelagem, materiais e detalhamento para SketchUp.'
    extension.version = '0.2.0'
    extension.creator = 'DL Design Studio'
    extension.copyright = '2026'
    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end
