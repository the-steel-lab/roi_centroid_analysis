# roi_centroid_analysis

Compares surface-based fMRI ROI centroids between two task conditions across subjects and hemispheres. Computes centroid positions and shifts (task1 − task2), vertex-level Jaccard overlap, polar displacement plots in the Y–Z plane, and mixed-effects statistics.

---

## Quick start

1. Edit the **USER CONFIGURATION** block at the top of `run_roi_analysis.m` (subjects, hemisphere list, ROI numbers, paths, task names).
2. Run `run_roi_analysis.m` from MATLAB.
3. Outputs land in `output/<study>/`.

---

## Pipeline overview

```
run_roi_analysis.m
│
├── load_roi_data()          — load vertices, coords, centroids per subject/hemi/task
├── create_com_roi()         — write center-of-mass sub-ROI files
├── build_group_matrices()   — assemble [nSubj × 3 × nHemi] centroid & diff matrices
├── compute_overlap()        — vertex-level Jaccard index between tasks
├── plot_results()           — bar plots (X/Y/Z shift) + polar plots (Y–Z plane)
├── plot_overlap()           — Jaccard overlap bar plots
├── run_shift_statistics()   — LME + paired t-test on centroid shift (Y axis)
└── run_overlap_statistics() — LME + pairwise t-tests on Jaccard overlap
```

---

## Input files

| File | Format | Description |
|------|--------|-------------|
| `ref.<roi_stem>-<hemi>.1D.roi` | two-column text: `vertex_index  roi_number` | Surface ROI labels; one row per vertex assigned to a ROI |
| `<hemi>.inflated.coords.txt` | four-column text: `vertex_index  X  Y  Z` | Inflated-surface vertex coordinates (mm) |

Vertex indices in both files are **0-based**. The first row of the ROI file is treated as a header and skipped if its ROI number is not in `cfg.roi_list`.

### Coordinate axes

| Axis | Direction |
|------|-----------|
| X | Left–Right (medial–lateral in native hemisphere space) |
| Y | Anterior–Posterior |
| Z | Dorsal–Ventral |

> **Note on hemisphere averaging:** When bar-plot shifts are averaged across hemispheres, the RH X dimension is multiplied by −1 so that it reflects lateral→medial displacement, matching the LH convention. The Y and Z axes are the same across hemispheres and are averaged directly.

---

## Configuration (`run_roi_analysis.m`)

| Field | Description |
|-------|-------------|
| `cfg.subjects` | Cell array of subject IDs |
| `cfg.hemis` | Hemispheres to process, e.g. `{'lh', 'rh'}` |
| `cfg.roi_list` | Vector of ROI numbers to extract (e.g. `39:43`) |
| `cfg.roi_names` | Display names for each ROI (same order as `roi_list`) |
| `cfg.study` | Label appended to all output filenames and the output folder |
| `cfg.base_dir` | Root of per-subject data directories |
| `cfg.output_dir` | Where figures and results are saved |
| `cfg.coord_file` | Coordinate filename template; `{hemi}` is replaced at runtime |
| `cfg.coord_path` | Directory containing coordinate files |
| `cfg.tasks(1/2)` | Structs with fields `name`, `subdir`, `roi_stem` for each task |
| `cfg.com_n_vertices` | Number of closest-to-centroid vertices to keep in COM sub-ROIs |
| `cfg.com_output_dir` | Where COM sub-ROI files are written |

`cfg.tasks(1)` is the **minuend** (task1 − task2 = positive shift means task1 is more anterior/dorsal/etc.).

---

## Functions

### `load_roi_data(roi_path, coords_path, roi_list)`
Reads one ROI file and its associated coordinate file. Returns a struct `S` with:
- `S.vertices{r}` — 0-based vertex index vector for ROI `r`
- `S.coords{r}` — N×3 XYZ coordinates
- `S.centroid{r}` — 1×3 mean centroid
- `S.missing` / `S.coords_missing` — flags set if files are absent

Cell arrays are preallocated to `max(roi_list)` so ROI `r` is always at index `r`.

---

### `create_com_roi(roi_path, coords_path, roi_list, output_dir, n_vertices)`
For each ROI, selects the `n_vertices` vertices closest (Euclidean distance) to the ROI's center of mass and writes a new `.1D.roi` file. Useful for creating spatially compact, comparable sub-ROIs across subjects and tasks.

Output filename format: `<roi_number>.COM.<n_vertices>.<hemi>.1D.roi`

---

