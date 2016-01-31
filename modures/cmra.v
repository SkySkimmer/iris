Require Export modures.cofe.

Class Unit (A : Type) := unit : A → A.
Instance: Params (@unit) 2.

Class Op (A : Type) := op : A → A → A.
Instance: Params (@op) 2.
Infix "⋅" := op (at level 50, left associativity) : C_scope.
Notation "(⋅)" := op (only parsing) : C_scope.

Definition included `{Equiv A, Op A} (x y : A) := ∃ z, y ≡ x ⋅ z.
Infix "≼" := included (at level 70) : C_scope.
Notation "(≼)" := included (only parsing) : C_scope.
Hint Extern 0 (?x ≼ ?y) => reflexivity.
Instance: Params (@included) 3.

Class Minus (A : Type) := minus : A → A → A.
Instance: Params (@minus) 2.
Infix "⩪" := minus (at level 40) : C_scope.

Class ValidN (A : Type) := validN : nat → A → Prop.
Instance: Params (@validN) 3.
Notation "✓{ n }" := (validN n) (at level 1, format "✓{ n }").

Class Valid (A : Type) := valid : A → Prop.
Instance: Params (@valid) 2.
Notation "✓" := valid (at level 1).
Instance validN_valid `{ValidN A} : Valid A := λ x, ∀ n, ✓{n} x.

