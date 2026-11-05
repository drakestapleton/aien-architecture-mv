(* L581: symbolic/cost checks, not timing predictions. Stateless kernel. *)
ClearAll[hh,ww,xx,rr,theta,vectors];
hh={{1,1},{1,-1}}/Sqrt[2]; ww={{3,2},{-1,4}}; xx={x1,x2};
ExportString[<|
"basis_identity_residual" -> Simplify[(ww.Transpose[hh]).(hh.xx)-ww.xx],
"orthogonality" -> Simplify[Transpose[hh].hh],
"nonlinearity_does_not_commute" -> ToString[Simplify[(hh.xx)^2-hh.(xx^2)],InputForm],
"four_orbital_hybrid_orthogonality" -> Simplify[With[{tt=KroneckerProduct[{{1,1},{1,-1}},{{1,1},{1,-1}}]/2},tt.Transpose[tt]]],
"interference_probability" -> ToString[FullSimplify[Abs[(1+Exp[I theta])/2]^2,Element[theta,Reals]],InputForm],
"expert_matrix_entries" -> 2048*512,
"rank64_entry_ratio" -> N[64*(2048+512)/(2048*512)],
"rank64_bf16_vs_fp8_byte_ratio_no_metadata" -> N[2*64*(2048+512)/(2048*512)],
"rank_break_even_equal_precision" -> ToString[Reduce[rr*(2048+512)<2048*512 && rr>0,rr,Integers],InputForm],
"rank_break_even_bf16_vs_fp8" -> ToString[Reduce[2*rr*(2048+512)<2048*512 && rr>0,rr,Integers],InputForm],
"hadamard2048_add_sub_count_excluding_normalization" -> 2048*Log2[2048],
"complex128_state_GiB" -> Table[{nn,16*2^nn/2^30},{nn,{30,32,33}}],
"uniform_independent_eight_slot_expert_union_ASSUMPTION" -> N[256*(1-(1-8/256)^8)],
"rotation_relative_weight_error_reduction_percent" -> (100*(1-#)& /@ {0.8443305493994437,0.9776014339729382,0.9022996024413539}),
"rank64_relative_weight_error_percent" -> 100*{0.6085668140383202,0.8560844464246313,0.7771349973363622},
"rank204_relative_weight_error_percent" -> 100*{0.15022797722044212,0.5998930960862606,0.49053763737893785},
"selected_first_expert_zero_channel_fraction" -> N[280/512],
"selected_first_expert_zero_weight_payload_bytes" -> 280*2048*3,
"selected_first_expert_total_weight_payload_bytes" -> 512*2048*3,
"amdahl_halving_80percent_EXAMPLE" -> N[1/(1-4/5+(4/5)/2)],
"amdahl_halving_20percent_EXAMPLE" -> N[1/(1-1/5+(1/5)/2)]
|>,"RawJSON"]
