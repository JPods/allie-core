require 'json'

# ── JPods Station Names Dialog ─────────────────────────────────────────────────
#
# Standalone dialog for assigning friendly display names to each station.
# Names are stored as 'station_name' entity attributes on ComponentInstances
# and read by the Trip Simulator phone app.
#
# Opened via: Plugins > JPods > Station Names…

module JPods
  module StationNamesDialog

    DIALOG_HTML = <<~HTML.freeze
      <!DOCTYPE html>
      <html>
      <head>
      <meta charset="UTF-8">
      <style>
        *{box-sizing:border-box;margin:0;padding:0}
        body{
          background:#1e1e1e;color:#d4d4d4;
          font:13px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
          padding:14px 16px 16px;
        }
        h2{
          font-size:13px;font-weight:600;letter-spacing:0.07em;
          text-transform:uppercase;color:#888;margin-bottom:12px;
        }
        table{width:100%;border-collapse:collapse}
        th{
          font-size:11px;font-weight:600;text-transform:uppercase;
          letter-spacing:0.06em;color:#666;
          padding:4px 8px 6px;text-align:left;
          border-bottom:1px solid #333;
        }
        td{padding:5px 8px;border-bottom:1px solid #2a2a2a;vertical-align:middle}
        .sid{
          font-family:'SF Mono','Consolas',monospace;
          font-size:12px;color:#ce9178;white-space:nowrap;width:70px;
        }
        input{
          width:100%;background:#252526;color:#d4d4d4;
          border:1px solid #3c3c3c;border-radius:4px;
          padding:5px 8px;font-size:13px;font-family:inherit;
          outline:none;
        }
        input:focus{border-color:#0e639c}
        input.dirty{border-color:#d4a800}
        #status{
          font-size:12px;color:#888;margin-top:10px;min-height:18px;
        }
        #status.ok{color:#4ec9b0}
        #status.err{color:#f44747}
        #empty{
          color:#555;font-style:italic;font-size:13px;
          padding:20px 8px;text-align:center;
        }
        .footer{
          display:flex;align-items:center;justify-content:space-between;
          margin-top:12px;
        }
        button{
          background:#0e639c;color:#fff;border:none;border-radius:4px;
          padding:7px 18px;font-size:13px;font-weight:600;cursor:pointer;
        }
        button:hover{background:#1177bb}
        button:active{background:#0d5789}
      </style>
      </head>
      <body>
      <h2>Station Names</h2>
      <div id="content">
        <div id="empty">Loading stations…</div>
      </div>
      <div class="footer">
        <span id="status"></span>
        <button id="save-btn" onclick="save()" style="display:none">Save Names</button>
      </div>

      <script>
        function mark(inp){ inp.classList.add('dirty'); }

        function populate(stations) {
          const content = document.getElementById('content');
          if (!stations || stations.length === 0) {
            content.innerHTML =
              '<div id="empty">No stations found — place stations and run Build first.</div>';
            return;
          }
          let html = '<table><thead><tr><th>Station</th><th>Friendly Name</th></tr></thead><tbody>';
          stations.forEach(s => {
            const sid  = (s.id   || '').replace(/</g,'&lt;');
            const name = (s.name || '').replace(/</g,'&lt;').replace(/"/g,'&quot;');
            html += `<tr>
              <td class="sid">${sid}</td>
              <td><input id="inp_${sid}" value="${name}"
                   placeholder="friendly name…"
                   oninput="mark(this)"></td>
            </tr>`;
          });
          html += '</tbody></table>';
          content.innerHTML = html;
          document.getElementById('save-btn').style.display = '';
        }

        function save() {
          const inputs = document.querySelectorAll('input[id^="inp_"]');
          const names = {};
          inputs.forEach(inp => {
            const sid = inp.id.replace(/^inp_/, '');
            names[sid] = inp.value.trim();
          });
          sketchup.sn_save(JSON.stringify(names));
          inputs.forEach(inp => inp.classList.remove('dirty'));
        }

        function showStatus(msg, type) {
          const el = document.getElementById('status');
          el.textContent = msg;
          el.className = type || '';
          if (type === 'ok') setTimeout(() => { el.textContent = ''; el.className = ''; }, 3000);
        }

        // Called by Ruby after save
        window.snSaved  = function(n) { showStatus(n + ' name(s) saved.', 'ok'); };
        window.snError  = function(m) { showStatus('Error: ' + m, 'err'); };
        // Called by Ruby on load
        window.snLoad   = function(stations) { populate(stations); };
      </script>
      </body>
      </html>
    HTML

    @dialog = nil

    def self.open(model = nil)
      model ||= Sketchup.active_model

      if @dialog && @dialog.visible?
        refresh(model)
        @dialog.bring_to_front
        return
      end

      @dialog = UI::HtmlDialog.new(
        dialog_title:    'JPods — Station Names',
        preferences_key: 'jpods_station_names',
        scrollable:      true,
        resizable:       true,
        width:           420,
        height:          440,
        min_width:       300,
        min_height:      200,
        style:           UI::HtmlDialog::STYLE_DIALOG,
      )

      @dialog.set_html(DIALOG_HTML)
      register_callbacks(@dialog, model)
      @dialog.show

      # Push station data once the page is ready (small delay for DOM)
      UI.start_timer(0.3, false) { refresh(model) }
    end

    # ── Push current station list to the dialog ──────────────────────────────

    def self.refresh(model = nil)
      return unless @dialog && @dialog.visible?
      model ||= Sketchup.active_model
      stations = collect_stations(model)
      json = stations.to_json
      @dialog.execute_script("window.snLoad && window.snLoad(#{json})")
    rescue => e
      puts "[JPods StationNames] refresh error: #{e.message}"
    end

    # ── Collect [{id, name}] from entity attrs + followme.json fallback ──────

    def self.collect_stations(model)
      # Step 1: entity attribute scan
      seen = {}
      result = []
      (model.entities.grep(Sketchup::ComponentInstance) rescue []).each do |e|
        sid  = (e.get_attribute('JPods', 'structure_id', '') rescue '').to_s
        next if sid.empty? || seen[sid]
        seen[sid] = true
        name = (e.get_attribute('JPods', 'station_name', '') rescue '').to_s
        result << { id: sid, name: name }
      end
      result.sort_by! { |s| s[:id] }
    rescue
      []
    end

    # ── Callbacks ─────────────────────────────────────────────────────────────

    def self.register_callbacks(dlg, model)

      dlg.add_action_callback('sn_save') do |_ctx, json|
        begin
          names = JSON.parse(json.to_s)
          saved = 0
          (model.entities.grep(Sketchup::ComponentInstance) rescue []).each do |e|
            sid = (e.get_attribute('JPods', 'structure_id', '') rescue '').to_s
            next if sid.empty? || !names.key?(sid)
            val = names[sid].to_s.strip
            e.set_attribute('JPods', 'station_name', val)
            saved += 1
          end
          # Also write to network.json so Build picks them up
          model_dir  = File.dirname(model.path.to_s)
          model_base = File.basename(model.path.to_s, '.*')
          nj_path = File.join(model_dir, "#{model_base}.network.json")
          if File.exist?(nj_path)
            nj = JSON.parse(File.read(nj_path, encoding: 'utf-8'))
            nj['station_names'] = (nj['station_names'] || {}).merge(names)
            File.write(nj_path, JSON.pretty_generate(nj), encoding: 'utf-8')
          end
          puts "[JPods StationNames] saved #{saved} name(s)"
          dlg.execute_script("window.snSaved && window.snSaved(#{saved})")
        rescue => e
          puts "[JPods StationNames] save error: #{e.message}"
          dlg.execute_script("window.snError && window.snError(#{e.message.to_json})")
        end
      end

    end

  end
end
