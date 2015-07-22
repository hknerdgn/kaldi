// feat/inverse-stft.cc

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


#include "feat/inverse-stft.h"
#include "feat/compute-stft.h"


namespace kaldi {

Istft::Istft(const StftOptions &opts)
    : opts_(opts), feature_window_function_(opts.frame_opts), srfft_(NULL) {

    int32 padded_window_size = opts.frame_opts.PaddedWindowSize();
    if ((padded_window_size & (padded_window_size-1)) == 0)  // Is a power of two
        srfft_ = new SplitRadixRealFft<BaseFloat>(padded_window_size);
}

Istft::~Istft() {
    if (srfft_ != NULL)
        delete srfft_;
}

void Istft::Compute(const Matrix<BaseFloat> &input,
		   Matrix<BaseFloat> *wave_out) {
    KALDI_ASSERT(wave_out != NULL);

    int32 num_frames = input.NumRows();
    int32 input_feat_size = input.NumCols();
    int32 window_size = opts_.frame_opts.PaddedWindowSize();
    BaseFloat samp_freq = opts_.frame_opts.samp_freq;
    int32 frame_shift_samp = static_cast<int32>(samp_freq * 0.001 * opts_.frame_opts.frame_shift_ms);

    int32 wav_length = frame_shift_samp * (num_frames-1) + window_size;
    // Get dimensions of output wav and allocate space
    wave_out->Resize(1,wav_length); // write single channel, so single row
    wave_out->SetZero(); // set to zero to initialize overlap-add correctly

    KALDI_ASSERT(window_size+2 == input_feat_size);
    KALDI_ASSERT(opts_.output_type == "real_and_imaginary");

    // Buffers
    Vector<BaseFloat> window;  // windowed waveform.

    // Compute from all the frames, r is frame index..
    for (int32 r = 0; r < num_frames; r++) {

	window.CopyRowFromMat(input,r);
	int32 Nfft = window.Dim()-2;
	Vector<BaseFloat> temp(Nfft);

	// convert from layouts to standard fft layout
	temp(0)=window(0);
	int k=2;
	if (opts_.output_layout == "block") {
		temp(1)=window(Nfft/2);
		for (i=2;i<Nfft/2-1; i++) {
			temp(k++)=window(i);
			temp(k++)=window(i+Nfft/2+1);
		}
	} else if (opts_.output_layout == "interleaved") {
		temp(1)=window(Nfft);
		for (i=2;i<Nfft-1; i+=2) {
			temp(k++)=window(i);
			temp(k++)=window(i+1);
		}
	}

        if (srfft_ != NULL)  // Compute inverse FFT using split-radix algorithm.
            srfft_->Compute(window.Data(), false);
        else  // An alternative algorithm that works for non-powers-of-two
            RealFft(&window, false);
        OverlapAdd(window, r, opt_.frame_opts, feature_window_function_, &wave_out);
    }
} //Istft::Compute
}  // namespace kaldi
