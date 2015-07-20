// feat/feature-stft.h

// Copyright 2009-2012  Karel Vesely
// Copyright 2012  Navdeep Jaitly

// See ../../COPYING for clarification regarding multiple authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
// THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
// WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
// MERCHANTABLITY OR NON-INFRINGEMENT.
// See the Apache 2 License for the specific language governing permissions and
// limitations under the License.

#ifndef KALDI_FEAT_FEATURE_STFT_H_
#define KALDI_FEAT_FEATURE_STFT_H_


#include <string>

#include "feat/feature-functions.h"

namespace kaldi {
/// @addtogroup  feat FeatureExtraction
/// @{


/// StftOptions contains basic options for computing STFT features
/// It only includes things that can be done in a "stateless" way, i.e.
/// it does not include energy max-normalization.
/// It does not include delta computation.
struct StftOptions {
  FrameExtractionOptions frame_opts;
  BaseFloat log_floor; // floor for log(value) in log domain, used only for log outputs
  bool cut_dc; // do not output DC frequency value X[0]
  bool cut_nyquist; // do not output Nyquist frequency value X[1]
  bool add_log_energy; // add log(energy) as last feature
  bool raw_energy; // use raw energy before windowing
  std::string output_type; // "real_and_imaginary", "amplitude_and_phase", "amplitude", "phase"
  std::string amplitude_nonlinearity; // "none", "log", "power"
  BaseFloat amplitude_nonlinearity_param; // logbase or power
  bool block_output; // default order is interleaved, that is DC, NYQUIST, RE, IM, RE, IM, ..., if block=true then DC, NYQUIST, RE, RE, ..., IM, IM, ...
  bool add_amplitude_pnorm; // add p-norm of amplitude vector as last feature (before energy if exists) after applying amplitude nonlinearity
  bool normalize_amplitude; // normalize vector after nonlinearity
  BaseFloat normalization_param; // p value for p-norm, use 0 for max norm (inf-norm)

  StftOptions() :
    log_floor(-30),  // in log scale: a small value e.g. 1.0e-10
    cut_dc(false),
    cut_nyquist(false),
    add_log_energy(false),
    raw_energy(true),
    output_type("real_and_imaginary"),
    amplitude_nonlinearity("none"),
    amplitude_nonlinearity_param(10),
    block_output(false),
    add_amplitude_pnorm(false),
    normalize_amplitude(false),
    normalization_param(1.0) { }
    

  void Register(OptionsItf *po) {
    frame_opts.Register(po);
    po->Register("log-floor", &log_floor,
                 "Floor on logarithms (in log domain) in STFT computation");
    po->Register("cut-dc", &cut_dc,
                 "Cut DC value in STFT output");
    po->Register("cut-nyquist", &cut_nyquist,
                 "Cut Nyquist frequency value in STFT output");
    po->Register("add-log-energy", &add_log_energy,
                 "Add log-energy to the end of the STFT output vector");
    po->Register("raw-energy", &raw_energy,
                 "If true, compute energy before preemphasis and windowing");
    po->Register("output-type", &output_type,
                 "Valid types are real_and_imaginary (default), amplitude_and_phase, amplitude, phase");
    po->Register("amplitude-nonlinearity", &amplitude_nonlinearity,
                 "Valid nonlinearities are none (default), log, power");
    po->Register("amplitude-nonlinearity-param", &amplitude_nonlinearity_param,
                 "log base or power value");
    po->Register("block-output", &block_output,
                 "If true, change order of output from: DC, NYQUIST, RE, IM, RE, IM, ... to DC, NYQUIST, RE, RE, ..., IM, IM, ...");
    po->Register("add-amplitude-pnorm", &add_amplitude_pnorm,
                 "If true, add p-norm of the amplitude vector (after applying nonlinearity) at the end of the feature vector but before log-energy feature");
    po->Register("normalize-amplitude", &normalize_amplitude,
                 "If true, normalize amplitude vector by dividing by its p-norm value");
    po->Register("normalization-param", &normalization_param,
                 "Value of p for the p-norm, enter 0 for max (or infinity) norm, default 1");
  }
};

/// Class for computing STFT features; see \ref feat_mfcc for more information.
class Stft {
 public:
  explicit Stft(const StftOptions &opts);
  ~Stft();

  /// Will throw exception on failure (e.g. if file too short for
  /// even one frame).
  void Compute(const VectorBase<BaseFloat> &wave,
               Matrix<BaseFloat> *output,
               Vector<BaseFloat> *wave_remainder = NULL);

 private:
  StftOptions opts_;
  BaseFloat log_energy_floor_;
  FeatureWindowFunction feature_window_function_;
  SplitRadixRealFft<BaseFloat> *srfft_;
  KALDI_DISALLOW_COPY_AND_ASSIGN(Stft);
};


/// @} End of "addtogroup feat"
}  // namespace kaldi


#endif  // KALDI_FEAT_FEATURE_STFT_H_
