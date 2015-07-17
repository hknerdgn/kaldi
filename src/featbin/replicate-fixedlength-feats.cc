// featbin/subsample-feats.cc

// Copyright 2012-2014  Johns Hopkins University (author: Daniel Povey)

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

#include <sstream>
#include <algorithm>
#include <iterator>
#include <utility>

#include "base/kaldi-common.h"
#include "util/common-utils.h"
#include "matrix/kaldi-matrix.h"


int main(int argc, char *argv[]) {
  try {
    using namespace kaldi;
    using namespace std;
    
    const char *usage =
        "Replicates or up-samples fixed number of features per utterance as many times as given in the second argument per utterance."
        "Second argument is an scp/ark file which has the number of repetitions (as int32) per utterance."
        "Second argument can be obtained using feat-len command on a feats.scp/ark file."
        "\n"
        "Usage: replicate-fixedlength-feats <in-rspecifier1> <in-rspecifier2> <out-wspecifier>\n"
        "  e.g. replicate-fixedlength-feats ark:- ark:- ark:-\n";
    
    ParseOptions po(usage);
    
    int32 n = 1, offset = 0;

    po.Register("n", &n, "Take every n'th feature, for this value of n"
                "(with negative value, repeats each feature n times)");
    po.Register("offset", &offset, "Start with the feature with this offset, "
                "then take every n'th feature.");

    KALDI_ASSERT(n != 0);
    if (n < 0)
      KALDI_ASSERT(offset == 0 &&
                   "--offset option cannot be used with negative n.");
    
    po.Read(argc, argv);
    
    if (po.NumArgs() != 2) {
      po.PrintUsage();
      exit(1);
    }    

    string rspecifier = po.GetArg(1);
    string wspecifier = po.GetArg(2);
    
    SequentialBaseFloatMatrixReader feat_reader(rspecifier);
    BaseFloatMatrixWriter feat_writer(wspecifier);

    int32 num_done = 0, num_err = 0;
    int64 frames_in = 0, frames_out = 0;
    
    // process all keys
    for (; !feat_reader.Done(); feat_reader.Next()) {
      std::string utt = feat_reader.Key();
      const Matrix<BaseFloat> feats(feat_reader.Value());


      if (n > 0) {
        // This code could, of course, be much more efficient; I'm just
        // keeping it simple.
        int32 num_indexes = 0;
        for (int32 k = offset; k < feats.NumRows(); k += n)
          num_indexes++; // k is the index.

        frames_in += feats.NumRows();
        frames_out += num_indexes;
      
        if (num_indexes == 0) {
          KALDI_WARN << "For utterance " << utt << ", output would have no rows, "
                     << "producing no output.";
          num_err++;
          continue;
        }
        Matrix<BaseFloat> output(num_indexes, feats.NumCols());
        int32 i = 0;
        for (int32 k = offset; k < feats.NumRows(); k += n, i++) {
          SubVector<BaseFloat> src(feats, k), dest(output, i);
          dest.CopyFromVec(src);
        }
        KALDI_ASSERT(i == num_indexes);
        feat_writer.Write(utt, output);
        num_done++;
      } else {
        int32 repeat = -n;
        Matrix<BaseFloat> output(feats.NumRows() * repeat, feats.NumCols());
        for (int32 i = 0; i < output.NumRows(); i++)
          output.Row(i).CopyFromVec(feats.Row(i / repeat));
        frames_in += feats.NumRows();
        frames_out += feats.NumRows() * repeat;
        feat_writer.Write(utt, output);        
        num_done++;
      }
    }
    KALDI_LOG << "Processed " << num_done << " feature matrices; " << num_err
              << " with errors.";
    KALDI_LOG << "Processed " << frames_in << " input frames and "
              << frames_out << " output frames.";
    return (num_done != 0 ? 0 : 1);
  } catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}
