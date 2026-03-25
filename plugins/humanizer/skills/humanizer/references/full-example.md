# Full example

This example shows English text. The same principles and process apply to any language.

**Before (AI-sounding):**
> Great question! Here is an essay on this topic. I hope this helps!
>
> AI-assisted coding serves as an enduring testament to the transformative potential of large language models, marking a pivotal moment in the evolution of software development. In today's rapidly evolving technological landscape, these groundbreaking tools - nestled at the intersection of research and practice - are reshaping how engineers ideate, iterate, and deliver, underscoring their vital role in modern workflows.
>
> At its core, the value proposition is clear: streamlining processes, enhancing collaboration, and fostering alignment. It's not just about autocomplete; it's about unlocking creativity at scale, ensuring that organizations can remain agile while delivering seamless, intuitive, and powerful experiences to users. The tool serves as a catalyst. The assistant functions as a partner. The system stands as a foundation for innovation.
>
> Industry observers have noted that adoption has accelerated from hobbyist experiments to enterprise-wide rollouts, from solo developers to cross-functional teams. The technology has been featured in The New York Times, Wired, and The Verge. Additionally, the ability to generate documentation, tests, and refactors showcases how AI can contribute to better outcomes, highlighting the intricate interplay between automation and human judgment.
>
> - **Speed:** Code generation is significantly faster, reducing friction and empowering developers.
> - **Quality:** Output quality has been enhanced through improved training, contributing to higher standards.
> - **Adoption:** Usage continues to grow, reflecting broader industry trends.
>
> While specific details are limited based on available information, it could potentially be argued that these tools might have some positive effect. Despite challenges typical of emerging technologies - including hallucinations, bias, and accountability - the ecosystem continues to thrive. In order to fully realize this potential, teams must align with best practices.
>
> In conclusion, the future looks bright. Exciting times lie ahead as we continue this journey toward excellence. Let me know if you'd like me to expand on any section!

**Content Intelligence scan:**
- Language: English
- Content type: Blog/essay (opinionated, first-person wrapper, informal register)
- Mixed content: None
- Voice signals: Chatbot wrapper has first-person ("I hope"), but the body is neutral - Content Integrity mode for the body
- AI density: HIGH - 10+ Tier 1 patterns, uniform sentence length, extreme pattern stacking

**Self-audit Pass 1 - adversarial self-question:**
*(Internal: "What makes this text still obviously AI-generated after my first draft?")*

- First draft used "I've accepted suggestions" - that's first-person voice injected into Content Integrity mode. Remove.
- First draft mentioned a specific GitHub acceptance-rate statistic - that number wasn't in the original. Anti-hallucination violation. Remove.
- Rhythm in paragraphs 2-3 was too evenly varied - overcorrection. Make it messier.
- "Both seem reasonable" at the end of a paragraph is too neat - it's a mini-conclusion.

*(Fixed all four before proceeding to Pass 2.)*

**Final rewrite:**
> AI coding tools help with the boring parts - boilerplate, test scaffolding, repetitive refactors. They're less useful for architecture or anything requiring judgment about trade-offs.
>
> Adoption has grown. The original text mentions media coverage (NYT, Wired, The Verge) but not what those outlets actually said, so it's hard to know what the coverage means. Code generation is faster, and output quality has improved with better training data.
>
> The real question is whether "faster" means "better." These tools can generate code that compiles and passes lint but still misses the point. Hallucinations, bias, and accountability remain open problems - the original text acknowledges this but doesn't say how teams are addressing them.
>
> Documentation and test generation are probably the strongest use cases. The gap between automation and human judgment matters most when the stakes are high. For config files, less so.

**Content preservation check:**
- ✓ Core claim (AI tools reshape development) - preserved, made more specific
- ✓ Adoption growth - preserved
- ✓ Media coverage - preserved with caveat about vagueness (original was vague)
- ✓ Speed/quality/adoption benefits - preserved, converted from list to prose
- ✓ Challenges (hallucinations, bias, accountability) - preserved
- ✓ Documentation/test generation - preserved
- ✓ Automation vs. human judgment - preserved
- ✗ "Creativity at scale" claim - dropped (filler with no specific content behind it)
- ✗ "Best practices" recommendation - dropped (generic, no actionable content)
- Note: Did NOT invent any statistics or specific citations not in the original

