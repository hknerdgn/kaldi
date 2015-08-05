// feat/signal-functions.cc

// Copyright 2015  Hakan Erdogan   Jonathan Le Roux

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

#include "feat/signal-functions.h"
#include "matrix/toeplitz.h"
# include <algorithm>

namespace kaldi {

  // find best filter h that linearly converts vector a to be closer to vector b, leading to vector outpout
  void ChannelConvert(const Vector<BaseFloat> &a,
		      const Vector<BaseFloat> &b,
		      const int32 &taps,
		      Vector<BaseFloat> *h,
		      Vector<BaseFloat> *output) {
    int32 adim = a.Dim();
    int32 bdim = b.Dim();

    KALDI_ASSERT(adim > 0 && bdim > 0);
    KALDI_ASSERT(adim > taps);
    output->Resize(adim);
    h->Resize(taps);
    
    // get next power of 2
    int32 padded_size = 1;
    int32 value = 2 * std::max(adim,bdim); // factor 2 to avoid edge effects
    while (padded_size < value) padded_size <<= 1;
    SplitRadixRealFft<BaseFloat> *srfft;
    srfft = new SplitRadixRealFft<BaseFloat>(padded_size);

    // initialize FFT vectors 
    Vector<BaseFloat> af(padded_size); 
    Vector<BaseFloat> bf(padded_size); 
    
    for (int i=0; i< adim; i++) 
      af(i)=a(i);
    for (int i=0; i< bdim; i++) 
      bf(i)=b(i);

    // perform FFT
    srfft->Compute(af.Data(), true);
    srfft->Compute(bf.Data(), true);

    // get the auto-correlation of a
    Vector<BaseFloat> a_corr(padded_size); 
    a_corr(0) = std::pow(abs(af(0)),2);
    a_corr(1) = std::pow(abs(af(1)),2);
    for (int i=2; i< padded_size; i+=2) 
      a_corr(i) = std::pow(abs(af(i)),2) + std::pow(abs(af(i+1)),2);
    srfft->Compute(a_corr.Data(), false);
    a_corr.Scale(1/static_cast<BaseFloat>(padded_size));
	
    // get the cross-correlation of a and b
    Vector<BaseFloat> ab_corr(padded_size); 
    ab_corr(0) = af(0) * bf(0);
    ab_corr(1) = af(1) * bf(1);
    for (int i=2; i< padded_size; i+=2){ 
      ab_corr(i)   = af(i)   * bf(i) + af(i+1) * bf(i+1);
      ab_corr(i+1) = af(i+1) * bf(i) - af(i)   * bf(i+1);
    }
    srfft->Compute(ab_corr.Data(), false);
    ab_corr.Scale(1/static_cast<BaseFloat>(padded_size));

    // solve for the optimal filter
    Vector<BaseFloat> rvec(taps); 
    Vector<BaseFloat> yvec(taps); 
    for (int i=0; i< taps; i++) {
      rvec(i) =  a_corr(i);
      yvec(i) = ab_corr(i);
    }

    toeplitz_solve(rvec, rvec, yvec, h);

    // convolve input with filter to get the output
    Vector<BaseFloat> hf(padded_size); 
    for (int i=0; i<taps ; i++) 
      hf(i)=(*h)(i);
    srfft->Compute(hf.Data(), true);
    Vector<BaseFloat> xh(padded_size); 
    xh(0) = af(0) * hf(0);
    xh(1) = af(1) * hf(1);
    for (int i=2; i< padded_size; i+=2){ 
      xh(i)   = af(i)   * hf(i) - af(i+1) * hf(i+1);
      xh(i+1) = af(i+1) * hf(i) + af(i)   * hf(i+1);
    }
    srfft->Compute(xh.Data(), false);
    xh.Scale(1/static_cast<BaseFloat>(padded_size));
    for (int i=0; i< adim; i++) 
      (*output)(i)=xh(i);
    

  }

}  // namespace kaldi
