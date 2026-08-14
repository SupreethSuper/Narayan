# Observations on the CNN Acceleration Paper Set

**Corpus:** 12 PDFs in `C:\Users\supre\Downloads\papers`, spanning 2015–2025 (CVPR, ISCA, ICPP, TACO, TCAS-I, TVLSI, TPAMI-style arXiv, MDPI Electronics ×2, JKSUCI, Google whitepaper).
**Unifying subject:** making convolution in CNNs cheaper — in arithmetic, in memory traffic, in energy, or in silicon area.

---

## Part 0 — Corpus at a Glance

| # | File | Short name | Year / Venue | Primary lever |
|---|------|-----------|--------------|---------------|
| 1 | `Lavin_Fast_Algorithms_for_CVPR_2016_paper.pdf` | **Lavin & Gray** | 2016 CVPR | Winograd minimal filtering (algorithm) |
| 2 | `Liu_Sparse_Convolutional_Neural_2015_CVPR_paper.pdf` | **SCNN-Liu** | 2015 CVPR | Sparse decomposition + custom CPU SpMM |
| 3 | `1505.06798v2.pdf` | **Zhang et al.** | 2015 arXiv (TPAMI-style) | Nonlinear low-rank response reconstruction |
| 4 | `1806.08342v1.pdf` | **Krishnamoorthi** | 2018 Google whitepaper | Integer quantization (PTQ + QAT) |
| 5 | `3140659.3080254.pdf` | **SCNN (NVIDIA)** | 2017 ISCA | Sparse dataflow accelerator (Cartesian product) |
| 6 | `3472456.3472464.pdf` | **LoWino (ICPP)** | 2021 ICPP | INT8 Winograd, in-domain quantization |
| 7 | `3632956.pdf` | **LoWino (TACO)** | 2024 ACM TACO | Extended LoWino: inside-quantization + fused impl. |
| 8 | `A_Stride-Based_Convolution_Decomposition_...pdf` | **SCDM/WHD** | 2020 IEEE TCAS-I | Stride-based kernel decomposition + fused Winograd unit |
| 9 | `Accelerating_..._With_FFT_on_Embedded_Hardware.pdf` | **FFT-OVA** | 2018 IEEE TVLSI | FFT overlap-and-add convolution, cross-platform |
| 10 | `electronics-11-00945.pdf` | **Ghimire survey** | 2022 MDPI Electronics | Survey: efficient CNNs + HW acceleration |
| 11 | `electronics-14-01182-v2.pdf` | **Li 2025 FPGA** | 2025 MDPI Electronics | Layer-to-layer unified-input Decomposable Winograd on FPGA |
| 12 | `j.jksuci.2020.10.004.pdf` | **Habib survey** | 2022 JKSUCI | Survey: SGD optimizers + fast convolution + parallelism |

