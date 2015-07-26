// feat/stft-functions.h

// Copyright 2015 Hakan Erdogan

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

#ifndef KALDI_FEAT_STFT_FUNCTIONS_H_
#define KALDI_FEAT_STFT_FUNCTIONS_H_

#include <string>
#include <vector>

#include "matrix/matrix-lib.h"
#include "util/common-utils.h"
#include "base/kaldi-error.h"
#include "feat/mel-computations.h"
#include "feat/feature-functions.h"

namespace kaldi {
/// @addtogroup  feat FeatureExtraction
/// @{


// OverlapAdd aims to reverse ExtractWindow to reconstruct a wave signal
// OverlapAdd accumulates the waveform from a windowed frame.
// It attempts to reverse pre-emphasis but cannot reverse dither or DC removal
void OverlapAdd(const VectorBase<BaseFloat> &window,
                int32 start,  // start index of the segment, if negative, the overlap-adding will start from zero
                int32 wav_length,  // total length, if window goes out, it will be trimmed
                const FrameExtractionOptions &opts,
                const FeatureWindowFunction &window_function,
                Matrix<BaseFloat> *wave);


/// @} End of "addtogroup feat"
}  // namespace kaldi


#endif  // KALDI_FEAT_STFT_FUNCTIONS_H_
