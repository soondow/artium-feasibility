function S = generate_synthetic_rri(scenario, varargin)
%GENERATE_SYNTHETIC_RRI Phase 2 MVP용 deterministic RRI stream을 생성한다.
%
% S = generate_synthetic_rri("low_quality_artifact")는 beat 단위 timestamp,
% millisecond 단위 RRI 값, 그리고 demo 평가에만 사용하는 reference mask를
% 반환한다.

    p = inputParser;
    addRequired(p, 'scenario', @(x) ischar(x) || isstring(x));
    addParameter(p, 'DurationMinutes', 240, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'Seed', 7, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'MeanRriMs', 820, @(x) isnumeric(x) && isscalar(x) && x > 0);
    parse(p, scenario, varargin{:});

    scenario = lower(string(p.Results.scenario));
    durationMinutes = p.Results.DurationMinutes;
    meanRriMs = p.Results.MeanRriMs;

    rng(p.Results.Seed, 'twister');

    nBeats = ceil(durationMinutes * 60 / (meanRriMs / 1000) * 1.08);
    beatIndex = (1:nBeats)';

    respiratory = 28 * sin(2 * pi * beatIndex / 72);
    slowDrift = 35 * sin(2 * pi * beatIndex / max(500, round(nBeats / 3)));
    noise = 18 * randn(nBeats, 1);

    rriMs = meanRriMs + respiratory + slowDrift + noise;
    rriMs = min(max(rriMs, 520), 1180);

    trueRisk = false(nBeats, 1);
    trueLowQuality = false(nBeats, 1);

    switch scenario
        case "normal"
            label = "normal sinus-like baseline";

        case "low_quality_artifact"
            label = "low-quality artifact episode";
            artIdx = intervalMask(nBeats, 0.38, 0.62);
            trueLowQuality(artIdx) = true;

            artPositions = find(artIdx);
            nArt = numel(artPositions);
            missingIdx = artPositions(randperm(nArt, round(0.25 * nArt)));
            rriMs(missingIdx) = NaN;

            remaining = artPositions(~ismember(artPositions, missingIdx));
            spikeIdx = remaining(randperm(numel(remaining), round(0.25 * numel(remaining))));
            spikeSign = 2 * (rand(numel(spikeIdx), 1) > 0.5) - 1;
            rriMs(spikeIdx) = rriMs(spikeIdx) + spikeSign .* (720 + 520 * rand(numel(spikeIdx), 1));
            rriMs(spikeIdx) = min(max(rriMs(spikeIdx), 220), 2380);

            jumpIdx = remaining(randperm(numel(remaining), round(0.15 * numel(remaining))));
            rriMs(jumpIdx) = rriMs(jumpIdx) + 680 * sin((1:numel(jumpIdx))');
            rriMs(jumpIdx) = min(max(rriMs(jumpIdx), 220), 2380);

        case "high_risk_irregular"
            label = "high-risk irregular episode";
            riskIdx = intervalMask(nBeats, 0.44, 0.67);
            trueRisk(riskIdx) = true;

            k = (1:nnz(riskIdx))';
            irregularPattern = 820 + 170 * randn(nnz(riskIdx), 1) + 135 * sin(2 * pi * k / 3);
            shortLong = 115 * ((mod(k, 2) * 2) - 1);
            rriMs(riskIdx) = irregularPattern + shortLong;
            rriMs(riskIdx) = min(max(rriMs(riskIdx), 410), 1540);

            mildMotionIdx = intervalMask(nBeats, 0.24, 0.31);
            trueLowQuality(mildMotionIdx) = true;
            motionPositions = find(mildMotionIdx);
            nMotion = numel(motionPositions);
            motionMissing = motionPositions(randperm(nMotion, round(0.22 * nMotion)));
            rriMs(motionMissing) = NaN;

            motionRemaining = motionPositions(~ismember(motionPositions, motionMissing));
            motionSpike = motionRemaining(randperm(numel(motionRemaining), round(0.25 * numel(motionRemaining))));
            motionSpikeSign = 2 * (rand(numel(motionSpike), 1) > 0.5) - 1;
            rriMs(motionSpike) = rriMs(motionSpike) + motionSpikeSign .* (650 + 420 * rand(numel(motionSpike), 1));
            rriMs(motionSpike) = min(max(rriMs(motionSpike), 230), 2320);

        case "missing_burst"
            label = "missing coverage burst";
            burstIdx = intervalMask(nBeats, 0.42, 0.58);
            trueLowQuality(burstIdx) = true;
            burstPositions = find(burstIdx);
            nBurst = numel(burstPositions);

            missingIdx = burstPositions(randperm(nBurst, round(0.62 * nBurst)));
            rriMs(missingIdx) = NaN;

            remaining = burstPositions(~ismember(burstPositions, missingIdx));
            if ~isempty(remaining)
                spikeIdx = remaining(randperm(numel(remaining), round(0.16 * numel(remaining))));
                spikeSign = 2 * (rand(numel(spikeIdx), 1) > 0.5) - 1;
                rriMs(spikeIdx) = rriMs(spikeIdx) + spikeSign .* (680 + 380 * rand(numel(spikeIdx), 1));
                rriMs(spikeIdx) = min(max(rriMs(spikeIdx), 230), 2320);
            end

        case "near_threshold_noise"
            label = "near-threshold noisy risk observation";
            firstCenter = round(0.22 * nBeats);
            lastCenter = round(0.78 * nBeats);
            burstCenters = round(linspace(firstCenter, lastCenter, 7));
            burstLength = 90;

            for b = 1:numel(burstCenters)
                first = max(1, burstCenters(b) - floor(burstLength / 2));
                last = min(nBeats, first + burstLength - 1);
                idx = first:last;
                k = (1:numel(idx))';
                nearThresholdPattern = meanRriMs ...
                    + 70 * sin(2 * pi * k / 5) ...
                    + 42 * sin(2 * pi * k / 17) ...
                    + 22 * randn(numel(idx), 1);
                rriMs(idx) = nearThresholdPattern;
            end

            rriMs = min(max(rriMs, 520), 1180);

        otherwise
            error('Unknown scenario: %s', scenario);
    end

    timeSec = cumsum(fillmissing(rriMs, 'constant', meanRriMs)) / 1000;
    keep = timeSec <= durationMinutes * 60;

    S = struct();
    S.scenario = scenario;
    S.label = label;
    S.time_sec = timeSec(keep);
    S.rri_ms = rriMs(keep);
    S.true_risk = trueRisk(keep);
    S.true_low_quality = trueLowQuality(keep);
end

function mask = intervalMask(n, startFrac, endFrac)
    first = max(1, round(startFrac * n));
    last = min(n, round(endFrac * n));
    mask = false(n, 1);
    mask(first:last) = true;
end
