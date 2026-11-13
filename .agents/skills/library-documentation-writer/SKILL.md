---
name: library-documentation-writer
description: >-
  Expert guide and quality standards for authoring, reviewing, and refining technical documentation,
  user guides, and API documentation for software libraries and gems. Enforces the Diátaxis framework,
  Rails documentation principles, human technical voice, code-contract verification, and strict anti-AI style rules.
---

# Library Documentation Writer Skill

This skill guides the authoring, reviewing, and refining of user guides and technical documentation for software libraries (with specific optimization for Ruby gems and the `Dynamoid` project).

It enforces a documentation standard based on the **Diátaxis framework**, the **Ruby on Rails documentation philosophy**, and strict **anti-AI style rules** to produce clean, authoritative, human-crafted engineering prose.

---

## Cardinal Invariants (Hard Negative Constraints)

Before drafting, proposing, or writing any documentation text, enforce these non-negotiable rules:

1. **ZERO TOLERANCE: No Bold-Prefixed Bullet Lists (`* **Heading:** Explanation`)**
   * **Never** output lists where bullets start with bold text followed by a colon. This is the single most common AI writing pattern.
   * If tempted to write `* **Concept:** Explanation`, you must rewrite it into one of these human patterns:
     * **Parallel verb clauses sharing a sentence stem:** Introduce the list with a stem (e.g. `...serves as a unified interface to:`) and begin every bullet with an active parallel verb (`* Hold...`, `* Persist...`, `* Retrieve...`).
     * **Subtle italics with em-dash (`* *Concept* — Description`):** If categorical noun anchors are needed for skimmability, anchor each bullet with *italics* and an em-dash (`—`), avoiding tautological verbs (e.g. `* *Persistence* — saves changes...`, not `* *Persistence* — persists...`).
     * **Continuous prose paragraph:** Merge the points into fluid, well-connected prose.
2. **ZERO TOLERANCE: No Redundant Horizontal Dividers (`---`) Between Sections**
   * **Never** insert horizontal rules (`---`) before Markdown headings (`##`, `###`).
   * Headings in modern documentation engines (Rails Guides, mdBook, Docusaurus) already provide visual separation, padding, and borders. Inserting `---` before headings is a reflexive AI divider habit that creates visual clutter and double borders.
