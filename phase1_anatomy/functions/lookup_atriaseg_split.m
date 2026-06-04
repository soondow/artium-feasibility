function [case_split, source_set, source_id] = lookup_atriaseg_split(repoRoot, caseNames)
%LOOKUP_ATRIASEG_SPLIT Attach train/test metadata from data_external/atriaseg_splits.
%
% Missing split data is treated as "unknown" instead of failing the batch.
% PHASE1 feature extraction should remain reproducible even when the external
% manifest is unavailable, while still preserving split metadata when present.

    caseNames = string(caseNames(:));
    nCase = numel(caseNames);

    case_split = repmat("unknown", nCase, 1);
    source_set = repmat("unknown", nCase, 1);
    source_id = repmat("unknown", nCase, 1);

    splitPath = fullfile(repoRoot, 'data_external', 'atriaseg_splits', 'case_split.csv');
    if ~isfile(splitPath)
        warning('Split manifest not found: %s', splitPath);
        return;
    end

    S = readtable(splitPath, 'TextType', 'string');
    requiredVars = ["case_id", "split", "source_set", "source_id"];
    if ~all(ismember(requiredVars, string(S.Properties.VariableNames)))
        warning('Split manifest is missing required columns: %s', splitPath);
        return;
    end

    for i = 1:nCase
        idx = find(S.case_id == caseNames(i), 1, 'first');
        if isempty(idx)
            continue;
        end

        case_split(i) = S.split(idx);
        source_set(i) = S.source_set(idx);
        source_id(i) = S.source_id(idx);
    end
end
