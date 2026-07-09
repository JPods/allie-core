# JPods — SketchUp Dispatch Server (WEBrick)
**Last updated:** 2026-05-14
**Status:** Implemented — `dispatch_server.rb` running in plugin on port 5051

**Trip JSON schema:** `su_jpods/readmes/trip-json-schema.md` — all three trip file formats
(per-Nora trip file, fleet observation log, dispatch payload) with field reference and invariants.

The SketchUp plugin starts a WEBrick HTTP server on port 5051 when it loads.
Django's `TravelView` POSTs a trip command to it after posting the invoice to Alice.
SketchUp receives the trip and animates the pod moving from origin to destination.

**Port:** 5051 (port 5050 is MeshMobility)

---

## How It Works

```
Travel button (browser)
  → Django TravelView
    → Alice: POST invoice          (always)
    → SketchUp: POST localhost:5051/dispatch   (if network = SketchUp)
      → WEBrick handler
        → animate pod origin→destination in SketchUp
```

---

## Ruby Code — Add to SketchUp Plugin

Add this to your plugin's main `.rb` file (or a `dispatch_server.rb` loaded from it).
Start the server when the plugin loads; stop it when SketchUp closes.

```ruby
require 'webrick'
require 'json'

module JPods
  module DispatchServer

    PORT = 5051

    def self.start
      return if @server

      @server = WEBrick::HTTPServer.new(
        Port:        PORT,
        Logger:      WEBrick::Log.new(nil, WEBrick::Log::WARN),
        AccessLog:   [],
      )

      @server.mount_proc('/dispatch') do |req, res|
        if req.request_method == 'POST'
          begin
            trip = JSON.parse(req.body)
            handle_trip(trip)
            res.status = 200
            res['Content-Type'] = 'application/json'
            res.body = { status: 'ok', trip_id: trip['trip_id'] }.to_json
          rescue => e
            res.status = 500
            res.body = { error: e.message }.to_json
          end
        else
          res.status = 405
          res.body = { error: 'POST only' }.to_json
        end
      end

      # Run server in a background thread so SketchUp stays responsive
      @thread = Thread.new { @server.start }
      UI.messagebox("JPods dispatch server started on port #{PORT}") if $VERBOSE
    end

    def self.stop
      @server&.shutdown
      @thread&.join
      @server = nil
      @thread = nil
    end

    def self.handle_trip(trip)
      origin      = trip['origin_station_id']      # e.g. "S097"
      destination = trip['destination_station_id']  # e.g. "S098"
      trip_id     = trip['trip_id']
      contact     = trip['contact_name']

      # Log to SketchUp console
      puts "[JPods] Trip #{trip_id}: #{contact} #{origin}→#{destination}"

      # TODO: animate pod in SketchUp
      # Find the pod component instance associated with origin station,
      # move it along the guideway to the destination station.
      #
      # Example skeleton:
      #   model = Sketchup.active_model
      #   entities = model.active_entities
      #   pod = find_pod_at_station(entities, origin)
      #   path = find_guideway_path(entities, origin, destination)
      #   animate_pod(pod, path)
      #
      # The animation API in SketchUp uses:
      #   model.active_view.animation = MyAnimation.new(pod, path)
    end

  end
end

# Start server when plugin loads
JPods::DispatchServer.start

# Stop server when SketchUp closes
Sketchup.add_observer(
  Class.new(Sketchup::AppObserver) do
    def onQuit
      JPods::DispatchServer.stop
    end
  end.new
)
```

---

## Trip Payload (from Django)

```json
{
  "trip_id":                "T-20260429-A3F2",
  "origin_station_id":      "S097",
  "destination_station_id": "S098",
  "contact_name":           "Adult Traveler",
  "price":                  "2.00",
  "currency":               "USD",
  "network_id":             "default"
}
```

---

## Next Steps

1. Implement `find_pod_at_station(entities, station_id)` — find the pod component near the station
2. Implement `find_guideway_path(entities, origin, destination)` — trace the guideway edges
3. Implement `animate_pod(pod, path)` — use SketchUp's `Sketchup::Animation` interface
4. Optionally: highlight the route on the map before the pod moves

---

## Notes

- WEBrick is included in Ruby's standard library — no gem installation needed
- The server binds to `localhost` only — not exposed to the network
- Errors in `handle_trip` are caught and returned as 500; Django logs them but does not cancel the invoice
- Run SketchUp before pressing Travel in the phone app
