# ── Compute Phase 3: Geometry Extraction ──────────────────────────────────────
#
# Compute vehicle-path geometry (pts_mm) for every track using math.
# Start from CP markers in model.skp — they are the source of truth.
# Each cp_marker has a hub vertex and two 1750mm arms to the rail centerlines.
# All geometry is derived from these anchor points.
#
# NO CACHE. Every Compute re-reads the model. If extraction fails, fix the model.
#
# See: compute/phase3_geometry.md

module JPods
  module Compute
    module Geometry

      IN_PER_MM = 1.0 / 25.4
      HALF_TRACK_SPACING_MM = 1750.0  # 3500mm / 2 = half of DUAL_TRACK_SPACING
      UTURN_ARC_SEGMENTS = 16         # number of segments in 180° uturn arc

      # Extract geometry for all tracks.
      # Returns { tracks: Hash, failures: Array }
      def self.extract(model, template_data, model_id:)
        des = template_data['designer'] || {}
        tracks_def = des['tracks'] || {}
        failures = []
        tracks = {}  # tag → { pts_mm: [...], length_mm: N, radius_mm: N }

        plugin_dir = File.dirname(File.dirname(__FILE__))

        # ── Read CP markers from model.skp ────────────────────────────────────
        # Each marker gives: hub (center), in_tip (near_main centerline),
        # out_tip (far_main centerline), tangent (outward direction).
        cp_markers = _scan_cp_markers_full(model)
        puts "[Compute] #{cp_markers.size} CP marker(s) found in model"

        if cp_markers.empty?
          failures << "No CP markers found in model — cannot extract geometry"
          puts "[Compute] 🚫 No CP markers — all tracks will fail"
          total = tracks_def.keys.count { |t| t.start_with?('gw_') }
          puts "[Compute] Phase 3: 0/#{total} tracks resolved in 0 pass(es)"
          return { tracks: tracks, failures: failures }
        end

        # ── Priority 0: Synthesize track geometry from cp_markers ──────────
        # cp_markers give hub + tip_a + tip_b + tangent at each end.
        # tip_a/tip_b are the two guideway centerlines (3500mm apart).
        # Which tip is "in" vs "out" is topological — resolved after span walk.

        # Uturn arcs: semicircles connecting tip_a ↔ tip_b at each cp_marker
        _build_uturn_arcs(tracks, tracks_def, cp_markers)

        # CP tracks: straight lines from each tip outward/inward
        _build_cp_tracks(tracks, tracks_def, cp_markers)

        # Main tracks + interior (placeholder — let span resolver handle)
        _build_parallel_tracks(tracks, tracks_def, cp_markers)

        # ── Priority 1: Span-based chain resolution ─────────────────────────────
        succ_of = {}
        pred_of = {}
        tracks_def.each do |tag, td|
          next unless td.is_a?(Hash)
          Array(td['successors']).each do |s|
            next if s.to_s.empty?
            succ_of[tag] ||= s
            pred_of[s] = tag
          end
        end

        _resolve_spans(tracks, tracks_def, succ_of, pred_of, failures)

        # ── Verify tip_a/tip_b assignment ─────────────────────────────────
        # After span resolution, check if tracks connect. If a CP's in_lead
        # has a 3500mm gap to its successor, the tips are swapped. Fix and
        # re-resolve.
        _verify_tip_assignment(tracks, tracks_def, cp_markers)
        # If tips were swapped, uturns and spans need rebuilding too
        if cp_markers.any? { |_, m| m[:swapped] }
          tracks.delete_if { |k, _| k.match?(/\Agw_uturn_/) }
          _build_uturn_arcs(tracks, tracks_def, cp_markers)
          # Re-resolve spans with corrected CP tracks
          _resolve_spans(tracks, tracks_def, succ_of, pred_of, failures)
        end

        # ── CCW correction for ring arcs (gw_c_*) ─────────────────────────────
        _correct_ring_arc_direction(tracks, tracks_def)

        # ── Report unresolved tracks ──────────────────────────────────────────
        still_missing = tracks_def.keys.select { |t|
          t.start_with?('gw_') && !tracks.key?(t)
        }
        still_missing.each do |tag|
          pred_tag = pred_of[tag]
          succ_tag = succ_of[tag]
          pred_ok = pred_tag && tracks[pred_tag] ? '✓' : '✗'
          succ_ok = succ_tag && tracks[succ_tag] ? '✓' : '✗'
          failures << "#{tag}: no geometry (pred #{pred_tag} #{pred_ok}, succ #{succ_tag} #{succ_ok})"
          puts "[Compute] 🚫 #{tag}: unresolved (pred=#{pred_tag} #{pred_ok}, succ=#{succ_tag} #{succ_ok})"
        end

        total = tracks_def.keys.count { |t| t.start_with?('gw_') }
        resolved = total - still_missing.size
        puts "[Compute] Phase 3: #{resolved}/#{total} tracks resolved"

        { tracks: tracks, failures: failures }
      end

      private

      # ── Full CP marker scan ─────────────────────────────────────────────────
      # Reads cp_marker components from model.skp. For each marker, finds:
      #   - hub: the vertex shared by the two 1750mm rail edges (center of CP)
      #   - in_tip: end of the inbound rail arm (near_main centerline)
      #   - out_tip: end of the outbound rail arm (far_main centerline)
      #   - tangent: outward direction perpendicular to the rail span
      #
      # The two rail tips are 3500mm apart (DUAL_TRACK_SPACING). The hub is
      # exactly between them. The tangent points outward from the station.

      # ── cp_marker scan — DEFINITION-LOCAL coordinates only ──────────────
      # Compute is MODEL ONLY. All coordinates stay in definition-local space.
      # Build applies instance transforms to get world coordinates.
      #
      # cp_marker_N contains:
      #   - Hub vertex: shared by the two 1750mm guideway centerline edges
      #   - Two 1750mm edges: each defines one guideway centerline (3500mm apart)
      #   - 222mm edge: direction vector (outward toward network)
      #   - 177mm edge: vertical reference
      #
      # We read vertices from the component DEFINITION — no accumulated
      # parent transforms. The recursive scan finds cp_markers at any nesting
      # depth but only records the component entity and its marker index.

      def self._scan_cp_markers_full(model)
        markers = {}

        # Start scan from the station DEFINITION's entities, not model root.
        # model.skp contains a top-level ComponentInstance of the station which
        # may have a placement transform (rotation). We want coordinates in the
        # definition's local space — same frame as lines.computed.json.
        collected = []
        station_defn_ents = nil
        model.entities.each do |e|
          next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
          sub = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          # Look for the entity that contains gw_* tagged children or cp_markers
          has_station_content = sub.any? { |c|
            (c.respond_to?(:layer) && c.layer.name.to_s.match?(/\Agw_/i) rescue false) ||
            (c.is_a?(Sketchup::ComponentInstance) && c.definition.name.to_s.match?(/cp_marker/i) rescue false)
          }
          if has_station_content
            station_defn_ents = sub
            break
          end
        end
        station_defn_ents ||= model.entities  # fallback
        _collect_cp_markers(station_defn_ents, collected)

        collected.each do |entry|
          e = entry[:entity]
          idx = entry[:marker_index]
          cp_defn = e.definition

          # ── Pure math from points — no edges ─────────────────────────
          # The cp_marker contains points (vertices, construction points,
          # or guide points). Four key positions:
          #   Hub: the intersection point (connected to all lines)
          #   222mm end: ~222mm from hub (direction toward network)
          #   Two 1750mm ends: ~1750mm from hub (guideway centerlines)
          #
          # Collect all point positions, find hub as the point closest
          # to the centroid of all points (the intersection), classify
          # others by distance from hub.

          # Collect all unique positions from any geometry type
          positions = []
          cp_defn.entities.each do |ce|
            case ce
            when Sketchup::Edge
              ce.vertices.each { |v| positions << v.position }
            when Sketchup::ConstructionPoint
              positions << ce.position
            when Sketchup::ConstructionLine
              positions << ce.start if ce.start
              positions << ce.end if ce.end
            end
          end

          # Deduplicate by position (within 0.1mm)
          dedup_tol = 0.1 * IN_PER_MM
          unique_pts = []
          positions.each do |p|
            unless unique_pts.any? { |u| u.distance(p) < dedup_tol }
              unique_pts << p
            end
          end

          # Hub = point closest to centroid (the intersection of all lines)
          if unique_pts.size >= 4
            cx = unique_pts.sum(&:x) / unique_pts.size
            cy = unique_pts.sum(&:y) / unique_pts.size
            cz = unique_pts.sum(&:z) / unique_pts.size
            centroid = Geom::Point3d.new(cx, cy, cz)
            hub_local = unique_pts.min_by { |p| p.distance(centroid) }
          end

          unless hub_local
            puts "[Compute] ⚠ cp_marker_#{idx}: no hub vertex — skipping"
            next
          end

          # Classify other points by distance from hub
          dir_free_local = nil          # ~222mm
          gw_tips = []                  # ~1750mm (two of these)
          outward_tip_local = nil
          inward_tip_local = nil
          tangent_free_end_local = nil

          unique_pts.each do |p|
            next if p.distance(hub_local) < dedup_tol  # skip hub itself
            dist_mm = p.distance(hub_local) * 25.4
            if (dist_mm - 222.0).abs < 50.0
              dir_free_local = p
            elsif (dist_mm - HALF_TRACK_SPACING_MM).abs < 100.0
              gw_tips << p
            end
          end

          unless dir_free_local && gw_tips.size >= 2
            puts "[Compute] ⚠ cp_marker_#{idx}: need 222mm + 2×1750mm from hub — " \
                 "dir=#{dir_free_local ? '✓' : '✗'} tips=#{gw_tips.size}"
            next
          end

          # Cross product distinguishes outbound from inbound:
          #
          #   outbound ←── 1750mm ──── HUB ──── 1750mm ──→ inbound
          #                             │
          #                           222mm
          #                             ↓
          #                         vector_end
          #
          # cross(222mm_direction, tip_offset) Z-component:
          #   positive = outbound tip (gw_cp_out side)
          #   negative = inbound tip (gw_cp_in side)
          dir_dx = dir_free_local.x - hub_local.x
          dir_dy = dir_free_local.y - hub_local.y
          crosses = gw_tips.map { |tp|
            ox = tp.x - hub_local.x
            oy = tp.y - hub_local.y
            dir_dx * oy - dir_dy * ox  # Z-component of cross product
          }
          if crosses[0] > crosses[1]
            outward_tip_local = gw_tips[0]   # outbound (gw_cp_out side)
            inward_tip_local  = gw_tips[1]   # inbound (gw_cp_in side)
          else
            outward_tip_local = gw_tips[1]
            inward_tip_local  = gw_tips[0]
          end
          tangent_free_end_local = dir_free_local

          unless outward_tip_local && inward_tip_local
            puts "[Compute] ⚠ cp_marker_#{idx}: no tips resolved — skipping"
            next
          end

          # ── Apply instance transform ────────────────────────────────
          inst_xf = entry[:instance_xf] || Geom::Transformation.new
          hub_model     = inst_xf * hub_local
          outward_model = inst_xf * outward_tip_local
          inward_model  = inst_xf * inward_tip_local

          # Tangent: deferred until all markers collected — needs hub-to-hub axis.
          # The 222mm vector is perpendicular to the station axis (points toward
          # the network side). The tangent for CP stubs is ALONG the station axis
          # (outward from each end), computed from hub_0 → hub_1 direction.

          # ── Convert to mm (model-local space) ───────────────────────
          hub_mm     = [hub_model.x, hub_model.y, hub_model.z].map { |v| (v * 25.4).round(1) }
          outward_mm = [outward_model.x, outward_model.y, outward_model.z].map { |v| (v * 25.4).round(1) }
          inward_mm  = [inward_model.x, inward_model.y, inward_model.z].map { |v| (v * 25.4).round(1) }

          markers[idx] = {
            hub_mm:       hub_mm,
            outward_mm:   outward_mm,    # outbound tip (gw_cp_out side)
            inward_mm:    inward_mm,     # inbound tip (gw_cp_in side)
            tangent:      nil,           # set in second pass from hub-to-hub axis
            entity:       e
          }

          puts "[Compute] cp_marker_#{idx}: hub=(#{hub_mm.map{|v|v.round(0)}.join(',')})" \
               " outward=(#{outward_mm.map{|v|v.round(0)}.join(',')})" \
               " inward=(#{inward_mm.map{|v|v.round(0)}.join(',')})"
        end

        # ── Compute tangent per marker from hub-to-hub axis ───────────
        # The tangent for CP stubs runs ALONG the station axis, pointing
        # outward from each end. The 222mm vector is perpendicular to the
        # axis (it points toward the network SIDE, not along the axis).
        if markers.size >= 2
          sorted = markers.keys.sort
          h0 = markers[sorted[0]][:hub_mm]
          h1 = markers[sorted[1]][:hub_mm]
          ax = h1[0] - h0[0]; ay = h1[1] - h0[1]
          alen = Math.sqrt(ax*ax + ay*ay)
          if alen > 0.001
            unit_ax = ax / alen; unit_ay = ay / alen
            mid_x = (h0[0] + h1[0]) / 2.0
            mid_y = (h0[1] + h1[1]) / 2.0
            markers.each do |mi, m|
              # Tangent points OUTWARD from model center along the axis.
              # Use dot product with axis to determine which side of center
              # this marker is on — works regardless of axis orientation.
              dot = (m[:hub_mm][0] - mid_x) * ax + (m[:hub_mm][1] - mid_y) * ay
              if dot >= 0
                m[:tangent] = [unit_ax, unit_ay]     # same side as axis end
              else
                m[:tangent] = [-unit_ax, -unit_ay]   # opposite side
              end
              puts "[Compute] cp_marker_#{mi}: tangent=(#{m[:tangent].map{|v|v.round(3)}.join(',')})"
            end
          end
        elsif markers.size == 1
          # Single marker — tangent from 222mm direction (perpendicular, but it's all we have)
          mi, m = markers.first
          m[:tangent] ||= [1.0, 0.0]
          puts "[Compute] cp_marker_#{mi}: tangent=(#{m[:tangent].map{|v|v.round(3)}.join(',')}) [single marker]"
        end

        markers
      rescue => ex
        puts "[Compute] cp_marker scan error: #{ex.message}"
        puts ex.backtrace.first(3).join("\n")
        {}
      end

      # Find cp_marker components at any nesting depth.
      # Records entity, marker index, and the INSTANCE transform.
      #
      # Compute is MODEL ONLY. We need the instance transform (not parent
      # transforms) because multiple cp_markers share the same component
      # definition — the instance transform is what places cp_marker_0
      # at one end of the station and cp_marker_1 at the other.
      #
      # We accumulate parent transforms ONLY within the station's internal
      # nesting (groups inside the template model). This gives us coordinates
      # in the template's model-local space — the same frame as lines.computed.json.
      def self._collect_cp_markers(entities, out, depth = 0, parent_xf: Geom::Transformation.new)
        return if depth > 4
        entities.each do |e|
          case e
          when Sketchup::ComponentInstance
            dname = e.definition.name.to_s.strip.downcase
            tag_name = (e.respond_to?(:tag) ? (e.tag.name rescue '') : (e.layer.name rescue '')).to_s.strip.downcase

            is_cp = dname.match?(/\Acp_marker(_\d+)?\z/) ||
                    dname.match?(/\Acp(#\d+)?\z/) ||
                    dname == 'cp' ||
                    tag_name.match?(/\Acp_marker(_\d+)?\z/) ||
                    tag_name == 'cp'

            is_cp = false if dname.include?('cp_marker_b')

            if is_cp
              lbl = tag_name.empty? ? dname : tag_name
              m = lbl.match(/(\d+)\z/)
              marker_index = m ? m[1].to_i : (e.get_attribute('JPods', 'cp_marker_index', 0).to_i rescue 0)
              # Instance transform places this cp_marker within the model
              out << { entity: e, marker_index: marker_index, instance_xf: parent_xf * e.transformation }
            else
              _collect_cp_markers(e.definition.entities, out, depth + 1, parent_xf: parent_xf * e.transformation)
            end
          when Sketchup::Group
            _collect_cp_markers(e.entities, out, depth + 1, parent_xf: parent_xf * e.transformation)
          end
        end
      rescue => ex
        puts "[Compute] cp_marker scan error at depth #{depth}: #{ex.message}"
      end

      # ── CP tracks (gw_cp_in_N, gw_cp_out_N, gw_cp_in_lead_N, gw_cp_out_lead_N) ──
      # Straight lines from cp_marker guideway centerline tips.
      #
      # The two tips (tip_a, tip_b) are the two guideway centerlines — 3500mm apart.
      # Which tip serves gw_cp_in vs gw_cp_out is topological (from lines.json chains),
      # not geometric. We assign tip_a → gw_cp_in, tip_b → gw_cp_out initially.
      # After the span resolver runs, _verify_tip_assignment checks for 3500mm gaps
      # and swaps if needed.

      def self._build_cp_tracks(tracks, tracks_def, cp_markers)
        tracks_def.each do |tag, _td|
          next if tracks.key?(tag)
          m = tag.match(/\Agw_cp_(in|out)(?:_lead)?_(\d+)\z/)
          next unless m
          direction = m[1]  # "in" or "out"
          cp_n = m[2].to_i
          marker = cp_markers[cp_n]
          next unless marker

          # The cp_marker tip IS the outermost point of the model.
          # ALL tracks extend INWARD (against tangent) from the tip.
          #
          #   cp_marker tip ──── gw_cp_in/out (2500mm inward) ──── gw_cp_in/out_lead (2500mm more inward) ──→ model
          #
          # gw_cp_in:       [tip, tip - tangent*2500]           (network → model)
          # gw_cp_out:      [tip - tangent*2500, tip]           (model → network)
          # gw_cp_in_lead:  [tip - tangent*2500, tip - tangent*5000]   (toward model interior)
          # gw_cp_out_lead: [tip - tangent*5000, tip - tangent*2500]   (from model interior)
          tip = direction == 'in' ? marker[:outward_mm] : marker[:inward_mm]
          tang = marker[:tangent]
          arm_len = 2500.0
          is_lead = tag.include?('_lead_')

          # Junction = 2500mm inward from tip (where gw_cp meets gw_cp_lead and uturn)
          junction = [
            (tip[0] - tang[0] * arm_len).round(1),
            (tip[1] - tang[1] * arm_len).round(1),
            tip[2]
          ]

          if is_lead
            # Lead: from junction another 2500mm inward
            inner_end = [
              (junction[0] - tang[0] * arm_len).round(1),
              (junction[1] - tang[1] * arm_len).round(1),
              tip[2]
            ]
            pts = direction == 'in' ? [junction, inner_end] : [inner_end, junction]
          else
            # gw_cp_in/out: from tip to junction (both inward from cp_marker)
            pts = direction == 'in' ? [tip, junction] : [junction, tip]
          end

          tracks[tag] = { 'pts_mm' => pts, 'length_mm' => arm_len, 'radius_mm' => 0.0 }
          puts "[Compute] #{tag}: #{arm_len.round(0)}mm from cp_marker_#{cp_n}"
        end
      end

      # After span resolution, check if the tip_a/tip_b assignment is correct.
      # If gw_cp_in_lead_N's inner end is 3500mm from gw_near_main's nearest end,
      # the tips are swapped for that CP. Swap and rebuild the CP tracks.
      def self._verify_tip_assignment(tracks, tracks_def, cp_markers)
        swapped = false
        cp_markers.each do |cp_n, marker|
          # Find the successor of gw_cp_in_lead_N — it should connect to near_main
          # or the platform chain. Check the gap.
          in_lead = tracks["gw_cp_in_lead_#{cp_n}"]
          next unless in_lead && in_lead['pts_mm']&.size.to_i >= 2

          # Find what gw_cp_in_lead_N connects to via successors
          td = tracks_def["gw_cp_in_lead_#{cp_n}"]
          next unless td.is_a?(Hash)
          succs = Array(td['successors'])
          succs.each do |succ_tag|
            succ_track = tracks[succ_tag]
            next unless succ_track && succ_track['pts_mm']&.size.to_i >= 2

            # Gap between in_lead inner end and successor start
            in_end = in_lead['pts_mm'].last
            succ_start = succ_track['pts_mm'].first
            gap = Math.sqrt((in_end[0]-succ_start[0])**2 + (in_end[1]-succ_start[1])**2)

            if gap > 2000.0  # > 2m gap means tips are swapped (should be ~0, 3500 = wrong side)
              puts "[Compute] ⚠ cp_marker_#{cp_n}: tip assignment swapped (gap #{gap.round(0)}mm to #{succ_tag}) — correcting"
              marker[:outward_mm], marker[:inward_mm] = marker[:inward_mm], marker[:outward_mm]
              marker[:swapped] = true

              # Rebuild CP tracks for this marker
              %W[gw_cp_in_#{cp_n} gw_cp_out_#{cp_n} gw_cp_in_lead_#{cp_n} gw_cp_out_lead_#{cp_n}].each do |t|
                tracks.delete(t)
              end
              swapped = true
              break
            end
          end
        end

        if swapped
          # Rebuild CP tracks with corrected assignment
          _build_cp_tracks(tracks, tracks_def, cp_markers)
          puts "[Compute] tip assignment corrected — CP tracks rebuilt"
        end
      end

      # ── Parallel main tracks ──────────────────────────────────────────────────
      # gw_far_main, gw_near_main, and their splits (gw_far_main_2, etc.)
      # are parallel bezier curves 3500mm apart, running between cp_marker endpoints.
      # With 2 cp_markers we know both ends of each main. With 1, the chain-walk
      # resolves the missing end from uturn/CP geometry.

      def self._build_parallel_tracks(tracks, tracks_def, cp_markers)
        # With multiple cp_markers, we can compute main tracks directly.
        # The in_tip endpoints define the near_main centerline.
        # The out_tip endpoints define the far_main centerline.
        # For now, let chain-walk handle these from the seeded CP and uturn endpoints.
      end

      # ── Priority 0.2: Uturn arcs ─────────────────────────────────────────────
      # 180° semicircle connecting the two guideway centerlines (tip_a ↔ tip_b)
      # at each cp_marker. gw_uturn_N uses cp_marker_N's tips as arc endpoints.

      def self._build_uturn_arcs(tracks, tracks_def, cp_markers)
        tracks_def.each do |tag, _td|
          next if tracks.key?(tag)  # already read from model
          m = tag.match(/\Agw_uturn_(\d+)\z/)
          next unless m
          uturn_n = m[1].to_i

          # Find the CP marker for this uturn.
          # Uturn N uses cp_marker N's in/out tips as the arc endpoints.
          marker = cp_markers[uturn_n]
          unless marker
            puts "[Compute] ⚠ #{tag}: no cp_marker_#{uturn_n} — skipping"
            next
          end

          # Uturn arc: semicircle connecting the two guideway centerlines (tip_a ↔ tip_b).
          # The arc direction (which tip is start vs end) is determined by the
          # predecessor topology — the predecessor's track type tells us which
          # tip the traffic arrives from.
          pred_tag = nil
          tracks_def.each do |t, td|
            next unless td.is_a?(Hash)
            if Array(td['successors']).include?(tag)
              pred_tag = t
            end
          end

          # Uturn is at the JUNCTION — 2500mm inward from cp_marker tip.
          tang = marker[:tangent] || [0, 0]
          junc_off = 2500.0
          out_junc = [
            (marker[:outward_mm][0] - tang[0] * junc_off).round(1),
            (marker[:outward_mm][1] - tang[1] * junc_off).round(1),
            marker[:outward_mm][2]
          ]
          in_junc = [
            (marker[:inward_mm][0] - tang[0] * junc_off).round(1),
            (marker[:inward_mm][1] - tang[1] * junc_off).round(1),
            marker[:inward_mm][2]
          ]

          # Uturn arc: semicircle curving OUTSIDE the station (away from center).
          # Always from in_junc → out_junc. The _semicircle_pts arc direction
          # is determined by the start→end order; in→out curves outward.
          start_pt = in_junc
          end_pt   = out_junc

          hub = [
            (marker[:hub_mm][0] - tang[0] * junc_off).round(1),
            (marker[:hub_mm][1] - tang[1] * junc_off).round(1),
            marker[:hub_mm][2]
          ]
          pts = _semicircle_pts(start_pt, end_pt, hub, UTURN_ARC_SEGMENTS)

          arc_len = pts.each_cons(2).sum { |a, b|
            Math.sqrt((b[0]-a[0])**2 + (b[1]-a[1])**2 + (b[2]-a[2])**2)
          }.round(1)

          min_r = _min_radius_mm(pts)
          tracks[tag] = { 'pts_mm' => pts, 'length_mm' => arc_len, 'radius_mm' => (min_r || 0.0).round(1) }
          puts "[Compute] #{tag}: uturn arc #{arc_len.round(0)}mm, #{pts.size} pts from cp_marker_#{uturn_n}"
        end
      end

      # ── Semicircle point generation ────────────────────────────────────────
      # 180° arc from start_pt to end_pt, curving around center_pt.
      # Z interpolates linearly from start_pt[2] to end_pt[2].

      def self._semicircle_pts(start_pt, end_pt, center_pt, n_segments)
        # Vectors from center to start and end (XY plane)
        r1x = start_pt[0] - center_pt[0]
        r1y = start_pt[1] - center_pt[1]
        r2x = end_pt[0] - center_pt[0]
        r2y = end_pt[1] - center_pt[1]

        # Radius (should be ~1750mm for both)
        radius = Math.sqrt(r1x*r1x + r1y*r1y)

        # Start angle
        theta_start = Math.atan2(r1y, r1x)

        # Determine arc direction: which way (CW or CCW) gets us from start to end
        # in ~180°. Cross product tells us.
        cross = r1x * r2y - r1y * r2x
        # cross > 0 → CCW from start to end; cross < 0 → CW
        arc_dir = cross >= 0 ? 1.0 : -1.0

        pts = (0..n_segments).map { |i|
          t = i.to_f / n_segments
          theta = theta_start + arc_dir * Math::PI * t
          z = start_pt[2] + (end_pt[2] - start_pt[2]) * t
          [
            (center_pt[0] + radius * Math.cos(theta)).round(1),
            (center_pt[1] + radius * Math.sin(theta)).round(1),
            z.round(1)
          ]
        }
        pts
      end

      # ── Span-based chain resolution ──────────────────────────────────────
      # Finds spans of consecutive unresolved tracks between two resolved
      # endpoints. Generates one bezier for the full span, splits evenly
      # among the tracks in the span.

      def self._resolve_spans(tracks, tracks_def, succ_of, pred_of, failures)
        resolved_total = 0

        # Walk each chain from a resolved track forward through unresolved spans.
        # A span starts when we step from a resolved track into an unresolved one,
        # and ends when we reach another resolved track.
        visited_spans = {}

        tracks.keys.each do |start_tag|
          next unless start_tag.start_with?('gw_')
          succ_tag = succ_of[start_tag]
          next unless succ_tag
          next if tracks.key?(succ_tag)  # successor already resolved — no span

          # Walk forward through unresolved tracks
          span = []
          current = succ_tag
          while current && !tracks.key?(current)
            span << current
            current = succ_of[current]
          end

          # current is now the first resolved track after the span (or nil)
          next unless current && tracks.key?(current)
          next if span.empty?

          span_key = span.join(',')
          next if visited_spans[span_key]
          visited_spans[span_key] = true

          # We have: start_tag(resolved) → [span tracks] → current(resolved)
          span_start = tracks[start_tag]['pts_mm'].last
          span_end   = tracks[current]['pts_mm'].first

          # Generate bezier for full span
          full_pts = _generate_bezier(span_start, span_end, "span:#{span.first}..#{span.last}")
          next unless full_pts && full_pts.size >= 2

          # Split evenly among span tracks
          n_tracks = span.size
          pts_per_track = [(full_pts.size / n_tracks.to_f).ceil, 2].max

          span.each_with_index do |tag, i|
            # Slice the bezier points for this track
            from_idx = (i * (full_pts.size - 1).to_f / n_tracks).round
            to_idx   = ((i + 1) * (full_pts.size - 1).to_f / n_tracks).round
            to_idx = full_pts.size - 1 if i == n_tracks - 1  # last track gets the end
            track_pts = full_pts[from_idx..to_idx]
            track_pts = [full_pts[from_idx], full_pts[to_idx]] if track_pts.size < 2

            arc_len = track_pts.each_cons(2).sum { |a, b|
              Math.sqrt((b[0]-a[0])**2 + (b[1]-a[1])**2 + (b[2]-a[2])**2)
            }.round(1)

            min_r = _min_radius_mm(track_pts)
            tracks[tag] = { 'pts_mm' => track_pts, 'length_mm' => arc_len, 'radius_mm' => (min_r || 0.0).round(1) }

            if min_r && min_r < 1750.0 && !tag.match?(/uturn/)
              failures << "#{tag}: curve radius #{min_r.round(0)}mm < 1750mm minimum turn radius"
            end

            resolved_total += 1
            puts "[Compute] span: #{tag} (#{track_pts.size}pts, #{arc_len.round(0)}mm) " \
                 "[#{start_tag}→...→#{current}]"
          end
        end

        puts "[Compute] span resolution: #{resolved_total} track(s) resolved" if resolved_total > 0
      end

      # ── CCW correction for ring arcs ──────────────────────────────────────
      def self._correct_ring_arc_direction(tracks, tracks_def)
        succ_of = {}
        tracks_def.each do |tag, td|
          next unless td.is_a?(Hash)
          Array(td['successors']).each do |s|
            next if s.to_s.empty?
            succ_of[tag] ||= []
            succ_of[tag] << s
          end
        end

        corrected = 0
        tracks_def.each_key do |tag|
          next unless tag.match?(/\Agw_in_\d+\z/)
          entry = tracks[tag]
          next unless entry && entry['pts_mm'].is_a?(Array) && entry['pts_mm'].size >= 2
          entry_end = entry['pts_mm'].last

          (succ_of[tag] || []).each do |succ_tag|
            next unless succ_tag.match?(/\Agw_c_/)
            arc = tracks[succ_tag]
            next unless arc && arc['pts_mm'].is_a?(Array) && arc['pts_mm'].size >= 2

            arc_first = arc['pts_mm'].first
            arc_last  = arc['pts_mm'].last
            dist_fwd = Math.sqrt((entry_end[0]-arc_first[0])**2 + (entry_end[1]-arc_first[1])**2)
            dist_rev = Math.sqrt((entry_end[0]-arc_last[0])**2  + (entry_end[1]-arc_last[1])**2)

            if dist_rev < dist_fwd
              arc['pts_mm'] = arc['pts_mm'].reverse
              corrected += 1
              puts "[Compute] CCW fix: #{succ_tag} reversed (was CW, entry gap #{dist_fwd.round(0)}mm → #{dist_rev.round(0)}mm)"
            end
          end
        end

        ring_arcs = tracks.keys.select { |t| t.match?(/\Agw_c_\d+_\d+\z/) }.sort
        5.times do
          changed = 0
          ring_arcs.each do |arc_tag|
            arc = tracks[arc_tag]
            next unless arc && arc['pts_mm'].size >= 2
            arc_end = arc['pts_mm'].last

            (succ_of[arc_tag] || []).each do |succ_tag|
              next unless succ_tag.match?(/\Agw_c_/) || succ_tag.match?(/\Agw_out_/)
              succ = tracks[succ_tag]
              next unless succ && succ['pts_mm'].is_a?(Array) && succ['pts_mm'].size >= 2

              next unless succ_tag.match?(/\Agw_c_/)
              succ_first = succ['pts_mm'].first
              succ_last  = succ['pts_mm'].last
              dist_fwd = Math.sqrt((arc_end[0]-succ_first[0])**2 + (arc_end[1]-succ_first[1])**2)
              dist_rev = Math.sqrt((arc_end[0]-succ_last[0])**2  + (arc_end[1]-succ_last[1])**2)

              if dist_rev < dist_fwd
                succ['pts_mm'] = succ['pts_mm'].reverse
                corrected += 1
                changed += 1
                puts "[Compute] CCW fix: #{succ_tag} reversed (chain from #{arc_tag})"
              end
            end
          end
          break if changed == 0
        end

        puts "[Compute] CCW correction: #{corrected} ring arc(s) reversed" if corrected > 0
      end

      # ── Minimum curve radius from pts_mm ─────────────────────────────────
      def self._min_radius_mm(pts)
        return nil unless pts.size >= 3
        min_r = Float::INFINITY
        pts.each_cons(3) do |a, b, c|
          ax, ay = a[0].to_f, a[1].to_f
          bx, by = b[0].to_f, b[1].to_f
          cx, cy = c[0].to_f, c[1].to_f
          d = 2.0 * ((bx - ax) * (cy - ay) - (by - ay) * (cx - ax))
          next if d.abs < 1e-6
          ab = Math.sqrt((bx-ax)**2 + (by-ay)**2)
          bc = Math.sqrt((cx-bx)**2 + (cy-by)**2)
          ca = Math.sqrt((ax-cx)**2 + (ay-cy)**2)
          r = (ab * bc * ca) / d.abs
          min_r = r if r < min_r
        end
        min_r < 1e9 ? min_r : nil
      end

      # ── Bezier generation from two endpoints ───────────────────────────────

      def self._generate_bezier(sp, ep, tag)
        dx = ep[0] - sp[0]; dy = ep[1] - sp[1]; dz = ep[2] - sp[2]
        chord = Math.sqrt(dx*dx + dy*dy + dz*dz)
        return nil if chord < 10

        n_pts = [(chord / 1000.0).ceil + 1, 4].max

        pts = (0...n_pts).map { |i|
          t = i.to_f / (n_pts - 1)
          t_z = t * t * (3.0 - 2.0 * t)
          [
            (sp[0] + dx * t).round(1),
            (sp[1] + dy * t).round(1),
            (sp[2] + dz * t_z).round(1)
          ]
        }
        pts
      end

    end
  end
end
