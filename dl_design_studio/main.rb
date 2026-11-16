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
