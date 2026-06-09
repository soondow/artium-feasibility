function S = generate_synthetic_rri(scenario, varargin)
% 함수 설명:
%   Phase 2 검증에 사용할 정상, 인공물, 고위험, 결측, 경계 잡음 합성 RRI 시나리오를 생성합니다.
%
% 입력:
%   scenario (문자열, 비어 있을 수 없음: 생성하거나 실행할 시나리오 이름입니다.)
%   varargin (가변 인자 목록, 비어 있을 수 있음: 이름-값 형식의 선택 파라미터입니다.)
%
% 출력:
%   S (구조체 또는 테이블: 함수 목적에 따른 합성 신호, MSPC 점수, 또는 요약 결과를 담습니다.)
%
% 예외:
%   지원하지 않는 시나리오 이름이 전달되거나 인자 검증 조건을 만족하지 못하면 예외가 발생합니다.
%
% 처리 절차:
%   1. 기준 RRI에 호흡성 변동, 장기 표류, 난수 잡음을 더해 기본 신호를 생성합니다.
%   2. 시나리오별로 결측, 급등락, 급격한 변화, 불규칙 패턴을 삽입합니다.
%   3. 누적 시간으로 요청 길이를 초과한 박동을 잘라 최종 구조체를 반환합니다.

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
% 함수 설명:
%   전체 길이에 대한 시작과 종료 비율로 연속 참 구간 마스크를 생성합니다.
%
% 입력:
%   n (수치형 스칼라, 비어 있을 수 없음: 마스크 길이 또는 개수입니다.)
%   startFrac (수치형 스칼라, 비어 있을 수 없음: 시작 위치 비율입니다.)
%   endFrac (수치형 스칼라, 비어 있을 수 없음: 종료 위치 비율입니다.)
%
% 출력:
%   mask (논리형 벡터: 지정 구간만 true인 마스크입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    first = max(1, round(startFrac * n));
    last = min(n, round(endFrac * n));
    mask = false(n, 1);
    mask(first:last) = true;
end
