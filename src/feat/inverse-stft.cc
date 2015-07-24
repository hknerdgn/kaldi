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
                    Matrix<BaseFloat> *wave_out,
                    int32 wav_length) {
    KALDI_ASSERT(wave_out != NULL);

    int32 num_frames = input.NumRows();
    int32 input_feat_size = input.NumCols();
    int32 window_size = opts_.frame_opts.PaddedWindowSize();
    int32 frame_length = opts_.frame_opts.WindowSize();
    BaseFloat samp_freq = opts_.frame_opts.samp_freq;
    int32 frame_shift_samp = static_cast<int32>(samp_freq * 0.001 * opts_.frame_opts.frame_shift_ms);

    if (wav_length < 0) wav_length = frame_shift_samp * (num_frames-1) + window_size;

    // Get dimensions of output wav and allocate space
    wave_out->Resize(1,wav_length); // write single channel, so single row
    wave_out->SetZero(); // set to zero to initialize overlap-add correctly

    KALDI_ASSERT(window_size+2 == input_feat_size);
    KALDI_ASSERT(opts_.output_type == "real_and_imaginary" || opts_.output_type == "amplitude_and_phase");

    int32 Nfft = input.NumCols()-2; // also equal to window_size

    // Compute from all the frames, r is frame index..
    for (int32 r = 0; r < num_frames; r++) {

        Vector<BaseFloat> temp(Nfft);

        // convert from layouts to standard fft layout which is as follows
        // DC, Nyquist, RE, IM, RE, IM, ...
        int32 k=2;
        if (opts_.output_layout == "block") {
            if (opts_.output_type == "amplitude_and_phase") {
                temp(0)=input(r,0) * std::cos(input(r,Nfft/2+1));
                temp(1)=input(r,Nfft/2) * std::cos(input(r,Nfft+1));
                for (int32 i=1; i<Nfft/2-1; i++) { // start with first nonzero freq. at position 1
                    temp(k++)=input(r,i) * std::cos(input(r,i+Nfft/2+1));
                    temp(k++)=input(r,i) * std::sin(input(r,i+Nfft/2+1));
                }
            } else {
                temp(0)=input(r,0);
                temp(1)=input(r,Nfft/2);
                for (int32 i=1; i<Nfft/2-1; i++) { // start with first nonzero freq. at position 1
                    temp(k++)=input(r,i);
                    temp(k++)=input(r,i+Nfft/2+1);
                }
            }
        } else if (opts_.output_layout == "interleaved") {
            if (opts_.output_type == "amplitude_and_phase") {
                temp(0)=input(r,0) * std::cos(input(r,1));
                temp(1)=input(r,Nfft) * std::cos(input(r,Nfft+1));
                for (int32 i=2; i<Nfft-1; i+=2) { // start with first nonzero freq. now at position 2 (due to interlaved)
                    temp(k++)=input(r,i) * std::cos(input(r,i+1));
                    temp(k++)=input(r,i) * std::sin(input(r,i+1));
                }
            } else {
                temp(0)=input(r,0);
                temp(1)=input(r,Nfft);
                for (int32 i=2; i<Nfft-1; i+=2) { // start with first nonzero freq. now at position 2 (due to interleaved)
                    temp(k++)=input(r,i);
                    temp(k++)=input(r,i+1);
                }
            }
        }

        if (srfft_ != NULL)  // Compute inverse FFT using split-radix algorithm.
            srfft_->Compute(temp.Data(), false);
        else  // An alternative algorithm that works for non-powers-of-two
            RealFft(&temp, false);
        temp.Scale(1/static_cast<BaseFloat>(Nfft)); // inverse fft does not do 1/Nfft
        int32 start = r*frame_shift_samp;
        if (!opts_.frame_opts.snip_edges)
            start = -frame_length/2+frame_shift_samp/2+r*frame_shift_samp;
        OverlapAdd(temp, start, wav_length, opts_.frame_opts, feature_window_function_, wave_out);
    }
} //Istft::Compute
}  // namespace kaldi
