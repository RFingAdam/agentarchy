# Where the wallpapers actually came from

Companion to `docs/asset-audit.md`, which is generated. This one is written, and records what was found
when the generated table's answer ("no source recorded") was pushed on rather than accepted.

Date: 2026-08-23. Upstream at `upstream/PIN` (`basecamp/omarchy`).

## Four places the answer could have been, and what each said

**1. The contribution rules.** Upstream solicited these wallpapers deliberately, in
[issue #617](https://github.com/basecamp/omarchy/issues/617), "Add up to 3 default backgrounds for every
theme that match really well". The rules are quoted in full because their content is the finding:

> - Must look good at 6K. Doesn't mean it HAS to be natively 6K, but it can't be like 1440p. Gotta be
>   minimum 4K and not rely on lines that'll look blurry at 6K.
> - Must be 2mb or less. That means JPG for anything that's a picture but PNG for anything that's a
>   graphical design.
> - Must fit with the tones and style of the theme.

Resolution, file size, and taste. Nobody was asked where the image came from or whether they had the
right to give it away.

**2. The pull requests.** Six representative wallpaper PRs were read end to end, including their comment
threads: #4533 and #3317 (bjarneo, the vantablack and hackerman themes), #1008 (shawnyeager, two
catppuccin backgrounds), #761 (gthelding, ristretto), #2288 (vaqMAD, matte-black), #5110 (dhh, retro-82
"by @oldjobobo"). The conversations are about how it looks, whether the JPEG can be smaller, and which
vscode theme to pair with it. Not one names a source, an author, or a licence.

**3. The files themselves.** Two of the 68 still carry EXIF:

* `themes/hackerman/backgrounds/1-synth-scape.jpg` -- `Software: Adobe Photoshop CC 2018 (Windows)`,
  `ImageDescription: Abstract landscape background with a modern techno wireframe design`. That is not
  how a person titles their own wallpaper; it is how a stock library captions a listing, and searching
  the phrase returns exactly that kind of listing on Dreamstime, Getty and iStock. It is evidence of a
  commercial stock origin, not proof of one -- but it points the wrong way.
* `themes/matte-black/backgrounds/0-ship-at-sea.jpg` -- `Software: Adobe Photoshop 24.6 (Macintosh)`.

The other 66 have had their metadata stripped, largely by the webp re-encode.

**4. Links in the trail.** Two files have one. `themes/osaka-jade/backgrounds/2-shaded-entrance.webp`
points at another person's theme repository it was copied from; `themes/ethereal/backgrounds/1-cosmic.webp`
points at a VS Code marketplace listing. Both restate that the image was copied from somewhere else,
which is a trail, not permission.

## Does upstream's MIT licence cover them?

No, and this is the argument worth being careful about. GitHub's terms and the repository's MIT licence
mean a contributor licenses what they submit under the project's licence -- *if they had the right to*.
For a contributor who found a wallpaper and opened a PR with it, there is no right to convey, and MIT on
the repository does not launder one into existence. Upstream ships them anyway; that is upstream's
exposure to carry, and it does not transfer to a fork that re-publishes them under a different name.

## Conclusion

For none of the 68 can redistribution rights be established, and for at least one there is positive
evidence pointing at commercial stock. They are removed from this repository. Each theme instead ships a
wallpaper generated from its own palette (`bin/oal-dev-make-wallpapers`), which is unambiguously ours,
and licensed wallpapers can be added back one at a time as their provenance is established.

The removed files are not lost to Agentarchy's own users: the theme system reads
`~/.config/oal/backgrounds/<theme>/`, so anyone who has them keeps them, and Adam's copy of the
originals lives outside this repository.

## The 68 files removed

