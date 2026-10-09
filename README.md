# Vätternrundan 2026 trip

A map of the trip from Nantes to Stockholm (and back) for Vätternrundan 2026, the 315 km bike ride around Lake Vättern in Sweden.

Live: https://vatternmumble.vumble.dev

## What's inside

- `index.html`: the whole web app in one file (Leaflet map, legs, layovers, timings). No build step.
- `verify.mjs`: a quick check that runs the page script without a browser. Run it with `node verify.mjs`.
- `ios/`: a native SwiftUI + MapKit version of the same app. Open `ios/Vatternrundan.xcodeproj` in Xcode.

## Deploy

Vercel deploys `main` on every push. `.vercelignore` keeps `ios/` and `verify.mjs` out of the web deploy.
