# 3D Map Style Guide

This document is the visual source of truth for the map. It supplements
`docs/design.md`; it does not change gameplay rules.

## Direction

The map uses a calm, stylized low-poly storybook look. Shapes must remain
readable from the normal portrait-mobile camera and at full-map zoom.

- Prefer a strong silhouette over small surface detail.
- Use simple geometry, broad color fields, and matte materials.
- Avoid realistic textures, noisy surfaces, and thin decorative parts.
- Exaggerate important landmarks and encounters slightly.
- Keep decorative variation deterministic.
- Use the shared colors in `scripts/map_visual_palette.gd`.

## Scale and hierarchy

- Ground and roads are the quiet visual base.
- Trees and mountains frame the route without obscuring connections.
- Encounters are more saturated and sit on a round, road-colored plaza.
- The player and every enemy use one consistent pawn scale.
- Enemy appearance must not reveal strength; power is communicated by UI.
- Start and goal must have distinct silhouettes. The goal is a generic
  destination landmark and must not reference Karlskoga or the working title.

## Geometry and materials

- Model families should be reusable Godot scenes or small procedural meshes.
- Use 6-12 radial segments for round low-poly forms.
- Use matte materials with roughness near `0.9`.
- Use shadows for landmarks and characters; disable them on flat road surfaces.
- Imported assets should use `.glb` when practical and be wrapped in a local
  Godot scene for scale, pivot, and material control.

## Encounter plaza

Every tile with an encounter has a shallow round plaza beneath the encounter.
It uses exactly the tile's `road_color`, so it reads as a small widened,
well-trodden part of the road rather than a separate marker. The plaza follows
the road anchor on curved roads and never communicates encounter type or power.