**Quality scoring:**
| Dimension | Score | Notes |
|-----------|-------|-------|
| Directness | 8 | No filler, no throat-clearing |
| Rhythm | 7 | Good variation, one paragraph could be shorter |
| Trust | 8 | States things and moves on; calls out original's vagueness rather than filling gaps |
| Authenticity | 7 | Reads human; some sentences could be more opinionated but Content Integrity mode limits this |
| Preservation | 9 | All substantive claims preserved; only pure filler dropped |
| **Total** | **39/50** | Passes quality gate (≥35) |

**Changes made:**
- Removed chatbot artifacts ("Great question!", "I hope this helps!", "Let me know if...", "While specific details are limited...")
- Removed significance inflation ("testament", "pivotal moment", "evolving landscape", "vital role")
- Removed promotional language ("groundbreaking", "nestled", "seamless, intuitive, and powerful")
- Removed vague attributions ("Industry observers") - noted the vagueness rather than fabricating specifics
- Removed participial tails ("underscoring", "highlighting", "reflecting", "contributing to", "reducing friction", "empowering")
- Removed negative parallelism ("It's not just X; it's Y")
- Removed rule of three ("catalyst/partner/foundation", "streamlining/enhancing/fostering")
- Removed false ranges ("from X to Y, from A to B")
- Removed copula avoidance ("serves as", "functions as", "stands as")
- Removed formulaic conclusion ("the future looks bright", "exciting times lie ahead", "journey toward excellence")
- Removed hedging ("could potentially be argued that... might have some")
- Removed filler ("In order to", "At its core", "the value proposition is clear:")
- Removed conclusion bloat ("In conclusion...")
- Converted bold-label bullet list to flowing prose (Pattern 13)
- Applied statistical texture: varied paragraph lengths (2-4 sentences), mixed sentence lengths, used contractions, added parenthetical
- Used pronouns ("they're") instead of restating noun phrases
- Anti-hallucination: explicitly did NOT invent statistics or citations to replace vague original claims

> Verification: 0 Tier 1 patterns remaining. Quality: 39/50. Sentence length range: 4–28 words. Paragraph length range: 2–4 sentences.

---

## Example 2: Technical documentation (short, with code)

**Before (AI-sounding):**
> ## Getting Started
>
> It's important to note that this library leverages WebSocket connections to facilitate real-time data synchronization. The library serves as a robust foundation for building responsive applications, streamlining the process of managing state across distributed systems.
>
> To get started, you'll need to install the package. Additionally, ensure that your environment is properly configured. The installation process is straightforward:
>
> ```bash
> npm install sync-state
> ```
>
> The library boasts a comprehensive API that empowers developers to harness the full potential of real-time synchronization. Overall, it's a powerful tool that plays a crucial role in modern application development.

**Content Intelligence scan:**
- Language: English
- Content type: Technical documentation (third-person, precise register, no opinions)
- Mixed content: Yes - fenced code block (preserve exactly)
- Voice signals: No first-person, no opinions → Content Integrity mode
- AI density: HIGH - 7 Tier 1 patterns in ~100 words

**Final rewrite:**
> ## Getting started
>
> This library uses WebSocket connections for real-time state sync across distributed systems.
>
> Install the package:
>
> ```bash
> npm install sync-state
> ```
>
> The API docs cover connection setup, state management, and conflict resolution.

**Changes made:**
- Removed didactic disclaimer ("It's important to note")
- Replaced AI vocabulary: "leverages" → "uses", "facilitate" → cut, "robust" → cut, "streamlining" → cut, "straightforward" → cut, "comprehensive" → cut, "empowers" → cut, "harness" → cut, "crucial role" → cut
- Removed copula avoidance ("serves as a robust foundation" → cut entirely)
- Removed significance inflation ("boasts", "full potential")
- Removed conclusion bloat ("Overall, it's a powerful tool that plays a crucial role")
- Removed formulaic transition ("Additionally")
- Removed filler ("the process of", "you'll need to", "ensure that your environment is properly configured")
- Title case → sentence case in heading
- Preserved code block exactly
- Content Integrity mode: no personality added (technical docs)

> Verification: 0 Tier 1 patterns remaining. Quality: 41/50. Sentence length range: 3–12 words. Paragraph length range: 1–2 sentences.
