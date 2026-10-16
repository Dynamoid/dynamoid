# The Diátaxis Documentation Architecture

The Diátaxis framework organizes technical documentation into four distinct quadrants based on two axes: **Action vs. Cognition** (doing vs. understanding) and **Acquisition vs. Application** (learning vs. working).

```text
               PRACTICAL / ACTION
                      │
       Tutorials      │     How-To Guides
   (Learning by doing)│  (Problem-solving)
                      │
LEARNING ─────────────┼───────────── WORKING
                      │
     Explanation      │       Reference
  (Understanding why) │     (Looking up facts)
                      │
              THEORETICAL / COGNITION
```

Separating these modes prevents the common anti-pattern of the "kitchen-sink" manual, where reference details, high-level architecture, and step-by-step setup are mixed into a confusing hybrid.

---

## The Four Quadrants

### 1. Tutorials (Learning-Oriented)
* **Audience:** A beginner who needs to experience a complete, successful workflow.
* **Goal:** Enable the learner to build competence and confidence through concrete action.
* **Characteristics:**
  * Linear, step-by-step progression with zero branching or optional tangents.
  * Guarantees a working result at the end (e.g., "Install the gem, define your first model, and persist a record").
  * Explains just enough theory to understand the immediate action; defers edge cases and advanced options to other guides.

### 2. How-To Guides (Task-Oriented)
* **Audience:** A developer who knows the basics and wants to solve a specific problem.
* **Goal:** Provide a reliable recipe for an explicit task (e.g., "How to configure a Global Secondary Index", "How to perform atomic counter updates", "How to configure Strong Consistency").
* **Characteristics:**
  * Assumes basic competence; skips beginner explanations.
  * Clear preconditions and concrete outcome.
  * Explains options and trade-offs directly relevant to the task.

### 3. Reference (Information-Oriented)
* **Audience:** A developer actively writing code who needs to check an exact technical contract.
* **Goal:** Present authoritative, unembellished facts.
* **Characteristics:**
  * Method signatures, parameter types, default values, return types, and raised exceptions.
  * Mirrors the software's codebase structure (modules, classes, and methods).
  * In Ruby gems, this is primarily managed via RDoc or YARD comments in the source code, complemented by high-level option tables in user guides.

### 4. Explanation / Concepts (Understanding-Oriented)
* **Audience:** A developer who wants to understand how the system works and why it was designed that way.
* **Goal:** Provide mental models, architectural background, and design rationale.
* **Characteristics:**
  * Answers *why*: explains trade-offs, limitations, and comparisons (e.g., "The DynamoDB Data Model", "Key Differences from Relational Databases", "Why Fields Must Be Explicitly Declared").
  * Free from step-by-step task instructions; focuses on illuminating the system.

---

## Applying Diátaxis to Ruby Library Guides

In a comprehensive documentation suite (like Rails Guides or Dynamoid's 12-chapter catalog), individual chapters often strike a deliberate balance:

1. **Chapter 1 (Getting Started):** Pairs an introductory **Explanation** (mental model, database trade-offs) with a beginner **Tutorial/Walkthrough** (install, define a model, run CRUD).
2. **Topic Chapters (Chapters 2–10):** Focus on **How-To Guides & Conceptual Deep-Dives** for specific subsystems (e.g., Tables & Keys, Secondary Indexes, Query Interface), linking to RDoc for exhaustive parameter reference.
3. **Operational Chapters (Chapters 11–12):** Provide task-oriented recipes for configuration, runtime environments, and testing.

### Cross-Referencing Rule
When writing a guide:
* If you find yourself listing every option and internal flag, link to the **Reference (RDoc)**.
* If you find yourself explaining deep architectural history or database theory, link to or isolate it in an **Explanation** section.
* Keep the main narrative focused on guiding the developer through practical comprehension.
