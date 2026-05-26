function W = segment_rri_windows(S, beatsPerWindow, strideBeats)
%SEGMENT_RRI_WINDOWS Split a beat-level synthetic RRI stream into windows.

    if nargin < 2 || isempty(beatsPerWindow)
        beatsPerWindow = 60;
    end

    if nargin < 3 || isempty(strideBeats)
        strideBeats = 30;
    end

    rriMs = S.rri_ms(:);
    n = numel(rriMs);
    starts = 1:strideBeats:(n - beatsPerWindow + 1);
    nWin = numel(starts);

    windows = cell(nWin, 1);
    startSec = nan(nWin, 1);
    stopSec = nan(nWin, 1);
    trueRisk = false(nWin, 1);
    trueLowQuality = false(nWin, 1);

    for k = 1:nWin
        idx = starts(k):(starts(k) + beatsPerWindow - 1);
        windows{k} = rriMs(idx);
        startSec(k) = S.time_sec(idx(1));
        stopSec(k) = S.time_sec(idx(end));
        trueRisk(k) = mean(S.true_risk(idx)) >= 0.25;
        trueLowQuality(k) = mean(S.true_low_quality(idx)) >= 0.25;
    end

    W = table((1:nWin)', starts(:), startSec, stopSec, trueRisk, trueLowQuality, windows, ...
        'VariableNames', {'window_id', 'start_beat', 'start_sec', 'stop_sec', ...
        'true_risk', 'true_low_quality', 'rri_ms'});
end
