# Thalia – your workflow in the app

Thalia replaces the printed weekly tracker and the sheet of paper at the desk – **not** the ritual,
the ownership or the pause to think. The annual goals give continuity, the weekly plan context,
the daily record evidence, and your reflection meaning.

## From paper to app

| Before (paper + ChatGPT) | In Thalia | Where |
|---|---|---|
| Sunday message to ChatGPT (score, interpretation, next week's commitments) | Same message – Thalia adds a **planning prompt** with the exact CSV format, your structure and last week's report | Woche → Planen, or + → Wochenplan importieren → Planungs-Prompt kopieren |
| ChatGPT writes a Word tracker → print shop | ChatGPT writes a **CSV** (one code block) | – |
| Thick printed sheets | **Import**: paste the answer (the code block is found automatically) → preview → Importieren | + → Wochenplan importieren |
| 10 annual goals, 18 detailed categories | Goals 1–10, categories 1.1 … 10 (kept across weeks) | Ziele |
| Exactly 10 scored items per category | Ten items per category and week; the preview warns when a category has more or fewer | Woche, Heute |
| Measurements (weight, protein, PH, TEREA …) kept apart from the items | **Messwerte**: never scored, may *suggest* a mark | Heute → Messwerte |
| ✓ / X / 0.5 / N/A / blank | ✓ ½ ✗ N/A and blank (= not recorded yet) – tap cycles, long-press shows all | everywhere |
| Desk sheet: PH done, what I worked on | **Arbeit**: + PH, timer (50 min), block with result and next step | Heute → Arbeit |
| Evening: transcribe the desk sheet into the tracker | **Tag abschließen**: check evidence → fill gaps → confirm categories (own score possible) → reflect | Heute → Tag abschließen, 21:45 reminder |
| Weekly score by hand | Calculated: category → goal → week, every goal 10 % | Woche, Ziele |
| Score + interpretation back to ChatGPT | **Woche abschließen** → Wochenbericht kopieren + Planungs-Prompt kopieren | Woche → Woche abschließen |
| Major review KW49 | Goal year with review milestone; goals don't get harder automatically | Ziele, Einstellungen → Jahresziele |
| Scoring changed in KW42 | Weeks before KW42 marked "vor KW42", shown apart in charts | Rückblick |

## The weekly flow

1. **Sunday – reflect and choose the week.** Woche → *Woche abschließen*: the score and the
   reality behind it (work in PH and real hours, measurements against targets, missed commitments,
   days not closed), the four questions (repeat · avoidable friction · outside the plan · change /
   keep). Then *Planungs-Prompt kopieren*.
2. **ChatGPT writes the plan.** Paste the prompt, add your Sunday message. The answer is one
   `csv` block (format: [IMPORT.md](IMPORT.md)). Assumptions and resolved contradictions go into the
   week's description.
3. **Import.** + → Wochenplan importieren → paste → preview ("KW46: 180 Punkte in 18 Kategorien ·
   20 Messwerte", warnings) → Importieren. Re-importing a revised plan updates; items the new plan
   no longer has go to *Zuletzt gelöscht*.
4. **During the day – capture what happened.** + PH or the timer (Live Activity, "50 minutes are
   up – stop deliberately"), measurements with +, marks on items, notes (trigger, success, contact,
   parked idea). On the watch: +1 PH, timer, measurements, open items.
5. **At night – decide what it means.** *Tag abschließen*. Deliberate, never automatic.
6. **Next Sunday** – the closed week (report + reflection) goes into the next planning conversation.

## What Thalia calculates – and what stays your call

| Kind | Examples | Thalia |
|---|---|---|
| Objective entries | minutes, pages, TEREA, spending, bedtime | totals, progress, explicit thresholds (`>=150`, `<=23:00`) |
| Reported completion | journaled, block as planned, call made | your mark is the evidence; nothing is inferred from unrelated data |
| Subjective judgment | attentive family time, HAEB stress spilling over | you enter or confirm it; own category score in the evening review |

A measurement linked to an item (`link`) only **suggests** ✓ or ✗ – "Vorschläge übernehmen" applies
them, nothing is overwritten silently. Without a value there is no suggestion (blank stays blank).
Apple Health values are suggestions too; adopted values stay on the device (guideline 5.1.3(ii)).

## Scoring

- Item: ✓ = 1, ½ = 0.5, ✗ = 0; N/A and blank don't count. Category per day = 10 × earned ÷ applicable.
- Week: category = average of its valid days → goal = average of its categories → week = average
  of the **ten goals, 10 % each** (Ernährung 8 + Training 6 → Fit Body 7; Fit Body weighs as much as Schlaf).
- Not scheduled ≠ missed. `woche:3` items: each ✓ ½ ✗ uses a slot; what's left at the end of the
  week counts as missed on the last possible day. Optional items are never scored.
- Personal zero rule (`ko`): ✗ sets the category to 0 that day; entries stay intact.
- Missing coverage stays visible ("9/10 Ziele bewertet – nicht voll vergleichbar").
- Power-hour = exactly 50 focused minutes; tutoring in real hours: 12 × 50 min + 16 × 60 min = 26 h net.

All of this lives in `Packages/ThaliaCore` (`Scoring.swift`, `Measures.swift`) and is tested on Linux
with the handover's own examples (`ScoringTests.swift`).

## Research behind the design

- **Equal weighting and "good enough"**: The 12 Week Year scores a week as tactics done ÷ planned and
  treats 85 % as good enough ([monday.com summary](https://monday.com/blog/productivity/12-week-year-time-management-system/));
  Thalia shows the score without a target line and repeats "Wiederholen statt steigern", because the
  foundation year is about consistency, not raising the bar.
- **Skips must not punish**: Habitify's "Skip" keeps streaks but still lowers the completion rate,
  which users asked to change ([Habitify help](https://intercom.help/habitify-app/en/articles/6113621-learn-about-streak-in-habitify),
  [feedback board](https://feedback.habitify.me/p/skipping-a-habit-should-not-reduce-avg-completion-rate)).
  In Thalia N/A leaves the denominator and blank is "not recorded", never a failure. No streaks.
- **Pace instead of pressure**: Strides shows a pace line against where you should be by now
  ([Strides FAQ](https://www.stridesapp.com/faq.html)) – Thalia's weekly targets (8 PH stammloop …)
  show an even-pace marker.
- **Short, fixed review prompts**: Full Focus Planner's weekly preview ([PDF](https://fullfocusplanner.com/wp-content/themes/fullfocusplanner-v6/files/quickstart/Weekly%20Preview%20Pages.pdf))
  and Bullet Journal's migration of unfinished items ([bulletjournal.com](https://bulletjournal.com/blogs/faq/what-is-the-bullet-journal-method))
  → the four weekly questions and the list of missed commitments in the weekly closing.
- **A few taps in the evening**: Daylio's tap-first entry ([overview](https://postmake.io/tools/daylio)) → the evening review
  is mostly taps; text is optional.
- **Focus blocks**: Power-hour = 50 minutes is your own rule; the often-cited DeskTime data found
  ~52 min work / 17 min break among their most productive users ([Quartz](https://qz.com/267823/the-perfect-recipe-for-productivity-rest-17-minutes-every-52)).
- **Standards**: ISO 8601 weeks (Monday start, week 1 holds the first Thursday; 2026 has 53 weeks) –
  [Apple: yearForWeekOfYear](https://developer.apple.com/documentation/foundation/calendar/component/yearforweekofyear);
  CSV quoting per RFC 4180 ([rfc-editor.org/rfc/rfc4180](https://www.rfc-editor.org/rfc/rfc4180));
  App Store Review Guideline 5.1.3(ii): "may not store personal health information in iCloud"
  ([guidelines](https://developer.apple.com/app-store/review/guidelines/#5.1.3));
  Live Activities run up to 8 hours ([ActivityKit](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)) –
  plenty for a 50-minute block; at most 10 App Shortcuts per app (Thalia has 4).
