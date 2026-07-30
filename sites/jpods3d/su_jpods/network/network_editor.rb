# ── NetworkEditor v2 — slim JSON I/O for console and project ──────────────────
#
# Migrated from codearchive/jpod_network_editor.rb (2520 lines → ~120 lines).
# The old file was a full HTML dialog + JSON editor + UI binding.
# v2 keeps only the methods that console, project, and structure_tool call.

require 'json'

module JPods
  module NetworkEditor

    # ── Path delegation to Project ─────────────────────────────────────────
    def self.default_network_json_path(model)
      JPods::Project.default_network_json_path(model)
    end

    def self.default_json_path(model)
      JPods::Project.default_json_path(model)
    end

    # ── JSON read/write ────────────────────────────────────────────────────
    def self.load_network_definition_from_path(path)
      return {} unless path && File.exist?(path)
      JSON.parse(File.read(path, encoding: 'utf-8'))
    rescue => ex
      puts "[NetworkEditor] load error: #{ex.message}"
      {}
    end

    def self.save_network_definition_to_path(path, data)
      return unless path && data
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(data), encoding: 'utf-8')
      puts "[NetworkEditor] saved → #{File.basename(path)}"
    rescue => ex
      puts "[NetworkEditor] save error: #{ex.message}"
    end

    @@console_dialog = nil

    def self.set_console_dialog(dialog)
      @@console_dialog = dialog
    end

    def self.push_network_json(model_or_data, path = nil)
      return unless @@console_dialog
      begin
        # Re-read from disk and push to iframe
        if path && File.exist?(path)
          nd = load_network_definition_from_path(path)
          if nd['connections'].is_a?(Hash)
            flat = feature_connections_to_flat_array(nd['connections'])
            nd_for_iframe = nd.dup
            nd_for_iframe['connections'] = flat.map { |e|
              { 'id' => e['connection_id'],
                'from' => e['from'], 'to' => e['to'],
                'via_markers' => e['via_markers'] || [] }
            }.uniq { |c| c['id'] }
            nd_text = JSON.pretty_generate(nd_for_iframe)
          else
            nd_text = JSON.pretty_generate(nd)
          end
          @@console_dialog.execute_script("loadNetworkEditorContent(#{nd_text.to_json}, #{path.to_json})")
        end
      rescue => ex
        puts "[NetworkEditor] push error: #{ex.message}"
      end
    end

    # ── Feature connections ────────────────────────────────────────────────
    # Read connections from network.json, push to console dialog's network editor iframe.
    # The iframe exposes addConnection(fromStructId, fromStub, toStructId, toStub, connId, viaMarkers)
    def self.push_feature_connections(model, dialog)
      return unless model && dialog
      path = default_network_json_path(model) rescue nil
      return unless path && File.exist?(path)
      data = load_network_definition_from_path(path)
      conns = data['connections'] || {}
      flat = feature_connections_to_flat_array(conns)

      # Push each connection to the network editor iframe via addConnection()
      flat.each do |entry|
        from_sid  = entry.dig('from', 'structure_id').to_s
        from_stub = entry.dig('from', 'stub').to_i
        to_sid    = entry.dig('to', 'structure_id').to_s
        to_stub   = entry.dig('to', 'stub').to_i
        conn_id   = entry['connection_id'].to_s
        via       = (entry['via_markers'] || []).to_json

        js = "var frame = document.getElementById('network-editor-iframe'); " \
             "if (frame && frame.contentWindow && frame.contentWindow.addConnection) { " \
             "frame.contentWindow.addConnection(#{from_sid.to_json}, #{from_stub}, #{to_sid.to_json}, #{to_stub}, #{conn_id.to_json}, #{via}); }"
        dialog.execute_script(js) rescue nil
      end

      puts "[NetworkEditor] pushed #{flat.size} connection(s) to console"
    end

    # Convert nested connections hash to flat array for console display
    def self.feature_connections_to_flat_array(conns)
      return [] unless conns.is_a?(Hash)
      result = []
      conns.each do |conn_key, conn_data|
        next unless conn_data.is_a?(Hash)
        via = conn_data['via_markers'] || []
        conn_data.each do |seg_id, seg_data|
          next if seg_id == 'via_markers'
          next unless seg_data.is_a?(Hash) && seg_data['from'].is_a?(Hash)
          result << {
            'connection_id' => conn_key,
            'segment_id'    => seg_id,
            'from'          => seg_data['from'],
            'to'            => seg_data['to'],
            'via_markers'   => via,
          }
        end
      end
      result
    end

    def self.flat_array_to_feature_connections(flat)
      result = {}
      flat.each do |entry|
        cid = entry['connection_id']
        result[cid] ||= {}
        result[cid]['via_markers'] = entry['via_markers'] if entry['via_markers']
        result[cid][entry['segment_id']] = {
          'from' => entry['from'], 'to' => entry['to']
        }
      end
      result
    end

    # ── UI actions ─────────────────────────────────────────────────────────
    def self.show_in_finder_or_organize(model)
      dir = JPods::Project.project_dir(model) rescue nil
      if dir && File.directory?(dir)
        UI.openURL("file://#{dir}")
      end
    end

    def self.launch_organize_script(model, candidates, dest_dir)
      # Delegate to Project if available
      if defined?(JPods::Project) && JPods::Project.respond_to?(:launch_organize_script)
        JPods::Project.launch_organize_script(model, candidates, dest_dir)
      end
    end

    # ── Dialog lifecycle ───────────────────────────────────────────────────
    def self.close
      # No-op — v2 doesn't have a separate NetworkEditor dialog
    end

    def self.delete_connection(model, conn_id)
      path = default_network_json_path(model) rescue nil
      return unless path && File.exist?(path)
      data = load_network_definition_from_path(path)
      conns = data['connections'] || {}
      had = conns.key?(conn_id)
      conns.delete(conn_id)
      puts "[NetworkEditor] delete_connection: #{conn_id} #{had ? 'REMOVED' : 'NOT FOUND'} — #{conns.size} remaining"
      save_network_definition_to_path(path, data)
    end

  end
end
