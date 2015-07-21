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
#include "feat/feature-stft.h"
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
    bool subtract_mean = false;
    int32 channel = -1;
    BaseFloat min_duration = 0.0;
    // Define defaults for gobal options
    std::string output_format = "kaldi";

    // Register the option struct
    stft_opts.Register(&po);
    // Register the options
    po.Register("output-format", &output_format, "Format of the output files [kaldi, htk]");
    po.Register("subtract-mean", &subtract_mean, "Subtract mean of each feature file [CMS]; not recommended to do it this way. ");
    po.Register("channel", &channel, "Channel to extract (-1 -> expect mono, 0 -> left, 1 -> right)");
    po.Register("min-duration", &min_duration, "Minimum duration of segments to process (in seconds).");

    // OPTION PARSING ..........................................................
    //

    // parse options (+filling the registered variables)
    po.Read(argc, argv);

    if (po.NumArgs() != 2) {
      po.PrintUsage();
      exit(1);
    }

    std::string wav_rspecifier = po.GetArg(1);

    std::string output_wspecifier = po.GetArg(2);

    Stft stft(stft_opts);

    SequentialTableReader<WaveHolder> reader(wav_rspecifier);
    BaseFloatMatrixWriter kaldi_writer;  // typedef to TableWriter<something>.
    TableWriter<HtkMatrixHolder> htk_writer;

    if (output_format == "kaldi") {
      if (!kaldi_writer.Open(output_wspecifier))
        KALDI_ERR << "Could not initialize output with wspecifier "
                  << output_wspecifier;
    } else if (output_format == "htk") {
      if (!htk_writer.Open(output_wspecifier))
        KALDI_ERR << "Could not initialize output with wspecifier "
                  << output_wspecifier;
    } else {
      KALDI_ERR << "Invalid output_format string " << output_format;
    }

    int32 num_utts = 0, num_success = 0;
    for (; !reader.Done(); reader.Next()) {
      num_utts++;
      std::string utt = reader.Key();
      const WaveData &wave_data = reader.Value();
      if (wave_data.Duration() < min_duration) {
        KALDI_WARN << "File: " << utt << " is too short ("
                   << wave_data.Duration() << " sec): producing no output.";
        continue;
      }
      int32 num_chan = wave_data.Data().NumRows(), this_chan = channel;
      {  // This block works out the channel (0=left, 1=right...)
        KALDI_ASSERT(num_chan > 0);  // should have been caught in
        // reading code if no channels.
        if (channel == -1) {
          this_chan = 0;
          if (num_chan != 1)
            KALDI_WARN << "Channel not specified but you have data with "
                       << num_chan  << " channels; defaulting to zero";
        } else {
          if (this_chan >= num_chan) {
            KALDI_WARN << "File with id " << utt << " has "
                       << num_chan << " channels but you specified channel "
                       << channel << ", producing no output.";
            continue;
          }
        }
      }

      if (stft_opts.frame_opts.samp_freq != wave_data.SampFreq())
        KALDI_ERR << "Sample frequency mismatch: you specified "
                  << stft_opts.frame_opts.samp_freq << " but data has "
                  << wave_data.SampFreq() << " (use --sample-frequency "
                  << "option).  Utterance is " << utt;

      SubVector<BaseFloat> waveform(wave_data.Data(), this_chan);
      Matrix<BaseFloat> features;
      try {
        stft.Compute(waveform, &features, NULL);
      } catch (...) {
        KALDI_WARN << "Failed to compute features for utterance "
                   << utt;
        continue;
      }
      if (subtract_mean) {
        Vector<BaseFloat> mean(features.NumCols());
        mean.AddRowSumMat(1.0, features);
        mean.Scale(1.0 / features.NumRows());
        for (int32 i = 0; i < features.NumRows(); i++)
          features.Row(i).AddVec(-1.0, mean);
      }
      if (output_format == "kaldi") {
        kaldi_writer.Write(utt, features);
      } else {
        std::pair<Matrix<BaseFloat>, HtkHeader> p;
        p.first.Resize(features.NumRows(), features.NumCols());
        p.first.CopyFromMat(features);
        int32 frame_shift = stft_opts.frame_opts.frame_shift_ms * 10000;
        HtkHeader header = {
          features.NumRows(),
          frame_shift,
          static_cast<int16>(sizeof(float)*features.NumCols()),
          007 | 020000
        };
        p.second = header;
        htk_writer.Write(utt, p);
      }
      if(num_utts % 10 == 0)
        KALDI_LOG << "Processed " << num_utts << " utterances";
      KALDI_VLOG(2) << "Processed features for key " << utt;
      num_success++;
    }
    KALDI_LOG << " Done " << num_success << " out of " << num_utts
              << " utterances.";
    return (num_success != 0 ? 0 : 1);
  } catch(const std::exception& e) {
    std::cerr << e.what();
    return -1;
  }
  return 0;
}