* `themes/catppuccin-latte/backgrounds/1-color-fade.webp` -- first added 2025-07-18, 786b0b22
* `themes/catppuccin/backgrounds/1-totoro.webp` -- first added 2025-07-17, e2c8e3cc
* `themes/catppuccin/backgrounds/2-waves.webp` -- first added 2025-08-23, cc807821 (#1008)
* `themes/catppuccin/backgrounds/3-blue-eye.webp` -- first added 2025-08-23, cc807821 (#1008)
* `themes/ethereal/backgrounds/1-cosmic.webp` -- first added 2025-11-20, cd2a4e41 (#3464)
* `themes/ethereal/backgrounds/2-meadow.webp` -- first added 2025-12-08, 20fde4d7
* `themes/everforest/backgrounds/1-tree-tops.webp` -- first added 2025-07-17, e2c8e3cc
* `themes/flexoki-light/backgrounds/1-orb.webp` -- first added 2025-10-12, 0df4dc1a
* `themes/gruvbox/backgrounds/1-the-backwater.jpg` -- first added 2025-07-17, e2c8e3cc
* `themes/gruvbox/backgrounds/2-flower-basket.webp` -- first added 2026-03-25, e921ea3c
* `themes/gruvbox/backgrounds/3-village-square.jpg` -- first added 2026-03-25, e921ea3c
* `themes/gruvbox/backgrounds/4-idyllic-procession.jpg` -- first added 2026-03-25, e921ea3c
* `themes/gruvbox/backgrounds/5-leaves.jpg` -- first added 2025-12-24, fd952c23
* `themes/hackerman/backgrounds/1-synth-scape.jpg` -- first added 2025-11-20, a1b1eb59 (#3317)
* `themes/hackerman/backgrounds/2-geometric.webp` -- first added 2025-11-20, a1b1eb59 (#3317)
* `themes/kanagawa/backgrounds/1-kanagawa.jpg` -- first added 2025-07-17, e2c8e3cc
* `themes/last-horizon/backgrounds/1-eyes-wide.webp` -- first added 2026-05-09, b2fb2384
* `themes/last-horizon/backgrounds/2-blink.webp` -- first added 2026-05-09, b2fb2384
* `themes/last-horizon/backgrounds/3-bokeh.webp` -- first added 2026-05-09, b2fb2384
* `themes/last-horizon/backgrounds/4-new-horizons.jpg` -- first added 2026-05-09, b2fb2384
* `themes/lumon/backgrounds/01-united-in-severance.webp` -- first added 2026-03-18, e24a9f22
* `themes/lupine/backgrounds/01-cherry-blossom-bokeh.webp` -- first added 2026-05-24, 4a2a228d
* `themes/lupine/backgrounds/02-cherry-blossom-white.webp` -- first added 2026-05-24, 4a2a228d
* `themes/lupine/backgrounds/03-pastel-clouds.webp` -- first added 2026-05-24, c8281490
* `themes/lupine/backgrounds/04-elegant-blue-wave.webp` -- first added 2026-05-24, 1008776d
* `themes/lupine/backgrounds/05-abstract-wave.webp` -- first added 2026-05-24, 1008776d
* `themes/matte-black/backgrounds/0-ship-at-sea.jpg` -- first added 2025-09-08, e5a1b994
* `themes/matte-black/backgrounds/1-dark-waters.webp` -- first added 2025-07-17, e2c8e3cc
* `themes/matte-black/backgrounds/2-dot-hands.webp` -- first added 2025-10-10, 6b3fc343 (#2288)
* `themes/miasma/backgrounds/01-nature-of-fear.webp` -- first added 2026-01-29, 55231e97
* `themes/miasma/backgrounds/02-crowned.webp` -- first added 2026-01-29, 55231e97
* `themes/nord/backgrounds/0-black-moon.jpg` -- first added 2026-02-18, 73051524
* `themes/nord/backgrounds/1-city-view.webp` -- first added 2025-07-17, e2c8e3cc
* `themes/nord/backgrounds/2-night-hawks.webp` -- first added 2025-08-12, 8a9b841e (#707)
* `themes/osaka-jade/backgrounds/1-glowing-city.webp` -- first added 2025-08-06, 1d29c32f (#514)
* `themes/osaka-jade/backgrounds/2-shaded-entrance.webp` -- first added 2025-08-10, 38bf472d (#589)
* `themes/osaka-jade/backgrounds/3-mountain-moon.webp` -- first added 2025-08-10, af00a902
* `themes/retro-82/backgrounds/1-in-the-groove.webp` -- first added 2026-03-26, a68f2ae0 (#5110)
* `themes/retro-82/backgrounds/2-dusk-guardian.webp` -- first added 2026-03-26, a68f2ae0 (#5110)
* `themes/retro-82/backgrounds/3-glassy-lines.webp` -- first added 2026-03-26, a68f2ae0 (#5110)
* `themes/retro-82/backgrounds/4-gateway.webp` -- first added 2026-03-26, a68f2ae0 (#5110)
* `themes/retro-82/backgrounds/5-zen-boat.webp` -- first added 2026-03-26, a68f2ae0 (#5110)
* `themes/retro-82/backgrounds/6-abstract-pyramids.webp` -- first added 2026-03-26, a68f2ae0 (#5110)
* `themes/retro-82/backgrounds/7-the-journey.webp` -- first added 2026-03-26, a68f2ae0 (#5110)
* `themes/retro-82/backgrounds/8-glitter-glass.webp` -- first added 2026-03-26, a68f2ae0 (#5110)
* `themes/ristretto/backgrounds/0-launch.webp` -- first added 2026-05-02, f0a43a43
* `themes/ristretto/backgrounds/1-color-curves.webp` -- first added 2025-07-28, 51fe5bf6 (#384)
* `themes/ristretto/backgrounds/2-coffee-beans.jpg` -- first added 2025-08-22, 7c4156fc (#761)
* `themes/ristretto/backgrounds/3-industrial-moon.webp` -- first added 2025-08-22, 7c4156fc (#761)
* `themes/rose-pine/backgrounds/1-funky-shapes.webp` -- first added 2025-07-16, 2235332c
* `themes/rose-pine/backgrounds/2-dot-map.webp` -- first added 2025-08-24, 1f4723ae (#1023)
* `themes/solitude/backgrounds/1-on-pole.webp` -- first added 2026-05-09, 47a53a18
* `themes/solitude/backgrounds/2-wreakage.webp` -- first added 2026-05-09, 47a53a18
* `themes/solitude/backgrounds/3-climb.jpg` -- first added 2026-05-09, 47a53a18
* `themes/solitude/backgrounds/4-ether.webp` -- first added 2026-05-09, 47a53a18
* `themes/solitude/backgrounds/5-eyed.jpg` -- first added 2026-05-09, 47a53a18
* `themes/tokyo-night/backgrounds/0-winding-road.webp` -- first added 2026-08-13, 9c9e0829
* `themes/tokyo-night/backgrounds/1-quattro.webp` -- first added 2026-08-12, 3da9eaf6
* `themes/tokyo-night/backgrounds/2-swirl-buck.webp` -- first added 2026-01-12, 281f0b86
* `themes/tokyo-night/backgrounds/3-sunset-lake.webp` -- first added 2025-07-17, 49efa1c3
* `themes/tokyo-night/backgrounds/4-omakub.webp` -- first added 2026-08-06, 45194516
* `themes/vantablack/backgrounds/0-dot-hands.webp` -- first added 2025-10-10, 6b3fc343 (#2288)
* `themes/vantablack/backgrounds/1-twisted-stairs.webp` -- first added 2026-02-07, c289cd07 (#4533)
* `themes/vantablack/backgrounds/2-layers-deep.webp` -- first added 2026-02-07, c289cd07 (#4533)
* `themes/vantablack/backgrounds/3-layers-stacked.webp` -- first added 2026-02-07, c289cd07 (#4533)
* `themes/white/backgrounds/1-white.webp` -- first added 2026-02-21, 94d668bc
* `themes/white/backgrounds/2-white.webp` -- first added 2026-02-21, 94d668bc
* `themes/white/backgrounds/3-white.webp` -- first added 2026-02-21, 94d668bc

## Re-running this

`bin/oal-dev-asset-provenance` regenerates `docs/asset-audit.md` from upstream's history. Re-run it after
a `upstream/PIN` bump: a new wallpaper arriving upstream with no provenance is a new row, and the manifest
excludes it from vendoring in any case.
