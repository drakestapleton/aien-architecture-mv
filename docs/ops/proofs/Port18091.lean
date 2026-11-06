/-
Port18091.lean: the :18091 own-model recovery state machine of docs/ops/SPARK_TEST_SCHEDULE.md
section 4, as an explicit model, with the invariant proved for every reachable state.

Model-to-system link: hand-copied from that section's transition table (this repository, branch
hive/dra118-own-model-schedule). It is a model of the PLAN, not of any running service: nothing
here inspects a process, a port or a manifest file.

Port: down (nothing bound), own m (an ollm serve process started from frozen manifest m),
external w (any retired or outside weights, e.g. the 35B). V m means manifest m passed the
DRA-125 freeze + acceptance checks ("verified"). last is the recovery target.
-/

namespace P18091

inductive Port where
  | down
  | own (m : Nat)
  | external (w : Nat)

structure St where
  port : Port
  last : Option Nat

inductive Ev where
  | cutover (m : Nat)        -- bind :18091 to manifest m (refused unless V m)
  | crash                    -- the server died
  | stop                     -- clean stop to the truthful unavailable state
  | recover                  -- restart from the recovery target, or stay down
  | restoreExternal (w : Nat) -- the retired 35B restore; the plan refuses it

def portOk (V : Nat → Prop) : Port → Prop
  | .down => True
  | .own m => V m
  | .external _ => False

def Safe (V : Nat → Prop) (s : St) : Prop :=
  portOk V s.port ∧ ∀ m, s.last = some m → V m

def init : St := ⟨.down, none⟩

def step (V : Nat → Prop) [DecidablePred V] (s : St) : Ev → St
  | .cutover m => if V m then ⟨.own m, some m⟩ else s
  | .crash => ⟨.down, s.last⟩
  | .stop => ⟨.down, s.last⟩
  | .recover =>
      match s.last with
      | some m => ⟨.own m, some m⟩
      | none => ⟨.down, none⟩
  | .restoreExternal _ => s

theorem inv_init (V : Nat → Prop) : Safe V init := by
  refine ⟨trivial, ?_⟩
  intro m h
  simp [init] at h

theorem inv_step (V : Nat → Prop) [DecidablePred V] (s : St) (e : Ev)
    (h : Safe V s) : Safe V (step V s e) := by
  obtain ⟨hp, hl⟩ := h
  cases e with
  | cutover m =>
      by_cases hv : V m
      · refine ⟨?_, ?_⟩
        · simp [step, hv, portOk]
        · intro m' hm
          simp [step, hv] at hm
          subst hm
          exact hv
      · simp only [step, hv, ite_false]
        exact ⟨hp, hl⟩
  | crash => exact ⟨trivial, hl⟩
  | stop => exact ⟨trivial, hl⟩
  | recover =>
      cases hs : s.last with
      | none =>
          refine ⟨?_, ?_⟩
          · simp [step, hs, portOk]
          · intro m hm
            simp [step, hs] at hm
      | some m =>
          have hm : V m := hl m hs
          refine ⟨?_, ?_⟩
          · simp [step, hs, portOk, hm]
          · intro m' hm'
            simp [step, hs] at hm'
            subst hm'
            exact hm
  | restoreExternal w => exact ⟨hp, hl⟩

/-- Every state reachable from init by any finite event sequence keeps the invariant:
:18091 is down or serves a verified own manifest, and the recovery target is verified. -/
theorem inv_reachable (V : Nat → Prop) [DecidablePred V] (es : List Ev) :
    Safe V (es.foldl (step V) init) := by
  have key : ∀ (l : List Ev) (s : St), Safe V s → Safe V (l.foldl (step V) s) := by
    intro l
    induction l with
    | nil => intro s h; exact h
    | cons e rest ih => intro s h; exact ih _ (inv_step V s e h)
  exact key es init (inv_init V)

/-- Negative control: the retired plan (restore the 35B on :18091) breaks the invariant. -/
def badStep (V : Nat → Prop) [DecidablePred V] (s : St) : Ev → St
  | .restoreExternal w => ⟨.external w, s.last⟩
  | e => step V s e

theorem bad_breaks (V : Nat → Prop) [DecidablePred V] :
    ¬ Safe V (badStep V init (.restoreExternal 0)) := by
  intro h
  exact h.1

/-- Negative control: a cutover that skips the verification check breaks it for an
unverified manifest. -/
def uncheckedStep (V : Nat → Prop) [DecidablePred V] (s : St) : Ev → St
  | .cutover m => ⟨.own m, some m⟩
  | e => step V s e

theorem unchecked_breaks (V : Nat → Prop) [DecidablePred V] (m : Nat) (hm : ¬ V m) :
    ¬ Safe V (uncheckedStep V init (.cutover m)) := by
  intro h
  exact hm h.1

end P18091

#print axioms P18091.inv_reachable
#print axioms P18091.bad_breaks
#print axioms P18091.unchecked_breaks
