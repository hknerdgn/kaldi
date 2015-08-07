// featbin/channel-adapt.cc

// Copyright 2015 Hakan Erdogan, Jonathan LeRoux

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
#include "feat/signal-functions.h"
#include "feat/wave-reader.h"

int main(int argc, char *argv[]) {
    try {
        using namespace kaldi;
        const char *usage =
            "Channel-adapt wav1 files to be close to wav2 files and write to wav3 files.\n"
            "in other words: linearly predict wav2 files from wav1 files and write the predictions in wav3.\n"
            "Usage:  channel-adapt [options...] <wav1-rspecifier> <wav2-rspecifier> <wav3-wspecifier>\n";

        int32 channel = -1;
        BaseFloat min_duration = 0.0;
        int32 taps = 800;
        // construct all the global objects
        ParseOptions po(usage);
        // Define defaults for gobal options

        // Register the options
        po.Register("channel", &channel, "Channel to extract (-1 -> expect mono, 0 -> left, 1 -> right)");
        po.Register("min-duration", &min_duration, "Minimum duration of utterances to process (in seconds).");
        po.Register("taps", &taps, "Duration of FIR filter in taps.");

        // OPTION PARSING ..........................................................
        //

        // parse options (+filling the registered variables)
        po.Read(argc, argv);

        if (po.NumArgs() != 3) {
            po.PrintUsage();
            exit(1);
        }

        std::string wav1_rspecifier = po.GetArg(1);
        std::string wav2_rspecifier = po.GetArg(2);
        std::string wav3_wspecifier = po.GetArg(3);

        SequentialTableReader<WaveHolder> reader1(wav1_rspecifier);
        SequentialTableReader<WaveHolder> reader2(wav2_rspecifier);
        TableWriter<WaveHolder> writer(wav3_wspecifier);

        int32 num_utts = 0, num_success = 0;
        for (; !reader1.Done() && !reader2.Done(); reader1.Next(), reader2.Next()) {
            num_utts++;
            std::string utt1 = reader1.Key();
            std::string utt2 = reader2.Key();
            KALDI_ASSERT(utt1 == utt2);
            const WaveData &wave1_data = reader1.Value();
            const WaveData &wave2_data = reader2.Value();
            int32 samp_rate=wave1_data.SampFreq();
            if (wave1_data.Duration() < min_duration) {
                KALDI_WARN << "File: " << utt1 << " is too short ("
                           << wave1_data.Duration() << " sec): producing no output.";
                continue;
            }
            KALDI_ASSERT(wave1_data.Duration() == wave2_data.Duration());
            int32 num_chan = wave1_data.Data().NumRows(), this_chan1 = channel;
            {   // This block works out the channel (0=left, 1=right...)
                KALDI_ASSERT(num_chan > 0);  // should have been caught in
                // reading code if no channels.
                if (channel == -1) {
                    this_chan1 = 0;
                    if (num_chan != 1)
                        KALDI_WARN << "Channel not specified but you have data with "
                                   << num_chan  << " channels; defaulting to zero";
                } else {
                    if (this_chan1 >= num_chan) {
                        KALDI_WARN << "File with id " << utt1 << " has "
                                   << num_chan << " channels but you specified channel "
                                   << channel << ", producing no output.";
                        continue;
                    }
                }
            }

            SubVector<BaseFloat> waveform1(wave1_data.Data(), this_chan1);
            SubVector<BaseFloat> waveform2(wave2_data.Data(), this_chan1);
            Vector<BaseFloat> waveform3;
            Vector<BaseFloat> filter;
            ChannelConvert(waveform1,waveform2,taps,&filter,&waveform3);
            if(num_utts % 10 == 0)
                KALDI_LOG << "Processed " << num_utts << " utterances";

            // convert matrix to WaveData
            WaveData wave(samp_rate, waveform3);
            Vector<BaseFloat> diff(waveform1);
            diff.AddVec(-1.0, waveform2);
            BaseFloat diff12=diff.Norm(2); // l2 norm
            diff.CopyFromVec(waveform2);
            diff.AddVec(-1.0, waveform3);
            BaseFloat diff13=diff.Norm(2); // l2 norm
            KALDI_LOG << utt1 << " RMSE(1,2)= " << diff12 << ". RMSE(2,3)= " << diff13 << "." ;
            writer.Write(utt1, wave); // write data in wave format.
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
