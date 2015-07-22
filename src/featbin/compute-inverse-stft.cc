// featbin/stft-to-wav.cc

// Copyright 2009-2012  Microsoft Corporation
//                      Johns Hopkins University (author: Daniel Povey)
// Hakan Erdogan

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

#include "base/kaldi-common.h"
#include "util/common-utils.h"
#include "feat/inverse-stft.h"
#include "feat/wave-reader.h"
//#include "matrix/kaldi-matrix.h"

int main(int argc, char *argv[]) {
  try {
    using namespace kaldi;
    const char *usage =
        "Convert stft feature files to wave files by inverse fft and overlap-add.\n"
        "Usage:  stft-to-wav [options...] <feats-rspecifier> <wav-wspecifier>\n";

    // construct all the global objects
    ParseOptions po(usage);
    StftOptions stft_opts;
    // Define defaults for gobal options

    // Register the option struct
    stft_opts.Register(&po);
    // Register the options

    // OPTION PARSING ..........................................................
    //

    // parse options (+filling the registered variables)
    po.Read(argc, argv);

    if (po.NumArgs() != 2) {
      po.PrintUsage();
      exit(1);
    }

    std::string feats_rspecifier = po.GetArg(1);

    std::string wav_wspecifier = po.GetArg(2);

    Istft istft(stft_opts);

    SequentialBaseFloatMatrixReader reader(feats_rspecifier);

    TableWriter<WaveHolder> writer(wav_wspecifier);

    //BaseFloat samp_freq = stft_opts.frame_opts.samp_freq;
    //int32 frame_shift_samp = static_cast<int32>(samp_freq * 0.001 * stft_opts.frame_opts.frame_shift_ms);
    
    int32 num_utts = 0, num_success = 0;
    for (; !reader.Done(); reader.Next()) {
      num_utts++;
      std::string utt = reader.Key();
      Matrix<BaseFloat> stftdata_matrix(reader.Value());
      //int32 num_frames = stftdata_matrix.NumCols();
      //int32 window_size = stftdata_matrix.NumRows();
      //int32 wav_length = frame_shift_samp * (num_frames-1) + window_size;

      Matrix<BaseFloat> wave_vector; // no init here, Matrix with single row because WaveData uses that
      istft.Compute(stftdata_matrix, &wave_vector);

      //wavdata_matrix.SetZero(); // initialize to zeros
      // fill in the matrix from inverse stft and overlap-add

      WaveData wave(samp_freq, wave_vector);
      writer.Write(utt, wave); // write data in wave format.
      num_success++;

    }
  return 0;
  } catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}
