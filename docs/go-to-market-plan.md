# DuckWhisperer Go-To-Market Plan

Working name: DuckWhisperer.

This plan is for launching the app as a consumer-friendly Mac voice typing product for everyday office workers. The goal is to avoid looking like a technical Superwhisper clone and instead own a simpler promise: private voice typing that works wherever the cursor is.

## Executive Summary

The Mac dictation market is crowded, but not closed. The crowded part is "AI dictation for power users": model menus, local Whisper settings, developer workflows, and comparison pages against Superwhisper or Wispr Flow. The clearer opening is a product for nontechnical Mac office workers who write all day in Gmail, Outlook, Slack, Teams, Docs, Word, Notion, CRMs, and browser fields.

Recommended positioning:

> Private voice typing for every Mac app.

Core promise:

> Press a shortcut, talk naturally, and DuckWhisperer types polished text where your cursor already is. Your voice stays on your Mac.

Do not lead with "Whisper," "local models," "AI transcription," or "Superwhisper alternative." Those are useful proof points and SEO pages, but they are not the mass-market headline.

Recommended wedge:

- Mac-only first.
- Office-worker first.
- Local/private by default.
- Paste-back reliability as a first-class feature.
- Simple writing modes instead of model complexity.
- One download that works without a terminal.
- Clear setup repair when macOS permissions block paste-back.

## Market Read

This is a real market with strong demand signals:

- Wispr Flow has enough pull to support high subscription pricing and venture funding. TechCrunch reported a $30M Series A in June 2025 and additional funding later in 2025.
- Multiple indie Mac dictation apps have appeared around the same core behavior: hold a shortcut, talk, paste into any app.
- Built-in dictation exists, but users still look for third-party tools because built-ins are fragmented by app, inconsistent across surfaces, or not polished enough for daily work.
- Existing products are splitting into two camps: polished cloud/cross-platform products and privacy/local Mac-native products.

The market is saturated at the feature checklist level. It is less saturated at the trust, simplicity, and nontechnical onboarding level.

## Competitor Map

| Product | Positioning | Pricing observed | Strength | Gap DuckWhisperer can exploit |
| --- | --- | ---: | --- | --- |
| Apple Dictation | Built into macOS | Free | Zero install, good enough for quick use | Not a productized writing workflow; limited customization; privacy details vary by setting/language; no trust-building onboarding |
| Wispr Flow | Voice dictation everywhere, cross-platform, teams | Free tier, $15/mo monthly, $12/mo annual | Polished, real-time, cross-platform, enterprise/security story | Subscription fatigue; cloud/privacy concerns for some users; more account/team oriented |
| Superwhisper | Powerful voice-to-text with many local/cloud model choices | $8.49/mo, $84.99/yr, $249.99 lifetime | Deep configurability, local and cloud options, power-user trust | Complexity; model choice burden; less obvious for normal office workers |
| Aqua Voice | Fast real-time dictation with context and technical vocabulary | Free starter, $8/mo annual Pro, $12/mo annual Team | Speed, streaming UI, strong demos, developer vocabulary | Developer/prompting flavor; annual subscription; privacy/local default less central |
| Voibe | Private/offline Mac dictation | $7.50/mo, $59/yr, $149 lifetime promo | Similar local/privacy value prop, simple pricing | Still leaves room for friendlier setup, better demos, simpler office-worker story |
| MacWhisper | Local transcription for files, meetings, YouTube, and basic dictation | Free, $29 one-time Pro shown on site | Strong local transcription, low one-time price | Broad transcription tool, not primarily "voice typing everywhere" |
| VoiceInk, Yapper, Spokenly, BetterDictation, similar indies | Local or hybrid Mac dictation | Ranges from free/open-source to one-time and BYOK | Price and local privacy | Often technical, niche, developer-coded, or less mainstream in presentation |
| Microsoft Dictate / Google Docs Voice Typing | App-specific dictation | Included with app/account | Familiar, no separate Mac app | Only works in specific apps/browsers; not a universal Mac shortcut |
| Dragon legacy | Dictation brand recognition | Expensive/enterprise legacy | Known by lawyers, medical, accessibility users | Mac support and modern UX gaps create replacement demand |

Conclusion: DuckWhisperer should not try to out-feature the category. It should win on "I installed this and it just works in my work apps."

## Target Customer

Primary ICP:

- Mac office workers who type for a living but do not think of themselves as technical.
- Roles: founders, managers, sales, customer support, recruiters, operations, consultants, lawyers, admins, analysts, students with office-style workloads.
- Daily surfaces: Gmail, Outlook, Slack, Teams, Google Docs, Word, Notion, Linear/Jira, CRMs, browser text fields, ChatGPT/Claude prompts.

