function S = import_public_rri_csv(csvPath, varargin)
%IMPORT_PUBLIC_RRI_CSV Import an external ECG/PPG-derived RRI CSV file.
%
% The importer is intentionally schema-light. It accepts common interval
% column names such as rri_ms, ibi_ms, rr_ms, rr_interval_ms, and nn_ms.
% If no time column is present, time_sec is reconstructed by cumulative RRI.

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
    idx = 0;
    for i = 1:numel(candidates)
        hit = find(lowerNames == candidates(i), 1, 'first');
        if ~isempty(hit)
            idx = hit;
            return;
        end
    end
end
