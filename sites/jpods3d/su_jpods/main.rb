require 'sketchup.rb'

begin
  puts "[JPods main.rb] NetworkEditor.close at file load start"
  JPods::NetworkEditor.close if defined?(JPods::NetworkEditor) && JPods::NetworkEditor.respond_to?(:close)
rescue
end

# Guard against double-loading. Note: `return` at top level of a load'd file
# raises LocalJumpError in Ruby, so we use unless/end to wrap the whole body.
unless $jpods_main_loaded
$jpods_main_loaded = true

# Install logger first so all plugin output is captured to JPods logs and UI.
begin
  load File.join(__dir__, 'jpod_logging.rb')
  JPods::Logging.install! if defined?(JPods::Logging)
rescue => e
  puts "JPods logging install warning: #{e.message}"
end

# ── Module loading ────────────────────────────────────────────────────────────
# boot.rb is the authority for module loading (v4.0).
# This old load list has been removed — all modules load from boot.rb.

end # unless $jpods_main_loaded

# ── Register menus and toolbar (once per session) ─────────────────────────────
# Runs every time main.rb is loaded; $jpods_registered guards against duplicates.
module JPods

  # Use a separate global for the one-time menu/observer registration block
  # (distinct from $jpods_main_loaded which guards the module load loop above).
  unless $jpods_registered
    $jpods_registered = true

    # ── Plugin menu — mirrors toolbar order ────────────────────────────────
    jpods_menu = UI.menu("Plugins").add_submenu("JPods")
    jpods_menu.add_item("JPods Console") {
      JPods::Console.open(Sketchup.active_model) rescue nil
    }
    jpods_menu.add_item("Show Toolbar") {
      tb = UI::Toolbar.new("JPods")
      tb.restore
      tb.show if tb.respond_to?(:show)
    }
    jpods_menu.add_separator
    jpods_menu.add_item("Place Structure…") {
      JPods::JPodStructureTool.activate_with_prompt(Sketchup.active_model) rescue nil
    }
    jpods_menu.add_item("Name Stations…") {
      JPods::StationNamesDialog.open(Sketchup.active_model) rescue nil
    }
    jpods_menu.add_item("CP Calculate") {
      model = Sketchup.active_model
      if model && defined?(JPods::StructurePlacer)
        if JPods::StructurePlacer.cps_shown?
          JPods::StructurePlacer.hide_all_cp_labels(model)
          model.select_tool(nil)
        else
          JPods::StructurePlacer.purge_phantoms(model)
          JPods::StructurePlacer.recompute_all_cps(model)
          JPods::StructurePlacer._show_cp_circles(model)
          model.select_tool(JPods::JPodConnectTool.new) rescue nil unless model.path.to_s.include?('track_formations')
        end
      end
    }
    jpods_menu.add_item("Populate (toggle)") {
      # Same as toolbar Populate toggle
    }
    jpods_menu.add_item("Travel…") {
      JPods::Console.open_travel(Sketchup.active_model) rescue nil
    }
    jpods_menu.add_item("Camera (toggle)") {
      # Same as toolbar Camera toggle
    }
    jpods_menu.add_separator
    anim_menu = jpods_menu.add_submenu("Animation")
    anim_menu.add_item("Start / Resume") {
      if defined?(JPods::AnimationV2) && JPods::AnimationV2.paused?
        JPods::AnimationV2.resume rescue nil
        puts "[JPods] Resume Animation (menu)"
      else
        JPods::JPodGuideway.start_animation(Sketchup.active_model) rescue nil
        puts "[JPods] Start Animation (menu)"
      end
    }
    anim_menu.add_item("Freeze") {
      JPods::AnimationV2.pause rescue nil
      puts "[JPods] Freeze Animation (menu)"
    }
    anim_menu.add_item("High Frequency Dispatch") {
      JPods::JPodVehicleAnim.toggle_random_high_freq if defined?(JPods::JPodVehicleAnim)
    }
    jpods_menu.add_separator
    jpods_menu.add_item("Crew Health Check") {
      JPods::CrewHealth.check(Sketchup.active_model) rescue nil
    }
    jpods_menu.add_separator
    jpods_menu.add_item("Console2") {
      JPods::Console2.open(Sketchup.active_model) rescue nil
    }
    jpods_menu.add_item("Note…") {
      input = UI.inputbox(["Note:"], [""], "JPods — Note")
      next unless input
      JPods._save_note(nil, input[0].to_s)
    }

    # ── Comment mode ─────────────────────────────────────────────────────────
    # @@note_mode: when true, the next toolbar button click captures a comment
    # before executing its action. The button name is automatically recorded —
    # the user only supplies the reason.
    @@note_mode = false

    # _note_context — collect auto-captured fields for a note.
    def self._note_context
      m = Sketchup.active_model
      {
        model: (m && m.path && !m.path.empty?) ? File.basename(m.path, '.skp') : 'unknown',
        state: (defined?(JPods::JPodVehicleAnim) && JPods::JPodVehicleAnim.running?) ?
               'animating' : 'idle'
      }
    end

    # _save_note — write note to Allie inbox and commit.
    # action: name of the button that was clicked (nil for freestanding notes).
    # comment: user's text.
    def self._save_note(action, comment)
      return if comment.to_s.strip.empty?
      ctx     = _note_context
      ts_utc  = Time.now.utc
      ts_str  = ts_utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      ts_file = ts_utc.strftime('%Y%m%dT%H%M%S')

      lines  = ["# NOTE — #{ts_str}\n"]
      lines << "model:    #{ctx[:model]}\n"
      lines << "state:    #{ctx[:state]}\n"
      lines << "action:   #{action}\n" if action
      lines << "comment:  #{comment.strip}\n"
      body = lines.join

      inbox = File.expand_path('~/Allie/process/inbox')
      if Dir.exist?(inbox)
        path = File.join(inbox, "#{ts_file}-note.md")
        File.write(path, body)
        puts "[JPods Note] #{action || 'freestanding'}: #{comment.strip[0, 80]}"
        begin
          allie = File.expand_path('~/Allie')
          msg   = "NOTE #{ts_str}: [#{action || 'note'}] #{comment.strip[0, 50]}"
          system('git', '-C', allie, 'add', path)
          system('git', '-C', allie, 'commit', '-m', msg)
        rescue => _e
        end
      else
        puts "[JPods Note] (no inbox) #{action}: #{comment.strip}"
      end
    end

    # _note_before_action — if comment mode is on, capture a note tied to the
    # named action and clear the mode flag. Returns true if note was saved or
    # mode was off (caller should always proceed with the action). Returns false
    # only if the user cancelled the input dialog — caller should abort action.
    def self._note_before_action(action_name)
      return true unless @@note_mode
      @@note_mode = false
      input = UI.inputbox(["Why (#{action_name}):"], [""], "JPods — Note Before Action")
      return false unless input   # user pressed Cancel — abort action
      _save_note(action_name, input[0].to_s)
      true
    end

    # ── Toolbar ───────────────────────────────────────────────────────────────
    # Order: Console → Place → CP Calculate → Populate → Trip Sim → Camera → Animate → Note
    unless defined?(@@jpods_toolbar_registered) && @@jpods_toolbar_registered
      @@jpods_toolbar_registered = true
      icon_dir = File.join(__dir__, "toolbar_icons")

      tb = UI::Toolbar.new("JPods")

      # 1. JPods Console
      cmd_console = UI::Command.new("JPods Console") {
        JPods::Console.open(Sketchup.active_model) rescue nil
      }
      cmd_console.large_icon = File.join(icon_dir, "console.png")
      cmd_console.small_icon = File.join(icon_dir, "console_small.png")
      cmd_console.tooltip    = "JPods Console"
      cmd_console.status_bar_text = "Open the JPods Console"
      tb.add_item(cmd_console)

      # 2. Place Structure
      cmd_structure = UI::Command.new("Place Structure") {
        next unless JPods._note_before_action("Place Structure")
        JPods::JPodStructureTool.activate_with_prompt(Sketchup.active_model) rescue nil
      }
      cmd_structure.large_icon = File.join(icon_dir, "place_station.png")
      cmd_structure.small_icon = File.join(icon_dir, "place_station_small.png")
      cmd_structure.tooltip    = "Place Structure"
      cmd_structure.status_bar_text = "Place a station or traffic circle on terrain"
      tb.add_item(cmd_structure)

      # Name Stations — moved to Network Display panel (no toolbar button)

      # 4. CP Calculate — shows CPs and activates Connect tool (W key for waypoints)
      cmd_cp = UI::Command.new("CP Calculate") {
        next unless JPods._note_before_action("CP Calculate")
        model = Sketchup.active_model
        if model && defined?(JPods::StructurePlacer)
          if JPods::StructurePlacer.cps_shown?
            JPods::StructurePlacer.hide_all_cp_labels(model)
            model.select_tool(nil)
            JPods::JPodNetworkTool.clear_overlays rescue nil
            puts "[JPods] CP markers hidden"
          else
            JPods::StructurePlacer.purge_phantoms(model)
            JPods::StructurePlacer.recompute_all_cps(model)
            JPods::StructurePlacer._show_cp_circles(model)
            is_template = model.path.to_s.include?('track_formations')
            unless is_template
              model.select_tool(JPods::JPodConnectTool.new) rescue nil
            end
            puts "[JPods] CP Calculate — connect guideways (W for waypoints)"
          end
        end
      }
      cmd_cp.large_icon = File.join(icon_dir, "cp_calculate.png")
      cmd_cp.small_icon = File.join(icon_dir, "cp_calculate_small.png")
      cmd_cp.tooltip    = "CP Calculate — show CPs and connect guideways"
      cmd_cp.status_bar_text = "Show connection points, activate Connect tool (W key for waypoints)"
      tb.add_item(cmd_cp)

      # 4. Populate — toggle: fill ~70% / clear all
      @@populated = false
      cmd_populate = UI::Command.new("Populate") {
        next unless JPods._note_before_action("Populate")
        model = Sketchup.active_model
        if model
          if @@populated
            JPods::AnimationV2.stop if defined?(JPods::AnimationV2) && JPods::AnimationV2.running?
            SallyV2.reset if defined?(SallyV2)
            result = JPods::JPodGuideway.clear_all_vehicles(model)
            puts "[JPods] Cleared #{result[:cleared]} pod(s)"
            # Refresh console pod list
            JPods::Console.refresh_vehicle_list(model) if defined?(JPods::Console) && JPods::Console.respond_to?(:refresh_vehicle_list)
            @@populated = false
          else
            result = JPods::JPodGuideway.populate_fleet(model)
            puts "[JPods] Populated #{result[:placed]} pod(s) at #{result[:stations]} station(s)"
            # Refresh console pod list
            JPods::Console.refresh_vehicle_list(model) if defined?(JPods::Console) && JPods::Console.respond_to?(:refresh_vehicle_list)
            @@populated = true
          end
        end
      }
      cmd_populate.large_icon = File.join(icon_dir, "populate.png")
      cmd_populate.small_icon = File.join(icon_dir, "populate_small.png")
      cmd_populate.tooltip    = "Populate — toggle fill/clear vehicles"
      cmd_populate.status_bar_text = "Toggle: place vehicles at ~70% capacity / clear all vehicles"
      tb.add_item(cmd_populate)

      # 5. Travel — JPods Travel phone app
      cmd_trip = UI::Command.new("Travel") {
        JPods::Console.open_travel(Sketchup.active_model)
      }
      cmd_trip.large_icon = File.join(icon_dir, "trip_simulator.png")
      cmd_trip.small_icon = File.join(icon_dir, "trip_simulator_small.png")
      cmd_trip.tooltip    = "Travel"
      cmd_trip.status_bar_text = "Open JPods Travel — book a trip, follow your pod"
      tb.add_item(cmd_trip)

      # 6. Camera — toggle: follow selected pod / stop
      cmd_follow = UI::Command.new("Camera") {
        next unless JPods._note_before_action("Camera")
        model = Sketchup.active_model
        if model && defined?(JPods::AnimationV2)
          current = JPods::AnimationV2.camera_follow_id.to_s
          unless current.empty?
            JPods::AnimationV2.set_camera_follow('')
            puts "[JPods] Camera follow stopped (was #{current})"
            next
          end
          sel = model.selection.first
          vid = sel ? (sel.get_attribute('JPods', 'vehicle_id', '') rescue '').to_s : ''
          if vid.empty?
            UI.messagebox("Select a pod first, then click Camera.", MB_OK) rescue nil
          else
            JPods::AnimationV2.set_camera_follow(vid)
            puts "[JPods] Camera following #{vid}"
          end
        end
      }
      cmd_follow.large_icon = File.join(icon_dir, "camera_follow.png")
      cmd_follow.small_icon = File.join(icon_dir, "camera_follow_small.png")
      cmd_follow.tooltip    = "Camera — select vehicle, click to follow (click again to stop)"
      cmd_follow.status_bar_text = "Follow selected vehicle with camera (click again to stop)"
      tb.add_item(cmd_follow)

      # 7. Animate — toggle: start / complete trips (graceful stop)
      @@anim_toggle_cmd = UI::Command.new("Animate") {
        if defined?(JPods::AnimationV2) && JPods::AnimationV2.paused?
          JPods::AnimationV2.resume rescue nil
          @@anim_toggle_cmd.large_icon = File.join(icon_dir, "stop_anim.png")
          @@anim_toggle_cmd.small_icon = File.join(icon_dir, "stop_anim_small.png")
          @@anim_toggle_cmd.tooltip    = "Pause Animation"
        elsif defined?(JPods::AnimationV2) && JPods::AnimationV2.running?
          JPods::AnimationV2.pause rescue nil
          @@anim_toggle_cmd.large_icon = File.join(icon_dir, "animate.png")
          @@anim_toggle_cmd.small_icon = File.join(icon_dir, "animate_small.png")
          @@anim_toggle_cmd.tooltip    = "Resume Animation"
        else
          ok = JPods::AnimationV2.start(Sketchup.active_model) rescue nil
          if ok
            @@anim_toggle_cmd.large_icon = File.join(icon_dir, "stop_anim.png")
            @@anim_toggle_cmd.small_icon = File.join(icon_dir, "stop_anim_small.png")
            @@anim_toggle_cmd.tooltip    = "Pause Animation"
          end
        end
      }
      @@anim_toggle_cmd.large_icon = File.join(icon_dir, "animate.png")
      @@anim_toggle_cmd.small_icon = File.join(icon_dir, "animate_small.png")
      @@anim_toggle_cmd.tooltip    = "Animate"
      @@anim_toggle_cmd.status_bar_text = "Start animation or complete all trips"
      @@anim_toggle_cmd.set_validation_proc {
        paused    = defined?(JPods::AnimationV2) && (JPods::AnimationV2.paused? rescue false)
        animating = defined?(JPods::AnimationV2) && JPods::AnimationV2.running? && !paused
        if paused
          @@anim_toggle_cmd.large_icon = File.join(icon_dir, "animate.png")
          @@anim_toggle_cmd.small_icon = File.join(icon_dir, "animate_small.png")
          @@anim_toggle_cmd.tooltip    = "Resume Animation"
          MF_ENABLED
        elsif animating
          @@anim_toggle_cmd.large_icon = File.join(icon_dir, "stop_anim.png")
          @@anim_toggle_cmd.small_icon = File.join(icon_dir, "stop_anim_small.png")
          @@anim_toggle_cmd.tooltip    = "Pause Animation"
          MF_CHECKED | MF_ENABLED
        else
          @@anim_toggle_cmd.large_icon = File.join(icon_dir, "animate.png")
          @@anim_toggle_cmd.small_icon = File.join(icon_dir, "animate_small.png")
          @@anim_toggle_cmd.tooltip    = "Animate"
          MF_ENABLED
        end
      }
      tb.add_item(@@anim_toggle_cmd)

      # 8. Crew Health
      cmd_health = UI::Command.new("Crew Health") {
        next unless JPods._note_before_action("Crew Health") rescue true
        model = Sketchup.active_model
        results = JPods::CrewHealth.check(model) rescue []
        total_faults = results.sum { |r| r[:faults].size } rescue 0
        if total_faults == 0
          puts "[JPods] Crew Health: ALL HEALTHY"
        else
          puts "[JPods] Crew Health: #{total_faults} FAULT(S)"
        end
      }
      cmd_health.large_icon = File.join(icon_dir, "crew_health.png")
      cmd_health.small_icon = File.join(icon_dir, "crew_health_small.png")
      cmd_health.tooltip    = "Crew Health Check"
      cmd_health.status_bar_text = "Each crew member checks their domain — Sally, Natalie, Nora, Noelle, Animation"
      tb.add_item(cmd_health)

      # 9. Note
      cmd_note = UI::Command.new("Note") {
        if @@note_mode
          @@note_mode = false
          puts "[JPods Note] Comment mode cancelled"
        else
          @@note_mode = true
          puts "[JPods Note] Comment mode ON — click any button to annotate it"
        end
      }
      cmd_note.large_icon = File.join(icon_dir, "note.png")
      cmd_note.small_icon = File.join(icon_dir, "note_small.png")
      cmd_note.tooltip    = "Note — click to enter comment mode"
      cmd_note.status_bar_text = "Comment mode: your next button click will be annotated before it runs"
      tb.add_item(cmd_note)

      tb.restore
    end

    # Re-register Sally's system clock tick after every plugin reload.
    # The registration auto-starts the timer; idempotent (replaces any prior entry).
    if defined?(JPods::SystemClock) && defined?(JPods::Sally)
      JPods::SystemClock.register('Sally') { |m| JPods::Sally.on_system_tick(m) }
    end

    if defined?(JPods::Oversight)
      JPods::Oversight.install_observer_once
      # Do NOT call run_for_model here — onOpenModel fires on startup for the
      # active model and will call it. Calling here too causes doubled output.
    end

    # ── Save-cleanup observer — erase display-only overlay groups before save ──
    # Overlay groups are regenerated on demand (Path, Show Route, FollowMe overlay).
    # They must not be saved with the model — they are session state, not model data.
    OVERLAY_GROUP_NAMES = [
      'JPods Track Overlay',        # Show Tracks button / show_track_overlay
      'JPods Route Station',      # Show Route / show_route_followus_overlay
      'JPods FollowMe Lines',     # FollowMe overlay
      'JPods FollowMe Stubs',
      'JPods FollowMe Gaps',
      'JPods FollowMe Names',
      'JPods Trip Path',          # Show Trip Path
      'JPods Trip Gaps',
      'JPods Trip Names',
    ].freeze

    class SaveCleanupObserver < Sketchup::ModelObserver
      def onBeforeSaveModel(model)
        to_erase = model.entities.select { |e|
          e.is_a?(Sketchup::Group) &&
          JPods::OVERLAY_GROUP_NAMES.include?(e.name)
        }
        return if to_erase.empty?
        puts "[JPods] Clearing #{to_erase.size} overlay group(s) before save: " \
             "#{to_erase.map(&:name).uniq.join(', ')}"
        model.entities.erase_entities(to_erase)
      rescue => e
        puts "[JPods SaveCleanupObserver] #{e.message}"
      end
    end

    # Prevent duplicate structure IDs on paste/copy-drag.
    # AppObserver handles install for active model on open/new.
    # Do NOT call install_paste_observer directly here — onOpenModel fires on
    # startup and handles it. Calling here too causes doubled output.
    unless defined?(@@jpods_app_observer_installed) && @@jpods_app_observer_installed
      app_obs = Class.new(Sketchup::AppObserver) do
        def onNewModel(model)
          if defined?(JPods::StructurePlacer) && JPods::StructurePlacer.respond_to?(:install_paste_observer)
            JPods::StructurePlacer.install_paste_observer(model)
          end

          # Attach save-cleanup observer to this model
          model.add_observer(JPods::SaveCleanupObserver.new) if defined?(JPods::SaveCleanupObserver)

          # Startup validation: Noelle
          JPods.validate_followme_on_startup(model) if defined?(JPods) && JPods.respond_to?(:validate_followme_on_startup)

          # Startup validation: Natalie
          JPods::NatalieBridge.validate_vehicle_placement_json_on_startup(model) if defined?(JPods::NatalieBridge) && JPods::NatalieBridge.respond_to?(:validate_vehicle_placement_json_on_startup)
        end
        alias onOpenModel onNewModel
      end.new
      Sketchup.add_observer(app_obs)
      @@jpods_app_observer_installed = true
    end

    # Attach save-cleanup to the model that's already open at plugin load time.
    # onOpenModel only fires for models opened *after* the observer is registered.
    begin
      Sketchup.active_model&.add_observer(JPods::SaveCleanupObserver.new)
    rescue => e
      puts "[JPods] SaveCleanupObserver attach at load: #{e.message}"
    end

    file_loaded(__FILE__)
    puts "✅  JPods plugin loaded  (v4.0 — su_jpods menus)"
  end # unless $jpods_registered
