From stdpp Require Export coPset.
From iris.proofmode Require Import tactics.
From iris.algebra Require Import gmap auth agree gset coPset.
From iris.base_logic.lib Require Export own.
From iris.base_logic.lib Require Import wsat.
From iris Require Import options.
Export invG.
Import uPred.

Definition uPred_fupd_def `{!invG Σ} (E1 E2 : coPset) (P : iProp Σ) : iProp Σ :=
  wsat ∗ ownE E1 ==∗ ◇ (wsat ∗ ownE E2 ∗ P).
Definition uPred_fupd_aux : seal (@uPred_fupd_def). Proof. by eexists. Qed.
Definition uPred_fupd := uPred_fupd_aux.(unseal).
Arguments uPred_fupd {Σ _}.
Lemma uPred_fupd_eq `{!invG Σ} : @fupd _ uPred_fupd = uPred_fupd_def.
Proof. rewrite -uPred_fupd_aux.(seal_eq) //. Qed.

Lemma uPred_fupd_mixin `{!invG Σ} : BiFUpdMixin (uPredI (iResUR Σ)) uPred_fupd.
Proof.
  split.
  - rewrite uPred_fupd_eq. solve_proper.
  - intros E1 E2 P (E1''&->&?)%subseteq_disjoint_union_L.
    rewrite uPred_fupd_eq /uPred_fupd_def ownE_op //.
    by iIntros "$ ($ & $ & HE) !> !> [$ $] !> !>" .
  - rewrite uPred_fupd_eq. iIntros (E1 E2 P) ">H [Hw HE]". iApply "H"; by iFrame.
  - rewrite uPred_fupd_eq. iIntros (E1 E2 P Q HPQ) "HP HwE". rewrite -HPQ. by iApply "HP".
  - rewrite uPred_fupd_eq. iIntros (E1 E2 E3 P) "HP HwE".
    iMod ("HP" with "HwE") as ">(Hw & HE & HP)". iApply "HP"; by iFrame.
  - intros E1 E2 Ef P HE1Ef. rewrite uPred_fupd_eq /uPred_fupd_def ownE_op //.
    iIntros "Hvs (Hw & HE1 &HEf)".
    iMod ("Hvs" with "[Hw HE1]") as ">($ & HE2 & HP)"; first by iFrame.
    iDestruct (ownE_op' with "[HE2 HEf]") as "[? $]"; first by iFrame.
    iIntros "!> !>". by iApply "HP".
  - rewrite uPred_fupd_eq /uPred_fupd_def. by iIntros (????) "[HwP $]".
Qed.
Instance uPred_bi_fupd `{!invG Σ} : BiFUpd (uPredI (iResUR Σ)) :=
  {| bi_fupd_mixin := uPred_fupd_mixin |}.

Instance uPred_bi_bupd_fupd `{!invG Σ} : BiBUpdFUpd (uPredI (iResUR Σ)).
Proof. rewrite /BiBUpdFUpd uPred_fupd_eq. by iIntros (E P) ">? [$ $] !> !>". Qed.

Instance uPred_bi_fupd_plainly `{!invG Σ} : BiFUpdPlainly (uPredI (iResUR Σ)).
Proof.
  split.
  - rewrite uPred_fupd_eq /uPred_fupd_def. iIntros (E P) "H [Hw HE]".
    iAssert (◇ ■ P)%I as "#>HP".
    { by iMod ("H" with "[$]") as "(_ & _ & HP)". }
    by iFrame.
  - rewrite uPred_fupd_eq /uPred_fupd_def. iIntros (E P Q) "[H HQ] [Hw HE]".
    iAssert (◇ ■ P)%I as "#>HP".
    { by iMod ("H" with "HQ [$]") as "(_ & _ & HP)". }
    by iFrame.
  - rewrite uPred_fupd_eq /uPred_fupd_def. iIntros (E P) "H [Hw HE]".
    iAssert (▷ ◇ ■ P)%I as "#HP".
    { iNext. by iMod ("H" with "[$]") as "(_ & _ & HP)". }
    iFrame. iIntros "!> !> !>". by iMod "HP".
  - rewrite uPred_fupd_eq /uPred_fupd_def. iIntros (E A Φ) "HΦ [Hw HE]".
    iAssert (◇ ■ ∀ x : A, Φ x)%I as "#>HP".
    { iIntros (x). by iMod ("HΦ" with "[$Hw $HE]") as "(_&_&?)". }
    by iFrame.
Qed.

Lemma fupd_plain_soundness `{!invPreG Σ} E1 E2 (P: iProp Σ) `{!Plain P} :
  (∀ `{Hinv: !invG Σ}, ⊢ |={E1,E2}=> P) → ⊢ P.
Proof.
  iIntros (Hfupd). apply later_soundness. iMod wsat_alloc as (Hinv) "[Hw HE]".
  iAssert (|={⊤,E2}=> P)%I as "H".
  { iMod fupd_intro_mask'; last iApply Hfupd. done. }
  rewrite uPred_fupd_eq /uPred_fupd_def.
  iMod ("H" with "[$]") as "[Hw [HE >H']]"; iFrame.
Qed.

Lemma step_fupdN_soundness `{!invPreG Σ} φ n :
  (∀ `{Hinv: !invG Σ}, ⊢@{iPropI Σ} |={⊤}[∅]▷=>^n |={⊤,∅}=> ⌜ φ ⌝) →
  φ.
Proof.
  intros Hiter.
  apply (soundness (M:=iResUR Σ) _  (S n)); simpl.
  apply (fupd_plain_soundness ⊤ ⊤ _)=> Hinv.
  iPoseProof (Hiter Hinv) as "H". clear Hiter.
  destruct n as [|n].
  - iApply fupd_plainly_mask_empty. iMod "H" as %?; auto.
  - iDestruct (step_fupdN_wand _ _ _ _ (|={⊤}=> ⌜φ⌝)%I with "H []") as "H'".
    { by iApply fupd_plain_mask_empty. }
    rewrite -step_fupdN_S_fupd.
    iMod (step_fupdN_plain with "H'") as "Hφ". iModIntro. iNext.
    rewrite -later_laterN laterN_later.
    iNext. by iMod "Hφ".
Qed.

Lemma step_fupdN_soundness' `{!invPreG Σ} φ n :
  (∀ `{Hinv: !invG Σ}, ⊢@{iPropI Σ} |={⊤}[∅]▷=>^n ⌜ φ ⌝) →
  φ.
Proof.
  iIntros (Hiter). eapply (step_fupdN_soundness _ n).
  iIntros (Hinv). iPoseProof (Hiter Hinv) as "Hiter".
  iApply (step_fupdN_wand with "Hiter"). by iApply fupd_mask_weaken.
Qed.
