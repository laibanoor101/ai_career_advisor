# Copilot Agent prompts (copy one at a time)

Before using these: copy the folder `design_reference/` into `E:\ai_career_advisor\design_reference\` (it holds roadmap_screen.html, history_screen.html, design_tokens.md). Keep the original `ai_career_advisor_nextgen_dark_glass_ui.html` in the project root too.

---------------------------------------------------------------
## PROMPT A - Roadmap screen
---------------------------------------------------------------
Read these files first: design_reference/design_tokens.md and design_reference/roadmap_screen.html (also open ai_career_advisor_nextgen_dark_glass_ui.html section "7. CAREER DETAIL & SKILL GAP" if something is unclear).

Redesign the Roadmap (Career Detail & Skill Gap) screen to match roadmap_screen.html pixel-for-pixel, reusing the same theme tokens, glass-card widget, gradients and Plus Jakarta Sans font already used in results_screen.dart. Support dark and light mode exactly as described in design_tokens.md.

IMPORTANT: Do NOT hardcode "Software Engineer", 94%, 84.5%, or any sample text from the HTML. Everything must come from real data:
- The selected career (name, category, match %) comes from the Top-5 result produced by the existing .tflite recommendation flow. Pass it via the state management (Provider) or route arguments that results_screen.dart already uses.
- Career description, required skills (required level 1-5) and learning resources come from the dataset in assets/data/. If learning resources do not exist there, create assets/data/learning_resources.json (career -> list of {title, provider, url, icon type}) and load it from there.
- The user's skill ratings and academic data come from the profile/skills providers already built.

Layout, top to bottom:
1. Top bar: back button, title "Detailed Career Report", bookmark button that toggles a saved state and shows a toast.
2. Career title glass card: category tag (purple pill), match badge (cyan pill), title, short description.
3. Hero banner (height ~112, radius 16, cyan border): the HTML had a base64 photo; do NOT embed any image. Use a gradient (purple -> indigo -> cyan) with a Material icon, the pathway tag, a title and a "High Growth" pill.
4. "Why This Fits Your Profile" card (purple left border, gradient fill, brain icon, 3 check bullets). Generate the bullets in Dart from real inputs: user's top RIASEC codes, academic % vs the career's requirement, the user's highest-rated skill needed by this career.
5. "Skill Gap Analysis" with a computed "N Gaps to Build" counter. One glass card per required skill: coloured left border, name, status badge, "Current: X (n/5)", "Required: Y (n/5)", progress bar (current / required, clamped 0-1). Rules: gap >= 2 red "Needs Attention"; gap == 1 amber "Developing"; gap <= 0 green "Matched Strength".
6. "Curated Free Learning Resources": tappable glass cards opening the URL with url_launcher (add to pubspec.yaml if missing).
7. Sticky bottom gradient button "Save to My Learning Plan" (glow) that saves the plan with shared_preferences and shows a toast.

Requirements:
- Scrollable and safe on small phones (TECNO KL7), no overflow stripes; test with a very long career name.
- Loading, empty and error states.
- Create test/roadmap_screen_test.dart: verify gap colour rules, the gaps counter, and that the screen shows the career it is given (use two different careers to prove nothing is hardcoded).
- Run `flutter analyze` and `flutter test`, fix every issue, then list the files you changed. Do not touch Splash, Auth, Profile, RIASEC or Skills screens.

---------------------------------------------------------------
## PROMPT B - History screen
---------------------------------------------------------------
Read these files first: design_reference/design_tokens.md and design_reference/history_screen.html (also section "8. HISTORY" of ai_career_advisor_nextgen_dark_glass_ui.html if needed).

Redesign the History screen to match history_screen.html pixel-for-pixel, using the same dark/light theme, glass cards, gradients and Plus Jakarta Sans font as the other screens.

Data (NO hardcoded sample records such as "Software Engineer 94%" or "Electrical Engineer 86%"):
- Each time the user saves a result from the Career Matches screen, store an assessment record: timestamp, academic level/field label (e.g. "Intermediate (Pre-Eng)"), top-5 careers with match %, and a profile snapshot (RIASEC scores, skill ratings, marks).
- Save to Cloud Firestore at users/{uid}/assessments (uid from Firebase Auth) and cache the same list with shared_preferences so History opens instantly and works offline. Sync when internet returns.
- Put this in a repository/service class exposed with Provider.

UI:
1. Header: back button, title "Assessment History", red "Clear" text button (confirmation dialog first, then delete the user's records in Firestore and local cache).
2. Subtitle: "Track how your recommendations evolve as your skills & marks update."
3. Record cards, newest first: clock icon + "Today • hh:mm AM" or "14 Oct 2026 • 04:30 PM" (from the real timestamp), level badge on the right, top career name, "Other: ..." line with the next 2 careers, cyan match badge for the newest and purple for older ones, divider, "View Full Output ->" (opens Career Matches filled from that SAVED record, not a new prediction) and a share icon (share_plus, add to pubspec.yaml if missing, share a short text summary).
4. Empty state: dashed-border glass card with folder icon, "No Assessment History" and the helper text from the HTML.
5. Bottom gradient button "Take New Career Assessment" that starts the profile flow.
6. Swipe-to-delete a single record with an undo snackbar.

Requirements:
- Loading, error and offline states; no overflow on small phones; safe when the user is logged out (use local cache only).
- Create test/history_screen_test.dart: empty state, 2 records in newest-first order, Clear confirm flow. Use a fake repository, not real Firebase.
- Show me the exact Firestore security rule that lets a user read/write only users/{uid}/assessments for their own uid.
- Run `flutter analyze` and `flutter test`, fix everything, then list changed files. Do not modify other screens except wiring the Save button in results_screen.dart to the repository.

---------------------------------------------------------------
## PROMPT C - 4-tab bottom navigation (after A and B work)
---------------------------------------------------------------
Read design_reference/design_tokens.md. Add a 4-tab bottom navigation bar (Assess, Matches, Roadmap, History) in the same glass style: frosted bar, purple-gradient active tab, muted slate inactive tabs, dark and light mode. Keep each tab's state alive (IndexedStack). The Roadmap tab must show an empty-state "Pick a career from Matches" when no career is selected yet. Make the Android back button behave correctly. Run flutter analyze and flutter test, then list changed files.
