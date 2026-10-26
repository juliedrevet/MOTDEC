# MOTDEC

MATLAB code for:

> **Motor engagement amplifies and reformats the neural code for evidence in human auditory decisions.**
> Drevet J, Benjamin L, Morillon B (in prep.). 

## Data

- **MEG data** (Zenodo, [doi:10.5281/zenodo.23596213](https://doi.org/10.5281/zenodo.23596213)):
  - `<participant>_header.mat`: trial information;
  - `<participant>_tracking.mat` and `<participant>_listen.mat`: preprocessed epochs, [−500;+1000] ms around each tone, 200 Hz.

  Put these files in `data/meg/`, or point to their folder in `config_paths_local.m` (see Setup).
- **Trial table** (`data/motdat_data.mat`, in this repository): one row per tone, with the decoded variables (pitch, evidence strength, belief update, …). `make_table_from_header.m` rebuilds it from the header files.

## Requirements

- MATLAB (tested with R2022b), with the following toolboxes:
  - Statistics and Machine Learning Toolbox;
  - Image Processing Toolbox (cluster-based permutation tests);
  - Signal Processing and Curve Fitting Toolboxes (some plots);
  - Parallel Computing Toolbox: optional; without it, `parfor` loops run serially.
- [FieldTrip](https://www.fieldtriptoolbox.org) (Oostenveld et al., 2011), for the low-pass filter and Hilbert transform of the MEG data. The results in the manuscript were computed with the FieldTrip version distributed with [SPM12](https://www.fil.ion.ucl.ac.uk/spm/software/spm12/) (release 7487, November 2018; folder `spm12/external/fieldtrip`).
- [Bayes Factor Toolbox](https://zenodo.org/records/13744717) (Krekelberg, 2024).

## Setup

1. Clone this repository and download the MEG data (see above).
2. If the MEG data, FieldTrip or the Bayes Factor Toolbox are not in the default places, create `config_paths_local.m` in the MOTDEC folder. It is not tracked by git:

   ```matlab
   function local = config_paths_local()
   local = [];
   local.meg_dir         = '/path/to/meg/data/';
   local.fieldtrip_dir   = '/path/to/fieldtrip/';
   local.bayesfactor_dir = '/path/to/bayesFactor/';
   end
   ```

3. In MATLAB, make the MOTDEC folder the current folder and run the analyses scripts.

## Citation

If you use this code, please cite the manuscript above. The data were originally published in:

> Morillon B, Baillet S (2017). Motor origin of temporal predictions in auditory attention. *Proc Natl Acad Sci USA* 114:E8913–E8921.

## License

The code is released under the MIT License (see [`LICENSE`](LICENSE)). FieldTrip and the Bayes Factor Toolbox are not included in this repository and keep their own licenses.