Best early buyer:

- A person who writes long messages, gets annoyed by typing, and is comfortable installing a Mac menu-bar app.
- They care that it is private, but they mostly buy because it saves time and feels effortless.

Avoid initially:

- Enterprise IT buyers.
- Medical/legal compliance-heavy teams.
- Mobile-first users.
- Developers who mainly want voice coding.
- People looking for meeting transcription first.

Those segments can come later, but they complicate launch.

## Jobs To Be Done

Primary job:

> When I know what I want to say but typing is slowing me down, I want to speak it into the app I am already using so I can send, save, or edit it immediately.

Secondary jobs:

- Turn rambling speech into clean email.
- Capture notes without switching apps.
- Draft Slack/Teams replies without sounding weird.
- Dictate into AI chat boxes with more context.
- Avoid cloud upload for sensitive work.
- Reduce keyboard strain.

Core anxieties:

- "Will this paste in the right place?"
- "Is my voice being uploaded?"
- "Is setup going to be annoying?"
- "Will it make me sound robotic?"
- "Is this another subscription?"

The product and website should answer these before talking about models.

## Positioning

Category:

> Voice typing for Mac.

Primary tagline:

> Private voice typing for every Mac app.

Alternate homepage headline options:

- "Talk. DuckWhisperer types."
- "Write with your voice in every Mac app."
- "The private Mac dictation app for work."
- "Stop typing the long stuff."

Supporting copy:

> Press Option+Space, say what you mean, and DuckWhisperer puts polished text where your cursor already is. Core dictation runs locally on your Mac, with no account required for normal voice typing.

Proof points:

- Works in every text field.
- Local transcription by default.
- One shortcut.
- Paste-back recovery if macOS blocks insertion.
- Writing modes for email, chat, notes, bullets, and raw dictation.
- Personal dictionary for names and terms.
- Time-saved tracker.

What not to lead with:

- Whisper.
- Model sizes.
- Translation packs.
- Fun modes.
- Robot/duck/alien styles.
- GitHub/source build.

Those are secondary, advanced, or demo flavor.

## Product Packaging For Launch

Minimum public launch requirements:

- Signed and notarized DMG.
- First-run welcome window that checks Microphone, Accessibility, app install location, and default model availability.
- One obvious "Try it here" path.
- One obvious "Start voice typing" shortcut.
- Permission failure UI that says exactly what is missing and how to fix it.
- No terminal needed.
- Default English dictation works immediately after install.
- Optional downloads are clearly optional.
- Crash/log file path and support bundle export.
- Update path or at least "new version available" messaging.

Nice-to-have before paid launch:

- License/trial flow.
- In-app feedback button.
- Privacy page.
- Short onboarding video.
- A "send test email to yourself" demo mode.
- Guided recovery if paste-back fails.

Do not make the app feel like a model lab. Advanced model/language choices should remain tucked away.

## Pricing Strategy

Recommended launch test:

- Free trial: 7 or 14 days.
- Early access one-time license: $39 to $49.
- Public one-time license: $79 to $99.
- Team pack later: 5 seats for a discount.

Why one-time first:

- The market already has visible subscription fatigue.
- Local compute makes the cost story believable.
- A one-time price differentiates from Wispr Flow and Aqua Voice.
- It lowers the psychological barrier for nontechnical users who hate another monthly app.

Alternative:

- $5/mo or $49/yr with a free tier.

Only choose subscription if there will be real recurring cloud cost, sync, team admin, or continuous hosted services. For a local-first Mac app, one-time is the cleaner starting story.

## Website Strategy

The homepage should be brutally simple.

Above the fold:

- Brand name.
- "Private voice typing for every Mac app."
- 20-40 second looping video showing Gmail/Slack/Docs paste-back.
- Buttons: "Download for Mac" and "Watch 30-sec demo."
- Trust strip: "Runs locally", "Works in Gmail, Slack, Word, Docs", "No account for core dictation."

Homepage sections:

1. Problem: typing long messages is slow.
2. Demo: press Option+Space, speak, paste.
3. Works everywhere: Gmail, Outlook, Slack, Teams, Docs, Word, Notion, browser fields.
4. Privacy: voice stays on your Mac for core dictation.
5. Writing modes: Email, Chat, Notes, Bullets, Raw.
6. Setup: one DMG, guided permissions.
7. Pricing.
8. FAQ.

High-intent SEO pages:

