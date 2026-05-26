function F = extract_hrv_features(rriMs, validMask)
%EXTRACT_HRV_FEATURES 간결한 HRV 및 irregularity feature를 계산한다.

    if nargin < 2 || isempty(validMask)
        validMask = ~isnan(rriMs(:));
    end

    rriMs = rriMs(:);
    validMask = validMask(:) & ~isnan(rriMs);
    x = rriMs(validMask);

    F = emptyFeatureStruct();
    F.n_beats = numel(x);

    if numel(x) < 20
        F.status = "insufficient_beats";
        return;
    end

    dx = diff(x);
    meanNN = mean(x);
    sdnn = std(x, 0);
    rmssd = sqrt(mean(dx .^ 2));
    pnn50 = mean(abs(dx) > 50);
    cvRri = sdnn / meanNN;
    sd1 = rmssd / sqrt(2);
    sd2 = sqrt(max(2 * sdnn ^ 2 - 0.5 * rmssd ^ 2, 0));

    F.meanNN_ms = meanNN;
    F.SDNN_ms = sdnn;
    F.RMSSD_ms = rmssd;
    F.pNN50 = pnn50;
    F.CV_RRI = cvRri;
    F.SD1_ms = sd1;
    F.SD2_ms = sd2;
    F.irregularity_index = estimate_irregularity(F);
    F.status = "ok";
end

function F = emptyFeatureStruct()
    F = struct();
    F.n_beats = 0;
    F.meanNN_ms = NaN;
    F.SDNN_ms = NaN;
    F.RMSSD_ms = NaN;
    F.pNN50 = NaN;
    F.CV_RRI = NaN;
    F.SD1_ms = NaN;
    F.SD2_ms = NaN;
    F.irregularity_index = NaN;
    F.status = "empty";
end

function score = estimate_irregularity(F)
    rmssdTerm = sigmoid01((F.RMSSD_ms - 55) / 18);
    cvTerm = sigmoid01((F.CV_RRI - 0.075) / 0.025);
    pnnTerm = sigmoid01((F.pNN50 - 0.25) / 0.10);
    sdnnTerm = sigmoid01((F.SDNN_ms - 70) / 22);

    score = 0.35 * rmssdTerm + 0.25 * cvTerm + 0.25 * pnnTerm + 0.15 * sdnnTerm;
    score = min(max(score, 0), 1);
end

function y = sigmoid01(x)
    y = 1 ./ (1 + exp(-x));
end
