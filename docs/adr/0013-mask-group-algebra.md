# ADR 0013 — Mask Group Architecture and Boolean Coverage Algebra (Lightroom Parity)

- **Status:** Accepted
- **Date:** 2026-10-17
- **Deciders:** Developer's Paradise
- **Consults:** ADR 0003 (Non-destructive recipe model), ADR 0008 (Dual UI shells), ADR 0010 (On-device ML stack), Issue #90, Issue #91, Issue #92

---

## 1. Context

In professional photo editing (Adobe Lightroom Mobile/Desktop), local adjustments are not merely a flat list of independent masks. Complex photographic adjustments require combining spatial and semantic selections:
- **Select Subject MINUS Linear Gradient:** Darken or vignette the background or ground while protecting the human subject.
- **Select Sky INTERSECT Radial Gradient:** Brighten only the sunset hotspot in the clouds without affecting terrain or foreground trees.
- **Color Range / Luminosity PLUS Brush:** Broadly target highlights and selectively brush in or erase specific specular details.

Previously, ApertureX adjustment layers (`AdjustmentLayer`) evaluated sequentially in isolation:
$$\text{image}_{k} = \text{lerp}(\text{image}_{k-1}, \text{graded}(\text{image}_{k-1}), \text{cov}_k \times \text{amount}_k)$$
This architecture prevented boolean operations between masks and caused multiple passes over image memory.

---

## 2. Decision

### 2.1 Boolean Coverage Algebra
A Mask Group is composed of one or more member masks evaluated in order into a single scalar coverage buffer $\text{cov} \in [0.0, 1.0]$:

1. **Initial Coverage ($\text{cov}_0$):**
   - The first member initiates coverage with its computed mask coverage $\text{cov}_{\text{first}} = \text{coverage}(\text{member}_0) \times \text{member}_0.\text{amount}$. If inverted, $\text{cov}_{\text{first}} = (1.0 - \text{coverage}(\text{member}_0)) \times \text{member}_0.\text{amount}$.
2. **Operations:**
   For subsequent member $m_k$ with evaluated coverage $c_k = \text{coverage}(m_k) \times m_k.\text{amount}$ (inverted if $m_k.\text{inverted}$):
   - **Add (Union):** Linear clamp addition matching Lightroom standard:
     $$\text{cov}_k = \min(\text{cov}_{k-1} + c_k, 1.0)$$
   - **Subtract (Difference):**
     $$\text{cov}_k = \max(\text{cov}_{k-1} - c_k, 0.0)$$
   - **Intersect (Intersection):**
     $$\text{cov}_k = \text{cov}_{k-1} \times c_k$$
3. **Group Invert:**
   If the group has `inverted: true`:
   $$\text{cov}_{\text{final}} = 1.0 - \text{cov}_N$$
4. **Group Amount:**
   Global group amount $\text{amount}_{\text{group}} \in [0.0, 2.0]$ scales coverage:
   $$t = \text{cov}_{\text{final}} \times \text{amount}_{\text{group}}$$
   For $t \le 0.0$, pixel grading is skipped. For $t > 1.0$, lerp extrapolation (overdrive) is preserved as specified in ADR/Issue #91, clamping only when writing final 8-bit channels.

### 2.2 Grade Placement: Group-Level vs Member-Level
In Adobe Lightroom, adjustment components (subject, sky, brush, gradient) define **geometry and selection coverage**; color and exposure grades live strictly at the **group level**.
ApertureX adopts this standard:
- Group members define mask geometry, individual `amount` ($0..200\%$), `inverted` flag, and `joinOp` (`add`, `subtract`, `intersect`).
- The **Group** owns the grading parameters (`exposure`, `contrast`, `highlights`, `shadows`, `saturation`, `temperature`, `tint`), `amount`, and `inverted`.
- **Backward Compatibility:** Any ungrouped/legacy layer is treated as an implicit single-member group where the layer's own grade parameters are applied.

### 2.3 Recipe Schema & Compatibility
To maintain complete backwards compatibility with existing UI callers (`recipe.layers`, `nodeEditorProvider.selected`, brush stroke modifiers):
1. `AdjustmentLayer` gains:
   - `groupId: String?` (UUID string matching parent `MaskGroup.id`, or null if ungrouped).
   - `joinOp: MaskJoinOp` (`add`, `subtract`, `intersect`, default `add`).
2. `EditRecipe` maintains `layers: List<AdjustmentLayer>` and adds:
   - `maskGroups: List<MaskGroup>` (default `[]`).
   - `currentSchemaVersion` bumped to `21`.
3. Legacy recipes (v20 and earlier) load with `maskGroups: []` and empty `groupId`s on layers, which renders byte-identically to prior behavior.

### 2.4 Bridge & Execution Plan
In Rust:
- `MaskLayer` represents individual mask primitives.
- `MaskGroupDef` specifies group metadata: `id: String`, `name: String`, `inverted: bool`, `amount: f32`, `params: ColorParams`, and list of member layers with their `joinOp`.
- Engine evaluates the group's composite coverage in a single combined pass, then blends the group's pointwise grade once, reducing memory round-trips.

---

## 3. Consequences

### Positive
- **Full Lightroom Feature Parity:** Enables "Select Subject minus Linear Gradient", "Select Sky intersect Radial", and complex multi-tool masks.
- **Single Grade Per Group:** Cleaner UI, avoids stacking conflicting grades across nested members.
- **Fast Execution:** Eliminates redundant intermediate RGB lerps by computing coverage before applying the pointwise grade.
- **Complete Backwards Compatibility:** Flat ungrouped layers render identically with zero migration overhead.

### Negative & Mitigations
- **Complexity in UI:** Mask stack in `mask_controls.dart` must handle tree-like groupings.
  *Mitigation:* Clean collapsible group cards with clear member indentation and explicit Add/Subtract/Intersect segmented chips.
- **State Serialization:** Group IDs and ordering must be tracked deterministically.
  *Mitigation:* UUIDs with hash-stable ordering in `EditRecipe`.
