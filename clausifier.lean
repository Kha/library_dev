import clause
import prover_state
open expr list tactic monad decidable

meta def head_lit_rule := clause.literal → clause → tactic (option (list clause))

meta def inf_whnf (l : clause.literal) (c : clause) : tactic (option (list clause)) := do
normalized ← whnf l↣formula,
if normalized = l↣formula then return none else
match l with
| clause.literal.left _ := return $ some [{ c with type := imp normalized c↣type↣binding_body }]
| clause.literal.right _ := return $ some [{ c with type := imp normalized↣not_ c↣type↣binding_body }]
end

set_option eqn_compiler.max_steps 500

meta def inf_false_l (l : clause.literal) (c : clause) : tactic (option (list clause)) :=
match l with
| clause.literal.left (const false_name _) :=
  if false_name = ``false then
     return (some [])
   else
     return none
| _ :=  return none
end

lemma false_r {c} : (¬false → c) → c := λnfc, nfc (λx, x)
meta def inf_false_r (l : clause.literal) (c : clause) : tactic (option (list clause)) :=
match l with
| clause.literal.right (const false_name _) :=
if false_name = ``false then do
  proof' ← mk_mapp ``false_r [none, some c↣proof],
  return $ some [{ c with num_lits := c↣num_lits - 1, proof := proof', type := binding_body c↣type }]
else
  return none
| _ := return none
end

lemma true_l {c} : (true → c) → c := λtc, tc true.intro
meta def inf_true_l (l : clause.literal) (c : clause) : tactic (option (list clause)) :=
match l with
| clause.literal.left (const true_name _) :=
if true_name = ``true then do
  proof' ← mk_mapp ``true_l [none, some c↣proof],
  return $ some [{ c with num_lits := c↣num_lits - 1, proof := proof', type := binding_body c↣type }]
else
  return none
| _ := return none
end

meta def inf_true_r (l : clause.literal) (c : clause) : tactic (option (list clause)) :=
match l with
| clause.literal.right (const true_name _) :=
if true_name = ``true then do
  return (some [])
else
  return none
| _ := return none
end

lemma not_r {a c} : (¬¬a → c) → (a → c) := λnnac a, nnac (λx, x a)
meta def inf_not_r (l : clause.literal) (c : clause) : tactic (option (list clause)) :=
match (l, is_not (clause.literal.formula l)) with
| (clause.literal.right _, some a) := do
  proof' ← mk_mapp ``not_r [none, none, some c↣proof],
  return $ some [{ c with proof := proof', type := imp a (binding_body c↣type) }]
| _ := return none
end

lemma and_l {a b c} : ((a ∧ b) → c) → (a → b → c) := λabc a b, abc (and.intro a b)
meta def inf_and_l (l : clause.literal) (c : clause) : tactic (option (list clause)) :=
match l with
| clause.literal.left (app (app (const and_name _) a) b) :=
  if and_name = ``and then do
    proof' ← mk_mapp ``and_l [none, none, none, some c↣proof],
    return $ some [{ c with num_lits := c↣num_lits + 1, proof := proof', type := imp a (imp b (binding_body c↣type)) }]
  else return none
| _ := return none
end

lemma and_r1 {a b c} : (¬(a ∧ b) → c) → (¬a → c) := λnabc na, nabc (λab, na (and.left ab))
lemma and_r2 {a b c} : (¬(a ∧ b) → c) → (¬b → c) := λnabc na, nabc (λab, na (and.right ab))
meta def inf_and_r (l : clause.literal) (c : clause) : tactic (option (list clause)) :=
match l with
| clause.literal.right (app (app (const and_name _) a) b) :=
  if and_name = ``and then do
    proof₁ ← mk_mapp ``and_r1 [none, none, none, some c↣proof],
    proof₂ ← mk_mapp ``and_r2 [none, none, none, some c↣proof],
    na ← mk_mapp ``not [some a],
    nb ← mk_mapp ``not [some b],
    return $ some [
      { c with proof := proof₁, type := imp na (binding_body c↣type) },
      { c with proof := proof₂, type := imp nb (binding_body c↣type) }
    ]
  else return none
| _ := return none
end

lemma or_r {a b c} : (¬(a ∨ b) → c) → (¬a → ¬b → c) := λnabc na nb, nabc (λab, or.elim ab na nb)
meta def inf_or_r (l : clause.literal) (c : clause) : tactic (option (list clause)) :=
match l with
| clause.literal.right (app (app (const or_name _) a) b) :=
  if or_name = ``or then do
    na ← mk_mapp ``not [some a],
    nb ← mk_mapp ``not [some b],
    proof' ← mk_mapp ``or_r [none, none, none, some c↣proof],
    return $ some [{ c with num_lits := c↣num_lits + 1, proof := proof', type := imp na (imp nb (binding_body c↣type)) }]
  else return none
| _ := return none
end

lemma or_l1 {a b c} : ((a ∨ b) → c) → (a → c) := λabc a, abc (or.inl a)
lemma or_l2 {a b c} : ((a ∨ b) → c) → (b → c) := λabc b, abc (or.inr b)
meta def inf_or_l (l : clause.literal) (c : clause) : tactic (option (list clause)) :=
match l with
| clause.literal.left (app (app (const or_name _) a) b) :=
  if or_name = ``or then do
    proof₁ ← mk_mapp ``or_l1 [none, none, none, some c↣proof],
    proof₂ ← mk_mapp ``or_l2 [none, none, none, some c↣proof],
    return $ some [
      { c with proof := proof₁, type := imp a (binding_body c↣type) },
      { c with proof := proof₂, type := imp b (binding_body c↣type) }
    ]
  else return none
| _ := return none
end

lemma all_r {a} {b : a → Prop} {c} : (¬(∀x:a, b x) → c) → (∀x:a, ¬b x → c) := λnabc a nb, nabc (λab, absurd (ab a) nb)
meta def inf_all_r (l : clause.literal) (c : clause) : tactic (option (list clause)) :=
match l with
| clause.literal.right (pi n bi a b) := do
    nb ← mk_mapp ``not [some b],
    proof' ← mk_mapp ``all_r [none, none, none, some c↣proof],
    return $ some [{ c with num_quants := 1, proof := proof', type := pi n bi a (imp nb (binding_body c↣type)) }]
| _ := return none
end

lemma imp_l1 {a b c} : ((a → b) → c) → (¬a → c) := λabc na, abc (λa, absurd a na)
lemma imp_l2 {a b c} : ((a → b) → c) → (b → c) := λabc b, abc (λa, b)
meta def inf_imp_l (l : clause.literal) (c : clause) : tactic (option (list clause)) :=
match l with
| clause.literal.left (pi _ _ a b) :=
  if ¬has_var b then do
    proof₁ ← mk_mapp ``imp_l1 [none, none, none, some c↣proof],
    proof₂ ← mk_mapp ``imp_l2 [none, none, none, some c↣proof],
    na ← mk_mapp ``not [some a],
    return $ some [
      { c with proof := proof₁, type := imp na (binding_body c↣type) },
      { c with proof := proof₂, type := imp b (binding_body c↣type) }
    ]
  else return none
| _ := return none
end

lemma ex_l {a} {b : a → Prop} {c} : ((∃x:a, b x) → c) → (∀x:a, b x → c) := λeabc a b, eabc (exists.intro a b)
meta def inf_ex_l (l : clause.literal) (c : clause) : tactic (option (list clause)) :=
match l with
| clause.literal.left (app (app (const ex_name _) d) p) :=
  if ex_name = ``Exists then do
    proof' ← mk_mapp ``ex_l [none, none, none, some c↣proof],
    n ← mk_fresh_name, -- FIXME: (binding_name p) produces ugly [anonymous] output
    px ← whnf $ app p (mk_var 0),
    return $ some [{ c with num_quants := 1, proof := proof',
      type := pi n binder_info.default d (imp px (binding_body c↣type)) }]
  else return none
| _ := return none
end

lemma demorgan {a} {b : a → Prop} : (¬∃x:a, ¬b x) → ∀x, b x :=
take nenb x, classical.by_contradiction (take nbx, nenb (exists.intro x nbx))
lemma all_l {a} {b : a → Prop} {c} : ((∀x:a, b x) → c) → ((¬∃x:a, ¬b x) → c) :=
λabc nanb, abc (demorgan nanb)
meta def inf_all_l (l : clause.literal) (c : clause) : tactic (option (list clause)) :=
match l with
| clause.literal.left (pi n bi a b) := do
    nb ← mk_mapp ``not [some b],
    enb ← mk_mapp ``Exists [none, some $ lam n binder_info.default a nb],
    nenb ← mk_mapp ``not [some enb],
    proof' ← mk_mapp ``all_l [none, none, none, some c↣proof],
    return $ some [{ c with proof := proof', type := imp nenb (binding_body c↣type) }]
| _ := return none
end

lemma helper_r {a b c} : (a → b) → (¬a → c) → (¬b → c) := λab nac nb, nac (λa, nb (ab a))
meta def inf_ex_r (ctx : list expr) (l : clause.literal) (c : clause) : tactic (option (list clause)) :=
match l with
| clause.literal.right (app (app (const ex_name _) d) p) :=
  if ex_name = ``Exists then do
    sk_sym_name_pp ← get_unused_name `sk (some 1), sk_sym_name ← mk_fresh_name,
    inh_name ← mk_fresh_name,
    inh_lc ← return $ local_const inh_name inh_name binder_info.implicit d,
    sk_sym ← return $ local_const sk_sym_name sk_sym_name_pp binder_info.default (pis (ctx ++ [inh_lc]) d),
    sk_p ← whnf_core transparency.none $ app p (app_of_list sk_sym (ctx ++ [inh_lc])),
    sk_ax ← mk_mapp ``Exists [some (local_type sk_sym),
      some (lambdas [sk_sym] (pis (ctx ++ [inh_lc]) (imp (clause.literal.formula l) sk_p)))],
    sk_ax_name ← get_unused_name `sk_axiom (some 1), assert sk_ax_name sk_ax,
    nonempt_of_inh ← mk_mapp ``nonempty.intro [some d, some inh_lc],
    eps ← mk_mapp ``classical.epsilon [some d, some nonempt_of_inh, some p],
    existsi (lambdas (ctx ++ [inh_lc]) eps),
    eps_spec ← mk_mapp ``classical.epsilon_spec [some d, some p],
    exact (lambdas (ctx ++ [inh_lc]) eps_spec),
    sk_ax_local ← get_local sk_ax_name, cases_using sk_ax_local [sk_sym_name_pp, sk_ax_name],
    sk_ax' ← get_local sk_ax_name, sk_sym' ← get_local sk_sym_name_pp,
    sk_p' ← whnf_core transparency.none $ app p (app_of_list sk_sym' (ctx ++ [inh_lc])),
    not_sk_p' ← mk_mapp ``not [some sk_p'],
    proof' ← mk_mapp ``helper_r [none, none, none, some (app_of_list sk_ax' (ctx ++ [inh_lc])), some c↣proof],
    return $ some [{ c with num_quants := 1, proof := lambdas [inh_lc] proof',
      type := pis [inh_lc] (imp not_sk_p' (binding_body c↣type)) }]
else return none
| _ := return none
end

meta def first_some {a : Type} : list (tactic (option a)) → tactic (option a)
| [] := return none
| (x::xs) := do xres ← x, match xres with some y := return (some y) | none := first_some xs end

meta def clausification_rules (ctx : list expr) : list head_lit_rule :=
[ inf_false_l, inf_false_r, inf_true_l, inf_true_r,
  inf_not_r,
  inf_and_l, inf_and_r,
  inf_or_l, inf_or_r,
  inf_imp_l, inf_all_r,
  inf_ex_l,
  inf_all_l, inf_ex_r ctx,
  inf_whnf ]

meta def clausify_at (c : clause) (i : nat) : tactic (option (list clause)) := do
opened ← clause.open_constn c (c↣num_quants + i),
literal ← return $ clause.get_lit opened.1 0,
maybe_clausified ← first_some (do
  r ← clausification_rules (list.taken c↣num_quants opened.2),
  [r literal opened.1]),
match maybe_clausified with
| none := return none
| some clsfd := return $ some (do c' ← clsfd, [clause.close_constn c' opened.2])
end

meta def clausify_core : clause → tactic (option (list clause)) | c := do
one_step ← first_some (do i ← range c↣num_lits, [clausify_at c i]),
match one_step with
| some next := do
  next' ← sequence (do n ← next, [do
        n' ← clausify_core n,
        return $ option.get_or_else n' [n]]),
  return (some $ list.join next')
| none := return none
end

meta def clausify (cs : list clause) : tactic (list clause) :=
liftM list.join $ sequence (do c ← cs, [do cs' ← clausify_core c, return (option.get_or_else cs' [c])])

meta def clausification_pre : resolution_prover unit := preprocessing_rule $ λnew, do
clausified ← sequence (do n ← new, [do n' ← ↑(clausify_core n), return $ option.get_or_else n' [n]]),
return (list.join clausified)

meta def clausification_inf : inference := λgiven, do
clausified : option (list clause) ← ↑(clausify_core given↣c),
match clausified with
| some cs := do forM' cs (λc, add_inferred c [given]), remove_redundant given↣id []
| none := return ()
end
