function E = extract_binary_episodes(mask, mergeGapWindows)
%EXTRACT_BINARY_EPISODES Convert a binary window mask into contiguous episodes.
%
% E = extract_binary_episodes(mask) returns start/stop indices for each
% contiguous true region. E = extract_binary_episodes(mask, N) merges
% episodes separated by N or fewer false windows.
%
% The merge gap is important for overlapping wearable windows: a short gap
% between window alerts often represents the same user-facing episode, not a
% new independent alarm event.

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
