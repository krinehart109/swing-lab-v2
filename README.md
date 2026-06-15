# Swing Lab ⛳

A golf swing trainer. Three tools:

- **Analyze** — load or record a swing video, scrub frame-by-frame, play at ⅛x–1x speed, and draw lines, circles, and measured angles on top (swing plane, spine angle, etc.).
- **AI Coach** — on-device AI pose tracking (MediaPipe) maps your body through the swing, finds Address/Top/Impact/Finish, and measures tempo ratio, shoulder turn, head & hip sway, and posture loss. Pick a pro (Rory, Tiger, Scottie, Nelly, Freddie, Hideki) for a side-by-side metric comparison, and get the top "best value" fixes — each with a drill, ranked by impact vs effort. Runs entirely in the browser; the model (~6 MB) downloads from a CDN on first use, so the AI tab needs internet the first time. Film face-on with your full body in frame.
  - **Save Analysis + Clip** stores the full report, keyframe stills, and the video itself in the browser's IndexedDB — the Saved Swings list survives app restarts, and Load brings back both the report and the clip.
  - **Auto-trim**: when you load a video, a quick motion scan finds the swing and trims playback/analysis to just those frames (with padding). A badge under the video shows the window; tap "Use full clip" to undo.
- **Tempo** — audio tempo trainer built on the 3:1 pro ratio, with Tour 21/7, Smooth 24/8, and Easy 27/9 presets.
- **Log** — practice journal with club, star rating, and notes (saved on-device).

No build step, no dependencies — it's a single static page (`index.html` + manifest + icons).

## Accounts (cloud, Google sign-in)

Accounts run on **Supabase** (free tier). Each player signs in with **Google**; their notes and swing analyses sync to their account and follow them across devices. Access is **invite-only** — a player can sign in but can't use the app until an admin adds their email to the allowlist.

- **Sign in with Google** on first open. New accounts land on a "waiting for approval" screen until an admin approves them.
- **Onboarding tutorial** — an animated, under-a-minute walkthrough on first login; replay from the account menu (▾).
- **Admin panel** (account menu → Admin, admins only): see every player with swing/note counts, **approve/revoke** access, **make admin/player**, **wipe** a player's data, **remove** a player, and **invite by email** (adds them to the allowlist + opens your mail app with the app link).
- **Capture guide** — "📷 How to film a good swing" on the Analyze screen.

**Data placement:** profiles, the allowlist, practice-log notes, and AI analysis (metrics + keyframe thumbnails) live in Supabase, isolated per user by Row-Level Security. **Swing video clips stay on-device** (IndexedDB, keyed by the cloud swing id) — so a saved swing shows "report only" on a device that doesn't have the clip. Backend config: see [`supabase/schema.sql`](supabase/schema.sql). The Supabase Project URL + publishable key are embedded in `index.html` (safe to expose; protected by RLS).

**First-time admin bootstrap:** after the very first Google sign-in, run this once in the Supabase SQL Editor to make yourself the approved admin:

```sql
update public.profiles set role='admin', approved=true
where id = (select id from public.profiles order by created_at asc limit 1);
insert into public.allowlist (email)
select email from public.profiles order by created_at asc limit 1
on conflict do nothing;
```

## Run it

From this folder:

```sh
python3 -m http.server 8421
```

Then open <http://localhost:8421>.

## Put it on your iPhone home screen

### Option A — host it (recommended, works anywhere)

1. Push this folder to a GitHub repo and enable **GitHub Pages** (Settings → Pages → deploy from branch), or drag the folder onto [Netlify Drop](https://app.netlify.com/drop).
2. Open the HTTPS URL in **Safari** on your iPhone.
3. Tap the **Share** button → **Add to Home Screen** → **Add**.

You get the gold Swing Lab icon, it launches full-screen like a native app, and it works offline (the service worker caches it).

### Option B — same Wi-Fi as your Mac (quick test)

1. Run the server command above on the Mac.
2. On your iPhone, open Safari to `http://192.168.4.170:8421` (your Mac's address — check System Settings → Wi-Fi if it changed).
3. Share → **Add to Home Screen**.

Works the same, but only while your Mac is on and on the same network, and offline caching is disabled over plain HTTP.

### Optional — launch via the Shortcuts app

If you'd rather have it in a Shortcut: Shortcuts app → **+** → **Add Action** → **Open URLs** → paste your Swing Lab URL → name it "Swing Lab". You can add that shortcut to the home screen too, but plain **Add to Home Screen** from Safari gives the nicer full-screen app experience.

## Tips on the course / range

- Film down-the-line or face-on; the **Angle** tool takes three taps (point → vertex → point) and prints the angle in degrees.
- Drawings stick to the video while you scrub, so set your swing-plane line at address and step through impact.
- For tempo, the three tones are takeaway → top → impact. Most amateurs are too slow back and too fast down — let the tones fix the ratio.