- `/voice-typing-for-mac`
- `/mac-dictation-app`
- `/speech-to-text-mac`
- `/dictate-into-any-app`
- `/private-dictation-mac`
- `/offline-dictation-mac`
- `/apple-dictation-alternative`
- `/superwhisper-alternative`
- `/wispr-flow-alternative`
- `/dragon-dictation-alternative-for-mac`

Each page should include:

- One exact query in H1.
- A real video/gif of the workflow.
- Comparison table.
- Clear privacy explanation.
- Download CTA above the fold and at the bottom.

Avoid generic AI copy. Show the app doing normal office work.

## Launch Channels

Primary channels:

- TikTok, Reels, YouTube Shorts: short demos of real office annoyances.
- SEO landing pages for "voice typing for Mac" and competitor alternatives.
- Reddit and Mac communities with transparent founder posts, not spam.
- Product Hunt after the DMG, website, and onboarding are solid.
- Direct outreach to productivity creators who show Mac workflows.

Secondary channels:

- Mac app directories.
- Newsletter sponsorships in productivity/Mac niches.
- Accessibility and RSI communities, with careful and respectful messaging.
- Small business/solopreneur communities.
- AppSumo only if the economics are intentionally planned. Do not use it as a panic channel.

First 10 demo videos:

1. "I wrote this email without typing."
2. "Mac dictation, but it works in every app."
3. "Stop typing Slack replies."
4. "Private voice typing on Mac."
5. "Apple Dictation vs DuckWhisperer in Gmail."
6. "Long ramble into clean email."
7. "Voice type into ChatGPT."
8. "Fix the name it always gets wrong."
9. "What happens if paste fails?"
10. "How much time did I save this week?"

Tone for social:

- Casual.
- Normal office context.
- Show the cursor, shortcut, paste, and final text.
- Do not explain models unless the video is specifically for a technical audience.

## Naming And Domain Plan

Do not buy a premium single-word domain.

Options:

- Keep DuckWhisperer as the app name if a clean non-premium domain is available on `.app`, `.co`, or a two-word `.com`.
- If DuckWhisperer domains are too expensive, keep the product concept and switch before public launch.
- The domain can be descriptive even if the brand is short.

Acceptable domain patterns:

- `use<brand>.com`
- `get<brand>.app`
- `try<brand>.app`
- `<brand>voice.com`
- `<brand>typing.com`
- `<brand>mac.com`

For SEO, the domain matters less than the page title and H1. A domain like `useduckwhisperer.app` or `duckwhisperervoice.app` is acceptable if the homepage title is "Voice Typing for Mac - DuckWhisperer."

Naming decision rule:

- Memorable to office workers.
- Easy to say out loud.
- Not too silly for a manager to expense.
- Not a direct knockoff of another app.
- Cheap domain available.
- No obvious trademark conflict after a basic search.

## Launch Roadmap

### Phase 1: Prelaunch Readiness

Goal: make the product safe for nontechnical users.

- Finish signed/notarized DMG path.
- Add first-run welcome and permission doctor as the default first experience.
- Add support bundle export.
- Add basic crash/error reporting path that preserves privacy.
- Ship Sparkle 2 auto-update flow with signed appcast.
- Finalize name and domain.
- Write privacy policy and terms.
- Create homepage with one video demo.
- Create pricing page.

Exit criteria:

- A nondeveloper can install from DMG, grant permissions, dictate into TextEdit/Gmail, and recover from a paste permission failure without help.

### Phase 2: Private Beta

Goal: prove daily usage and identify setup failures.

- Recruit 25 to 50 Mac office workers.
- Give a one-time beta license.
- Ask them to use it in real work for one week.
- Track qualitative feedback: install success, paste success, first successful dictation, daily reuse, cancellation causes.
- Collect 5 testimonials and 10 raw objections.

Beta questions:

- What app did you use it in first?
- Did it paste where expected?
- Did the output sound like you?
- What made setup confusing?
- Would you pay $49?
- What would make you uninstall?

Exit criteria:

- 80 percent of beta users complete first dictation without live help.
- 50 percent use it again on a second day.
- Paste-back failures have a clear recovery path.

### Phase 3: Public Soft Launch

Goal: validate messaging and conversion.

- Launch homepage, DMG, and trial.
- Publish 5 SEO pages.
- Post 10 short videos over 2 weeks.
- Launch in 2 to 3 Mac/productivity communities.
- Start a small founder-led support loop.
- Offer early access lifetime pricing.

Metrics:

- Visitor to download conversion.
- Download to first successful dictation.
- First dictation to second-day reuse.
- Trial to paid conversion.
- Support issues per 100 installs.
- Paste failures per 100 dictations.

