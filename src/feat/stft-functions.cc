// feat/stft-functions.cc

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


// reverses Preemphasis
// z=De_emphasis(y)
// z[n] = alpha * z[n-1] + y[n]
void Deemphasize(VectorBase<BaseFloat> *waveform, BaseFloat preemph_coeff) {
    if (preemph_coeff == 0.0) return;
    KALDI_ASSERT(preemph_coeff >= 0.0 && preemph_coeff <= 1.0);
    //(*waveform)(0) = (*waveform)(0);  // assume z[-1]=0
    for (int32 i = 1; i < waveform->Dim(); i++)
        (*waveform)(i) += preemph_coeff * (*waveform)(i-1);
}

// OverlapAdd aims to reverse ExtractWindow to reconstruct a wave signal
// OverlapAdd accumulates the waveform from a windowed frame.
// It attempts to reverse pre-emphasis but cannot reverse dither or DC removal
// typically: allocate and initialize wave to zero and call this function
// for each frame similar to ExtractWindow
void OverlapAdd(const VectorBase<BaseFloat> &window,
                int32 start,  // start sample
                int32 wav_length,  // if exceeds, will be trimmed
                const FrameExtractionOptions &opts,
                const FeatureWindowFunction &window_function,
                Matrix<BaseFloat> *wave) {
    int32 frame_shift = opts.WindowShift();
    int32 padded_frame_length = window.Dim();  // usually this is PaddedWindowSize, typically longer than frame_length
    int32 start_output = start;
    if (start_output < 0) start_output = 0;
    int32 end = start + padded_frame_length;
    if (end > wav_length) end = wav_length;
    KALDI_ASSERT(frame_shift != 0 && padded_frame_length != 0);
    KALDI_ASSERT(window_function.window.Dim() <= padded_frame_length);
    KALDI_ASSERT((*wave).NumCols() >= end);
    // factor required for perfect reconstruction
    BaseFloat factor = static_cast<BaseFloat>(frame_shift) / static_cast<BaseFloat>(window_function.window.Sum());

    Vector<BaseFloat> window_part(window);
    if (opts.preemph_coeff != 0.0)
        Deemphasize(&window_part, opts.preemph_coeff); // actually pre-emphasis and de-emphasis should be done before framing and after forming the full signal, but since it was done frame-wise in ExtractWindow function, we also revert it this way

    for (int32 k=start_output; k<end; k++)
        (*wave)(0,k) += factor * window_part(k-start); // accumulate (overlap-add) into first row of Matrix wave
}
