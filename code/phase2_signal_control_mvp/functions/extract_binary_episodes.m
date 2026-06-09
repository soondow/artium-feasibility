function E = extract_binary_episodes(mask, mergeGapWindows)
% 함수 설명:
%   이진 윈도우 마스크를 시작, 종료, 길이를 가진 연속 에피소드 테이블로 변환합니다.
%
% 입력:
%   mask (논리형 또는 수치형 벡터, 비어 있을 수 없음: 에피소드 또는 전환 계산 대상 이진 시퀀스입니다.)
%   mergeGapWindows (수치형 스칼라, 비어 있을 수 있음: 같은 에피소드로 병합할 최대 빈 윈도우 수입니다.)
%
% 출력:
%   E (테이블: start_idx, stop_idx, duration_windows 컬럼을 가진 에피소드 목록입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
%
% 처리 절차:
%   1. 마스크 앞뒤에 false를 붙이고 차분해 상승 및 하강 경계를 찾습니다.
%   2. 시작과 종료 인덱스를 에피소드 행렬로 묶습니다.
%   3. 지정된 빈 구간 이하로 떨어진 에피소드를 병합합니다.
%   4. 빈 결과도 동일한 스키마의 0행 테이블로 반환합니다.

    if nargin < 2 || isempty(mergeGapWindows)
        mergeGapWindows = 0;
    end

    mask = logical(mask(:));
    edges = diff([false; mask; false]);
    starts = find(edges == 1);
    stops = find(edges == -1) - 1;

    episodes = [starts stops];
    episodes = mergeCloseEpisodes(episodes, mergeGapWindows);

    if isempty(episodes)
        E = table(zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
            'VariableNames', {'start_idx', 'stop_idx', 'duration_windows'});
        return;
    end

    durationWindows = episodes(:, 2) - episodes(:, 1) + 1;
    E = table(episodes(:, 1), episodes(:, 2), durationWindows, ...
        'VariableNames', {'start_idx', 'stop_idx', 'duration_windows'});
end

function merged = mergeCloseEpisodes(episodes, maxGap)
% 함수 설명:
%   지정된 빈 구간 이하로 떨어진 이웃 에피소드를 하나로 병합합니다.
%
% 입력:
%   episodes (테이블 또는 수치형 행렬, 비어 있을 수 없음: 시작 및 종료 인덱스를 포함한 에피소드 목록입니다.)
%   maxGap (수치형 스칼라, 비어 있을 수 없음: 병합할 최대 빈 윈도우 수입니다.)
%
% 출력:
%   merged (수치형 행렬: 병합이 반영된 에피소드 목록입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    if isempty(episodes)
        merged = episodes;
        return;
    end

    merged = episodes;
    writeIdx = 1;

    for i = 2:size(episodes, 1)
        gap = episodes(i, 1) - merged(writeIdx, 2) - 1;
        if gap <= maxGap
            merged(writeIdx, 2) = episodes(i, 2);
        else
            writeIdx = writeIdx + 1;
            merged(writeIdx, :) = episodes(i, :);
        end
    end

    merged = merged(1:writeIdx, :);
end