### Phase 4: Scale What Works

Goal: repeat the channel that gets buyers, not just attention.

- Double down on the best converting SEO pages.
- Produce comparison pages only where fair and specific.
- Add affiliate/referral if creator demos convert.
- Add team licenses only after individual usage is strong.
- Consider Setapp or Mac App Store later, but keep direct DMG first for full paste-back capability.

## Metrics

North star:

- Successful paste-backs per active user per week.

Activation:

- Install completed.
- Microphone permission granted.
- Accessibility permission granted.
- First successful dictation.
- First successful paste into another app.

Engagement:

- Dictations per day.
- Words dictated per week.
- Time saved estimate.
- Writing modes used.
- Undo/retry/paste recovery rate.

Revenue:

- Trial starts.
- Paid conversion.
- Refund rate.
- Price sensitivity by cohort.
- Creator/SEO/channel attribution.

Reliability:

- Paste-back success rate.
- Average transcription latency.
- Permission error rate.
- Model download failure rate.
- Crash rate.

## Messaging Matrix

| Audience | Headline | Proof | CTA |
| --- | --- | --- | --- |
| General office worker | Stop typing the long stuff | Works in email, chat, docs, and browser fields | Download for Mac |
| Privacy-sensitive worker | Private voice typing for Mac | Core dictation runs locally | Try it offline |
| Slack/email heavy user | Turn rambling into clean replies | Email and chat writing modes | Watch demo |
| RSI/fatigue user | Give your hands a break | Press one shortcut and talk | Start voice typing |
| Productivity nerd | Save hours of typing each week | Time-saved tracker and local history | Try DuckWhisperer |

## Content Calendar

Week 1:

- Publish homepage.
- Publish `/voice-typing-for-mac`.
- Publish `/mac-dictation-app`.
- Post 3 demo videos.
- Recruit beta users from personal network.

Week 2:

- Publish `/apple-dictation-alternative`.
- Publish `/private-dictation-mac`.
- Post 4 demo videos.
- Gather install failure notes.

Week 3:

- Publish `/superwhisper-alternative`.
- Publish `/wispr-flow-alternative`.
- Post 3 comparison videos.
- Ship fixes from beta.

Week 4:

- Product Hunt or public soft launch.
- Early access pricing.
- Creator outreach.
- Publish "How much typing time did I save?" demo.

## Risks

- App looks like a cheap clone if the brand, icon, and website over-index on bird jokes or Superwhisper comparisons.
- Paste-back reliability is the whole product. If it fails often, marketing will amplify the wrong thing.
- Too many modes make the app feel technical. Keep advanced choices hidden.
- Local-only positioning can become a trap if users expect instant cloud-level speed. Sell privacy and reliability, not magic.
- One-time pricing is simple, but support costs need to be watched.

## Immediate Implementation Plan

1. Freeze current product scope for launch: voice typing, writing modes, personal dictionary, time saved, reliable paste-back, simple settings.
2. Decide brand/domain before public website work. Use DuckWhisperer as codename until then.
3. Build the landing page and 5 SEO pages.
4. Add a real first-run welcome flow if it does not already open automatically.
5. Add trial/license mechanics only after the install path is fully reliable.
6. Package a signed/notarized DMG.
7. Recruit 25 beta users and watch the install + first dictation loop.
8. Use beta feedback to rewrite homepage copy before broader launch.

## Source Notes

Sources checked in May 2026:

- Wispr Flow pricing and plans: https://wisprflow.ai/pricing
- Wispr Flow docs: https://docs.wisprflow.ai/articles/9559327591-flow-plans-and-what-s-included
- Superwhisper Pro pricing: https://superwhisper.com/docs/get-started/sw-pro
- Superwhisper model architecture: https://superwhisper.com/models
- Aqua Voice homepage/pricing: https://aquavoice.com/
- Voibe pricing: https://www.getvoibe.com/pricing/
- MacWhisper homepage/pricing: https://www.macwhisper.net/
- Apple Dictation support: https://support.apple.com/guide/mac-help/dictate-messages-and-documents-mh40584/mac
- Microsoft Word Dictate support: https://support.microsoft.com/office/dictate-your-documents-in-word-3876e05f-3fcc-418f-b8ab-db7ce0d11d3c
- Google Docs voice typing support: https://support.google.com/docs/answer/4492226
- Wispr funding coverage: https://techcrunch.com/2025/06/24/wispr-flow-raises-30m-from-menlo-ventures-for-its-ai-powered-dictation-app/
