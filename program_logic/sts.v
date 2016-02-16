From algebra Require Export sts.
From program_logic Require Export invariants ghost_ownership.
Import uPred.

Class STSInG Λ Σ (i : gid) (sts : stsT) := {
  sts_inG :> ghost_ownership.InG Λ Σ i (stsRA sts);
  sts_inhabited :> Inhabited (sts.state sts);
}.

Section definitions.
  Context {Λ Σ} (i : gid) (sts : stsT) `{!STSInG Λ Σ i sts} (γ : gname).
  Import sts.
  Definition sts_inv (φ : state sts → iPropG Λ Σ) : iPropG Λ Σ :=
    (∃ s, own i γ (sts_auth s ∅) ★ φ s)%I.
  Definition sts_ownS (S : states sts) (T : tokens sts) : iPropG Λ Σ:=
    own i γ (sts_frag S T).
  Definition sts_own (s : state sts) (T : tokens sts) : iPropG Λ Σ :=
    own i γ (sts_frag_up s T).
  Definition sts_ctx (N : namespace) (φ: state sts → iPropG Λ Σ) : iPropG Λ Σ :=
    inv N (sts_inv φ).
End definitions.
Instance: Params (@sts_inv) 6.
Instance: Params (@sts_ownS) 6.
Instance: Params (@sts_own) 7.
Instance: Params (@sts_ctx) 7.

Section sts.
  Context {Λ Σ} (i : gid) (sts : stsT) `{!STSInG Λ Σ StsI sts}.
  Context (φ : sts.state sts → iPropG Λ Σ).
  Implicit Types N : namespace.
  Implicit Types P Q R : iPropG Λ Σ.
  Implicit Types γ : gname.
  Implicit Types S : sts.states sts.
  Implicit Types T : sts.tokens sts.

  (** Setoids *)
  Global Instance sts_inv_ne n γ :
    Proper (pointwise_relation _ (dist n) ==> dist n) (sts_inv StsI sts γ).
  Proof. by intros φ1 φ2 Hφ; rewrite /sts_inv; setoid_rewrite Hφ. Qed.
  Global Instance sts_inv_proper γ :
    Proper (pointwise_relation _ (≡) ==> (≡)) (sts_inv StsI sts γ).
  Proof. by intros φ1 φ2 Hφ; rewrite /sts_inv; setoid_rewrite Hφ. Qed.
  Global Instance sts_ownS_proper γ :
    Proper ((≡) ==> (≡) ==> (≡)) (sts_ownS StsI sts γ).
  Proof. intros S1 S2 HS T1 T2 HT. by rewrite /sts_ownS HS HT. Qed.
  Global Instance sts_own_proper γ s :
    Proper ((≡) ==> (≡)) (sts_ownS StsI sts γ s).
  Proof. intros T1 T2 HT. by rewrite /sts_ownS HT. Qed.
  Global Instance sts_ctx_ne n γ N :
    Proper (pointwise_relation _ (dist n) ==> dist n) (sts_ctx StsI sts γ N).
  Proof. by intros φ1 φ2 Hφ; rewrite /sts_ctx Hφ. Qed.
  Global Instance sts_ctx_proper γ N :
    Proper (pointwise_relation _ (≡) ==> (≡)) (sts_ctx StsI sts γ N).
  Proof. by intros φ1 φ2 Hφ; rewrite /sts_ctx Hφ. Qed.

  (* The same rule as implication does *not* hold, as could be shown using
     sts_frag_included. *)
  Lemma sts_ownS_weaken E γ S1 S2 T :
    S1 ⊆ S2 → sts.closed S2 T →
    sts_ownS StsI sts γ S1 T ⊑ pvs E E (sts_ownS StsI sts γ S2 T).
  Proof. intros. by apply own_update, sts_update_frag. Qed.

  Lemma sts_own_weaken E γ s S T :
    s ∈ S → sts.closed S T →
    sts_own StsI sts γ s T ⊑ pvs E E (sts_ownS StsI sts γ S T).
  Proof. intros. by apply own_update, sts_update_frag_up. Qed.

  Lemma sts_alloc N s :
    φ s ⊑ pvs N N (∃ γ, sts_ctx StsI sts γ N φ ∧
                        sts_own StsI sts γ s (set_all ∖ sts.tok s)).
  Proof.
    eapply sep_elim_True_r.
    { apply (own_alloc StsI (sts_auth s (set_all ∖ sts.tok s)) N).
      apply sts_auth_valid; solve_elem_of. }
    rewrite pvs_frame_l. apply pvs_strip_pvs.
    rewrite sep_exist_l. apply exist_elim=>γ. rewrite -(exist_intro γ).
    transitivity (▷ sts_inv StsI sts γ φ ★
                    sts_own StsI sts γ s (set_all ∖ sts.tok s))%I.
    { rewrite /sts_inv -later_intro -(exist_intro s).
      rewrite [(_ ★ φ _)%I]comm -assoc. apply sep_mono_r.
      by rewrite -own_op sts_op_auth_frag_up; last solve_elem_of+. }
    rewrite (inv_alloc N) /sts_ctx pvs_frame_r.
    by rewrite always_and_sep_l.
  Qed.

  Lemma sts_opened E γ S T :
    (▷ sts_inv StsI sts γ φ ★ sts_ownS StsI sts γ S T)
    ⊑ pvs E E (∃ s, ■ (s ∈ S) ★ ▷ φ s ★ own StsI γ (sts_auth s T)).
  Proof.
    rewrite /sts_inv /sts_ownS later_exist sep_exist_r. apply exist_elim=>s.
    rewrite later_sep pvs_timeless !pvs_frame_r. apply pvs_mono.
    rewrite -(exist_intro s).
    rewrite [(_ ★ ▷φ _)%I]comm -!assoc -own_op -[(▷φ _ ★ _)%I]comm.
    rewrite own_valid_l discrete_validI.
    rewrite -!assoc. apply const_elim_sep_l=> Hvalid.
    assert (s ∈ S) by (by eapply sts_auth_frag_valid_inv, discrete_valid).
    rewrite const_equiv // left_id comm sts_op_auth_frag //.
    (* this is horrible, but will be fixed whenever we have RAs back *)
    by rewrite -sts_frag_valid; eapply cmra_valid_op_r, discrete_valid.
  Qed.

  Lemma sts_closing E γ s T s' T' :
    sts.step (s, T) (s', T') →
    (▷ φ s' ★ own StsI γ (sts_auth s T))
    ⊑ pvs E E (▷ sts_inv StsI sts γ φ ★ sts_own StsI sts γ s' T').
  Proof.
    intros Hstep. rewrite /sts_inv /sts_own -(exist_intro s').
    rewrite later_sep [(_ ★ ▷φ _)%I]comm -assoc.
    rewrite -pvs_frame_l. apply sep_mono_r. rewrite -later_intro.
    rewrite own_valid_l discrete_validI. apply const_elim_sep_l=>Hval.
    transitivity (pvs E E (own StsI γ (sts_auth s' T'))).
    { by apply own_update, sts_update_auth. }
    by rewrite -own_op sts_op_auth_frag_up; last by inversion_clear Hstep.
  Qed.

  Context {V} (fsa : FSA Λ (globalF Σ) V) `{!FrameShiftAssertion fsaV fsa}.

  Lemma sts_fsaS E N P (Q : V → iPropG Λ Σ) γ S T :
    fsaV → nclose N ⊆ E →
    P ⊑ sts_ctx StsI sts γ N φ →
    P ⊑ (sts_ownS StsI sts γ S T ★ ∀ s,
          ■ (s ∈ S) ★ ▷ φ s -★
          fsa (E ∖ nclose N) (λ x, ∃ s' T',
            ■ sts.step (s, T) (s', T') ★ ▷ φ s' ★
            (sts_own StsI sts γ s' T' -★ Q x))) →
    P ⊑ fsa E Q.
  Proof.
    rewrite /sts_ctx=>? HN Hinv Hinner.
    eapply (inv_fsa fsa); eauto. rewrite Hinner=>{Hinner Hinv P HN}.
    apply wand_intro_l. rewrite assoc.
    rewrite (sts_opened (E ∖ N)) !pvs_frame_r !sep_exist_r.
    apply (fsa_strip_pvs fsa). apply exist_elim=>s.
    rewrite (forall_elim s). rewrite [(▷_ ★ _)%I]comm.
    (* Getting this wand eliminated is really annoying. *)
    rewrite [(■_ ★ _)%I]comm -!assoc [(▷φ _ ★ _ ★ _)%I]assoc [(▷φ _ ★ _)%I]comm.
    rewrite wand_elim_r fsa_frame_l.
    apply (fsa_mono_pvs fsa)=> x.
    rewrite sep_exist_l; apply exist_elim=> s'.
    rewrite sep_exist_l; apply exist_elim=>T'.
    rewrite comm -!assoc. apply const_elim_sep_l=>-Hstep.
    rewrite assoc [(_ ★ (_ -★ _))%I]comm -assoc.
    rewrite (sts_closing (E ∖ N)) //; [].
    rewrite pvs_frame_l. apply pvs_mono.
    by rewrite assoc [(_ ★ ▷_)%I]comm -assoc wand_elim_l.
  Qed.

  Lemma sts_fsa E N P (Q : V → iPropG Λ Σ) γ s0 T :
    fsaV → nclose N ⊆ E →
    P ⊑ sts_ctx StsI sts γ N φ →
    P ⊑ (sts_own StsI sts γ s0 T ★ ∀ s,
          ■ (s ∈ sts.up s0 T) ★ ▷ φ s -★
          fsa (E ∖ nclose N) (λ x, ∃ s' T',
            ■ (sts.step (s, T) (s', T')) ★ ▷ φ s' ★
            (sts_own StsI sts γ s' T' -★ Q x))) →
    P ⊑ fsa E Q.
  Proof. apply sts_fsaS. Qed.
End sts.