3. **Review Mode & Pre-Flight Self-Audit:**
   * Whenever prompted to **"review"** documentation, start by evaluating the guide across the four review topics in [Guide Review Topics](#guide-review-topics) along with the three-pass audit (Code Contract, Architecture, and Human Voice).
   * Always print a proposed draft for the current atomic unit and wait for explicit user approval before calling `edit_file`.
   * Before executing any file edit tool or presenting Markdown drafts, mechanically scan the proposed text. If any line matches `* **Keyword:**` or `---` before a heading, rewrite or remove it immediately before outputting.
4. **ZERO TOLERANCE: Never Output Full Sections During Review (Atomic Paragraphs Only)**
   * During iterative review and discussion with the user, **never** output whole sections or multiple paragraphs at once.
   * Always print **strictly only the specific paragraph or code snippet** currently being discussed. Outputting entire surrounding sections creates cognitive overload and obscures targeted feedback.
5. **ZERO TOLERANCE: Explicit User Confirmation Required Before Switching to Next Work Unit**
   * **Never** print, propose, or output text for the next section, subsection, paragraph, or work unit in the same turn where the previous unit is finalized, edited, or approved.
   * **Strict Two-Step Workflow:**
     1. When a section, paragraph, or edit is completed, confirm the change and **ask explicitly** if the user is ready to move to the next work unit. Do NOT include any proposed text for the upcoming unit in that message.
     2. **Wait** for the user's explicit confirmation (e.g., "yes", "ready"). Only in the subsequent turn—after explicit approval to proceed—may you output the proposed text for the new work unit.
6. **ZERO TOLERANCE: Never Amend Existing Git Commits (Always Create New Commits)**
   * **Never** use `git commit --amend` or propose amending an already existing commit.
   * Always propose or create a **brand-new commit** for newly reviewed and approved changes. Amending rewrites history and obscures the boundary between previously reviewed code and recent modifications.
7. **ZERO TOLERANCE: Never Modify or Propose Modifying the Git Index/Stage**
   * **Never** execute or propose commands that modify the git index or staging area (such as `git add`, `git rm`, `git restore --staged`, `git reset`, or `git update-index`).
   * Staging files and managing the git index is strictly reserved for the developer.
8. **Regenerate HTML Documentation with mdBook:**
   * After applying any changes or edits to Markdown files in `doc/`, always run `mdbook build .mdbook` to regenerate the HTML documentation in `book/` and verify that the build succeeds cleanly.


---

## Guide Review Topics

When reviewing an existing guide or planning a revision, evaluate the document in the following order:

1. *Guide vs. Reference Scope* — Determine what information belongs in a guide-style document versus reference documentation (RDoc). Evaluate the scope of the guide: which concepts, use cases, and examples are important and valuable for a user, and which low-level or exhaustive details should be trimmed or moved out.
2. *Structure and Organization* — Review how the guide is divided into sections, their logical order, the nesting of subsections (`##`, `###`), and the clarity and balance of section titles.
3. *Section Rhythm (Use Case -> Solution -> Code)* — Structure each section as a sequence of plain-text paragraphs each followed by an illustrating code example, avoiding long blocks of unbroken prose or code blocks that dominate the section. Each paragraph should start from a use case or problem, explain the proposed solution, and illustrate it with code.
4. *Prose and Code Example Quality* — Dive into the text and code snippets to check for:
   * Duplication across paragraphs or sections and overly long wording.
   * Unnecessary inline comments in code examples (split multi-example blocks into separate paragraph + code pairs rather than stacking examples with `#` explanatory comments).
   * Code style, indentation, clear variable names (such as `user` and `user_copy` rather than ambiguous `user_a` and `user_b`), code clarity, and how well each snippet illustrates the idea.

---

## The Three-Pass Writing Workflow

Whenever authoring a new guide or revising an existing section, follow this three-pass process:

```text
┌─────────────────────────┐
│ 1. Technical Grounding  │ -> Verify signatures, options, exceptions & deprecations in source code
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ 2. Architecture & Flow  │ -> Map to Diátaxis quadrants; structure progressive disclosure
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ 3. Humanization Audit   │ -> Apply anti-AI ban list; prefer italics over bold; vary rhythm
└─────────────────────────┘
```

---

### Pass 1: Technical Grounding (The Code Contract)
Documentation is an engineering contract. Never write or update documentation from assumption or general LLM memory.

1. **Verify Methods in Source Code:** Search `lib/` for the exact method definition, supported keyword arguments, and defaults.
2. **Check for Deprecations:** Inspect `git grep "deprecator.warn"` to ensure deprecated methods (e.g., dynamic finders, legacy composite key helpers) are not taught as standard syntax.
3. **Verify Warning-Free Execution:** Ensure recommended code patterns do not trigger runtime logger warnings (e.g., method redefinition warnings when overriding implicit fields like `:id` or timestamps). Teach official suppression/override options (such as `skip_generating_fields`).
4. **Confirm Raised Exceptions:** Verify the exact error class raised on validation failure, concurrency conflict, or missing keys.
5. **Distinguish Database Primitives from Library DSL:** Clearly separate what the underlying engine does (DynamoDB tables, items, attributes) from what the gem does (models, fields, criteria):
   * Use **item** strictly for DynamoDB storage and database operations.
   * Use **model** (or model instance) for Ruby classes, in-memory objects, and lifecycle hooks.
   * Reserve **record** strictly for Fowler's Active Record pattern and Rails `ActiveRecord` comparisons—never use "record" to describe Dynamoid entities.
   * Use **field** for Ruby class-level declarations and **attribute** for in-memory values and DynamoDB storage.

*Refer to [Ruby & Library Code Documentation Standards](./references/ruby_doc_standards.md) for code snippet conventions.*

---

### Pass 2: Architecture & Progressive Disclosure
Structure the document to guide the developer smoothly without cognitive overload.

1. **Select the Diátaxis Mode:** Determine whether the section is explaining concepts (**Explanation**), providing a step-by-step recipe (**How-To**), or summarizing API contracts (**Reference**).
2. **Heading Symmetry & Scope Alignment:** Sibling sections at the same hierarchy level (`##`) must follow parallel, balanced naming (e.g., `## Partition Key` and `## Sort Key`). Avoid mixing architectural concept titles with configuration action verbs at the same level.
3. **Follow Progressive Disclosure:**
   * Establish the standard 80% use case first (*convention over configuration*).
   * Introduce customizations and options second.
   * Place edge cases, caveats, and complex overrides in dedicated subsections or callouts.
4. **Feature-Isolated Snippets & Natural Modeling:**
   * Consolidate and minimize the number of model classes introduced within a single guide. Reuse the guide's core domain models across sections (e.g., reusing `Author` and `Book` for options and customizations rather than inventing one-off classes for each snippet). Introduce a new model class only when existing classes cannot naturally illustrate the concept.
   * Strip away unrelated configuration options from code examples (e.g., do not configure custom partition keys in an example demonstrating sort keys).
   * Omit redundant default arguments in baseline examples (e.g., omit `:string` when `range` defaults to `:string`).
   * Preserve natural entity identity (e.g., an `Order` model's identity is its partition key, with foreign keys like `customer_id` or timestamps like `placed_at` serving as sort keys).
   * Place association macros (`belongs_to`, `has_one`, `has_many`, `has_and_belongs_to_many`) above `field` declarations in model classes to match standard Rails conventions.
5. *Summary Tables for Fast Lookup* — When a section introduces a family of types, macros, or options (such as data types, association options, or storage configuration settings), include a concise Markdown summary table before the detailed subsections so returning users can scan names, types, and defaults in under 30 seconds.
6. *Contextual Guidance, Trade-Offs, and Mental-Model Contrasts* — Help readers avoid production pitfalls right where decisions are made:
   * *In-situ callouts (no FAQ graveyards)* — Place warnings, engine constraints, and gotchas (`> [!NOTE]`, `> [!IMPORTANT]`, `> [!WARNING]`) directly inside the relevant feature section rather than collecting them into a disconnected FAQ page.
   * *Active Record contrasts* — Proactively call out where Dynamoid or DynamoDB differs from relational `ActiveRecord` expectations at the point of use (such as associations persisting immediately, `belongs_to` being optional by default, or `field :type` being required for STI).
   * *Architectural trade-offs and "when (not) to use"* — Explain engine limits and design trade-offs alongside the feature (such as when to use `has_many` vs. querying a Global Secondary Index for high-cardinality relationships, numeric vs. string timestamps, or scan vs. query costs).
   * *Rationale for surprising defaults* — When a default exists for backward compatibility or historical DynamoDB constraints (such as `store_empty_string_as_nil` or omitting `nil` attributes), briefly explain *why* so the behavior feels intentional rather than arbitrary.

*Refer to [The Diátaxis Documentation Architecture](./references/diataxis_architecture.md) for structural guidance.*

---

### Pass 3: Humanization & Voice Audit
Audit the text against recognizable AI writing markers to ensure the prose sounds natural, professional, and human.

1. **No Formulaic Bold Bullets:** Strictly eliminate `* **Keyword:** Explanation` bullet lists. Group related thoughts into natural paragraphs or parallel list items.
2. **Italics Over Bold for Terms:** When introducing new technical terms, use subtle *italics* (`*primary key*`, `*partition key*`, `*convention over configuration*`) or plain text. Avoid visual bolding noise (`**word**`).
3. **No Heavy Bold in Tables:** Keep Markdown table cells in clean, plain text. The table headers already identify the columns.
4. **The Hybrid Rule for Ruby Classes vs. Concepts:** Use lowercase plain text for conceptual data shapes ("nested hashes or arrays", "numbers, strings, and booleans"). Use fixed-width code font (`String`, `Integer`, `BigDecimal`, `Set`) for specific Ruby constants, casting targets, and table type columns. Avoid unformatted capitalized plain text ("Ruby Set", "open File") in prose.
5. **Apply the Banned Vocabulary List:**
   * Strip empty buzzwords: *seamlessly*, *robust*, *effortlessly*, *game-changer*, *comprehensive suite*.
   * Strip LLM transitions: *delve*, *dive into*, *unpack*, *in today's landscape*, *furthermore*, *moreover*.
   * Strip passive hedging: *it is important to note that*, *rather than being a simple...*. State facts directly.
6. **Vary Sentence Cadence & Avoid Repetition:** Mix short, punchy statements with longer, explanatory sentences. Eliminate repetitive verbs in adjacent clauses (*"uses X ... but uses Y"*).
7. **Link-First Navigation:** Format "Next Steps" and table-of-contents lists with the link first:
   `* [Title](path.md) — Concise summary of the chapter.`
8. **No Redundant Section Dividers:** Never place `---` lines between `##` or `###` sections. Let headings and vertical whitespace structure the guide.

*Refer to the [Human Technical Voice & Style Guide](./references/human_technical_voice.md) for the full ban list and examples.*

---

## Quick Pre-Publication Checklist

Before proposing or committing documentation changes, verify each item:

- [ ] Every method, option, and exception cited exists in the current gem codebase.
- [ ] No deprecated methods are taught as recommended practices.
- [ ] Recommended code snippets execute cleanly without runtime logger warnings (e.g., method redefinition).
- [ ] Code snippets isolate the feature under discussion without extraneous, unrelated configuration options.
- [ ] Sections follow the `Use Case -> Solution -> Code` rhythm: alternating concise plain-text paragraphs with illustrating code examples (no long walls of text or multi-example code blocks).
- [ ] Unnecessary inline comments in code snippets are removed, and variable names are clear and self-explanatory.
- [ ] Baseline snippets omit redundant default arguments (`range :customer_id` before typed `range :placed_at, :datetime`).
- [ ] Model classes are consolidated across the guide—reusing core classes throughout and introducing new classes only when they more naturally demonstrate a concept.
- [ ] Entity domain modeling respects natural identity (primary identifiers as partition keys, foreign keys/timestamps as sort keys).
- [ ] Sibling headings at the same level maintain parallel, symmetrical naming (`## Partition Key` / `## Sort Key`).
- [ ] The text uses correct domain terminology: *item* for DynamoDB storage, *model* for Ruby classes/instances, and *record* reserved strictly for Active Record pattern / Rails comparisons.
- [ ] Class-level *field* declarations are strictly distinguished from in-memory/DynamoDB *attributes*.
- [ ] Scope is explicitly stated for constraints (partition-level vs. table-wide vs. secondary index uniqueness).
- [ ] Multi-option or multi-type sections include a concise summary table for fast lookup.
- [ ] Caveats, Active Record contrasts, architectural trade-offs, and historical default rationale are placed in-situ alongside the relevant feature rather than in a separate FAQ.
- [ ] No formulaic `* **Keyword:** text` bullet lists are present.
- [ ] Technical terms use *italics* or plain text, not bold (`**`).
- [ ] Table cells are clean plain text without bolding spam.
- [ ] Ruby classes use code font (`String`, `Integer`, `BigDecimal`) while conceptual types use lowercase plain text ("hashes and arrays").
- [ ] No redundant horizontal rules (`---`) separating section headings.
- [ ] Banned buzzwords (*seamlessly*, *robust*, *delve*, etc.) are completely absent.
- [ ] Code snippets are self-contained, syntax-highlighted (`ruby`), and show `# =>` return values (same-line for scalar outputs, next-line for complex objects).
- [ ] Relative cross-references and guide links resolve to existing files.
- [ ] Explicit user confirmation received before printing proposed text for each subsequent section or work unit.
- [ ] Never execute or propose commands that modify the git index or staging area (`git add`, `git rm`, `git reset`, `git restore --staged`).
- [ ] Never amend existing git commits; always create brand-new commits for new changes.
- [ ] Regenerate HTML documentation with `mdbook build .mdbook` after modifying guides.