Definition includedN `{Dist A, Op A} (n : nat) (x y : A) := ∃ z, y ={n}= x ⋅ z.
Notation "x ≼{ n } y" := (includedN n x y)
  (at level 70, format "x  ≼{ n }  y") : C_scope.
Instance: Params (@includedN) 4.
Hint Extern 0 (?x ≼{_} ?y) => reflexivity.

Record CMRAMixin A `{Dist A, Equiv A, Unit A, Op A, ValidN A, Minus A} := {
  (* setoids *)
  mixin_cmra_op_ne n (x : A) : Proper (dist n ==> dist n) (op x);
  mixin_cmra_unit_ne n : Proper (dist n ==> dist n) unit;
  mixin_cmra_validN_ne n : Proper (dist n ==> impl) (✓{n});
  mixin_cmra_minus_ne n : Proper (dist n ==> dist n ==> dist n) minus;
  (* valid *)
  mixin_cmra_validN_0 x : ✓{0} x;
  mixin_cmra_validN_S n x : ✓{S n} x → ✓{n} x;
  (* monoid *)
  mixin_cmra_associative : Associative (≡) (⋅);
  mixin_cmra_commutative : Commutative (≡) (⋅);
  mixin_cmra_unit_l x : unit x ⋅ x ≡ x;
  mixin_cmra_unit_idempotent x : unit (unit x) ≡ unit x;
  mixin_cmra_unit_preservingN n x y : x ≼{n} y → unit x ≼{n} unit y;
  mixin_cmra_validN_op_l n x y : ✓{n} (x ⋅ y) → ✓{n} x;
  mixin_cmra_op_minus n x y : x ≼{n} y → x ⋅ y ⩪ x ={n}= y
}.
Definition CMRAExtendMixin A `{Equiv A, Dist A, Op A, ValidN A} := ∀ n x y1 y2,
  ✓{n} x → x ={n}= y1 ⋅ y2 →
  { z | x ≡ z.1 ⋅ z.2 ∧ z.1 ={n}= y1 ∧ z.2 ={n}= y2 }.

(** Bundeled version *)
Structure cmraT := CMRAT {
  cmra_car :> Type;
  cmra_equiv : Equiv cmra_car;
  cmra_dist : Dist cmra_car;
  cmra_compl : Compl cmra_car;
  cmra_unit : Unit cmra_car;
  cmra_op : Op cmra_car;
  cmra_validN : ValidN cmra_car;
  cmra_minus : Minus cmra_car;
  cmra_cofe_mixin : CofeMixin cmra_car;
  cmra_mixin : CMRAMixin cmra_car;
  cmra_extend_mixin : CMRAExtendMixin cmra_car
}.
Arguments CMRAT {_ _ _ _ _ _ _ _} _ _ _.
Arguments cmra_car : simpl never.
Arguments cmra_equiv : simpl never.
Arguments cmra_dist : simpl never.
Arguments cmra_compl : simpl never.
Arguments cmra_unit : simpl never.
Arguments cmra_op : simpl never.
Arguments cmra_validN : simpl never.
Arguments cmra_minus : simpl never.
Arguments cmra_cofe_mixin : simpl never.
Arguments cmra_mixin : simpl never.
Arguments cmra_extend_mixin : simpl never.
Add Printing Constructor cmraT.
Existing Instances cmra_unit cmra_op cmra_validN cmra_minus.
Coercion cmra_cofeC (A : cmraT) : cofeT := CofeT (cmra_cofe_mixin A).
Canonical Structure cmra_cofeC.

(** Lifting properties from the mixin *)
Section cmra_mixin.
  Context {A : cmraT}.
  Implicit Types x y : A.
  Global Instance cmra_op_ne n (x : A) : Proper (dist n ==> dist n) (op x).
  Proof. apply (mixin_cmra_op_ne _ (cmra_mixin A)). Qed.
  Global Instance cmra_unit_ne n : Proper (dist n ==> dist n) (@unit A _).
  Proof. apply (mixin_cmra_unit_ne _ (cmra_mixin A)). Qed.
  Global Instance cmra_validN_ne n : Proper (dist n ==> impl) (@validN A _ n).
  Proof. apply (mixin_cmra_validN_ne _ (cmra_mixin A)). Qed.
  Global Instance cmra_minus_ne n :
    Proper (dist n ==> dist n ==> dist n) (@minus A _).
  Proof. apply (mixin_cmra_minus_ne _ (cmra_mixin A)). Qed.
  Lemma cmra_validN_0 x : ✓{0} x.
  Proof. apply (mixin_cmra_validN_0 _ (cmra_mixin A)). Qed.
  Lemma cmra_validN_S n x : ✓{S n} x → ✓{n} x.
  Proof. apply (mixin_cmra_validN_S _ (cmra_mixin A)). Qed.
  Global Instance cmra_associative : Associative (≡) (@op A _).
  Proof. apply (mixin_cmra_associative _ (cmra_mixin A)). Qed.
  Global Instance cmra_commutative : Commutative (≡) (@op A _).
  Proof. apply (mixin_cmra_commutative _ (cmra_mixin A)). Qed.
  Lemma cmra_unit_l x : unit x ⋅ x ≡ x.
  Proof. apply (mixin_cmra_unit_l _ (cmra_mixin A)). Qed.
  Lemma cmra_unit_idempotent x : unit (unit x) ≡ unit x.
  Proof. apply (mixin_cmra_unit_idempotent _ (cmra_mixin A)). Qed.
  Lemma cmra_unit_preservingN n x y : x ≼{n} y → unit x ≼{n} unit y.
  Proof. apply (mixin_cmra_unit_preservingN _ (cmra_mixin A)). Qed.
  Lemma cmra_validN_op_l n x y : ✓{n} (x ⋅ y) → ✓{n} x.
  Proof. apply (mixin_cmra_validN_op_l _ (cmra_mixin A)). Qed.
  Lemma cmra_op_minus n x y : x ≼{n} y → x ⋅ y ⩪ x ={n}= y.
  Proof. apply (mixin_cmra_op_minus _ (cmra_mixin A)). Qed.
  Lemma cmra_extend_op n x y1 y2 :
    ✓{n} x → x ={n}= y1 ⋅ y2 →
    { z | x ≡ z.1 ⋅ z.2 ∧ z.1 ={n}= y1 ∧ z.2 ={n}= y2 }.
  Proof. apply (cmra_extend_mixin A). Qed.
End cmra_mixin.

Hint Extern 0 (✓{0} _) => apply cmra_validN_0.

(** * CMRAs with a global identity element *)
(** We use the notation ∅ because for most instances (maps, sets, etc) the
`empty' element is the global identity. *)
Class CMRAIdentity (A : cmraT) `{Empty A} : Prop := {
  cmra_empty_valid : ✓ ∅;
  cmra_empty_left_id :> LeftId (≡) ∅ (⋅);
  cmra_empty_timeless :> Timeless ∅
}.

(** * Morphisms *)
Class CMRAMonotone {A B : cmraT} (f : A → B) := {
  includedN_preserving n x y : x ≼{n} y → f x ≼{n} f y;
  validN_preserving n x : ✓{n} x → ✓{n} (f x)
}.

(** * Frame preserving updates *)
Definition cmra_updateP {A : cmraT} (x : A) (P : A → Prop) := ∀ z n,
  ✓{n} (x ⋅ z) → ∃ y, P y ∧ ✓{n} (y ⋅ z).
Instance: Params (@cmra_updateP) 3.
Infix "⇝:" := cmra_updateP (at level 70).
Definition cmra_update {A : cmraT} (x y : A) := ∀ z n,
  ✓{n} (x ⋅ z) → ✓{n} (y ⋅ z).
Infix "⇝" := cmra_update (at level 70).
Instance: Params (@cmra_update) 3.

(** * Properties **)
Section cmra.
Context {A : cmraT}.
Implicit Types x y z : A.
Implicit Types xs ys zs : list A.

(** ** Setoids *)
Global Instance cmra_unit_proper : Proper ((≡) ==> (≡)) (@unit A _).
Proof. apply (ne_proper _). Qed.
Global Instance cmra_op_ne' n : Proper (dist n ==> dist n ==> dist n) (@op A _).
Proof.
  intros x1 x2 Hx y1 y2 Hy.
  by rewrite Hy (commutative _ x1) Hx (commutative _ y2).
Qed.
Global Instance ra_op_proper' : Proper ((≡) ==> (≡) ==> (≡)) (@op A _).
Proof. apply (ne_proper_2 _). Qed.
Global Instance cmra_validN_ne' : Proper (dist n ==> iff) (@validN A _ n) | 1.
Proof. by split; apply cmra_validN_ne. Qed.
Global Instance cmra_validN_proper : Proper ((≡) ==> iff) (@validN A _ n) | 1.
Proof. by intros n x1 x2 Hx; apply cmra_validN_ne', equiv_dist. Qed.
Global Instance cmra_minus_proper : Proper ((≡) ==> (≡) ==> (≡)) (@minus A _).
Proof. apply (ne_proper_2 _). Qed.

Global Instance cmra_valid_proper : Proper ((≡) ==> iff) (@valid A _).
Proof. by intros x y Hxy; split; intros ? n; [rewrite -Hxy|rewrite Hxy]. Qed.
Global Instance cmra_includedN_ne n :
  Proper (dist n ==> dist n ==> iff) (@includedN A _ _ n) | 1.
Proof.
  intros x x' Hx y y' Hy.
  by split; intros [z ?]; exists z; [rewrite -Hx -Hy|rewrite Hx Hy].
Qed.
Global Instance cmra_includedN_proper n :
  Proper ((≡) ==> (≡) ==> iff) (@includedN A _ _ n) | 1.
Proof.
  intros x x' Hx y y' Hy; revert Hx Hy; rewrite !equiv_dist=> Hx Hy.
  by rewrite (Hx n) (Hy n).
Qed.
Global Instance cmra_included_proper :
  Proper ((≡) ==> (≡) ==> iff) (@included A _ _) | 1.
Proof.
  intros x x' Hx y y' Hy.
  by split; intros [z ?]; exists z; [rewrite -Hx -Hy|rewrite Hx Hy].
Qed.

(** ** Validity *)
Lemma cmra_valid_validN x : ✓ x ↔ ∀ n, ✓{n} x.
Proof. done. Qed.
Lemma cmra_validN_le x n n' : ✓{n} x → n' ≤ n → ✓{n'} x.
Proof. induction 2; eauto using cmra_validN_S. Qed.
Lemma cmra_valid_op_l x y : ✓ (x ⋅ y) → ✓ x.
Proof. rewrite !cmra_valid_validN; eauto using cmra_validN_op_l. Qed.
Lemma cmra_validN_op_r x y n : ✓{n} (x ⋅ y) → ✓{n} y.
Proof. rewrite (commutative _ x); apply cmra_validN_op_l. Qed.
Lemma cmra_valid_op_r x y : ✓ (x ⋅ y) → ✓ y.
Proof. rewrite !cmra_valid_validN; eauto using cmra_validN_op_r. Qed.

(** ** Units *)
Lemma cmra_unit_r x : x ⋅ unit x ≡ x.
Proof. by rewrite (commutative _ x) cmra_unit_l. Qed.
Lemma cmra_unit_unit x : unit x ⋅ unit x ≡ unit x.
Proof. by rewrite -{2}(cmra_unit_idempotent x) cmra_unit_r. Qed.
Lemma cmra_unit_validN x n : ✓{n} x → ✓{n} (unit x).
Proof. rewrite -{1}(cmra_unit_l x); apply cmra_validN_op_l. Qed.
Lemma cmra_unit_valid x : ✓ x → ✓ (unit x).
Proof. rewrite -{1}(cmra_unit_l x); apply cmra_valid_op_l. Qed.

(** ** Order *)
Lemma cmra_included_includedN x y : x ≼ y ↔ ∀ n, x ≼{n} y.
Proof.
  split; [by intros [z Hz] n; exists z; rewrite Hz|].
  intros Hxy; exists (y ⩪ x); apply equiv_dist; intros n.
  symmetry; apply cmra_op_minus, Hxy.
Qed.
Global Instance cmra_includedN_preorder n : PreOrder (@includedN A _ _ n).
Proof.
  split.
  * by intros x; exists (unit x); rewrite cmra_unit_r.
  * intros x y z [z1 Hy] [z2 Hz]; exists (z1 ⋅ z2).
    by rewrite (associative _) -Hy -Hz.
Qed.
Global Instance cmra_included_preorder: PreOrder (@included A _ _).
Proof.
  split; red; intros until 0; rewrite !cmra_included_includedN; first done.
  intros; etransitivity; eauto.
Qed.
Lemma cmra_validN_includedN x y n : ✓{n} y → x ≼{n} y → ✓{n} x.
Proof. intros Hyv [z ?]; cofe_subst y; eauto using cmra_validN_op_l. Qed.
Lemma cmra_validN_included x y n : ✓{n} y → x ≼ y → ✓{n} x.
Proof. rewrite cmra_included_includedN; eauto using cmra_validN_includedN. Qed.

Lemma cmra_includedN_0 x y : x ≼{0} y.
Proof. by exists (unit x). Qed.
Lemma cmra_includedN_S x y n : x ≼{S n} y → x ≼{n} y.
Proof. by intros [z Hz]; exists z; apply dist_S. Qed.
Lemma cmra_includedN_le x y n n' : x ≼{n} y → n' ≤ n → x ≼{n'} y.
Proof. induction 2; auto using cmra_includedN_S. Qed.

Lemma cmra_includedN_l n x y : x ≼{n} x ⋅ y.
Proof. by exists y. Qed.
Lemma cmra_included_l x y : x ≼ x ⋅ y.
Proof. by exists y. Qed.
Lemma cmra_includedN_r n x y : y ≼{n} x ⋅ y.
Proof. rewrite (commutative op); apply cmra_includedN_l. Qed.
Lemma cmra_included_r x y : y ≼ x ⋅ y.
Proof. rewrite (commutative op); apply cmra_included_l. Qed.

Lemma cmra_unit_preserving x y : x ≼ y → unit x ≼ unit y.
Proof. rewrite !cmra_included_includedN; eauto using cmra_unit_preservingN. Qed.
Lemma cmra_included_unit x : unit x ≼ x.
Proof. by exists x; rewrite cmra_unit_l. Qed.
Lemma cmra_preserving_l x y z : x ≼ y → z ⋅ x ≼ z ⋅ y.
Proof. by intros [z1 Hz1]; exists z1; rewrite Hz1 (associative op). Qed.
Lemma cmra_preserving_r x y z : x ≼ y → x ⋅ z ≼ y ⋅ z.
Proof. by intros; rewrite -!(commutative _ z); apply cmra_preserving_l. Qed.

Lemma cmra_included_dist_l x1 x2 x1' n :
  x1 ≼ x2 → x1' ={n}= x1 → ∃ x2', x1' ≼ x2' ∧ x2' ={n}= x2.
Proof.
  intros [z Hx2] Hx1; exists (x1' ⋅ z); split; auto using cmra_included_l.
  by rewrite Hx1 Hx2.
Qed.

(** ** Minus *)
Lemma cmra_op_minus' x y : x ≼ y → x ⋅ y ⩪ x ≡ y.
Proof.
  rewrite cmra_included_includedN equiv_dist; eauto using cmra_op_minus.
Qed.

(** ** Timeless *)
Lemma cmra_timeless_included_l x y : Timeless x → ✓{1} y → x ≼{1} y → x ≼ y.
Proof.
  intros ?? [x' ?].
  destruct (cmra_extend_op 1 y x x') as ([z z']&Hy&Hz&Hz'); auto; simpl in *.
  by exists z'; rewrite Hy (timeless x z).
Qed.
Lemma cmra_timeless_included_r n x y : Timeless y → x ≼{1} y → x ≼{n} y.
Proof. intros ? [x' ?]. exists x'. by apply equiv_dist, (timeless y). Qed.
Lemma cmra_op_timeless x1 x2 :
  ✓ (x1 ⋅ x2) → Timeless x1 → Timeless x2 → Timeless (x1 ⋅ x2).
Proof.
  intros ??? z Hz.
  destruct (cmra_extend_op 1 z x1 x2) as ([y1 y2]&Hz'&?&?); auto; simpl in *.
  { by rewrite -?Hz. }
  by rewrite Hz' (timeless x1 y1) // (timeless x2 y2).
Qed.

(** ** RAs with an empty element *)
Section identity.
  Context `{Empty A, !CMRAIdentity A}.
  Lemma cmra_empty_leastN  n x : ∅ ≼{n} x.
  Proof. by exists x; rewrite left_id. Qed.
  Lemma cmra_empty_least x : ∅ ≼ x.
  Proof. by exists x; rewrite left_id. Qed.
  Global Instance cmra_empty_right_id : RightId (≡) ∅ (⋅).
  Proof. by intros x; rewrite (commutative op) left_id. Qed.
  Lemma cmra_unit_empty : unit ∅ ≡ ∅.
  Proof. by rewrite -{2}(cmra_unit_l ∅) right_id. Qed.