int main(int argc, char *argv[]) {
  try {
    using namespace kaldi;

    const char *usage =
        "Apply transform (e.g. LDA; HLDA; fMLLR/CMLLR; MLLT/STC)\n"
        "Linear transform if transform-num-cols == feature-dim, affine if\n"
        "transform-num-cols == feature-dim+1 (->append 1.0 to features)\n"
        "Per-utterance by default, or per-speaker if utt2spk option provided\n"
        "Global if transform-rxfilename provided.\n"
        "Usage: transform-feats [options] (<transform-rspecifier>|<transform-rxfilename>) <feats-rspecifier> <feats-wspecifier>\n"
        "See also: transform-vec, copy-feats, compose-transforms\n";
        
    ParseOptions po(usage);
    std::string utt2spk_rspecifier;
    po.Register("utt2spk", &utt2spk_rspecifier, "rspecifier for utterance to speaker map");

    po.Read(argc, argv);

    if (po.NumArgs() != 3) {
      po.PrintUsage();
      exit(1);
    }

    std::string transform_rspecifier_or_rxfilename = po.GetArg(1);
    std::string feat_rspecifier = po.GetArg(2);
    std::string feat_wspecifier = po.GetArg(3);

    SequentialBaseFloatMatrixReader feat_reader(feat_rspecifier);
    BaseFloatMatrixWriter feat_writer(feat_wspecifier);

    RandomAccessBaseFloatMatrixReaderMapped transform_reader;
    bool use_global_transform;
    Matrix<BaseFloat> global_transform;
    if (ClassifyRspecifier(transform_rspecifier_or_rxfilename, NULL, NULL)
       == kNoRspecifier) {
      // not an rspecifier -> interpret as rxfilename....
      use_global_transform = true;
      ReadKaldiObject(transform_rspecifier_or_rxfilename, &global_transform);
    } else {  // an rspecifier -> not a global transform.
      use_global_transform = false;
      if (!transform_reader.Open(transform_rspecifier_or_rxfilename,
                                 utt2spk_rspecifier)) {
        KALDI_ERR << "Problem opening transforms with rspecifier "
                  << '"' << transform_rspecifier_or_rxfilename << '"'
                  << " and utt2spk rspecifier "
                  << '"' << utt2spk_rspecifier << '"';
      }
    }

    enum { Unknown, Logdet, PseudoLogdet, DimIncrease };
    int32 logdet_type = Unknown;
    double tot_t = 0.0, tot_logdet = 0.0;  // to compute average logdet weighted by time...
    int32 num_done = 0, num_error = 0;
    BaseFloat cached_logdet = -1;
    
    for (;!feat_reader.Done(); feat_reader.Next()) {
      std::string utt = feat_reader.Key();
      const Matrix<BaseFloat> &feat(feat_reader.Value());

      if (!use_global_transform && !transform_reader.HasKey(utt)) {
        KALDI_WARN << "No fMLLR transform available for utterance "
                   << utt << ", producing no output for this utterance";
        num_error++;
        continue;
      }
      const Matrix<BaseFloat> &trans =
          (use_global_transform ? global_transform : transform_reader.Value(utt));
      int32 transform_rows = trans.NumRows(),
          transform_cols = trans.NumCols(),
          feat_dim = feat.NumCols();

      Matrix<BaseFloat> feat_out(feat.NumRows(), transform_rows);

      if (transform_cols == feat_dim) {
        feat_out.AddMatMat(1.0, feat, kNoTrans, trans, kTrans, 0.0);
      } else if (transform_cols == feat_dim + 1) {
        // append the implicit 1.0 to the input features.
        SubMatrix<BaseFloat> linear_part(trans, 0, transform_rows, 0, feat_dim);
        feat_out.AddMatMat(1.0, feat, kNoTrans, linear_part, kTrans, 0.0);
        Vector<BaseFloat> offset(transform_rows);
        offset.CopyColFromMat(trans, feat_dim);
        feat_out.AddVecToRows(1.0, offset);
      } else {
        KALDI_WARN << "Transform matrix for utterance " << utt << " has bad dimension "
                   << transform_rows << "x" << transform_cols << " versus feat dim "
                   << feat_dim;
        if (transform_cols == feat_dim+2)
          KALDI_WARN << "[perhaps the transform was created by compose-transforms, "
              "and you forgot the --b-is-affine option?]";
        num_error++;
        continue;
      }
      num_done++;

      if (logdet_type == Unknown) {
        if (transform_rows == feat_dim) logdet_type = Logdet;  // actual logdet.
        else if (transform_rows < feat_dim) logdet_type = PseudoLogdet;  // see below
        else logdet_type = DimIncrease;  // makes no sense to have any logdet.
        // PseudoLogdet is if we have a dimension-reducing transform T, we compute
        // 1/2 logdet(T T^T).  Why does this make sense?  Imagine we do MLLT after
        // LDA and compose the transforms; the MLLT matrix is A and the LDA matrix is L,
        // so T = A L.  T T^T = A L L^T A, so 1/2 logdet(T T^T) = logdet(A) + 1/2 logdet(L L^T).
        // since L L^T is a constant, this is valid for comparing likelihoods if we're
        // just trying to see if the MLLT is converging.
      }

      if (logdet_type != DimIncrease) { // Accumulate log-determinant stats.
        SubMatrix<BaseFloat> linear_transform(trans, 0, trans.NumRows(), 0, feat_dim);
        // "linear_transform" is just the linear part of any transform, ignoring
        // any affine (offset) component.
        SpMatrix<BaseFloat> TT(trans.NumRows());
        // TT = linear_transform * linear_transform^T
        TT.AddMat2(1.0, linear_transform, kNoTrans, 0.0);
        BaseFloat logdet;
        if (use_global_transform) {
          if (cached_logdet == -1)
            cached_logdet = 0.5 * TT.LogDet(NULL);
          logdet = cached_logdet;
        } else {
          logdet = 0.5 * TT.LogDet(NULL);
        }
        if (logdet != logdet || logdet-logdet != 0.0) // NaN or info.
          KALDI_WARN << "Matrix has bad logdet " << logdet;
        else {
          tot_t += feat.NumRows();
          tot_logdet += feat.NumRows() * logdet;
        }
      }
      feat_writer.Write(utt, feat_out);
    }
    if (logdet_type != Unknown && logdet_type != DimIncrease)
      KALDI_LOG << "Overall average " << (logdet_type == PseudoLogdet ? "[pseudo-]":"")
                << "logdet is " << (tot_logdet/tot_t) << " over " << tot_t
                << " frames.";
    KALDI_LOG << "Applied transform to " << num_done << " utterances; " << num_error
              << " had errors.";

    return (num_done != 0 ? 0 : 1);
  } catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}