### `build_group_matrices(subjectData, cfg)`
Assembles per-ROI matrices across all subjects and hemispheres:
- `results.roi(ri).centroid.<taskname>` — `[nSubj × 3 × nHemi]`, NaN where data are missing
- `results.roi(ri).diff_matrix` — `[nSubj × 3 × nHemi]`, task1 − task2
- `results.roi(ri).diff_theta` — `[nSubj × nHemi]`, polar angle in Y–Z plane (radians)
- `results.roi(ri).diff_rho` — `[nSubj × nHemi]`, polar magnitude in Y–Z plane (mm)

Polar coordinates are computed as `cart2pol(Y_diff, Z_diff)`, so angle 0° = anterior, 90° = dorsal.

---

### `compute_overlap(results, subjectData, cfg)`
Computes vertex-level Jaccard index between the two tasks for each ROI × hemisphere × subject:

```
Jaccard = |intersection| / |union|
```

Adds to `results.roi(ri).overlap.<hemi>`:
- `n_task1`, `n_task2` — vertex counts per task
- `n_shared` — intersection size
- `jaccard` — Jaccard index (NaN if either ROI is empty or missing)

---

### `plot_results(results, cfg)`
Produces two figure types per ROI, each in per-hemisphere and hemisphere-averaged versions:

**Bar plots** (`figures_centroid_shift/`):
| File | Content |
|------|---------|
| `ROI<N>_centroid_shift_<study>.png` | Two subplots (LH, RH): group-mean bars with individual subject dots for X, Y, Z shift |
| `ROI<N>_centroid_shift_avg_<study>.png` | Single plot: hemispheres averaged (RH X flipped to lateral-medial before averaging); X tick labelled `X (lat-med)` |

**Polar plots** (`figures_polar/`):
| File | Content |
|------|---------|
| `ROI<N>_polar_YZ_<study>.png/.pdf` | Two polar subplots (LH, RH): each subject as a radial line + dot in the Y–Z plane |
| `ROI<N>_polar_YZ_avg_<study>.png/.pdf` | Single polar plot: Y and Z averaged directly across hemispheres |

---

### `plot_overlap(results, cfg)`
Bar plots of Jaccard overlap per ROI surface, with individual subject lines and dots.

| File | Content |
|------|---------|
| `figures_overlap/overlap_by_surface_<study>.png/.pdf` | Two subplots (LH, RH) |
| `figures_overlap/overlap_by_surface_avg_<study>.png/.pdf` | Single plot: Jaccard averaged across hemispheres per subject |

---

### `run_shift_statistics(results, cfg)`
Fits a linear mixed-effects model per ROI on the **Y-axis** centroid position:

```
Shift ~ Task * Hemisphere + (1|Subjects)
```

Also runs a paired t-test comparing subject-mean Y values between tasks (averaging across hemispheres). Reports t-statistic, degrees of freedom, p-value, and Cohen's *d*. Results stored in `results.roi(ri).lmeModel`, `.anova_stats`, `.tresult`.

---

### `run_overlap_statistics(results, cfg)`
Fits a single LME across all ROIs and hemispheres:

```
Jaccard ~ Hemisphere * Surface + (1|Subjects)
```

Follow-up paired t-tests:
- LH vs. RH (averaged across surfaces)
- All pairwise ROI surface comparisons (averaged across hemispheres)

Results stored in `results.overlap_lme`, `.overlap_anova`, `.overlap_ttest_hemi`, `.overlap_ttest_surface`.

---

## Outputs

```
output/<study>/
├── results_roi_analysis_<study>.mat     — results struct + cfg
├── figures_centroid_shift/
│   ├── ROI<N>_centroid_shift_<study>.png          (LH / RH subplots)
│   └── ROI<N>_centroid_shift_avg_<study>.png      (hemispheres averaged)
├── figures_polar/
│   ├── ROI<N>_polar_YZ_<study>.png/.pdf           (LH / RH subplots)
│   └── ROI<N>_polar_YZ_avg_<study>.png/.pdf       (hemispheres averaged)
├── figures_overlap/
│   ├── overlap_by_surface_<study>.png/.pdf        (LH / RH subplots)
│   └── overlap_by_surface_avg_<study>.png/.pdf    (hemispheres averaged)
└── com_rois/
    └── <subj>/<task>/
        └── <roi>.COM.<n>.lh.1D.roi / <roi>.COM.<n>.rh.1D.roi
```

The saved `.mat` file contains both the `results` struct (all matrices, statistics, model objects) and the `cfg` struct used to produce it.

---

## Missing data handling

- Missing ROI or coordinate files are caught with warnings; the corresponding subject/hemi/task entry is set to `NaN`.
- `NaN` subjects are excluded from group-mean bars but shown as absent from individual-dot overlays.
- Figures for an ROI are skipped entirely only if **all** subjects are `NaN`.
- Jaccard is `NaN` when either task's vertex set is empty (no overlap possible).