End identity.

(** ** Updates *)
Global Instance cmra_update_preorder : PreOrder (@cmra_update A).
Proof. split. by intros x y. intros x y y' ?? z ?; naive_solver. Qed.
Lemma cmra_update_updateP x y : x ⇝ y ↔ x ⇝: (y =).
Proof.
  split.
  * by intros Hx z ?; exists y; split; [done|apply (Hx z)].
  * by intros Hx z n ?; destruct (Hx z n) as (?&<-&?).
Qed.
End cmra.

Hint Extern 0 (_ ≼{0} _) => apply cmra_includedN_0.

(** * Properties about monotone functions *)
Instance cmra_monotone_id {A : cmraT} : CMRAMonotone (@id A).
Proof. by split. Qed.
Instance cmra_monotone_compose {A B C : cmraT} (f : A → B) (g : B → C) :
  CMRAMonotone f → CMRAMonotone g → CMRAMonotone (g ∘ f).
Proof.
  split.
  * move=> n x y Hxy /=. by apply includedN_preserving, includedN_preserving.
  * move=> n x Hx /=. by apply validN_preserving, validN_preserving.
Qed.

Section cmra_monotone.
  Context {A B : cmraT} (f : A → B) `{!CMRAMonotone f}.
  Lemma included_preserving x y : x ≼ y → f x ≼ f y.
  Proof.
    rewrite !cmra_included_includedN; eauto using includedN_preserving.
  Qed.
  Lemma valid_preserving x : ✓ x → ✓ (f x).
  Proof. rewrite !cmra_valid_validN; eauto using validN_preserving. Qed.
End cmra_monotone.

(** * Instances *)
(** ** Discrete CMRA *)
Class RA A `{Equiv A, Unit A, Op A, Valid A, Minus A} := {
  (* setoids *)
  ra_op_ne (x : A) : Proper ((≡) ==> (≡)) (op x);
  ra_unit_ne :> Proper ((≡) ==> (≡)) unit;
  ra_validN_ne :> Proper ((≡) ==> impl) ✓;
  ra_minus_ne :> Proper ((≡) ==> (≡) ==> (≡)) minus;
  (* monoid *)
  ra_associative :> Associative (≡) (⋅);
  ra_commutative :> Commutative (≡) (⋅);
  ra_unit_l x : unit x ⋅ x ≡ x;
  ra_unit_idempotent x : unit (unit x) ≡ unit x;
  ra_unit_preserving x y : x ≼ y → unit x ≼ unit y;
  ra_valid_op_l x y : ✓ (x ⋅ y) → ✓ x;
  ra_op_minus x y : x ≼ y → x ⋅ y ⩪ x ≡ y
}.

