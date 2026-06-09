function W = segment_rri_windows(S, beatsPerWindow, strideBeats)
% 함수 설명:
%   박동 단위 RRI 구조체를 겹치는 고정 길이 윈도우 테이블로 분할합니다.
%
% 입력:
%   S (구조체, 비어 있을 수 없음: RRI, 시간축, 실제 위험 및 품질 라벨을 담은 신호 구조체입니다.)
%   beatsPerWindow (수치형 스칼라, 비어 있을 수 있음: 한 윈도우에 포함할 박동 수입니다.)
%   strideBeats (수치형 스칼라, 비어 있을 수 있음: 윈도우 시작 간격입니다.)
%
% 출력:
%   W (테이블: 윈도우 ID, 시작 박동, 시간, 라벨, RRI 셀 배열을 담습니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
%
% 처리 절차:
%   1. 시작 박동 인덱스를 stride 기준으로 생성합니다.
%   2. 각 윈도우의 RRI 벡터와 시작 및 종료 시간을 추출합니다.
%   3. 윈도우 내부 위험 및 낮은 품질 라벨 비율이 기준 이상이면 해당 윈도우 라벨을 true로 설정합니다.

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
