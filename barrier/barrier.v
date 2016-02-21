From prelude Require Export functions.
From algebra Require Export upred_big_op.
From program_logic Require Export sts saved_prop.
From program_logic Require Import hoare.
From heap_lang Require Export derived heap wp_tactics notation.
Import uPred.

Definition newchan := (λ: "", ref '0)%L.
Definition signal := (λ: "x", "x" <- '1)%L.
Definition wait := (rec: "wait" "x" :=if: !"x" = '1 then '() else "wait" "x")%L.

(** The STS describing the main barrier protocol. Every state has an index-set
    associated with it. These indices are actually [gname], because we use them
    with saved propositions. *)
Module barrier_proto.
  Inductive phase := Low | High.
  Record stateT := State { state_phase : phase; state_I : gset gname }.
  Inductive token := Change (i : gname) | Send.

  Global Instance stateT_inhabited: Inhabited stateT.
  Proof. split. exact (State Low ∅). Qed.

  Definition change_tokens (I : gset gname) : set token :=
    mkSet (λ t, match t with Change i => i ∉ I | Send => False end).

  Inductive trans : relation stateT :=
  | ChangeI p I2 I1 : trans (State p I1) (State p I2)
  | ChangePhase I : trans (State Low I) (State High I).

  Definition tok (s : stateT) : set token :=
      change_tokens (state_I s)
    ∪ match state_phase s with Low => ∅ | High => {[ Send ]} end.

  Canonical Structure sts := sts.STS trans tok.

  (* The set of states containing some particular i *)
  Definition i_states (i : gname) : set stateT :=
    mkSet (λ s, i ∈ state_I s).

  Lemma i_states_closed i :
    sts.closed (i_states i) {[ Change i ]}.
  Proof.
    split.
    - apply (non_empty_inhabited(State Low {[ i ]})). rewrite !mkSet_elem_of /=.
      apply lookup_singleton.
    - move=>[p I]. rewrite /= /tok !mkSet_elem_of /= =>HI.
      move=>s' /elem_of_intersection. rewrite !mkSet_elem_of /=.
      move=>[[Htok|Htok] ? ]; subst s'; first done.
      destruct p; done.
    - (* If we do the destruct of the states early, and then inversion
         on the proof of a transition, it doesn't work - we do not obtain
         the equalities we need. So we destruct the states late, because this
         means we can use "destruct" instead of "inversion". *)
      move=>s1 s2. rewrite !mkSet_elem_of /==> Hs1 Hstep.
      (* We probably want some helper lemmas for this... *)
      inversion_clear Hstep as [T1 T2 Hdisj Hstep'].
      inversion_clear Hstep' as [? ? ? ? Htrans _ _ Htok].
      destruct Htrans; last done; move:Hs1 Hdisj Htok.
      rewrite /= /tok /=.
      intros. apply dec_stable. 
      assert (Change i ∉ change_tokens I1) as HI1
        by (rewrite mkSet_not_elem_of; set_solver +Hs1).
      assert (Change i ∉ change_tokens I2) as HI2.
      { destruct p.
        - set_solver +Htok Hdisj HI1.
        - set_solver +Htok Hdisj HI1 / discriminate. }
      done.
  Qed.

  (* The set of low states *)
  Definition low_states : set stateT :=
    mkSet (λ s, if state_phase s is Low then True else False).

  Lemma low_states_closed : sts.closed low_states {[ Send ]}.
  Proof.
    split.
    - apply (non_empty_inhabited(State Low ∅)). by rewrite !mkSet_elem_of /=.
    - move=>[p I]. rewrite /= /tok !mkSet_elem_of /= =>HI.
      destruct p; last done. set_solver.
    - move=>s1 s2. rewrite !mkSet_elem_of /==> Hs1 Hstep.
      inversion_clear Hstep as [T1 T2 Hdisj Hstep'].
      inversion_clear Hstep' as [? ? ? ? Htrans _ _ Htok].
      destruct Htrans; move:Hs1 Hdisj Htok =>/=;
                                first by destruct p.
      rewrite /= /tok /=. intros. set_solver +Hdisj Htok.
  Qed.

End barrier_proto.
(* I am too lazy to type the full module name all the time. But then
   why did we even put this into a module? Because some of the names 
   are so general.
   What we'd really like here is to import *some* of the names from
   the module into our namespaces. But Coq doesn't seem to support that...?? *)
Import barrier_proto.

(** Now we come to the Iris part of the proof. *)
Section proof.
  Context {Σ : iFunctorG} (N : namespace).
  Context `{heapG Σ} (heapN : namespace).
  Context `{stsG heap_lang Σ sts}.
  Context `{savedPropG heap_lang Σ}.

  Local Hint Immediate i_states_closed low_states_closed.

  Local Notation iProp := (iPropG heap_lang Σ).

  Definition waiting (P : iProp) (I : gset gname) : iProp :=
    (∃ Ψ : gname → iProp, ▷(P -★ Π★{set I} (λ i, Ψ i)) ★
                             Π★{set I} (λ i, saved_prop_own i (Ψ i)))%I.

  Definition ress (I : gset gname) : iProp :=
    (Π★{set I} (λ i, ∃ R, saved_prop_own i R ★ ▷R))%I.

  Local Notation state_to_val s :=
    (match s with State Low _ => 0 | State High _ => 1 end).
  Definition barrier_inv (l : loc) (P : iProp) (s : stateT) : iProp :=
    (l ↦ '(state_to_val s) ★
     match s with State Low I' => waiting P I' | State High I' => ress I' end
    )%I.

  Definition barrier_ctx (γ : gname) (l : loc) (P : iProp) : iProp :=
    (heap_ctx heapN ★ sts_ctx γ N (barrier_inv l P))%I.

  Global Instance barrier_ctx_ne n γ l : Proper (dist n ==> dist n) (barrier_ctx γ l).
  Proof.
    move=>? ? EQ. rewrite /barrier_ctx. apply sep_ne; first done. apply sts_ctx_ne.
    move=>[p I]. rewrite /barrier_inv. destruct p; last done.
    rewrite /waiting. by setoid_rewrite EQ.
  Qed.

  Definition send (l : loc) (P : iProp) : iProp :=
    (∃ γ, barrier_ctx γ l P ★ sts_ownS γ low_states {[ Send ]})%I.

  Global Instance send_ne n l : Proper (dist n ==> dist n) (send l).
  Proof. (* TODO: This really ought to be doable by an automatic tactic. it is just application of already regostered congruence lemmas. *)
    move=>? ? EQ. rewrite /send. apply exist_ne=>γ. by rewrite EQ.
  Qed.

  Definition recv (l : loc) (R : iProp) : iProp :=
    (∃ γ P Q i, barrier_ctx γ l P ★ sts_ownS γ (i_states i) {[ Change i ]} ★
        saved_prop_own i Q ★ ▷(Q -★ R))%I.

  Global Instance recv_ne n l : Proper (dist n ==> dist n) (recv l).
  Proof.
    move=>? ? EQ. rewrite /send. do 4 apply exist_ne=>?. by rewrite EQ.
  Qed.

  Lemma waiting_split i i1 i2 Q R1 R2 P I :
    i ∈ I → i1 ∉ I → i2 ∉ I → i1 ≠ i2 →
    (saved_prop_own i2 R2 ★ saved_prop_own i1 R1 ★ saved_prop_own i Q ★
     (Q -★ R1 ★ R2) ★ waiting P I)
    ⊑ waiting P ({[i1]} ∪ ({[i2]} ∪ (I ∖ {[i]}))).
  Proof.
    intros. rewrite /waiting !sep_exist_l. apply exist_elim=>Ψ.
    rewrite -(exist_intro (<[i1:=R1]> (<[i2:=R2]> Ψ))).
    rewrite [(Π★{set _} (λ _, saved_prop_own _ _))%I](big_sepS_delete _ I i) //.
    rewrite !assoc [(_ ★ (_ -★ _))%I]comm !assoc [(_ ★ ▷ _)%I]comm.
    rewrite !assoc [(_ ★ _ i _)%I]comm !assoc [(_ ★ _ i _)%I]comm -!assoc.
    rewrite 3!assoc. apply sep_mono.
    - rewrite saved_prop_agree. u_strip_later.
      apply wand_intro_l. rewrite [(_ ★ (_ -★ Π★{set _} _))%I]comm !assoc wand_elim_r.
      rewrite (big_sepS_delete _ I i) //.
      rewrite big_sepS_insert; last set_solver.
      rewrite big_sepS_insert; last set_solver.
      rewrite [(_ ★ Π★{set _} _)%I]comm !assoc [(_ ★ Π★{set _} _)%I]comm -!assoc.
      apply sep_mono.
      + apply big_sepS_mono; first done. intros j.
        rewrite elem_of_difference not_elem_of_singleton. intros.
        rewrite fn_lookup_insert_ne; last naive_solver.
        rewrite fn_lookup_insert_ne; last naive_solver.
        done.
      + rewrite !fn_lookup_insert fn_lookup_insert_ne // !fn_lookup_insert !assoc.
        eapply wand_apply_r'; first done.
        apply: (eq_rewrite (Ψ i) Q (λ x, x)%I); last by eauto with I.
        rewrite eq_sym. eauto with I.
    - rewrite big_sepS_insert; last set_solver.
      rewrite big_sepS_insert; last set_solver.
      rewrite !assoc. apply sep_mono.
      + rewrite !fn_lookup_insert fn_lookup_insert_ne // !fn_lookup_insert comm.
        done.
      + apply big_sepS_mono; first done. intros j.
        rewrite elem_of_difference not_elem_of_singleton. intros.
        rewrite fn_lookup_insert_ne; last naive_solver.
        rewrite fn_lookup_insert_ne; last naive_solver.
        done.
  Qed. 

  Lemma ress_split i i1 i2 Q R1 R2 I :
    i ∈ I → i1 ∉ I → i2 ∉ I → i1 ≠ i2 →
    (saved_prop_own i2 R2 ★ saved_prop_own i1 R1 ★ saved_prop_own i Q ★
     (Q -★ R1 ★ R2) ★ ress I)
    ⊑ ress ({[i1]} ∪ ({[i2]} ∪ (I ∖ {[i]}))).
  Proof.
    intros. rewrite /ress.
    rewrite [(Π★{set _} _)%I](big_sepS_delete _ I i) // !assoc !sep_exist_l !sep_exist_r.
    apply exist_elim=>R.
    rewrite big_sepS_insert; last set_solver.
    rewrite big_sepS_insert; last set_solver.
    rewrite -(exist_intro R1) -(exist_intro R2) [(_ i2 _ ★ _)%I]comm -!assoc.
    apply sep_mono_r. rewrite !assoc. apply sep_mono_l.
    rewrite [(▷ _ ★ _ i2 _)%I]comm -!assoc. apply sep_mono_r.
    rewrite !assoc [(_ ★ _ i R)%I]comm !assoc saved_prop_agree.
    rewrite [(▷ _ ★ _)%I]comm -!assoc. eapply wand_apply_l.
    { rewrite <-later_wand, <-later_intro. done. }
    { by rewrite later_sep. }
    u_strip_later.
    apply: (eq_rewrite R Q (λ x, x)%I); eauto with I.
  Qed.

  Lemma newchan_spec (P : iProp) (Φ : val → iProp) :
    (heap_ctx heapN ★ ∀ l, recv l P ★ send l P -★ Φ (LocV l))
    ⊑ || newchan '() {{ Φ }}.
  Proof.
    rewrite /newchan. wp_seq.
    rewrite -wp_pvs. wp eapply wp_alloc; eauto with I ndisj.
    apply forall_intro=>l. rewrite (forall_elim l). apply wand_intro_l.
    rewrite !assoc. apply pvs_wand_r.
    (* The core of this proof: Allocating the STS and the saved prop. *)
    eapply sep_elim_True_r.
    { by eapply (saved_prop_alloc _ P). }
    rewrite pvs_frame_l. apply pvs_strip_pvs. rewrite sep_exist_l.
    apply exist_elim=>i.
    trans (pvs ⊤ ⊤ (heap_ctx heapN ★ ▷ (barrier_inv l P (State Low {[ i ]}))  ★ saved_prop_own i P)).
    - rewrite -pvs_intro. rewrite [(_ ★ heap_ctx _)%I]comm -!assoc. apply sep_mono_r.
      rewrite {1}[saved_prop_own _ _]always_sep_dup !assoc. apply sep_mono_l.
      rewrite /barrier_inv /waiting -later_intro. apply sep_mono_r.
      rewrite -(exist_intro (const P)) /=. rewrite -[saved_prop_own _ _](left_id True%I (★)%I).
      apply sep_mono.
      + rewrite -later_intro. apply wand_intro_l. rewrite right_id.
        by rewrite big_sepS_singleton.
      + by rewrite big_sepS_singleton.
    - rewrite (sts_alloc (barrier_inv l P) ⊤ N); last by eauto.
      rewrite !pvs_frame_r !pvs_frame_l. 
      rewrite pvs_trans'. apply pvs_strip_pvs. rewrite sep_exist_r sep_exist_l.
      apply exist_elim=>γ.
      (* TODO: The record notation is rather annoying here *)
      rewrite /recv /send. rewrite -(exist_intro γ) -(exist_intro P).
      rewrite -(exist_intro P) -(exist_intro i) -(exist_intro γ).
      (* This is even more annoying than usually, since rewrite sometimes unfolds stuff... *)
      rewrite [barrier_ctx _ _ _]lock !assoc [(_ ★locked _)%I]comm !assoc -lock.
      rewrite -always_sep_dup.
      rewrite [barrier_ctx _ _ _]lock always_and_sep_l -!assoc assoc -lock.
      rewrite -pvs_frame_l. apply sep_mono_r.
      rewrite [(saved_prop_own _ _ ★ _)%I]comm !assoc. rewrite -pvs_frame_r.
      apply sep_mono_l.
      rewrite -assoc [(▷ _ ★ _)%I]comm assoc -pvs_frame_r.
      eapply sep_elim_True_r; last eapply sep_mono_l.
      { rewrite -later_intro. apply wand_intro_l. by rewrite right_id. }
      rewrite (sts_own_weaken ⊤ _ _ (i_states i ∩ low_states) _ 
                              ({[ Change i ]} ∪ {[ Send ]})).
      + apply pvs_mono. rewrite sts_ownS_op; eauto; []. set_solver.
      (* TODO the rest of this proof is rather annoying. *)
      + rewrite /= /tok /=. apply elem_of_equiv=>t.
        rewrite elem_of_difference elem_of_union.
        rewrite !mkSet_elem_of /change_tokens.
        (* TODO: destruct t; set_solver does not work. What is the best way to do on? *)
        destruct t as [i'|]; last by naive_solver. split.
        * move=>[_ Hn]. left. destruct (decide (i = i')); first by subst i.
          exfalso. apply Hn. left. set_solver.
        * move=>[[EQ]|?]; last discriminate. set_solver. 
      + apply elem_of_intersection. rewrite !mkSet_elem_of /=. set_solver.
      + apply sts.closed_op; eauto; first set_solver; [].
        apply (non_empty_inhabited (State Low {[ i ]})).
        apply elem_of_intersection.
        rewrite !mkSet_elem_of /=. set_solver.
  Qed.

  Lemma signal_spec l P (Φ : val → iProp) :
    heapN ⊥ N → (send l P ★ P ★ Φ '()) ⊑ || signal (LocV l) {{ Φ }}.
  Proof.
    intros Hdisj. rewrite /signal /send /barrier_ctx. rewrite sep_exist_r.
    apply exist_elim=>γ. wp_let.
    (* I think some evars here are better than repeating *everything* *)
    eapply (sts_fsaS _ (wp_fsa _)) with (N0:=N) (γ0:=γ); simpl;
      eauto with I ndisj.
    rewrite [(_ ★ sts_ownS _ _ _)%I]comm -!assoc. apply sep_mono_r.
    apply forall_intro=>-[p I]. apply wand_intro_l. rewrite -!assoc.
    apply const_elim_sep_l=>Hs. destruct p; last done.
    rewrite {1}/barrier_inv =>/={Hs}. rewrite later_sep.
    eapply wp_store; eauto with I ndisj. 
    rewrite -!assoc. apply sep_mono_r. u_strip_later.
    apply wand_intro_l. rewrite -(exist_intro (State High I)).
    rewrite -(exist_intro ∅). rewrite const_equiv /=; last first.
    { apply rtc_once. constructor; first constructor;
                        rewrite /= /tok /=; set_solver. }
    rewrite left_id -later_intro {2}/barrier_inv -!assoc. apply sep_mono_r.
    rewrite !assoc [(_ ★ P)%I]comm !assoc -2!assoc.
    apply sep_mono; last first.
    { apply wand_intro_l. eauto with I. }
    (* Now we come to the core of the proof: Updating from waiting to ress. *)
    rewrite /waiting /ress sep_exist_l. apply exist_elim=>{Φ} Φ.
    rewrite later_wand {1}(later_intro P) !assoc wand_elim_r.
    rewrite big_sepS_later -big_sepS_sepS. apply big_sepS_mono'=>i.
    rewrite -(exist_intro (Φ i)) comm. done.
  Qed.

  Lemma wait_spec l P (Φ : val → iProp) :
    heapN ⊥ N → (recv l P ★ (P -★ Φ '())) ⊑ || wait (LocV l) {{ Φ }}.
  Proof.
    rename P into R. intros Hdisj. wp_rec.
    rewrite {1}/recv /barrier_ctx. rewrite !sep_exist_r.
    apply exist_elim=>γ. rewrite !sep_exist_r. apply exist_elim=>P.
    rewrite !sep_exist_r. apply exist_elim=>Q. rewrite !sep_exist_r.
    apply exist_elim=>i. wp_focus (! _)%L.
    (* I think some evars here are better than repeating *everything* *)
    eapply (sts_fsaS _ (wp_fsa _)) with (N0:=N) (γ0:=γ); simpl;
      eauto with I ndisj.
    rewrite !assoc [(_ ★ sts_ownS _ _ _)%I]comm -!assoc. apply sep_mono_r.
    apply forall_intro=>-[p I]. apply wand_intro_l. rewrite -!assoc.
    apply const_elim_sep_l=>Hs.
    rewrite {1}/barrier_inv =>/=. rewrite later_sep.
    eapply wp_load; eauto with I ndisj.
    rewrite -!assoc. apply sep_mono_r. u_strip_later.
    apply wand_intro_l. destruct p.
    { (* a Low state. The comparison fails, and we recurse. *)
      rewrite -(exist_intro (State Low I)) -(exist_intro {[ Change i ]}).
      rewrite const_equiv /=; last by apply rtc_refl.
      rewrite left_id -[(▷ barrier_inv _ _ _)%I]later_intro {3}/barrier_inv.
      rewrite -!assoc. apply sep_mono_r, sep_mono_r, wand_intro_l.
      wp_op; first done. intros _. wp_if. rewrite !assoc.
      rewrite -always_wand_impl always_elim.
      rewrite -{2}pvs_wp. apply pvs_wand_r.
      rewrite -(exist_intro γ) -(exist_intro P) -(exist_intro Q) -(exist_intro i).
      rewrite !assoc.
      do 3 (rewrite -pvs_frame_r; apply sep_mono; last (try apply later_intro; reflexivity)).
      rewrite [(_ ★ heap_ctx _)%I]comm -!assoc -pvs_frame_l. apply sep_mono_r.
      rewrite comm -pvs_frame_l. apply sep_mono_r.
      apply sts_ownS_weaken; eauto using sts.up_subseteq. }
    (* a High state: the comparison succeeds, and we perform a transition and
       return to the client *)
    rewrite [(_ ★ □ (_ → _ ))%I]sep_elim_l.
    rewrite -(exist_intro (State High (I ∖ {[ i ]}))) -(exist_intro ∅).
    change (i ∈ I) in Hs.
    rewrite const_equiv /=; last first.
    { apply rtc_once. constructor; first constructor; rewrite /= /tok /=; [set_solver..|].
      (* TODO this proof is rather annoying. *)
      apply elem_of_equiv=>t. rewrite !elem_of_union.
      rewrite !mkSet_elem_of /change_tokens /=.
      destruct t as [j|]; last naive_solver.
      rewrite elem_of_difference elem_of_singleton.
      destruct (decide (i = j)); naive_solver. }
    rewrite left_id -[(▷ barrier_inv _ _ _)%I]later_intro {2}/barrier_inv.
    rewrite -!assoc. apply sep_mono_r. rewrite /ress.
    rewrite (big_sepS_delete _ I i) // [(_ ★ Π★{set _} _)%I]comm -!assoc.
    apply sep_mono_r. rewrite !sep_exist_r. apply exist_elim=>Q'.
    apply wand_intro_l. rewrite [(heap_ctx _ ★ _)%I]sep_elim_r.
    rewrite [(sts_own _ _ _ ★ _)%I]sep_elim_r [(sts_ctx _ _ _ ★ _)%I]sep_elim_r.
    rewrite !assoc [(_ ★ saved_prop_own i Q)%I]comm !assoc saved_prop_agree.
    wp_op>; last done. intros _. u_strip_later.
    wp_if. 
    eapply wand_apply_r; [done..|]. eapply wand_apply_r; [done..|].
    apply: (eq_rewrite Q' Q (λ x, x)%I); last by eauto with I.
    rewrite eq_sym. eauto with I.
  Qed.

  Lemma recv_split l P1 P2 Φ :
    (recv l (P1 ★ P2) ★ (recv l P1 ★ recv l P2 -★ Φ '())) ⊑ || Skip {{ Φ }}.
  Proof.
    rename P1 into R1. rename P2 into R2.
    rewrite {1}/recv /barrier_ctx. rewrite sep_exist_r.
    apply exist_elim=>γ. rewrite sep_exist_r.  apply exist_elim=>P. 
    rewrite sep_exist_r.  apply exist_elim=>Q. rewrite sep_exist_r.
    apply exist_elim=>i. rewrite -wp_pvs.
    (* I think some evars here are better than repeating *everything* *)
    eapply (sts_fsaS _ (wp_fsa _)) with (N0:=N) (γ0:=γ); simpl;
      eauto with I ndisj.
    rewrite !assoc [(_ ★ sts_ownS _ _ _)%I]comm -!assoc. apply sep_mono_r.
    apply forall_intro=>-[p I]. apply wand_intro_l. rewrite -!assoc.
    apply const_elim_sep_l=>Hs. rewrite -wp_pvs. wp_seq.
    eapply sep_elim_True_l.
    { eapply saved_prop_alloc_strong with (P0 := R1) (G := I). }
    rewrite pvs_frame_r. apply pvs_strip_pvs. rewrite sep_exist_r.
    apply exist_elim=>i1. rewrite always_and_sep_l. rewrite -assoc.
    apply const_elim_sep_l=>Hi1. eapply sep_elim_True_l.
    { eapply saved_prop_alloc_strong with (P0 := R2) (G := I ∪ {[ i1 ]}). }
    rewrite pvs_frame_r. apply pvs_mono. rewrite sep_exist_r.
    apply exist_elim=>i2. rewrite always_and_sep_l. rewrite -assoc.
    apply const_elim_sep_l=>Hi2.
    rewrite ->not_elem_of_union, elem_of_singleton in Hi2.
    destruct Hi2 as [Hi2 Hi12]. change (i ∈ I) in Hs. destruct p.
    (* Case I: Low state. *)
    - rewrite -(exist_intro (State Low ({[i1]} ∪ ({[i2]} ∪ (I ∖ {[i]}))))).
      rewrite -(exist_intro ({[Change i1 ]} ∪ {[ Change i2 ]})).
      rewrite const_equiv; last first.
      { apply rtc_once. constructor; first constructor; rewrite /= /tok /=; first set_solver.
      (* This gets annoying... and I think I can see a pattern with all these proofs. Automatable? *)
        - apply elem_of_equiv=>t. destruct t; last set_solver.
          rewrite !mkSet_elem_of /change_tokens /=.
          rewrite !elem_of_union !elem_of_difference !elem_of_singleton.
          naive_solver.
        - apply elem_of_equiv=>t. destruct t as [j|]; last set_solver.
          rewrite !mkSet_elem_of /change_tokens /=.
          rewrite !elem_of_union !elem_of_difference !elem_of_singleton.
          destruct (decide (i1 = j)); first naive_solver. 
          destruct (decide (i2 = j)); first naive_solver.
          destruct (decide (i = j)); naive_solver. }
      rewrite left_id -later_intro {1 3}/barrier_inv.
      (* FIXME ssreflect rewrite fails if there are evars around. Also, this is very slow because we don't have a proof mode. *)
      rewrite -(waiting_split _ _ _ Q R1 R2); [|done..].
      match goal with | |- _ ⊑ ?G => rewrite [G]lock end.
      rewrite {1}[saved_prop_own i1 _]always_sep_dup.
      rewrite {1}[saved_prop_own i2 _]always_sep_dup.
      rewrite !assoc [(_ ★ _ i1 _)%I]comm.
      rewrite !assoc [(_ ★ _ i _)%I]comm.
      rewrite !assoc [(_ ★ (l ↦ _))%I]comm.
      rewrite !assoc [(_ ★ (waiting _ _))%I]comm.
      rewrite !assoc [(_ ★ (Q -★ _))%I]comm -!assoc 5!assoc.
      unlock. apply sep_mono.
      + (* This should really all be handled automatically. *)
        rewrite !assoc [(_ ★ (l ↦ _))%I]comm -!assoc. apply sep_mono_r.
        rewrite !assoc [(_ ★ _ i2 _)%I]comm -!assoc. apply sep_mono_r.
        rewrite !assoc [(_ ★ _ i1 _)%I]comm -!assoc. apply sep_mono_r.
        rewrite !assoc [(_ ★ _ i _)%I]comm -!assoc. apply sep_mono_r.
        done.
      + apply wand_intro_l. rewrite !assoc. eapply pvs_wand_r. rewrite /recv.
        rewrite -(exist_intro γ) -(exist_intro P) -(exist_intro R1) -(exist_intro i1).
        rewrite -(exist_intro γ) -(exist_intro P) -(exist_intro R2) -(exist_intro i2).
        do 2 rewrite !(assoc (★)%I) [(_ ★ sts_ownS _ _ _)%I]comm.
        rewrite -!assoc. rewrite [(sts_ownS _ _ _ ★ _ ★ _)%I]assoc -pvs_frame_r.
        apply sep_mono.
        * rewrite -sts_ownS_op; [|set_solver|by eauto..].
          apply sts_own_weaken; first done.
          { rewrite !mkSet_elem_of /=. set_solver+. }
          apply sts.closed_op; [by eauto..|set_solver|].
          apply (non_empty_inhabited (State Low ({[i1]} ∪ ({[i2]} ∪ (I ∖ {[i]}))))).
          rewrite !mkSet_elem_of /=. set_solver+.
        * rewrite {1}[heap_ctx _]always_sep_dup !assoc [(_ ★ heap_ctx _)%I]comm -!assoc. apply sep_mono_r.
          rewrite !assoc ![(_ ★ heap_ctx _)%I]comm -!assoc. apply sep_mono_r.
          rewrite {1}[sts_ctx _ _ _]always_sep_dup !assoc [(_ ★ sts_ctx _ _ _)%I]comm -!assoc. apply sep_mono_r.
          rewrite !assoc ![(_ ★ sts_ctx _ _ _)%I]comm -!assoc. apply sep_mono_r.
          rewrite comm. apply sep_mono_r. apply sep_intro_True_l.
          { rewrite -later_intro. apply wand_intro_l. by rewrite right_id. }
          apply sep_intro_True_r; first done.
          { rewrite -later_intro. apply wand_intro_l. by rewrite right_id. }
(* Case II: High state. TODO: Lots of this script is just copy-n-paste of the previous one.
   Some of that ist because stuff should be more trivial than it is (like sts_ownS_op
   having a too strong precondition, see the TODO over there); some of that
   is because the goals a fairly simioar in structure, and the proof scripts
   are mostlx concerned with manually managaing the structure (assoc, comm, dup) of
   the context. *)
    - rewrite -(exist_intro (State High ({[i1]} ∪ ({[i2]} ∪ (I ∖ {[i]}))))).
      rewrite -(exist_intro ({[Change i1 ]} ∪ {[ Change i2 ]})).
      rewrite const_equiv; last first.
      (* This is exactly the same proof as above. Really, this should all be automated to be simple...
         but if we can't get that, at least factor it out as a lemma? *)
      { apply rtc_once. constructor; first constructor; rewrite /= /tok /=; first set_solver.
      (* This gets annoying... and I think I can see a pattern with all these proofs. Automatable? *)
        - apply elem_of_equiv=>t. destruct t; last set_solver.
          rewrite !mkSet_elem_of /change_tokens /=.
          rewrite !elem_of_union !elem_of_difference !elem_of_singleton.
          naive_solver.
        - apply elem_of_equiv=>t. destruct t as [j|]; last set_solver.
          rewrite !mkSet_elem_of /change_tokens /=.
          rewrite !elem_of_union !elem_of_difference !elem_of_singleton.
          destruct (decide (i1 = j)); first naive_solver. 
          destruct (decide (i2 = j)); first naive_solver.
          destruct (decide (i = j)); naive_solver. }
      rewrite left_id -later_intro {1 3}/barrier_inv.
      rewrite -(ress_split _ _ _ Q R1 R2); [|done..].
      match goal with | |- _ ⊑ ?G => rewrite [G]lock end.
      rewrite {1}[saved_prop_own i1 _]always_sep_dup.
      rewrite {1}[saved_prop_own i2 _]always_sep_dup.
      rewrite !assoc [(_ ★ _ i1 _)%I]comm.
      rewrite !assoc [(_ ★ _ i _)%I]comm.
      rewrite !assoc [(_ ★ (l ↦ _))%I]comm.
      rewrite !assoc [(_ ★ (ress _))%I]comm.
      rewrite !assoc [(_ ★ (Q -★ _))%I]comm -!assoc 5!assoc.
      unlock. apply sep_mono.
      + (* This should really all be handled automatically. *)
        rewrite !assoc [(_ ★ (l ↦ _))%I]comm -!assoc. apply sep_mono_r.
        rewrite !assoc [(_ ★ _ i2 _)%I]comm -!assoc. apply sep_mono_r.
        rewrite !assoc [(_ ★ _ i1 _)%I]comm -!assoc. apply sep_mono_r.
        rewrite !assoc [(_ ★ _ i _)%I]comm -!assoc. apply sep_mono_r.
        done.
      + apply wand_intro_l. rewrite !assoc. eapply pvs_wand_r. rewrite /recv.
        rewrite -(exist_intro γ) -(exist_intro P) -(exist_intro R1) -(exist_intro i1).
        rewrite -(exist_intro γ) -(exist_intro P) -(exist_intro R2) -(exist_intro i2).
        do 2 rewrite !(assoc (★)%I) [(_ ★ sts_ownS _ _ _)%I]comm.
        rewrite -!assoc. rewrite [(sts_ownS _ _ _ ★ _ ★ _)%I]assoc -pvs_frame_r.
        apply sep_mono.
        * rewrite -sts_ownS_op; [|set_solver|by eauto..].
          apply sts_own_weaken; first done.
          { rewrite !mkSet_elem_of /=. set_solver+. }
          apply sts.closed_op; [by eauto..|set_solver|].
          apply (non_empty_inhabited (State High ({[i1]} ∪ ({[i2]} ∪ (I ∖ {[i]}))))).
          rewrite !mkSet_elem_of /=. set_solver+.
        * rewrite {1}[heap_ctx _]always_sep_dup !assoc [(_ ★ heap_ctx _)%I]comm -!assoc. apply sep_mono_r.
          rewrite !assoc ![(_ ★ heap_ctx _)%I]comm -!assoc. apply sep_mono_r.
          rewrite {1}[sts_ctx _ _ _]always_sep_dup !assoc [(_ ★ sts_ctx _ _ _)%I]comm -!assoc. apply sep_mono_r.
          rewrite !assoc ![(_ ★ sts_ctx _ _ _)%I]comm -!assoc. apply sep_mono_r.
          rewrite comm. apply sep_mono_r. apply sep_intro_True_l.
          { rewrite -later_intro. apply wand_intro_l. by rewrite right_id. }
          apply sep_intro_True_r; first done.
          { rewrite -later_intro. apply wand_intro_l. by rewrite right_id. }
  Qed.

  Lemma recv_strengthen l P1 P2 :
    (P1 -★ P2) ⊑ (recv l P1 -★ recv l P2).
  Proof.
    apply wand_intro_l. rewrite /recv. rewrite sep_exist_r. apply exist_mono=>γ.
    rewrite sep_exist_r. apply exist_mono=>P. rewrite sep_exist_r.
    apply exist_mono=>Q. rewrite sep_exist_r. apply exist_mono=>i.
    rewrite -!assoc. apply sep_mono_r, sep_mono_r, sep_mono_r, sep_mono_r.
    rewrite (later_intro (P1 -★ _)%I) -later_sep. apply later_mono.
    apply wand_intro_l. rewrite !assoc wand_elim_r wand_elim_r. done.
  Qed.

End proof.

Section spec.
  Context {Σ : iFunctorG}.
  Context `{heapG Σ}.
  Context `{stsG heap_lang Σ barrier_proto.sts}.
  Context `{savedPropG heap_lang Σ}.

  Local Notation iProp := (iPropG heap_lang Σ).

  (* TODO: Maybe notation for LocV (and Loc)? *)
  Lemma barrier_spec (heapN N : namespace) :
    heapN ⊥ N →
    ∃ (recv send : loc -> iProp -n> iProp),
      (∀ P, heap_ctx heapN ⊑ ({{ True }} newchan '() {{ λ v, ∃ l, v = LocV l ★ recv l P ★ send l P }})) ∧
      (∀ l P, {{ send l P ★ P }} signal (LocV l) {{ λ _, True }}) ∧
      (∀ l P, {{ recv l P }} wait (LocV l) {{ λ _, P }}) ∧
      (∀ l P Q, {{ recv l (P ★ Q) }} Skip {{ λ _, recv l P ★ recv l Q }}) ∧
      (∀ l P Q, (P -★ Q) ⊑ (recv l P -★ recv l Q)).
  Proof.
    intros HN. exists (λ l, CofeMor (recv N heapN l)). exists (λ l, CofeMor (send N heapN l)).
    split_and?; cbn.
    - intros. apply: always_intro. apply impl_intro_l. rewrite -newchan_spec.
      rewrite comm always_and_sep_r. apply sep_mono_r. apply forall_intro=>l.
      apply wand_intro_l. rewrite right_id -(exist_intro l) const_equiv // left_id.
      done.
    - intros. apply ht_alt. rewrite -signal_spec; last done.
        by rewrite right_id.
    - intros. apply ht_alt. rewrite -wait_spec; last done.
      apply sep_intro_True_r; first done. apply wand_intro_l. eauto with I.
    - intros. apply ht_alt. rewrite -recv_split.
      apply sep_intro_True_r; first done. apply wand_intro_l. eauto with I.
    - intros. apply recv_strengthen.
  Qed.

End spec.
