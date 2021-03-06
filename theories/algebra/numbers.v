From iris.algebra Require Export cmra local_updates proofmode_classes.
From iris Require Import options.

(** ** Natural numbers with [add] as the operation. *)
Section nat.
  Instance nat_valid : Valid nat := λ x, True.
  Instance nat_validN : ValidN nat := λ n x, True.
  Instance nat_pcore : PCore nat := λ x, Some 0.
  Instance nat_op : Op nat := plus.
  Definition nat_op_plus x y : x ⋅ y = x + y := eq_refl.
  Lemma nat_included (x y : nat) : x ≼ y ↔ x ≤ y.
  Proof. by rewrite nat_le_sum. Qed.
  Lemma nat_ra_mixin : RAMixin nat.
  Proof.
    apply ra_total_mixin; try by eauto.
    - solve_proper.
    - intros x y z. apply Nat.add_assoc.
    - intros x y. apply Nat.add_comm.
    - by exists 0.
  Qed.
  Canonical Structure natR : cmraT := discreteR nat nat_ra_mixin.

  Global Instance nat_cmra_discrete : CmraDiscrete natR.
  Proof. apply discrete_cmra_discrete. Qed.

  Instance nat_unit : Unit nat := 0.
  Lemma nat_ucmra_mixin : UcmraMixin nat.
  Proof. split; apply _ || done. Qed.
  Canonical Structure natUR : ucmraT := UcmraT nat nat_ucmra_mixin.

  Global Instance nat_cancelable (x : nat) : Cancelable x.
  Proof. by intros ???? ?%Nat.add_cancel_l. Qed.

  Lemma nat_local_update (x y x' y' : nat) :
    x + y' = x' + y → (x,y) ~l~> (x',y').
  Proof.
    intros ??; apply local_update_unital_discrete=> z _.
    compute -[minus plus]; lia.
  Qed.

  (* This one has a higher precendence than [is_op_op] so we get a [+] instead
     of an [⋅]. *)
  Global Instance nat_is_op (n1 n2 : nat) : IsOp (n1 + n2) n1 n2.
  Proof. done. Qed.
End nat.

(** ** Natural numbers with [max] as the operation. *)
Record max_nat := MaxNat { max_nat_car : nat }.

Canonical Structure max_natO := leibnizO max_nat.

Section max_nat.
  Instance max_nat_unit : Unit max_nat := MaxNat 0.
  Instance max_nat_valid : Valid max_nat := λ x, True.
  Instance max_nat_validN : ValidN max_nat := λ n x, True.
  Instance max_nat_pcore : PCore max_nat := Some.
  Instance max_nat_op : Op max_nat := λ n m, MaxNat (max_nat_car n `max` max_nat_car m).
  Definition max_nat_op_max x y : MaxNat x ⋅ MaxNat y = MaxNat (x `max` y) := eq_refl.

  Lemma max_nat_included x y : x ≼ y ↔ max_nat_car x ≤ max_nat_car y.
  Proof.
    split.
    - intros [z ->]. simpl. lia.
    - exists y. rewrite /op /max_nat_op. rewrite Nat.max_r; last lia. by destruct y.
  Qed.
  Lemma max_nat_ra_mixin : RAMixin max_nat.
  Proof.
    apply ra_total_mixin; apply _ || eauto.
    - intros [x] [y] [z]. repeat rewrite max_nat_op_max. by rewrite Nat.max_assoc.
    - intros [x] [y]. by rewrite max_nat_op_max Nat.max_comm.
    - intros [x]. by rewrite max_nat_op_max Max.max_idempotent.
  Qed.
  Canonical Structure max_natR : cmraT := discreteR max_nat max_nat_ra_mixin.

  Global Instance max_nat_cmra_discrete : CmraDiscrete max_natR.
  Proof. apply discrete_cmra_discrete. Qed.

  Lemma max_nat_ucmra_mixin : UcmraMixin max_nat.
  Proof. split; try apply _ || done. intros [x]. done. Qed.
  Canonical Structure max_natUR : ucmraT := UcmraT max_nat max_nat_ucmra_mixin.

  Global Instance max_nat_core_id (x : max_nat) : CoreId x.
  Proof. by constructor. Qed.

  Lemma max_nat_local_update (x y x' : max_nat) :
    max_nat_car x ≤ max_nat_car x' → (x,y) ~l~> (x',x').
  Proof.
    move: x y x' => [x] [y] [y'] /= ?.
    rewrite local_update_unital_discrete=> [[z]] _.
    rewrite 2!max_nat_op_max. intros [= ?].
    split; first done. apply f_equal. lia.
  Qed.

  Global Instance : IdemP (=@{max_nat}) (⋅).
  Proof. intros [x]. rewrite max_nat_op_max. apply f_equal. lia. Qed.

  Global Instance max_nat_is_op (x y : nat) :
    IsOp (MaxNat (x `max` y)) (MaxNat x) (MaxNat y).
  Proof. done. Qed.
