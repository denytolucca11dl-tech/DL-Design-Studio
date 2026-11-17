# frozen_string_literal: true
require 'sketchup.rb'
require 'json'

module DLDesignStudio
  VERSION = '0.2.0'
  ROOT = File.dirname(__FILE__)
  @dialog = nil

  def self.open_panel
    if @dialog && @dialog.visible?
      @dialog.bring_to_front
      return
    end

    @dialog = UI::HtmlDialog.new(
      dialog_title: 'DL Design Studio',
      preferences_key: 'dl_design_studio_main',
      scrollable: true,
      resizable: true,
      width: 940,
      height: 760,
      min_width: 760,
      min_height: 600,
      style: UI::HtmlDialog::STYLE_DIALOG
    )
    @dialog.set_file(File.join(ROOT, 'ui', 'index.html'))

    @dialog.add_action_callback('get_selection_info') do |_context|
      model = Sketchup.active_model
      selection = model.selection
      @dialog.execute_script("window.DLStudio && window.DLStudio.updateSelection(#{selection_info(selection).to_json})")
    end

    @dialog.add_action_callback('analyze_round_corner') do |_context, settings_json|
      begin
        settings = JSON.parse(settings_json || '{}')
        model = Sketchup.active_model
        selection = model.selection
        mode = settings['mode'] == 'object' ? 'object' : 'manual'
        kind = settings['kind'] == 'chamfer' ? 'chamfer' : 'round'
        radius = Float(settings['radius_mm'])
        segments = Integer(settings['segments'])
        errors = []
        errors << 'Informe um raio maior que zero.' unless radius.positive?
        errors << 'Use entre 1 e 24 segmentos.' unless (1..24).cover?(segments)
        edges = selection.grep(Sketchup::Edge)
        objects = selection.grep(Sketchup::Group) + selection.grep(Sketchup::ComponentInstance)
        if mode == 'manual'
          errors << 'Selecione uma ou mais arestas no modelo.' if edges.empty?
        else
          errors << 'Selecione um grupo ou componente.' if objects.empty?
        end
        
        if mode == 'object' && objects.length == 1
          validation = validate_rectangular_block(objects.first)
          errors << validation[:message] unless validation[:valid]
        end

        summary = {
          valid: errors.empty?, mode: mode, kind: kind, radius_mm: radius,
          segments: segments, selected_edges: edges.length,
          selected_objects: objects.length,
          message: errors.empty? ? 'Seleção válida. A análise foi concluída; a geração da geometria será habilitada na próxima etapa.' : errors.join(' ')
        }
        @dialog.execute_script("window.DLStudio && window.DLStudio.showRoundAnalysis(#{summary.to_json})")
      rescue StandardError => e
        @dialog.execute_script("window.DLStudio && window.DLStudio.showRoundAnalysis(#{ { valid: false, message: "Não foi possível analisar: #{e.message}" }.to_json })")
      end
    end

    @dialog.add_action_callback('show_module') do |_context, module_name|
      labels = {
        'roof' => 'DL Roof Generator', 'timber' => 'DL Timber',
        'cladding' => 'DL Cladding', 'materials' => 'DL Materials',
        'detailing' => 'DL Detailing'
      }
      label = labels[module_name.to_s] || 'Módulo'
      UI.messagebox("#{label}\n\nEste módulo será desenvolvido nas próximas etapas. Nenhuma geometria foi alterada.")
    end

    @dialog.show
  end
  def self.radius_to_inches(radius_mm)
    radius_mm.to_f.mm
  end
  
  
  def self.validate_rectangular_block(object)
    unless object.is_a?(Sketchup::Group)
      return {
        valid: false,
        message: 'Selecione um grupo retangular.'
      }
    end

    entities = object.entities
    faces = entities.grep(Sketchup::Face)
    edges = entities.grep(Sketchup::Edge)

    unless faces.length == 6 && edges.length == 12
      return {
        valid: false,
        message: 'O bloco precisa ter 6 faces e 12 arestas.'
      }
    end

    unless faces.all? { |face|
      face.loops.length == 1 &&
      face.outer_loop.vertices.length == 4
    }
      return {
        valid: false,
        message: 'Todas as faces precisam ter 4 lados.'
      }
    end

    tolerance = 0.001

    rectangular = faces.all? do |face|
      vertices = face.outer_loop.vertices.map(&:position)

      vectors = 4.times.map do |i|
        vertices[i].vector_to(vertices[(i + 1) % 4])
      end

      vectors.all? { |v| v.length > tolerance } &&
        4.times.all? do |i|
          a = vectors[i].normalize
          b = vectors[(i + 1) % 4].normalize
          a.dot(b).abs < tolerance
        end
    end

    unless rectangular
      return {
        valid: false,
        message: 'O bloco possui faces fora de esquadro.'
      }
    end

    {
      valid: true,
      message: 'Bloco retangular aprovado na validação inicial.'
    }
  end


 
  def self.selection_info(selection)
    {
      total: selection.length,
      faces: selection.grep(Sketchup::Face).length,
      edges: selection.grep(Sketchup::Edge).length,
      groups: selection.grep(Sketchup::Group).length,
      components: selection.grep(Sketchup::ComponentInstance).length
    }
  end

  unless file_loaded?(__FILE__)
    menu = UI.menu('Extensions').add_submenu('DL Design Studio')
    menu.add_item('Abrir painel') { self.open_panel }
    toolbar = UI::Toolbar.new('DL Design Studio')
    command = UI::Command.new('DL Design Studio') { self.open_panel }
    command.tooltip = 'Abrir DL Design Studio'
    command.status_bar_text = 'Abre o painel principal do DL Design Studio'
    toolbar.add_item(command)
    toolbar.restore
    file_loaded(__FILE__)
  end
end
