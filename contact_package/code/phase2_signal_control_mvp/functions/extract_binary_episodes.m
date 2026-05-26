function E = extract_binary_episodes(mask, mergeGapWindows)
%EXTRACT_BINARY_EPISODES binary window mask를 연속 episode로 변환한다.
%
% E = extract_binary_episodes(mask)는 각 연속 true 구간의 start/stop index를
% 반환한다. E = extract_binary_episodes(mask, N)은 false window가 N개 이하로
% 떨어져 있는 episode들을 병합한다.

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