End max_nat.

(** ** Natural numbers with [min] as the operation. *)
Record min_nat := MinNat { min_nat_car : nat }.

Canonical Structure min_natO := leibnizO min_nat.

Section min_nat.
  Instance min_nat_valid : Valid min_nat := λ x, True.
  Instance min_nat_validN : ValidN min_nat := λ n x, True.
  Instance min_nat_pcore : PCore min_nat := Some.
  Instance min_nat_op : Op min_nat := λ n m, MinNat (min_nat_car n `min` min_nat_car m).
  Definition min_nat_op_min x y : MinNat x ⋅ MinNat y = MinNat (x `min` y) := eq_refl.

  Lemma min_nat_included (x y : min_nat) : x ≼ y ↔ min_nat_car y ≤ min_nat_car x.
  Proof.
    split.
    - intros [z ->]. simpl. lia.
    - exists y. rewrite /op /min_nat_op. rewrite Nat.min_r; last lia. by destruct y.
  Qed.
  Lemma min_nat_ra_mixin : RAMixin min_nat.
  Proof.
    apply ra_total_mixin; apply _ || eauto.
    - intros [x] [y] [z]. repeat rewrite min_nat_op_min. by rewrite Nat.min_assoc.
    - intros [x] [y]. by rewrite min_nat_op_min Nat.min_comm.
    - intros [x]. by rewrite min_nat_op_min Min.min_idempotent.
  Qed.
  Canonical Structure min_natR : cmraT := discreteR min_nat min_nat_ra_mixin.

  Global Instance min_nat_cmra_discrete : CmraDiscrete min_natR.
  Proof. apply discrete_cmra_discrete. Qed.

  Global Instance min_nat_core_id (x : min_nat) : CoreId x.
  Proof. by constructor. Qed.

  Lemma min_nat_local_update (x y x' : min_nat) :
    min_nat_car x' ≤ min_nat_car x → (x,y) ~l~> (x',x').
  Proof.
    move: x y x' => [x] [y] [x'] /= ?.
    rewrite local_update_discrete. move=> [[z]|] _ /=; last done.
    rewrite 2!min_nat_op_min. intros [= ?].
    split; first done. apply f_equal. lia.
  Qed.

  Global Instance : LeftAbsorb (=) (MinNat 0) (⋅).
  Proof. done. Qed.

  Global Instance : RightAbsorb (=) (MinNat 0) (⋅).
  Proof. intros [x]. by rewrite min_nat_op_min Min.min_0_r. Qed.

  Global Instance : IdemP (=@{min_nat}) (⋅).
  Proof. intros [x]. rewrite min_nat_op_min. apply f_equal. lia. Qed.

  Global Instance min_nat_is_op (x y : nat) :
    IsOp (MinNat (x `min` y)) (MinNat x) (MinNat y).
  Proof. done. Qed.
End min_nat.

(** ** Positive integers with [Pos.add] as the operation. *)
Section positive.
  Instance pos_valid : Valid positive := λ x, True.
  Instance pos_validN : ValidN positive := λ n x, True.
  Instance pos_pcore : PCore positive := λ x, None.
  Instance pos_op : Op positive := Pos.add.
  Definition pos_op_plus x y : x ⋅ y = (x + y)%positive := eq_refl.
  Lemma pos_included (x y : positive) : x ≼ y ↔ (x < y)%positive.
  Proof. by rewrite Plt_sum. Qed.
  Lemma pos_ra_mixin : RAMixin positive.
  Proof.
    split; try by eauto.
    - by intros ??? ->.
    - intros ???. apply Pos.add_assoc.
    - intros ??. apply Pos.add_comm.
  Qed.
  Canonical Structure positiveR : cmraT := discreteR positive pos_ra_mixin.

  Global Instance pos_cmra_discrete : CmraDiscrete positiveR.
  Proof. apply discrete_cmra_discrete. Qed.

  Global Instance pos_cancelable (x : positive) : Cancelable x.
  Proof. intros n y z ??. by eapply Pos.add_reg_l, leibniz_equiv. Qed.
  Global Instance pos_id_free (x : positive) : IdFree x.
  Proof.
    intros y ??. apply (Pos.add_no_neutral x y). rewrite Pos.add_comm.
    by apply leibniz_equiv.
  Qed.

  (* This one has a higher precendence than [is_op_op] so we get a [+] instead
     of an [⋅]. *)
  Global Instance pos_is_op (x y : positive) : IsOp (x + y)%positive x y.
  Proof. done. Qed.
End positive.
