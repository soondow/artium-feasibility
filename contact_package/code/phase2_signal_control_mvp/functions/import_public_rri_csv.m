function S = import_public_rri_csv(csvPath, varargin)
% 함수 설명:
%   외부 ECG/PPG 기반 RRI CSV를 Phase 2 윈도우 분할 함수가 사용할 수 있는 구조체로 변환합니다.
%
% 입력:
%   csvPath (문자형 또는 문자열, 비어 있을 수 없음: 가져올 CSV 파일 경로입니다.)
%   varargin (이름-값 인자, 비어 있을 수 있음: ScenarioName으로 시나리오명을 지정할 수 있습니다.)
%
% 출력:
%   S (구조체: scenario, label, time_sec, rri_ms, true_risk, true_low_quality 필드를 포함합니다.)
%
% 예외:
%   CSV 파일이 없거나 RRI/IBI 계열 열을 찾지 못하면 error를 발생시킵니다.
%
% 처리 절차:
%   1. CSV를 읽고 흔한 RRI/IBI 열 이름을 대소문자 무관하게 탐색합니다.
%   2. 초 또는 밀리초 시간 열이 있으면 사용하고, 없으면 누적 RRI로 time_sec을 복원합니다.
%   3. 시간과 RRI가 모두 유효한 행만 남깁니다.
%   4. Phase 2 파이프라인 입력 구조체와 낮은 품질 프록시 라벨을 생성합니다.

    p = inputParser;
    addRequired(p, 'csvPath', @(x) ischar(x) || isstring(x));
    addParameter(p, 'ScenarioName', "public_rri_unlabeled", @(x) ischar(x) || isstring(x));
    parse(p, csvPath, varargin{:});

    csvPath = string(csvPath);
    if ~isfile(csvPath)
        error('CSV file not found: %s', csvPath);
    end

    T = readtable(csvPath);
    names = string(T.Properties.VariableNames);
    lowerNames = lower(names);

    rriNames = ["rri_ms", "ibi_ms", "rr_ms", "rr_interval_ms", "nn_ms", "interval_ms"];
    rriCol = find_first_column(lowerNames, rriNames);
    if rriCol == 0
        error('CSV must contain one RRI/IBI column: %s', strjoin(rriNames, ', '));
    end

    rriMs = T{:, rriCol};
    rriMs = double(rriMs(:));

    timeSec = [];
    secCol = find_first_column(lowerNames, ["time_sec", "timestamp_sec", "t_sec", "seconds"]);
    msCol = find_first_column(lowerNames, ["time_ms", "timestamp_ms", "t_ms"]);
    if secCol > 0
        timeSec = double(T{:, secCol});
    elseif msCol > 0
        timeSec = double(T{:, msCol}) / 1000;
    end

    if isempty(timeSec)
        filledRri = fillmissing(rriMs, 'constant', median(rriMs, 'omitnan'));
        timeSec = cumsum(filledRri) / 1000;
    else
        timeSec = timeSec(:);
    end

    valid = ~isnan(timeSec) & ~isnan(rriMs);
    timeSec = timeSec(valid);
    rriMs = rriMs(valid);

    S = struct();
    S.scenario = string(p.Results.ScenarioName);
    S.label = "external ECG/PPG-derived RRI import";
    S.time_sec = timeSec;
    S.rri_ms = rriMs;
    S.true_risk = false(size(rriMs));
    S.true_low_quality = isnan(rriMs) | rriMs < 300 | rriMs > 2000;
end

function idx = find_first_column(lowerNames, candidates)
% 함수 설명:
%   후보 열 이름 목록 중 테이블에 처음으로 존재하는 열의 인덱스를 찾습니다.
%
% 입력:
%   lowerNames (문자열 배열, 비어 있을 수 없음: 소문자로 정규화된 실제 열 이름입니다.)
%   candidates (문자열 배열, 비어 있을 수 없음: 허용할 후보 열 이름입니다.)
%
% 출력:
%   idx (수치형 스칼라: 찾은 열 인덱스이며, 없으면 0입니다.)
%
% 예외:
%   입력 배열이 문자열 비교를 지원하지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    idx = 0;
    for i = 1:numel(candidates)
        hit = find(lowerNames == candidates(i), 1, 'first');
        if ~isempty(hit)
            idx = hit;
            return;
        end
    end
end
