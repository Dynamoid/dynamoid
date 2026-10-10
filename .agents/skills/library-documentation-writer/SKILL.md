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
   * Whenever prompted to **"review"** documentation, do not stop at conversational high-level commentary. Systematically execute the three-pass audit (Code Contract, Architecture, and Human Voice).
   * Before executing any file edit tool or presenting Markdown drafts, mechanically scan the proposed text. If any line matches `* **Keyword:**` or `---` before a heading, rewrite or remove it immediately before outputting.

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
   * Strip away unrelated configuration options from code examples (e.g., do not configure custom partition keys in an example demonstrating sort keys).
   * Omit redundant default arguments in baseline examples (e.g., omit `:string` when `range` defaults to `:string`).
   * Preserve natural entity identity (e.g., an `Order` model's identity is its partition key, with foreign keys like `customer_id` or timestamps like `placed_at` serving as sort keys).

*Refer to [The Diátaxis Documentation Architecture](./references/diataxis_architecture.md) for structural guidance.*

---

### Pass 3: Humanization & Voice Audit
Audit the text against recognizable AI writing markers to ensure the prose sounds natural, professional, and human.

1. **No Formulaic Bold Bullets:** Strictly eliminate `* **Keyword:** Explanation` bullet lists. Group related thoughts into natural paragraphs or parallel list items.
2. **Italics Over Bold for Terms:** When introducing new technical terms, use subtle *italics* (`*primary key*`, `*partition key*`, `*convention over configuration*`) or plain text. Avoid visual bolding noise (`**word**`).
3. **No Heavy Bold in Tables:** Keep Markdown table cells in clean, plain text. The table headers already identify the columns.
4. **Apply the Banned Vocabulary List:**
   * Strip empty buzzwords: *seamlessly*, *robust*, *effortlessly*, *game-changer*, *comprehensive suite*.
   * Strip LLM transitions: *delve*, *dive into*, *unpack*, *in today's landscape*, *furthermore*, *moreover*.
   * Strip passive hedging: *it is important to note that*, *rather than being a simple...*. State facts directly.
5. **Vary Sentence Cadence & Avoid Repetition:** Mix short, punchy statements with longer, explanatory sentences. Eliminate repetitive verbs in adjacent clauses (*"uses X ... but uses Y"*).
6. **Link-First Navigation:** Format "Next Steps" and table-of-contents lists with the link first:
   `* [Title](path.md) — Concise summary of the chapter.`
7. **No Redundant Section Dividers:** Never place `---` lines between `##` or `###` sections. Let headings and vertical whitespace structure the guide.

*Refer to the [Human Technical Voice & Style Guide](./references/human_technical_voice.md) for the full ban list and examples.*

---

## Quick Pre-Publication Checklist

Before proposing or committing documentation changes, verify each item:

- [ ] Every method, option, and exception cited exists in the current gem codebase.
- [ ] No deprecated methods are taught as recommended practices.
- [ ] Recommended code snippets execute cleanly without runtime logger warnings (e.g., method redefinition).
- [ ] Code snippets isolate the feature under discussion without extraneous, unrelated configuration options.
- [ ] Baseline snippets omit redundant default arguments (`range :customer_id` before typed `range :placed_at, :datetime`).
- [ ] Entity domain modeling respects natural identity (primary identifiers as partition keys, foreign keys/timestamps as sort keys).
- [ ] Sibling headings at the same level maintain parallel, symmetrical naming (`## Partition Key` / `## Sort Key`).
- [ ] The text uses correct domain terminology: *item* for DynamoDB storage, *model* for Ruby classes/instances, and *record* reserved strictly for Active Record pattern / Rails comparisons.
- [ ] Class-level *field* declarations are strictly distinguished from in-memory/DynamoDB *attributes*.
- [ ] Scope is explicitly stated for constraints (partition-level vs. table-wide vs. secondary index uniqueness).
- [ ] No formulaic `* **Keyword:** text` bullet lists are present.
- [ ] Technical terms use *italics* or plain text, not bold (`**`).
- [ ] Table cells are clean plain text without bolding spam.
- [ ] No redundant horizontal rules (`---`) separating section headings.
- [ ] Banned buzzwords (*seamlessly*, *robust*, *delve*, etc.) are completely absent.
- [ ] Code snippets are self-contained, syntax-highlighted (`ruby`), and show `# =>` return values.
- [ ] Relative cross-references and guide links resolve to existing files.