**Shape of the set:** 8 primary research papers, 2 broad surveys, 1 industrial whitepaper, 1 conference→journal extension pair (#6 → #7, same core authors, explicitly labeled as an extension). Roughly half are software/algorithm papers, half are hardware papers, and the Winograd algorithm is the single most common thread (7 of 12 papers engage with it directly).

---

# Part 1 — Detailed Per-Paper Observations

## 1. Lavin & Gray — *Fast Algorithms for Convolutional Neural Networks* (CVPR 2016)

**Problem framing.** Progress in convnets is limited by compute; FFT convolution is fast for *large* filters but state-of-the-art nets use small 3×3 filters and want *small batch sizes* (large batches hurt convergence and cap cluster size). So there is a gap: fast algorithms for small filters and small batches.

**Core method — Winograd/Toom-Cook minimal filtering.**
- Minimal 1D algorithm F(m,r) needs exactly μ = m + r − 1 multiplications (Winograd 1980). Nesting gives 2D: μ(F(m×n, r×s)) = (m+r−1)(n+s−1).
- Elegant framing: *the minimal filtering algorithm requires one multiplication per input.*
- Matrix form: `Y = Aᵀ[(Gg) ⊙ (Bᵀd)]`; 2D: `Y = Aᵀ[(GgGᵀ) ⊙ (BᵀdB)]A`.
- Key implementation insight (Eq. 10): the channel reduction can be done **in the transform domain**, so the inverse transform cost is amortized over C channels. The element-wise products across channels collapse into α² independent **matrix multiplications** — which map well to CPU/GPU/FPGA.

**Concrete algorithms given.**
- F(2×2,3×3): 16 mults vs 36 direct → **2.25×** arithmetic reduction. Transforms: 32 adds (data), 28 FLOPs (filter), 24 adds (inverse).
- F(3×3,2×2): for the weight-gradient path in training (also 2.25×).
- F(4×4,3×3): 36 mults vs 144 → **4×**. Transforms grow to 144/72/100 FLOPs.

**Explicit statement of the fundamental limit.** "The number of additions and constant multiplications required by the minimal Winograd transforms increases **quadratically** with the tile size... for large tiles the complexity of the transforms will overwhelm any savings in multiplications." Also: transform matrix element *magnitude* grows with tile size, degrading numeric accuracy. This is the single constraint that papers #6, #7, #8, #11 all later try to work around.

**Analytical model (very reusable).** Total layer cost:
`L = α′(1 + β′/K + γ′/P + δ′/C)·NHWCK`
where α′ = multiply complexity, β′/γ′/δ′ = normalized data/filter/inverse transform complexities, P = tiles per channel. Speedup vs direct is bounded by R²/α′. Requirement for a real speedup: β′≪K, γ′≪P, δ′≪C.

**FFT comparison (the most rigorous in the set).**
- FFT is cast in the same overlap-and-save framework, so the comparison is apples-to-apples.
- Hermitian symmetry reduces unique products to α(⌊α/2⌋+1); with naive complex multiply that is 4(⌊α/2⌋+1)/α > **2** real mults per input.
- Introduces a **3-multiply complex multiplication** (Karatsuba-style) into convnet FFT — stated as novel for convnets — giving 3(⌊α/2⌋+1)/α > **1.5** real mults/input, implemented via 3 SGEMM calls.
- Winograd is always **1.0** real mult per input. Conclusion: FFT with direct CGEMM needs tile size ≥ **64×64** to match Winograd F(4×4,3×3)'s 6×6 tile on the multiply stage; with fast CGEMM it reaches parity at tile **16**.
- Memory argument: a 64×64 transformed filter channel is 4096 units vs 9 for the original 3×3 filter; Winograd's 6×6 tile expands it to only 36.

**GPU implementation detail worth noting.** NVIDIA Maxwell (Titan X). Fully **fused** kernel: data transform + 16 batched GEMMs + inverse transform in one block. Instruction cache is only ~720 instructions — main loop exceeds it, mitigated by 128-byte cache-line alignment. CHWN data order for contiguous loads. "Super-blocking" of 32 4×4 tiles across images/rows/cols to keep small batch sizes efficient. L2 cache blocking over 128-filter groups halves DDR bandwidth. An "FX" variant runs the filter transform as a separate kernel into a ≤16 MB workspace.

**Results.**
- fp32 vs cuDNN v3: **2.26×** at N=1, 1.48× at N=64, peak 7.28× at N=8 (where cuDNN's FFT path collapses to 1.29 TFLOPS). 9.49 effective TFLOPS at N=16.
- fp16: **10.28 effective TFLOPS** at N=64 on a 6.96 TFLOPS device (effective TFLOPS can exceed peak because it credits the direct-algorithm FLOP count).
- **Accuracy surprise:** F(2×2,3×3) is *more accurate than direct convolution* in fp32 (1.53e-5 vs 4.01e-5 max element error on VGG conv1.2) — because its multiply stage reduces over C channels rather than RSC filter elements. F(4×4,3×3) is worse but still better than direct fp16.
- Workspace: fused = 0 global workspace; FX ≤ 16 MB; cuDNN FFT used up to **2.6 GB**.

**Other observations.**
- Explicitly declares quantization/approximation methods out of scope and "orthogonal and complementary" — a claim that papers #6/#7 later show is *false in the Winograd case* (they are not orthogonal).
- Strassen recursion is discussed and rejected: each recursion halves all 3 matrix dimensions for only an 8/7 gain, whereas fast convolution gives ≥2.25× while shrinking only P.
- Notes cuDNN's FFT behaves as if it uses very large tiles or one tile per image, explaining its poor mid-N performance.

---

## 2. Liu, Wang, Foroosh, Tappen, Pensky — *Sparse Convolutional Neural Networks* (CVPR 2015)

**Problem framing.** Over-parameterization is *necessary* during training (non-convexity + random init), and no independence constraint is imposed among kernels — therefore heavy redundancy is expected, and can be removed after the fact.

**Core method — two-stage sparse decomposition.**
1. **Inter-channel:** transform input tensor I and kernel K by a matrix P ∈ ℝ^{m×m}: `K(u,v,i,j) ≈ Σ_k R(u,v,k,j)P(k,i)`.
2. **Intra-channel:** for each channel i, decompose R(·,·,i,·) into a small basis Q_i ∈ ℝ^{s×s×q_i} and a **sparse** coefficient matrix S_i ∈ ℝ^{q_i×n}.
- Result: each conv layer = a few basis convolutions + one **sparse matrix multiplication**.

**Optimization objective (the "intelligent" part).** Sparse **group-lasso**:
`min L_net + λ₁ Σ‖S_i‖₁ + λ₂ Σ_j ‖S_i(j,·)‖₂` s.t. ‖P(·,j)‖₂≤1, ‖Q_i(·,·,k)‖₂≤1.
- ℓ₁ term drives element sparsity; group-lasso term zeroes entire *rows*, which reduces the number of basis filters q_i that need convolving. So the objective simultaneously optimizes **network loss, sparsity, and rank**.

**Clean articulation of sparse-vs-low-rank.** "Speedup from a sparse decomposition is proportional to the percentage of **non-zero elements**; reduction from a low-rank decomposition is proportional to the percentage of **non-zero columns**. The sparsity constraint targets specific entries; a low-rank constraint must eliminate entire columns." This is the sharpest statement of that distinction in the whole set.

**Initialization study.** Three inits compared: sparse dictionary learning (Mairal et al.), PCA, and identity. Findings:
- All three yield only *limited* sparsity from initialization alone; fine-tuning does the heavy lifting.
- **PCA beats sparse coding** in practice, attributed to sparse coding's non-convexity and inexact reconstruction, while PCA's global optimum is obtainable via SVD.
- Random/identity init is markedly worse — so *both* init and fine-tuning matter.

**Custom sparse-dense matmul (the systems contribution).** Two observations drive it:
1. After training, kernel sparsity **pattern is fixed** → the non-zero locations can be **compiled directly into the multiplication code as register indices**, eliminating indirect/jumping memory access.
2. Only kernels are treated as sparse; input feature maps (moderately sparse) are treated as dense.
- Built on OpenBLAS's AVX blocking scheme (L2-cache blocks → 8-element strips → 8×8 tiles in 8 AVX registers). Code generation emits e.g. `c7 += a1 × b1,7`.

**Results.**
- >90% sparsity on all 5 AlexNet-style conv layers, <1% ILSVRC2012 accuracy drop.
- Theoretical vs **actual** per-layer speedups: conv1 2.61/2.47, conv2 7.14/**4.52**, conv3 16.12/**6.88**, conv4 12.42/5.18, conv5 10.77/3.92. The theory-practice gap widens with sparsity.
- Runtime breakdown: sparse matmul dominates the last three layers; basis convolution dominates the first two.
- Detection (SPP + PASCAL VOC2007): mAP ~2% below baseline; cascade prunes ~80% of candidate windows for ~5× FC speedup; FC layers themselves 85%/68% sparse for >2× more.

**Sharp micro-observations.**
- Runtime analysis of the sparse kernel: **arithmetic time is linear in density and near the theoretical limit, but I/O time falls only sub-linearly.** Below 10% density, I/O is >80% of runtime. This is an early, clear statement of the "sparsity becomes memory-bound" phenomenon that SCNN (#5) later attacks in hardware.
- Arithmetic + I/O time sums to *more* than measured total time — CPU pipelining overlaps them.
- Kernel similarity to originals decays sharply with depth: cosine sim 0.85 (conv1) → 0.60 (conv2) → **0.34** (conv3). Yet accuracy barely drops. Direct evidence that *approximating the original kernels is the wrong objective; approximating the network loss is right.*
- Honest limitation: conv1 (11×11, 3 input channels) resists compression; separable-filter decomposition of the bases was tried and failed ("bases showed too much variation").

---

## 3. Zhang, Zou, He, Sun — *Accelerating Very Deep Convolutional Networks for Classification and Detection* (arXiv 1505.06798v2, 2015)

**Problem framing.** Prior acceleration work decomposes *one or two* layers and reports results on shallow nets or single AlexNet layers. Nobody has accelerated a *whole very deep model* (≥10 layers) on ImageNet. Two failure modes identified: (a) SGD-based data-reconstruction solvers are fragile on ImageNet-scale models, (b) approximation error **accumulates rapidly** across layers.

**Method component 1 — low-rank response reconstruction.**
- Assumption: filter *responses* y (not weights) lie on a low-rank subspace. Justified empirically: in Conv2 (d=256), the first 128 eigenvectors carry >99.9% energy; Conv7 (d=512), first 256 carry >95%.
- Key argument: responses y = Wx are lower-rank than either W or x alone, because *both* the weights and the local input volumes are correlated. Prior work assumed low-rank weights only.
- Decomposition: y = PW′x + b, replacing a (k×k, d) layer with a (k×k, d′) layer plus a **1×1×d′ → d** layer. Complexity O(dk²c) → O(d′k²c) + O(dd′).

**Method component 2 — nonlinear (ReLU-aware) solution.** This is the paper's signature idea.
- Objective: `min Σ‖r(y_i) − r(My_i + b)‖²` s.t. rank(M) ≤ d′, with r = ReLU.
- Solved by relaxation with auxiliary variables z and penalty λ, alternating between:
  - **(M,b) subproblem** = Reduced Rank Regression, solved in closed form by **GSVD** (Generalized SVD) — *no SGD needed*.
  - **{z} subproblem** = independent 1-D problems with a closed-form two-candidate solution (z₀ = min(0,y′), z₁ = max(0,(λy′+r(y))/(λ+1))).
- λ warm-started at 0.01 for 25 iterations, raised to 1 for 25 more. Notes that pushing λ→∞ theoretically converges to the exact problem, but in practice large λ stalls the solver.
- **Only 3,000 sampled images needed; 2–5 minutes per layer in MATLAB.** Contrast with SGD solvers.
- Justification for why nonlinearity matters: measured ReLU sparsity is >60% for Conv2–7 and **95% for Conv7** — so ReLU is truncating most activations, and a linear objective optimizes the wrong thing.

**Method component 3 — asymmetric reconstruction (the accumulated-error fix).**
`min Σ‖r(Wx_i) − r(MWx̂_i + b)‖²` — the **target** uses the exact input x, the **prediction** uses the already-degraded input x̂ from previous approximated layers. So each layer is asked to compensate for upstream error rather than to faithfully replicate its own I/O.
- Reported gain: at 4× speedup on 3 layers, asymmetric beats symmetric by >1.0% top-5.
- Also tried a symmetric variant using x̂ on both sides — reported as *worse still*.

**Method component 4 — whole-model rank selection.** Observes empirically that accuracy is roughly **linear in PCA energy**, and assumes whole-model accuracy relates to the *product* of per-layer PCA energies. Maximize `E = Π_l Σ_{a≤d′_l} σ_{l,a}` subject to `Σ_l (d′_l/d_l)·C_l ≤ C`. Solved greedily: repeatedly drop the eigenvalue with the smallest ΔE/E ÷ ΔC ratio.
- Rank selection matters *far more for VGG-16 than for SPP-10*, because VGG-16 spreads 3×3 filters over five feature-map sizes (224/112/56/28/14) whereas SPP-10 repeats them on one size. At 4×, rank selection cuts the error increase from 6.38% → **3.84%**.
- The selected ranks are interpretable: Conv51–53 keep far more filters (232/224/214 vs 104 elsewhere at 4×) because their time complexity is low, so compressing them is a bad trade.

**Method component 5 — 3-D (combined) decomposition.** Composes their channel decomposition with Jaderberg's spatial k×1/1×k separation, splitting a layer into (k×1,d″), (1×k,d′), (1×1,d), each contributing √r of the speedup. The asymmetric solver absorbs the spatial method's error too.

**Results.**
| Model | Speedup | Method | Δ top-5 (1-view) |
|---|---|---|---|
| VGG-16 | 3× | asym 3d + FT | **0.0%** |
| VGG-16 | 4× | asym 3d + FT | **0.3%** |
| VGG-16 | 5× | asym 3d + FT | 1.0% |
| VGG-16 | 4× | Jaderberg (their impl.) | 9.7% |
| VGG-16 | 3× / 4× / 5× | asym 3d, **no FT** | 0.4 / 0.9 / 2.0% |
| SPP-10 | 4× | asym 3d + FT | 1.3% |

- Actual vs theoretical speedup: CPU 3.8× actual for 4× theoretical (very close); GPU only 2.3–3.0× — attributed to generic Caffe kernels not being optimized for 1×1, 1×3, 3×1 convolutions.
- Detection (Fast R-CNN, VOC2007): baseline 66.9 mAP → 66.9 at 3×, **66.1 at 4×**, 65.2 at 5×.
- Beats Figurnov et al.'s whole-VGG-16 results substantially (they report +3.4%/+7.1% error at 3×/4× *after* fine-tuning).

**Most interesting single finding.** Training the *same decomposed architecture from scratch* gives 16.9% top-5 vs **14.1%** for their accelerated model (SPP-10, 4×) — a 2.8% gap. Conclusion stated explicitly: "a very deep model can be accelerated **not simply because the decomposed architecture is more powerful, but because the acceleration optimization algorithm is able to digest information**." (Note: this directly contradicts a claim reported in survey #10 — see Part 3.)

**Fine-tuning honesty.** Fine-tuning is "very sensitive to initialization and learning rate": too small a rate and it stalls in a poor optimum, too large and it behaves like training from scratch and "the initialization appears to be forgotten." They use lr=1e-5, batch 128, 5 epochs.

---

## 4. Krishnamoorthi (Google) — *Quantizing Deep Convolutional Networks for Efficient Inference: A Whitepaper* (arXiv 1806.08342, 2018)

**Nature.** Not a novel-method paper — a systematic, experiment-backed *design guide*, and the most complete quantization reference in the set. Announces the TensorFlow/TFLite `tf.contrib.quantize` tooling.

**Quantizer taxonomy.**
- **Uniform affine:** scale Δ and integer zero-point z; `x_int = round(x/Δ)+z`, clamped to [0, N−1]. Zero-point being an integer guarantees **zero is represented exactly** — critical so that zero-padding introduces no error. One-sided ranges are relaxed to include zero (e.g. (2.1,3.5)→(0,3.5)), at some precision cost.
- **Uniform symmetric:** z = 0. Simpler; for SIMD they further restrict to [−(N/2−1), N/2−1].
- **Stochastic:** additive uniform noise then rounding. Analyzed but rejected for inference.
- Explicit accounting of the affine quantizer's **cost**: the cross terms in the convolution expansion mean naive handling costs 2–4× throughput; the constant term and the fact that the activation sum is shared across same-size kernels can recover most of it, but only with hand-optimized kernels.

**Granularity — the paper's central practical finding.** Per-layer vs **per-channel** (per output kernel) quantization of weights. Per-channel is *not* considered for activations because it would complicate the inner product.

**Post-training quantization results (Table 2/3).** The Mobilenet numbers are dramatic:
| Network | Asym, per-layer | Sym, per-channel | Asym, per-channel | FP32 |
|---|---|---|---|---|
| Mobilenet-v1 1 224 | **0.001** | 0.591 | 0.703 | 0.709 |
| Mobilenet-v2 1 224 | **0.001** | 0.698 | 0.697 | 0.719 |
| Inception-v3 | 0.78 | 0.78 | 0.78 | 0.78 |
| Resnet-v1 50 | 0.75 | 0.751 | 0.751 | 0.752 |

Per-layer weight quantization **destroys** Mobilenets (accuracy → random) while leaving Resnet/Inception untouched.

**Root cause diagnosis (Appendix A).** Batch-norm **folding** multiplies each output kernel by γ/σ, and γ/σ varies enormously across kernels in a layer. Folding therefore creates long-tailed weight distributions with extreme outliers, and a single per-layer scale cannot span them. Per-channel quantization sidesteps this **by construction** — its accuracy is independent of the BN scaling. Quantified with an SQNR metric: `SQNR = 10log₁₀(ΣW² / Σ(W − SimQuant(W))²)`, plotted per output feature map.

**Other post-training observations.**
1. Activations quantize to 8 bits with **almost no loss** — because dynamic ranges are already small, thanks to (a) BN without scaling (Inception-v3) and (b) **ReLU6** clipping to (0,6) (Mobilenet-v1).
2. "**Almost all the accuracy loss due to quantization is due to weight quantization.**"
3. Larger-parameter networks (Resnet, Inception) are more robust than Mobilenets.
4. Activation ranges: min/max moving average over batches; ~100 mini-batches suffice for convergence. TensorRT's KL-divergence method is mentioned but not adopted.

**Quantization-aware training (QAT).**
- Simulated quantize→dequantize nodes inserted in the graph; backward pass uses the **straight-through estimator** with the gradient masked to the in-range region: `δ_out = δ_in · I_{x∈[x_min,x_max]}`.
- Master weights kept in float and updated with gradients (so small updates don't underflow), then re-quantized each step.
- QAT **closes the gap between symmetric and asymmetric**, and makes even per-layer schemes viable at 8 bits (Mobilenet-v1: 0.001 → 0.70).

**Batch-norm handling (the most technically intricate part).** Three-stage recipe:
1. Always scale weights by a **correction factor c = σ_B/σ** to long-term statistics before quantization, so quantized weights don't jitter batch-to-batch: `w_corrected = c·γW/σ_B`.
2. During early training, undo the scaling on the output (`y_corrected = y/c`) so behavior matches ordinary batch norm.
3. After `freeze_bn_delay` steps (200k–400k in their figures), **switch to frozen long-term moving averages** with a bias correction `γ(μ_B/σ_B − μ/σ)`.
- Comparison figures show: naive folding → heavy eval-accuracy jitter; batch renormalization → less jitter but not eliminated; moving-average weights → reduced but not eliminated; **correction + freezing → best accuracy, minimal jitter.**

**Low-precision (4-bit) results.**
- At 4-bit weights, per-channel is **decisively** better than per-layer post-training (e.g. Resnet-v1-50: 0.002 → 0.54), and fine-tuning adds a lot more (→ 0.732).
- **Weights quantize better than activations.** Hypothesis given: activation quantization "introduces random errors as the activation patterns vary from image to image, while weight quantization is deterministic," letting the network learn to compensate for the deterministic distortion.

**Training best practices (each backed by a figure).**
1. Stochastic quantization **underperforms** deterministic — because inference is deterministic, creating a train/test mismatch.
2. Fine-tuning from a float checkpoint > training quantized from scratch.
3. BN matching (above).
4. **Use EMA of weights with caution** — quantized training drives float weights toward decision boundaries, so tiny differences between instantaneous and averaged weights cause large quantized-weight differences.

**Architecture recommendations.**
- **Do not constrain activation ranges** — plain ReLU beats ReLU6 for quantized accuracy; let training find the range. (Note this is in mild tension with observation #2 above, where ReLU6 is credited for making activations easy to quantize — the paper resolves it in favor of learned ranges.)
- **Width ↔ precision is a tradeable axis**: 4-bit per-channel weights with a wider depth multiplier gives a further ~25% model-size reduction at the same accuracy as 8-bit.

**Measured runtime (Pixel 2, one large core, ms).** Mobilenet-v1: 155 float → 68 fixed CPU → **16 on Qualcomm HVX DSP**. Inception-v3: 1391 → 536. Resnet-v2-152: 4885 → 3240. So 2–3× on CPU, ~10× on the DSP.

**Hardware recommendations (explicit ask to accelerator designers).** Aggressive operator fusion; compressed memory access / on-the-fly weight decompression; support for **4, 8 and 16-bit** arithmetic (16 needed for regression tasks like super-resolution/HDR); per-layer bitwidth selection; and **per-channel quantization support is called "critical."**

---

## 5. Parashar et al. (NVIDIA/MIT/Berkeley/Stanford) — *SCNN: An Accelerator for Compressed-sparse CNNs* (ISCA 2017)

**Problem framing.** Two independent sparsity sources: pruning gives 20–80% zero weights; ReLU gives 50–70% zero activations. Together these can cut work by >10×. Prior accelerators exploit one or the other, and mostly only *gate* multipliers (saving energy but not cycles) or keep data uncompressed in on-chip buffers.

**Positioning table (Table 2) — the clearest taxonomy of sparse accelerators in the set:**
| Architecture | Gate MACC | Skip MACC | Skip buffer/DRAM | Inner spatial dataflow |
|---|---|---|---|---|
| Eyeriss | A | – | A | Row Stationary |
| Cnvlutin | A | A | A | Vector Scalar + Reduction |
| Cambricon-X | W | W | W | Dot Product |
| **SCNN** | **A+W** | **A+W** | **A+W** | **Cartesian Product** |

**Core method — the PT-IS-CP-sparse dataflow.** ("PlanarTiled-InputStationary-CartesianProduct-sparse")
- **IS (input stationary, temporal):** an input activation is held at the compute unit while multiplied by all K×R×S weights that consume it. Amortizes access to the large (energy-expensive) input buffer. Loop nest becomes `K/Kc → C → W → H → Kc → R → S`.
- **CP (Cartesian product, intra-PE spatial):** a vector of F weights × vector of I activations feeds an F×I multiplier array computing the **full cross product**. Two properties: every fetched value is reused across the whole other vector (wire multicast), and **every product is useful** — no extraneous computation. This is precisely what makes it work on *compressed* data: any non-zero weight times any non-zero activation is a valid partial sum.
- **PT (planar tiling, inter-PE):** the W×H activation plane is split into Wt×Ht tiles across PEs, each extending fully through C. Cross-tile dependencies at edges ("data halos") resolved via **output halos** (oversized accumulation buffers, partial sums exchanged with neighbors at output-channel-group boundaries). Input halos were the alternative; efficiency difference stated as minimal.

**The hard part, honestly stated.** Because operands come from compressed streams, output coordinates come from decoded indices, not loop counters — so the F×I products land at **discontiguous** addresses. Solution: replace the monolithic accumulation buffer with **A distributed accumulator banks behind a scatter crossbar**, with A = 2×F×I to keep bank conflicts low. Also: the accumulator buffer must stay **uncompressed**, because output activations are probabilistically dense until they pass through ReLU.

**Compression format.** Data vector + index vector holding the count of non-zeros followed by the run of zeros before each value. 4 bits per index (up to 15 zeros between non-zeros; longer runs get a zero placeholder). Weights compressed at Kc×R×S granularity (3-D volume linearized so compression spans dimension transitions), activations at Wt×Ht×C.

**Configuration.** 8×8 PEs, 4×4 multipliers/PE = **1024 multipliers**, 16-bit multiply / 24-bit accumulate, 32 accumulator banks × 32 entries, 10 KB IARAM + 10 KB OARAM per PE (1 MB total data + 0.2 MB indices), 50-entry weight FIFO. ~1 GHz in TSMC 16nm FinFET → **2 Tera-ops**.

**Area breakdown (Table 4) — an important result in itself.** Total PE 0.123 mm²; accelerator 7.9 mm².
- Memories (IARAM+OARAM+accumulators) = **57%** of PE area.
- Multiplier array = only **6%** (0.008 mm²).
- Scatter crossbar (16×32) = 0.026 mm² — **3× the multiplier array's area.**
This is the concrete cost of sparsity: SCNN is 7.9 mm² vs DCNN's 5.9 mm² despite having *half* the activation SRAM.

**Results.**
- Speedup vs dense DCNN: AlexNet **2.37×**, GoogLeNet **2.19×**, VGGNet **3.52×** → 2.7× average.
- Energy: DCNN-opt 2.0× better than DCNN; SCNN **2.3×** better. Per-layer range 0.89×–4.7× vs DCNN.
- Density sweep (synthetic GoogLeNet): at 1.0/1.0 density SCNN reaches only **79%** of DCNN performance and consumes **33% more energy** (overhead of sparse bookkeeping). Crossover points: performance at ~0.85/0.85, energy vs DCNN at ~0.83/0.83, energy vs DCNN-opt at ~0.6/0.6. At 0.1/0.1 → 24× speedup and 6% of DCNN's energy.

**Two named inefficiencies (good engineering honesty).**
1. **Intra-PE fragmentation:** in late GoogLeNet inception modules, 1×1 sub-layers with Kc=8 yield at most 8 non-zero weights per output-channel group → average multiplier utilization **<20%**.
2. **Inter-PE load imbalance:** PEs synchronize at output-channel-group boundaries; early finishers idle.
- PE-granularity study: 64 PEs (16 mult each) beats 4 PEs (256 mult each) by 11% — math utilization 59% vs 35%. Conclusion: **intra-PE fragmentation is more critical than inter-PE barriers.**

**Ablation (Table 6 / Fig. 12).** SCNN-SparseA (≈Cnvlutin) vs SCNN-SparseW (≈Cambricon-X) vs SCNN. At 0.4/0.4 nominal density, SCNN is 1.7×/2.6× faster and 1.6×/2.1× more energy-efficient than SparseW/SparseA respectively. Interesting inversion: at high density SparseA is *better* (weight bookkeeping removed; IARAM is <1% of energy thanks to input-stationary filtering, while the weight FIFO is 6.7%), but below 0.8/0.8 SparseW takes over.

**Acknowledged weakness.** Fully-connected layers: no weight reuse across activations, so the Cartesian product misaligns — a 4×4 array runs at **25% of peak** (4 useful products/cycle). Mitigating arguments: FC is 8%/1%/2% of multiplies in AlexNet/GoogLeNet/VGGNet, FC is memory-bandwidth-bound anyway, and recent nets drop FC entirely. Suggested system answer: pair SCNN with **EIE** for FC layers.

**Temporal tiling.** 9 of 72 layers (all VGGNet) don't fit on-chip; DRAM traffic pipelines behind compute; performance degrades only below ~4 GB/s (nominal 50 GB/s). Per-layer energy penalty 5–62%, mean 18%.

**Methodology note.** Two-tool approach: a cycle-level simulator driven by *real* pruned weights and sparse activation maps from pycaffe (so load imbalance is captured faithfully), plus **TimeLoop**, an analytical model for design-space exploration, calibrated against synthesizable SystemC → Catapult HLS → Design Compiler area/energy numbers.

---

## 6. Li, Jia, Feng, Wang — *LoWino: Towards Efficient Low-Precision Winograd Convolutions on Modern CPUs* (ICPP 2021)

**Problem framing — the key insight of the paper.** "Winograd convolution and quantization are **not orthogonal optimization methods that can be simply combined together**." Directly contradicts Lavin's framing. Reason: the Winograd input transform *amplifies the value range* — by 4× for F(2×2,3×3) and by **~100×** for F(4×4,3×3), read off the coefficients of Bᵀ. Applying INT8 before the transform therefore overflows.

**Survey of the two existing industrial workarounds (Fig. 2), both shown to be bad:**
- **Up-casting** (ncnn): promote transformed matrices INT8→INT16. No overflow, but the multiply stage now runs at INT16 — **throws away the speedup that motivated quantization**.
- **Down-scaling** (oneDNN): multiply the transformed matrix by α (1/4 for m=2, 1/100 for m=4, **1/10000 for m=6**) and round. Round-off destroys precision, and the factor collapses as tile size grows. This is *why vendor libraries only ship one small tile size for INT8 Winograd*.

**Their method — quantize inside the Winograd domain.**
`y_k = Aᵀ[ Q′( Σ_c Q(Gg_{k,c}Gᵀ) ⊙̃ Q(Bᵀd_c B) ) ]A`
Inputs and filters stay FP32; the *transformed* matrices are quantized. Because the range amplification has already happened, the full INT8 range [−128,127] is used, rather than a narrow sub-range as in down-scaling (illustrated with a log-scale histogram comparison, Fig. 9).
- Saturating linear quantizer `Q(X) = S_INT8(αX)`, α = (2^{b−1}−1)/τ.
- Threshold τ chosen by **KL-divergence calibration** on ~500 unlabeled images: `τ = argmin D_KL(P(X_FP32) ‖ P(Q_τ′(X_FP32)))`. Notes ‖X‖_∞ is usually not optimal. **No retraining required.**

**Implementation (targets Intel VNNI `vpdpbusd`).** The instruction takes A = 64×UINT8, B = 64×INT8, C = 16×INT32, doing 4-element dot products; theoretically 4× FP32 peak.

Optimizations, in order of interest:
1. **Compensation trick for the unsigned operand.** `vpdpbusd` requires the first operand unsigned, but transformed inputs can be negative. Fix: **add 128** to the transformed input (input-transform stage) and multiply the transformed filter by an auxiliary matrix of **−128** (filter-transform stage, which is *offline* for inference). Then `Z = V̂×U + Ẑ` with `V̂ = V+Δ`, `Ẑ = −Δ×U`. Both corrections land in memory-bound stages, so they cost almost nothing.
2. **Custom data layout** (Table 1) built around σ=16 (FP32 vector length) and φ=4 (INT8s per 32-bit word). Guarantees VNNI compatibility, 64-byte-aligned vector loads/stores, and cache/TLB locality.
3. **Codelet generator** for transforms: emits vectorized C++ from wincnn-generated matrices, with zero-multiply elimination, **common sub-expression elimination** across rows, constant folding, and φ-loop unrolling.
4. **Non-temporal stores** at the end of input transform and matmul, so scatter writes bypass cache (the data won't be reused soon). This converts the output stage's expensive *gather* into a cheap sequential read.
5. **Cache blocking + register blocking** for the tall-and-skinny batched GEMM (batch = T = (m+r−1)², V is N×C, U is C×K, with N ≫ C,K). Search space constrained by `rowblk×colblk + colblk < 31` (32 AVX-512 registers, one reserved for broadcast) and `Cblk×Kblk < 512²`.
6. **JIT code generation + auto-tuning** over {Nblk, Cblk, Kblk, rowblk, colblk}, results cached in a "wisdom file." Justified because layer configs are known ahead of time.
7. **Static scheduling** for parallelism — tasks pre-assigned at compile time; since C, K, ω are typically powers of two, load balances naturally. Single fork-join.

**Design divergence from oneDNN, explained.** oneDNN caches all intermediate data on-chip, which forces small matrices (low compute-to-memory ratio) and worsens as tile size grows (F(4,3) has 2.25× the intermediates of F(2,3)). LoWino **writes all intermediates to main memory** so it can use large blocks. Consequence measured in Fig. 10: LoWino spends *more* time in transformation (it reads FP32 inputs, 4× the bytes of oneDNN's INT8 inputs) but wins in matmul whenever the layer is large (YOLOv3_c, U-Net_b) and ties when it isn't (VGG16_b, ResNet-50_c).

**Results.**
- 20 benchmark layers from AlexNet, VGG16, ResNet-50, GoogLeNet, YOLOv3, FusionNet, U-Net.
- vs best oneDNN INT8: **up to 2.04×, average 1.26×**. vs best oneDNN FP32: 1.9× (F(2,3)) and 2.6× (F(4,3)).
- Accuracy (ImageNet top-1):

| Model | FP32 | oneDNN F(2,3) | **LoWino F(2,3)** | Down-scaling F(4,3) | **LoWino F(4,3)** |
|---|---|---|---|---|---|
| VGG16 | 71.59 | 70.98 | **71.33** | **00.00** | 69.20 |
| ResNet-50 | 76.13 | 75.91 | **76.09** | **00.00** | 75.53 |

The `00.00` entries are the headline: the down-scaling approach at F(4×4,3×3) produces a network at *random* accuracy. LoWino is the first to make large-tile INT8 Winograd usable at all.

**Honest negative result.** Winograd does **not** always beat direct convolution even at lower complexity — for ResNet-50_a, INT8 F(2,3) is slower than INT8 direct in *both* oneDNN's and their implementation, because transform memory overhead exceeds compute savings. For YOLOv3_a, direct even beats F(4,3).

---

## 7. Wang, Li, Jia, Feng, Wang — *Fast Convolution Meets Low Precision: Exploring Efficient Quantized Winograd Convolution on Modern CPUs* (ACM TACO, Jan 2024)

**Relationship to #6.** Explicitly labeled an extension of the ICPP'21 paper, with three stated additions: (1) systematic **numerical-error analysis**, (2) **fused as well as non-fused** implementations, (3) evaluation on **Intel 3rd-gen** Xeon Scalable in addition to 2nd-gen.

**Terminology upgrade.** The method is renamed from "quantization in the Winograd domain" to the **outside-quantization vs inside-quantization** dichotomy. This is a cleaner conceptual frame: existing methods quantize *outside* the Winograd domain (spatial domain), LoWino quantizes *inside*.

**New contribution 1 — quantitative error analysis (Section 5.3).** Ground truth = INT8 *direct* convolution; inputs ~N(0,1) quantized to INT8; filters from pretrained VGG16/ResNet-50.
- Metrics: mean absolute error `E_abs`, and relative Frobenius error `E_rel = ‖Y−Y*‖_F / ‖Y*‖_F`.

| Model | F(2×2,3×3) D-S | F(2×2,3×3) LoWino | F(4×4,3×3) D-S | F(4×4,3×3) LoWino |
|---|---|---|---|---|
| VGG16 E_abs | 1.525E-01 | **7.892E-02** | 1.929E+00 | **8.076E-01** |
| VGG16 E_rel | 1.664E-01 | **8.636E-02** | 2.314E+00 | **9.214E-01** |
| ResNet-50 E_abs | 8.147E-02 | **5.209E-02** | 1.147E+00 | **5.086E-01** |
| ResNet-50 E_rel | 1.391E-01 | **8.861E-02** | 2.158E+00 | **9.003E-01** |

- Swept across 7 (C,K) configurations × 5 spatial sizes: error reduced by up to **45.64%/47.44%** (E_abs/E_rel) at F(2,3) and up to **85.89%/86.84%** at F(4,3). The larger the tile, the larger the advantage — exactly the regime where down-scaling collapses.
- Also note that error jumps roughly an order of magnitude going from F(2,3) to F(4,3) *for both methods* — the Winograd instability is not eliminated, only made survivable.

**New contribution 2 — fused vs non-fused implementations.**
- **Non-fused:** each stage is a separate kernel writing everything to main memory, with a synchronization barrier between stages. Better for **large tiles**, because the matmul stage can see all tiles at once and pick large blocks.
- **Fused:** input transform + matmul + output transform for a subset of tiles fused into one kernel (subset controlled by Nblk/Kblk). Better for **small tiles** like F(2,3), where the working set fits in cache.
- Best implementation selected per convolution layer by a search on the target platform.
- Measured cache effect (Table 10): fused raises cache *references* (more data held) but cuts miss rate — F(2,3): 71.53% → 41.79% (**−29.74 pts**); F(4,3): 74.53% → 36.70% (**−37.83 pts**).
- Quantization/de-quantization overhead: non-fused 13.93%/18% (F(2,3)/F(4,3)); fused 8.23%/8%.
- Caveat given: with weaker instructions (e.g. SSE instead of VNNI), the compute fraction rises and the quantization fraction falls — the overhead figure is instruction-set dependent.

**Results (stronger than ICPP version).**
- Layer speedups vs best oneDNN: up to **2.74× / 2.90×** on the two platforms, **average 1.84× / 1.91×** (vs 1.26× average in the ICPP paper — the fused variant and platform update account for the improvement).
- End-to-end inference speedup vs oneDNN F(2,3) INT8: VGG16 1.34× (F(2,3)) → **2.04×** (F(4,3)); ResNet-50 1.05× → **1.11×**.
- **Model-structure effect explained:** VGG16 gains far more than ResNet-50 because a higher proportion of VGG16's layers are 3×3; ResNet-50's residual blocks mix 1×1 and 3×3. (A general lesson: fast-convolution gains are gated by the *fraction* of the network that is 3×3.)
- Accuracy table identical to #6.

**Discussion section observations.**
- Explicitly notes that non-linear quantization, hybrid block floating point, flexible floating point, and **FP8** are unexplored alternatives.
- The inside-quantization methodology is claimed **hardware-independent** (CPU-with-VNNI is just the vehicle); GPU/NPU left as future work.
- Related work note of interest: Andri et al. (MICRO 2022) do **tap-wise quantization** for integer-only Winograd on custom accelerators; Liu et al. accelerate Winograd on GPU Tensor Cores in **FP16** — so the low-precision-Winograd problem is being attacked from several directions.

---

## 8. Yang, Wang, Wang, Geng — *A Stride-Based Convolution Decomposition Method to Stretch CNN Acceleration Algorithms* (IEEE TCAS-I, Sept 2020)

**Problem framing — three explicit hardware complaints about Winograd/FFT/FFA:**
1. **Area waste from heterogeneity.** Supporting N kernel sizes requires N distinct compute units (their example: an FFA accelerator with three unit types for 3/5/7). "When one of the three units is working, the other two units are left unused."
2. **Precision forces small parameters.** Table II shows Winograd transform element ranges: at tile 4 the elements are just {1, 1/2}; at tile 8 they span **1/720 to 49**. Under INT8/INT16 fixed point, large-tile transforms are unquantizable. So designers pick small units — and then can't handle large kernels.
3. **Stride ≠ 1 is essentially unsupported.** All three fast algorithms assume stride 1; large-stride convolution is "a major restriction to hardware flexibility," and the authors state they know of little prior work on it.

**Method 1 — SCDM (Stride-based Convolution Decomposition Method).** Reform *any* (kernel size r, stride s) into a fixed F(m,n) pattern:
- If r ≤ n: zero-pad kernel and input tile to n×n / m×m.
- If r > n: decompose the kernel into blocks, **gathering elements at s-step distance in both directions** (the "jumping mechanism"), zero-pad each block, and run each (kernel block, corresponding input block) pair through the same unit; sum the results.
- Worked examples: 5×5/s=1 → one 3×3 + two 2×3 + one 2×2 blocks (F(4,3)); 5×5/s=2 → same block shapes but gathered at 2-step stride; 5×5/s=3 → nine blocks; F(4,2)/s=2 → nine blocks.
- **s determines *which* elements are gathered; r and s together determine *how many* blocks.** The jumping mechanism produces the smallest possible blocks, minimizing redundant zero-pad computation.
- Offline vs online decomposition trade-off analyzed: offline needs no control logic but overlapping input regions cost extra off-chip accesses and storage; online needs address-generation logic but no extra storage and overlapping regions **hit in on-chip buffers**. Argues online decomposition *simplifies* PE interconnect relative to reconfigurable GEMM accelerators (Eyeriss, Thinker) because after decomposition all work has an identical shape.

**Method 2 — AEM (Area Efficiency Model).** `AE = Perf/Area = [OPs/(T_mem+T_comp)] / (A_dot + A_trans)`, with
`T_comp = (C₁C₂/P_in P_f)·N_slide²`, `N_slide = ⌈(W−(r−1))/(m−r+1)⌉`, and
`Area = m²·U_mult + [2m²(m−1) + 2mn(m+n−2)]·U_add`.
The key structural fact: performance improves ~linearly in (m−r+1) but **area grows as a square/cubic function of m and n** → area efficiency degrades rapidly with unit size. Three converging reasons to pick small units: (a) area efficiency, (b) precision — only n≤3, m≤4 gives transform matrices of {0, ±1, ±1/2}, so multiplies become **shifts**, (c) power scales with m,n through pre-computation logic. Chooses **F(4,3) and F(4,2)**; notes F(3,2) would be too small to give useful reduction.

**Method 3 — MCM (Multiplication Consumption Model).**
`Mult_conventional = r²(m−n+1)²`
`Mult_SCDM = s²m² if s·n > r ; ⌈r/n⌉²m² if r ≥ s·n`
From equating these, crossover thresholds are derived analytically: SCDM beats GEMM when **r > 2s for F(4,3)** and **r > 4s/3 for F(4,2)**.
Empirical rule found by sweeping r,s from 1 to >100:
- F(4,2) ≥ F(4,3) when 3s > r > 4s/3
- **F(4,3) > F(4,2) when r ≥ 3s and r = 6k+3** (k natural)
- F(4,2) > F(4,3) when r ≥ 3s and r ≠ 6k+3
The saving-rate curve is *serrated*, spiking at r=9, 15 for s=3 — matching the 6k+3 rule.

**Method 4 — WHD (the fused unit).** Fuse F(4,3) and F(4,2) into one datapath:
- The **input transform matrix B is identical** for both → one shared input-transform module, no select signal needed.
- Filter and output transforms share most operators; a single `sel` bit switches between them.
- Both do their dot product on a **4×4** shape → they fully share one 4×4 PE array of plain multipliers.
- `sel` is set by the MCM rule: sel=1 (F(4,3)) when r ≥ 3s and r = 6k+3, else sel=0.
- Modules: filter transform = 7 `Tunitf` (each 3 ADD, 2 SHIFT, 1 INV, 2 MUX2); input transform = 8 `Tuniti` (2 INV, 4 ADD each); output transform = 7 `Tunito` (1 INV, 5 ADD, 1 MUX2 each).
- Total unit cost: **30 INV, 97 ADD, 16 MULT, 14 SHIFT, 21 MUX2** — and SHIFT is free (hardwired bit selection).

**Results.**
- Operation reduction across six models: **VGG16 55.41%** (best — a single conv shape, 3×3/s=1, perfectly matching F(4,3)), YOLOv1 and DarkNet19 >50%, GoogleNet 40.61%, **ResNet50 34.08%** (worst — dominated by 1×1 kernels which suffer excessive zero padding). AlexNet in between.
- Fusing gain: averaged over s+1≤r≤11, s∈{1,2}, WHD improves multiplication reduction by **18.7% over F(4,3) alone and 9.0% over F(4,2) alone**. At the single most common shape (3×3/s=1) it saves **43.8%** more than F(4,2) alone.
- vs other fast algorithms at 3×3/s=1: WHD **55.6%** reduction vs FFA 33% vs FFT 39%. One honest exception: at 5×5/s=1 WHD loses to both (its small units force zero-padding, while 8-point FFT fits that shape naturally). But 8-point FFT cannot handle 5×5/s=2 at all ((r+s−1) > 7).
- Transform complexity comparison (Table IX): Winograd F(4,·) elements {±1, 0, ±0.5}; 8-point FFT {±1, 0, ±0.7071}; 16-point FFT adds {±0.9239, ±0.3827} — and FFT pre-computation still needs real multiplies.
- Synthesis (Xilinx XC7Z100, 200 MHz, INT8 in / INT16 out, multipliers in LUTs not DSPs) vs a GEMM unit of equal throughput (36 multipliers): **−28.8% LUT, −44.4% FF, −21.6% power.**
- Flexibility table: WHD = any kernel, any stride; FFA work = stride 1, kernels 3/5/7; FFT work = stride 1, kernels 1–8.
- Failure mode disclosed: when s approaches r (e.g. (r,s) = (3,2), (4,3), (5,4)) the saving rate is poor, even **−14%** at (5,4). Defended on the grounds that such shapes lose receptive field and don't appear in real models.

**Best single line in the paper.** "It is worth mentioning that these multiplications are **indeed eliminated** in the hardware implementation and don't occupy computation time... In contrast, in some previous architectures the multiplication operations are saved, however, the multipliers **still exist in PE and are merely inactive.**" — a precise distinction between *arithmetic* savings and *realized* savings that most papers in this set blur.

---

## 9. Abtahi, Shea, Kulkarni, Mohsenin — *Accelerating CNN With FFT on Embedded Hardware* (IEEE TVLSI, Sept 2018)

**Framing.** Convolution is ~90% of AlexNet's computation (Fig. 1). FFT convolution is well studied on GPUs but under-studied on **embedded** hardware where cache is scarce — and plain FFT-Conv's intermediate memory blow-up is exactly the wrong property for such devices.

**Three methods compared head-to-head.**
| Method | Formula | Complexity | Memory |
|---|---|---|---|
| Direct-Conv | sliding-window MAC | **O(N²K²)** | N² + K² |
| FFT-Conv | `F⁻¹{F(d)·F(f)}`, (N+K−1)-point | **O(N² log N)** | **2N²** (filter must be padded up to data size) |
| FFT-OVA-Conv | `Σ_k F⁻¹{F(d(n−kL))·F(f)}` | **O(N² log K)** | ≈ Direct-Conv |

The overlap-and-add idea: segment the data into chunks *the size of the filter*, FFT each, and align-and-add the block outputs. Since all FFT inputs are the same small dimension, **no intermediate memory blow-up occurs** — which is precisely the constraint that makes plain FFT-Conv unattractive on embedded parts.

**Analytical comparison (Fig. 5).** For AlexNet and ResNet-20: FFT-OVA-Conv cuts computation **7× and 10× vs Direct-Conv**, and **2.8× and 2.5× vs FFT-Conv**. Memory access: both FFT variants ~3× better than Direct; FFT-Conv needs 2× the intermediate storage of the other two. Worked example given (3×3 kernel over 9×9 input): Direct = 17 ops × 49 positions; OVA = 7 ops × 9 segments + FFT/IFFT overhead.

**Network choice reasoning.** Table I compares AlexNet/VGG-B/GoogLeNet/VGG-D/Inception-V3/ResNet-20 on CV params, FC params, and error. Trend noted: modern nets have many conv layers and one FC layer (Inception-V3: 77 CV, 1 FC) vs older ones (AlexNet: 5 CV, 3 FC). ResNet-20 chosen for **0.27M conv parameters at 8.75% error** — 1.7× better error than AlexNet at a tiny parameter budget.

**Four platforms — the real contribution is the cross-platform sweep.**
1. **PENC many-core** (their own, 65nm CMOS, 192 cores in clusters of 3 + shared memory + router). Notable: has a **built-in 8- and 16-point FFT instruction** that supplies radix-2 FFT addresses from a hardware block. 16-bit datapath, 128 instructions, 128 data memory, 16 registers, 32-entry CAM for inter-core messaging. Evaluated with a cycle-accurate simulator whose numbers come from Cadence SoC Encounter post-layout + activity-factor-driven power analysis; host = Intel Atom/Edison, power measured with an INA219.
2. **ARM Cortex-A53** (Raspberry Pi 3B, 1.2 GHz), GNU Octave implementation, board-level current via TI INA219 + Arduino.
3. **NVIDIA Jetson TX1** (256-core Maxwell), Torch7 + CUDA 7/8 + cuFFT/cuBLAS/cuDNN v4–5.1, half-float tensors, cuDNN in fastest mode to enable FFT, **batch size 1** for consistency.
4. **SPARCNet on Zynq 7020 FPGA** — their prior HLS+Verilog accelerator; parallelizes across output channels; each PE has scratchpad for its filter and partial output; 16-bit floating point; **fuses conv + batch-norm + ReLU into one operation**; supports filter/input-channel bit-vector masks for sparsity.

**Results per platform.**
- **PENC:** FFT-OVA-Conv is **2.9× / 1.65×** faster than Direct/FFT-Conv, with **6.8× / 2.5×** better throughput-per-watt and 6× / 2.9× better EDP. Three parallelism levels tried: semi-serial (15 cores/layer), semi-parallel (22), most-parallel (37 ≈ number of filters). Best absolute: **12.4 ms, 60.5 MB/s per-layer throughput, 3.38 W.**
  - *Instructive failure:* cluster memory is only 6 KB, so the last five ResNet-20 layers under FFT-Conv must borrow memory from adjacent clusters. **Inter-cluster latency is ~2× intra-cluster**, so those layers are the *slowest* under FFT-Conv, and FFT-Conv's power is 1.4× higher due to extra router + storage-cluster power. A concrete demonstration that FFT-Conv's memory expansion is the binding constraint on embedded parts.
  - FFT-OVA used only 8-point FFTs (data segmented into 3×3 blocks); FFT-Conv used 16-point where data ≥16.
- **ARM A53:** FFT-OVA-Conv gives **3.36× / 1.38×** execution-time improvement and 2.72× / 1.32× throughput vs Direct/FFT.
- **TX1 GPU:** FFT-Conv is **1.9× faster, 2.2× more energy-efficient, 5.6× better per-layer throughput** than Direct. **FFT-OVA was not beneficial here** — with <6 KB per max image, "the overhead associated with launching multiple concurrent FFTs and IFFTs outweighs the potential speed up." *The optimal convolution algorithm is platform-dependent.*
- **SPARCNet/Zynq:** Direct-Conv with 32 PEs → 220 ms, 443 mJ, 1.6 MB/s. FFT-Conv with 16 1-D FFT PEs → **42 ms, 135–137 mJ, 10.8 MB/s** — nearly **6×** faster. Note FFT-Conv could not be built with 32 PEs: **insufficient FPGA resources**. Also observed that FFT-Conv's per-layer time is *flat* across layers (constant-size zero-padded FFTs) whereas Direct-Conv shows the classic descending stair-step.

**Cross-platform ranking.** PENC is **10916× and 1.8×** faster than ARM A53 and TX1 GPU; **5053×, 4.3×, and 2.4×** more energy-efficient than ARM, TX1, and SPARCNet; 7.5× and 1.2× better per-layer throughput than ARM and TX1. (The 10916× vs ARM figure should be read with care — ARM baseline is a serial GNU Octave implementation, not an optimized library.)

**Comparison caveats disclosed.** No prior ResNet-20/CIFAR-10 implementation was found for direct comparison. Their TX1 result is 1.12× worse than a ResNet-200 pedestrian-detection result, attributed to their **batch size of 1** (kept for cross-platform consistency); larger batches would pipeline and reduce setup time.

---

## 10. Ghimire, Kil, Kim — *A Survey on Efficient CNNs and Hardware Acceleration* (MDPI Electronics 11(6):945, 2022)

**Structure.** Two axes: (1) design an efficient CNN *from* a base model (pruning, quantization, tensor decomposition, knowledge distillation) vs (2) *directly* design one (NAS); crossed with hardware from general-purpose through spatial architectures to PIM, ending in hardware/software co-design.

**Pruning.**
- Historical anchor: OBD/OBS (early 1990s) used the **Hessian** of the loss to rank weights.
- **Unstructured (weight/connection) pruning:** the classic train → prune-below-threshold → retrain loop; iterated. Refinements catalogued: frequency-domain pruning (converting spatial weights to frequency coefficients and pruning per band achieves higher compression); per-layer rather than global thresholds; **Gaussian mixture models** over per-layer weight distributions to pick which layers to prune; **energy-aware** pruning (optimize energy, not just compression ratio and accuracy); gradient-flow cutoff for end-to-end automatic per-layer sparsity without fine-tuning.
- The **lottery ticket hypothesis** noted as a counterpoint: dense randomly-initialized nets contain "winning ticket" subnetworks that train in isolation to comparable accuracy with the *same initial weights*.
- **Structural (filter/channel/layer) pruning:** three branches identified — (a) ranking filters by criteria (L1, L2, APoZ, feature-map **rank** as in HRank), (b) minimizing reconstruction error (ThiNet uses layer i+1's statistics to prune layer i; NISP minimizes error at the "Final Response Layer"), (c) finding *replaceable* rather than *unimportant* filters via similarity (geometric median, online filter clustering). Layer pruning is a third tier, claimed to cut inference time and runtime memory more than filter pruning at similar accuracy.
- Train-time structural pruning: network slimming (L1 on **batch-norm scaling factors**), and group-LASSO on BN layers to prune from scratch.
- Key trade-off stated: unstructured pruning gives large compression but **requires specialized hardware**; structural pruning keeps dense ops runnable on general hardware but loses whole filters, hurting accuracy.

**Quantization.** Distribution (uniform vs logarithmic/non-uniform), projection (deterministic vs stochastic), and timing (post-training vs quantization-aware). Notes 4-bit PTQ without fine-tuning exists; INT8 training of ResNet-50 with 1.5% loss; and generalization of bit precision beyond INT8 (DoReFa: AlexNet at 51% top-1 with **1-bit weights, 2-bit activations, 6-bit gradients**).
- **Binarization** treated separately: deterministic `sign(x)` vs stochastic with hard-sigmoid probability. Lineage: BinaryConnect (binarize weights in forward/backward but not the update) → **BNN** (also binarize activations — "the very first binary neural network") → **XNOR-Net** (adds a floating-point scaling factor α per binary weight, w ≈ α·b_w). Then optimization-based methods: loss-aware binarization and incremental network quantization minimize the *global* loss rather than local layer error; IR-Net uses a self-adaptive error-decay estimator and is "the first approach to consider information retention for both forward and backward propagation." MACs become **XNOR + popcount**.

**Tensor decomposition.**
- Low-rank matrix: SVD variants — simplified SVD on weight matrices, SVD on the weight×input product, **sparsity embedded in low-rank factors** (lower rank for unimportant neurons), channel-wise SVD splitting a w×h conv into w×h then 1×1 (i.e. exactly Zhang et al.'s structure, #3), "SVD training" that reaches low rank without running SVD every step, and joint decomposition of structurally identical layers.
- Tensorized: **CP** (sum of rank-1 tensors), **Tucker** (matrices + small core), **Tensor Train** (chain of 3-D tensors, good for high-order), **Tensor Ring** (linear combination of TTs). Stable hybrids exist (Tucker then CP on the core). Rank selection via progressive genetic algorithm noted.
- Blunt verdict in the Discussion: tensor decomposition's success is "currently limited to compression of **RNN** models" (TT gives up to 1000× parameter reduction for RNNs); CNN compression via TR gives only **5.8% compression for 1.9% accuracy loss**. The bottleneck is stated to be *training* decomposed CNN models.

**Knowledge distillation.** Three components: knowledge (logits / activations / intermediate features), distillation algorithm (**offline / online / self**), and teacher–student architecture. Catalogued: ensembles of teachers with data augmentation; distillation for *quantized* students; data-free distillation from synthesized responses; training on teacher checkpoints before convergence; KDCL (dynamic soft targets via ensembling for one-stage online training); layer-selectivity learning using inter-layer/inter-class Gram matrices to *choose* which intermediate layers to match; self-distillation with an auxiliary self-teacher, and distilling from the best-performing student of past epochs.

**Hardware — dataflow taxonomy (the most reusable table).** Four canonical dataflows with named exemplars:
| Dataflow | What stays in the PE register file | Exemplars |
|---|---|---|
| **Weight-stationary** | filter weights | TPU |
| **Input-stationary** | input activations | **SCNN** (#5) |
| **Output-stationary** | accumulating partial sums | Origami |
| **Row-stationary** | jointly maximizes weight + activation + psum reuse | **Eyeriss, Eyeriss-v2** |
Stated verdict: **row-stationary has the lowest energy consumption.** Also draws the temporal (CPU SIMD / GPU SIMT, ALUs with centralized control and no local memory) vs spatial (ASIC/FPGA PEs with local memory and control, connected in an NoC for direct message passing) distinction.

**Processing-in-memory.** DRAM-based **DrAcc** (in-DRAM bit ops for ternary-weight CNNs, 84 FPS at 2 W); ReRAM-based **PRIME** (256×256 array as either 4-bit multi-level-cell compute or 1-bit storage) and **PattPIM** (exploits *weight pattern repetition* for space compression and computation reuse); HMC-based **Neurocube** (3-D stacked DRAM, PE clusters access multiple vaults in parallel). Caveat given: fabricating large ReRAM arrays is still an open problem.

**Hardware/algorithm co-design.**
- Sparse: Cambricon-X (skip zero weights via stored indices) → Cambricon-S (fixes indexing overhead with cooperative HW/SW) → SCNN (both, but "results in massive write-back traffic and supports only the convolutional layer") → Eyeriss-v2 (row-stationary in the compressed domain) → SNAP (**associative index-matching search** to find matching non-zero pairs; supports general conv, pointwise conv, and FC; two-level partial-sum reduction).
- Quantized: **variable-bitwidth** (Stripes: bit-serial AND + shifted accumulation, fixed weight width, variable activation width; UNPU: inverse — 16-bit activations, 1–16-bit weights; BitFusion: dynamically fuses bit-level PEs to match each layer's bitwidth; BitBlade: replaces BitFusion's shift-add with bitwise summation) vs **fixed-bitwidth** (YodaNN). Binary/ternary FPGA work: FINN (all layers binarized), a Tiny-YOLO 3-bit implementation (first and last layers kept at 8-bit), and a reconfigurable BNN accelerator with layer-adaptive parallelism claiming 9.69× area-speed efficiency. Note that INT8 is also supported in commodity ARM (Cortex-A75, Mali-G76, NEON SIMD).
- **NAS-based co-design** as the frontier: MnasNet incorporates measured latency into the objective; Codesign-NAS searches for a **CNN–accelerator pair**; a (q,s) NAS searches quantization and scaling factors then MAC/PE combinations. Distinction drawn: hardware-*aware* NAS explores the model space against a *fixed* accelerator, while co-design NAS explores **both spaces simultaneously**.

**Applications survey.** NVIDIA CUDA ecosystem dominance (AMD RADEON noted as competitive in raw FLOPS/bandwidth but hampered by "lacking community, software, and tensor cores"); Google TPU (four generations, initially inference-only, later training too, but "a generalized structure... not optimized for resource-constrained contexts"); smartphone NPUs (Apple A-series, Huawei Kirin, Samsung Exynos); edge modules (Jetson TX1/TX2/Nano/Xavier, Edge TPU, ARM Ethos, CEVA NeuPro, Hailo); FPGA efforts (Intel Xeon+Arria pairing, Microsoft Brainwave on Stratix via Project Catapult).

**Explicit non-conclusion.** "There is **no golden rule** for selecting which compression algorithm and hardware architecture design will produce the best results... Choosing a suitable method strictly depends on the specific applications and requirements."

---

## 11. Li, Liang, Yang, Li — *An Efficient CNN Accelerator Design on FPGA Using the Layer-to-Layer Unified Input Winograd Architecture* (MDPI Electronics 14(6):1182, 2025)

**Position.** The most recent paper in the set; targets FPGA **training** (not just inference — it explicitly handles forward propagation, backward propagation, and weight-gradient stages).

**Architecture-selection reasoning (Table 2).** Compares four accelerator families before picking one:
| Type | MAC array | Strength | Weakness |
|---|---|---|---|
| GEMM-like | 1-D | high generality | intensive computation |
| Winograd-like | 2-D | efficient for small kernels | large kernels degrade it |
| Winograd-GEMM hybrid | 1-D or 2-D | dynamic mode selection | control logic adds critical-path delay |
| **Reconfigurable-Winograd** | 2-D systolic | HW/SW co-design, best resource utilization | transform reconfiguration needs extra timing control |

**Method — layer-to-layer unified 6×6 input DWM.** Builds on the Decomposable Winograd Method (DWM: decompose kernels >3×3 or stride >1 into ≤3×3 stride-1 kernels) and on IA-DWM (Input-Aligned DWM, which made DWM implementable on a unified unit). Criticism of IA-DWM: it uses 4×4 blocks, giving a **low multiplication saving ratio**.

Five-step pipeline: **Splitting → Transformation (to uniform 6×6) → Calculation (element-wise mult + channel sum) → Inverse Transformation → Aggregation.**
Constraint set: n_h = n_w = 6, n = m + r − 1, r ∈ [1,6]. Notably, 1×1 kernels become F(6×6, 6×6, 1×1) — a **special case that degenerates to element-wise matrix multiplication**, which is a neat way to keep 1×1 layers on the same hardware.

**Block-size analysis (a well-reasoned design decision).**
- Larger blocks → better multiplication saving ratio, but larger transform coefficients → precision/complexity cost. States **>8×8 loses too much precision** in hardware.
- Odd block sizes need static padding / dynamic overlapping / dynamic border removal → prefer even.
- Chooses 6×6: multiplications become **56.25%** of the 4×4 scheme's and additions **1.23×**. (Arithmetic check: a 6×6 tile with a 3×3 kernel yields 4×4 output with 36 mults; four 4×4 tiles yield the same 4×4 output with 4×16 = 64 mults; 36/64 = 56.25% ✓. Note their Table 3 normalizes the two rows inconsistently — the ratios in the text are correct, the table entries are not directly comparable.)
- 6×6 transform matrices contain 4, 5, 2, 8 — handled as shift combinations (5 = 2² + 1). The **G matrix** (with 1/4, 1/6, 1/24, 1/12) is judged too hard to maintain in fixed point, so it is **precomputed off-chip** — legitimate because weights are fixed at inference.

**Transform-unit optimization (the paper's most concrete algorithmic contribution).** Two problems identified with a naive Bᵀ·H·B:
1. It is **sequential** — Bᵀ·H must complete before ·B, so the addition delay can exceed the dot-product delay and become the bottleneck.
2. The transform involves **long chain additions**, capping clock frequency, with reusable common sub-expressions being recomputed.
Fix: define `N_m0 = −h₂ + h₄`, `N_m1 = −4h₂ + h₄`, `N_m2 = h₁ − h₃` and rewrite all six output rows in terms of them. Result: **192 → 156 additions per channel, an 18.75% reduction**, plus a shorter critical path. Implemented as three pipeline stages (Stage 1 data reuse, Stage 2 temporary storage, Stage 3 accumulation) built from five primitive blocks: Acc, Mad, Sub, Com, Mul. The right-hand transform is symmetric and reuses the same circuit.

**WPE array — column-indexed structure.** Instead of a conventional systolic array with bus cost `B_Trad = Q(Q+1)/2(Q+P_IN)`, PEs are laid out as c rows × m columns and the row index resets when moving to the next row, plus extra skip buses between some adjacent WPEs in different columns. With 64 WPEs this **reduces output bus ports by 34%**, cutting flip-flop power. Each PE holds P_IN MAC units plus multiplexers to reconfigure for different layer types.

**Memory subsystem — the "preprocessing shift network."** Because decomposed kernels of different sizes need different access patterns over the input feature map, a configuration table maps (starting address MS, working mode MD) per kernel shape. A **"Reuse Loader"** pre-buffer stores data on first read so subsequent accesses are served by shifting/aligning in the buffer rather than re-reading on-chip memory. Input buffer = 16 independent on-chip memory units, each entry covering 8 input channels, one row per 6×6 tile. Weight buffer = 32 units, each entry 8 input × 8 output channels, with distinct access modes for FP/BP/WG stages. An **Auxiliary Processing Unit** handles channel accumulation, max pooling, quantization, activation, and FC layers, with independent datapaths for parallel pipelining.

**Results (Xilinx XC7Z045, 150 MHz, 8-bit PINT).**
- Precision: 8-bit PINT gives **<0.4% accuracy degradation** on VGG16 and ResNet18 vs FP32.
- Throughput: ResNet-18 **683.26 GOPS** (90% average MAC utilization), VGG-16 **665.38 GOPS** (85%).
- Power efficiency: **74.51 / 72.84 GOPS/W**; DSP efficiency 0.87 / 0.85 GOPS/DSP.
- Resources: 114.7 K LUT, 272 BRAM, 786 DSP, ~9.1 W.
- Headline claims vs prior work: 7.68× throughput, **5.8× DSP efficiency**, 3.85× energy efficiency.

**Cross-comparison honesty (Table 4).** They report cases where they lose:
- A 2024 work reaches 711 GOPS at 430 MHz — **1.06× their throughput but at ~4× worse power efficiency** (18.91 vs 74.51 GOPS/W).
- A 2023 TPU-style GEMM design reaches **143.41 GOPS/W (1.91× better than theirs)** using far fewer resources — but at 7.68× lower throughput.
- A 2023 HW/SW co-design has 23% better DSP efficiency but 65% lower performance.
This makes the paper's real claim clear: not best-in-class on any single metric, but the **best balance** of throughput and power for edge deployment.

**Diagnosed low-utilization layers.** ResNet-18 conv1.1 has only **3 input channels**, so 6×6 tiling leaves MACs unmapped. Also, off-chip DRAM access (2.4 GB/s on Zynq-7000) dominates small conv layers and non-conv layers. And the pre-stored reuse mechanism, tuned to help big layers, actively *reduces* MAC utilization in some small ones — an explicit acknowledgement that the optimization is not uniformly beneficial.

---

## 12. Habib & Qureshi — *Optimization and Acceleration of Convolutional Neural Networks: A Survey* (JKSUCI 34, 2022)

**Scope.** Broader and less hardware-focused than #10. Three strategies for speed: **(1) SGD optimizer improvements, (2) fast convolution, (3) parallelism** — plus architectural history (LeNet 1998 → 2019) and component-level advances (convolution variants, pooling, activations).

**Fast-convolution family tree (the most complete algorithmic genealogy in the set).**
- **Cook–Toom:** Lagrange interpolation at L = N + M − 1 real points. "Forms the basic building block of the large convolution algorithms." Weakness: reduces multiplications but **exponentially increases additions**, and becomes inefficient as problem size grows; limited to special integers unless the L points are chosen carefully. Wang & Parhi generalized it to interpolate at only **L − 2 = N + M − 3** points; also note that VLSI implementations exploit 2^k number representation in a way software cannot.
- **Iterated Short Convolution (ISC)** (Cheng & Parhi 2004): decompose long convolutions into short ones via a mixed-radix / tensor-decomposition formulation in matrix form, design fast algorithms for the short ones, then iterate. Transformed into fast parallel FIR filters; efficiency depends on the choice of short-convolution algorithm; best for large FIR filters.
- **Winograd:** based on the Chinese Remainder Theorem over an integer ring. Stated CRT premise: "It's possible to uniquely determine a non-negative integer given only its remainder with respect to given moduli, provided the moduli are relatively prime and the integer is smaller than the product of the moduli." Complements Strassen — Strassen suits large convolutions, Winograd small ones.
- **Strassen:** 7 multiplications instead of 8, at the cost of 18 additions; recursive version saves up to `1 − (7/8)^N`. Weakness: fails and degrades overall performance for *very* large matrices; reduces dynamic power but **increases signal and logic power** due to higher signal rate.
- **Strassen–Winograd hybrid** (Zhao et al. 2018): instead of recursively transforming input tiles with the kernel, uses two separate matrices U and V, cutting the additions the hybrid would otherwise incur. Saves **75% of computational cost** vs traditional algorithms; best for small matrices on multiplication reduction, but incurs more additions than Strassen alone; **Winograd alone outperforms the hybrid once the matrix is small enough.**
- **DWM** (Huang et al. 2020): decompose kernels >3×3 or stride >1 into ≤3×3 stride-1 kernels; **~2× speedup with no numerical accuracy degradation**; implemented as a plug-and-play operator in TensorFlow and PyTorch; sometimes beats cuDNN. (This is the direct ancestor of paper #11 and a sibling of #8's SCDM.)
- **Low-rank / tensor decomposition:** Jaderberg et al. exploit cross-channel and filter redundancy with rank-1 spatial bases — 4.5× speedup on scene-text character recognition with ~1% accuracy drop, architecture-independent, and reported **better than FFT**. Tai et al. train low-rank-constrained CNNs *from scratch*, cost O(d²NCXY) → **O(dK(N+C)XY)** ≈ d× acceleration, and find low-rank-constrained nets **outperform unconstrained ones** (NIN, 93.31% on CIFAR-10 without augmentation). Kossaifi et al. give a unified framework expressing convolution as a linear combination of rank-1 tensors, extending to ND convolutions.
- **Embedded-targeted Winograd** (Maji et al. 2019) on ARM Cortex-A: ~60% improvement over prior techniques.
- **Cheng & Parhi 2020:** 1-D and 2-D fast convolution independent of kernel size, with input/output feature maps of the same size; multiplication saving factor up to **3.24×** vs direct 2-D convolution; improves memory-access efficiency; applicable in software and hardware "in a plug and play fashion."

**Excellent, specific critique of Winograd on dilated convolutions.** Zero-padding a dilated filter inflates its effective size — a 3×3 kernel at dilation rate 2 needs a **6×6 tile to produce 2×2 output**. Winograd transforms the padded zeros into *non-zero* values in the Winograd domain, so those padded positions still consume element-wise multiplications. Consequence: "increase in tile size increases the number of element-wise multiplications needed for each tile," degrading Winograd for dilated convolution. Notes that **Intel and NVIDIA cuDNN fall back to GEMM for dilated convolutions.** A second criticism: implementations that use dedicated PEs for Winograd need *separate* PEs for CONV and FC, causing "critical under-utilization of resources" — the same complaint as #8's motivation.

**FPGA power comparison (from Zhao et al. 2019, Xilinx Kintex-7, Vivado 2014.3, 100 MHz).** All designs take about the same time for a similar matrix convolution; the differentiator is power: Strassen **−4%**, Winograd **−20.5%**, Strassen–Winograd **−21.3%** dynamic power vs conventional. Note Strassen's signal and logic powers are *higher* than conventional.

**FFT section.** Standard transform → element-wise multiply → inverse. Notes cuFFT as the dominant library, DSP and FPGA implementations, and — interestingly — **training the CNN entirely in the spectral domain** with spectral-domain non-linearities, interpolation, and Hermitian symmetry, eliminating per-layer FFTs and cutting CIFAR-10 training time.

**Parallelism section.**
- **Data parallelism** = replicate parameters, split samples, all-reduce gradients. Communication cost given for the ring all-reduce: `T_c = 2Σ_i[α⌈log P⌉ + β((P−1)/P)|M_i|]`. Bandwidth requirement noted as only **O(100 Mb)**, much less than CNN compute demands.
  - Subdivided into **batch parallelism** (each process computes an independent mini-batch gradient) and **domain parallelism** (decompose *input activations*; each process holds all parameters but convolves only a subregion; **halo exchange** for boundary points when filter size > 1; boundary-independent convolutions can overlap with communication; no communication overhead at all for 1×1 convolutions).
  - Fundamental limit stated clearly: increasing mini-batch beyond a threshold N degrades inference accuracy, so **mini-batch size caps the achievable parallelism** — "a scalability chokepoint."
- **Model parallelism** = partition the network into disjoint sets across devices; removes parameter synchronization but adds inter-operation data transfer; inter-process communication occurs in forward propagation but *not* during weight update or backward error propagation. **Spatial partitioning** is one strategy: because conv and pooling depend only on neighboring data, partitioning across spatial dimensions permits concurrent execution with modest communication; ReLU parallelizes trivially regardless of spatial distribution.
- Named systems catalogued: **layer-wise parallelism** with a device graph + computation graph and a cost model searched by dynamic programming; **SOYBEAN** (automatic hybrid data+model tiling, 1.5–4× better than data parallelism on AlexNet/VGG); **SOAP / FlexFlow** (parallelize in Sample, Operation, Attribute, Parameter dimensions; 3.8× training improvement over state of the art, prediction 3× faster); **hybrid parallelism on 3-D CNNs** (CosmoFlow, 171 TFlop/s on 128 Tesla V100s, using 64× larger sample size than mini-batch parallelism would allow); a combined sample+spatial tensor decomposition for ResNet-50; **DN2PCIoT** (graph partitioning for constrained IoT devices, **38% more inferences/second** for LeNet-5 than TensorFlow and Metis); **eCNN** (ERNet + FBISA coarse-grained ISA, 4K Ultra-HD 30 fps super-resolution/denoising at 6.94 W); an adaptive framework fusing spatial partitioning with layer fusion (1.9–3.7× speedup across 8 Raspberry Pi 3 devices on ResNet/VGG16/YOLO); and **HyPar** (layer-wise parallelism search across DNN accelerator arrays partitioning input/output feature maps, gradient, error, and kernel tensors, via hierarchical layer-wise dynamic programming with linear time complexity).
- **HyPar's blunt verdict, worth quoting:** "model parallelism is worst among all, and data parallelism is not the best parallelism technique. **Hybrid parallelism can perform better than both.**" Reported: **3.39× performance and 1.51× efficiency over data parallelism, 2.40× over "one weird trick."**

**Optimizer taxonomy (unique to this paper in the set).** SGD → Momentum → NAG → AdaGrad → AdaDelta → RMSProp → ADAM → NADAM → AMSGrad, each with formulation and *challenges*:
- Momentum/NAG fix the uniform-gradient-direction problem; **NAG is better** (dampens oscillations in high-curvature regions, tolerates larger μ) but picking learning rate and momentum coefficient jointly is hard.
- AdaGrad adapts per-parameter rates from accumulated squared gradients, removing manual tuning — but the denominator **accumulates forever**, decaying the learning rate to zero and halting training.
- AdaDelta fixes this with a windowed exponentially-weighted average and removes the need for a global learning rate — but its optimization path oscillates and it underperforms momentum-based methods (annealing suggested).
- RMSProp decays old gradients; **lacks bias correction**, which matters for sparse gradients (β near 1 → large steps → divergence).
- ADAM = RMSProp + Momentum + bias correction; low memory. **But**: converges to poor solutions on some tasks (CIFAR-10 classification), where SGD+momentum wins; cites the "marginal value of adaptive gradient methods" result that adaptive methods don't improve generalization error.
- NADAM = Nesterov momentum + RMSProp. AMSGrad uses the **max** of historical squared gradients instead of the exponential average, to prevent rare large gradients from being washed out — but is reported as having "the worst performance than other methods."
- Their summary mapping: Momentum/NAG → issue 1; AdaGrad/RMSProp → issue 2; **ADAM/NADAM → both**.

**Component-level advances catalogued.** Convolution variants (tiled convolution for rotation/scale invariance, transposed/deconvolution, dilated, Network-in-Network with mlpconv micro-networks, Inception with variable filter sizes). Pooling variants under the unified **L_p pooling** formulation (p=1 → average, p=∞ → max), plus mixed pooling (dropout + drop-connect), stochastic pooling (sample from a multinomial over activations, avoids overfitting), **spectral pooling** (low-pass filtering in the frequency domain — retains more information but is slower and risks destroying conjugate symmetry of Fourier-transformed real inputs), spatial pyramid pooling (number of bins fixed regardless of input size, enabling arbitrary input dimensions), multi-scale orderless pooling (VLAD encoding of multi-scale patch activations for geometric invariance), and ordinal pooling (rank elements and take a weighted sum).

---

# Part 2 — Main Observations: The "Intelligent Methods" Used

Extracted and grouped across the corpus. Each entry names the mechanism, the papers using it, and *why it works*.

## A. Algebraic complexity reduction (change the arithmetic, not the math)

| Method | Papers | Mechanism | Gain |
|---|---|---|---|
| **Winograd / Toom-Cook minimal filtering** | 1, 6, 7, 8, 10, 11, 12 | μ(F(m,r)) = m+r−1; nest 1-D→2-D. Trade multiplications for additions and constant multiplies. | 2.25× (F(2,3)), 4× (F(4,3)) |
| **FFT convolution** | 1, 9, 10, 12 | Convolution theorem; overlap-and-save. Hermitian symmetry halves products. | O(N²K²) → O(N² log N) |
| **FFT overlap-and-add** | 9 | Segment data into filter-sized chunks so all FFTs are small and no intermediate memory expands. | O(N² log K); 7–10× vs direct |
| **Fast complex multiply (3 real mults)** | 1 | Karatsuba-style identity; refactor FFT transforms to emit (U_a,U_b,U_c) real matrices and use 3 SGEMM calls. | 4→3 real mults per complex mult |
| **Strassen matrix multiplication** | 1 (rejected), 12 | 7 mults instead of 8 per 2×2 block, recursively. | 1 − (7/8)^N |
| **Strassen–Winograd hybrid** | 12 | Separate U,V matrices instead of recursive kernel transformation, avoiding added additions. | 75% cost reduction claimed |
| **Cook-Toom / ISC** | 12 | Lagrange interpolation at N+M−1 (or −3) points; iterated short convolutions via mixed radix. | multiplication↓, addition↑ |
| **Channel reduction in the transform domain** | 1 | Sum over C channels *before* the inverse transform, amortizing δ over C. | makes Winograd practical |
| **Recasting element-wise products as batched GEMM** | 1, 6, 7 | The α² independent element positions form α² independent matrix multiplies. | maps to optimized BLAS/systolic HW |

## B. Redundancy removal (change the model)

| Method | Papers | Mechanism |
|---|---|---|
| **Unstructured weight pruning** | 5, 10 | Prune below threshold → retrain → iterate; needs sparse-aware hardware |
| **Structural (filter/channel/layer) pruning** | 10 | Rank by L1/L2/APoZ/feature-map rank; or minimize reconstruction error (ThiNet, NISP); or find *replaceable* filters by similarity |
| **Sparse decomposition with group-lasso** | 2 | ℓ₁ for element sparsity + group-lasso for row sparsity → jointly optimizes sparsity *and* rank against the network loss |
| **Low-rank response reconstruction** | 3 | Assume filter *responses* (not weights) are low-rank; PCA/SVD on the response covariance |
| **Nonlinear (ReLU-aware) low-rank via GSVD** | 3 | Reduced Rank Regression solved in closed form; alternating with a 1-D auxiliary-variable subproblem |
| **Spatial (k×1 / 1×k) separation** | 3, 12 | Jaderberg-style; composed with channel decomposition for 3-D decomposition |
| **Tensor decomposition (CP / Tucker / TT / TR)** | 10, 12 | Replace high-order weight tensors with chains/sums of low-rank factors |
| **Knowledge distillation** | 10 | Train a small student against a large teacher's soft outputs / intermediate features; offline, online, or self |
| **Neural Architecture Search** | 10 | Search space restriction (cell-based), search algorithms (RL, evolution, BO, gradient), and cheap evaluation (accuracy predictors, one-shot supernets) |

## C. Precision reduction

| Method | Papers | Detail |
|---|---|---|
| **Uniform affine / symmetric quantization** | 4, 6, 7, 10, 11 | Scale + zero-point; integer zero-point makes zero-padding exact |
| **Per-channel weight quantization** | 4, 10 | Separate scale per output kernel; immune to batch-norm scale variation. *The single most impactful quantization decision in the corpus.* |
| **KL-divergence threshold calibration** | 6, 7 | τ = argmin D_KL(P(X) ‖ P(Q_τ(X))) over ~500 unlabeled images; no retraining |
| **Quantization-aware training + straight-through estimator** | 4, 10 | Simulated quant/dequant in the graph; gradient passed through only within the clamping range; float master weights |
| **Batch-norm folding with correction + freezing** | 4 | Scale by c = σ_B/σ before quantization to kill jitter; undo on the output early in training; freeze long-term statistics after a delay with a bias correction |
| **Inside-Winograd-domain quantization** | 6, 7 | Quantize *after* the range-amplifying transform, so the full INT8 range is used |
| **Unsigned-operand compensation (±128)** | 6, 7 | Add 128 in input transform, multiply by −128 in the offline filter transform; both stages are memory-bound so it is nearly free |
| **Binarization / XNOR-popcount** | 10 | Deterministic sign() or stochastic hard-sigmoid; XNOR-Net adds a per-filter float scale α |
| **Variable-bitwidth arithmetic** | 10 | Bit-serial (Stripes, UNPU) or bit-level PE fusion (BitFusion, BitBlade) |
| **8-bit PINT format** | 11 | <0.4% degradation on VGG16/ResNet18; simplifies basic compute units |

## D. Generality methods — making a fixed unit handle any convolution shape

This is a distinct, recurring family that deserves its own grouping.

| Method | Papers | Mechanism |
|---|---|---|
| **Stride-based convolution decomposition (SCDM)** | 8 | Gather kernel/input elements at **s-step distance** ("jumping mechanism"), zero-pad blocks to n×n / m×m, run each through one unit, accumulate. Handles *any* r, *any* s. |
| **Decomposable Winograd Method (DWM)** | 11, 12 | Decompose kernels >3×3 or stride >1 into ≤3×3 stride-1 kernels. |
| **Input-aligned / layer-to-layer unified input tiling** | 11 | Fix the *input tile* at 6×6 rather than the output at 2×2, so a single hardware unit serves every decomposed shape; 1×1 kernels degenerate to element-wise multiply. |
| **Fusing two Winograd units with shared logic** | 8 | F(4,3) and F(4,2) share the same B matrix, most of G/A, and the same 4×4 dot-product array — complementary saving-rate curves at near-zero extra area. |
| **Analytic unit-selection rules** | 8 | MCM-derived thresholds (r > 2s for F(4,3); r > 4s/3 for F(4,2); F(4,3) wins when r ≥ 3s and r = 6k+3) drive a single `sel` bit. |

## E. Dataflow and memory methods (hardware)

| Method | Papers | Mechanism |
|---|---|---|
| **Input-stationary + Cartesian product dataflow** | 5 | Every non-zero weight × every non-zero activation is a useful product → full multiplier utilization on compressed data |
| **Planar tiling with output halos** | 5 | Spatial tiles across PEs; oversized accumulator buffers hold incomplete partial sums exchanged with neighbors |
| **Scatter crossbar to banked accumulators** | 5 | Handles discontiguous output coordinates from decoded indices; A = 2×F×I banks to limit conflicts |
| **Compressed encoding kept end-to-end** | 5 | Data vector + 4-bit run-of-zeros index vector, in DRAM *and* all on-chip buffers |
| **Row/weight/input/output-stationary taxonomy** | 10 | Four canonical dataflows; row-stationary reported as lowest energy |
| **Processing-in-memory** | 10 | DRAM (DrAcc), ReRAM (PRIME, PattPIM), HMC/3-D (Neurocube) |
| **Cache + register blocking with auto-tuning** | 6, 7 | Sub-matrices sized to L2; register tiles constrained by 32 AVX-512 registers; JIT + wisdom file |
| **Non-temporal stores to convert gather → sequential read** | 6, 7 | Scatter at the end of matmul so the output-transform stage reads contiguously |
| **Fused vs non-fused kernel choice** | 7 | Fused wins for small tiles (cache miss rate −30 to −38 pts); non-fused wins for large tiles (bigger GEMM blocks) |
| **Fused conv + batch-norm + ReLU** | 9 | Eliminates intermediate memory traffic between three consecutive layers |
| **Pre-stored "Reuse Loader" + shift network** | 11 | Buffer data on first read; serve later accesses by shifting/aligning instead of re-reading |
| **Common sub-expression elimination in transform circuits** | 11 (HW), 6/7 (SW codelets) | 192 → 156 additions per channel (18.75%); also shortens the critical path |
| **Column-indexed PE array** | 11 | Row index resets between rows + skip buses → 34% fewer output bus ports → lower FF power |
| **Compile-time encoding of sparse structure into code** | 2 | Non-zero positions become register indices in generated code — eliminates indirect memory access entirely |

## F. Optimization / training methods

| Method | Papers | Mechanism |
|---|---|---|
| **Closed-form solvers instead of SGD** | 3 | SVD / GSVD / PCA; 3000 images, 2–5 min per layer; avoids SGD's sensitivity to init and learning rate |
| **Asymmetric reconstruction** | 3 | Target from the *exact* input, prediction from the *degraded* input — each layer compensates for upstream error |
| **Greedy rank selection under a complexity budget** | 3 | Maximize Π(PCA energy) s.t. Σ(d′/d)C ≤ C; drop the eigenvalue with the smallest ΔE/E ÷ ΔC |
| **Fine-tune from a float/full checkpoint, not from scratch** | 2, 3, 4 | Consistently better than scratch training in all three papers |
| **Cascade classifiers to prune work** | 2 | Use the last conv layer as a stage-1 classifier; prune ~80% of detection windows → ~5× FC speedup |
| **Adaptive-moment optimizers** | 12 | Momentum → NAG → AdaGrad → AdaDelta → RMSProp → ADAM → NADAM → AMSGrad, each fixing a specific pathology |
| **Data / model / hybrid parallelism** | 12 | Batch and domain (halo-exchange) data parallelism; spatial model partitioning; automated search (SOYBEAN, FlexFlow/SOAP, HyPar) |

---

# Part 3 — Cross-Paper Comparison of Methods

## 3.1 The master comparison table

| Paper | Lever | Where the win comes from | Needs retraining? | Needs custom HW? | Kernel/stride generality | Headline result |
|---|---|---|---|---|---|---|
| **1 Lavin & Gray** | Winograd | Arithmetic (mults) | No | No (GPU) | 3×3, stride 1 | 2.26× vs cuDNN at N=1; 10.28 eff. TFLOPS |
| **2 Liu (SCNN-Liu)** | Sparse + low-rank | Arithmetic + code specialization | **Yes** (fine-tune) | No (AVX CPU) | Any (11×11 to 3×3) | >90% sparsity, <1% acc drop, 2.5–6.9× actual |
| **3 Zhang** | Low-rank responses | Arithmetic | Optional (helps) | No | Any | VGG-16 4× at +0.3% top-5 |
| **4 Krishnamoorthi** | Quantization | Precision (memory + arithmetic) | Optional (PTQ vs QAT) | Benefits from it | Any | 4× model size; 2–3× CPU, ~10× DSP; ≤1–2% acc |
| **5 SCNN (NVIDIA)** | Sparsity in HW | Arithmetic + data movement | Uses pruned models | **Yes** (ASIC) | Conv only; FC at 25% peak | 2.7× perf, 2.3× energy vs dense |
| **6 LoWino ICPP** | Winograd + INT8 | Arithmetic + precision | **No** (PTQ + calibration) | No (VNNI CPU) | 3×3, stride 1 | 2.04× max / 1.26× avg vs oneDNN |
| **7 LoWino TACO** | Same + fused impl. | Same | No | No | 3×3, stride 1 | 2.90× max / 1.91× avg; VGG16 2.04× end-to-end |
| **8 SCDM/WHD** | Decomposition + fused Winograd unit | Arithmetic + area | No | **Yes** (FPGA/ASIC) | **Any r, any s** | 34–55% op reduction; −28.8% LUT, −21.6% power |
| **9 FFT-OVA** | FFT-OVA | Arithmetic + memory | No | Partly (PENC has FFT ISA) | Any | 2.9×/1.65× vs Direct/FFT on PENC; 6× on FPGA |
| **10 Ghimire** | Survey | — | — | — | — | Taxonomy + co-design frontier |
| **11 Li 2025** | 6×6 unified-input DWM | Arithmetic + area + memory | No | **Yes** (FPGA) | **Any r, any s** (r ≤ 6 per block) | 683 GOPS, 74.5 GOPS/W, 5.8× DSP eff. |
| **12 Habib** | Survey | — | — | — | — | Fast-conv genealogy + parallelism verdicts |

## 3.2 Winograd vs FFT — the corpus's most-repeated comparison

Five papers weigh in. They **agree on the direction** but differ enormously in rigor and in the operating point they care about.

| Paper | Verdict | Evidence quality |
|---|---|---|
| **1 Lavin** | Winograd wins for 3×3. FFT+direct-CGEMM needs tile **64×64** to match F(4×4,3×3)'s 6×6 on the multiply stage; FFT+fast-CGEMM reaches parity at tile **16**. Winograd = 1.0 real mult/input, FFT ≥ 1.5 even with fast CGEMM. | **Strongest** — normalized complexity tables for both, same overlap-and-save framework, and empirical cuDNN-FFT numbers |
| **8 Yang** | Winograd chosen over FFT because "FFT-based convolutions are inefficient for small kernel sizes if mismatch exists between kernel size and input size," and 1/3/5 kernels dominate modern nets. Concrete: at 3×3/s=1, WHD 55.6% vs FFT 39% vs FFA 33%. But FFT wins at 5×5/s=1. | Strong — analytic MCM + transform-element comparison |
| **9 Abtahi** | FFT-OVA > FFT > Direct on embedded CPU/many-core; FFT > Direct on GPU; **FFT-OVA is not beneficial on GPU** (kernel-launch overhead). Does not test Winograd. | Empirical across 4 platforms; no Winograd baseline |
| **11 Li 2025** | "FFT... performance is positively correlated with the size of the convolution kernel, [so it] offers limited performance improvements for mainstream CNN models." | Assertion with citation |
| **12 Habib** | Winograd for small convolutions, Strassen for large; Winograd fails on **dilated** convolutions (zero padding becomes non-zero in the Winograd domain), so Intel/cuDNN fall back to GEMM. | Qualitative but the dilated-conv argument is a genuine and specific contribution |

**Synthesis:** the field converged on Winograd for the 3×3 regime that dominates modern CNNs, and on FFT only when the kernel is genuinely large or when the tile size can be made large enough to amortize the transform. FFT's real remaining niche in this corpus is embedded platforms via **overlap-and-add**, where the memory-expansion problem is what actually mattered — not the FLOP count.

## 3.3 The Winograd tile-size dilemma and the four distinct responses

Every Winograd paper confronts the same wall: bigger tile ⇒ more multiplication savings, but transform cost grows **quadratically** and coefficient magnitude grows too, wrecking fixed-point precision.

| Response | Paper | Strategy | Verdict |
|---|---|---|---|
| **Stay small** | 1 (implements F(2,3)), 8 (F(4,3)+F(4,2) only) | Accept a modest ratio; keep transform elements in {0, ±1, ±½} so multiplies become shifts | Simplest, most hardware-friendly, but leaves savings on the table |
| **Up-cast the transformed data** | ncnn (critiqued in 6, 7) | INT8 → INT16 after transform | Correct but **defeats the purpose** — the multiply stage loses the low-precision speedup |
| **Down-scale after transform** | oneDNN (critiqued in 6, 7) | Multiply by α (¼, 1/100, 1/10000) and round | Works at m=2; **produces 0.00% accuracy at m=4** |
| **Quantize inside the Winograd domain** | 6, 7 | Keep FP32 through the transform; quantize the transformed values, using the full INT8 range | Enables F(4,3) at usable accuracy: VGG16 69.20% vs 00.00%; errors cut 85% |
| **Change the tiling, not the arithmetic** | 11 | Fix the *input* tile at 6×6 (not the output), precompute the awkward G matrix off-chip, express transform constants as shift combinations (5 = 2²+1) | 56.25% of the 4×4 scheme's multiplications at 1.23× additions |

This is the clearest example in the corpus of **the same constraint producing four genuinely different engineering answers** at different layers of the stack (algorithm, data type, quantization placement, tiling).

## 3.4 "Winograd only does 3×3 stride 1" — three distinct fixes

| Fix | Paper(s) | How | Cost |
|---|---|---|---|
| **Build multiple units** | prior work critiqued by 8 | One compute unit per kernel size (e.g. three FFA units for 3/5/7) | Massive area waste — idle units |
| **Fall back to another algorithm** | prior work critiqued by 8; cuDNN for dilated (12) | Direct multiplication for 11×11, zero-padding for 5×5, GEMM for dilated | 40.7% degradation in multiplication-reduction rate reported for F(6,3) |
| **Decompose the kernel** | **8 (SCDM), 11 (DWM), 12 (cites DWM)** | Split into ≤3×3 stride-1 sub-kernels (SCDM generalizes by gathering at s-step distance), run all on one unit, accumulate | Zero-padding waste; poor when s ≈ r; but **any r, any s on uniform hardware** |

Decomposition clearly won: papers 8 (2020), 11 (2025), and the DWM line cited in 12 all converge on it independently. Paper 11's refinement — unify the **input** tile rather than the output tile — is the key step that makes decomposition map onto a single reconfigurable hardware unit.

## 3.5 Sparsity: two eras, two answers

| Dimension | **Liu et al. 2015 (#2)** — software | **SCNN 2017 (#5)** — hardware |
|---|---|---|
| Sparsity source | Learned via group-lasso decomposition | External pruning (Han et al.) + ReLU |
| Sparsity exploited | **Weights only** (activations treated as dense) | **Weights AND activations** |
| Where zeros are skipped | Compiled-in register indices, CPU AVX | Never fetched from any buffer or DRAM |
| Compression scope | Kernels only | Weights + activations, DRAM through all on-chip buffers |
| Sparsity ratio | >90% | 20–80% weights, 50–70% activations |
| Speedup | 2.5–6.9× per layer (theoretical 2.6–16×) | 2.7× network-wide |
| Fundamental cost identified | **I/O time falls only sub-linearly** — below 10% density, I/O is >80% of runtime | Memories = 57% of PE area; crossbar alone = 3× the multiplier array's area |
| Break-even | (not analyzed) | SCNN is **worse** than dense above ~85% density (perf) and ~83% (energy) |

Both independently arrive at the same deep conclusion: **arithmetic scales with sparsity but data movement does not.** Liu measures it in a CPU cache hierarchy; SCNN pays for it in crossbar silicon. Neither achieves the ideal proportional speedup.

## 3.6 Quantization: three positions in the corpus

| | **#4 Krishnamoorthi (2018)** | **#6/#7 LoWino (2021/2024)** | **#11 Li (2025)** |
|---|---|---|---|
| Scope | General-purpose recipe for all CNNs | Specifically the Winograd interaction | A fixed choice inside an accelerator |
| Key question | Where to place scales (per-layer vs per-channel)? | **Where in the pipeline to quantize** (before or after the transform)? | Which format is cheap in FPGA fabric? |
| Answer | **Per-channel weights + per-layer activations** | **Inside the Winograd domain** | **8-bit PINT** |
| Calibration | min/max moving average (~100 batches) | **KL-divergence** on ~500 unlabeled images | (assumed from prior work) |
| Retraining | PTQ suffices to ~2%; QAT to ~1% | **None required** | None |
| Diagnostic insight | Batch-norm folding creates cross-kernel dynamic-range explosion → per-layer scales fail on Mobilenets | The Winograd transform amplifies range ~100× at m=4 → outside-quantization overflows | Large blocks lose precision; >8×8 is unusable |

The through-line: **all three trace their key failure to a *range* problem, and all three solve it by choosing a better place to put the scale.** Krishnamoorthi moves the scale to per-kernel granularity; LoWino moves it later in the pipeline; Li moves the awkward transform off-chip.

## 3.7 Theoretical vs. actual speedup — the gap, everywhere

| Paper | Theoretical | Actual | Gap explanation given |
|---|---|---|---|
| **2 Liu** | 16.12× (conv3) | **6.88×** | Sparse-matmul overhead + inefficient basis convolution in Caffe (matmul is poor for few filters) |
| **3 Zhang** | 4× | **3.5× CPU, 3.3× GPU** | FC and other layers on CPU; on GPU, generic Caffe kernels aren't tuned for 1×1/1×3/3×1 |
| **3 Zhang (VGG-16)** | 4× | 3.8× CPU, **2.9× GPU** | Same; "GPU speedup ratios are more sensitive to specialized implementation" |
| **5 SCNN** | oracle (Fig. 9) | 2.7× | **Intra-PE fragmentation** (<20% multiplier utilization in late GoogLeNet layers) + **inter-PE barriers** |
| **6/7 LoWino** | F(4,3) = 4× arithmetic | 1.26–1.91× avg | Transform stage is **memory-bound** and reads FP32 (4× the bytes of oneDNN's INT8 input) |
| **9 Abtahi** | 7–10× (FFT-OVA vs Direct) | **2.9–3.36×** | Cluster-memory limits force inter-cluster traffic at ~2× latency |
| **11 Li** | — | 85–90% MAC utilization | 3-input-channel first layer; 2.4 GB/s DRAM bandwidth; the reuse mechanism hurts small layers |

**Common root causes, ranked by how often they appear:**
1. **Memory bandwidth / data movement** (2, 5, 6, 7, 9, 11) — the dominant cause
2. **Utilization / fragmentation** at layer boundaries or odd shapes (5, 11)
3. **Unoptimized library kernels** for the newly-introduced small operators (2, 3)
4. **Overheads of the acceleration mechanism itself** (5's crossbar, 6/7's transform, 8's zero-padding)

Paper 8 stands slightly apart: because its multiplication reduction is realized by *actually shrinking the PE array* rather than idling multipliers, its 55.6% reduction at 3×3/s=1 translates directly into 28.8% fewer LUTs.

## 3.8 Retraining requirement — a sharp dividing line

| No retraining at all | Retraining optional (improves results) | Retraining required |
|---|---|---|
| 1 (Lavin — exact algorithm) | 3 (Zhang — 0.9% → 0.3% with FT at 4×) | 2 (Liu — group-lasso *is* the training) |
| 6, 7 (LoWino — PTQ + calibration) | 4 (Krishnamoorthi — PTQ ~2%, QAT ~1%) | 5 (SCNN uses pruned models from Han et al.) |
| 8 (SCDM — pure decomposition) | 11 (quantization only) | 10 (pruning/KD/NAS all train) |
| 9 (FFT-OVA — exact) | | |

Notable: the **exact algebraic methods (1, 8, 9)** need no retraining by construction, which makes them uniquely deployable. The **approximate methods** split — LoWino is remarkable precisely because it achieves quantization-level gains with post-training-only cost, whereas the low-rank/sparse methods cannot escape retraining.

## 3.9 Platform coverage

| Platform | Papers | Note |
|---|---|---|
| **GPU** | 1 (Maxwell Titan X), 9 (Jetson TX1), 12 (V100 for DWM) | Winograd was born here; embedded GPU covered by 9 |
| **CPU (server)** | 2 (i7 AVX), 3 (i7 SSE), 6, 7 (Xeon Scalable VNNI) | The VNNI-era papers are the most sophisticated |
| **CPU (embedded)** | 9 (ARM Cortex-A53), 12 (ARM Cortex-A) | |
| **FPGA** | 8 (XC7Z100), 9 (Zynq 7020 / SPARCNet), 11 (XC7Z045), 12 (Kintex-7) | Where decomposition methods live |
| **ASIC** | 5 (TSMC 16nm), 9 (PENC 65nm), 10 (survey) | |
| **Mobile SoC / DSP** | 4 (Pixel 2, Qualcomm HVX) | Only paper with real phone measurements |
| **PIM** | 10 (survey only) | Identified as an open frontier |

## 3.10 Benchmark networks — comparability caveat

| Network | Papers using it |
|---|---|
| **VGG (16 / D / E)** | 1, 3, 5, 6, 7, 8, 11, 12 |
| **ResNet (18 / 20 / 50 / 152)** | 4, 6, 7, 8, 9, 11 |
| **AlexNet** | 2, 5, 6, 7, 8, 9 |
| **GoogLeNet / Inception** | 4, 5, 6, 7, 8 |
| **MobileNet v1/v2, NasNet** | 4 only |
| **YOLO / U-Net / FusionNet** | 6, 7, 8 |
| **CIFAR-10** | 9 |

Two observations:
- **VGG is the most flattering benchmark** for fast-convolution work, and every Winograd paper leans on it. Papers 7, 8, and 11 all state the reason explicitly: VGG16 is almost entirely 3×3, so gains are near-maximal (55.41% op reduction in #8; 2.04× end-to-end in #7). ResNet-50, with its mixed 1×1/3×3 residual blocks, gives only 1.11× (#7) and 34.08% (#8). **Reported speedups are therefore as much a statement about the benchmark as about the method.**
- Only **#4** covers the depthwise-separable / MobileNet family — and it is precisely the family that *breaks* naive quantization. None of the Winograd papers touch depthwise convolution at all, which is a conspicuous corpus-wide gap given MobileNet-class models' importance at the edge.

## 3.11 Direct disagreements between papers

**(a) Are quantization and fast convolution orthogonal?**
- **#1 Lavin (2016):** approximation/quantization methods are "orthogonal and complementary" and out of scope.
- **#6/#7 LoWino (2021/2024):** "Winograd convolution and quantization are **not** orthogonal optimization methods that can be simply combined together. A holistic design is needed."
- **Resolution:** LoWino is right, and demonstrates it — naive combination yields 00.00% accuracy at F(4×4,3×3). Lavin's framing was reasonable for FP32 GPU work but does not survive contact with INT8.

**(b) Is the accelerated architecture inherently better, or does the algorithm matter?**
- **#3 Zhang:** the *same* decomposed architecture trained from scratch gives 16.9% top-5 vs **14.1%** for their accelerated model — a 2.8% gap. Concludes the acceleration algorithm "digests information" from the trained model.
- **#10 Ghimire (citing others):** in *structural pruning*, "fine-tuning the pruned model yields comparable or inferior performance than training the same model from scratch with randomly initialized weights."
- **Resolution:** these are compatible but the tension is real and worth flagging. The claims concern different operations (low-rank response reconstruction vs filter pruning) and different scales (very deep ImageNet models vs the pruning literature's typical settings). Anyone building on either should not treat "train from scratch instead" as a settled question.

**(c) Should activation ranges be constrained?**
- **#4 observation 2(b):** ReLU6 is credited with making Mobilenet-v1 activations easy to quantize (fixed (0,6) range removes dynamic-range variation).
- **#4 model recommendations:** "Do not constrain activation ranges" — plain ReLU beats ReLU6 for quantized accuracy.
- Same paper; the recommendation supersedes the observation, but the tension is instructive: a *fixed* range helps naive quantization while a *learned* range helps the final result.

**(d) Does Winograd always beat direct convolution?**
- Implied yes by #1, #11, #12.
- **#6/#7 explicitly no:** for ResNet-50_a, INT8 F(2,3) is slower than INT8 direct in both oneDNN and LoWino; for YOLOv3_a, direct beats even F(4,3). Reason: transform memory overhead exceeds compute savings for certain layer geometries.
- **#8 partially no:** derives explicit thresholds (r > 2s, r > 4s/3) below which GEMM wins, and reports a **−14%** saving rate at (r,s) = (5,4).
- **Resolution:** the honest position is #6/#7/#8's — fast convolution needs a per-layer decision, and #6 lists "an automatic mechanism to select the optimal algorithm for a convolutional layer among direct, Winograd, and others" as explicit future work.

**(e) Which parallelism strategy is best?**
- **#12 (via HyPar):** "model parallelism is worst among all, and data parallelism is not the best... **hybrid parallelism can perform better than both**" — 3.39× perf / 1.51× efficiency over data parallelism.
- Data parallelism's ceiling is also named: mini-batch size beyond N degrades accuracy, so it is a scalability chokepoint.
- No other paper in the set addresses distributed training, so this is uncontested here.

## 3.12 Lineage and influence within the corpus

```
Winograd (1980) / Toom (1963) / Cook (1966)
        │
        └─► #1 Lavin & Gray (2016)  ◄── the anchor citation for #6,#7,#8,#11,#12
                 │
                 ├─► #8 SCDM/WHD (2020)      — decompose for any r,s; fuse F(4,3)+F(4,2)
                 │        │
                 │        └──────────────┐
                 ├─► DWM (Huang 2020) ───┤
                 │        │              │
                 │        └─► IA-DWM ────┴─► #11 Li (2025)  — 6×6 unified INPUT tiling
                 │
                 └─► #6 LoWino ICPP (2021) ──► #7 LoWino TACO (2024)  — inside-quantization
                            ▲
                            │ builds on
                    #4 Krishnamoorthi (2018) quantization recipe
                            │
Jaderberg (2014) spatial ───┼──► #3 Zhang (2015) 3-D decomposition (composes both)
Denton (2014) low-rank  ────┘
                            
Han et al. pruning ────────► #2 Liu (2015) sparse+low-rank CPU
                     └─────► #5 SCNN ISCA (2017) sparse dataflow ASIC
                                    ▲
                     Eyeriss / Cnvlutin / Cambricon-X (compared against)

FFT (Mathieu 2013, Vasilache 2014) ──► #9 FFT-OVA embedded (2018)

#10 Ghimire (2022) and #12 Habib (2022) survey essentially all of the above.
```

Notable: **#6 → #7 is the only explicit self-extension**, and the delta is instructive — the journal version adds error quantification, an implementation variant (fused), and a second hardware platform, raising the average speedup from 1.26× to 1.91×. That is a good template for what a conference→journal extension should contain.

## 3.13 Metric heterogeneity — why cross-paper numbers cannot be added

The corpus uses at least eight incommensurable primary metrics:

| Metric | Papers | Problem |
|---|---|---|
| Arithmetic complexity reduction (×) | 1, 8, 9, 11, 12 | Ignores transform and memory overhead |
| Effective TFLOPS | 1 | Credits direct-algorithm FLOPs, so it can exceed device peak |
| Wall-clock speedup vs a named baseline | 2, 3, 6, 7, 9 | Baseline quality varies enormously (optimized cuDNN/oneDNN vs serial GNU Octave) |
| GOPS / GOPS-per-Watt / GOPS-per-DSP | 11, and 11's comparison table | Platform-normalized but sensitive to clock and precision |
| Energy per inference (mJ) | 9 | Only paper with measured board-level energy across platforms |
| Energy relative to a dense baseline | 5 | Simulated, not measured |
| Latency (ms) on a real phone | 4 | The most deployment-realistic measurement in the set |
| Accuracy delta (top-1 / top-5 / mAP) | 2, 3, 4, 6, 7, 11 | Sometimes top-1, sometimes top-5, sometimes 1-view vs 10-view |

**Practical consequences:**
- #9's "PENC is 10916× faster than ARM A53" is not comparable to #7's "1.91× over oneDNN" — the former's baseline is an unoptimized interpreted implementation, the latter's is a hand-tuned vendor library. **Baseline strength is the single largest confound in this corpus.**
- #11's Table 4 is the only place where cross-platform normalization is attempted seriously (GOPS/DSP and GOPS/W), and it is done well — including reporting cases where they lose.
- Accuracy reporting is inconsistent enough that only within-paper deltas should be trusted.

## 3.14 Where the papers agree — the consensus findings

1. **Convolution layers are >90% of the compute** (stated in 4, 5, 9, 11, 12 with essentially identical framing). FC layers are memory-bound rather than compute-bound.
2. **3×3 filters dominate modern CNNs**, and therefore the optimization target is small-kernel convolution (1, 8, 11, 12).
3. **Memory movement, not arithmetic, is the binding constraint** once arithmetic is reduced (2, 4, 5, 6, 7, 9, 11). Krishnamoorthi's version: "moving 8-bit data is 4× more efficient than moving 32-bit... memory access can dominate power consumption."
4. **CNNs are heavily over-parameterized and tolerate large approximation** (2, 3, 4, 10, 12). Liu's cosine-similarity result (conv3 kernels at 0.34 similarity with negligible accuracy loss) is the most striking single demonstration.
5. **Fine-tuning from a trained checkpoint beats training the compressed structure from scratch** (2, 3, 4) — though see §3.11(b) for the pruning-specific counterargument.
6. **The optimization solver matters as much as the decomposition design** (3 states this explicitly; 6/7's whole contribution is a solver-placement decision).
7. **Optimal method is layer-dependent and platform-dependent** — 6/7 (Winograd vs direct per layer), 8 (F(4,3) vs F(4,2) per shape), 9 (FFT-OVA helps CPU, hurts GPU), 3 (per-layer rank selection), 11 (fused vs non-fused per layer), 10 ("no golden rule").
8. **Hardware/software co-design is the frontier** — stated as the concluding direction by 10, 11, and 12 independently.

## 3.15 Corpus-wide gaps

- **Depthwise / separable convolution is almost absent.** Only #4 evaluates MobileNets — and finds they are the hardest case. No Winograd or sparsity paper addresses depthwise convolution, despite it being the dominant edge primitive since 2017.
- **Transformers / attention are entirely absent.** The most recent paper (#11, 2025) mentions CMT (a CNN-ViT hybrid) only in passing (#7's discussion). The corpus is purely CNN-era.
- **Training acceleration is thin.** Only #11 explicitly handles FP/BP/WG stages in hardware; #1 gives F(3×3,2×2) for weight gradients; #12 covers distributed training. Everything else is inference-only.
- **Dilated convolution** is raised as a problem only by #12, and no paper in the set solves it.
- **Energy is under-measured.** Only #4 (phone) and #9 (INA219 board-level) report *measured* energy; #5 and #11 report simulated/tool-estimated power.
- **No paper composes all three main levers** (fast convolution + sparsity + quantization). The closest are #6/#7 (fast conv + quantization) and #5 (sparsity + dataflow). Composing Winograd with sparsity is notably absent — plausibly because the Winograd transform *destroys* sparsity by turning zeros into non-zeros (the same mechanism #12 identifies for dilated convolution). **This is the most interesting unexplored intersection implied by the corpus.**

---

## Appendix — One-line takeaway per paper

1. **Lavin & Gray** — Winograd minimal filtering, one multiply per input, and the analytical model that everyone else uses to reason about transform overhead.
2. **Liu et al.** — Sparsity is best learned against the network loss (group-lasso), and best exploited by compiling the fixed non-zero pattern directly into register indices.
3. **Zhang et al.** — Reconstruct *nonlinear responses* with a closed-form GSVD solver, and reconstruct them *asymmetrically* so each layer absorbs upstream error; that is what makes whole-model very-deep acceleration work.
4. **Krishnamoorthi** — Per-channel weight quantization is the decision that matters, because batch-norm folding explodes cross-kernel dynamic range; everything else is refinement.
5. **SCNN** — A Cartesian-product, input-stationary dataflow makes every product useful on doubly-compressed data; the price is that the scatter crossbar costs 3× the multiplier array's area.
6. **LoWino (ICPP)** — Quantize *inside* the Winograd domain, and large-tile INT8 Winograd goes from unusable (0.00% accuracy) to practical.
7. **LoWino (TACO)** — The same idea, quantified (85% error reduction at F(4,3)) and rounded out with a fused implementation that cuts cache miss rate by ~38 points.
8. **SCDM/WHD** — Decompose any (kernel, stride) into one uniform pattern by gathering elements at s-step distance, then fuse two complementary small Winograd units that share their transform logic and PE array.
9. **FFT-OVA** — Overlap-and-add is the FFT variant that actually fits embedded memory hierarchies, and the best convolution algorithm is platform-dependent (it helps CPUs and many-cores, and hurts GPUs).
10. **Ghimire survey** — The map: pruning / quantization / tensor decomposition / KD / NAS crossed with temporal / spatial / PIM hardware, converging on NAS-driven model–accelerator co-design.
11. **Li 2025** — Unify the *input* tile at 6×6 rather than the output tile, and one reconfigurable Winograd unit covers every decomposed kernel shape at 683 GOPS and 74.5 GOPS/W.
12. **Habib survey** — The genealogy: Cook-Toom → Winograd → Strassen → Strassen-Winograd → DWM, plus the honest verdicts that Winograd fails on dilated convolution and that hybrid parallelism beats both data and model parallelism.