end # module JPods (menus/observers)

begin
  puts "[JPods main.rb] NetworkEditor.close at file load end"
  JPods::NetworkEditor.close if defined?(JPods::NetworkEditor) && JPods::NetworkEditor.respond_to?(:close)
rescue
end

# ── Reload helpers — defined OUTSIDE the load guard so they survive reloads ──
# Re-defined on every load of main.rb so they are always available, matching
# the boot.rb pattern.
module JPods

  def self.show_timed_notice(message, title: 'JPods', seconds: 2.0)
    safe_msg = message.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    safe_title = title.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')

    dlg = UI::HtmlDialog.new(
      dialog_title: title,
      preferences_key: 'jpods_timed_notice',
      scrollable: false,
      resizable: false,
      width: 360,
      height: 120,
      style: UI::HtmlDialog::STYLE_DIALOG
    )
    dlg.set_html("<html><body style='margin:0;background:#1e1e1e;color:#d4d4d4;font:13px -apple-system,Segoe UI,sans-serif;display:flex;align-items:center;justify-content:center;height:100%;'><div style='text-align:center;'><div style='font-size:14px;font-weight:600;margin-bottom:8px;'>#{safe_title}</div><div>#{safe_msg}</div></div></body></html>")
    dlg.show
    UI.start_timer(seconds, false) { dlg.close rescue nil }
  rescue => e
    puts "JPods timed notice warning: #{e.message}"
  end

  def self.reload_plugin_with_notice
    $jpods_main_loaded = nil
    load __FILE__
    if JPods.respond_to?(:show_timed_notice)
      JPods.show_timed_notice('JPods plugin reloaded.', title: 'JPods', seconds: 2.0)
    else
      UI.messagebox('JPods plugin reloaded.', MB_OK, 'JPods')
    end
  rescue => e
    UI.messagebox("Reload failed:\n#{e.message}", MB_OK, 'JPods')
  end

end # module JPods (reload helpers)
