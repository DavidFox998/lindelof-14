namespace TheoremaAureum.YM_MassGap
def sum_sq : List Int → Nat := 
  fun xs => (xs.map fun x => (x.natAbs * x.natAbs)).foldl (· + ·) 0

theorem lattice_positivity : 
  ∀ xs : List Int, 0 ≤ sum_sq xs ∧ (sum_sq xs = 0 ↔ xs.all (· = 0)) := by 
  intro xs
  constructor
  · unfold sum_sq; induction xs <;> simp_arith
  · induction xs with
    | nil => simp [sum_sq]
    | cons h t ih => 
      simp [sum_sq, List.all]
      constructor
      · intro hsum
        have : h.natAbs * h.natAbs = 0 := by 
          apply Nat.eq_zero_of_add_eq_zero_left hsum
        have : h = 0 := by cases h <;> simp [Int.natAbs] at this ⊢; cases this
        simp [this, ih.mp (Nat.eq_zero_of_add_eq_zero_right hsum)]
      · intro hall; simp [hall]
end TheoremaAureum.YM_MassGap
