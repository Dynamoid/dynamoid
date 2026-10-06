# Human Technical Voice & Style Guide

This document defines the tone, style constraints, and formatting standards for library documentation. Its primary goal is to ensure documentation reads like professional, human-crafted engineering prose (in the tradition of Stripe, Rails, and classic technical publishing) and strictly avoids recognizable AI writing patterns.

---

## 1. Core Principles

1. **Write for Working Developers:** The reader wants to understand concepts clearly and solve problems quickly. Be welcoming, authoritative, and concise. Avoid academic pedantry and patronizing explanations.
2. **Respect the Reading Rhythm:** Technical prose should feel fluid and natural. Vary sentence lengths—alternate short, decisive statements with longer, explanatory sentences.
3. **Show, Don't Lecture:** Anchor concepts in code and concrete behavior rather than abstract generalizations.

---

## 2. Formatting & Typography Rules

### Avoid Bold Overuse
* **Banning Bold Spam:** AI writing models heavily overuse bold text (`**term**`), bolding keywords in every sentence. This creates visual clutter and breaks the reader's flow.
* **Use Italics for Terms:** When introducing a new technical term or concept for the first time, use subtle *italics* (`*primary key*`, *convention over configuration*), or simply keep it in plain text.
* **Tables:** Do not bold every cell in the first column of Markdown tables. The table header already identifies the column. Use plain text unless emphasizing a critical distinction.

### Natural Lists vs. AI Bullet Dumps
* **Never use formulaic bold-prefixed lists:** Strictly avoid lists formatted as:
  ```markdown
  * **Heading 1:** Explanation of heading 1.
  * **Heading 2:** Explanation of heading 2.
  * **Heading 3:** Explanation of heading 3.
  ```
  This is the single most common AI marker.
* **How to Transform Bold-Prefixed Bullets:**
  * *Forbidden (AI Dump):*
    ```markdown
    * **Data representation:** Holds attributes in memory and exposes accessors.
    * **Persistence:** Saves changes with user.save and deletes with user.destroy.
    * **Querying:** Retrieves items with User.find and User.where.
    ```
  * *Transformation 1 (Parallel Verb Clauses sharing a stem):*
    ```markdown
    An Active Record model serves as a unified interface to:

    * Hold attributes in memory with typed accessors.
    * Persist changes and delete items through instance methods (such as `user.save` and `user.destroy`).
    * Retrieve items using class-level queries like `User.find` and `User.where`.
    ```
  * *Transformation 2 (Subtle Italics with Em-Dash Definition List):*
    ```markdown
    An Active Record model unites four core responsibilities:

    * *State* — holds an individual item's attributes in memory and exposes typed accessors.
    * *Persistence* — saves changes and deletes items directly through instance methods (such as `user.save` and `user.destroy`).
    * *Querying* — retrieves items through class-level finders such as `User.find` and `User.where`.
    * *Domain logic* — enforces validation rules and business methods directly on the model alongside its data.
    ```
  * *Transformation 3 (Continuous Prose Paragraph):*
    ```markdown
    An Active Record model serves as a unified interface. An instance holds attributes in memory and coordinates its own persistence with methods like `user.save` and `user.destroy`. At the class level, query methods like `User.find` and `User.where` retrieve items directly from the table.
    ```
* **When to Use Bullets:** Use bullet lists only when all items share a single grammatical stem (e.g., listing supported options, requirements, or sequential takeaways).
* **Link-First Navigation Lists:** In "Next Steps" or table-of-contents lists, put the link first, followed by an em-dash (`—`) and a concise summary:
  ```markdown
  * [Tables & Primary Keys](tables_and_keys.md) — Configure custom table names, partition keys, and sort keys.
  * [Fields & Data Types](fields_and_types.md) — Explore supported types, defaults, and custom serializers.
  ```

### Avoid Redundant Horizontal Rules (`---`)
* **The AI Divider Reflex:** AI writing models routinely insert horizontal rules (`---`) before every `##` and `###` heading as a mechanical section separator.
* **Why It Is Prohibited in Guides:** Documentation generators (such as mdBook, Rails Guides, Docusaurus) already style headings with proportional margins, typography, and borders via CSS. Preceding headings with `<hr>` produces double borders and unsightly whitespace.
* **Legitimate Uses:** Restrict `---` to Markdown frontmatter or rare narrative thematic breaks where no heading exists. Never use them as routine dividers between titled sections.

---

## 3. The Banned Vocabulary & Phrase List

Never use the following empty buzzwords, clichés, and formulaic AI transitions:

| Banned Pattern | Why It Is Banned | Better Alternative |
|---|---|---|
| *seamlessly, effortless, robust* | Generic marketing filler; carries zero technical meaning. | Explain the actual technical mechanism (e.g., "automatically handles retries"). |
| *delve, dive into, unpack, explore* | Overused LLM transition verbs. | State the topic directly: "This section covers...", "To configure...", or just begin the explanation. |
| *game-changer, revolutionizes* | Hyperbolic marketing tone. | Describe the concrete capability. |
| *comprehensive suite / array of* | Vague filler. | Specify what is provided: "supports standard ActiveModel validators". |
| *In today's fast-paced / modern landscape* | Generic introductory throat-clearing. | Delete entirely; start with the problem or library concept. |
| *It is important / crucial to note that...* | Passive hedging; adds unnecessary word count. | State the fact directly: "DynamoDB does not support...", or use a `> [!NOTE]` callout if critical. |
| *Furthermore, Moreover, In conclusion* | Formulaic essay transitions. | Use natural topic transitions or organize into clear subheadings. |
| *It's not just X, it's Y* | Pretentious contrastive framing cliché. | Describe Y directly and accurately. |
| *Rather than being a simple X...* | Unnecessary negative contrast. | Directly state what the feature is and how it works. |

---

## 4. Elimination of "Meta-Talk"

Do not narrate your own writing process to the reader:
* **Avoid:** "In this section, we will explore how callbacks work in Dynamoid."
* **Better:** "Dynamoid integrates `ActiveModel::Callbacks`, providing lifecycle hooks during record persistence."
* **Avoid:** "As we saw in the previous section about keys..."
* **Better:** Link directly to the relevant concept or assume the context established earlier in the guide.

---

## 5. Precise Technical Precision

* **Match Product Terminology Strictly:** When discussing database primitives, use the engine's exact terms (in DynamoDB: *table*, *item*, *attribute*, *partition key*, *sort key*, *query operation*, *scan operation*). Never mix in alien terms like "record" or "row" when explaining DynamoDB internals.
* **No False Hand-Waving:** Never describe an operation as "falling back" or "automagically handling" if the database or library actually requires explicit user action or raises an error.