Section discrete.
  Context {A : cofeT} `{∀ x : A, Timeless x}.
  Context `{Unit A, Op A, Valid A, Minus A} (ra : RA A).

  Instance discrete_validN : ValidN A := λ n x,
    match n with 0 => True | S n => ✓ x end.
  Definition discrete_cmra_mixin : CMRAMixin A.
  Proof.
    destruct ra; split; unfold Proper, respectful, includedN;
      repeat match goal with
      | |- ∀ n : nat, _ => intros [|?]
      end; try setoid_rewrite <-(timeless_S _ _ _ _); try done.
    by intros x y ?; exists x.
  Qed.
  Definition discrete_extend_mixin : CMRAExtendMixin A.
  Proof.
    intros [|n] x y1 y2 ??.
    * by exists (unit x, x); rewrite /= ra_unit_l.
    * exists (y1,y2); split_ands; auto.
      apply (timeless _), dist_le with (S n); auto with lia.
  Qed.
  Definition discreteRA : cmraT :=
    CMRAT (cofe_mixin A) discrete_cmra_mixin discrete_extend_mixin.
  Lemma discrete_updateP (x : A) (P : A → Prop) `{!Inhabited (sig P)} :
    (∀ z, ✓ (x ⋅ z) → ∃ y, P y ∧ ✓ (y ⋅ z)) → (x : discreteRA) ⇝: P.
  Proof.
    intros Hvalid z [|n]; [|apply Hvalid].
    by destruct (_ : Inhabited (sig P)) as [[y ?]]; exists y.
  Qed.
  Lemma discrete_update (x y : A) :
    (∀ z, ✓ (x ⋅ z) → ✓ (y ⋅ z)) → (x : discreteRA) ⇝ y.
  Proof. intros Hvalid z [|n]; [done|apply Hvalid]. Qed.
End discrete.

(** ** CMRA for the unit type *)
Section unit.
  Instance unit_valid : Valid () := λ x, True.
  Instance unit_unit : Unit () := λ x, x.
  Instance unit_op : Op () := λ x y, ().
  Instance unit_minus : Minus () := λ x y, ().
  Global Instance unit_empty : Empty () := ().
  Definition unit_ra : RA ().
  Proof. by split. Qed.
  Canonical Structure unitRA : cmraT :=
    Eval cbv [unitC discreteRA cofe_car] in discreteRA unit_ra.
  Global Instance unit_cmra_identity : CMRAIdentity unitRA.
  Proof. by split; intros []. Qed.
End unit.

(** ** Product *)
Section prod.
  Context {A B : cmraT}.
  Instance prod_op : Op (A * B) := λ x y, (x.1 ⋅ y.1, x.2 ⋅ y.2).
  Global Instance prod_empty `{Empty A, Empty B} : Empty (A * B) := (∅, ∅).
  Instance prod_unit : Unit (A * B) := λ x, (unit (x.1), unit (x.2)).
  Instance prod_validN : ValidN (A * B) := λ n x, ✓{n} (x.1) ∧ ✓{n} (x.2).
  Instance prod_minus : Minus (A * B) := λ x y, (x.1 ⩪ y.1, x.2 ⩪ y.2).
  Lemma prod_included (x y : A * B) : x ≼ y ↔ x.1 ≼ y.1 ∧ x.2 ≼ y.2.
  Proof.
    split; [intros [z Hz]; split; [exists (z.1)|exists (z.2)]; apply Hz|].
    intros [[z1 Hz1] [z2 Hz2]]; exists (z1,z2); split; auto.
  Qed.
  Lemma prod_includedN (x y : A * B) n : x ≼{n} y ↔ x.1 ≼{n} y.1 ∧ x.2 ≼{n} y.2.
  Proof.
    split; [intros [z Hz]; split; [exists (z.1)|exists (z.2)]; apply Hz|].
    intros [[z1 Hz1] [z2 Hz2]]; exists (z1,z2); split; auto.
  Qed.
  Definition prod_cmra_mixin : CMRAMixin (A * B).
  Proof.
    split; try apply _.
    * by intros n x y1 y2 [Hy1 Hy2]; split; rewrite /= ?Hy1 ?Hy2.
    * by intros n y1 y2 [Hy1 Hy2]; split; rewrite /= ?Hy1 ?Hy2.
    * by intros n y1 y2 [Hy1 Hy2] [??]; split; rewrite /= -?Hy1 -?Hy2.
    * by intros n x1 x2 [Hx1 Hx2] y1 y2 [Hy1 Hy2];
        split; rewrite /= ?Hx1 ?Hx2 ?Hy1 ?Hy2.
    * by split.
    * by intros n x [??]; split; apply cmra_validN_S.
    * split; simpl; apply (associative _).
    * split; simpl; apply (commutative _).
    * split; simpl; apply cmra_unit_l.
    * split; simpl; apply cmra_unit_idempotent.
    * intros n x y; rewrite !prod_includedN.
      by intros [??]; split; apply cmra_unit_preservingN.
    * intros n x y [??]; split; simpl in *; eauto using cmra_validN_op_l.
    * intros x y n; rewrite prod_includedN; intros [??].
      by split; apply cmra_op_minus.
  Qed.
  Definition prod_cmra_extend_mixin : CMRAExtendMixin (A * B).
  Proof.
    intros n x y1 y2 [??] [??]; simpl in *.
    destruct (cmra_extend_op n (x.1) (y1.1) (y2.1)) as (z1&?&?&?); auto.
    destruct (cmra_extend_op n (x.2) (y1.2) (y2.2)) as (z2&?&?&?); auto.
    by exists ((z1.1,z2.1),(z1.2,z2.2)).
  Qed.
  Canonical Structure prodRA : cmraT :=
    CMRAT prod_cofe_mixin prod_cmra_mixin prod_cmra_extend_mixin.
  Global Instance prod_cmra_identity `{Empty A, Empty B} :
    CMRAIdentity A → CMRAIdentity B → CMRAIdentity prodRA.
  Proof.
    split.
    * split; apply cmra_empty_valid.
    * by split; rewrite /=left_id.
    * by intros ? [??]; split; apply (timeless _).
  Qed.
End prod.
Arguments prodRA : clear implicits.

Instance prod_map_cmra_monotone {A A' B B' : cmraT} (f : A → A') (g : B → B') :
  CMRAMonotone f → CMRAMonotone g → CMRAMonotone (prod_map f g).
Proof.
  split.
  * intros n x y; rewrite !prod_includedN; intros [??]; simpl.
    by split; apply includedN_preserving.
  * by intros n x [??]; split; simpl; apply validN_preserving.
Qed.
Definition prodRA_map {A A' B B' : cmraT}
    (f : A -n> A') (g : B -n> B') : prodRA A B -n> prodRA A' B' :=
  CofeMor (prod_map f g : prodRA A B → prodRA A' B').
Instance prodRA_map_ne {A A' B B'} n :
  Proper (dist n==> dist n==> dist n) (@prodRA_map A A' B B') := prodC_map_ne n.
