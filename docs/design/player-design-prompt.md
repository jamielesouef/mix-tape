# Claude Design prompt — mixtape library + player

Design language foundation. Paste the block below into Claude Design.

---

Design **two screens** for **mixtape**, a personal music app for iPhone (iOS 26):

1. **The library** — a paged wallet of albums
2. **The player** — now playing, reached by choosing an album from the library

Together they establish the design language for the whole app — colour, type, spacing, motion,
control vocabulary. Treat them as a foundation pair, not two isolated mockups. The transition
between them is part of the deliverable: an album cover in the library becomes the hero artwork
in the player.

## Product

The library is a **CD wallet**, not a streaming service. A user turns to a page of the wallet,
picks an album, and that album plays start to finish. **The queue is the album** — there is no
cross-album queue, no library-wide shuffle, no radio, no recommendations. Playback is a
deliberate act with a specific record. When the last track ends, playback stops and the wallet
returns to the page that album came from.

## The aesthetic

**Minimal, dark, artwork-led. This is the governing constraint and it outranks everything below.**

- Album artwork is the only saturated element anywhere in the app. Everything else is a
  near-black violet ground, tinted by context, with white text at two or three opacity steps
  (100% / ~60% / ~35%).
- Hairline strokes only. No cards, no borders, no drop shadows, no bevels, no gradients used
  as decoration. On any given screen exactly one element is filled and solid; everything else
  is an outline glyph or plain text.
- Generous emptiness. Roughly a third of each screen carries nothing. Restraint is the point.

**No skeuomorphism.** The product is a CD wallet conceptually, not visually. Do not draw vinyl
grooves, jewel cases, plastic sheen, spinning discs, tape reels, paper texture, leather, stitching,
wear, scuffs, drop shadows imitating depth, or a page-curl. Nothing on screen should imitate a
physical material.

What the physical reference *is* allowed to contribute is **typographic and geometric discipline**,
because that discipline is already minimal:

- Condensed technical capitals for metadata — the register of `TYPE II`, `C-90`, `HIGH BIAS`
  printed on a cassette label. Use for format, duration, track counts, page labels.
- A small text lozenge for format (`FLAC · 44.1 kHz`), set flat — no chrome around it.
- A rigid, unforgiving grid in the library. A real wallet page is a uniform lattice holding
  wildly inconsistent artwork, and that contrast is the whole effect. The grid does the work;
  the sleeves are invisible.
- A progress indicator that is a **hairline with a small circular knob** — the geometry of a
  hub, not a picture of one.

**Accent: a restrained magenta / cyan pair.** State only — active progress fill, current-track
marker, selection, focus. Never decoration, never a glow, never at rest.

## Screen 1 — Library (the wallet)

- A paged grid of album covers. Square art, uniform gutters, edge-to-edge, no labels
  interrupting the lattice — the artwork is the identity.
- Paging is horizontal and discrete: one page of albums at a time, not an infinite scroll.
  The page transition is a clean slide, not a turn or a flip.
- A quiet page indicator and a page or section label set in condensed capitals.
- Album title and artist appear only for the selected item, or beneath the grid — not stamped
  on every tile.
- A minimal way to move between library sections (albums / artists / whatever the wallet is
  divided into) — treat this as a text-level control, not a tab bar with icons.
- Selecting a cover expands it into the player's hero artwork. Design that transition.

States to produce: a full page; a partly-filled last page; an empty library; loading;
an album with missing artwork (the placeholder must carry the design language, not be a grey square).

## Screen 2 — Player (now playing)

- Album artwork owns the top ~60–65%, full-bleed to the edges, dissolving at its lower boundary
  into a background colour sampled from the art itself.
- Track title and artist left-aligned at the seam where the artwork dissolves — title in a
  confident weight, artist one step down and dimmed. Album name quiet, nearby.
- Progress: hairline, elapsed on the left, remaining as `−m:ss` on the right, format lozenge
  centred beneath.
- Transport: **previous / play-pause / next** only. Oversized glyphs, generously spaced,
  play-pause the one filled shape on the screen.
- Volume: hairline slider with small end glyphs.
- Dismiss affordance returning to the wallet page this album came from.
- An access point to the album's track list, which shows the queue *is* exactly this album —
  no "up next" beyond it.

States to produce: playing with rich colourful artwork; playing with dark or monochrome artwork
(prove the sampled chrome stays readable); paused; buffering; missing artwork; track list expanded
with the current track marked.

## Hard rules — these controls do not exist

Do not draw, disable, or reserve space for: **shuffle, repeat, add-to-queue, autoplay, up-next
carousel, radio, recommendations, social or sharing.** They are absent from the product, not
deferred. The complete transport vocabulary is previous, play/pause, next, scrub.

## Chrome

Liquid Glass for floating chrome only — the dismiss bar, an overlay panel — always paired with a
**Reduce Transparency fallback**: a solid tinted surface at the same colour value. Show both.

## Deliver as design tokens

Name and specify these, so the rest of the app can be built from the two screens:

- **Colour** — background ramp, three text opacity steps, two accents, the artwork-sampling rule
- **Type** — display / title / body / metadata-condensed, with Dynamic Type behaviour
- **Spacing** — a scale, plus the library grid gutter and the player's seam offset and transport spacing
- **Radii** — artwork, glass panels, lozenges
- **Stroke** — hairline weight, glyph weight
- **Motion** — cover-to-hero transition, library page slide, artwork cross-fade on track change,
  play/pause morph, dismiss; durations and curves
- **Glass** — blur, tint, and the opaque fallback pairing

Meet WCAG AA for all text over sampled backgrounds. Title and artist must survive the largest
Dynamic Type size without truncation.

## Also sketch, briefly

The same language on **tvOS**, where there is no wallet — a conventional focus-driven album grid,
artwork larger still, and the accent pair carrying the focus ring. One frame of each screen is
enough; the phone screens are the deliverable.
