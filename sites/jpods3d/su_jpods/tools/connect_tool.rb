# JPods Connect Tool
#
# Interactive viewport tool for connecting structure gate CPs into guideways.
#
# WORKFLOW
#   1. Activate: all structure gate CPs appear as overlay rings in the viewport.
#   2. Click near any CP ring to lock it as the FROM end (ring turns green).
#   3. Move the mouse — a live dashed Bezier preview of BOTH parallel guideways
#      follows the cursor, snapping to the nearest CP when within range.
#   4. Click a second CP to commit: builds BOTH parallel guideways instantly,
#      exactly as Network.build_segment does (arc insertion, terrain snap,
#      beam + columns).  The connection is also appended to the model's JSON
#      file if one is currently loaded.
#   5. Esc with a FROM selected — cancel that selection and start over.
#      Esc with nothing selected — exit the tool.
#
# HOW BOTH TRACKS ARE IDENTIFIED FROM ONE CLICK
#   Each CP stores center (world), tangent (outbound unit vector), and
#   half_offset (= DUAL_TRACK_SPACING / 2 ≈ 1.5 m).  The two physical
#   track stub-tip positions are:
#     perp      = tangent × Z_AXIS  (horizontal, 90° left of outbound dir)
#     left_tip  = center + perp * half_offset
#     right_tip = center - perp * half_offset
#   The gate ring drawn in the viewport is exactly this span — one click
#   captures both tracks simultaneously.

require 'json'
require 'fileutils'

