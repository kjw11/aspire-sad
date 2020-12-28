#!/bin/bash

. ./cmd.sh
. ./path.sh

set -e

nj=1
exp=exp
sad_work_dir=$exp/segmentation_1a
sad_nnet_dir=$sad_work_dir/tdnn_stats_sad_1a
in_data=data/data
out_data=$sad_work_dir/outdata
sad_mfcc=$out_data/mfcc

stage=3
sad_stage=0

if [ $stage -le 1 ]; then
  # nnet-based method requires high resolution feature
  # so we need to make 40-dimensional mfcc
  steps-5.4/make_mfcc.sh --nj $nj --cmd "$cmd" --write-utt2num-frames true \
                     --mfcc-config conf/mfcc_hires.conf \
                     $in_data $exp/mfcc_hires/log $exp/mfcc_hires
fi

if [ $stage -le 2 ]; then
  # Perform segmentation
  local/segmentation/detect_speech_activity.sh --nj $nj --stage $sad_stage \
    --cmd "$cmd" \
    $in_data $sad_nnet_dir $sad_mfcc $sad_work_dir \
    $out_data || exit 1
fi

if [ $stage -le 3 ]; then
  # Generate RTTM file from segmentation performed by SAD. This can   # be used to evaluate the performance of the SAD as an intermediate
  # be used to evaluate the performance of the SAD as an intermediate
  # step.
  cp $in_data/utt2spk $out_data/
  cat $out_data/segments | awk '{print $1 " " $2}' > $out_data/labels
  python local/make_rttm.py $out_data/segments $out_data/labels $out_data/rttm
  #steps/segmentation/convert_utt2spk_and_segments_to_rttm.py \
  #  ${out_data}_seg/utt2spk $out_data/segments $out_data/rttm
fi
exit 0;
if [ $stage -le 4 ]; then
  # Calculate Miss/FA
  perl local/md-eval.pl -1 -c 0.25 -r trans.rttm -s $out_data/rttm > results.txt
fi
