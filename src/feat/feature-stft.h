// feat/feature-stft.h

// Copyright 2015  Hakan Erdogan

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
  std::string output_type; // "real_and_imaginary", "amplitude_and_phase", "amplitude", "phase"
  std::string output_layout; // layout == "block" then len=N+2, that is RE, IM, RE, IM, ...
			     // layout == "interleaved" then len=N+2, RE, RE, ..., IM, IM, ...

  StftOptions() :
    output_type("real_and_imaginary"),
    output_layout("block") { }
    

  void Register(OptionsItf *po) {
    frame_opts.Register(po);
    po->Register("output-type", &output_type,
                 "Valid types are real_and_imaginary (default), amplitude_and_phase, amplitude, phase");
    po->Register("output-layout", &output_layout,
                 "block: RE RE ... IM IM ... , interleaved: RE IM RE IM ...");
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