module JPods
  class JPodConnectTool

    # Screen-space snap and ring size (pixels) — independent of zoom level.
    RING_RADIUS_PX = 22    # radius of the 2D overlay circle
    RING_SNAP_PX   = 36    # pixel distance that counts as a click
    # World-space fallback snap — same radius as the original su_mostly version.
    # Used when screen_coords is unavailable or returns no hit.
    SNAP_RADIUS_M    = 4.0.m
    CIRCLE_SEGS      = 32
    BEZIER_SEGS      = 20           # minimum segment count (fallback for tiny chords)
    PREVIEW_SEG_M    = 3.0.m        # target spacing for preview curves — finer than
                                    # build (2m) but dense enough for smooth viewport display

    # Viewport colours — 3-click CP teaching model:
    #   Click 1 → COL_INSPECT (white)   "I see this CP and its connection"
    #   Click 2 → COL_FROM    (gold)    "I intend to connect FROM here"  (unconnected CP)
    #             COL_INSPECT again     "connection exists — click once more to edit"
    #   Click 3 → COL_EDIT    (cyan)    "I am editing this connection's waypoints"
    COL_IDLE     = Sketchup::Color.new(0, 200, 80)  # green — visible on SU background
    COL_HOVER    = Sketchup::Color.new(255, 210,   0)
    COL_INSPECT  = Sketchup::Color.new(255, 255, 255)   # white  — inspect state
    COL_FROM     = Sketchup::Color.new(255, 180,   0)   # gold   — FROM-ready (unconnected)
    COL_EDIT     = Sketchup::Color.new(  0, 220, 220)   # cyan   — editing waypoints
    COL_PREVIEW  = Sketchup::Color.new( 80, 180, 255)
    COL_BUILT    = Sketchup::Color.new(255, 165,  60)   # amber — already-built guideway beams
    COL_PLANNED  = Sketchup::Color.new( 60, 210, 130)   # green — Bezier plan from JSON
    COL_BLOCKED  = Sketchup::Color.new( 80, 140, 255)   # blue  — cpb barrier in place (cold/closed)

    # Class-level draft state — survive tool deactivation (e.g. SketchUp's Move tool
    # intercepts M before any plugin's onKeyDown, forcing the tool to exit briefly).
    # @@draft_connections: all drafted (not-yet-built) connections from this session.
    # @@last_draft_idx:    index of the connection being refined with W-key waypoints.
    @@draft_connections = [] unless defined?(@@draft_connections)
    @@last_draft_idx    = nil unless defined?(@@last_draft_idx)

    # ── Life-cycle ─────────────────────────────────────────────────────────────

    def self.draft_connections
      @@draft_connections ||= []
    end

    def self.clear_drafts
      @@draft_connections = []
      @@last_draft_idx    = nil
    end

    # Remove a single draft by conn_id.  Called by the Network Editor delete button
    # so the viewport bezier overlay disappears immediately.
    # Returns true if found and removed, false if not found.
    def self.remove_draft(conn_id)
      @@draft_connections ||= []
      idx = @@draft_connections.index { |d| d[:conn_id] == conn_id }
      return false unless idx
      @@draft_connections.delete_at(idx)
      if @@last_draft_idx
        if @@last_draft_idx == idx
          @@last_draft_idx = @@draft_connections.empty? ? nil : [[idx - 1, 0].max, @@draft_connections.size - 1].min
        elsif @@last_draft_idx > idx
          @@last_draft_idx -= 1
        end
      end
      Sketchup.active_model.active_view.invalidate rescue nil
      true
    end

    def initialize
      @cps                  = []   # { struct_id:, stub:, center:, tangent:, half_offset: }
      # ── 3-click CP state machine ────────────────────────────────────────────
      # @inspect_cp / @inspect_clicks — click 1 (white): see CP and its connection
      # @from_cp                      — click 2 (gold):  FROM-ready on unconnected CP
      # @edit_cp                      — click 3 (cyan):  edit waypoints on connected CP
      @inspect_cp           = nil
      @inspect_clicks       = 0
      @from_cp              = nil
      @edit_cp              = nil
      # ────────────────────────────────────────────────────────────────────────
      @hover_cp             = nil  # gate under cursor
      @preview_pts          = nil  # [[left_pts], [right_pts]] gold preview while picking TO
      @edit_preview_pts     = nil  # [[left_pts], [right_pts]] cyan preview while editing
      @built_paths          = []   # [[pts], ...] one polyline per built connection
      @planned_path_entries = []   # [{ from_sid:, from_stub:, to_sid:, to_stub:, from_cp:, to_cp:, pts: }, ...]
      @markers              = []   # [{ num:, pt:, label: }, ...]
      @cursor_ip            = nil
      @active_bezier_pts    = nil
      @w_key_down           = false
      @dragging_marker_num  = nil
      @drag_pt              = nil
      @pending_via_pts      = []
      @pending_via_nums     = []
      @hover_marker         = false   # true when cursor is within grab-range of a marker
    end

    def activate
      model = Sketchup.active_model
      collect_cps(model)
      collect_built_paths(model)
      collect_planned_paths(model)
      collect_markers(model)
      restore_draft_connections(model)   # rebuild in-memory drafts from JSON on re-entry
      @cursor_ip = Sketchup::InputPoint.new
      set_status_idle
      model.active_view.invalidate
    end

    def deactivate(view)
      view.invalidate
    end

    def resume(view)
      view.invalidate
    end

    # ── Mouse movement — hover highlight + live preview ────────────────────────

    def onMouseMove(_flags, x, y, view)
      @cursor_ip ||= Sketchup::InputPoint.new
      @cursor_ip.pick(view, x, y)

      # Drag mode: move ghost to beam-level position and rebuild bezier live.
      # Snap to terrain + CLEARANCE_HEIGHT so the dragged marker stays at beam level.
      if @dragging_marker_num
        pt = @cursor_ip.position
        terrain_pt = Terrain.ground_z_at(view.model, pt.x, pt.y)
        @drag_pt = Geom::Point3d.new(pt.x, pt.y,
                                     terrain_pt.z + Constants::CLEARANCE_HEIGHT)
        update_draft_via_pt(@dragging_marker_num, @drag_pt)
        view.invalidate
        return
      end

      prev_hover = @hover_cp
      @hover_cp  = best_cp(view, x, y, @cursor_ip.position)

      if @from_cp
        # Gold state: preview follows cursor toward potential TO cp.
        # When via_pts exist and no real CP is under cursor, project the TO past
        # the cursor so the bezier curves through the waypoints visibly.
        to_cp = if @hover_cp && !from_cp?(@hover_cp)
          @hover_cp
        elsif @pending_via_pts.any?
          cursor_pos = @cursor_ip.position
          last_via   = @pending_via_pts.last
          # If cursor is near or behind the last waypoint, extend past it
          dir = cursor_pos - @from_cp[:center]
          dir = Geom::Vector3d.new(1, 0, 0) if dir.length < 0.001
          far_pt = cursor_pos.offset(dir.normalize, [last_via.distance(cursor_pos) + 5.0.m, 5.0.m].max)
          synthetic_cp(far_pt, @from_cp)
        else
          synthetic_cp(@cursor_ip.position, @from_cp)
        end
        @preview_pts = build_dual_preview_via(@from_cp, @pending_via_pts, to_cp)
      elsif @edit_cp
        # Cyan state: preview shows connection being reshaped by pending waypoints
        entry = connection_entry_for_cp(@edit_cp)
        if entry
          other = other_cp_in_entry(entry, @edit_cp)
          @edit_preview_pts = build_dual_preview_via(@edit_cp, @pending_via_pts, other)
        end
      end

      # Track whether cursor is near a marker so onSetCursor can show grab icon.
      cursor_pt = @cursor_ip.position rescue nil
      prev_hover_marker = @hover_marker
      @hover_marker = cursor_pt && @markers.any? { |mk|
        dx = cursor_pt.x - mk[:pt].x; dy = cursor_pt.y - mk[:pt].y
        Math.sqrt(dx * dx + dy * dy) < 2.0.m
      }

      view.invalidate if @hover_cp != prev_hover || @from_cp || @edit_cp ||
                         @hover_marker != prev_hover_marker
    end

    # ── Click ──────────────────────────────────────────────────────────────────

    def onLButtonDown(_flags, x, y, view)
      ip = Sketchup::InputPoint.new
      ip.pick(view, x, y)
      cursor_pt = ip.position

      # Shift-click: delete all connections attached to the clicked CP node.
      # Keys on the CP ring (node), not the guideway geometry — so one click clears
      # both directions of a bidirectional pair (seg_A→B and seg_B→A).
      # Falls back to nearest draft line if no CP ring was near the cursor.
      if (_flags & CONSTRAIN_MODIFIER_MASK) != 0
        idx = nearest_draft_idx_at(x, y, view)
        if idx
          conn_id = @@draft_connections[idx][:conn_id]
          puts "[JPods Connect] Shift-click: deleting #{conn_id} (draft idx=#{idx})"
          @@draft_connections.delete_at(idx)
          JPods::NetworkEditor.delete_connection(view.model, conn_id)
          json_path = (NetworkEditor.default_network_json_path(view.model) rescue nil)
          JPods::NetworkEditor.push_network_json(view.model, json_path) if json_path
          collect_cps(Sketchup.active_model)
          collect_planned_paths(Sketchup.active_model)
          Sketchup.set_status_text(
            "JPods Connect: deleted #{conn_id}. Shift-click another to delete.")
        else
          # No draft line near cursor — try clicking a CP ring
          clicked = best_cp(view, x, y, cursor_pt)
          if clicked && clicked[:struct_id] && !clicked[:stub].nil?
            sid_lc = clicked[:struct_id].to_s.downcase
            stub_s = clicked[:stub].to_s
            cp_tok = "#{sid_lc}.#{stub_s}"

            # Find the FIRST (single) connection that starts or ends at this CP
            target_cid = nil

            # Check drafts
            @@draft_connections.each do |draft|
              cid = draft[:conn_id].to_s.downcase
              if cid.start_with?("#{cp_tok}_") || cid.end_with?("_#{cp_tok}")
                target_cid = draft[:conn_id]
                break
              end
            end

            # Check network.json if not found in drafts
            unless target_cid
              begin
                json_path = JPods::NetworkEditor.default_network_json_path(view.model)
                if json_path && File.exist?(json_path)
                  root = JSON.parse(File.read(json_path, encoding: 'utf-8')) rescue {}
                  (root['connections'] || {}).each_key do |cid|
                    if cid.downcase.start_with?("#{cp_tok}_") || cid.downcase.end_with?("_#{cp_tok}")
                      target_cid = cid
                      break
                    end
                  end
                end
              rescue
              end
            end

            if target_cid
              puts "[JPods Connect] Shift-click CP: deleting #{target_cid}"
              @@draft_connections.reject! { |d| d[:conn_id] == target_cid }
              JPods::NetworkEditor.delete_connection(view.model, target_cid)
              json_path = (NetworkEditor.default_network_json_path(view.model) rescue nil)
              JPods::NetworkEditor.push_network_json(view.model, json_path) if json_path
              collect_cps(Sketchup.active_model)
              collect_planned_paths(Sketchup.active_model)
              Sketchup.set_status_text(
                "JPods Connect: deleted #{target_cid}. Shift-click another to delete.")
            else
              Sketchup.set_status_text(
                "JPods Connect: no connection at #{cp_tok}.")
            end
          end
        end
        view.invalidate
        return
      end

      # Marker drag takes priority in idle and edit states
      if @from_cp.nil?
        mk = nearest_marker_xy(cursor_pt)
        if mk
          @dragging_marker_num = mk[:num]
          @drag_pt             = mk[:pt]
          Sketchup.set_status_text("JPods Connect: dragging W#{mk[:num]} — release to set position.")
          return
        end
      end

      clicked = best_cp(view, x, y, cursor_pt)

      # Clicked empty terrain
      if clicked.nil?
        if @edit_cp
          # Stay in edit mode — empty terrain is noise; user presses Esc to exit
          view.invalidate
          return
        end
        clear_cp_state
        set_status_idle
        view.invalidate
        return
      end

      # ── Gold (FROM-ready) state: second click on a different CP commits the connection ──
      if @from_cp && !same_cp?(clicked, @from_cp)
        draft_from = @from_cp
        draft_to   = clicked
        conn_id    = commit(view, @from_cp, clicked, @pending_via_pts, @pending_via_nums)
        if conn_id
          record_draft(draft_from, draft_to, conn_id,
                       via_pts: @pending_via_pts.dup,
                       via_nums: @pending_via_nums.dup)
        end
        clear_cp_state
        model = Sketchup.active_model
        collect_cps(model)
        collect_built_paths(model)
        collect_planned_paths(model)
        collect_markers(model)
        Sketchup.set_status_text(
          "JPods: connected #{JPods::ConnectionPoint.new(structure_id: draft_from[:struct_id], index: draft_from[:stub]).to_key}" \
          " \u2192 #{JPods::ConnectionPoint.new(structure_id: draft_to[:struct_id], index: draft_to[:stub]).to_key}." \
          "  Click a CP to continue.")
        view.invalidate
        return
      end

      if @inspect_cp && same_cp?(clicked, @inspect_cp)
        connected = has_connection?(clicked)
        if connected
          @edit_cp        = @inspect_cp
          @inspect_cp     = nil
          @inspect_clicks = 0
          entry = connection_entry_for_cp(@edit_cp)
          if entry
            other = other_cp_in_entry(entry, @edit_cp)
            @edit_preview_pts = build_dual_preview_via(@edit_cp, [], other)
          end
          Sketchup.set_status_text(
            "JPods: #{JPods::ConnectionPoint.new(structure_id: @edit_cp[:struct_id], index: @edit_cp[:stub]).to_key} CYAN — " \
            "press W to add waypoints along this connection. Esc when done.")
        else
          @from_cp        = @inspect_cp
          @inspect_cp     = nil
          @inspect_clicks = 0
          @pending_via_pts  = []
          @pending_via_nums = []
          Sketchup.set_status_text(
            "JPods: #{JPods::ConnectionPoint.new(structure_id: @from_cp[:struct_id], index: @from_cp[:stub]).to_key} GOLD — " \
            "click another CP to connect. Press W to add waypoints first. Esc to cancel.")
        end

      elsif @from_cp && same_cp?(clicked, @from_cp)
        @inspect_cp     = @from_cp
        @inspect_clicks = 0
        @from_cp        = nil
        @preview_pts    = nil
        @pending_via_pts  = []
        @pending_via_nums = []
        Sketchup.set_status_text(
          "JPods: #{JPods::ConnectionPoint.new(structure_id: @inspect_cp[:struct_id], index: @inspect_cp[:stub]).to_key} — " \
          "click again to act, or Esc to clear.")

      elsif @edit_cp && same_cp?(clicked, @edit_cp)
        clear_cp_state
        set_status_idle

      else
        clear_cp_state
        @inspect_cp     = clicked
        @inspect_clicks = 0
        connected       = has_connection?(clicked)
        hint = connected ?
          "connected. Click again to edit its waypoints (CYAN)." :
          "no connection. Click again to set as FROM (GOLD) and connect."
        Sketchup.set_status_text(
          "JPods: #{JPods::ConnectionPoint.new(structure_id: clicked[:struct_id], index: clicked[:stub]).to_key} — #{hint}")
      end

      view.invalidate
    end

    # Release — commit marker drag
    def onLButtonUp(_flags, _x, _y, view)
      return unless @dragging_marker_num
      commit_marker_move(view.model, @dragging_marker_num, @drag_pt)
      @dragging_marker_num = nil
      @drag_pt             = nil
      view.invalidate
    end

    # ── Keyboard ──────────────────────────────────────────────────────────────
    # W key — drop a waypoint marker without leaving the tool (one per press).
    #         M is SketchUp's built-in Move shortcut and fires before onKeyDown.
    # Esc   — cancel FROM selection, or exit tool.

    def onKeyDown(key, _repeat, _flags, view)
      # W key (ASCII 87 / 119) — Waypoint: guard against key-repeat
      if key == 87 || key == 119
        unless @w_key_down
          @w_key_down = true
          drop_marker_at_cursor(view)
        end
        return true
      end


      return false unless key == 27   # Esc

      if @inspect_cp || @from_cp || @edit_cp
        clear_cp_state
        set_status_idle
        view.invalidate
      else
        view.model.select_tool(nil)
      end
      true
    end

    def onKeyUp(key, _repeat, _flags, _view)
      @w_key_down = false if key == 87 || key == 119
      false
    end

    # State-dependent cursor — teaches the student which mode they are in:
    #   Idle / Inspect        → crosshair (671) — click a CP
    #   Gold/Cyan, no pending → pencil    (280) — click another CP or press W
    #   Gold/Cyan, pending W  → crosshair (671) — precise waypoint placement
    def onSetCursor
      if @dragging_marker_num
        UI.set_cursor(648)   # 4-arrow move — actively repositioning a waypoint
      elsif @hover_marker
        UI.set_cursor(643)   # pointing hand — can grab this waypoint
      elsif @from_cp || @edit_cp
        UI.set_cursor(@pending_via_pts.any? ? 671 : 280)
                             # crosshair while placing waypoints; pencil otherwise
      else
        UI.set_cursor(671)   # crosshair — default: click a gate to begin
      end
    end

    # ── Viewport drawing ───────────────────────────────────────────────────────

    def draw(view)
      # Green plan lines — drawn from live draft connections (not JSON).
      # Via-point changes update @@draft_connections in real time, so the bezier
      # always follows the current marker positions with no disk read needed.
      visible_draft_connections.each do |d|
        pts = d[:center_pts]
        next unless pts && pts.size >= 2
        view.line_width    = 4
        view.line_stipple  = "_"
        view.drawing_color = COL_PLANNED
        view.draw(GL_LINE_STRIP, pts)
        view.line_stipple  = ""
      end

      # Gold state: live bezier preview following cursor toward the TO cp.
      # Drawn in gold so the student knows this connection is being built.
      if @from_cp && @preview_pts && !@preview_pts.empty?
        view.line_width    = 4
        view.line_stipple  = ""
        view.drawing_color = COL_FROM
        @preview_pts.each { |pts| view.draw(GL_LINE_STRIP, pts) if pts.size >= 2 }
      end

      # Cyan state: connection being edited — show dual tracks live from the draft.
      # d[:paths] and d[:center_pts] are rebuilt by rebuild_draft_paths on every
      # drag tick, so the bezier always follows the marker in real time.
      if @edit_cp
        d = draft_for_cp(@edit_cp)
        if d
          if d[:center_pts] && d[:center_pts].size >= 2
            view.line_width    = 3
            view.line_stipple  = "_"
            view.drawing_color = Sketchup::Color.new(0, 140, 140)
            view.draw(GL_LINE_STRIP, d[:center_pts])
            view.line_stipple  = ""
          end
          if d[:paths] && !d[:paths].empty?
            view.line_width    = 4
            view.line_stipple  = ""
            view.drawing_color = COL_EDIT
            d[:paths].each { |pts| view.draw(GL_LINE_STRIP, pts) if pts.size >= 2 }
          end
        end
      end

      # Inspect state: highlight this CP's connection in white so the student can see it.
      if @inspect_cp
        d = draft_for_cp(@inspect_cp)
        if d && d[:center_pts] && d[:center_pts].size >= 2
          view.line_width    = 4
          view.line_stipple  = ""
          view.drawing_color = COL_INSPECT
          view.draw(GL_LINE_STRIP, d[:center_pts])
        end
      end

      # Amber dashed centerlines for already-built guideways (terrain-adjusted).
      unless @built_paths.empty?
        view.line_width    = 8
        view.line_stipple  = "-"
        view.drawing_color = COL_BUILT
        @built_paths.each { |pts| view.draw(GL_LINE_STRIP, pts) if pts.size >= 2 }
        view.line_stipple  = ""
      end

      # Orange marker circles — waypoint posts that influence Bezier routing.
      # Refreshed each frame from in-model groups (fast scan kept cheap).
      live_markers = collect_markers_live(view.model)
      unless live_markers.empty?
        live_markers.each do |mk|
          is_dragging = (@dragging_marker_num == mk[:num])
          gpt = mk[:ground_pt] || mk[:pt]   # ground-level point for radius circles
          # 5 m and 10 m radius reference circles at terrain level — dashed, dim.
          # Help users judge the curve radius they are applying to the guideway.
          view.line_stipple  = "-"
          view.line_width    = 1
          view.drawing_color = Sketchup::Color.new(180, 120, 40, 160)
          draw_circle_pts(view, gpt, 5.m)
          draw_circle_pts(view, gpt, 10.m)
          # Marker identity rings at beam level
          view.line_width    = is_dragging ? 4 : 3
          view.line_stipple  = ""
          view.drawing_color = is_dragging ?
            Sketchup::Color.new(255, 220, 50) :   # bright yellow while dragging
            Sketchup::Color.new(255, 140, 0)       # orange at rest
          draw_circle_pts(view, mk[:pt], 1.5.m)   # outer ring at beam level
          draw_circle_pts(view, mk[:pt], 0.4.m)   # inner dot at beam level
          # Screen-space label beside the outer ring
          sc = view.screen_coords(mk[:pt]) rescue nil
          if sc
            view.draw_text(
              Geom::Point3d.new(sc.x + 18, sc.y - 6, 0),
              mk[:label], size: 36, bold: true,
              color: is_dragging ? "#ffdc32" : "#ff8c00"
            ) rescue view.draw_text(Geom::Point3d.new(sc.x + 18, sc.y - 6, 0), mk[:label])
          end
        end
      end

      # Ghost ring at drag destination
      if @dragging_marker_num && @drag_pt
        view.line_width    = 4
        view.line_stipple  = ""
        view.drawing_color = Sketchup::Color.new(255, 255, 80)
        draw_circle_pts(view, @drag_pt, 1.8.m)
        draw_circle_pts(view, @drag_pt, 0.5.m)
      end

      # Gate rings — color reflects the 3-click teaching state
      @cps.each do |cp|
        if from_cp?(cp)
          draw_gate(view, cp, COL_FROM,    3)   # gold
        elsif edit_cp?(cp)
          draw_gate(view, cp, COL_EDIT,    3)   # cyan
        elsif inspect_cp?(cp)
          draw_gate(view, cp, COL_INSPECT, 3)   # white
        elsif hover_cp?(cp)
          draw_gate(view, cp, COL_HOVER,   2)   # yellow
        elsif cp[:blocked]
          draw_gate(view, cp, COL_BLOCKED, 2)   # blue — cpb barrier (cold/closed)
        else
          draw_gate(view, cp, COL_IDLE,    1)   # gray
        end
      end

      # Dual-track lines for all committed connections not currently being built/edited.
      # Uses the same suppression logic as the dashed center line above.
      visible_draft_connections.each do |draft|
        next if draft[:paths].nil? || draft[:paths].empty?
        view.line_width    = 3
        view.line_stipple  = ""
        view.drawing_color = COL_PLANNED
        draft[:paths].each { |pts| view.draw(GL_LINE_STRIP, pts) if pts.size >= 2 }
      end

    end

    # =========================================================================
    private
    # =========================================================================

    # Right-click context menu — "Place Marker Here" without leaving the tool.
    def getMenu(menu, _flags, x, y, view)
      @cursor_ip ||= Sketchup::InputPoint.new
      @cursor_ip.pick(view, x, y)
      menu.add_item("Place Waypoint Here (W)") { drop_marker_at_cursor(view) }
      menu.add_separator
      if @from_cp || @edit_cp || @inspect_cp
        menu.add_item("Clear selection (Esc)") do
          clear_cp_state; set_status_idle; view.invalidate
        end
      end
      menu.add_item("Exit Connect Guideways") { view.model.select_tool(nil) }
    end

    # ── CP value-comparison helpers ────────────────────────────────────────────
    # Value equality (struct_id + stub) — collect_cps rebuilds @cps with new
    # Ruby objects so object identity (equal?) always fails after a rebuild.

    def same_cp?(a, b)
      a && b &&
        a[:struct_id] == b[:struct_id] &&
        a[:stub].to_i == b[:stub].to_i
    end

    def from_cp?(cp)    = same_cp?(cp, @from_cp)
    def edit_cp?(cp)    = same_cp?(cp, @edit_cp)
    def inspect_cp?(cp) = same_cp?(cp, @inspect_cp)
    def hover_cp?(cp)   = same_cp?(cp, @hover_cp)

    # True if this CP appears in any draft connection (in-memory, always live).
    def has_connection?(cp)
      !draft_for_cp(cp).nil?
    end

    # Find the draft connection that involves +cp+.
    def draft_for_cp(cp)
      return nil unless cp
      sid  = cp[:struct_id]
      stub = cp[:stub].to_i
      @@draft_connections.find { |d|
        next unless d[:from_cp] && d[:to_cp]
        (d[:from_cp][:struct_id] == sid && d[:from_cp][:stub].to_i == stub) ||
        (d[:to_cp][:struct_id]   == sid && d[:to_cp][:stub].to_i   == stub)
      }
    end

    # Kept for callers that expect an entry-like hash — bridges old API to drafts.
    def connection_entry_for_cp(cp)
      d = draft_for_cp(cp)
      return nil unless d
      { from_sid: d[:from_cp][:struct_id], from_stub: d[:from_cp][:stub].to_i,
        to_sid:   d[:to_cp][:struct_id],   to_stub:   d[:to_cp][:stub].to_i,
        from_cp:  d[:from_cp],             to_cp:     d[:to_cp],
        pts:      d[:center_pts] || [] }
    end

    # Given a draft and one of its CPs, return the other CP.
    def other_cp_in_draft(draft, cp)
      if draft[:from_cp][:struct_id] == cp[:struct_id] && draft[:from_cp][:stub].to_i == cp[:stub].to_i
        draft[:to_cp]
      else
        draft[:from_cp]
      end
    end

    # Legacy alias used by a few callers that pass an entry hash.
    def other_cp_in_entry(entry, cp)
      if entry[:from_sid] == cp[:struct_id] && entry[:from_stub] == cp[:stub].to_i
        entry[:to_cp]
      else
        entry[:from_cp]
      end
    end

    # Draft connections that are NOT currently being edited/built —
    # these are the ones that show as green dashed in the viewport.
    def visible_draft_connections
      active = @from_cp || @edit_cp
      return @@draft_connections unless active
      sid  = active[:struct_id]
      stub = active[:stub].to_i
      @@draft_connections.reject { |d|
        next false unless d[:from_cp] && d[:to_cp]
        (d[:from_cp][:struct_id] == sid && d[:from_cp][:stub].to_i == stub) ||
        (d[:to_cp][:struct_id]   == sid && d[:to_cp][:stub].to_i   == stub)
      }
    end

    # Clear all CP interaction state back to idle.
    def clear_cp_state
      @inspect_cp       = nil
      @inspect_clicks   = 0
      @from_cp          = nil
      @edit_cp          = nil
      @preview_pts      = nil
      @edit_preview_pts = nil
      @pending_via_pts  = []
      @pending_via_nums = []
    end

    # ── CP collection ──────────────────────────────────────────────────────────

    def collect_cps(model)
      @cps = []
      no_cp_sids = []
      model.entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        next if e.hidden?
        next if e.respond_to?(:layer) && e.layer && !e.layer.visible?
        next if e.deleted?
        # Use the structure_id attribute — NOT entity name — so manually placed
        # and imported models that kept their original names are still found.
        sid = e.get_attribute("JPods", "structure_id").to_s
        next if sid.empty?
        raw = e.get_attribute("JPods", "connection_points")
        if raw.nil? || raw.empty?
          no_cp_sids << sid
          next
        end
        begin
          t = e.respond_to?(:transformation) ? e.transformation : Geom::Transformation.new
          JSON.parse(raw).each do |d|
            center_local = StructurePlacer.point3d_from_any(d["center"])
            tangent_local = StructurePlacer.vector3d_from_any(d["tangent"])
            next unless center_local && tangent_local
            @cps << {
              struct_id:   sid,
              stub:        d["index"],
              center:      t * center_local,
              tangent:     t * tangent_local,
              half_offset: d["half_offset"].to_f,
            }
          end
        rescue => ex
          puts "JPodConnectTool: CP parse error on #{sid}: #{ex.message}"
        end
      end
      # Single summary line instead of one warning per registered-but-undetected entity.
      if no_cp_sids.any?
        puts "JPodConnectTool: #{no_cp_sids.size} registered structure(s) have no CPs (#{no_cp_sids.first(3).join(', ')}#{no_cp_sids.size > 3 ? '…' : ''}) — run Calculate CPs"
      end

      # Detect cpb barriers — mark nearby CPs as blocked (blue/cold)
      barrier_positions = []
      model.entities.each do |e|
        next unless e.is_a?(Sketchup::ComponentInstance)
        defn = e.definition
        is_cpb = defn.name.downcase.include?('cpb') ||
                 defn.entities.any? { |c|
                   c.is_a?(Sketchup::ComponentInstance) &&
                   c.definition.name.to_s.downcase.include?('cp_marker_b')
                 }
        barrier_positions << e.transformation.origin if is_cpb
      end
      if barrier_positions.any?
        @cps.each do |cp|
          cp[:blocked] = barrier_positions.any? { |bp| bp.distance(cp[:center]) < 20.m }
        end
      end
    end

    # Collect beam_path centerlines from already-built guideways.
    # Uses track_index 1 (one per connection pair) to avoid doubling up.
    # Called on activate and after each commit so the overlay stays current.
    def collect_built_paths(model)
      @built_paths = []
      model.entities.each do |e|
        # Direct name check — avoids the broken `rescue next` pattern.
        next unless e.is_a?(Sketchup::Group) && e.name == "JPods Guideway"
        next unless e.get_attribute("JPods", "track_index", -1).to_i == 1
        raw = e.get_attribute("JPods", "beam_path")
        next unless raw
        begin
          pts = JSON.parse(raw).map { |a| Geom::Point3d.new(a[0].to_f, a[1].to_f, a[2].to_f) }
          @built_paths << pts if pts.size >= 2
        rescue
          # ignore malformed beam_path
        end
      end
    rescue => ex
      puts "JPodConnectTool collect_built_paths: #{ex.message}"
    end

    # Build the green Bezier plan overlay from JSON on disk.
    # Stores entries as { from_sid:, from_stub:, to_sid:, to_stub:, from_cp:, to_cp:, pts: }
    # so draw() can suppress the entry being actively edited without losing the rest.
    def collect_planned_paths(model)
      @planned_path_entries = []

      begin
        json_path = NetworkEditor.default_network_json_path(model)
        if json_path.nil? || !File.exist?(json_path)
          puts "[JPods ConnectTool] no network.json found — no plan overlay"
          return
        end
        raw   = JSON.parse(File.read(json_path, encoding: 'utf-8'))
        conns = NetworkEditor.feature_connections_to_flat_array(raw['connections'] || {})
        puts "[JPods ConnectTool] #{conns.size} connection(s) in network.json"
      rescue => ex
        puts "[JPods ConnectTool] JSON read error: #{ex.message}"
        return
      end

      conns.each do |conn|
        from_spec  = conn['from'] || {}
        to_spec    = conn['to']   || {}
        marker_ids = conn['via_markers'] || []

        from_sid   = from_spec['structure_id'].to_s
        from_stub  = from_spec['stub'].to_i
        to_sid     = to_spec['structure_id'].to_s
        to_stub    = to_spec['stub'].to_i

        from_cp = @cps.find { |cp| cp[:struct_id] == from_sid && cp[:stub].to_i == from_stub }
        to_cp   = @cps.find { |cp| cp[:struct_id] == to_sid   && cp[:stub].to_i == to_stub   }
        next unless from_cp && to_cp

        marker_pts = marker_ids.filter_map { |n|
          m = model.entities.find { |e|
            e.is_a?(Sketchup::Group) && e.name == "JPod Marker" &&
            e.get_attribute("JPods", "marker_number", 0).to_i == n.to_i
          }
          next unless m
          b  = m.bounds
          bz = m.get_attribute("JPods", "beam_z")
          rz = bz ? bz.to_f : (b.min.z + Constants::CLEARANCE_HEIGHT)
          Geom::Point3d.new(b.center.x, b.center.y, rz)
        }

        begin
          pts = Network.bezier_spline_pts(from_cp, marker_pts, to_cp)
          next unless pts.size >= 2
          @planned_path_entries << {
            from_sid:  from_sid,  from_stub: from_stub,
            to_sid:    to_sid,    to_stub:   to_stub,
            from_cp:   from_cp,   to_cp:     to_cp,
            pts:       pts,
          }
        rescue => ex
          puts "JPodConnectTool planned path error [#{conn['id']}]: #{ex.message}"
        end
      end
    rescue => ex
      puts "JPodConnectTool collect_planned_paths: #{ex.message}"
      @planned_path_entries = []
    end

    # Returns planned path entries that do NOT involve the currently-active FROM cp.
    # When a student is editing a connection, that connection's stale JSON path is
    # suppressed so only the live preview bezier (updated by W-key waypoints) shows.
    # Suppress the planned path for any CP currently being edited (gold or cyan)
    # so the live preview is the only bezier the student sees for that connection.
    def visible_planned_entries
      active = @from_cp || @edit_cp
      return @planned_path_entries unless active
      sid  = active[:struct_id]
      stub = active[:stub].to_i
      @planned_path_entries.reject { |e|
        (e[:from_sid] == sid && e[:from_stub] == stub) ||
        (e[:to_sid]   == sid && e[:to_stub]   == stub)
      }
    end

    # Collect all JPod Marker groups in the model into @markers for getExtents.
    def collect_markers(model)
      @markers = collect_markers_live(model)
    end

    # Cheap per-frame scan — returns array of { num:, pt:, label: }.
    # Kept separate from collect_markers so activate can cache @markers but
    # draw can always reflect newly-dropped markers without a full re-activate.
    def collect_markers_live(model)
      result = []
      model.entities.each do |e|
        next unless e.is_a?(Sketchup::Group) && e.name == "JPod Marker"
        num = e.get_attribute("JPods", "marker_number", 0).to_i
        b   = e.bounds
        # beam_z attribute (stored in inches) is the authoritative routing elevation.
        # Falls back to b.min.z for legacy markers placed before this attribute existed.
        raw_bz = e.get_attribute("JPods", "beam_z")
        routing_z = raw_bz ? raw_bz.to_f : (b.min.z + Constants::CLEARANCE_HEIGHT)
        # terrain_z for ground-level overlay circles; estimate from beam_z if missing.
        raw_tz   = e.get_attribute("JPods", "terrain_z")
        terrain_z = raw_tz ? raw_tz.to_f :
                    (routing_z - Constants::CLEARANCE_HEIGHT)
        pt        = Geom::Point3d.new(b.center.x, b.center.y, routing_z)
        ground_pt = Geom::Point3d.new(b.center.x, b.center.y, terrain_z)
        result << { num: num, pt: pt, ground_pt: ground_pt, label: "W#{num}" }
      end
      result.sort_by { |m| m[:num] }
    rescue
      []
    end

    # Draw a flat horizontal circle at +pt+ with radius +r+ using line segments.
    def draw_circle_pts(view, pt, r)
      segs = 24
      angle_step = 2.0 * Math::PI / segs
      pts = (0..segs).map { |i|
        a = i * angle_step
        Geom::Point3d.new(pt.x + r * Math.cos(a), pt.y + r * Math.sin(a), pt.z)
      }
      view.draw(GL_LINE_STRIP, pts)
    end

    # XY-only proximity test to find the nearest marker to the cursor.
    # Returns a { num:, pt:, label: } hash or nil.
    def nearest_marker_xy(cursor_pt)
      best = nil
      best_dist = 2.0.m
      collect_markers_live(Sketchup.active_model).each do |mk|
        dx = cursor_pt.x - mk[:pt].x
        dy = cursor_pt.y - mk[:pt].y
        d  = Math.sqrt(dx * dx + dy * dy)
        if d < best_dist
          best_dist = d
          best = mk
        end
      end
      best
    rescue
      nil
    end

    # Screen-space click-on-line: returns the index of the draft whose bezier
    # is closest to (sx, sy) within max_px pixels, or nil if none is that close.
    def nearest_draft_idx_at(sx, sy, view, max_px = 14)
      best_idx  = nil
      best_dist = max_px.to_f
      @@draft_connections.each_with_index do |draft, idx|
        next if draft[:paths].nil? || draft[:paths].empty?
        draft[:paths].each do |polyline|
          next if polyline.size < 2
          polyline.each_cons(2) do |a, b|
            sa = view.screen_coords(a) rescue next
            sb = view.screen_coords(b) rescue next
            d  = seg_dist_2d(sx, sy, sa.x, sa.y, sb.x, sb.y)
            if d < best_dist
              best_dist = d
              best_idx  = idx
            end
          end
        end
      end
      best_idx
    rescue
      nil
    end

    # Perpendicular distance from point (px,py) to segment (ax,ay)-(bx,by).
    def seg_dist_2d(px, py, ax, ay, bx, by)
      dx = bx - ax;  dy = by - ay
      len2 = dx * dx + dy * dy
      return Math.sqrt((px - ax)**2 + (py - ay)**2) if len2 < 1e-6
      t = [([((px - ax) * dx + (py - ay) * dy) / len2, 0.0].max), 1.0].min
      ex = ax + t * dx;  ey = ay + t * dy
      Math.sqrt((px - ex)**2 + (py - ey)**2)
    end

    # Live update of draft via_pts while a marker is being dragged.
    # Rebuilds the bezier for every draft that uses +num+ so the curve
    # tracks the marker in real time without committing to the model.
    def update_draft_via_pt(num, pt)
      @@draft_connections.each_with_index do |draft, idx|
        i = draft[:via_marker_nums].index(num)
        next unless i
        draft[:via_pts][i] = pt
        rebuild_draft_paths(idx)
      end
    end

    # Commit a marker drag: move the SketchUp group to new_pt, update all
    # affected draft via_pts, and persist via_markers to JSON.
    def commit_marker_move(model, num, new_pt)
      return unless new_pt
      g = model.entities.find { |e|
        e.is_a?(Sketchup::Group) && e.name == "JPod Marker" &&
        e.get_attribute("JPods", "marker_number", 0).to_i == num
      }
      return unless g && g.valid?
      b            = g.bounds
      old_beam_z   = g.get_attribute("JPods", "beam_z") || b.min.z
      current_base = Geom::Point3d.new(b.center.x, b.center.y, old_beam_z.to_f)
      offset       = new_pt - current_base
      model.start_operation("Move JPod Waypoint W#{num}", true)
      g.transform!(Geom::Transformation.translation(offset))
      g.set_attribute("JPods", "beam_z", new_pt.z)   # update stored beam elevation
      model.commit_operation
      # Update all drafts using this marker, write JSON for the active one
      @@draft_connections.each_with_index do |draft, idx|
        i = draft[:via_marker_nums].index(num)
        next unless i
        draft[:via_pts][i] = new_pt
        rebuild_draft_paths(idx)
      end
      if !@@last_draft_idx.nil? && (draft = @@draft_connections[@@last_draft_idx])
        update_json_via_markers(draft[:conn_id], draft[:via_marker_nums], model)
      end
      collect_markers(model)
      # Drafts already updated by update_draft_via_pt; center_pts need rebuild.
      @@draft_connections.each_with_index do |draft, idx|
        rebuild_draft_paths(idx) if draft[:via_marker_nums].include?(num)
      end
      Sketchup.set_status_text(
        "JPods Connect: W#{num} moved. Press W for another waypoint or click a gate.")
    rescue => ex
      model.abort_operation rescue nil
      puts "[JPods ConnectTool] commit_marker_move: #{ex.message}"
    end

    # Drop a marker at the current cursor InputPoint (called from W key and right-click).
    # Teaching rule: waypoints must be bound to a connection — no free-floating markers.
    def drop_marker_at_cursor(view)
      unless @from_cp || @edit_cp
        Sketchup.set_status_text(
          "JPods: select a CP first (click once for white inspect, " \
          "again to go gold or cyan). Waypoints must be attached to a connection.")
        return
      end
      ip = @cursor_ip
      return unless ip && ip.valid?
      pt = ip.position
      # Snap to terrain + CLEARANCE_HEIGHT — the default beam elevation.
      # ground_z_at skips JPods guideways/stations so the result is actual terrain,
      # not the beam surface the cursor may be hovering over.
      terrain_pt = Terrain.ground_z_at(view.model, pt.x, pt.y)
      pt = Geom::Point3d.new(pt.x, pt.y,
                             terrain_pt.z + Constants::CLEARANCE_HEIGHT)
      model  = view.model
      max_n  = 0
      model.entities.each do |e|
        next unless e.is_a?(Sketchup::Group) && e.name == "JPod Marker"
        n = e.get_attribute("JPods", "marker_number", 0).to_i
        max_n = n if n > max_n
      end
      n = max_n + 1
      model.start_operation("Place JPod Marker #{n}", true)
      g = model.entities.add_group
      g.name = "JPod Marker"
      g.set_attribute("JPods", "marker_number", n)
      g.set_attribute("JPods", "beam_z",       pt.z)   # inches — beam elevation for routing
      # Assign to "JPods Marker" tag so users can show/hide all markers together
      tag = model.layers["JPods Marker"] || model.layers.add("JPods Marker")
      g.layer = tag
      up  = Geom::Vector3d.new(0, 0, 1)
      g.set_attribute("JPods", "terrain_z", terrain_pt.z)  # inches — for overlay circles

      # Ground-level reference circles (permanent geometry at terrain).
      # Inner ring: 1 m — marks the post footprint.
      # 5 m ring:  helps judge tight-curve radius.
      # 10 m ring: helps judge wide-curve radius.
      cg  = g.entities.add_group
      cmat = model.materials["JPods_MarkerCircle"] || model.materials.add("JPods_MarkerCircle")
      cmat.color = Sketchup::Color.new(255, 140, 0)
      cg.material = cmat
      [1.0.m, 5.0.m, 10.0.m].each do |r|
        segs = r > 2.m ? 48 : 16
        g.entities.add_circle(terrain_pt, up, r, segs)
      end

      # Thin stem from terrain to beam level — shows pole is grounded
      stem_ht = pt.z - terrain_pt.z
      if stem_ht > 0.01.m
        sg   = g.entities.add_group
        smat = model.materials["JPods_MarkerStem"] || model.materials.add("JPods_MarkerStem")
        smat.color = Sketchup::Color.new(160, 80, 0)
        sg.material = smat
        sc = sg.entities.add_circle(terrain_pt, up, 0.06.m, 8)
        if sc.is_a?(Array)
          sf = sg.entities.add_face(sc)
          sf.pushpull(stem_ht) if sf.is_a?(Sketchup::Face)
        end
      end

      # Orange cap post at beam level — base sits at terrain + CLEARANCE_HEIGHT
      pg  = g.entities.add_group
      mat = model.materials["JPods_MarkerPost"] || model.materials.add("JPods_MarkerPost")
      mat.color = Sketchup::Color.new(255, 140, 0)
      pg.material = mat
      c = pg.entities.add_circle(pt, up, 0.12.m, 8)
      if c.is_a?(Array)
        f = pg.entities.add_face(c)
        f.pushpull(Constants::MARKER_POST_HEIGHT) if f.is_a?(Sketchup::Face)
      end
      begin
        top_pt = pt.offset(up, Constants::MARKER_POST_HEIGHT + 0.3.m)
        g.entities.add_text("W#{n}", top_pt)
      rescue; end
      model.commit_operation

      # Route the waypoint to the active state.
      if @from_cp
        # Gold state — accumulate pending waypoints; preview updates in onMouseMove.
        @pending_via_pts  << pt
        @pending_via_nums << n
        # Project the preview TO well past the last waypoint so the bezier
        # visibly bends through it.  Placing a waypoint at the cursor means
        # TO == via_pt → zero-length last segment → curve looks straight.
        to_for_preview = if @hover_cp && !from_cp?(@hover_cp)
          @hover_cp
        else
          last_via = @pending_via_pts.last
          dir      = last_via - @from_cp[:center]
          dir      = Geom::Vector3d.new(1, 0, 0) if dir.length < 0.001
          far_pt   = last_via.offset(dir.normalize, [dir.length, 10.0.m].max)
          synthetic_cp(far_pt, @from_cp)
        end
        @preview_pts = build_dual_preview_via(@from_cp, @pending_via_pts, to_for_preview)
        Sketchup.set_status_text(
          "JPods: W#{n} added — #{@pending_via_nums.size} waypoint(s) pending. " \
          "Press W for more, then click the destination CP.")

      elsif @edit_cp
        # Cyan state — add waypoint to existing connection.
        # Update the draft IN-MEMORY first (source of truth for green bezier),
        # then persist to JSON so Network Editor and Build both see it.
        @pending_via_pts  << pt
        @pending_via_nums << n
        d = draft_for_cp(@edit_cp)
        if d
          other = other_cp_in_draft(d, @edit_cp)
          d[:via_pts]         = @pending_via_pts.dup
          d[:via_marker_nums] = @pending_via_nums.dup
          idx = @@draft_connections.index(d)
          rebuild_draft_paths(idx) if idx
          @edit_preview_pts = build_dual_preview_via(@edit_cp, @pending_via_pts, other)
          update_json_via_markers(d[:conn_id], @pending_via_nums, model)
        end
        Sketchup.set_status_text(
          "JPods: W#{n} added to connection — #{@pending_via_nums.size} waypoint(s). " \
          "Press W for more or Esc when done.")

      end
      view.invalidate
    end

    # Screen-space snap — always matches what the eye sees regardless of zoom.
    def nearest_cp_px(view, sx, sy)
      best      = nil
      best_dist = RING_SNAP_PX
      @cps.each do |cp|
        sc = view.screen_coords(cp[:center]) rescue next
        d  = Math.sqrt((sc.x - sx)**2 + (sc.y - sy)**2)
        if d < best_dist
          best_dist = d
          best      = cp
        end
      end
      best
    end

    # World-space fallback: identical to su_mostly nearest_cp.
    # Guaranteed to work regardless of screen_coords behavior.
    def nearest_cp_world(cursor_pt)
      best      = nil
      best_dist = SNAP_RADIUS_M
      @cps.each do |cp|
        d = cursor_pt.distance(cp[:center])
        if d < best_dist
          best_dist = d
          best      = cp
        end
      end
      best
    end

    # Try pixel snap first; fall back to world-space if screen_coords fails or misses.
    def best_cp(view, sx, sy, cursor_pt)
      nearest_cp_px(view, sx, sy) || nearest_cp_world(cursor_pt)
    end

    # Synthetic CP pointing from from_cp toward an arbitrary world point,
    # used so the preview follows the cursor even when not near a real CP.
    def synthetic_cp(cursor_pt, from_cp)
      vec = cursor_pt - from_cp[:center]
      vec = Geom::Vector3d.new(1, 0, 0) if vec.length < 0.001
      {
        struct_id:   nil,
        stub:        nil,
        center:      cursor_pt,
        tangent:     vec.normalize,
        half_offset: from_cp[:half_offset],
      }
    end

    # ── Gate ring drawing ─────────────────────────────────────────────────────

    # Draws:
    #   • A 3D gate bar spanning both track positions (world context)
    #   • A short tangent whisker (outbound direction)
    #   • A 2D screen-space ring at a fixed pixel radius — always visible
    #   • A text label: StructureID.CPn
    def draw_gate(view, cp, color, width)
      perp      = horiz_perp(cp[:tangent])
      half_off  = [cp[:half_offset], 0.5.m].max   # at least 0.5 m so bar is visible
      left_tip  = cp[:center].offset(perp,         half_off)
      right_tip = cp[:center].offset(perp.reverse, half_off)

      view.line_width    = width + 1
      view.drawing_color = color

      # 3D gate bar
      view.draw(GL_LINE_STRIP, [left_tip, right_tip])

      # Tangent whisker
      whisker_end = cp[:center].offset(cp[:tangent].normalize, half_off * 0.8)
      view.draw(GL_LINE_STRIP, [cp[:center], whisker_end])

      # ── 2D overlay ring — fixed screen size, always clickable ──────────
      sc = view.screen_coords(cp[:center]) rescue nil
      return unless sc
      sx = sc.x;  sy = sc.y
      ring_pts = (0...CIRCLE_SEGS).map do |i|
        a = 2.0 * Math::PI * i / CIRCLE_SEGS
        Geom::Point3d.new(sx + Math.cos(a) * RING_RADIUS_PX,
                          sy + Math.sin(a) * RING_RADIUS_PX, 0)
      end
      view.line_width    = width + 1
      view.drawing_color = color
      view.draw2d(GL_LINE_LOOP, ring_pts)

      # Label (offset right of ring)
      label_pt = Geom::Point3d.new(sx + RING_RADIUS_PX + 4, sy - 6, 0)
      cp_label = JPods::ConnectionPoint.new(structure_id: cp[:struct_id], index: cp[:stub]).to_key
      view.draw_text(label_pt, cp_label,
                     { size: 33, bold: true, color: color }) rescue
        view.draw_text(label_pt, cp_label)
    end

    # Bounding box hint so SketchUp never culls the tool's viewport drawing.
    def getExtents
      bb = Geom::BoundingBox.new
      @cps.each { |cp| bb.add(cp[:center]) }
      @built_paths.each   { |pts| pts.each { |pt| bb.add(pt) } }
      @@draft_connections.each { |d|
        (d[:center_pts] || []).each { |pt| bb.add(pt) }
        (d[:paths] || []).each { |pts| pts.each { |pt| bb.add(pt) } }
      }
      bb.empty? ? Sketchup.active_model.bounds : bb
    end

    # ── Preview geometry ──────────────────────────────────────────────────────

    def build_preview(from_cp, to_cp)
      center_pts = bezier_pts(from_cp, to_cp)   # adaptive n from PREVIEW_SEG_M
      half_off   = (from_cp[:half_offset] + to_cp[:half_offset]) / 2.0
      [
        offset_path(center_pts,  half_off),
        offset_path(center_pts, -half_off),
      ]
    end

    # Cubic Bezier with chord/3 handles — same algorithm as Network.tangent_curve_pts.
    # n is adaptive: one point per PREVIEW_SEG_M of chord, minimum BEZIER_SEGS.
    def bezier_pts(from_cp, to_cp, n: nil)
      p0 = from_cp[:center]
      p1 = to_cp[:center]

      # CP vector requirement: the bezier must leave from_cp in its outbound
      # vector direction and approach to_cp from its outbound vector direction.
      # No chord-snapping — all CP tangents are outbound by invariant (2026-04-29).
      # The 2026-04-17 dot-product workaround is removed: it was needed when
      # pair_stubs stored inbound tangents; that inconsistency no longer exists.
      t0 = from_cp[:tangent].normalize
      t1 = to_cp[:tangent].normalize

      chord = p0.distance(p1)
      n   ||= [[(chord / PREVIEW_SEG_M).ceil, BEZIER_SEGS].max, 512].min
      scale = chord / 3.0
      c0    = p0.offset(t0, scale)
      c1    = p1.offset(t1, scale)

      (0..n).map do |i|
        t  = i.to_f / n
        mt = 1.0 - t
        Geom::Point3d.new(
          mt*mt*mt * p0.x + 3*mt*mt*t * c0.x + 3*mt*t*t * c1.x + t*t*t * p1.x,
          mt*mt*mt * p0.y + 3*mt*mt*t * c0.y + 3*mt*t*t * c1.y + t*t*t * p1.y,
          mt*mt*mt * p0.z + 3*mt*mt*t * c0.z + 3*mt*t*t * c1.z + t*t*t * p1.z
        )
      end
    end

    def offset_path(pts, dist)
      return pts if pts.size < 2 || dist.abs < 0.001
      n = pts.size
      pts.each_with_index.map do |pt, i|
        dir = case i
              when 0     then horiz_unit(pts[0],     pts[1])
              when n - 1 then horiz_unit(pts[n-2],   pts[n-1])
              else
                d1 = horiz_unit(pts[i-1], pts[i])
                d2 = horiz_unit(pts[i],   pts[i+1])
                avg = Geom::Vector3d.new((d1.x+d2.x)/2.0, (d1.y+d2.y)/2.0, 0)
                avg_len = avg.length
                if avg_len > 0.001
                  # Miter cap: never shift the offset point more than 3× |dist|
                  # from the center point — prevents spikes at sharp turns.
                  miter = [1.0 / avg_len, 3.0].min
                  n_vec = avg.normalize
                  Geom::Vector3d.new(n_vec.x * miter, n_vec.y * miter, n_vec.z * miter)
                else
                  d1
                end
              end
        perp = Geom::Vector3d.new(-dir.y, dir.x, 0)
        Geom::Point3d.new(pt.x + perp.x * dist, pt.y + perp.y * dist, pt.z)
      end
    end

    def horiz_unit(a, b)
      dx = b.x - a.x;  dy = b.y - a.y
      len = Math.sqrt(dx*dx + dy*dy)
      return Geom::Vector3d.new(1, 0, 0) if len < 0.001
      Geom::Vector3d.new(dx/len, dy/len, 0)
    end

    def horiz_perp(tangent)
      t = Geom::Vector3d.new(tangent.x, tangent.y, 0)
      t = Geom::Vector3d.new(1, 0, 0) if t.length < 0.001
      t = t.normalize
      Geom::Vector3d.new(-t.y, t.x, 0)
    end

    # ── Commit — write to JSON and push into whichever dialog is live ─────────

    def commit(view, from_cp, to_cp, pending_via_pts = [], pending_via_nums = [])
      model   = view.model
      from_sid_lc = from_cp[:struct_id]
      to_sid_lc   = to_cp[:struct_id]
      conn_id = "#{from_cp[:struct_id].downcase}.#{from_cp[:stub]}_#{to_cp[:struct_id].downcase}.#{to_cp[:stub]}"

      conn = {
        "id"          => conn_id,
        "from"        => { "structure_id" => from_cp[:struct_id],
                           "stub"         => from_cp[:stub] },
        "to"          => { "structure_id" => to_cp[:struct_id],
                           "stub"         => to_cp[:stub] },
        "via_markers" => pending_via_nums,
      }

      # ── Write to network.json ─────────────────────────────────────────────────
      begin
        json_path = (NetworkEditor.default_network_json_path(model) rescue nil)
        json_path = File.join(Dir.tmpdir, 'jpods_network.json') if json_path.nil? || json_path.empty?

        root = File.exist?(json_path) ?
                 (JSON.parse(File.read(json_path, encoding: "utf-8")) rescue {}) : {}
        root = {} unless root.is_a?(Hash)
        root["connections"] ||= {}

        # Reject if either CP is already used (each gate connects to exactly one partner).
        cp_used = ->(conns_hash, sid, stub) {
          conns_hash.any? do |_cp_id, entry|
            next false unless entry.is_a?(Hash)
            entry.any? do |_k, v|
              next false unless v.is_a?(Hash) && v["from"]
              (v.dig("from","structure_id") == sid && v.dig("from","stub").to_i == stub.to_i) ||
              (v.dig("to","structure_id")   == sid && v.dig("to","stub").to_i   == stub.to_i)
            end
          end
        }
        if cp_used.(root["connections"], from_cp[:struct_id], from_cp[:stub])
          Sketchup.set_status_text("JPods Connect: #{from_cp[:struct_id].downcase}.#{from_cp[:stub]} already connected. Select a free gate.")
          return
        end
        if cp_used.(root["connections"], to_cp[:struct_id], to_cp[:stub])
          Sketchup.set_status_text("JPods Connect: #{to_cp[:struct_id].downcase}.#{to_cp[:stub]} already connected. Select a free gate.")
          return
        end

        # Build the nested network.json entry for this cp_ connection.
        # Segment IDs: lowercase station, numeric CP index only (no "cp" prefix).
        fwd_seg_id = "seg_#{from_cp[:struct_id].downcase}_#{from_cp[:stub]}_#{to_cp[:struct_id].downcase}_#{to_cp[:stub]}"
        rev_seg_id = "seg_#{to_cp[:struct_id].downcase}_#{to_cp[:stub]}_#{from_cp[:struct_id].downcase}_#{from_cp[:stub]}"
        rev_id     = "#{to_cp[:struct_id].downcase}.#{to_cp[:stub]}_#{from_cp[:struct_id].downcase}.#{from_cp[:stub]}"

        root["connections"].delete(conn_id)
        root["connections"].delete(rev_id)
        root["connections"][conn_id] = {
          "via_markers" => pending_via_nums,
          fwd_seg_id    => {
            "from"      => { "structure_id" => from_cp[:struct_id], "stub" => from_cp[:stub] },
            "to"        => { "structure_id" => to_cp[:struct_id],   "stub" => to_cp[:stub]   },
            "length_mm" => nil,
          },
          rev_seg_id    => {
            "from"      => { "structure_id" => to_cp[:struct_id],   "stub" => to_cp[:stub]   },
            "to"        => { "structure_id" => from_cp[:struct_id], "stub" => from_cp[:stub] },
            "length_mm" => nil,
          },
        }
        FileUtils.mkdir_p(File.dirname(json_path))
        File.write(json_path, JSON.pretty_generate(root), encoding: "utf-8")
        puts "JPodConnectTool: wrote #{conn_id} → network.json"
        NetworkEditor.push_network_json(root, json_path)
        JPods::Project.note_unmanaged_project(model) if defined?(JPods::Project)
      rescue => ex
        puts "JPodConnectTool: could not update network.json: #{ex.message}"
        puts ex.backtrace.first(3).join("\n")
      end

      conn_id   # return so caller can record the draft
    end

    # ── Draft connection tracking ─────────────────────────────────────────────

    def record_draft(from_cp, to_cp, conn_id, via_pts: [], via_nums: [])
      # Reactivate an existing draft so re-clicking FROM→TO selects it without
      # resetting its waypoints.  Merge any newly-passed via points on top.
      existing_idx = @@draft_connections.index { |d| d[:conn_id] == conn_id }
      if existing_idx
        d = @@draft_connections[existing_idx]
        if via_nums.any?
          d[:via_pts]         = via_pts
          d[:via_marker_nums] = via_nums
          rebuild_draft_paths(existing_idx)
        end
        @@last_draft_idx   = existing_idx
        @active_bezier_pts = d[:paths]
        return
      end
      draft = {
        conn_id:         conn_id,
        from_cp:         from_cp,
        to_cp:           to_cp,
        via_pts:         via_pts.dup,
        via_marker_nums: via_nums.dup,
        paths:           build_dual_preview_via(from_cp, via_pts, to_cp),
        center_pts:      (bezier_pts_via(from_cp, via_pts, to_cp) rescue []),
      }
      @@draft_connections << draft
      @@last_draft_idx = @@draft_connections.size - 1
      @active_bezier_pts = draft[:paths]
    end

    # Rebuild dual-track Bezier paths and green center spline for the draft at +idx+.
    def rebuild_draft_paths(idx)
      d = @@draft_connections[idx]
      return unless d
      d[:paths]      = build_dual_preview_via(d[:from_cp], d[:via_pts], d[:to_cp])
      d[:center_pts] = (bezier_pts_via(d[:from_cp], d[:via_pts], d[:to_cp]) rescue [])
      @active_bezier_pts = d[:paths] if idx == @@last_draft_idx
    end

    # Build dual-track Bezier (centerline ± half_offset) through optional via_pts.
    # Splits into segments: FROM→v1→v2→…→TO, each a cubic Bezier arc.
    #
    # Z profile: preview uses flat-Z — each point's Z is linearly interpolated
    # between from_cp.z and to_cp.z based on cumulative XY arc fraction.
    # The preview is a routing aid for XY layout; actual Z profile is computed
    # by PathBuilder.apply_vertical_profile at Build time.
    def build_dual_preview_via(from_cp, via_pts, to_cp)
      center_pts = bezier_pts_via(from_cp, via_pts, to_cp)

      # Flatten Z: linear interp from from_cp.z → to_cp.z by XY arc fraction.
      if center_pts.size >= 2
        xy_dists = [0.0]
        center_pts.each_cons(2) do |a, b|
          dx = b.x - a.x; dy = b.y - a.y
          xy_dists << xy_dists.last + Math.sqrt(dx * dx + dy * dy)
        end
        total = xy_dists.last
        z0 = from_cp[:center].z
        z1 = to_cp[:center].z
        if total > 0.001
          center_pts = center_pts.each_with_index.map do |pt, i|
            frac = xy_dists[i] / total
            Geom::Point3d.new(pt.x, pt.y, z0 + frac * (z1 - z0))
          end
        end
      end

      half_off = (from_cp[:half_offset] + to_cp[:half_offset]) / 2.0
      half_off = 1.5.m if half_off < 0.001
      [
        offset_path(center_pts,  half_off),
        offset_path(center_pts, -half_off),
      ]
    end

    # Catmull-Rom cubic spline through via_pts — smooth, no zigzags.
    # C1-continuous at every waypoint: T_i = (P_{i+1} - P_{i-1}) / 2
    # so tangents agree across joins and the curve bends evenly between markers.
    # Endpoints use the CP gate tangent at chord/1 scale (matching bezier_pts).
    def bezier_pts_via(from_cp, via_pts, to_cp, n: nil)
      # Adaptive segment count: one point per PREVIEW_SEG_M of total path length.
      chord = from_cp[:center].distance(to_cp[:center])
      n   ||= [[(chord / PREVIEW_SEG_M).ceil, BEZIER_SEGS].max, 512].min
      return bezier_pts(from_cp, to_cp, n: n) if via_pts.empty?

      # Sort waypoints by projection onto the FROM→TO axis so that placing a
      # marker between two existing ones slots it in the right position
      # regardless of the order they were dropped.  XY distance along the
      # main axis determines sequence; off-axis position is preserved exactly.
      if via_pts.size > 1
        axis = to_cp[:center] - from_cp[:center]
        a_len = axis.length
        if a_len > 0.001
          via_pts = via_pts.sort_by { |p| (p - from_cp[:center]).dot(axis) / a_len }
        end
      end

      pts = [from_cp[:center]] + via_pts + [to_cp[:center]]
      m   = pts.size

      # Tangent vectors: T_i such that Bezier C0 = Pi + Ti/3, C1 = Pi+1 - Ti+1/3
      tangents = Array.new(m)

      # FROM endpoint: CP vector requirement — depart in the outbound direction.
      d0  = pts[0].distance(pts[1])
      t0  = from_cp[:tangent].normalize
      tangents[0] = Geom::Vector3d.new(t0.x * d0, t0.y * d0, t0.z * d0)

      # TO endpoint: curve must arrive inward (into the gate), so the velocity
      # at the terminal point is the REVERSE of the outbound tangent.
      # to_cp[:tangent] is outbound (away from station); arrival = its reverse.
      # (Matches bezier_spline_pts in jpod_network.rb which also uses .reverse)
      dn  = pts[m - 2].distance(pts[m - 1])
      t1  = to_cp[:tangent].normalize.reverse
      tangents[m - 1] = Geom::Vector3d.new(t1.x * dn, t1.y * dn, t1.z * dn)

      # Interior waypoints: Catmull-Rom direction, magnitude clamped to
      # min(d_prev, d_next).  Prevents overshoot when a waypoint is placed
      # between two existing waypoints — regardless of how close they are.
      (1...m - 1).each do |i|
        diff   = pts[i + 1] - pts[i - 1]   # Vector3d
        cr_len = diff.length * 0.5          # unclamped Catmull-Rom magnitude
        if cr_len > 1e-6
          d_prev = pts[i].distance(pts[i - 1])
          d_next = pts[i].distance(pts[i + 1])
          scale  = [d_prev, d_next].min / cr_len  # ≤ 1 → can only shrink
          scale  = 1.0 if scale > 1.0             # never stretch
          tangents[i] = Geom::Vector3d.new(diff.x * 0.5 * scale,
                                            diff.y * 0.5 * scale,
                                            diff.z * 0.5 * scale)
        else
          tangents[i] = tangents[i - 1] || Geom::Vector3d.new(0, 0, 0)
        end
      end

      # Forward-agreement: ensure T_i doesn't point backward into the
      # NEXT segment.  A backward tangent makes the cubic loop around
      # the marker (the swirl) before reaching the next point.
      # Fix: remove the backward component; if the result is near-zero,
      # replace with the angle-bisector of the two adjacent segments.
      (1...m - 1).each do |i|
        fwd = pts[i + 1] - pts[i]
        next if fwd.length < 1e-6
        next if tangents[i].dot(fwd) >= 0   # already forward — fine
        unit = fwd.normalize
        dot  = tangents[i].dot(unit)
        proj = Geom::Vector3d.new(unit.x * dot, unit.y * dot, unit.z * dot)
        tangents[i] = tangents[i] - proj
        if tangents[i].length < 1e-6
          bwd = pts[i] - pts[i - 1]
          bis = fwd.normalize + bwd.normalize
          s   = [pts[i].distance(pts[i - 1]), pts[i].distance(pts[i + 1])].min * 0.4
          if bis.length > 1e-6
            bn = bis.normalize
            tangents[i] = Geom::Vector3d.new(bn.x * s, bn.y * s, bn.z * s)
          else
            tangents[i] = Geom::Vector3d.new(0, 0, 0)
          end
        end
      end

      # Concatenate cubic Bezier segments using Hermite → Bezier control points
      segs_n = [n / (via_pts.size + 1), 6].max
      result = []

      (0...m - 1).each do |i|
        p0 = pts[i];       p1 = pts[i + 1]
        ti = tangents[i];  tj = tangents[i + 1]

        c0x = p0.x + ti.x / 3.0;  c0y = p0.y + ti.y / 3.0;  c0z = p0.z + ti.z / 3.0
        c1x = p1.x - tj.x / 3.0;  c1y = p1.y - tj.y / 3.0;  c1z = p1.z - tj.z / 3.0

        seg = (0..segs_n).map { |k|
          t  = k.to_f / segs_n
          mt = 1.0 - t
          a  = mt * mt * mt;  b = 3.0 * mt * mt * t
          c  = 3.0 * mt * t * t;  d = t * t * t
          Geom::Point3d.new(
            a * p0.x + b * c0x + c * c1x + d * p1.x,
            a * p0.y + b * c0y + c * c1y + d * p1.y,
            a * p0.z + b * c0z + c * c1z + d * p1.z
          )
        }
        result += (i == 0 ? seg : seg[1..])
      end
      result
    end

    # Write updated via_marker numbers for a connection back to network.json.
    def update_json_via_markers(conn_id, marker_nums, model)
      json_path = (NetworkEditor.default_network_json_path(model) rescue nil)
      return if json_path.nil? || json_path.empty? || !File.exist?(json_path)
      begin
        root = JSON.parse(File.read(json_path, encoding: 'utf-8'))
        if root.is_a?(Hash) && root['connections'].is_a?(Hash) && root['connections'][conn_id].is_a?(Hash)
          root['connections'][conn_id]['via_markers'] = marker_nums
          File.write(json_path, JSON.pretty_generate(root), encoding: 'utf-8')
          puts "[JPods ConnectTool] updated via_markers for #{conn_id}: #{marker_nums.inspect}"
          NetworkEditor.push_network_json(root, json_path)
        end
      rescue => ex
        puts "[JPods ConnectTool] update_json_via_markers error: #{ex.message}"
      end
    end

    # On re-entry (activate), rebuild @@draft_connections from network.json so
    # bezier overlays persist across tool deactivation / re-selection.
    def restore_draft_connections(model)
      @@draft_connections = []
      @@last_draft_idx    = nil
      json_path = (NetworkEditor.default_network_json_path(model) rescue nil)
      return if json_path.nil? || !File.exist?(json_path)
      begin
        raw  = JSON.parse(File.read(json_path, encoding: 'utf-8'))
        # Convert network.json nested cp_ hash → flat array for iteration.
        conns = NetworkEditor.feature_connections_to_flat_array(raw['connections'] || {})
        conns.each do |conn|
          from_spec = conn['from'] || {}; to_spec = conn['to'] || {}
          from_sid  = from_spec['structure_id'].to_s
          from_stub = from_spec['stub'].to_i
          to_sid    = to_spec['structure_id'].to_s
          to_stub   = to_spec['stub'].to_i

          from_cp = @cps.find { |cp|
            cp[:struct_id] == from_sid && cp[:stub].to_i == from_stub
          }
          to_cp = @cps.find { |cp|
            cp[:struct_id] == to_sid && cp[:stub].to_i == to_stub
          }

          unless from_cp && to_cp
            puts "[JPods ConnectTool] restore: #{conn['id']} — " \
                 "#{from_cp ? 'from OK' : "from #{from_sid.to_s.downcase}.#{from_stub} NOT FOUND"}, " \
                 "#{to_cp   ? 'to OK'   : "to #{to_sid.to_s.downcase}.#{to_stub} NOT FOUND"} " \
                 "(#{@cps.size} CPs loaded — run Calculate CPs if structures show no CPs)"
            next
          end

          marker_nums = conn['via_markers'] || []
          via_pts = marker_nums.map { |n|
            m = model.entities.find { |e|
              e.is_a?(Sketchup::Group) && e.name == "JPod Marker" &&
              e.get_attribute("JPods", "marker_number", 0).to_i == n.to_i
            }
            next unless m
            b  = m.bounds
            bz = m.get_attribute("JPods", "beam_z")
            rz = bz ? bz.to_f : (b.min.z + Constants::CLEARANCE_HEIGHT)
            Geom::Point3d.new(b.center.x, b.center.y, rz)
          }.compact

          paths      = build_dual_preview_via(from_cp, via_pts, to_cp) rescue []
          center_pts = (bezier_pts_via(from_cp, via_pts, to_cp) rescue [])

          @@draft_connections << {
            conn_id:         conn['id'],
            from_cp:         from_cp,
            to_cp:           to_cp,
            via_pts:         via_pts,
            via_marker_nums: marker_nums,
            paths:           paths,
            center_pts:      center_pts,
          }
        end
        @@last_draft_idx = @@draft_connections.size - 1 unless @@draft_connections.empty?
        @active_bezier_pts = @@draft_connections.last[:paths] unless @@draft_connections.empty?
        puts "[JPods ConnectTool] restored #{@@draft_connections.size} draft connection(s) from JSON"
      rescue => ex
        puts "[JPods ConnectTool] restore_draft_connections: #{ex.message}"
      end
    end

    def set_status_idle
      Sketchup.set_status_text(
        "JPods Connect: click a CP to connect. Shift-click a connection line to delete it. " \
        "Press W to add waypoints. Esc to exit.")
    end

  end  # class JPodConnectTool
end    # module JPods